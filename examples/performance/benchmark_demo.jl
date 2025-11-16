#!/usr/bin/env julia

# Performance Benchmarking Demo
# Shows how to measure actual runtime performance of compiled code

using StaticCompiler

println("=== Performance Benchmarking Demo ===\n")

# Example function 1: Simple arithmetic
function sum_range(n::Int)
    total = 0
    for i in 1:n
        total += i
    end
    return total
end

# Example function 2: Mathematical computation
function compute_pi(n::Int)
    sum = 0.0
    for i in 1:n
        sum += ((-1.0)^(i-1)) / (2.0*i - 1.0)
    end
    return 4.0 * sum
end

# 1️⃣  Basic benchmark
println("1️⃣  Basic function benchmark...")
try
    config = BenchmarkConfig(
        samples = 50,
        warmup_samples = 5,
        measure_allocations = true
    )

    result = benchmark_function(sum_range, (Int,), (1000,), config=config, verbose=false)

    println("   Function: $(result.function_name)")
    println("   Samples: $(result.samples)")
    println("   Median time: $(format_time(result.median_time_ns))")
    println("   Mean time: $(format_time(result.mean_time_ns)) ± $(format_time(result.std_dev_ns))")
    println("   Binary size: $(format_bytes(result.binary_size_bytes))")
    if result.allocations > 0
        println("   Allocations: $(result.allocations)")
    end
catch e
    println("   ⚠️  Benchmark skipped: $e")
end

# 2️⃣  Comparing optimization profiles
println("\n2️⃣  Comparing optimization profiles...")
try
    config = BenchmarkConfig(
        samples = 30,
        warmup_samples = 3,
        profiles_to_test = [:SPEED, :SIZE],
        measure_allocations = false
    )

    results = compare_optimization_profiles(
        compute_pi,
        (Int,),
        (1000,),
        config=config,
        verbose=false
    )

    if !isempty(results)
        println("\n   Profile Comparison Results:")
        for (profile, result) in sort(collect(results), by=x->x[2].median_time_ns)
            println("   $(rpad(string(profile), 10)): $(format_time(result.median_time_ns)) " *
                   "(binary: $(format_bytes(result.binary_size_bytes)))")
        end

        # Find fastest
        fastest = findmin(r -> r[2].median_time_ns, results)
        println("\n   ✅ Fastest profile: $(fastest[1][1])")
    end
catch e
    println("   ⚠️  Profile comparison skipped: $e")
end

# 3️⃣  Regression detection
println("\n3️⃣  Performance regression detection...")
try
    # Simulate baseline and current results
    config = BenchmarkConfig(samples=30, warmup_samples=3)

    println("   Creating baseline benchmark...")
    baseline = benchmark_function(sum_range, (Int,), (1000,), config=config, verbose=false)

    println("   Creating current benchmark...")
    current = benchmark_function(sum_range, (Int,), (1000,), config=config, verbose=false)

    # Check for regression (using 5% threshold)
    has_regression, pct_change, message = detect_performance_regression(
        current, baseline, threshold=5.0
    )

    if has_regression
        println("   ⚠️  $message")
    else
        println("   ✅ $message")
    end
catch e
    println("   ⚠️  Regression detection skipped: $e")
end

# 4️⃣  Benchmark history tracking
println("\n4️⃣  Benchmark history tracking...")
try
    output_dir = mktempdir()
    history_file = joinpath(output_dir, "benchmark_history.json")

    config = BenchmarkConfig(samples=20, warmup_samples=2)

    # Run multiple benchmarks and save history
    println("   Collecting benchmark samples...")
    for i in 1:3
        result = benchmark_function(sum_range, (Int,), (1000,), config=config, verbose=false)
        save_benchmark_history(result, history_file)
        println("   Sample $i: $(format_time(result.median_time_ns))")
        sleep(0.1)  # Small delay between runs
    end

    if isfile(history_file)
        file_size = stat(history_file).size
        println("\n   ✅ History saved to: $history_file")
        println("   History file size: $(format_bytes(file_size))")
    end

    # Cleanup
    try
        rm(output_dir, recursive=true)
    catch
    end
catch e
    println("   ⚠️  History tracking skipped: $e")
end

# 5️⃣  Custom benchmark configuration
println("\n5️⃣  Custom benchmark configurations...")
try
    # Fast benchmark (fewer samples)
    fast_config = BenchmarkConfig(
        samples = 10,
        warmup_samples = 2,
        measure_allocations = false,
        timeout_seconds = 5.0
    )

    # Thorough benchmark (more samples)
    thorough_config = BenchmarkConfig(
        samples = 100,
        warmup_samples = 10,
        measure_allocations = true,
        timeout_seconds = 30.0
    )

    println("   Fast benchmark (10 samples):")
    fast_result = benchmark_function(sum_range, (Int,), (500,), config=fast_config, verbose=false)
    println("      Median: $(format_time(fast_result.median_time_ns))")

    println("\n   Thorough benchmark (100 samples):")
    thorough_result = benchmark_function(sum_range, (Int,), (500,), config=thorough_config, verbose=false)
    println("      Median: $(format_time(thorough_result.median_time_ns))")
    println("      Std Dev: $(format_time(thorough_result.std_dev_ns))")

    println("\n   ✅ More samples provide more stable measurements")
catch e
    println("   ⚠️  Custom config demo skipped: $e")
end

# Summary
println("\n📊 Benchmarking Features:")
println("   ✅ Accurate runtime performance measurement")
println("   ✅ Statistical analysis (median, mean, std dev)")
println("   ✅ Optimization profile comparison")
println("   ✅ Performance regression detection")
println("   ✅ Historical tracking and trending")
println("   ✅ Configurable sample counts and warmup")
println("   ✅ Allocation and memory tracking")

println("\n💡 Usage Tips:")
println("   - Use median time (not mean) for typical performance")
println("   - Run warmup iterations to stabilize JIT effects")
println("   - Increase sample count for more accurate results")
println("   - Track history to detect performance regressions in CI")
println("   - Compare profiles to find the best optimization strategy")

println("\n📈 CI/CD Integration:")
println("   - Save benchmark results to JSON for historical tracking")
println("   - Set performance budgets and fail builds on regression")
println("   - Compare branches to validate optimizations")
println("   - Generate performance reports for pull requests")
