# Escape Analysis for Stack Promotion
#
# This module implements interprocedural escape analysis to determine
# if heap allocations can be safely promoted to stack allocations.
#
# Key Optimizations:
# 1. Stack Promotion: Convert heap allocations to stack when they don't escape
# 2. Scalar Replacement: Replace arrays with individual scalar variables
# 3. Allocation Elimination: Remove allocations entirely when possible

using Core.Compiler: IRCode, Instruction, SSAValue, Argument, GotoNode, GotoIfNot, ReturnNode
using InteractiveUtils

"""
Result of escape analysis for a single allocation site
"""
struct EscapeInfo
    ssa_value::Union{SSAValue, Nothing}
    allocation_type::Symbol  # :array, :string, :struct, :unknown
    escapes::Bool
    escape_reasons::Vector{String}
    can_stack_promote::Bool
    can_scalar_replace::Bool
    size_known::Bool
    estimated_size::Union{Int, Nothing}
end

"""
Complete escape analysis report for a function
"""
struct EscapeAnalysisReport
    allocations::Vector{EscapeInfo}
    promotable_allocations::Int
    scalar_replaceable::Int
    potential_savings_bytes::Int
    optimizations_suggested::Vector{String}
end

"""
    analyze_escapes(f, types)

Perform interprocedural escape analysis on a function.

Returns an EscapeAnalysisReport with:
- All allocation sites found
- Which can be stack-promoted
- Which can be scalar-replaced
- Estimated memory savings

# Example
```julia
report = analyze_escapes(my_func, (Int, Float64))
println("Promotable allocations: \$(report.promotable_allocations)")
```
"""
function analyze_escapes(f, types)
    allocations = EscapeInfo[]

    try
        # Get optimized IR
        tt = Base.to_tuple_type(types)
        ci_array = static_code_typed(f, tt)

        if isempty(ci_array)
            return EscapeAnalysisReport(allocations, 0, 0, 0, String[])
        end

        ci, rt = ci_array[1]

        # Analyze each statement in the IR
        for (idx, stmt) in enumerate(ci.code)
            if stmt isa Expr
                # Check for allocation expressions
                if stmt.head === :call
                    alloc_info = check_allocation(stmt, idx, ci)
                    if !isnothing(alloc_info)
                        # Perform escape analysis on this allocation
                        escape_info = track_escape(alloc_info, idx, ci)
                        push!(allocations, escape_info)
                    end
                end
            end
        end
    catch e
        @debug "Escape analysis failed" exception=e
    end

    # Calculate statistics
    promotable = count(a -> a.can_stack_promote, allocations)
    scalar_replaceable = count(a -> a.can_scalar_replace, allocations)
    potential_savings = sum(a -> a.can_stack_promote && !isnothing(a.estimated_size) ? a.estimated_size : 0, allocations)

    # Generate optimization suggestions
    suggestions = String[]
    if promotable > 0
        push!(suggestions, "Stack promotion: $promotable allocation(s) can be moved to stack")
    end
    if scalar_replaceable > 0
        push!(suggestions, "Scalar replacement: $scalar_replaceable allocation(s) can be eliminated via scalarization")
    end
    if potential_savings > 1024
        push!(suggestions, "Potential memory savings: $(div(potential_savings, 1024)) KB")
    end

    return EscapeAnalysisReport(allocations, promotable, scalar_replaceable, potential_savings, suggestions)
end

"""
Check if a call expression is an allocation
"""
function check_allocation(expr::Expr, idx::Int, ci)
    if length(expr.args) == 0
        return nothing
    end

    func = expr.args[1]
    func_name = string(func)

    # Detect array allocations
    if occursin("Array", func_name) || occursin("Vector", func_name) ||
       occursin("zeros", func_name) || occursin("ones", func_name)

        size_known = false
        estimated_size = nothing

        # Try to extract size information
        if length(expr.args) >= 2
            size_arg = expr.args[2]
            if size_arg isa Int
                size_known = true
                estimated_size = size_arg * 8  # Rough estimate
            end
        end

        return (ssa=SSAValue(idx), type=:array, size_known=size_known, size=estimated_size)
    end

    # Detect string allocations
    if occursin("string", lowercase(func_name)) || occursin("String", func_name)
        return (ssa=SSAValue(idx), type=:string, size_known=false, size=nothing)
    end

    # Detect struct allocations (new)
    if func isa Type
        # This is a constructor call
        return (ssa=SSAValue(idx), type=:struct, size_known=true, size=64)  # Estimate
    end

    return nothing
end

"""
Track if an allocation escapes the function
"""
function track_escape(alloc_info, alloc_idx::Int, ci)
    ssa = alloc_info.ssa
    escapes = false
    escape_reasons = String[]

    # Track uses of this SSA value
    for (idx, stmt) in enumerate(ci.code)
        if idx <= alloc_idx
            continue  # Only look at subsequent statements
        end

        # Check if this SSA value is used
        uses = find_ssa_uses(stmt, ssa)

        for use_context in uses
            # Determine if this use causes escape
            if use_causes_escape(use_context, stmt, ci)
                escapes = true
                push!(escape_reasons, describe_escape(use_context, stmt))
            end
        end
    end

    # Check if returned (definitely escapes)
    if ssa in find_return_values(ci)
        escapes = true
        push!(escape_reasons, "Allocation is returned from function")
    end

    # Determine optimization potential
    can_stack_promote = !escapes && alloc_info.size_known &&
                        !isnothing(alloc_info.size) && alloc_info.size < 4096

    can_scalar_replace = !escapes && alloc_info.type === :array &&
                         alloc_info.size_known &&
                         !isnothing(alloc_info.size) && alloc_info.size < 256

    return EscapeInfo(
        ssa,
        alloc_info.type,
        escapes,
        escape_reasons,
        can_stack_promote,
        can_scalar_replace,
        alloc_info.size_known,
        alloc_info.size
    )
