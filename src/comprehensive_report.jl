# Comprehensive compilation reporting
# Combines all analysis tools into unified reports with export capabilities

using Dates

"""
Comprehensive compilation report combining all analyses
"""
struct ComprehensiveReport
    timestamp::DateTime
    function_name::String
    type_signature::String

    # Binary info
    binary_path::Union{String, Nothing}
    binary_size_bytes::Union{Int, Nothing}

    # Analysis results
    allocations::Union{AllocationProfile, Nothing}
    inlining::Union{InlineAnalysis, Nothing}
    bloat::Union{BloatAnalysis, Nothing}
    simd::Union{SIMDReport, Nothing}
    security::Union{SecurityReport, Nothing}
    memory_layout::Union{MemoryLayoutReport, Nothing}
    dependencies::Union{DependencyReport, Nothing}
    recommendations::Union{OptimizationRecommendations, Nothing}

    # Overall scores
    overall_score::Float64  # 0-100
    performance_score::Float64  # 0-100
    size_score::Float64  # 0-100
    security_score::Float64  # 0-100

    # Compilation metrics
    compilation_time_ms::Union{Float64, Nothing}
    cache_hit::Union{Bool, Nothing}
end

"""
    generate_comprehensive_report(f, types; compile=false, path=tempdir(), name="output", verbose=true)

Generate a comprehensive report combining all available analyses.

# Arguments
- `f`: Function to analyze
- `types`: Type signature tuple
- `compile`: If true, actually compile the binary
- `path`: Output path for binary
- `name`: Binary name
- `verbose`: Print progress

# Example
```julia
function my_func(x::Int)
    return x * x + 2
end

report = generate_comprehensive_report(my_func, (Int,), compile=true)
```
"""
function generate_comprehensive_report(f, types; compile=false, path=tempdir(), name="output", verbose=true)
    if verbose
        println("\n" * "="^70)
        println("GENERATING COMPREHENSIVE REPORT")
        println("="^70)
    end

    func_name = string(nameof(f))
    type_sig = string(types)
    binary_path = nothing
    binary_size = nothing
    compilation_time = nothing
    cache_hit = nothing

    # Run all analyses
    if verbose
        println("\n📊 Running analyses...")
    end

    # 1. Allocation analysis
    alloc_report = try
        if verbose print("   • Allocations... ") end
        r = analyze_allocations(f, types, verbose=false)
        if verbose println("✓") end
        r
    catch e
        if verbose println("✗") end
        nothing
    end

    # 2. Inlining analysis
    inline_report = try
        if verbose print("   • Inlining... ") end
        r = analyze_inlining(f, types, verbose=false)
        if verbose println("✓") end
        r
    catch e
        if verbose println("✗") end
        nothing
    end

    # 3. Bloat analysis
    bloat_report = try
        if verbose print("   • Binary bloat... ") end
        r = analyze_bloat(f, types, verbose=false)
        if verbose println("✓") end
        r
    catch e
        if verbose println("✗") end
        nothing
    end

    # 4. SIMD analysis
    simd_report = try
        if verbose print("   • SIMD vectorization... ") end
        r = analyze_simd(f, types, verbose=false)
        if verbose println("✓") end
        r
    catch e
        if verbose println("✗") end
        nothing
    end

    # 5. Security analysis
    security_report = try
        if verbose print("   • Security... ") end
        r = analyze_security(f, types, verbose=false)
        if verbose println("✓") end
        r
    catch e
        if verbose println("✗") end
        nothing
    end

    # 6. Dependency analysis
    dependency_report = try
        if verbose print("   • Dependencies... ") end
        r = analyze_dependency_bloat(f, types, verbose=false)
        if verbose println("✓") end
        r
    catch e
        if verbose println("✗") end
        nothing
    end

    # 7. Recommendations
    recommendation_report = try
        if verbose print("   • Recommendations... ") end
        r = recommend_optimizations(f, types, verbose=false)
        if verbose println("✓") end
        r
    catch e
        if verbose println("✗") end
        nothing
    end

    # 8. Compile if requested
    if compile
        if verbose
            println("\n🔨 Compiling binary...")
        end

        try
            start_time = time()
            binary_path = compile_executable(f, types, path, name)
            compilation_time = (time() - start_time) * 1000  # ms

            if isfile(binary_path)
                binary_size = filesize(binary_path)
                if verbose
                    println("   ✓ Compiled: $binary_path")
                    println("   Size: $(round(binary_size/1024, digits=1)) KB")
                    println("   Time: $(round(compilation_time, digits=1)) ms")
                end
            end
        catch e
            if verbose
                println("   ✗ Compilation failed: $e")
            end
        end
    end

    # Calculate overall scores
    perf_score = _calculate_performance_score(alloc_report, inline_report, simd_report)
    size_score = _calculate_size_score(bloat_report, dependency_report, binary_size)
    sec_score = security_report !== nothing ? security_report.security_score : 100.0
    overall = (perf_score + size_score + sec_score) / 3.0

    report = ComprehensiveReport(
        now(),
        func_name,
        type_sig,
        binary_path,
        binary_size,
        alloc_report,
        inline_report,
        bloat_report,
        simd_report,
        security_report,
        nothing,  # memory_layout not applicable for functions
        dependency_report,
        recommendation_report,
        overall,
        perf_score,
        size_score,
        sec_score,
        compilation_time,
        cache_hit
    )

    if verbose
        print_comprehensive_report(report)
    end

    return report
