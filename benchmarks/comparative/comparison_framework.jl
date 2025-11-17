# Comparative Benchmark Framework
# Compare StaticCompiler.jl optimizations with baselines

using Dates

"""
    ComparisonResult

Stores comparison data between two approaches.
"""
struct ComparisonResult
    approach_a_name::String
    approach_b_name::String
    metric_name::String
    value_a::Float64
    value_b::Float64
    improvement_pct::Float64
    winner::String
    timestamp::DateTime
end

"""
    compare_approaches(name_a, value_a, name_b, value_b, metric; higher_is_better=false)

Compare two approaches and determine the winner.
"""
function compare_approaches(name_a, value_a, name_b, value_b, metric; higher_is_better=false)
    if higher_is_better
        improvement = ((value_a - value_b) / value_b) * 100.0
        winner = value_a > value_b ? name_a : name_b
    else
        improvement = ((value_b - value_a) / value_a) * 100.0
        winner = value_a < value_b ? name_a : value_b
    end

    return ComparisonResult(
        name_a, name_b, metric,
        value_a, value_b,
        abs(improvement), winner,
        now()
    )
end

"""
    generate_comparison_report(results::Vector{ComparisonResult})

Generate a comprehensive comparison report.
"""
function generate_comparison_report(results::Vector{ComparisonResult})
    println("\n" * "="^80)
    println("COMPARATIVE BENCHMARK REPORT")
    println("="^80)
    println()
    println("Generated: $(now())")
    println()

    # Group by metric
    metrics = unique([r.metric_name for r in results])

    for metric in metrics
        println("-"^80)
        println("METRIC: $metric")
        println("-"^80)
        println()

        metric_results = filter(r -> r.metric_name == metric, results)

        for result in metric_results
            winner_marker = result.winner == result.approach_a_name ? "✅" : "  "
            println("  $winner_marker $(result.approach_a_name): $(round(result.value_a, digits=3))")

            winner_marker = result.winner == result.approach_b_name ? "✅" : "  "
            println("  $winner_marker $(result.approach_b_name): $(round(result.value_b, digits=3))")

            println()
            println("     Winner: $(result.winner)")
            println("     Improvement: $(round(result.improvement_pct, digits=1))%")
            println()
        end
    end

    println("="^80)
    println()
end

"""
    benchmark_compilation_overhead()

Compare compilation time overhead of different optimization levels.
"""
function benchmark_compilation_overhead()
    println("\n" * "="^70)
    println("COMPILATION OVERHEAD COMPARISON")
    println("="^70)
    println()

    results = ComparisonResult[]

    # Simple test function
    test_func(x::Int) = x * 2 + x * 3

    println("Testing with function: test_func(x::Int) = x * 2 + x * 3")
    println()

    # Measure analysis time
    println("⏱️  Measuring analysis overhead...")

    # Baseline (no analysis)
    t_baseline = @elapsed for _ in 1:10
        # Just type inference, no custom analysis
        nothing
    end

    # With escape analysis
    t_escape = @elapsed for _ in 1:10
        analyze_escapes(test_func, (Int,))
    end

    # With all analyses
    t_all = @elapsed for _ in 1:10
        analyze_escapes(test_func, (Int,))
        analyze_monomorphization(test_func, (Int,))
        analyze_devirtualization(test_func, (Int,))
        analyze_constants(test_func, (Int,))
        analyze_lifetimes(test_func, (Int,))
    end

    # Calculate per-iteration times (in milliseconds)
    baseline_ms = (t_baseline / 10) * 1000
    escape_ms = (t_escape / 10) * 1000
    all_ms = (t_all / 10) * 1000

    println()
    println("Results (per iteration):")
    println("  Baseline (no analysis):     $(round(baseline_ms, digits=2)) ms")
    println("  Escape analysis only:       $(round(escape_ms, digits=2)) ms")
    println("  All analyses:               $(round(all_ms, digits=2)) ms")
    println()

    overhead_pct = ((all_ms - baseline_ms) / baseline_ms) * 100
    println("  Analysis overhead: $(round(overhead_pct, digits=1))%")
    println()

    push!(results, compare_approaches(
        "No Analysis", baseline_ms,
        "All Analyses", all_ms,
        "Compilation Time (ms)",
        higher_is_better=false
    ))

    println("="^70)
    println()

    return results
end

"""
    benchmark_optimization_effectiveness()

Compare effectiveness of different optimizations.
"""
function benchmark_optimization_effectiveness()
    println("\n" * "="^70)
    println("OPTIMIZATION EFFECTIVENESS COMPARISON")
    println("="^70)
    println()

    results = ComparisonResult[]

    # Test various scenarios
    scenarios = [
        ("Simple arithmetic", (x::Int) -> x * 2 + 3),
        ("With allocation", (n::Int) -> sum(zeros(10))),
        ("Multiple operations", (x::Int) -> x + x * 2 - x * 3),
    ]

    for (name, func) in scenarios
        println("📊 Scenario: $name")

        # Analyze
        escape = analyze_escapes(func, (Int,))
        mono = analyze_monomorphization(func, (Int,))
        devirt = analyze_devirtualization(func, (Int,))

        println("   Escape analysis: $(escape.promotable_allocations) stack-promotable")
        println("   Monomorphization: $(mono.has_abstract_types ? "needed" : "not needed")")
        println("   Devirtualization: $(devirt.devirtualizable_calls) calls")
        println()
    end

    println("="^70)
    println()

    return results
end

"""
    benchmark_vs_baseline()

Compare optimized vs unoptimized approaches.
"""
function benchmark_vs_baseline()
    println("\n" * "="^70)
    println("OPTIMIZED VS BASELINE COMPARISON")
    println("="^70)
    println()

    results = ComparisonResult[]

    # Scenario: Allocation-heavy function
    println("📊 Test: Allocation-heavy computation")
    println()

    # Unoptimized (using Vector)
    function unoptimized_sum(n::Int)
        arr = Vector{Float64}(undef, 100)
        for i in 1:100
            arr[i] = Float64(i)
        end
        return sum(arr) + n
    end

    # Optimized (analysis would suggest StaticArrays)
    # For comparison, we just measure analysis capability
    escape_report = analyze_escapes(unoptimized_sum, (Int,))

    println("   Unoptimized approach:")
    println("     Allocations: $(length(escape_report.allocations))")
    println("     Stack-promotable: $(escape_report.promotable_allocations)")
    println()

    if escape_report.promotable_allocations > 0
        println("   ✅ Optimization opportunity identified!")
        println("      Potential savings: $(escape_report.potential_savings_bytes) bytes")
    end

    println()
    println("="^70)
    println()

    return results
end

# Run comparisons if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    println("Running comparative benchmarks...")
    println()

    results = ComparisonResult[]

    append!(results, benchmark_compilation_overhead())
    append!(results, benchmark_optimization_effectiveness())
    append!(results, benchmark_vs_baseline())

    if !isempty(results)
        generate_comparison_report(results)
    end

    println("✅ Comparative benchmarking complete")
    println()
end

export ComparisonResult, compare_approaches, generate_comparison_report
export benchmark_compilation_overhead, benchmark_optimization_effectiveness
export benchmark_vs_baseline
