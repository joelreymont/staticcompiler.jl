#!/usr/bin/env julia

# Smart Optimization Demo
# The "easy button" for optimal compilation

using StaticCompiler

println("=== Smart Optimization Demo ===\n")
println("Automatically analyze and optimize functions with one command!\n")

# Example functions to optimize
function calculate_sum(n::Int)
    total = 0
    for i in 1:n
        total += i
    end
    return total
end

function matrix_multiply(n::Int)
    result = 0.0
    for i in 1:n
        for j in 1:n
            result += i * j * 0.5
        end
    end
    return Int(floor(result))
end

# 1. Simplest usage - automatic everything
println("1. Ultra-simple compilation with quick_compile():\n")

try
    binary = quick_compile(calculate_sum, (Int,), "sum_app", args=(1000,))
    println()
catch e
    println("   Skipped: $e\n")
end

# 2. Smart optimization with automatic strategy selection
println("2. Smart optimization (automatic strategy):\n")

output_dir = mktempdir()
try
    result = smart_optimize(
        calculate_sum,
        (Int,),
        output_dir,
        "sum_optimized",
        args=(1000,),
        target=:auto,
        verbose=false
    )

    println("   Function: $(result.function_name)")
    println("   Chosen preset: $(uppercase(string(result.recommended_preset)))")
    println("   Strategy: $(result.chosen_strategy)")
    if result.binary_size !== nothing
        println("   Binary size: $(format_bytes(result.binary_size))")
    end
    if result.performance !== nothing
        println("   Performance: $(format_time(result.performance.median_time_ns))")
    end
    println("   Overall score: $(round(result.analysis.overall_score, digits=1))/100")
    println("   Optimization time: $(round(result.optimization_time_seconds, digits=2))s")

    if !isempty(result.improvements)
        println("\n   Improvements applied:")
        for improvement in result.improvements
            println("      • $improvement")
        end
    end
    println()
catch e
    println("   Skipped: $e\n")
finally
    rm(output_dir, recursive=true, force=true)
end

# 3. Smart optimization targeting specific goal
println("3. Smart optimization (size target):\n")

output_dir = mktempdir()
try
    result = smart_optimize(
        matrix_multiply,
        (Int,),
        output_dir,
        "matrix_size",
        args=(50,),
        target=:size,
        verbose=false
    )

    println("   Target: SIZE")
    println("   Chosen preset: $(uppercase(string(result.recommended_preset)))")
    if result.binary_size !== nothing
        println("   Binary size: $(format_bytes(result.binary_size))")
    end
    println("   Size score: $(round(result.analysis.size_score, digits=1))/100")
    println()
catch e
    println("   Skipped: $e\n")
finally
    rm(output_dir, recursive=true, force=true)
end

# 4. Smart optimization targeting performance
println("4. Smart optimization (speed target):\n")

output_dir = mktempdir()
try
    result = smart_optimize(
        matrix_multiply,
        (Int,),
        output_dir,
        "matrix_speed",
        args=(50,),
        target=:speed,
        verbose=false
    )

    println("   Target: SPEED")
    println("   Chosen preset: $(uppercase(string(result.recommended_preset)))")
    if result.performance !== nothing
        println("   Performance: $(format_time(result.performance.median_time_ns))")
    end
    println("   Performance score: $(round(result.analysis.performance_score, digits=1))/100")
    println()
catch e
    println("   Skipped: $e\n")
finally
    rm(output_dir, recursive=true, force=true)
end

# 5. Smart optimization with specific preset
println("5. Smart optimization (specific preset):\n")

output_dir = mktempdir()
try
    result = smart_optimize(
        calculate_sum,
        (Int,),
        output_dir,
        "sum_embedded",
        args=(1000,),
        target=:embedded,  # Force specific preset
        verbose=false
    )

    println("   Forced preset: EMBEDDED")
    println("   Strategy: $(result.chosen_strategy)")
    if result.binary_size !== nothing
        println("   Binary size: $(format_bytes(result.binary_size))")
    end
    println()
catch e
    println("   Skipped: $e\n")
finally
    rm(output_dir, recursive=true, force=true)
end

# 6. Full verbose smart optimization
println("6. Full verbose smart optimization:\n")
println("="^70)

output_dir = mktempdir()
try
    result = smart_optimize(
        matrix_multiply,
        (Int,),
        output_dir,
        "matrix_full",
        args=(30,),
        target=:auto,
        verbose=true
    )
catch e
    println("Skipped: $e")
finally
    rm(output_dir, recursive=true, force=true)
end

# Summary
println("\n" * "="^70)
println("SMART OPTIMIZATION SUMMARY")
println("="^70)
println()
println("Smart optimization provides three levels of simplicity:")
println()
println("1️⃣  ULTRA-SIMPLE: quick_compile()")
println("   binary = quick_compile(func, (Int,), \"app\", args=(100,))")
println("   → One line, automatic optimization, returns binary path")
println()
println("2️⃣  AUTOMATIC: smart_optimize() with :auto target")
println("   result = smart_optimize(func, (Int,), \"dist\", \"app\", args=(100,))")
println("   → Analyzes function, chooses best preset, returns full results")
println()
println("3️⃣  GUIDED: smart_optimize() with specific target")
println("   result = smart_optimize(func, (Int,), \"dist\", \"app\", target=:size)")
println("   → Uses specified optimization goal (size, speed, balanced)")
println()
println("Available targets:")
println("   • :auto      - Automatic selection (recommended)")
println("   • :size      - Optimize for binary size")
println("   • :speed     - Optimize for performance")
println("   • :balanced  - Balance size and speed")
println("   • :embedded, :serverless, :hpc, :desktop, :development, :release")
println()
println("What smart_optimize does automatically:")
println("   ✓ Analyzes function characteristics")
println("   ✓ Detects allocations, inlining, SIMD opportunities")
println("   ✓ Checks security issues")
println("   ✓ Chooses optimal compilation strategy")
println("   ✓ Applies appropriate preset")
println("   ✓ Runs benchmarks if arguments provided")
println("   ✓ Generates comprehensive report")
println("   ✓ Provides improvement suggestions")
println()
println("Perfect for:")
println("   • Quick prototyping")
println("   • Getting started with optimization")
println("   • When you want good results without deep knowledge")
println("   • Automated build scripts")
println("   • CI/CD pipelines")
println()
