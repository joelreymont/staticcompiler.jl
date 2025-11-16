# Parallel processing demonstration for StaticCompiler.jl
# Shows how to use parallel compilation and benchmarking for faster iteration

using StaticCompiler

# Example function to compile
function fibonacci(n::Int)
    if n <= 1
        return n
    end
    a, b = 0, 1
    for _ in 2:n
        a, b = b, a + b
    end
    return b
end

function demo_parallel_preset_comparison()
    println("=" * "^70")
    println("Parallel Preset Comparison Demo")
    println("="^70)
    println()

    # Sequential comparison (old way)
    println("1. Sequential comparison (for reference)...")
    sequential_start = time()

    sequential_results = compare_presets(
        fibonacci,
        (Int,),
        (30,),
        "output/sequential",
        presets=[:embedded, :serverless, :desktop],
        verbose=false
    )

    sequential_time = time() - sequential_start
    println("   Sequential time: $(round(sequential_time, digits=2))s")
    println()

    # Parallel comparison (new way)
    println("2. Parallel comparison (4 concurrent)...")
    parallel_start = time()

    # Get optimal concurrency for this system
    optimal = get_optimal_concurrency()
    println("   Optimal concurrency for this system: $optimal")
    println()

    parallel_results = parallel_compare_presets(
        fibonacci,
        (Int,),
        (30,),
        "output/parallel",
        presets=[:embedded, :serverless, :desktop, :hpc, :development, :release],
        max_concurrent=4,
        use_cache=true,
        verbose=true
    )

    parallel_time = time() - parallel_start
    println("   Parallel time: $(round(parallel_time, digits=2))s")
    println()

    # Speedup calculation
    if sequential_time > 0
        speedup = sequential_time / parallel_time
        println("Speedup: $(round(speedup, digits=2))x")
    end

    println()

    # Cleanup
    rm("output", recursive=true, force=true)
end

function demo_parallel_profile_benchmarking()
    println("\n" * "="^70)
    println("Parallel Profile Benchmarking Demo")
    println("="^70)
    println()

    println("Benchmarking fibonacci with multiple optimization profiles in parallel...")
    println()

    results = parallel_benchmark_profiles(
        fibonacci,
        (Int,),
        (30,),
        profiles=[:PROFILE_SIZE, :PROFILE_SPEED, :PROFILE_AGGRESSIVE, :PROFILE_DEBUG],
        max_concurrent=4,
        verbose=true
    )

    println()
    println("Results summary:")
    for (profile, result) in sort(collect(results), by=x->x[2].binary_size_bytes)
        println("  $(rpad(string(profile), 20)): " *
                "$(rpad(format_bytes(result.binary_size_bytes), 10)) " *
                "$(format_time(result.median_time_ns))")
    end
    println()
end

function demo_cached_workflow()
    println("\n" * "="^70)
    println("Cached Workflow Demo")
    println("="^70)
    println()

    # Create cache config
    cache_dir = mktempdir()
    cache_config = ResultCacheConfig(
        enabled=true,
        cache_dir=cache_dir,
        max_age_days=7,
        auto_clean=true
    )

    println("First run (will compile and cache)...")
    println()

    first_run_start = time()
    results1 = parallel_compare_presets(
        fibonacci,
        (Int,),
        (30,),
        "output/cached_1",
        presets=[:embedded, :serverless, :desktop],
        max_concurrent=3,
        use_cache=true,
        cache_config=cache_config,
        verbose=true
    )
    first_run_time = time() - first_run_start

    println("\nSecond run (will use cache)...")
    println()

    second_run_start = time()
    results2 = parallel_compare_presets(
        fibonacci,
        (Int,),
        (30,),
        "output/cached_2",
        presets=[:embedded, :serverless, :desktop],
        max_concurrent=3,
        use_cache=true,
        cache_config=cache_config,
        verbose=true
    )
    second_run_time = time() - second_run_start

    println()
    println("First run time:  $(round(first_run_time, digits=2))s")
    println("Second run time: $(round(second_run_time, digits=2))s")

    if first_run_time > 0
        speedup = first_run_time / second_run_time
        println("Cache speedup: $(round(speedup, digits=2))x")
    end

    # Show cache stats
    println()
    println("Cache statistics:")
    stats = result_cache_stats(cache_config)
    println("  Entries: $(stats["total_entries"])")
    println("  Size: $(format_bytes(stats["total_size_bytes"]))")
    println("  Location: $(stats["cache_dir"])")

    # Cleanup
    rm("output", recursive=true, force=true)
    rm(cache_dir, recursive=true, force=true)
    println()
end

# Run demonstrations
println("StaticCompiler.jl - Parallel Processing Demonstrations")
println()

try
    demo_parallel_preset_comparison()
    demo_parallel_profile_benchmarking()
    demo_cached_workflow()

    println("="^70)
    println("All demonstrations completed successfully!")
    println("="^70)
catch e
    println("Error during demonstration: $e")
    println()
    println("Note: Some demos require compilation capabilities.")
    println("Make sure you have a C compiler (gcc/clang) installed.")
end
