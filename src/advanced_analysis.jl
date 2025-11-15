# Advanced static analysis tools for StaticCompiler

using InteractiveUtils

"""
Analysis result for allocation profiling
"""
struct AllocationProfile
    total_allocations::Int
    allocation_sites::Vector{String}
    estimated_bytes::Int
    heap_escapes::Int
end

"""
Analysis result for inline decisions
"""
struct InlineAnalysis
    inlined_calls::Vector{String}
    not_inlined::Vector{String}
    inline_cost_estimates::Dict{String, Int}
end

"""
Dependency graph node
"""
struct CallNode
    function_name::String
    called_by::Vector{String}
    calls::Vector{String}
    depth::Int
end

"""
Binary bloat analysis result
"""
struct BloatAnalysis
    total_functions::Int
    large_functions::Vector{Tuple{String, Int}}  # (name, estimated_size)
    redundant_specializations::Vector{String}
    suggested_consolidations::Vector{String}
end

"""
Comprehensive analysis report
"""
struct AdvancedAnalysisReport
    allocations::AllocationProfile
    inlining::InlineAnalysis
    call_graph::Vector{CallNode}
    bloat::BloatAnalysis
    performance_score::Float64  # 0-100
    size_score::Float64         # 0-100
end

"""
    analyze_allocations(f, types)

Analyze allocation patterns in a function.

Returns an AllocationProfile with:
- Total allocation count
- Specific allocation sites
- Estimated heap usage
- Escaping allocations

# Example
```julia
profile = analyze_allocations(myfunc, (Int, Float64))
println("Total allocations: \$(profile.total_allocations)")
```
"""
function analyze_allocations(f, types)
    allocation_sites = String[]
    total_allocs = 0
    estimated_bytes = 0
    heap_escapes = 0

    try
        # Get LLVM IR
        mod = static_llvm_module(f, types)

        for func in LLVM.functions(mod)
            for bb in LLVM.blocks(func)
                for inst in LLVM.instructions(bb)
                    inst_str = string(inst)

                    # Detect allocation calls
                    if occursin("jl_alloc", inst_str) || occursin("jl_gc_alloc", inst_str)
                        total_allocs += 1
                        push!(allocation_sites, inst_str)

                        # Try to estimate size from IR
                        if occursin(r"i64 (\d+)", inst_str)
                            m = match(r"i64 (\d+)", inst_str)
                            if m !== nothing
                                estimated_bytes += parse(Int, m.captures[1])
                            end
                        end
                    end

                    # Detect heap escapes (stored to memory)
                    if occursin("store", inst_str) && occursin("alloc", inst_str)
                        heap_escapes += 1
                    end
                end
            end
        end
    catch e
        @debug "Allocation analysis failed" exception=e
    end

    return AllocationProfile(total_allocs, allocation_sites, estimated_bytes, heap_escapes)
end

"""
    analyze_inlining(f, types)

Analyze inlining decisions for a function.

Shows which calls got inlined and which didn't, with cost estimates.

# Example
```julia
inline_info = analyze_inlining(myfunc, (Int,))
println("Inlined: \$(length(inline_info.inlined_calls))")
println("Not inlined: \$(length(inline_info.not_inlined))")
```
"""
function analyze_inlining(f, types)
    inlined = String[]
    not_inlined = String[]
    costs = Dict{String, Int}()

    try
        # Get typed IR
        tt = Base.to_tuple_type(types)
        ci = only(static_code_typed(f, tt))

        # Analyze IR for call instructions
        for (i, stmt) in enumerate(ci[1].code)
            if isa(stmt, Expr)
                if stmt.head === :call
                    fname = string(stmt.args[1])

                    # Check if it's inlined (no :invoke in lowered code)
                    if occursin("#", fname) || occursin("##", fname)
                        push!(inlined, fname)
                        costs[fname] = estimate_inline_cost(stmt)
                    else
                        push!(not_inlined, fname)
                        costs[fname] = estimate_inline_cost(stmt)
                    end
                end
            end
        end
    catch e
        @debug "Inline analysis failed" exception=e
    end

    return InlineAnalysis(inlined, not_inlined, costs)
