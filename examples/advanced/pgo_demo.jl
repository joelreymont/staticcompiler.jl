#!/usr/bin/env julia

# Profile-Guided Optimization (PGO) Demo
# Shows how to use runtime profiling to guide compilation optimizations

using StaticCompiler

println("=== Profile-Guided Optimization Demo ===\n")

# Example function: Matrix-vector multiplication
function matvec_multiply(n::Int)
    result = 0.0
    for i in 1:n
        for j in 1:n
            result += i * j * 0.5
        end
    end
    return Int(floor(result))
end

# Example function: Fibonacci calculation
function compute_fibonacci(n::Int)
    if n <= 1
        return n
    end
    a, b = 0, 1
    for _ in 2:n
        a, b = b, a + b
    end
    return b
end

# 1. Basic Profile Collection
println("1. Collecting runtime profile...")
try
    profile = collect_profile(
        matvec_multiply,
        (Int,),
        (50,),
        verbose=false
    )

    println("   Function: $(profile.function_name)")
    println("   Median time: $(format_time(profile.benchmark_result.median_time_ns))")
    println("   Recommended profile: $(profile.recommended_profile)")

    if !isempty(profile.hot_paths)
        println("\n   Hot paths identified:")
        for (i, path) in enumerate(profile.hot_paths)
            println("      $i. $path")
        end
    end

    if !isempty(profile.optimization_opportunities)
        println("\n   Optimization opportunities:")
        for (i, opp) in enumerate(profile.optimization_opportunities)
            println("      $i. $opp")
        end
    end
catch e
    println("   Profile collection skipped: $e")
end

# 2. PGO Compilation with Speed Target
println("\n2. PGO compilation (speed target)...")
output_dir = mktempdir()

try
    config_speed = PGOConfig(
        target_metric = :speed,
        iterations = 2,
        benchmark_samples = 30,
        improvement_threshold = 3.0,
        auto_apply = true,
        save_profiles = false
    )

    result_speed = pgo_compile(
        matvec_multiply,
        (Int,),
        (50,),
        output_dir,
        "matvec_speed",
        config=config_speed,
        verbose=false
    )

    println("   Completed $(result_speed.iterations_completed) iterations")
    println("   Best profile: $(result_speed.best_profile)")
    println("   Best time: $(format_time(result_speed.best_time_ns))")
    println("   Improvement: $(round(result_speed.improvement_pct, digits=2))%")
    println("   PGO time: $(round(result_speed.total_time_ms / 1000, digits=2))s")
catch e
    println("   PGO compilation skipped: $e")
end

# 3. PGO Compilation with Size Target
println("\n3. PGO compilation (size target)...")
try
    config_size = PGOConfig(
        target_metric = :size,
        iterations = 2,
        benchmark_samples = 20,
        auto_apply = true,
        save_profiles = false
    )

    result_size = pgo_compile(
        matvec_multiply,
        (Int,),
        (50,),
        output_dir,
        "matvec_size",
        config=config_size,
        verbose=false
    )

    println("   Best profile: $(result_size.best_profile)")
    println("   Binary size: $(format_bytes(result_size.final_binary_size))")
    println("   Time: $(format_time(result_size.best_time_ns))")
catch e
    println("   Size-targeted PGO skipped: $e")
end

# 4. PGO Compilation with Balanced Target
println("\n4. PGO compilation (balanced target)...")
try
    config_balanced = PGOConfig(
        target_metric = :balanced,
        iterations = 3,
        benchmark_samples = 25,
        improvement_threshold = 5.0,
        auto_apply = true,
        save_profiles = false
    )

    result_balanced = pgo_compile(
        compute_fibonacci,
        (Int,),
        (30,),
        output_dir,
        "fib_balanced",
        config=config_balanced,
        verbose=false
    )

    println("   Iterations: $(result_balanced.iterations_completed)")
    println("   Best profile: $(result_balanced.best_profile)")
    println("   Time: $(format_time(result_balanced.best_time_ns))")
    println("   Size: $(format_bytes(result_balanced.final_binary_size))")
catch e
    println("   Balanced PGO skipped: $e")
end

# 5. PGO Configuration Options
println("\n5. PGO configuration options:")
println("   Available target metrics:")
println("      - :speed     (optimize for performance)")
println("      - :size      (optimize for binary size)")
println("      - :balanced  (balance size and speed)")
println("")
println("   Configuration parameters:")
println("      - initial_profile:       Starting optimization profile")
println("      - target_metric:         Optimization goal")
println("      - iterations:            Number of PGO cycles")
println("      - benchmark_samples:     Samples per benchmark")
println("      - improvement_threshold: Min % improvement to continue")
println("      - auto_apply:            Auto-apply recommendations")
println("      - save_profiles:         Save profile data to disk")
println("      - profile_dir:           Directory for saved profiles")

# 6. Manual Profile Analysis
println("\n6. Manual profile analysis workflow:")
println("   Step 1: Collect baseline profile")
println("      profile = collect_profile(func, types, args)")
println("")
println("   Step 2: Review recommendations")
println("      println(profile.recommended_profile)")
println("      println(profile.optimization_opportunities)")
println("")
println("   Step 3: Apply recommendations manually")
println("      compile with recommended profile")
println("")
println("   Step 4: Benchmark and compare")
println("      new_profile = collect_profile(func, types, args)")
println("      compare improvements")

# 7. Iterative Optimization Example
println("\n7. Iterative optimization example:")
example_config = PGOConfig(
    target_metric = :speed,
    iterations = 3,
    benchmark_samples = 50,
    improvement_threshold = 2.0,
    save_profiles = true,
    profile_dir = ".pgo_profiles"
)

println("   Config: $(example_config.iterations) iterations")
println("   Target: $(example_config.target_metric)")
println("   Threshold: $(example_config.improvement_threshold)%")
println("   Samples: $(example_config.benchmark_samples)")
println("")
println("   Typical PGO workflow:")
println("      Iteration 1: Compile with DEBUG, profile runtime")
println("      Iteration 2: Apply recommended profile, re-profile")
println("      Iteration 3: Fine-tune based on improvements")
println("      Stop when: improvement < threshold")

# Summary
println("\n" * "="^70)
println("PGO Features Summary")
println("="^70)
println("")
println("Profile Collection:")
println("   - Runtime performance measurement")
println("   - Hot path identification")
println("   - Optimization opportunity detection")
println("   - Automatic profile recommendation")
println("")
println("Iterative Optimization:")
println("   - Multiple compilation cycles")
println("   - Progressive refinement")
println("   - Automatic convergence detection")
println("   - Profile data persistence")
println("")
println("Target Metrics:")
println("   - Speed: Minimize execution time")
println("   - Size: Minimize binary size")
println("   - Balanced: Optimize both metrics")
println("")
println("Integration:")
println("   - Works with existing benchmarking system")
println("   - Compatible with all optimization profiles")
println("   - Saves profile data for analysis")
println("   - Supports manual and automatic modes")
println("")
println("Use Cases:")
println("   - Finding optimal optimization settings")
println("   - Validating performance improvements")
println("   - Automated CI/CD optimization")
println("   - Performance regression prevention")

# Cleanup
try
    rm(output_dir, recursive=true, force=true)
catch
end

println("\n" * "="^70)