end

"""
Calculate performance score from various analyses
"""
function _calculate_performance_score(alloc, inline, simd)
    scores = Float64[]

    # Allocation score (0 allocations = 100)
    if alloc !== nothing
        alloc_score = alloc.total_allocations == 0 ? 100.0 : max(0.0, 100.0 - alloc.total_allocations * 10.0)
        push!(scores, alloc_score)
    end

    # Inlining score
    if inline !== nothing
        total = length(inline.inlined_calls) + length(inline.not_inlined)
        inline_score = total > 0 ? (length(inline.inlined_calls) / total) * 100.0 : 100.0
        push!(scores, inline_score)
    end

    # SIMD score
    if simd !== nothing
        push!(scores, simd.vectorization_score)
    end

    return isempty(scores) ? 50.0 : sum(scores) / length(scores)
end

"""
Calculate size score from bloat and dependency analyses
"""
function _calculate_size_score(bloat, deps, binary_size)
    scores = Float64[]

    # Bloat score (inverted - lower bloat = higher score)
    if bloat !== nothing
        # Normalize: 0-50 functions = 100-50 score
        func_score = max(0.0, 100.0 - bloat.total_functions)
        push!(scores, func_score)
    end

    # Dependency score (inverted)
    if deps !== nothing
        dep_score = max(0.0, 100.0 - deps.bloat_score)
        push!(scores, dep_score)
    end

    # Binary size score (smaller = better)
    if binary_size !== nothing
        # 10 KB = 100, 100 KB = 50, 1 MB = 0
        size_kb = binary_size / 1024
        size_score = max(0.0, min(100.0, 110.0 - size_kb / 10.0))
        push!(scores, size_score)
    end

    return isempty(scores) ? 50.0 : sum(scores) / length(scores)
end

"""
Print comprehensive report to console
"""
function print_comprehensive_report(report::ComprehensiveReport)
    println("\n" * "="^70)
    println("COMPREHENSIVE COMPILATION REPORT")
    println("="^70)

    println("\n📋 SUMMARY")
    println("   Function: $(report.function_name)")
    println("   Signature: $(report.type_signature)")
    println("   Generated: $(Dates.format(report.timestamp, "yyyy-mm-dd HH:MM:SS"))")

    if report.binary_path !== nothing
        println("\n💾 BINARY")
        println("   Path: $(report.binary_path)")
        if report.binary_size_bytes !== nothing
            size_kb = round(report.binary_size_bytes / 1024, digits=1)
            println("   Size: $size_kb KB")
        end
        if report.compilation_time_ms !== nothing
            println("   Compilation Time: $(round(report.compilation_time_ms, digits=1)) ms")
        end
    end

    println("\n🎯 OVERALL SCORES")
    println("   Overall:     $(round(report.overall_score, digits=1))/100")
    println("   Performance: $(round(report.performance_score, digits=1))/100")
    println("   Size:        $(round(report.size_score, digits=1))/100")
    println("   Security:    $(round(report.security_score, digits=1))/100")

    # Print key findings
    if report.allocations !== nothing && report.allocations.total_allocations > 0
        println("\n⚠️  ALLOCATIONS: $(report.allocations.total_allocations) detected")
    end

    if report.simd !== nothing && report.simd.vectorization_score < 50
        println("⚠️  SIMD: Low vectorization ($(round(report.simd.vectorization_score, digits=1))/100)")
    end

    if report.security !== nothing && !isempty(report.security.critical_issues)
        println("❌ SECURITY: $(length(report.security.critical_issues)) critical issues!")
    end

    if report.dependencies !== nothing && report.dependencies.bloat_score > 60
        println("⚠️  DEPENDENCIES: High bloat score ($(round(report.dependencies.bloat_score, digits=1))/100)")
    end

    # Top recommendations
    if report.recommendations !== nothing && !isempty(report.recommendations.recommendations)
        println("\n💡 TOP RECOMMENDATIONS:")
        critical = filter(r -> r.priority == :critical, report.recommendations.recommendations)
        high = filter(r -> r.priority == :high, report.recommendations.recommendations)

        for (i, rec) in enumerate(vcat(critical, high)[1:min(3, length(critical) + length(high))])
            println("   $(i). [$(uppercase(string(rec.priority)))] $(rec.issue)")
        end
    end

    println("="^70)