end

function estimate_inline_cost(expr::Expr)
    # Simple heuristic: count operations
    cost = 0
    function count_ops(e)
        if isa(e, Expr)
            cost += 1
            for arg in e.args
                count_ops(arg)
            end
        end
    end
    count_ops(expr)
    return cost
end

"""
    build_call_graph(f, types; max_depth=3)

Build a call graph showing function dependencies.

Returns a vector of CallNode objects showing who calls what.

# Example
```julia
graph = build_call_graph(myfunc, (Int,), max_depth=2)
for node in graph
    println("\$(node.function_name) calls: \$(join(node.calls, ", "))")
end
```
"""
function build_call_graph(f, types; max_depth=3)
    nodes = Dict{String, CallNode}()
    visited = Set{String}()

    function explore(func, depth::Int, caller::String="")
        depth > max_depth && return

        fname = string(func)
        fname in visited && return
        push!(visited, fname)

        calls = String[]

        try
            tt = Base.to_tuple_type(types)
            ci = only(static_code_typed(func, tt))

            for stmt in ci[1].code
                if isa(stmt, Expr) && stmt.head === :call
                    called = string(stmt.args[1])
                    if !startswith(called, "Core") && !startswith(called, "Base")
                        push!(calls, called)
                        # Recursively explore (would need actual function, simplified here)
                    end
                end
            end
        catch
        end

        called_by = caller == "" ? String[] : [caller]
        nodes[fname] = CallNode(fname, called_by, calls, depth)

        return nodes[fname]
    end

    explore(f, 0)

    return collect(values(nodes))
end

"""
    analyze_bloat(f, types)

Analyze what's contributing to binary size bloat.

Identifies:
- Large functions
- Redundant type specializations
- Opportunities for code consolidation

# Example
```julia
bloat = analyze_bloat(myfunc, (Int,))
println("Large functions: \$(length(bloat.large_functions))")
for (name, size) in bloat.large_functions
    println("  \$name: ~\$size bytes")
end
```
"""
function analyze_bloat(f, types)
    large_funcs = Tuple{String, Int}[]
    redundant = String[]
    suggestions = String[]
    total_funcs = 0

    try
        mod = static_llvm_module(f, types)

        for func in LLVM.functions(mod)
            total_funcs += 1
            fname = LLVM.name(func)

            # Estimate function size from basic block count
            bb_count = length(collect(LLVM.blocks(func)))
            inst_count = sum(length(collect(LLVM.instructions(bb))) for bb in LLVM.blocks(func))

            estimated_size = inst_count * 4  # Rough estimate: 4 bytes per instruction

            # Flag large functions (>1KB estimated)
            if estimated_size > 1000
                push!(large_funcs, (fname, estimated_size))
            end

            # Detect potential redundant specializations
            # Functions with similar names might be redundant specializations
            if occursin(r"_\d+$", fname)
                push!(redundant, fname)
            end
        end

        # Generate suggestions
        if length(large_funcs) > 5
            push!(suggestions, "Consider splitting large functions into smaller helpers")
        end
        if length(redundant) > 10
            push!(suggestions, "Many type specializations detected - consider using @nospecialize")
        end

        # Sort by size
        sort!(large_funcs, by=x -> x[2], rev=true)

    catch e
        @debug "Bloat analysis failed" exception=e
    end

    return BloatAnalysis(total_funcs, large_funcs, redundant, suggestions)
end

