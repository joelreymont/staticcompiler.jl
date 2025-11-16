#!/usr/bin/env julia

# SIMD Vectorization Analysis Demo
# This example demonstrates how to analyze SIMD vectorization opportunities

using StaticCompiler

println("=== SIMD Vectorization Analysis Demo ===\n")

# Example 1: Non-vectorized loop
println("1️⃣  Non-vectorized loop:")
function scalar_sum(arr::Vector{Float64})
    result = 0.0
    for i in 1:length(arr)
        result += arr[i]
    end
    return result
end

report1 = analyze_simd(scalar_sum, (Vector{Float64},), verbose=false)
println("   Vectorization Score: $(round(report1.vectorization_score, digits=1))/100")
if !isempty(report1.missed_opportunities)
    println("   Issues: $(report1.missed_opportunities[1])")
end

# Example 2: SIMD-optimized loop
println("\n2️⃣  SIMD-optimized loop:")
function simd_sum(arr::Vector{Float64})
    result = 0.0
    @simd for i in 1:length(arr)
        @inbounds result += arr[i]
    end
    return result
end

report2 = analyze_simd(simd_sum, (Vector{Float64},), verbose=false)
println("   Vectorization Score: $(round(report2.vectorization_score, digits=1))/100")
if !isempty(report2.simd_instructions)
    println("   SIMD Instructions: $(length(report2.simd_instructions))")
end

# Example 3: Complex computation
println("\n3️⃣  Vector computation:")
function vector_compute(a::Vector{Float64}, b::Vector{Float64})
    result = similar(a)
    @simd for i in 1:length(a)
        @inbounds result[i] = a[i] * b[i] + 2.0 * a[i]
    end
    return result
end

report3 = analyze_simd(vector_compute, (Vector{Float64}, Vector{Float64}), verbose=false)
println("   Vectorization Score: $(round(report3.vectorization_score, digits=1))/100")
if !isempty(report3.simd_instructions)
    println("   SIMD Instructions Found:")
    for (i, inst) in enumerate(unique(report3.simd_instructions)[1:min(3, end)])
        println("      - $inst")
    end
end

# Summary
println("\n📊 Summary:")
println("   Scalar loop:  $(round(report1.vectorization_score, digits=1))/100")
println("   SIMD loop:    $(round(report2.vectorization_score, digits=1))/100")
println("   Vector ops:   $(round(report3.vectorization_score, digits=1))/100")

println("\n💡 Tip: Use @simd and @inbounds annotations to enable auto-vectorization")
println("   For maximum performance, consider using LoopVectorization.jl")
