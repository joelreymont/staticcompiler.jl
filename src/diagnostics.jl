# Error diagnostics and helpful messages for static compilation failures

struct CompilationError <: Exception
    original_error::Exception
    func::Any
    types::Any
    suggestions::Vector{String}
end

function Base.showerror(io::IO, err::CompilationError)
    println(io, "StaticCompiler compilation failed for ", err.func, err.types)
    println(io)
    println(io, "Original error: ", err.original_error)

    if !isempty(err.suggestions)
        println(io)
        println(io, "Suggestions:")
        for suggestion in err.suggestions
            println(io, "  - ", suggestion)
        end
    end
end

function diagnose_error(err::Exception, func, types)
    suggestions = String[]
    err_str = string(err)
    err_lower = lowercase(err_str)

    # Type instability detection
    if occursin("did not infer to a concrete type", err_lower) ||
       occursin("union", err_lower) ||
       occursin("type.*not.*concrete", err_lower)
        push!(suggestions, "Use @code_warntype $func$types to identify type instabilities")
        push!(suggestions, "Ensure all code paths return the same concrete type")
        push!(suggestions, "Add type annotations to variables if needed")
    end

    # GC allocation detection
    if occursin("jl_alloc", err_str) || occursin("jl_gc", err_str)
        push!(suggestions, "Use StaticTools.MallocArray instead of Array")
        push!(suggestions, "Use StaticTools.MallocString instead of String")
        push!(suggestions, "Consider Bumper.jl for managed static memory allocation")
        push!(suggestions, "Use stack-allocated types like StaticArrays or Tuples")
    end

    # Runtime function calls
    if occursin("jl_", err_str) && !occursin("julia_", err_str)
        push!(suggestions, "Function calls Julia runtime (not allowed in static compilation)")
        push!(suggestions, "Add @device_override for stdlib functions that need replacement")
        push!(suggestions, "Inspect with static_code_llvm($func, $types) to find runtime calls")
    end

    # Error throwing
    if occursin("throw", err_lower) || occursin("error", err_lower)
        push!(suggestions, "Error handling requires @device_override")
        push!(suggestions, "Use @print_and_throw for static-friendly error messages")
        push!(suggestions, "See src/quirks.jl for examples of error overrides")
    end

    # Global variables
    if occursin("global", err_lower)
        push!(suggestions, "Global variables (except constants) are not supported")
        push!(suggestions, "Pass state through function arguments instead")
        push!(suggestions, "Use const global tuples or named tuples for constants")
    end

    # Return type issues
    if occursin("return", err_lower) && occursin("type", err_lower)
        push!(suggestions, "Ensure function returns a native type (Int, Float64, Ptr, etc.)")
        push!(suggestions, "Tuples and structs in return position may cause issues")
        push!(suggestions, "Consider returning values by pointer argument instead")
    end

    CompilationError(err, func, types, suggestions)
end
