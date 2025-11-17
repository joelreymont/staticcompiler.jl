using Test
using StaticCompiler
using Libdl
using LinearAlgebra
using LoopVectorization
using ManualMemory
using Distributed
using StaticTools
using StrideArraysCore
using MacroTools
using LLD_jll
using Bumper

addprocs(1)
@everywhere using StaticCompiler, StrideArraysCore

const GROUP = get(ENV, "GROUP", "All")

if GROUP == "Core" || GROUP == "All"
    include("testcore.jl")
end

if GROUP == "Integration" || GROUP == "All"
    include("testintegration.jl")
end

# Advanced Compiler Optimizations Tests
if GROUP == "Optimizations" || GROUP == "All"
    println("\n" * "="^70)
    println("Running Advanced Optimization Tests")
    println("="^70)

    include("test_advanced_optimizations.jl")
    include("test_optimization_edge_cases.jl")
    include("test_correctness_verification.jl")

    println("\n" * "="^70)
    println("Running Optimization Benchmarks")
    println("="^70)
    include("test_optimization_benchmarks.jl")

    # Generate coverage report
    include("test_coverage_report.jl")
    coverage = generate_coverage_report()
end
