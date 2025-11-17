# Monomorphization Analysis
# Analyzes abstract type parameters that could be specialized

"""
    AbstractParameterInfo

Information about an abstract type parameter.
"""
struct AbstractParameterInfo
    position::Int
    type::Type
    is_abstract::Bool
end

"""
    MonomorphizationReport

Report from monomorphization analysis showing abstract types.
"""
struct MonomorphizationReport
    has_abstract_types::Bool
    function_name::Symbol
    abstract_parameters::Vector{AbstractParameterInfo}
    optimization_opportunities::Int
end

"""
    analyze_monomorphization(f::Function, types::Tuple)

Analyze whether function `f` with argument types `types` uses abstract types
that could benefit from monomorphization (specialization).

Returns a `MonomorphizationReport` containing:
- `has_abstract_types`: Whether abstract types were found
- `function_name`: Name of analyzed function
- `abstract_parameters`: List of abstract type parameters
- `optimization_opportunities`: Count of parameters that could be specialized

# Example
```julia
function process(x::Number)
    return x * 2
end

report = analyze_monomorphization(process, (Number,))
if report.has_abstract_types
    println("Function uses abstract types and could be specialized")
end
```
"""
function analyze_monomorphization(f::Function, types::Tuple)
    fname = nameof(f)
    abstract_params = AbstractParameterInfo[]

    # Analyze each input type
    for (i, T) in enumerate(types)
        is_abstract = isabstracttype(T)

        if is_abstract
            push!(abstract_params, AbstractParameterInfo(i, T, true))
        else
            # Check for nested abstract types (e.g., Vector{Number})
            if T isa DataType && !isempty(T.parameters)
                for param in T.parameters
                    if param isa Type && isabstracttype(param)
                        push!(abstract_params, AbstractParameterInfo(i, param, true))
                    end
                end
            end
        end
    end

    has_abstract = !isempty(abstract_params)
    opportunities = length(abstract_params)

    return MonomorphizationReport(
        has_abstract,
        fname,
        abstract_params,
        opportunities
    )
end

"""
    isabstracttype(T) -> Bool

Check if type T is abstract (including checking for abstract type parameters).
"""
function isabstracttype(T)
    # Use Base's implementation for all types
    # UnionAll and Union are considered abstract
    if T isa UnionAll
        return true
    elseif T isa Union
        return true
    else
        return Base.isabstracttype(T)
    end
end

# Export the analysis function
export analyze_monomorphization, MonomorphizationReport, AbstractParameterInfo