end

"""
    export_report_json(report::ComprehensiveReport, filepath::String)

Export report to JSON format.
"""
function export_report_json(report::ComprehensiveReport, filepath::String)
    data = Dict(
        "timestamp" => string(report.timestamp),
        "function_name" => report.function_name,
        "type_signature" => report.type_signature,
        "binary_path" => report.binary_path,
        "binary_size_bytes" => report.binary_size_bytes,
        "compilation_time_ms" => report.compilation_time_ms,
        "scores" => Dict(
            "overall" => report.overall_score,
            "performance" => report.performance_score,
            "size" => report.size_score,
            "security" => report.security_score
        ),
        "allocations" => report.allocations !== nothing ? Dict(
            "total" => report.allocations.total_allocations,
            "bytes" => report.allocations.estimated_bytes
        ) : nothing,
        "simd" => report.simd !== nothing ? Dict(
            "score" => report.simd.vectorization_score,
            "vectorized" => report.simd.vectorized_loops
        ) : nothing,
        "security" => report.security !== nothing ? Dict(
            "score" => report.security.security_score,
            "critical_issues" => length(report.security.critical_issues),
            "warnings" => length(report.security.warnings)
        ) : nothing,
        "dependencies" => report.dependencies !== nothing ? Dict(
            "bloat_score" => report.dependencies.bloat_score,
            "total_functions" => report.dependencies.total_functions,
            "modules" => length(report.dependencies.unique_modules)
        ) : nothing
    )

    # Simple JSON-like output without JSON dependency
    open(filepath, "w") do io
        _write_simple_json(io, data, 0)
    end

    println("✅ JSON report exported to: $filepath")
end

# Simple JSON writer (no external dependencies)
function _write_simple_json(io::IO, data, indent::Int)
    prefix = "  "^indent

    if data === nothing
        print(io, "null")
    elseif isa(data, Dict)
        println(io, "{")
        keys_list = collect(keys(data))
        for (i, key) in enumerate(keys_list)
            print(io, prefix, "  \"", key, "\": ")
            _write_simple_json(io, data[key], indent + 1)
            if i < length(keys_list)
                println(io, ",")
            else
                println(io)
            end
        end
        print(io, prefix, "}")
    elseif isa(data, String)
        print(io, "\"", data, "\"")
    elseif isa(data, Number)
        print(io, data)
    elseif isa(data, Bool)
        print(io, data ? "true" : "false")
    else
        print(io, "\"", string(data), "\"")
    end
end

