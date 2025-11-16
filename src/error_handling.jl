# Enhanced error handling with cleanup and recovery

"""
    CompilationError

Base type for compilation-related errors.
"""
abstract type CompilationError <: Exception end

"""
    CompilationFailure

Error when compilation fails.
"""
struct CompilationFailure <: CompilationError
    function_name::String
    stage::String
    message::String
    original_error::Union{Exception,Nothing}
end

function Base.showerror(io::IO, e::CompilationFailure)
    print(io, "Compilation failed for '$(e.function_name)' at stage '$(e.stage)': $(e.message)")
    if e.original_error !== nothing
        print(io, "\n  Caused by: $(e.original_error)")
    end
end

"""
    BenchmarkError

Error during benchmarking.
"""
struct BenchmarkError <: CompilationError
    function_name::String
    message::String
    original_error::Union{Exception,Nothing}
end

function Base.showerror(io::IO, e::BenchmarkError)
    print(io, "Benchmarking failed for '$(e.function_name)': $(e.message)")
    if e.original_error !== nothing
        print(io, "\n  Caused by: $(e.original_error)")
    end
end

"""
    PGOError

Error during profile-guided optimization.
"""
struct PGOError <: CompilationError
    function_name::String
    iteration::Int
    message::String
    original_error::Union{Exception,Nothing}
end

function Base.showerror(io::IO, e::PGOError)
    print(io, "PGO failed for '$(e.function_name)' at iteration $(e.iteration): $(e.message)")
    if e.original_error !== nothing
        print(io, "\n  Caused by: $(e.original_error)")
    end
end

"""
    with_cleanup(f::Function, cleanup::Function)

Execute function `f` and ensure `cleanup` runs even if an error occurs.

# Arguments
- `f` - Function to execute
- `cleanup` - Cleanup function (should not throw)

# Returns
- Result of `f()` if successful

# Example
```julia
tmpdir = mktempdir()
result = with_cleanup(
    () -> compile_executable(func, types, tmpdir, "test"),
    () -> rm(tmpdir, recursive=true, force=true)
)
```
"""
function with_cleanup(f::Function, cleanup::Function)
    try
        return f()
    finally
        try
            cleanup()
        catch e
            @warn "Cleanup failed" exception=(e, catch_backtrace())
        end
    end
end

"""
    safe_compile(f, types, output_path, name; cleanup_on_error=true, verbose=false, kwargs...)

Safely compile with automatic cleanup on errors.

# Arguments
- `f` - Function to compile
- `types` - Type signature
- `output_path` - Output directory
- `name` - Binary name
- `cleanup_on_error` - Remove output directory on failure (default: true)
- `verbose` - Print error details
- `kwargs...` - Additional arguments for compile_executable

# Returns
- Path to compiled binary

# Throws
- `CompilationFailure` with error details
"""
function safe_compile(f, types, output_path, name;
                     cleanup_on_error=true,
                     verbose=false,
                     kwargs...)
    created_dir = false

    try
        # Create output directory if it doesn't exist
        if !isdir(output_path)
            mkpath(output_path)
            created_dir = true
        end

        # Attempt compilation
        binary_path = compile_executable(f, types, output_path, name; kwargs...)

        if !isfile(binary_path)
            throw(CompilationFailure(
                string(nameof(f)),
                "output",
                "Binary file was not created: $binary_path",
                nothing
            ))
        end

        return binary_path

    catch e
        if verbose
            @error "Compilation failed" exception=(e, catch_backtrace())
        end

        # Cleanup on error if requested
        if cleanup_on_error && created_dir && isdir(output_path)
            try
                rm(output_path, recursive=true, force=true)
            catch cleanup_err
                @warn "Failed to cleanup output directory" exception=cleanup_err
            end
        end

        # Re-throw as CompilationFailure if not already
        if isa(e, CompilationError)
            rethrow(e)
        else
            throw(CompilationFailure(
                string(nameof(f)),
                "compilation",
                "Unexpected error during compilation",
                e
            ))
        end
    end
end

"""
    safe_benchmark(f, types, args; config=BenchmarkConfig(), verbose=false)

Safely benchmark with error handling and cleanup.

# Arguments
- `f` - Function to benchmark
- `types` - Type signature
- `args` - Benchmark arguments
- `config` - BenchmarkConfig
- `verbose` - Print error details

# Returns
- `BenchmarkResult` or `nothing` on failure

# Example
```julia
result = safe_benchmark(myfunc, (Int,), (100,))
if result !== nothing
    println("Median time: \$(result.median_time_ns) ns")
end
```
"""
function safe_benchmark(f, types, args; config=BenchmarkConfig(), verbose=false)
    tmpdir = mktempdir()

    try
        return with_cleanup(
            () -> benchmark_function(f, types, args, config=config, verbose=false),
            () -> rm(tmpdir, recursive=true, force=true)
        )
    catch e
        if verbose
            @error "Benchmarking failed" exception=(e, catch_backtrace())
        end

        # Return nothing instead of throwing for non-critical operations
        return nothing
    end
