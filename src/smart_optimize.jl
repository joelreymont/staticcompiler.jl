# Smart Optimization
# Automatically analyzes functions and chooses optimal compilation strategy

"""
    SmartOptimizationResult

Result of smart optimization analysis and compilation.

# Fields
- `function_name::String` - Function that was analyzed
- `analysis::ComprehensiveReport` - Complete static analysis
- `recommended_preset::Symbol` - Recommended optimization preset
- `chosen_strategy::String` - Explanation of chosen strategy
- `binary_path::Union{String, Nothing}` - Path to compiled binary
- `binary_size::Union{Int, Nothing}` - Size of compiled binary
- `performance::Union{BenchmarkResult, Nothing}` - Runtime performance
- `optimization_time_seconds::Float64` - Total time spent optimizing
- `improvements::Vector{String}` - List of improvements made
"""
struct SmartOptimizationResult
    function_name::String
    analysis::ComprehensiveReport
    recommended_preset::Symbol
    chosen_strategy::String
    binary_path::Union{String, Nothing}
    binary_size::Union{Int, Nothing}
    performance::Union{BenchmarkResult, Nothing}
    optimization_time_seconds::Float64
    improvements::Vector{String}
end

"""
    smart_optimize(f, types, output_path, name; args=nothing, target=:auto, verbose=true)

Automatically analyze a function and compile it with optimal settings.

This is the "easy button" for optimization - it analyzes your function,
chooses the best optimization strategy, and compiles it automatically.

# Arguments
- `f` - Function to optimize
- `types` - Type signature tuple
- `output_path` - Output directory
- `name` - Binary name
- `args` - Arguments for benchmarking (optional but recommended)
- `target` - Optimization target (:auto, :size, :speed, :balanced, or preset name)
- `verbose` - Print detailed progress

# Returns
- `SmartOptimizationResult` with complete optimization details

# Example
```julia
# Automatic optimization
result = smart_optimize(my_func, (Int,), "dist", "my_app", args=(100,))

# Force specific target
result = smart_optimize(my_func, (Int,), "dist", "my_app", target=:size)

# Use specific preset
result = smart_optimize(my_func, (Int,), "dist", "my_app", target=:embedded)
```
"""
function smart_optimize(f, types, output_path, name; args=nothing, target=:auto, verbose=true)
    start_time = time()

    if verbose
        println("\n" * "="^70)
        println("SMART OPTIMIZATION")
        println("="^70)
        println("Function: $(nameof(f))")
        println("Target: $target")
        println()
    end

    improvements = String[]

    # Step 1: Analyze the function
    if verbose
        println("📊 Analyzing function characteristics...")
    end

    analysis = generate_comprehensive_report(
        f, types,
        compile=false,
        benchmark=args !== nothing,
        benchmark_args=args,
        verbose=false
    )

    if verbose
        println("   Overall score: $(round(analysis.overall_score, digits=1))/100")
        println("   Performance score: $(round(analysis.performance_score, digits=1))/100")
        println("   Size score: $(round(analysis.size_score, digits=1))/100")
        println("   Security score: $(round(analysis.security_score, digits=1))/100")
    end

    # Step 2: Determine optimization strategy
    if verbose
        println("\n🎯 Determining optimization strategy...")
    end

    recommended_preset, strategy = if target == :auto
        choose_optimal_preset(analysis, args !== nothing, verbose)
    elseif target in [:size, :speed, :balanced]
        choose_preset_for_target(target, verbose)
    else
        # Assume it's a preset name
        preset = get_preset(target)
        if preset === nothing
            error("Unknown target: $target. Use :auto, :size, :speed, :balanced, or a preset name")
        end
        (target, "User-specified preset: $target")
    end

    if verbose
        println("   Recommended: $recommended_preset")
        println("   Strategy: $strategy")
    end

    # Step 3: Apply automatic improvements
    if verbose
        println("\n🔧 Applying automatic improvements...")
    end

    # Check for common issues and suggest fixes
    if analysis.allocations !== nothing && analysis.allocations.total_allocations > 0
        push!(improvements, "Detected $(analysis.allocations.total_allocations) allocations - " *
                           "consider removing for better performance")
        if verbose
            println("   ⚠️  Found allocations: $(analysis.allocations.total_allocations)")
        end
    end

    if analysis.inlining !== nothing && !isempty(analysis.inlining.not_inlined)
        push!(improvements, "Found $(length(analysis.inlining.not_inlined)) non-inlined calls - " *
                           "using aggressive optimization")
        if verbose
            println("   ℹ️  Non-inlined calls: $(length(analysis.inlining.not_inlined))")
        end
    end

    if analysis.simd !== nothing && !isempty(analysis.simd.missed_opportunities)
        push!(improvements, "Detected $(length(analysis.simd.missed_opportunities)) SIMD opportunities - " *
                           "using native optimizations")
        if verbose
            println("   ℹ️  SIMD opportunities: $(length(analysis.simd.missed_opportunities))")
        end
    end

    if analysis.security !== nothing && !isempty(analysis.security.critical_issues)
        push!(improvements, "Found $(length(analysis.security.critical_issues)) security issues - " *
                           "applying security hardening")
        if verbose
            println("   ⚠️  Security issues: $(length(analysis.security.critical_issues))")
        end
    end

    # Step 4: Compile with chosen preset
    if verbose
        println("\n🔨 Compiling with optimized settings...")
    end

    compilation_result = compile_with_preset(
        f, types, output_path, name,
        recommended_preset,
        args=args,
        verbose=verbose
    )

    # Step 5: Build result
    total_time = time() - start_time

    result = SmartOptimizationResult(
        string(nameof(f)),
        analysis,
        recommended_preset,
        strategy,
        get(compilation_result, "binary_path", nothing),
        get(compilation_result, "binary_size", nothing),
        args !== nothing && haskey(compilation_result, "benchmark") ?
            BenchmarkResult(
                string(nameof(f)),
                50, # Default samples
                0.0, # We don't have all fields, use what we have
                get(compilation_result["benchmark"], "median_time_ns", 0.0),
                get(compilation_result["benchmark"], "mean_time_ns", 0.0),
                0.0,
                get(compilation_result["benchmark"], "std_dev_ns", 0.0),
                0, 0, nothing,
                get(compilation_result, "binary_size", 0),
                Dates.now()
            ) : nothing,
        total_time,
        improvements
    )

    # Step 6: Print summary
    if verbose
        print_smart_optimization_summary(result)
    end

    return result
