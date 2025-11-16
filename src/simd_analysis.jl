# SIMD and vectorization analysis

"""
SIMD vectorization report
"""
struct SIMDReport
    vectorized_loops::Int
    missed_opportunities::Vector{String}
    simd_instructions::Vector{String}
    suggestions::Vector{String}
    vectorization_score::Float64  # 0-100
end

"""
    analyze_simd(f, types; verbose=true)

Analyze SIMD vectorization opportunities in a function.

Detects:
- Vectorized loops in LLVM IR
- Missed vectorization opportunities
- SIMD instructions used
- Suggestions for improvement

# Example
```julia
function process_array(arr::Vector{Float64})
    result = 0.0
    for i in 1:length(arr)
        result += arr[i] * 2.0
    end
    return result
end

report = analyze_simd(process_array, (Vector{Float64},))
```
"""
function analyze_simd(f, types; verbose=true)
    vectorized = 0
    missed = String[]
    simd_insts = String[]
    suggestions = String[]

    try
        # Get LLVM IR
        mod = static_llvm_module(f, types)

        for func in LLVM.functions(mod)
            for bb in LLVM.blocks(func)
                for inst in LLVM.instructions(bb)
                    inst_str = string(inst)

                    # Detect SIMD instructions
                    if occursin(r"<\d+ x ", inst_str)  # Vector types like <4 x float>
                        vectorized += 1
                        # Extract instruction type
                        if occursin("fadd", inst_str)
                            push!(simd_insts, "Vector addition (SIMD)")
                        elseif occursin("fmul", inst_str)
                            push!(simd_insts, "Vector multiplication (SIMD)")
                        elseif occursin("load", inst_str)
                            push!(simd_insts, "Vector load (SIMD)")
                        else
                            push!(simd_insts, "SIMD operation: $(first(split(inst_str), 30))")
                        end
                    end

                    # Detect scalar operations that could be vectorized
                    if occursin("fadd", inst_str) && !occursin("<", inst_str)
                        # Scalar float add - potential vectorization opportunity
                        if !any(s -> occursin("scalar operations", s), missed)
                            push!(missed, "Scalar floating-point operations detected")
                        end
                    end

                    # Detect loops (phi nodes indicate loops)
                    if occursin("phi", inst_str) && !occursin("<", inst_str)
                        if !any(s -> occursin("loop", s), missed)
                            push!(missed, "Loop detected without SIMD vectorization")
                        end
                    end
                end
            end
        end

        # Generate suggestions
        if vectorized == 0 && !isempty(missed)
            push!(suggestions, "No SIMD vectorization detected. Consider using @simd or LoopVectorization.jl")
            push!(suggestions, "Ensure loops operate on contiguous arrays for auto-vectorization")
            push!(suggestions, "Use @inbounds to help the compiler vectorize")
        elseif vectorized > 0 && !isempty(missed)
            push!(suggestions, "Partial vectorization detected. Some loops could benefit from @simd")
        end

        if any(s -> occursin("scalar operations", s), missed)
            push!(suggestions, "Replace scalar operations with SIMD intrinsics for better performance")
        end

    catch e
        @debug "SIMD analysis failed" exception=e
    end

    # Remove duplicates
    unique!(simd_insts)
    unique!(missed)

    # Calculate score
    score = if vectorized > 0
        min(100.0, vectorized * 20.0)  # Each vectorized operation adds to score
    else
        isempty(missed) ? 100.0 : 0.0
    end

    report = SIMDReport(vectorized, missed, simd_insts, suggestions, score)

    if verbose
        print_simd_report(report)
    end

    return report
end

function print_simd_report(report::SIMDReport)
    println("\n" * "="^70)
    println("SIMD VECTORIZATION ANALYSIS")
    println("="^70)

    println("\n📊 VECTORIZATION SCORE: $(round(report.vectorization_score, digits=1))/100")

    if report.vectorized_loops > 0
        println("\n✅ VECTORIZED OPERATIONS: $(report.vectorized_loops)")
        if !isempty(report.simd_instructions)
            println("\nSIMD Instructions Found:")
            for (i, inst) in enumerate(unique(report.simd_instructions)[1:min(5, end)])
                println("  $i. $inst")
            end
            if length(report.simd_instructions) > 5
                println("  ... and $(length(report.simd_instructions) - 5) more")
            end
        end
    else
        println("\n⚠️  NO VECTORIZATION: No SIMD operations detected")
    end

    if !isempty(report.missed_opportunities)
        println("\n🔍 MISSED OPPORTUNITIES:")
        for (i, missed) in enumerate(report.missed_opportunities)
            println("  $i. $missed")
        end
    end

    if !isempty(report.suggestions)
        println("\n💡 SUGGESTIONS:")
        for (i, suggestion) in enumerate(report.suggestions)
            println("  $i. $suggestion")
        end

        println("\n📝 EXAMPLE:")
        println("""
        # Add @simd to loops:
        function optimized_loop(arr)
            result = 0.0
            @simd for i in 1:length(arr)
                @inbounds result += arr[i]
            end
            return result
        end

        # Or use LoopVectorization.jl:
        using LoopVectorization
        function super_fast(arr)
            result = 0.0
            @turbo for i in 1:length(arr)
                result += arr[i]
            end
            return result
        end
        """)
    else
        println("\n✅ Code is well-vectorized!")
    end

    println("="^70)
end

export SIMDReport, analyze_simd