end

"""
    retry_on_failure(f::Function; max_attempts=3, delay_seconds=1.0, verbose=false)

Retry a function on failure with exponential backoff.

# Arguments
- `f` - Function to execute
- `max_attempts` - Maximum number of attempts (default: 3)
- `delay_seconds` - Initial delay between attempts (default: 1.0)
- `verbose` - Print retry attempts

# Returns
- Result of `f()` if any attempt succeeds

# Throws
- Last exception if all attempts fail

# Example
```julia
result = retry_on_failure(
    () -> network_dependent_operation(),
    max_attempts=5,
    delay_seconds=2.0
)
```
"""
function retry_on_failure(f::Function; max_attempts=3, delay_seconds=1.0, verbose=false)
    last_error = nothing

    for attempt in 1:max_attempts
        try
            return f()
        catch e
            last_error = e

            if attempt < max_attempts
                if verbose
                    @warn "Attempt $attempt/$max_attempts failed, retrying in $(delay_seconds)s..." exception=e
                end

                sleep(delay_seconds)
                delay_seconds *= 2  # Exponential backoff
            end
        end
    end

    # All attempts failed
    if verbose
        @error "All $max_attempts attempts failed" exception=(last_error, catch_backtrace())
    end

    throw(last_error)
end

"""
    validate_compilation_result(binary_path::String;
                                min_size_bytes=100,
                                check_executable=true)

Validate that a compilation result is valid.

# Arguments
- `binary_path` - Path to compiled binary
- `min_size_bytes` - Minimum expected file size (default: 100)
- `check_executable` - Verify file has executable permissions (Unix only)

# Returns
- `true` if valid, `false` otherwise

# Example
```julia
if validate_compilation_result(binary_path)
    println("Binary is valid")
end
```
"""
function validate_compilation_result(binary_path::String;
                                     min_size_bytes=100,
                                     check_executable=true)
    # Check file exists
    if !isfile(binary_path)
        @warn "Binary file does not exist: $binary_path"
        return false
    end

    # Check file size
    file_size = filesize(binary_path)
    if file_size < min_size_bytes
        @warn "Binary file is suspiciously small: $file_size bytes (expected at least $min_size_bytes)"
        return false
    end

    # Check executable permissions on Unix
    if check_executable && !Sys.iswindows()
        try
            # Check if file has executable bit set
            mode = stat(binary_path).mode
            is_executable = (mode & 0o111) != 0

            if !is_executable
                @warn "Binary file is not executable: $binary_path"
                return false
            end
        catch e
            @warn "Failed to check executable permissions" exception=e
        end
    end

    return true
end

"""
    collect_diagnostics(f, types)

Collect diagnostic information about a function for error reporting.

# Arguments
- `f` - Function to analyze
- `types` - Type signature

# Returns
- `Dict` with diagnostic information

# Example
```julia
diagnostics = collect_diagnostics(myfunc, (Int, Float64))
println("Methods: \$(diagnostics["method_count"])")
```
"""
function collect_diagnostics(f, types)
    diagnostics = Dict{String, Any}()

    try
        diagnostics["function_name"] = string(nameof(f))
        diagnostics["type_signature"] = string(types)

        # Get method information
        tt = Base.to_tuple_type(types)
        methods_list = methods(f, tt)
        diagnostics["method_count"] = length(methods_list)

        if length(methods_list) > 0
            m = first(methods_list)
            diagnostics["method_file"] = string(m.file)
            diagnostics["method_line"] = m.line
            diagnostics["method_module"] = string(m.module)
        end

        # Check if function is generic
        diagnostics["is_generic"] = length(methods(f)) > 1

    catch e
        diagnostics["error"] = string(e)
    end

    return diagnostics
end

"""
    error_context(f::Function, context::Dict{String,Any})

Execute function with additional context for better error messages.

# Arguments
- `f` - Function to execute
- `context` - Context information (e.g., function name, stage)

# Returns
- Result of `f()`

# Throws
- Original exception with added context

# Example
```julia
result = error_context(
    () -> risky_operation(),
    Dict("operation" => "compilation", "stage" => "llvm")
)
```
"""
function error_context(f::Function, context::Dict{String,Any})
    try
        return f()
    catch e
        @error "Operation failed" context... exception=(e, catch_backtrace())
        rethrow(e)
    end
end
