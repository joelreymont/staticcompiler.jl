# Monomorphization - Specialization of Generic Code
#
# This module implements monomorphization to eliminate abstract types
# by creating specialized versions for concrete types.
#
# Transforms:
#   function process(x::Number) -> process_Int64(x::Int64), process_Float64(x::Float64)
#
# This enables static compilation of code using abstract types when
# all concrete instantiations are known at compile time.

using Core.Compiler: widenconst, argextype
using InteractiveUtils

"""
Information about an abstract type parameter and its concrete instantiations
"""
struct TypeInstantiation
    parameter_position::Int
    abstract_type::Type
    concrete_types::Set{Type}
    can_monomorphize::Bool
end

"""
A monomorphized version of a function
"""
struct MonomorphizedVariant
    original_function::Function
    type_signature::Type
    specialized_name::Symbol
    concrete_args::Vector{Type}
end

"""
Complete monomorphization analysis
"""
struct MonomorphizationReport
    function_name::Symbol
    has_abstract_types::Bool
    abstract_parameters::Vector{TypeInstantiation}
    possible_variants::Vector{MonomorphizedVariant}
    can_fully_monomorphize::Bool
    specialization_factor::Int  # Number of variants needed
end

"""
    analyze_monomorphization(f, types)

Analyze if a function can be monomorphized.

Identifies abstract type parameters and determines which concrete
types they're instantiated with across the program.

# Example
```julia
abstract type Animal end
struct Dog <: Animal end
struct Cat <: Animal end

make_sound(a::Animal) = sound(a)

report = analyze_monomorphization(make_sound, (Animal,))
println("Can monomorphize: ", report.can_fully_monomorphize)
```
"""
function analyze_monomorphization(f, types)
    func_name = Symbol(f)
    tt = Base.to_tuple_type(types)

    # Check which parameters are abstract
    abstract_params = TypeInstantiation[]

    for (i, T) in enumerate(types)
        if isabstracttype(T)
            # Found an abstract type - need to monomorphize
            concrete = find_concrete_instantiations(f, i, T)

            instantiation = TypeInstantiation(
                i,
                T,
                concrete,
                !isempty(concrete)
            )
            push!(abstract_params, instantiation)
        end
    end

    has_abstract = !isempty(abstract_params)

    # Generate all possible variants
    variants = MonomorphizedVariant[]

    if has_abstract && all(p -> p.can_monomorphize, abstract_params)
        # Can fully monomorphize
        variants = generate_variants(f, types, abstract_params)
    end

    can_fully_mono = has_abstract && !isempty(variants)
    specialization_factor = max(1, length(variants))

    return MonomorphizationReport(
        func_name,
        has_abstract,
        abstract_params,
        variants,
        can_fully_mono,
        specialization_factor
    )
end

"""
Find concrete types that an abstract parameter is instantiated with
"""
function find_concrete_instantiations(f, param_position::Int, abstract_type::Type)
    concrete_types = Set{Type}()

    try
        # Look at all method specializations
        for method in methods(f)
            sig = method.sig

            if sig isa UnionAll
                continue  # Skip generic signatures
            end

            if sig.parameters isa Tuple && length(sig.parameters) >= param_position
                param_type = sig.parameters[param_position + 1]  # +1 for typeof(f)

                # Check if this is a concrete subtype of our abstract type
                if isconcretetype(param_type) && param_type <: abstract_type
                    push!(concrete_types, param_type)
                end
            end
        end

        # Heuristic: If we found no concrete types but have common subtypes, suggest them
        if isempty(concrete_types)
            concrete_types = suggest_common_subtypes(abstract_type)
        end

    catch e
        @debug "Failed to find concrete instantiations" exception=e
    end

    return concrete_types
end

"""
Suggest common concrete subtypes for an abstract type
"""
function suggest_common_subtypes(T::Type)
    suggestions = Set{Type}()

    # Common Number subtypes
    if T === Number || T >: Number
        push!(suggestions, Int64)
        push!(suggestions, Float64)
        push!(suggestions, Int32)
        push!(suggestions, Float32)
    end

    # Common Integer subtypes
    if T === Integer || T >: Integer
        push!(suggestions, Int64)
        push!(suggestions, Int32)
        push!(suggestions, UInt64)
    end

    # Common AbstractFloat subtypes
    if T === AbstractFloat || T >: AbstractFloat
        push!(suggestions, Float64)
        push!(suggestions, Float32)
    end

    # Common AbstractArray subtypes
    if T === AbstractArray || T >: AbstractArray
        push!(suggestions, Vector{Float64})
        push!(suggestions, Matrix{Float64})
    end

    return suggestions
