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

    # Check type stability
    try
        tt = Base.to_tuple_type(types)
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
        if occursin("jl_alloc", fname)
            push!(issues, Issue(:error, :gc_allocation,
                "GC allocation detected: $fname",
                "Use StaticTools.MallocArray instead of Array"))
        end

        # Check for error throwing
        if occursin("jl_throw", fname)
            push!(issues, Issue(:error, :runtime_call,
                "Error throwing detected: $fname",
                "Add @device_override for error handling"))
        end

        # Check for other runtime calls
        if occursin("jl_", fname) && !occursin("julia_", fname)
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