end

"""
    choose_optimal_preset(analysis::ComprehensiveReport, has_benchmark::Bool, verbose::Bool)

Automatically choose the best preset based on analysis results.
"""
function choose_optimal_preset(analysis::ComprehensiveReport, has_benchmark::Bool, verbose::Bool)
    # Decision matrix based on analysis

    # Check if function is allocation-heavy
    has_allocations = analysis.allocations !== nothing &&
                     analysis.allocations.total_allocations > 0

    # Check binary size from analysis
    estimated_size = analysis.binary_size_bytes !== nothing ?
                     analysis.binary_size_bytes :
                     0

    # Check if it's a small, simple function
    is_small_function = estimated_size < 50_000  # < 50KB

    # Check performance characteristics
    has_simd_opportunities = analysis.simd !== nothing &&
                            !isempty(analysis.simd.missed_opportunities)

    needs_performance = analysis.performance_score < 80.0

    # Check security requirements
    has_security_issues = analysis.security !== nothing &&
                         !isempty(analysis.security.critical_issues)

    # Decision logic
    if is_small_function && has_allocations
        # Small function with allocations - optimize for size
        return (:embedded, "Small function with allocations - minimizing size with aggressive compression")

    elseif needs_performance && has_simd_opportunities
        # Performance-critical with SIMD potential - use HPC
        return (:hpc, "Performance-critical function with SIMD opportunities - using HPC profile")

    elseif has_security_issues
        # Security issues present - use release profile with hardening
        return (:release, "Security issues detected - using release profile with hardening")

    elseif estimated_size > 100_000 && estimated_size < 500_000
        # Medium-sized binary - balance size and speed
        return (:serverless, "Medium-sized binary - balancing size and startup time")

    elseif estimated_size >= 500_000
        # Large binary - focus on performance since size is already large
        return (:hpc, "Large binary - focusing on performance optimization")

    elseif analysis.overall_score >= 90.0
        # Already excellent - use balanced desktop profile
        return (:desktop, "Already well-optimized - using balanced desktop profile")

    else
        # Default to balanced approach
        return (:desktop, "General-purpose function - using balanced desktop profile")
    end