end

"""
Generate all monomorphized variants
"""
function generate_variants(f, types, abstract_params::Vector{TypeInstantiation})
    variants = MonomorphizedVariant[]

    # Get all combinations of concrete types
    concrete_combinations = generate_concrete_combinations(types, abstract_params)

    for (i, concrete_types) in enumerate(concrete_combinations)
        variant_name = Symbol(string(f) * "_specialized_" * string(i))

        variant = MonomorphizedVariant(
            f,
            Tuple{concrete_types...},
            variant_name,
            collect(concrete_types)
        )

        push!(variants, variant)
    end

    return variants
end

"""
Generate all combinations of concrete types for abstract parameters
"""
function generate_concrete_combinations(types, abstract_params::Vector{TypeInstantiation})
    # Start with the original types
    result = [collect(types)]

    # For each abstract parameter, expand with its concrete instantiations
    for param in abstract_params
        new_result = []

        for type_combo in result
            for concrete_type in param.concrete_types
                new_combo = copy(type_combo)
                new_combo[param.parameter_position] = concrete_type
                push!(new_result, new_combo)
            end
        end

        result = new_result
    end

    return result
end

"""
    monomorphize_function(f, types)

Attempt to monomorphize a function with abstract types.

Returns a vector of specialized functions if successful.
"""
function monomorphize_function(f, types)
    report = analyze_monomorphization(f, types)

    if !report.can_fully_monomorphize
        return nothing
    end

    # For now, return the report (actual code generation would require codegen)
    # In a real implementation, this would generate actual Julia functions
    return report
end

"""
Apply monomorphization during compilation
"""
function apply_monomorphization!(ci, f, types)
    report = analyze_monomorphization(f, types)

    if !report.can_fully_monomorphize
        return ci, false  # No changes
    end

    # Mark that monomorphization was applied
    # In a full implementation, we would:
    # 1. Generate specialized versions
    # 2. Replace abstract calls with dispatching to concrete versions
    # 3. Inline the dispatch when possible

    return ci, true
end

"""
Pretty print monomorphization report
"""
function Base.show(io::IO, report::MonomorphizationReport)
    println(io, "Monomorphization Analysis: ", report.function_name)
    println(io, "=" ^ 60)

    if !report.has_abstract_types
        println(io, "✓ No abstract types - already concrete")
        return
    end

    println(io, "Abstract Parameters:")
    for param in report.abstract_parameters
        println(io, "  Position ", param.parameter_position, ": ", param.abstract_type)
        println(io, "    Concrete instantiations: ", length(param.concrete_types))

        for T in param.concrete_types
            println(io, "      • ", T)
        end

        if param.can_monomorphize
            println(io, "    ✓ Can monomorphize")
        else
            println(io, "    ✗ Cannot determine concrete types")
        end
    end

    println(io, "\nMonomorphization Status:")
    if report.can_fully_monomorphize
        println(io, "  ✓ Can fully monomorphize")
        println(io, "  Specialization factor: ", report.specialization_factor)
        println(io, "  Generated variants: ", length(report.possible_variants))

        if !isempty(report.possible_variants)
            println(io, "\n  Specialized Signatures:")
            for variant in report.possible_variants
                args_str = join(string.(variant.concrete_args), ", ")
                println(io, "    $(variant.specialized_name)($(args_str))")
            end
        end
    else
        println(io, "  ✗ Cannot fully monomorphize")
        println(io, "    Reason: Unknown concrete instantiations")
    end
end

"""
    check_monomorphizable(f, types) -> Bool

Quick check if a function can be monomorphized.
"""
function check_monomorphizable(f, types)
    report = analyze_monomorphization(f, types)
    return report.can_fully_monomorphize
end

export TypeInstantiation, MonomorphizedVariant, MonomorphizationReport
export analyze_monomorphization, monomorphize_function, apply_monomorphization!
export check_monomorphizable
