# Performance Benchmarking
# Measures actual runtime performance of compiled binaries

using Statistics

"""
    BenchmarkResult

Stores benchmark timing results for a compiled function.

# Fields
- `function_name::String` - Name of the benchmarked function
- `samples::Int` - Number of benchmark iterations
- `min_time_ns::Float64` - Minimum execution time in nanoseconds
- `median_time_ns::Float64` - Median execution time in nanoseconds
- `mean_time_ns::Float64` - Mean execution time in nanoseconds
- `max_time_ns::Float64` - Maximum execution time in nanoseconds
- `std_dev_ns::Float64` - Standard deviation in nanoseconds
- `allocations::Int` - Number of allocations (if measured)
- `memory_bytes::Int` - Memory allocated in bytes (if measured)
- `optimization_profile::Union{Symbol,Nothing}` - Optimization profile used
- `binary_size_bytes::Int` - Size of compiled binary
- `timestamp::DateTime` - When benchmark was run
"""
struct BenchmarkResult
    function_name::String
    samples::Int
    min_time_ns::Float64
    median_time_ns::Float64
    mean_time_ns::Float64
    max_time_ns::Float64
    std_dev_ns::Float64
    allocations::Int
    memory_bytes::Int
    optimization_profile::Union{Symbol,Nothing}
    binary_size_bytes::Int
    timestamp::DateTime
end

"""
    BenchmarkConfig

Configuration for benchmarking runs.

# Fields
- `samples::Int` - Number of iterations (default: 100)
- `warmup_samples::Int` - Warmup iterations before measuring (default: 10)
- `measure_allocations::Bool` - Track allocations (default: true)
- `timeout_seconds::Float64` - Maximum time per iteration (default: 10.0)
- `profiles_to_test::Vector{Symbol}` - Optimization profiles to benchmark (default: [:SPEED, :SIZE])
- `compare_baseline::Bool` - Compare against unoptimized build (default: true)
- `check_regression::Bool` - Detect performance regressions (default: false)
- `regression_threshold::Float64` - Regression threshold percentage (default: 5.0)
"""
struct BenchmarkConfig
    samples::Int
    warmup_samples::Int
    measure_allocations::Bool
    timeout_seconds::Float64
    profiles_to_test::Vector{Symbol}
    compare_baseline::Bool
    check_regression::Bool
    regression_threshold::Float64

    function BenchmarkConfig(;
        samples::Int = 100,
        warmup_samples::Int = 10,
        measure_allocations::Bool = true,
        timeout_seconds::Float64 = 10.0,
        profiles_to_test::Vector{Symbol} = [:SPEED, :SIZE],
        compare_baseline::Bool = true,
        check_regression::Bool = false,
        regression_threshold::Float64 = DEFAULT_REGRESSION_THRESHOLD_PCT
    )
        new(samples, warmup_samples, measure_allocations, timeout_seconds,
            profiles_to_test, compare_baseline, check_regression, regression_threshold)
    end
end

"""
    benchmark_function(f, types, args; config=BenchmarkConfig(), verbose=true)

Benchmark a compiled function's runtime performance.

# Arguments
- `f` - Function to benchmark
- `types` - Tuple of argument types
- `args` - Tuple of argument values for benchmarking
- `config` - BenchmarkConfig for configuration
- `verbose` - Print progress information

# Returns
- `BenchmarkResult` with timing statistics

# Example
```julia
add(x::Int, y::Int) = x + y
result = benchmark_function(add, (Int, Int), (10, 20))
println("Median time: \$(result.median_time_ns / 1000) μs")
```
"""
function benchmark_function(f, types, args; config=BenchmarkConfig(), verbose=true)
    verbose && println("Benchmarking $(nameof(f))...")

    # Compile the function
    output_dir = mktempdir()
    binary_name = string(nameof(f), "_bench")
    binary_path = joinpath(output_dir, binary_name)

    try
        # Compile to shared library
        verbose && println("  Compiling...")
        compile_shlib(f, types, binary_path, name=binary_name)

        if !isfile(binary_path * ".so")
            error("Compilation failed - binary not found")
        end

        binary_size = stat(binary_path * ".so").size
        verbose && println("  Binary size: $(binary_size) bytes")

        # Load the compiled function
        lib = Libdl.dlopen(binary_path * ".so")
        func_ptr = Libdl.dlsym(lib, "julia_$(nameof(f))")

        # Create a callable wrapper
        compiled_func = if length(types) == 1
            (x) -> ccall(func_ptr, types[1], (types[1],), x)
        elseif length(types) == 2
            (x, y) -> ccall(func_ptr, types[1], (types...,), x, y)
        else
            error("Benchmarking supports up to 2 arguments currently")
        end

        # Warmup
        verbose && println("  Warming up ($(config.warmup_samples) iterations)...")
        for _ in 1:config.warmup_samples
            compiled_func(args...)
        end

        # Benchmark
        verbose && println("  Running benchmark ($(config.samples) iterations)...")
        times = Vector{Float64}(undef, config.samples)
        total_allocs = 0
        total_memory = 0

        for i in 1:config.samples
            if config.measure_allocations
                stats = @timed compiled_func(args...)
                times[i] = stats.time * 1e9  # Convert to nanoseconds
                total_allocs += stats.gcstats.allocd != 0 ? 1 : 0
                total_memory += stats.gcstats.allocd
            else
                t0 = time_ns()
                compiled_func(args...)
                times[i] = Float64(time_ns() - t0)
            end
        end

        # Calculate statistics
        min_time = minimum(times)
        median_time = median(times)
        mean_time = mean(times)
        max_time = maximum(times)
        std_dev = std(times)

        Libdl.dlclose(lib)

        result = BenchmarkResult(
            string(nameof(f)),
            config.samples,
            min_time,
            median_time,
            mean_time,
            max_time,
            std_dev,
            total_allocs,
            total_memory,
            nothing,  # No profile specified for single benchmark
            binary_size,
            Dates.now()
        )

        if verbose
            println("\n📊 Benchmark Results:")
            println("   Median: $(format_time(median_time))")
            println("   Mean:   $(format_time(mean_time)) ± $(format_time(std_dev))")
            println("   Range:  $(format_time(min_time)) - $(format_time(max_time))")
            if config.measure_allocations
                println("   Allocations: $total_allocs / $(config.samples)")
                println("   Memory: $(format_bytes(total_memory))")
            end
        end

        return result

    catch e
        verbose && println("  ⚠️  Benchmark failed: $e")
        rethrow(e)
    finally
        try
            rm(output_dir, recursive=true, force=true)
        catch
        end
    end
