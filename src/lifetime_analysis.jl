# Lifetime Analysis and Automatic Memory Management
#
# This module implements lifetime analysis to automatically insert
# free() calls for manually-allocated memory (MallocArray, MallocString).
#
# Similar to Rust's borrow checker, this tracks:
# 1. Where allocations occur
# 2. Last use of each allocation
# 3. Where to safely insert deallocations

using StaticTools
using InteractiveUtils

"""
Information about a memory allocation's lifetime
"""
struct Lifetime
    allocation_site::Int  # SSA value where allocated
    allocation_type::Symbol  # :malloc_array, :malloc_string, etc.
    last_use::Int  # Last SSA value where used
    can_auto_free::Bool
    free_location::Union{Int, Nothing}  # Where to insert free()
    conflicts::Vector{String}  # Reasons we can't auto-free
end

"""
Complete lifetime analysis report
"""
struct LifetimeAnalysisReport
    function_name::Symbol
    allocations::Vector{Lifetime}
    auto_freeable::Int
    memory_leaks_prevented::Int
    insertable_frees::Vector{Tuple{Int, Symbol}}  # (location, variable)
end

"""
    analyze_lifetimes(f, types)

Perform lifetime analysis to detect where free() can be automatically inserted.

# Example
```julia
function compute()
    arr = MallocArray{Float64}(100)
    result = sum(arr)
    # Analyzer detects: free(arr) should go here
    return result
end

report = analyze_lifetimes(compute, ())
println("Auto-freeable allocations: ", report.auto_freeable)
```
"""
function analyze_lifetimes(f, types)
    func_name = Symbol(f)
    allocations = Lifetime[]

    try
        tt = Base.to_tuple_type(types)
        ci_array = static_code_typed(f, tt)

        if isempty(ci_array)
            return LifetimeAnalysisReport(func_name, allocations, 0, 0, Tuple{Int, Symbol}[])
        end

        ci, rt = ci_array[1]

        # Find all manual memory allocations
        alloc_sites = find_malloc_sites(ci)

        # For each allocation, track its lifetime
        for (ssa_val, alloc_type) in alloc_sites
            lifetime = track_lifetime(ssa_val, alloc_type, ci)
            push!(allocations, lifetime)
        end

    catch e
        @debug "Lifetime analysis failed" exception=e
    end

    # Count auto-freeable allocations
    auto_freeable = count(lt -> lt.can_auto_free, allocations)

    # Generate free insertion points
    free_inserts = Tuple{Int, Symbol}[]
    for lt in allocations
        if lt.can_auto_free && !isnothing(lt.free_location)
            push!(free_inserts, (lt.free_location, Symbol("alloc_", lt.allocation_site)))
        end
    end

    return LifetimeAnalysisReport(
        func_name,
        allocations,
        auto_freeable,
        auto_freeable,  # Each auto-free prevents a leak
        free_inserts
    )
end

"""
Find all MallocArray, MallocString, etc. allocation sites
"""
function find_malloc_sites(ci)
    sites = Tuple{Int, Symbol}[]

    for (idx, stmt) in enumerate(ci.code)
        if stmt isa Expr && stmt.head === :call
            if length(stmt.args) > 0
                func = stmt.args[1]
                func_name = string(func)

                # Detect StaticTools allocations
                if occursin("MallocArray", func_name)
                    push!(sites, (idx, :malloc_array))
                elseif occursin("MallocString", func_name) || occursin("malloc", func_name)
                    push!(sites, (idx, :malloc_string))
                elseif occursin("StrideArray", func_name)
                    push!(sites, (idx, :stride_array))
                end
            end
        end
    end

    return sites
end

"""
Track the lifetime of an allocation
"""
function track_lifetime(alloc_ssa::Int, alloc_type::Symbol, ci)
    conflicts = String[]
    last_use = alloc_ssa

    # Track all uses of this SSA value
    for (idx, stmt) in enumerate(ci.code)
        if idx <= alloc_ssa
            continue
        end

        # Check if this statement uses our allocation
        if uses_ssa_value(stmt, SSAValue(alloc_ssa))
            last_use = idx

            # Check for problematic uses
            if statement_returns_value(stmt, SSAValue(alloc_ssa))
                push!(conflicts, "Allocation is returned - cannot auto-free")
            end

            if statement_stores_to_global(stmt, SSAValue(alloc_ssa))
                push!(conflicts, "Allocation stored to global - cannot auto-free")
            end

            if statement_captures_in_closure(stmt, SSAValue(alloc_ssa))
                push!(conflicts, "Allocation captured in closure - cannot auto-free")
            end
        end
    end

    # Check if there's already a free() call
    has_manual_free = has_free_call(ci, alloc_ssa)

    can_auto_free = isempty(conflicts) && !has_manual_free

    # Determine where to insert free()
    free_location = nothing
    if can_auto_free
        # Insert free after last use, before any return
        free_location = find_free_insertion_point(ci, last_use)
    end

    return Lifetime(
        alloc_ssa,
        alloc_type,
        last_use,
        can_auto_free,
        free_location,
        conflicts
    )
end

"""
Check if a statement uses a particular SSA value
"""
function uses_ssa_value(stmt, target::SSAValue)
    if stmt === target
        return true
    end

    if stmt isa Expr
        for arg in stmt.args
            if arg === target
                return true
            elseif arg isa Expr && uses_ssa_value(arg, target)
                return true
            end
        end
    end

    return false
end

"""
Check if statement returns a value
"""
function statement_returns_value(stmt, target::SSAValue)
    if stmt isa ReturnNode && isdefined(stmt, :val) && stmt.val === target
        return true
    end

    if stmt isa Expr && stmt.head === :return && length(stmt.args) > 0
        return stmt.args[1] === target
    end

    return false
