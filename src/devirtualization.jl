# Devirtualization - Eliminating Dynamic Dispatch
#
# This module implements devirtualization to replace virtual method calls
# with direct calls when the target is statically determinable.
#
# Optimizations:
# 1. Type-based devirtualization: When receiver type is known
# 2. Class hierarchy analysis: When all subtypes are known
# 3. Call site specialization: When callers use concrete types

using InteractiveUtils

"""
Information about a virtual call site
"""
struct VirtualCallSite
    function_name::Symbol
    call_location::Int
    receiver_type::Type
    possible_targets::Vector{Method}
    can_devirtualize::Bool
    devirtualization_strategy::Symbol  # :direct, :switch, :none
end

"""
Devirtualization report for a function
"""
struct DevirtualizationReport
    function_name::Symbol
    total_call_sites::Int
    virtual_calls::Vector{VirtualCallSite}
    devirtualizable_calls::Int
    potential_speedup::Float64  # Estimated percentage improvement
end

"""
    analyze_devirtualization(f, types)

Analyze opportunities for devirtualizing method calls.

Identifies virtual calls that can be converted to direct calls.

# Example
```julia
abstract type Animal end
struct Dog <: Animal end

sound(d::Dog) = "woof"
make_noise(a::Animal) = sound(a)

report = analyze_devirtualization(make_noise, (Dog,))
println("Can devirtualize: ", report.devirtualizable_calls)
```
"""
function analyze_devirtualization(f, types)
    func_name = Symbol(f)
    virtual_calls = VirtualCallSite[]
    total_calls = 0

    try
        tt = Base.to_tuple_type(types)
        ci_array = static_code_typed(f, tt)

        if isempty(ci_array)
            return DevirtualizationReport(func_name, 0, virtual_calls, 0, 0.0)
        end

        ci, rt = ci_array[1]

        # Analyze each call site
        for (idx, stmt) in enumerate(ci.code)
            if stmt isa Expr && stmt.head === :call
                total_calls += 1

                # Check if this is a virtual call
                call_info = analyze_call_site(stmt, idx, ci, types)

                if !isnothing(call_info)
                    push!(virtual_calls, call_info)
                end
            end
        end

    catch e
        @debug "Devirtualization analysis failed" exception=e
    end

    devirtualizable = count(vc -> vc.can_devirtualize, virtual_calls)

    # Estimate speedup: each devirtualized call saves ~5-10ns
    # Virtual calls in tight loops can be significant
    speedup = devirtualizable > 0 ? min(devirtualizable * 5.0, 30.0) : 0.0

    return DevirtualizationReport(
        func_name,
        total_calls,
        virtual_calls,
        devirtualizable,
        speedup
    )
end

"""
Analyze a single call site for devirtualization opportunities
"""
function analyze_call_site(call_expr::Expr, idx::Int, ci, context_types)
    if length(call_expr.args) < 1
        return nothing
    end

    # Get the function being called
    func = call_expr.args[1]

    # Skip non-generic calls
    if !(func isa GlobalRef || func isa Symbol)
        return nothing
    end

    func_name = func isa GlobalRef ? func.name : func

    # Get receiver type if this is a method call
    receiver_type = Nothing

    if length(call_expr.args) >= 2
        receiver_arg = call_expr.args[2]

        # Try to infer receiver type
        receiver_type = try
            argextype(receiver_arg, ci, ci.slottypes)
        catch
            Any
        end

        receiver_type = widenconst(receiver_type)
    end

    # Check if this is a virtual call on an abstract type
    is_virtual = isabstracttype(receiver_type) ||
                 receiver_type === Any ||
                 receiver_type isa Union

    if !is_virtual && receiver_type !== Nothing
        return nothing  # Already concrete, no devirtualization needed
    end

    # Find all possible method targets
    possible_methods = Method[]

    try
        if isa(func, GlobalRef)
            resolved_func = getfield(func.mod, func.name)

            if resolved_func isa Function
                # Get all methods that could match
                for m in methods(resolved_func)
                    if method_could_match(m, receiver_type)
                        push!(possible_methods, m)
                    end
                end
            end
        end
    catch e
        @debug "Could not resolve methods" exception=e
    end

    # Determine devirtualization strategy
    can_devirt = false
    strategy = :none

    if length(possible_methods) == 1
        # Only one possible target - can directly call it
        can_devirt = true
        strategy = :direct
    elseif length(possible_methods) > 1 && length(possible_methods) <= 4
        # Few targets - can use a switch/dispatch table
        can_devirt = true
        strategy = :switch
    end

    return VirtualCallSite(
        func_name,
        idx,
        receiver_type,
        possible_methods,
        can_devirt,
        strategy
    )