end

"""
    compare_optimization_profiles(f, types, args; config=BenchmarkConfig(), verbose=true)

Benchmark a function with different optimization profiles and compare results.

# Arguments
- `f` - Function to benchmark
- `types` - Tuple of argument types
- `args` - Tuple of argument values
- `config` - BenchmarkConfig with profiles_to_test specified
- `verbose` - Print comparison table

# Returns
- `Dict{Symbol, BenchmarkResult}` mapping profile names to results

# Example
```julia
results = compare_optimization_profiles(myfunc, (Int,), (100,))
fastest = findmin(r -> r.median_time_ns, values(results))
```
"""
function compare_optimization_profiles(f, types, args; config=BenchmarkConfig(), verbose=true)
    verbose && println("=== Comparing Optimization Profiles ===\n")

    results = Dict{Symbol, BenchmarkResult}()

    for profile in config.profiles_to_test
        verbose && println("Testing profile: $profile")

        output_dir = mktempdir()
        binary_name = string(nameof(f), "_", lowercase(string(profile)))
        binary_path = joinpath(output_dir, binary_name)

        try
            # Compile with specific profile
            profile_obj = get_profile_by_symbol(profile)
            opt_flags = get_optimization_flags(profile_obj)
            cflags = Cmd(opt_flags)

            compile_shlib(f, types, binary_path, name=binary_name, cflags=cflags)

            if !isfile(binary_path * ".so")
                verbose && println("  ⚠️  Compilation failed for $profile\n")
                continue
            end

            binary_size = stat(binary_path * ".so").size

            # Load and benchmark
            lib = Libdl.dlopen(binary_path * ".so")
            func_ptr = Libdl.dlsym(lib, "julia_$(nameof(f))")

            compiled_func = if length(types) == 1
                (x) -> ccall(func_ptr, types[1], (types[1],), x)
            elseif length(types) == 2
                (x, y) -> ccall(func_ptr, types[1], (types...,), x, y)
            else
                error("Benchmarking supports up to 2 arguments currently")
            end

            # Warmup
            for _ in 1:config.warmup_samples
                compiled_func(args...)
            end

            # Benchmark
            times = Vector{Float64}(undef, config.samples)
            total_allocs = 0
            total_memory = 0

            for i in 1:config.samples
                if config.measure_allocations
                    stats = @timed compiled_func(args...)
                    times[i] = stats.time * 1e9
                    total_allocs += stats.gcstats.allocd != 0 ? 1 : 0
                    total_memory += stats.gcstats.allocd
                else
                    t0 = time_ns()
                    compiled_func(args...)
                    times[i] = Float64(time_ns() - t0)
                end
            end

            result = BenchmarkResult(
                string(nameof(f)),
                config.samples,
                minimum(times),
                median(times),
                mean(times),
                maximum(times),
                std(times),
                total_allocs,
                total_memory,
                profile,
                binary_size,
                Dates.now()
            )

            results[profile] = result
            Libdl.dlclose(lib)

        catch e
            verbose && println("  ⚠️  Error benchmarking $profile: $e\n")
        finally
            try
                rm(output_dir, recursive=true, force=true)
            catch
            end
        end
    end

    # Print comparison table
    if verbose && !isempty(results)
        println("\n📊 Profile Comparison:")
        println("   " * "="^70)
        println("   Profile      Median Time    Binary Size    Speedup")
        println("   " * "-"^70)

        sorted_by_time = sort(collect(results), by=x->x[2].median_time_ns)
        baseline_time = sorted_by_time[1][2].median_time_ns

        for (profile, result) in sorted_by_time
            speedup = baseline_time / result.median_time_ns
            println("   $(rpad(string(profile), 12)) $(lpad(format_time(result.median_time_ns), 13)) " *
                   "$(lpad(format_bytes(result.binary_size_bytes), 13))    $(round(speedup, digits=2))x")
        end
        println("   " * "="^70)
    end

    return results
