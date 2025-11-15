# Binary size estimation and analysis

struct SizeEstimate
    min_kb::Float64
    expected_kb::Float64
    max_kb::Float64
    confidence::Float64
    breakdown::Dict{Symbol, Float64}
end

"""
    estimate_binary_size(f, types; target=StaticTarget())

Estimate the size of the compiled binary before actually compiling.

Returns a SizeEstimate with min/expected/max sizes in KB, confidence level,
and a breakdown of where the size comes from.

# Example
```julia
estimate = estimate_binary_size(fib, (Int,))
println("Expected binary size: \$(estimate.expected_kb) KB")
```
"""
function estimate_binary_size(f, types; target=StaticTarget(), verbose=false)
    # Build call graph to count functions
    num_functions = try
        estimate_function_count(f, types)
    catch
        1  # At minimum, the main function
    end

    # Check for problematic patterns
    report = check_compilable(f, types, verbose=false)

    has_allocations = any(i -> i.category == :gc_allocation, report.issues)
    has_runtime_calls = any(i -> i.category == :runtime_call, report.issues)
    has_io = any(i -> i.category == :io_operation, report.issues)

    # Estimate LLVM IR size
    llvm_size_kb = try
        mod = static_llvm_module(f, types; demangle=true)
        length(string(mod)) / 1024
    catch
        num_functions * 2.0  # Rough estimate: 2KB per function
    end

    # Base sizes by platform
    base_sizes = Dict(
        "x86_64-linux" => 14.0,
        "aarch64-linux" => 16.0,
        "wasm32" => 8.0,
        "x86_64-windows" => 18.0,
        "arm-none" => 4.0
    )

    triple = LLVM.triple(target.tm)
    base_size = get(base_sizes, triple, 15.0)

    # Calculate components
    breakdown = Dict{Symbol, Float64}()
    breakdown[:base] = base_size
    breakdown[:functions] = num_functions * 1.5
    breakdown[:llvm_overhead] = llvm_size_kb * 0.3

    # Runtime dependencies add size
    if has_allocations
        breakdown[:allocator] = 8.0
    end

    if has_runtime_calls
        breakdown[:runtime] = 25.0
    end

    if has_io
        breakdown[:io_system] = 40.0
    end

    # Static tools overhead
    breakdown[:static_tools] = 2.0

    # Calculate estimates
    expected = sum(values(breakdown))
    min_size = expected * 0.7  # Optimistic with aggressive optimization
    max_size = expected * 1.5  # Pessimistic with debug symbols

    # Confidence based on analysis quality
    confidence = 0.7
    if num_functions > 1
        confidence += 0.1
    end
    if !has_runtime_calls
        confidence += 0.1
    end

    estimate = SizeEstimate(min_size, expected, max_size, min(confidence, 0.95), breakdown)

    if verbose
        print_size_estimate(estimate)
    end

    return estimate
end

function estimate_function_count(f, types)
    # Use static_code_typed to get initial function
    tt = Base.to_tuple_type(types)
    code_info = only(static_code_typed(f, tt))

    # Count unique functions called
    # This is a simple heuristic - actual count may vary
    count = 1

    # Scan for calls in the IR
    if isdefined(code_info[1], :code)
        for stmt in code_info[1].code
            if isa(stmt, Expr) && stmt.head == :call
                count += 0.5  # Fractional because some might be inlined
            end
        end
    end

    return ceil(Int, count)
end

function print_size_estimate(estimate::SizeEstimate)
    println("Binary Size Estimate:")
    println("  Expected: $(round(estimate.expected_kb, digits=1)) KB")
    println("  Range: $(round(estimate.min_kb, digits=1)) - $(round(estimate.max_kb, digits=1)) KB")
    println("  Confidence: $(round(estimate.confidence * 100, digits=0))%")
    println()
    println("  Breakdown:")
    for (component, size) in sort(collect(estimate.breakdown), by=x->x[2], rev=true)
        pct = (size / estimate.expected_kb) * 100
        println("    $(component): $(round(size, digits=1)) KB ($(round(pct, digits=0))%)")
    end
end

"""
    analyze_binary_size(binary_path)

Analyze an already-compiled binary to understand its size composition.

# Example
```julia
compile_executable(fib, (Int,), "/tmp", "fib")
analysis = analyze_binary_size("/tmp/fib")
```
"""
function analyze_binary_size(binary_path::String)
    if !isfile(binary_path)
        error("Binary not found: $binary_path")
    end

    total_size = filesize(binary_path) / 1024  # KB

    # Try to get section sizes if possible
    sections = Dict{Symbol, Float64}()

    # Use size command if available
    size_info = try
        if Sys.isunix()
            output = read(`size $binary_path`, String)
            # Parse size output
            lines = split(output, '\n')
            if length(lines) >= 2
                parts = split(strip(lines[2]))
                if length(parts) >= 3
                    sections[:text] = parse(Float64, parts[1]) / 1024
                    sections[:data] = parse(Float64, parts[2]) / 1024
                    sections[:bss] = parse(Float64, parts[3]) / 1024
                end
            end
        end
        sections
    catch
        sections
    end

    analysis = Dict{Symbol, Any}(
        :total_kb => total_size,
        :sections => sections,
        :stripped => check_if_stripped(binary_path)
    )

    return analysis
end

function check_if_stripped(binary_path::String)
    # Check if binary has debug symbols
    try
        if Sys.isunix()
            output = read(`file $binary_path`, String)
            return occursin("stripped", output)
        end
    catch
    end
    return false
end

export estimate_binary_size, analyze_binary_size, SizeEstimate
