# Compilability checker for static compilation

struct Issue
    severity::Symbol  # :error, :warning
    category::Symbol  # :type_instability, :gc_allocation, :runtime_call
    message::String
    suggestion::String
end

struct CompilabilityReport
    compilable::Bool
    issues::Vector{Issue}
end

"""
    check_compilable(f, types; verbose=true)

Check if a function can be statically compiled.

Returns a CompilabilityReport with issues and suggestions.

# Example
```julia
f(x) = x + 1
report = check_compilable(f, (Int,))
```
"""
function check_compilable(f, types; verbose=true)
    issues = Issue[]

    # Check for closures
    if applicable(f, types...)
        # Check if function is a closure (has captured variables)
        # Closures have numeric names like #1, #2, etc. or contain captured variables
        fname = string(typeof(f).name.name)
        has_captured = fieldcount(typeof(f)) > 0 && !isempty(fieldnames(typeof(f)))
        is_anonymous = startswith(fname, "#") || occursin("##", fname)

        if is_anonymous && has_captured
            # This is a closure with captured variables
            push!(issues, Issue(:error, :closure,
                "Closures with captured variables are not supported",
                "Refactor to pass all needed values as function arguments"))
        end
    end

    # Check type stability
    try
        tt = Base.to_tuple_type(types)

        # Check for abstract argument types
        for (i, T) in enumerate(tt.parameters)
            if !isconcretetype(T) && T !== Any
                push!(issues, Issue(:warning, :abstract_argument,
                    "Argument $i has abstract type $T",
                    "Use concrete types for all arguments (e.g., Int64 instead of Integer)"))
            elseif T === Any
                push!(issues, Issue(:error, :dynamic_dispatch,
                    "Argument $i has type Any which causes dynamic dispatch",
                    "Specify concrete types to enable static compilation"))
            end
        end

        rt = last(only(static_code_typed(f, tt)))
        if !isconcretetype(rt)
            push!(issues, Issue(:error, :type_instability,
                "Return type $rt is not concrete",
                "Use @code_warntype to identify type instabilities"))
        end
    catch e
        push!(issues, Issue(:error, :inference,
            "Type inference failed: $e",
            "Check function signature and ensure types are valid"))
    end

    # Check LLVM IR for problematic patterns
    try
        mod = static_llvm_module(f, types)
        llvm_issues = check_llvm_module(mod)
        append!(issues, llvm_issues)
    catch e
        # If LLVM generation fails, we already have the error
    end

    compilable = all(i.severity != :error for i in issues)
    report = CompilabilityReport(compilable, issues)

    if verbose
        print_report(report)
    end

    return report
end

function check_llvm_module(mod)
    issues = Issue[]

    for func in LLVM.functions(mod)
        fname = LLVM.name(func)

        # Check for GC allocations
        if occursin("jl_alloc", fname) || occursin("jl_gc", fname)
            push!(issues, Issue(:error, :gc_allocation,
                "GC allocation detected: $fname",
                "Use StaticTools.MallocArray instead of Array"))
        end

        # Check for error throwing
        if occursin("jl_throw", fname) || occursin("jl_error", fname)
            push!(issues, Issue(:error, :runtime_call,
                "Error throwing detected: $fname",
                "Add @device_override for error handling"))
        end

        # Check for dynamic dispatch indicators
        if occursin("jl_apply", fname) || occursin("jl_invoke", fname)
            push!(issues, Issue(:error, :dynamic_dispatch,
                "Dynamic dispatch detected: $fname",
                "Ensure all types are concrete to avoid runtime dispatch"))
        end

        # Check for I/O operations
        if occursin("jl_uv_", fname) || occursin("jl_iolock", fname)
            push!(issues, Issue(:error, :io_operation,
                "I/O operation detected: $fname",
                "I/O is not supported in static compilation"))
        end

        # Check for global variable access
        if occursin("jl_get_global", fname) || occursin("jl_set_global", fname)
            push!(issues, Issue(:error, :global_access,
                "Global variable access detected: $fname",
                "Pass values as function arguments instead"))
        end

        # Check for other runtime calls
        if occursin("jl_", fname) && !occursin("julia_", fname) &&
           !any(x -> occursin(x, fname), ["jl_alloc", "jl_throw", "jl_apply", "jl_invoke", "jl_uv_", "jl_get_global"])
            push!(issues, Issue(:warning, :runtime_call,
                "Julia runtime call: $fname",
                "May require @device_override or refactoring"))
        end
    end

    return issues
end

function print_report(report::CompilabilityReport)
    if report.compilable
        println("Function appears compilable")
    else
        println("Function is NOT compilable")
    end

    if !isempty(report.issues)
        println()
        println("Issues found:")
        for issue in report.issues
            symbol = issue.severity == :error ? "[ERROR]" : "[WARNING]"
            println("  $symbol $(issue.category): $(issue.message)")
            println("    -> $(issue.suggestion)")
        end
    end
end

export check_compilable, CompilabilityReport