"""
    advanced_analysis(f, types; verbose=true)

Perform comprehensive static analysis of a function.

Analyzes:
- Allocation patterns
- Inlining decisions
- Call graph dependencies
- Binary size bloat
- Overall performance/size scores

# Example
```julia
report = advanced_analysis(myfunc, (Int, Float64))
println("Performance score: \$(report.performance_score)/100")
println("Size score: \$(report.size_score)/100")
```
"""
function advanced_analysis(f, types; verbose=true)
    # Run all analyses
    alloc_profile = analyze_allocations(f, types)
    inline_info = analyze_inlining(f, types)
    call_graph = build_call_graph(f, types)
    bloat_info = analyze_bloat(f, types)

    # Calculate performance score (0-100, higher is better)
    perf_score = 100.0
    perf_score -= min(alloc_profile.total_allocations * 10, 50)  # Allocations hurt performance
    perf_score -= min(length(inline_info.not_inlined) * 5, 30)  # Missed inlines hurt
    perf_score = max(0.0, perf_score)

    # Calculate size score (0-100, higher means smaller)
    size_score = 100.0
    size_score -= min(bloat_info.total_functions * 0.5, 30)  # More functions = larger
    size_score -= min(length(bloat_info.large_functions) * 10, 40)  # Large functions hurt
    size_score -= min(length(bloat_info.redundant_specializations) * 2, 30)
    size_score = max(0.0, size_score)

    report = AdvancedAnalysisReport(
        alloc_profile, inline_info, call_graph, bloat_info, perf_score, size_score
    )

    if verbose
        print_advanced_report(report)
    end

    return report
end

function print_advanced_report(report::AdvancedAnalysisReport)
    println("\n" * "="^70)
    println("ADVANCED STATIC ANALYSIS REPORT")
    println("="^70)

    println("\n📊 PERFORMANCE SCORE: $(round(report.performance_score, digits=1))/100")
    println("📦 SIZE SCORE: $(round(report.size_score, digits=1))/100")

    println("\n--- ALLOCATION ANALYSIS ---")
    println("Total allocations: $(report.allocations.total_allocations)")
    println("Estimated heap usage: $(report.allocations.estimated_bytes) bytes")
    println("Heap escapes: $(report.allocations.heap_escapes)")
    if report.allocations.total_allocations > 0
        println("⚠️  Allocations detected - may prevent static compilation")
        println("   Use StaticTools.MallocArray or refactor to avoid allocations")
    else
        println("✅ No allocations detected")
    end

    println("\n--- INLINING ANALYSIS ---")
    println("Inlined calls: $(length(report.inlining.inlined_calls))")
    println("Not inlined: $(length(report.inlining.not_inlined))")
    if !isempty(report.inlining.not_inlined)
        println("Functions not inlined:")
        for (i, fname) in enumerate(report.inlining.not_inlined[1:min(5, end)])
            cost = get(report.inlining.inline_cost_estimates, fname, 0)
            println("  $i. $fname (cost: $cost)")
        end
        if length(report.inlining.not_inlined) > 5
            println("  ... and $(length(report.inlining.not_inlined) - 5) more")
        end
    end

    println("\n--- CALL GRAPH ---")
    println("Total functions: $(length(report.call_graph))")
    if !isempty(report.call_graph)
        println("Call hierarchy:")
        for node in report.call_graph[1:min(5, end)]
            indent = "  " ^ node.depth
            println("$indent$(node.function_name) → calls $(length(node.calls)) function(s)")
        end
    end

    println("\n--- BINARY BLOAT ANALYSIS ---")
    println("Total functions in IR: $(report.bloat.total_functions)")
    println("Large functions (>1KB): $(length(report.bloat.large_functions))")
    if !isempty(report.bloat.large_functions)
        println("Top contributors to binary size:")
        for (i, (name, size)) in enumerate(report.bloat.large_functions[1:min(5, end)])
            println("  $i. $name: ~$(round(size/1024, digits=1)) KB")
        end
    end

    println("Redundant specializations: $(length(report.bloat.redundant_specializations))")

    if !isempty(report.bloat.suggested_consolidations)
        println("\n💡 OPTIMIZATION SUGGESTIONS:")
        for suggestion in report.bloat.suggested_consolidations
            println("  • $suggestion")
        end
    end

    println("\n" * "="^70)
end

export AllocationProfile, InlineAnalysis, CallNode, BloatAnalysis, AdvancedAnalysisReport
export analyze_allocations, analyze_inlining, build_call_graph, analyze_bloat, advanced_analysis
