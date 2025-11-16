# Complete workflow demonstration showcasing all StaticCompiler.jl features
# This example demonstrates logging, cross-compilation, TUI, parallel processing, and more

using StaticCompiler

# Example function to compile
function calculate_primes(n::Int)
    primes = Int[]
    for num in 2:n
        is_prime = true
        for i in 2:isqrt(num)
            if num % i == 0
                is_prime = false
                break
            end
        end
        if is_prime
            push!(primes, num)
        end
    end
    return length(primes)
end

function demo_logging()
    println("\n" * "="^70)
    println("1. LOGGING SYSTEM DEMONSTRATION")
    println("="^70)

    # Configure logging to file and console
    config = LogConfig(
        level=INFO,
        log_to_file=true,
        log_file="demo_output/staticcompiler.log",
        use_colors=true
    )
    set_log_config(config)

    log_info("Logging system initialized")
    log_info("Starting compilation workflow", Dict(
        "function" => "calculate_primes",
        "target" => "demonstration"
    ))

    # Use log sections for organized output
    log_section("Analysis Phase") do
        log_info("Analyzing function")
        sleep(0.5)  # Simulate work
        log_info("Analysis complete", Dict("score" => "85.0"))
    end

    # Different log levels
    log_debug("This is a debug message (won't show at INFO level)")
    log_warn("This is a warning", Dict("threshold" => "exceeded"))

    println("\n✓ Logging demonstration complete")
    println("  Log file: demo_output/staticcompiler.log")
end

function demo_cross_compilation()
    println("\n" * "="^70)
    println("2. CROSS-COMPILATION DEMONSTRATION")
    println("="^70)

    # List available targets
    println("\nAvailable cross-compilation targets:")
    targets = list_cross_targets()
    for (i, (name, desc)) in enumerate(targets[1:min(5, length(targets))])
        println("  $i. $name: $desc")
    end

    # Demonstrate cross-compilation for ARM64 Linux
    println("\nCross-compiling for ARM64 Linux...")

    target = get_cross_target(:arm64_linux)
    log_info("Cross-compilation target selected", Dict(
        "arch" => target.arch,
        "os" => target.os
    ))

    try
        result = cross_compile_with_preset(
            calculate_primes, (Int,),
            "demo_output/cross",
            "primes_arm64",
            :embedded,
            target,
            verbose=false
        )

        log_info("Cross-compilation successful", Dict(
            "binary" => result["binary_path"],
            "size" => format_bytes(result["binary_size"])
        ))

        println("\n✓ Cross-compilation complete")
        println("  Target: ARM64 Linux")
        println("  Size: $(format_bytes(result["binary_size"]))")
    catch e
        log_warn("Cross-compilation skipped", Dict("reason" => "toolchain not available"))
        println("\n⚠️  Cross-compilation requires appropriate toolchain")
    end
end

function demo_parallel_processing()
    println("\n" * "="^70)
    println("3. PARALLEL PROCESSING DEMONSTRATION")
    println("="^70)

    println("\nComparing presets in parallel...")
    println("This demonstrates concurrent compilation for faster results\n")

    log_section("Parallel Preset Comparison") do
        # Get optimal concurrency
        max_concurrent = get_optimal_concurrency()
        log_info("Detected optimal concurrency", Dict("cores" => max_concurrent))

        # Compare presets in parallel
        try
            results = parallel_compare_presets(
                calculate_primes, (Int,), (100,),
                "demo_output/parallel",
                presets=[:embedded, :desktop, :release],
                max_concurrent=3,
                use_cache=true,
                verbose=true
            )

            println("\n✓ Parallel comparison complete")
            println("  Presets tested: $(length(results))")
        catch e
            log_warn("Parallel compilation skipped", Dict("reason" => string(e)))
        end
    end
end

function demo_smart_optimization()
    println("\n" * "="^70)
    println("4. SMART OPTIMIZATION DEMONSTRATION")
    println("="^70)

    println("\nUsing smart optimization (auto-selects best preset)...\n")

    log_section("Smart Optimization") do
        try
            result = smart_optimize(
                calculate_primes, (Int,),
                "demo_output/smart",
                "primes_smart",
                args=(100,),
                target=:auto,
                verbose=true
            )

            println("\n✓ Smart optimization complete")
            println("  Recommended preset: $(result.recommended_preset)")
            println("  Binary size: $(format_bytes(result.binary_size))")
            println("  Strategy: $(result.optimization_strategy)")
        catch e
            log_warn("Smart optimization skipped", Dict("reason" => string(e)))
        end
    end
end

function demo_pgo()
    println("\n" * "="^70)
    println("5. PROFILE-GUIDED OPTIMIZATION DEMONSTRATION")
    println("="^70)

    println("\nRunning PGO with iterative optimization...\n")

    log_section("Profile-Guided Optimization") do
        try
            config = PGOConfig(
                initial_profile=:PROFILE_DEBUG,
                target_metric=:speed,
                iterations=3,
                benchmark_samples=50,
                auto_apply=true
            )

            result = pgo_compile(
                calculate_primes, (Int,), (100,),
                "demo_output/pgo",
                "primes_pgo",
                config=config,
                verbose=true
            )

            println("\n✓ PGO complete")
            println("  Best profile: $(result.best_profile)")
            println("  Improvement: $(round(result.improvement_pct, digits=2))%")
            println("  Iterations: $(result.iterations_completed)")
        catch e
            log_warn("PGO skipped", Dict("reason" => string(e)))
        end
    end
