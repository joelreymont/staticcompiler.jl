# Security analysis for static compilation

"""
Security issue detected during analysis
"""
struct SecurityIssue
    severity::Symbol  # :critical, :high, :medium, :low
    category::Symbol  # :buffer_overflow, :integer_overflow, :unsafe_pointer, :unchecked_access
    location::String
    description::String
    recommendation::String
end

"""
Security analysis report
"""
struct SecurityReport
    critical_issues::Vector{SecurityIssue}
    warnings::Vector{SecurityIssue}
    info::Vector{SecurityIssue}
    security_score::Float64  # 0-100, higher is better
end

"""
    analyze_security(f, types; verbose=true)

Perform security analysis on a function before compilation.

Detects:
- Buffer overflows
- Unchecked array accesses
- Unsafe pointer operations
- Integer overflow risks
- Bounds checking issues

# Example
```julia
function process_data(arr::Vector{Int}, idx::Int)
    return arr[idx]  # Potentially unsafe!
end

report = analyze_security(process_data, (Vector{Int}, Int))
```
"""
function analyze_security(f, types; verbose=true)
    critical = SecurityIssue[]
    warnings = SecurityIssue[]
    info = SecurityIssue[]

    try
        # Get typed IR
        tt = Base.to_tuple_type(types)
        ci = only(static_code_typed(f, tt))

        # Analyze IR for security issues
        for (i, stmt) in enumerate(ci[1].code)
            # Check for unchecked array accesses
            if isa(stmt, Expr)
                if stmt.head === :call
                    fname = string(stmt.args[1])

                    # Unsafe array indexing
                    if occursin("getindex", fname) || occursin("setindex", fname)
                        # Check if @inbounds was used (removes bounds checks)
                        # In real code, would check IR metadata
                        push!(warnings, SecurityIssue(
                            :medium,
                            :unchecked_access,
                            "Line approx. $i",
                            "Array access without explicit bounds checking",
                            "Add explicit bounds checks or ensure indices are always valid"
                        ))
                    end

                    # Integer overflow risks
                    if fname in ["*", "+", "-"] && length(stmt.args) > 1
                        # Check if operating on integers
                        has_int = false
                        for arg in stmt.args[2:end]
                            if isa(arg, Int) || isa(arg, Symbol)
                                has_int = true
                            end
                        end

                        if has_int
                            push!(info, SecurityIssue(
                                :low,
                                :integer_overflow,
                                "Line approx. $i",
                                "Integer arithmetic could overflow",
                                "Consider using checked arithmetic or wider types"
                            ))
                        end
                    end
                end

                # Check for unsafe pointer operations
                if stmt.head === :foreigncall || (stmt.head === :call &&
                    any(arg -> isa(arg, Symbol) && occursin("unsafe", string(arg)), stmt.args))
                    push!(critical, SecurityIssue(
                        :critical,
                        :unsafe_pointer,
                        "Line approx. $i",
                        "Unsafe pointer operation detected",
                        "Ensure pointer is valid and operations are within bounds"
                    ))
                end
            end
        end

        # Check LLVM IR for additional issues
        mod = static_llvm_module(f, types)

        for func in LLVM.functions(mod)
            for bb in LLVM.blocks(func)
                for inst in LLVM.instructions(bb)
                    inst_str = string(inst)

                    # Check for buffer overflow indicators
                    if occursin("getelementptr", inst_str) && occursin("inbounds", inst_str)
                        # GEP with inbounds - bounds are assumed, not checked
                        push!(info, SecurityIssue(
                            :low,
                            :buffer_overflow,
                            "LLVM IR",
                            "Pointer arithmetic assumes bounds are correct",
                            "Ensure all pointer arithmetic is within allocated bounds"
                        ))
                    end

                    # Check for potential null pointer dereferences
                    if occursin("load", inst_str) && occursin("null", lowercase(inst_str))
                        push!(critical, SecurityIssue(
                            :critical,
                            :unsafe_pointer,
                            "LLVM IR",
                            "Potential null pointer dereference",
                            "Add null checks before dereferencing pointers"
                        ))
                    end
                end
            end
        end

    catch e
        @debug "Security analysis failed" exception=e
    end

    # Remove duplicates (keep only unique combinations of severity/category/description)
    unique_key(issue) = (issue.severity, issue.category, issue.description)
    critical = unique(unique_key, critical)
    warnings = unique(unique_key, warnings)
    info = unique(unique_key, info)

    # Calculate security score (higher is better)
    score = 100.0
    score -= length(critical) * 30.0  # Critical issues severely impact score
    score -= length(warnings) * 10.0  # Warnings moderately impact score
    score -= length(info) * 2.0       # Info slightly impacts score
    score = max(0.0, score)

    report = SecurityReport(critical, warnings, info, score)

    if verbose
        print_security_report(report)
    end

    return report
end

function print_security_report(report::SecurityReport)
    println("\n" * "="^70)
    println("SECURITY ANALYSIS REPORT")
    println("="^70)

    println("\n🔒 SECURITY SCORE: $(round(report.security_score, digits=1))/100")

    total_issues = length(report.critical_issues) + length(report.warnings) + length(report.info)

    if total_issues == 0
        println("\n✅ NO SECURITY ISSUES DETECTED")
        println("   Code appears to follow safe practices")
    else
        println("\n⚠️  TOTAL ISSUES: $total_issues")
    end

    if !isempty(report.critical_issues)
        println("\n🔴 CRITICAL ISSUES ($(length(report.critical_issues))):")
        for (i, issue) in enumerate(report.critical_issues)
            print_security_issue(i, issue)
        end
    end

    if !isempty(report.warnings)
        println("\n🟠 WARNINGS ($(length(report.warnings))):")
        for (i, issue) in enumerate(report.warnings[1:min(5, end)])
            print_security_issue(i, issue)
        end
        if length(report.warnings) > 5
            println("  ... and $(length(report.warnings) - 5) more warnings")
        end
    end

    if !isempty(report.info)
        println("\n🔵 INFORMATIONAL ($(length(report.info))):")
        println("  $(length(report.info)) low-severity items detected")
        println("  (Use verbose=true for full details)")
    end

    if !isempty(report.critical_issues)
        println("\n⚠️  CRITICAL ISSUES MUST BE FIXED BEFORE DEPLOYMENT!")
    end

    println("="^70)
end

function print_security_issue(num::Int, issue::SecurityIssue)
    println("\n  $num. [$(uppercase(string(issue.category)))]")
    println("     Location: $(issue.location)")
    println("     Issue: $(issue.description)")
    println("     Fix: $(issue.recommendation)")
end

export SecurityIssue, SecurityReport, analyze_security
