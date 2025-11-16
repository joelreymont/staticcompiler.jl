# Automated optimization recommendations

struct Recommendation
    priority::Symbol  # :critical, :high, :medium, :low
    category::Symbol  # :performance, :size, :correctness
    issue::String
    suggestion::String
    code_example::String
    estimated_impact::String
end

"""
Comprehensive optimization recommendations
"""
struct OptimizationRecommendations
    recommendations::Vector{Recommendation}
    overall_score::Float64  # 0-100
    potential_improvement::String
end

"""
    recommend_optimizations(f, types; verbose=true)

Analyze a function and provide actionable optimization recommendations.

Returns an OptimizationRecommendations object with prioritized suggestions
for improving compilation, performance, and binary size.

# Example
```julia
recs = recommend_optimizations(my_func, (Int, Float64))
println("Found \$(length(recs.recommendations)) recommendations")

for rec in recs.recommendations
    println("\$(rec.priority): \$(rec.issue)")
    println("   → \$(rec.suggestion)")
end
```
"""
function recommend_optimizations(f, types; verbose=true)
    recommendations = Recommendation[]

    # Run comprehensive analysis
    report = advanced_analysis(f, types, verbose=false)

    # 1. Check for allocations (CRITICAL for static compilation)
    if report.allocations.total_allocations > 0
        push!(recommendations, Recommendation(
            :critical,
            :correctness,
            "$(report.allocations.total_allocations) heap allocation$(report.allocations.total_allocations > 1 ? "s" : "") detected",
            "Replace Julia arrays with StaticTools.MallocArray or stack-allocated memory",
            """
            # Instead of:
            arr = zeros(Int, 100)

            # Use:
            using StaticTools
            arr = MallocArray{Int}(100)
            # or for small arrays:
            arr = @MVector zeros(Int, 100)
            """,
            "Enables static compilation, prevents runtime errors"
        ))
    end

    # 2. Check inlining opportunities
    not_inlined = length(report.inlining.not_inlined)
    if not_inlined > 3
        push!(recommendations, Recommendation(
            :high,
            :performance,
            "$not_inlined function calls not inlined",
            "Add @inline annotations to frequently called small functions",
            """
            @inline function compute(x::Int, y::Int)
                return x * 2 + y
            end
            """,
            "5-15% performance improvement on hot paths"
        ))
    end

    # 3. Check for large functions (binary bloat)
    if length(report.bloat.large_functions) > 5
        largest = report.bloat.large_functions[1]
        push!(recommendations, Recommendation(
            :medium,
            :size,
            "$(length(report.bloat.large_functions)) large functions (>1KB) increase binary size",
            "Split large functions into smaller helper functions",
            """
            # Instead of one large function:
            function process_all(data)
                # 100 lines of code...
            end

            # Split into:
            function process_all(data)
                step1 = preprocess(data)
                step2 = transform(step1)
                return finalize(step2)
            end

            @inline function preprocess(data) ... end
            @inline function transform(data) ... end
            @inline function finalize(data) ... end
            """,
            "10-30% binary size reduction"
        ))
    end

    # 4. Check for type specializations (bloat)
    redundant = length(report.bloat.redundant_specializations)
    if redundant > 10
        push!(recommendations, Recommendation(
            :medium,
            :size,
            "$redundant redundant type specializations detected",
            "Use @nospecialize on non-performance-critical arguments",
            """
            # Instead of:
            function helper(x, msg)  # Creates specializations for all msg types
                println(msg)
                return x * 2
            end

            # Use:
            function helper(x, @nospecialize(msg))
                println(msg)
                return x * 2
            end
            """,
            "15-25% binary size reduction"
        ))
    end

    # 5. Performance score analysis
    if report.performance_score < 70
        push!(recommendations, Recommendation(
            :high,
            :performance,
            "Performance score is low ($(round(report.performance_score, digits=1))/100)",
            "Review allocations, type stability, and inlining",
            """
            # Use these tools to debug:
            @code_warntype my_func(args...)  # Check type stability
            alloc_profile = analyze_allocations(my_func, types)  # Find allocations
            inline_info = analyze_inlining(my_func, types)  # Check inlining
            """,
            "Could improve overall performance by 2-5x"
        ))
    end

    # 6. Size score analysis
    if report.size_score < 60
        push!(recommendations, Recommendation(
            :medium,
            :size,
            "Size score is low ($(round(report.size_score, digits=1))/100)",
            "Use aggressive optimization profile and UPX compression",
            """
            exe = compile_executable_optimized(
                my_func, types,
                "/tmp", "myapp",
                profile=PROFILE_AGGRESSIVE  # Includes strip + UPX
            )
            """,
            "50-70% binary size reduction possible"
        ))
    end

    # 7. Check basic compilability
    basic_report = check_compilable(f, types, verbose=false)
    if !basic_report.compilable
        for issue in basic_report.issues
            if issue.severity == :error
                push!(recommendations, Recommendation(
                    :critical,
                    :correctness,
                    string(issue.category) * ": " * issue.message,
                    issue.suggestion,
                    "# See error diagnostics for details",
                    "Required for static compilation"
                ))
            end
        end
    end

    # Calculate overall score
    overall_score = (report.performance_score + report.size_score) / 2.0

    # Estimate potential improvement
    potential = if overall_score >= 85
        "Excellent! Only minor optimizations possible."
    elseif overall_score >= 70
        "Good foundation. Following recommendations could achieve 20-40% improvements."
    elseif overall_score >= 50
        "Significant optimization opportunity. Could achieve 50-100% improvements."
    else
        "Major optimization needed. Following recommendations could achieve 2-5x improvements."
    end

    result = OptimizationRecommendations(
        recommendations,
        overall_score,
        potential
    )

    if verbose
        print_recommendations(result)
    end

    return result