"""
    export_report_markdown(report::ComprehensiveReport, filepath::String)

Export report to Markdown format.
"""
function export_report_markdown(report::ComprehensiveReport, filepath::String)
    io = IOBuffer()

    println(io, "# Compilation Report")
    println(io, "")
    println(io, "**Function:** `$(report.function_name)`  ")
    println(io, "**Signature:** `$(report.type_signature)`  ")
    println(io, "**Generated:** $(Dates.format(report.timestamp, "yyyy-mm-dd HH:MM:SS"))  ")
    println(io, "")

    if report.binary_path !== nothing
        println(io, "## Binary Information")
        println(io, "")
        println(io, "- **Path:** `$(report.binary_path)`")
        if report.binary_size_bytes !== nothing
            size_kb = round(report.binary_size_bytes / 1024, digits=1)
            println(io, "- **Size:** $(size_kb) KB")
        end
        if report.compilation_time_ms !== nothing
            println(io, "- **Compilation Time:** $(round(report.compilation_time_ms, digits=1)) ms")
        end
        println(io, "")
    end

    println(io, "## Scores")
    println(io, "")
    println(io, "| Metric | Score |")
    println(io, "|--------|-------|")
    println(io, "| Overall | $(round(report.overall_score, digits=1))/100 |")
    println(io, "| Performance | $(round(report.performance_score, digits=1))/100 |")
    println(io, "| Size | $(round(report.size_score, digits=1))/100 |")
    println(io, "| Security | $(round(report.security_score, digits=1))/100 |")
    println(io, "")

    # Analysis results
    if report.allocations !== nothing
        println(io, "## Allocations")
        println(io, "")
        println(io, "- Total: $(report.allocations.total_allocations)")
        println(io, "- Estimated Bytes: $(report.allocations.estimated_bytes)")
        println(io, "")
    end

    if report.simd !== nothing
        println(io, "## SIMD Vectorization")
        println(io, "")
        println(io, "- Score: $(round(report.simd.vectorization_score, digits=1))/100")
        println(io, "- Vectorized Operations: $(report.simd.vectorized_loops)")
        println(io, "- Missed Opportunities: $(length(report.simd.missed_opportunities))")
        println(io, "")
    end

    if report.security !== nothing
        println(io, "## Security")
        println(io, "")
        println(io, "- Score: $(round(report.security.security_score, digits=1))/100")
        println(io, "- Critical Issues: $(length(report.security.critical_issues))")
        println(io, "- Warnings: $(length(report.security.warnings))")
        println(io, "")
    end

    if report.recommendations !== nothing && !isempty(report.recommendations.recommendations)
        println(io, "## Recommendations")
        println(io, "")
        for rec in report.recommendations.recommendations[1:min(5, end)]
            println(io, "### $(rec.issue)")
            println(io, "")
            println(io, "**Priority:** $(uppercase(string(rec.priority)))  ")
            println(io, "**Category:** $(rec.category)  ")
            println(io, "")
            println(io, "$(rec.suggestion)")
            println(io, "")
        end
    end

    content = String(take!(io))
    write(filepath, content)

    println("✅ Markdown report exported to: $filepath")
end

"""
    compare_reports(report1::ComprehensiveReport, report2::ComprehensiveReport; verbose=true)

Compare two comprehensive reports to track improvements.
"""
function compare_reports(report1::ComprehensiveReport, report2::ComprehensiveReport; verbose=true)
    if !verbose
        return nothing
    end

    println("\n" * "="^70)
    println("REPORT COMPARISON")
    println("="^70)

    println("\n📅 Timeline:")
    println("   Report 1: $(Dates.format(report1.timestamp, "yyyy-mm-dd HH:MM:SS"))")
    println("   Report 2: $(Dates.format(report2.timestamp, "yyyy-mm-dd HH:MM:SS"))")

    println("\n📊 Score Changes:")
    _print_delta("Overall", report1.overall_score, report2.overall_score)
    _print_delta("Performance", report1.performance_score, report2.performance_score)
    _print_delta("Size", report1.size_score, report2.size_score)
    _print_delta("Security", report1.security_score, report2.security_score)

    if report1.binary_size_bytes !== nothing && report2.binary_size_bytes !== nothing
        size1_kb = report1.binary_size_bytes / 1024
        size2_kb = report2.binary_size_bytes / 1024
        println("\n💾 Binary Size:")
        _print_delta("Size (KB)", size1_kb, size2_kb, reverse=true)
    end

    println("="^70)
end

function _print_delta(label, val1, val2; reverse=false)
    delta = val2 - val1
    if reverse
        delta = -delta
    end

    symbol = delta > 0 ? "↑" : (delta < 0 ? "↓" : "→")
    color_symbol = delta > 0 ? "✓" : (delta < 0 ? "✗" : "•")

    println("   $color_symbol $label: $(round(val1, digits=1)) → $(round(val2, digits=1)) ($symbol $(round(abs(delta), digits=1)))")
end

export ComprehensiveReport, generate_comprehensive_report
export export_report_json, export_report_markdown, compare_reports