end

function demo_caching()
    println("\n" * "="^70)
    println("6. RESULT CACHING DEMONSTRATION")
    println("="^70)

    cache_config = ResultCacheConfig(
        enabled=true,
        cache_dir="demo_output/cache",
        max_age_days=7
    )

    println("\nFirst run (will cache results)...")
    key1 = result_cache_key(calculate_primes, (Int,), 100)

    # Simulate caching
    mock_result = BenchmarkResult(
        "calculate_primes",
        100,
        1000.0,
        2000.0,
        2100.0,
        3000.0,
        500.0,
        0,
        0,
        :PROFILE_SPEED,
        15000,
        Dates.now()
    )

    cache_benchmark_result(mock_result, key1, config=cache_config)
    println("  ✓ Result cached")

    println("\nSecond run (will use cache)...")
    cached = load_cached_benchmark(key1, config=cache_config)

    if cached !== nothing
        println("  ✓ Result loaded from cache")
        println("  Median time: $(format_time(cached.median_time_ns))")
    end

    # Show cache statistics
    stats = result_cache_stats(cache_config)
    println("\nCache statistics:")
    println("  Entries: $(stats["total_entries"])")
    println("  Size: $(format_bytes(stats["total_size_bytes"]))")
end

function demo_error_handling()
    println("\n" * "="^70)
    println("7. ERROR HANDLING DEMONSTRATION")
    println("="^70)

    println("\nDemonstrating safe compilation with cleanup...")

    # Example: with_cleanup ensures cleanup even on errors
    cleanup_called = false

    try
        with_cleanup(
            () -> begin
                println("  Executing operation...")
                # Simulated work
                sleep(0.2)
                println("  Operation complete")
                return "success"
            end,
            () -> begin
                cleanup_called = true
                println("  Cleanup executed")
            end
        )
    catch e
        println("  Error occurred (cleanup still executed)")
    end

    println("\n✓ Error handling demonstration complete")
    println("  Cleanup executed: $cleanup_called")

    # Demonstrate retry logic
    println("\nDemonstrating retry with exponential backoff...")

    attempt = 0
    result = retry_on_failure(
        () -> begin
            attempt += 1
            println("  Attempt $attempt")
            if attempt < 3
                error("Simulated transient failure")
            end
            return "success"
        end,
        max_attempts=5,
        delay_seconds=0.1,
        verbose=false
    )

    println("  ✓ Success after $attempt attempts")
end

function demo_comprehensive_report()
    println("\n" * "="^70)
    println("8. COMPREHENSIVE ANALYSIS DEMONSTRATION")
    println("="^70)

    println("\nGenerating comprehensive analysis report...\n")

    try
        report = generate_comprehensive_report(
            calculate_primes, (Int,),
            compile=false,
            verbose=true
        )

        println("\nReport Summary:")
        println("  Overall score: $(round(report.overall_score, digits=1))/100")
        println("  Performance score: $(round(report.performance_score, digits=1))/100")
        println("  Security score: $(round(report.security_score, digits=1))/100")

        if report.recommendations !== nothing
            println("\nTop recommendations:")
            for (i, rec) in enumerate(report.recommendations.recommendations[1:min(3, end)])
                println("  $i. $(rec.description)")
            end
        end
    catch e
        log_warn("Analysis skipped", Dict("reason" => string(e)))
    end
end

function show_summary()
    println("\n" * "="^70)
    println("DEMONSTRATION COMPLETE")
    println("="^70)

    println("\nFeatures demonstrated:")
    println("  ✓ Structured logging system")
    println("  ✓ Cross-compilation for multiple targets")
    println("  ✓ Parallel processing for faster workflows")
    println("  ✓ Smart automatic optimization")
    println("  ✓ Profile-guided optimization (PGO)")
    println("  ✓ Result caching for performance")
    println("  ✓ Robust error handling")
    println("  ✓ Comprehensive analysis and reporting")

    println("\nGenerated outputs:")
    println("  demo_output/")
    println("  ├── staticcompiler.log (log file)")
    println("  ├── cross/ (cross-compiled binaries)")
    println("  ├── parallel/ (parallel compilation results)")
    println("  ├── smart/ (smart optimization results)")
    println("  ├── pgo/ (PGO optimization results)")
    println("  └── cache/ (cached results)")

    println("\nNext steps:")
    println("  1. Try: quick_interactive_menu() for interactive exploration")
    println("  2. Try: interactive_optimize(your_function, types, path, name)")
    println("  3. Read documentation in docs/ directory")
end

# Main demonstration runner
function main()
    println("StaticCompiler.jl - Complete Workflow Demonstration")
    println("This demo showcases all major features")
    println()
    println("Press Enter to start...")
    readline()

    # Create output directory
    mkpath("demo_output")

    try
        # Run all demonstrations
        demo_logging()
        demo_cross_compilation()
        demo_parallel_processing()
        demo_smart_optimization()
        demo_pgo()
        demo_caching()
        demo_error_handling()
        demo_comprehensive_report()

        show_summary()

    catch e
        println("\n❌ Error during demonstration: $e")
        println()
        println("Some features may require:")
        println("  - C compiler (gcc/clang)")
        println("  - Cross-compilation toolchains")
        println("  - Sufficient disk space")
    finally
        println("\nCleaning up...")
        # Note: In production, you might want to keep outputs
        # rm("demo_output", recursive=true, force=true)
    end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
else
    println("Demo loaded. Run main() to execute the complete demonstration.")
end