end

function print_recommendations(recs::OptimizationRecommendations)
    println("\n" * "="^70)
    println("AUTOMATED OPTIMIZATION RECOMMENDATIONS")
    println("="^70)

    println("\n📊 OVERALL SCORE: $(round(recs.overall_score, digits=1))/100")
    println("💡 POTENTIAL: $(recs.potential)")

    if isempty(recs.recommendations)
        println("\n✅ No recommendations - your code is already well optimized!")
        return
    end

    # Group by priority
    critical = filter(r -> r.priority == :critical, recs.recommendations)
    high = filter(r -> r.priority == :high, recs.recommendations)
    medium = filter(r -> r.priority == :medium, recs.recommendations)
    low = filter(r -> r.priority == :low, recs.recommendations)

    if !isempty(critical)
        println("\n🔴 CRITICAL ISSUES ($(length(critical)))")
        for (i, rec) in enumerate(critical)
            print_recommendation(i, rec)
        end
    end

    if !isempty(high)
        println("\n🟠 HIGH PRIORITY ($(length(high)))")
        for (i, rec) in enumerate(high)
            print_recommendation(i, rec)
        end
    end

    if !isempty(medium)
        println("\n🟡 MEDIUM PRIORITY ($(length(medium)))")
        for (i, rec) in enumerate(medium)
            print_recommendation(i, rec)
        end
    end

    if !isempty(low)
        println("\n🟢 LOW PRIORITY ($(length(low)))")
        for (i, rec) in enumerate(low)
            print_recommendation(i, rec)
        end
    end

    println("\n" * "="^70)
    println("💡 TIP: Address critical and high priority items first for maximum impact")
    println("="^70)
end

function print_recommendation(num::Int, rec::Recommendation)
    category_icon = rec.category == :performance ? "⚡" : rec.category == :size ? "📦" : "✓"
    println("\n  $num. $category_icon $(rec.issue)")
    println("     SUGGESTION: $(rec.suggestion)")
    if !isempty(rec.code_example)
        println("     EXAMPLE:")
        for line in split(rec.code_example, "\n")
            if !isempty(strip(line))
                println("       $line")
            end
        end
    end
    println("     IMPACT: $(rec.estimated_impact)")
end

"""
    quick_optimize(f, types, path, name)

One-command optimization that analyzes, recommends, and compiles
with the best settings for your function.

# Example
```julia
exe = quick_optimize(my_func, (Int,), "/tmp", "myapp")
```
"""
function quick_optimize(f, types, path::String, name::String; verbose=true)
    if verbose
        println("🔍 Analyzing function...")
    end

    # Get recommendations
    recs = recommend_optimizations(f, types, verbose=verbose)

    # Determine best profile based on analysis
    profile = if recs.overall_score >= 80
        if verbose
            println("\n✅ Code is well-optimized. Using PROFILE_SIZE for minimal binary.")
        end
        PROFILE_SIZE
    elseif any(r -> r.priority == :critical && r.category == :correctness, recs.recommendations)
        if verbose
            println("\n⚠️  Critical issues detected. Using PROFILE_DEBUG for easier debugging.")
        end
        PROFILE_DEBUG
    else
        if verbose
            println("\n⚙️  Using PROFILE_AGGRESSIVE for balanced optimization.")
        end
        PROFILE_AGGRESSIVE
    end

    if verbose
        println("\n🔨 Compiling...")
    end

    # Compile with chosen profile
    exe = compile_executable_optimized(f, types, path, name, profile=profile)

    if verbose
        final_size = filesize(exe) / 1024
        println("\n✅ Compilation complete!")
        println("   Binary: $exe")
        println("   Size: $(round(final_size, digits=1)) KB")
        println("   Profile: $(profile)")
    end

    return exe
end

export Recommendation, OptimizationRecommendations
export recommend_optimizations, quick_optimize