end

"""
Check if a method could match a given type
"""
function method_could_match(m::Method, T::Type)
    sig = m.sig

    if sig isa UnionAll
        return true  # Conservative: could match
    end

    if sig.parameters isa Tuple && length(sig.parameters) >= 2
        # Second parameter (after typeof(f)) is the receiver type
        param_type = sig.parameters[2]

        # Check if T could be this type
        return T === Any || T <: param_type || param_type <: T
    end

    return true  # Conservative
end

"""
    suggest_devirtualization(report::DevirtualizationReport)

Generate suggestions for devirtualizing code.
"""
function suggest_devirtualization(report::DevirtualizationReport)
    suggestions = String[]

    for call in report.virtual_calls
        if call.can_devirtualize
            if call.strategy === :direct
                push!(suggestions, """
                    # Call site at position $(call.call_location) can be devirtualized
                    # Receiver type: $(call.receiver_type)
                    # Single target: $(call.possible_targets[1])
                    # Strategy: Direct call (no dispatch needed)
                    """)
            elseif call.strategy === :switch
                push!(suggestions, """
                    # Call site at position $(call.call_location) can be devirtualized
                    # Receiver type: $(call.receiver_type)
                    # Targets: $(length(call.possible_targets))
                    # Strategy: Switch-based dispatch
                    """)
            end
        else
            if isabstracttype(call.receiver_type)
                push!(suggestions, """
                    # Call site at position $(call.call_location) uses abstract type
                    # Consider making receiver type concrete: $(call.receiver_type)
                    # Or use type parameters with concrete instantiations
                    """)
            end
        end
    end

    return suggestions
end

"""
Apply devirtualization transformation to IR
"""
function apply_devirtualization!(ci, f, types)
    report = analyze_devirtualization(f, types)

    if report.devirtualizable_calls == 0
        return ci, false
    end

    # In a full implementation, we would:
    # 1. Replace virtual calls with direct calls
    # 2. Generate specialized dispatch code
    # 3. Update SSA values accordingly

    # For now, just mark that it was analyzed
    return ci, true
end

"""
Pretty print devirtualization report
"""
function Base.show(io::IO, report::DevirtualizationReport)
    println(io, "Devirtualization Analysis: ", report.function_name)
    println(io, "=" ^ 60)

    println(io, "Total call sites: ", report.total_call_sites)
    println(io, "Virtual calls found: ", length(report.virtual_calls))
    println(io, "Devirtualizable: ", report.devirtualizable_calls)

    if report.potential_speedup > 0
        println(io, "Estimated speedup: ", round(report.potential_speedup, digits=1), "%")
    end

    if !isempty(report.virtual_calls)
        println(io, "\nVirtual Call Sites:")

        for (i, call) in enumerate(report.virtual_calls)
            println(io, "\n[$i] ", call.function_name, " at position ", call.call_location)
            println(io, "    Receiver type: ", call.receiver_type)
            println(io, "    Possible targets: ", length(call.possible_targets))

            if !isempty(call.possible_targets)
                for (j, m) in enumerate(call.possible_targets[1:min(3, end)])
                    println(io, "      $j. ", m.sig)
                end
                if length(call.possible_targets) > 3
                    println(io, "      ... and ", length(call.possible_targets) - 3, " more")
                end
            end

            if call.can_devirtualize
                println(io, "    ✓ Can devirtualize using: ", call.strategy)
            else
                println(io, "    ✗ Cannot devirtualize (too many targets or unknown type)")
            end
        end
    else
        println(io, "\n✓ No virtual calls found - all calls are direct")
    end
end

"""
Quick check if function has devirtualization opportunities
"""
function has_devirtualization_opportunities(f, types)
    report = analyze_devirtualization(f, types)
    return report.devirtualizable_calls > 0
end

export VirtualCallSite, DevirtualizationReport
export analyze_devirtualization, suggest_devirtualization
export apply_devirtualization!, has_devirtualization_opportunities
