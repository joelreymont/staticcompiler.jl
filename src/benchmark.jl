# Benchmark infrastructure for tracking compilation performance

using Serialization

struct BenchmarkResult
    function_name::String
    types::Tuple
    timestamp::Float64
    compilation_time_s::Float64
    binary_size_kb::Float64
    cache_hit::Bool
    julia_version::VersionNumber
    compiler_version::String
end

const BENCHMARK_DB = Ref{String}("")

function get_benchmark_db()
    if isempty(BENCHMARK_DB[])
        BENCHMARK_DB[] = joinpath(homedir(), ".julia", "staticcompiler_benchmarks", "benchmarks.jls")
    end
    return BENCHMARK_DB[]
end

"""
    @benchmark_compilation f types

Benchmark the compilation of a function and track it over time.

# Example
```julia
@benchmark_compilation fib (Int,)
```
"""
macro benchmark_compilation(f, types)
    quote
        benchmark_compile($(esc(f)), $(esc(types)))
    end
end

"""
    benchmark_compile(f, types; path=tempdir(), kwargs...)

Compile a function and record benchmark data.

Returns the compiled executable path and benchmark result.
"""
function benchmark_compile(f, types; path=tempdir(), name=string(nameof(f)), kwargs...)
    println("Benchmarking compilation of $(nameof(f))$types...")

    # Clear cache to get accurate compilation time
    clear_cache!()

    # Time the compilation
    start_time = time()
    exe_path = compile_executable(f, types, path, name; kwargs...)
    end_time = time()

    compilation_time = end_time - start_time
    binary_size = filesize(exe_path) / 1024  # KB

    # Create benchmark result
    result = BenchmarkResult(
        string(nameof(f)),
        types,
        time(),
        compilation_time,
        binary_size,
        false,  # cache was cleared
        VERSION,
        string(VERSION)
    )

    # Save to database
    save_benchmark(result)

    # Print results
    println("Compilation time: $(round(compilation_time, digits=2))s")
    println("Binary size: $(round(binary_size, digits=1)) KB")

    return exe_path, result
end

function save_benchmark(result::BenchmarkResult)
    db_path = get_benchmark_db()
    mkpath(dirname(db_path))

    # Load existing benchmarks
    benchmarks = if isfile(db_path)
        try
            deserialize(db_path)
        catch
            BenchmarkResult[]
        end
    else
        BenchmarkResult[]
    end

    # Add new result
    push!(benchmarks, result)

    # Save back
    serialize(db_path, benchmarks)
end

"""
    load_benchmarks()

Load all benchmark history.
"""
function load_benchmarks()
    db_path = get_benchmark_db()
    if !isfile(db_path)
        return BenchmarkResult[]
    end

    try
        return deserialize(db_path)
    catch
        @warn "Could not load benchmark database"
        return BenchmarkResult[]
    end
end

"""
    show_benchmark_history(function_name::String)

Show benchmark history for a specific function.
"""
function show_benchmark_history(function_name::String)
    benchmarks = load_benchmarks()
    matching = filter(b -> b.function_name == function_name, benchmarks)

    if isempty(matching)
        println("No benchmarks found for: $function_name")
        return
    end

    # Sort by timestamp
    sort!(matching, by=b->b.timestamp)

    println("Benchmark History for $function_name:")
    println("=" ^ 60)
    println()

    for (i, result) in enumerate(matching)
        date = Dates.unix2datetime(result.timestamp)
        println("Run $i - $(Dates.format(date, "yyyy-mm-dd HH:MM:SS"))")
        println("  Compilation time: $(round(result.compilation_time_s, digits=2))s")
        println("  Binary size: $(round(result.binary_size_kb, digits=1)) KB")
        println("  Julia version: $(result.julia_version)")
        println()
    end

    # Show trends if we have multiple results
    if length(matching) >= 2
        first_result = matching[1]
        last_result = matching[end]

        time_change = ((last_result.compilation_time_s - first_result.compilation_time_s) /
                      first_result.compilation_time_s) * 100
        size_change = ((last_result.binary_size_kb - first_result.binary_size_kb) /
                      first_result.binary_size_kb) * 100

        println("Trends (first vs last):")
        time_symbol = time_change > 0 ? "↑" : "↓"
        size_symbol = size_change > 0 ? "↑" : "↓"
        println("  Compilation time: $time_symbol $(abs(round(time_change, digits=1)))%")
        println("  Binary size: $size_symbol $(abs(round(size_change, digits=1)))%")
    end
end

"""
    clear_benchmarks!()

Clear all benchmark history.
"""
function clear_benchmarks!()
    db_path = get_benchmark_db()
    if isfile(db_path)
        rm(db_path)
        println("Benchmark history cleared")
    end
end

"""
    compare_benchmarks(f, types; runs=3)

Run multiple compilation benchmarks and compare results.
"""
function compare_benchmarks(f, types; runs=3)
    println("Running $runs benchmark compilations...")
    results = BenchmarkResult[]

    for i in 1:runs
        println("\nRun $i/$runs:")
        _, result = benchmark_compile(f, types, name="bench_run_$i")
        push!(results, result)
    end

    println("\n" * "=" ^ 60)
    println("Summary Statistics:")
    println("=" ^ 60)

    times = [r.compilation_time_s for r in results]
    sizes = [r.binary_size_kb for r in results]

    println("Compilation Time:")
    println("  Mean: $(round(sum(times)/length(times), digits=2))s")
    println("  Min:  $(round(minimum(times), digits=2))s")
    println("  Max:  $(round(maximum(times), digits=2))s")
    println()
    println("Binary Size:")
    println("  Mean: $(round(sum(sizes)/length(sizes), digits=1)) KB")
    println("  Min:  $(round(minimum(sizes), digits=1)) KB")
    println("  Max:  $(round(maximum(sizes), digits=1)) KB")

    return results
end

export @benchmark_compilation, benchmark_compile
export load_benchmarks, show_benchmark_history, clear_benchmarks!, compare_benchmarks