end

"""
    choose_preset_for_target(target::Symbol, verbose::Bool)

Choose preset for a specific optimization target.
"""
function choose_preset_for_target(target::Symbol, verbose::Bool)
    if target == :size
        return (:embedded, "Size optimization - using EMBEDDED preset with UPX compression")
    elseif target == :speed
        return (:hpc, "Speed optimization - using HPC preset with PGO")
    elseif target == :balanced
        return (:desktop, "Balanced optimization - using DESKTOP preset")
    else
        return (:desktop, "Unknown target - defaulting to DESKTOP preset")
    end
end

"""
    print_smart_optimization_summary(result::SmartOptimizationResult)

Print summary of smart optimization results.
"""
function print_smart_optimization_summary(result::SmartOptimizationResult)
    println("\n" * "="^70)
    println("SMART OPTIMIZATION COMPLETE")
    println("="^70)
    println()

    println("Function: $(result.function_name)")
    println("Preset: $(uppercase(string(result.recommended_preset)))")
    println("Strategy: $(result.chosen_strategy)")
    println()

    if result.binary_path !== nothing
        println("Output:")
        println("   Binary: $(result.binary_path)")
        if result.binary_size !== nothing
            println("   Size: $(format_bytes(result.binary_size))")
        end
    end

    if result.performance !== nothing
        println("\nPerformance:")
        println("   Median: $(format_time(result.performance.median_time_ns))")
        println("   Mean: $(format_time(result.performance.mean_time_ns)) ± " *
               "$(format_time(result.performance.std_dev_ns))")
    end

    println("\nScores:")
    println("   Overall: $(round(result.analysis.overall_score, digits=1))/100")
    println("   Performance: $(round(result.analysis.performance_score, digits=1))/100")
    println("   Size: $(round(result.analysis.size_score, digits=1))/100")
    println("   Security: $(round(result.analysis.security_score, digits=1))/100")

    if !isempty(result.improvements)
        println("\nImprovements Applied:")
        for (i, improvement) in enumerate(result.improvements)
            println("   $i. $improvement")
        end
    end

    println("\nOptimization time: $(round(result.optimization_time_seconds, digits=2))s")
    println()

    # Provide recommendations
    if result.analysis.overall_score < 70.0
        println("💡 Suggestions for further improvement:")
        if result.analysis.allocations !== nothing &&
           result.analysis.allocations.total_allocations > 0
            println("   • Remove allocations for better performance")
        end
        if result.analysis.security !== nothing &&
           !isempty(result.analysis.security.warnings)
            println("   • Address security warnings")
        end
        if result.analysis.recommendations !== nothing &&
           !isempty(result.analysis.recommendations.recommendations)
            println("   • Review automated recommendations")
        end
        println()
    else
        println("✅ Excellent optimization achieved!")
        println()
    end
end

"""
    quick_compile(f, types, name="output"; args=nothing)

Ultra-simple one-liner for compilation with automatic optimization.

# Arguments
- `f` - Function to compile
- `types` - Type signature tuple
- `name` - Binary name (default: "output")
- `args` - Arguments for benchmarking (optional)

# Returns
- Path to compiled binary

# Example
```julia
# Simplest possible usage
binary = quick_compile(my_func, (Int,), "my_app", args=(100,))

# Just compile, no benchmarking
binary = quick_compile(my_func, (Int,), "my_app")
```
"""
function quick_compile(f, types, name="output"; args=nothing)
    result = smart_optimize(
        f, types,
        ".",  # Current directory
        name,
        args=args,
        verbose=false
    )

    if result.binary_path !== nothing
        println("✅ Compiled: $(result.binary_path)")
        println("   Size: $(format_bytes(result.binary_size))")
        println("   Score: $(round(result.analysis.overall_score, digits=1))/100")
        return result.binary_path
    else
        error("Compilation failed")
    end
end