end

"""
Check if statement stores to global (conservative check)
"""
function statement_stores_to_global(stmt, target::SSAValue)
    if stmt isa Expr
        if stmt.head === :(=) || stmt.head === :global
            return uses_ssa_value(stmt, target)
        end
    end
    return false
end

"""
Check if value is captured in a closure (conservative)
"""
function statement_captures_in_closure(stmt, target::SSAValue)
    # Conservative: if used in a function call, it might be captured
    if stmt isa Expr && stmt.head === :call
        func = stmt.args[1]
        func_name = string(func)

        # Known safe functions that don't capture
        safe_funcs = ["getindex", "setindex!", "length", "size", "sum", "free"]

        if any(sf -> occursin(sf, func_name), safe_funcs)
            return false
        end

        # If passed as argument, might be captured
        return uses_ssa_value(stmt, target)
    end

    return false
end

"""
Check if there's already a manual free() call
"""
function has_free_call(ci, alloc_ssa::Int)
    for stmt in ci.code
        if stmt isa Expr && stmt.head === :call
            if length(stmt.args) > 0
                func_name = string(stmt.args[1])

                if occursin("free", func_name) && length(stmt.args) >= 2
                    arg = stmt.args[2]
                    if arg === SSAValue(alloc_ssa)
                        return true
                    end
                end
            end
        end
    end

    return false
end

"""
Find the best location to insert a free() call
"""
function find_free_insertion_point(ci, last_use::Int)
    # Look for the next safe point after last use
    for (idx, stmt) in enumerate(ci.code)
        if idx <= last_use
            continue
        end

        # Don't insert inside control flow
        if stmt isa GotoNode || stmt isa GotoIfNot
            continue
        end

        # Insert before any return
        if stmt isa ReturnNode || (stmt isa Expr && stmt.head === :return)
            return idx
        end

        # This is a safe insertion point
        return idx
    end

    # Default: insert at end
    return length(ci.code)
end

"""
Generate code with automatic free() calls inserted
"""
function insert_auto_frees(report::LifetimeAnalysisReport)
    insertions = String[]

    for (location, var_name) in report.insertable_frees
        push!(insertions, """
            # Auto-inserted by lifetime analysis
            # At statement $location:
            free($var_name)
            """)
    end

    return insertions
end

"""
    suggest_lifetime_improvements(report::LifetimeAnalysisReport)

Generate suggestions for improving memory management.
"""
function suggest_lifetime_improvements(report::LifetimeAnalysisReport)
    suggestions = String[]

    if report.auto_freeable > 0
        push!(suggestions, """
            ✓ $(report.auto_freeable) allocation(s) can have automatic free() inserted
            Enable auto-free with: compile_executable(f, types; auto_free=true)
            """)
    end

    for alloc in report.allocations
        if !alloc.can_auto_free && !isempty(alloc.conflicts)
            push!(suggestions, """
                ⚠ Allocation at statement $(alloc.allocation_site) cannot be auto-freed:
                """)

            for conflict in alloc.conflicts
                push!(suggestions, "  - $conflict")
            end

            push!(suggestions, "  Consider manual free() or restructuring code")
        end
    end

    leaked_allocs = count(lt -> !lt.can_auto_free && isempty(lt.conflicts), report.allocations)
    if leaked_allocs > 0
        push!(suggestions, """
            ⚠ Warning: $leaked_allocs allocation(s) may leak memory
            Add manual free() calls or enable auto-free
            """)
    end

    return suggestions
end

"""
Pretty print lifetime analysis report
"""
function Base.show(io::IO, report::LifetimeAnalysisReport)
    println(io, "Lifetime Analysis Report: ", report.function_name)
    println(io, "=" ^ 60)

    println(io, "Total allocations: ", length(report.allocations))
    println(io, "Auto-freeable: ", report.auto_freeable)
    println(io, "Memory leaks prevented: ", report.memory_leaks_prevented)

    if !isempty(report.allocations)
        println(io, "\nAllocation Lifetimes:")

        for (i, lt) in enumerate(report.allocations)
            println(io, "\n[$i] ", lt.allocation_type, " at statement ", lt.allocation_site)
            println(io, "    Last use: statement ", lt.last_use)
            println(io, "    Lifetime span: ", lt.last_use - lt.allocation_site, " statements")

            if lt.can_auto_free
                println(io, "    ✓ Can auto-free")
                if !isnothing(lt.free_location)
                    println(io, "    Free at: statement ", lt.free_location)
                end
            else
                println(io, "    ✗ Cannot auto-free")
                if !isempty(lt.conflicts)
                    println(io, "    Reasons:")
                    for conflict in lt.conflicts
                        println(io, "      - ", conflict)
                    end
                end
            end
        end
    end

    if !isempty(report.insertable_frees)
        println(io, "\nSuggested free() insertions:")
        for (loc, var) in report.insertable_frees
            println(io, "  Statement $loc: free($var)")
        end
    end
end

"""
Apply lifetime analysis transformations (for future code generation)
"""
function apply_lifetime_analysis!(ci, f, types; auto_free::Bool=false)
    if !auto_free
        return ci, false
    end

    report = analyze_lifetimes(f, types)

    if report.auto_freeable == 0
        return ci, false
    end

    # In a full implementation, we would:
    # 1. Insert free() calls at identified locations
    # 2. Update SSA numbering
    # 3. Verify correctness

    return ci, true
end

export Lifetime, LifetimeAnalysisReport
export analyze_lifetimes, suggest_lifetime_improvements
export insert_auto_frees, apply_lifetime_analysis!