end

"""
Find all uses of an SSA value in a statement
"""
function find_ssa_uses(stmt, target_ssa::SSAValue)
    uses = Symbol[]

    if stmt isa Expr
        for (i, arg) in enumerate(stmt.args)
            if arg === target_ssa
                # Determine context: call argument, store, etc.
                if stmt.head === :call && i > 1
                    push!(uses, :call_arg)
                elseif stmt.head === :(=)
                    push!(uses, :assignment)
                elseif stmt.head === :return
                    push!(uses, :return)
                end
            elseif arg isa Expr
                # Recursively check nested expressions
                append!(uses, find_ssa_uses(arg, target_ssa))
            end
        end
    elseif stmt isa ReturnNode && stmt.val === target_ssa
        push!(uses, :return)
    end

    return uses
end

"""
Determine if a use causes the allocation to escape
"""
function use_causes_escape(use_context::Symbol, stmt, ci)
    # Being returned definitely escapes
    if use_context === :return
        return true
    end

    # Being passed to a function may escape (conservative)
    if use_context === :call_arg
        if stmt isa Expr && stmt.head === :call && length(stmt.args) > 0
            func = stmt.args[1]
            func_name = string(func)

            # Known safe functions (don't escape their arguments)
            safe_functions = ["getindex", "setindex!", "length", "size", "sum", "prod"]

            if any(sf -> occursin(sf, func_name), safe_functions)
                return false
            end

            # Conservative: assume it escapes
            return true
        end
    end

    # Assignment to global or struct field escapes
    if use_context === :assignment
        # Would need more sophisticated analysis
        return true
    end

    return false
end

"""
Find all SSA values that are returned from function
"""
function find_return_values(ci)
    returns = []

    for stmt in ci.code
        if stmt isa ReturnNode && isdefined(stmt, :val)
            if stmt.val isa SSAValue
                push!(returns, stmt.val)
            end
        elseif stmt isa Expr && stmt.head === :return && length(stmt.args) > 0
            val = stmt.args[1]
            if val isa SSAValue
                push!(returns, val)
            end
        end
    end

    return returns
end

"""
Describe why an allocation escapes
"""
function describe_escape(use_context::Symbol, stmt)
    if use_context === :return
        return "Returned from function"
    elseif use_context === :call_arg
        if stmt isa Expr && length(stmt.args) > 0
            func_name = string(stmt.args[1])
            return "Passed to function: $func_name"
        end
        return "Passed to unknown function"
    elseif use_context === :assignment
        return "Assigned to non-local storage"
    else
        return "Unknown escape: $use_context"
    end
end

"""
    suggest_stack_promotion(report::EscapeAnalysisReport)

Generate code suggestions for stack-promoting allocations.
"""
function suggest_stack_promotion(report::EscapeAnalysisReport)
    suggestions = String[]

    for alloc in report.allocations
        if alloc.can_stack_promote
            if alloc.allocation_type === :array && !isnothing(alloc.estimated_size)
                size = div(alloc.estimated_size, 8)
                push!(suggestions, """
                    # Stack-allocate array instead of heap allocation
                    # Original: arr = zeros($size)
                    # Optimized: Use StaticArrays.jl
                    using StaticArrays
                    arr = @SVector zeros($size)
                    """)
            elseif alloc.allocation_type === :struct
                push!(suggestions, """
                    # This allocation doesn't escape - already stack-allocated by Julia
                    # No changes needed
                    """)
            end
        elseif alloc.can_scalar_replace
            push!(suggestions, """
                # This small array can be scalar-replaced
                # Consider unrolling the loop and using individual variables
                """)
        end
    end

    return suggestions
end

"""
Print escape analysis report in human-readable format
"""
function Base.show(io::IO, report::EscapeAnalysisReport)
    println(io, "Escape Analysis Report")
    println(io, "=" ^ 50)
    println(io, "Total allocations found: ", length(report.allocations))
    println(io, "Stack-promotable: ", report.promotable_allocations)
    println(io, "Scalar-replaceable: ", report.scalar_replaceable)

    if report.potential_savings_bytes > 0
        kb = div(report.potential_savings_bytes, 1024)
        println(io, "Potential memory savings: ", kb, " KB")
    end

    println(io, "\nOptimization Suggestions:")
    for suggestion in report.optimizations_suggested
        println(io, "  • ", suggestion)
    end

    if !isempty(report.allocations)
        println(io, "\nDetailed Allocation Analysis:")
        for (i, alloc) in enumerate(report.allocations)
            println(io, "\n[$i] ", alloc.allocation_type, " allocation")
            println(io, "    Escapes: ", alloc.escapes)
            if alloc.escapes && !isempty(alloc.escape_reasons)
                println(io, "    Reasons:")
                for reason in alloc.escape_reasons
                    println(io, "      - ", reason)
                end
            end
            println(io, "    Can stack-promote: ", alloc.can_stack_promote)
            println(io, "    Can scalar-replace: ", alloc.can_scalar_replace)
        end
    end
end

export EscapeInfo, EscapeAnalysisReport
export analyze_escapes, suggest_stack_promotion