end

"""
    detect_performance_regression(current::BenchmarkResult, baseline::BenchmarkResult; threshold=5.0)

Detect if there's a performance regression compared to baseline.

# Arguments
- `current` - Current benchmark result
- `baseline` - Baseline benchmark result
- `threshold` - Regression threshold in percentage (default: 5.0)

# Returns
- `(has_regression::Bool, percentage::Float64, message::String)`

# Example
```julia
has_regr, pct, msg = detect_performance_regression(new_result, old_result)
if has_regr
    @warn msg
end
```
"""
function detect_performance_regression(current::BenchmarkResult, baseline::BenchmarkResult; threshold=DEFAULT_REGRESSION_THRESHOLD_PCT)
    pct_change = ((current.median_time_ns - baseline.median_time_ns) / baseline.median_time_ns) * 100.0

    if pct_change > threshold
        msg = "Performance regression detected: $(round(pct_change, digits=2))% slower " *
              "($(format_time(baseline.median_time_ns)) → $(format_time(current.median_time_ns)))"
        return (true, pct_change, msg)
    elseif pct_change < -threshold
        msg = "Performance improvement: $(round(abs(pct_change), digits=2))% faster " *
              "($(format_time(baseline.median_time_ns)) → $(format_time(current.median_time_ns)))"
        return (false, pct_change, msg)
    else
        msg = "Performance unchanged: $(round(abs(pct_change), digits=2))% difference"
        return (false, pct_change, msg)
    end
end

"""
    format_time(nanoseconds::Float64)

Format time in nanoseconds to human-readable string.
"""
function format_time(nanoseconds::Float64)
    if nanoseconds < 1000
        return "$(round(nanoseconds, digits=1)) ns"
    elseif nanoseconds < 1_000_000
        return "$(round(nanoseconds / 1000, digits=1)) μs"
    elseif nanoseconds < 1_000_000_000
        return "$(round(nanoseconds / 1_000_000, digits=1)) ms"
    else
        return "$(round(nanoseconds / 1_000_000_000, digits=2)) s"
    end
end

"""
    format_bytes(bytes::Int)

Format bytes to human-readable string.
"""
function format_bytes(bytes::Int)
    if bytes < 1024
        return "$(bytes) B"
    elseif bytes < 1024^2
        return "$(round(bytes / 1024, digits=1)) KB"
    elseif bytes < 1024^3
        return "$(round(bytes / 1024^2, digits=1)) MB"
    else
        return "$(round(bytes / 1024^3, digits=2)) GB"
    end
end

"""
    benchmark_to_dict(result::BenchmarkResult)

Convert BenchmarkResult to Dict for serialization.
"""
function benchmark_to_dict(result::BenchmarkResult)
    return Dict(
        "function_name" => result.function_name,
        "samples" => result.samples,
        "min_time_ns" => result.min_time_ns,
        "median_time_ns" => result.median_time_ns,
        "mean_time_ns" => result.mean_time_ns,
        "max_time_ns" => result.max_time_ns,
        "std_dev_ns" => result.std_dev_ns,
        "min_time_formatted" => format_time(result.min_time_ns),
        "median_time_formatted" => format_time(result.median_time_ns),
        "mean_time_formatted" => format_time(result.mean_time_ns),
        "allocations" => result.allocations,
        "memory_bytes" => result.memory_bytes,
        "memory_formatted" => format_bytes(result.memory_bytes),
        "optimization_profile" => result.optimization_profile,
        "binary_size_bytes" => result.binary_size_bytes,
        "binary_size_formatted" => format_bytes(result.binary_size_bytes),
        "timestamp" => string(result.timestamp)
    )
end

"""
    save_benchmark_history(result::BenchmarkResult, filepath::String)

Append benchmark result to a history file for tracking over time.

# Arguments
- `result` - BenchmarkResult to save
- `filepath` - Path to history file (will be created if doesn't exist)

# Example
```julia
result = benchmark_function(myfunc, (Int,), (100,))
save_benchmark_history(result, "benchmarks/history.json")
```
"""
function save_benchmark_history(result::BenchmarkResult, filepath::String)
    # Load existing history
    history = if isfile(filepath)
        try
            parse_json_file(filepath)
        catch
            []
        end
    else
        []
    end

    # Append new result
    push!(history, benchmark_to_dict(result))

    # Write back
    write_json_file(filepath, history)
end
