# Dependency minimization analysis
# Identifies unnecessary dependencies and suggests optimizations

"""
Dependency analysis report
"""
struct DependencyReport
    total_functions::Int
    unique_modules::Vector{String}
    module_sizes::Dict{String, Int}  # Estimated contribution to binary size
    unused_imports::Vector{String}
    specialization_count::Dict{String, Int}
    suggestions::Vector{String}
    bloat_score::Float64  # 0-100, lower is better
end

"""
    analyze_dependency_bloat(f, types; verbose=true)

Analyze function dependencies to identify bloat and optimization opportunities.

Detects:
- Which modules/packages are pulled in
- Approximate size contribution per module
- Over-specialized functions
- Potential dead code
- Suggestions for using @nospecialize

# Example
```julia
function my_func(x::Int, y::Float64)
    return x + Int(floor(y))
end

report = analyze_dependency_bloat(my_func, (Int, Float64))
```
"""
function analyze_dependency_bloat(f, types; verbose=true)
    total_funcs = 0
    modules = Set{String}()
    module_sizes = Dict{String, Int}()
    specializations = Dict{String, Int}()
    suggestions = String[]

    try
        # Get LLVM IR
        mod = static_llvm_module(f, types)

        # Analyze all functions in the module
        for func in LLVM.functions(mod)
            total_funcs += 1
            func_name = LLVM.name(func)

            # Extract module name from function name
            # Julia functions are named like: julia_func_123 or module_func_456
            if occursin("julia_", func_name)
                module_name = "Base"
            else
                # Try to extract module name
                parts = split(func_name, '_')
                if length(parts) >= 2
                    module_name = parts[1]
                else
                    module_name = "Unknown"
                end
            end

            push!(modules, module_name)

            # Count specializations
            base_name = replace(func_name, r"_\d+$" => "")
            specializations[base_name] = get(specializations, base_name, 0) + 1

            # Estimate function size (number of instructions)
            func_size = 0
            for bb in LLVM.blocks(func)
                for inst in LLVM.instructions(bb)
                    func_size += 1
                end
            end
            module_sizes[module_name] = get(module_sizes, module_name, 0) + func_size
        end

        # Generate suggestions based on findings
        # 1. Check for over-specialization
        over_specialized = filter(p -> p.second > 5, specializations)
        if !isempty(over_specialized)
            push!(suggestions, "Found $(length(over_specialized)) over-specialized functions")
            push!(suggestions, "Consider using @nospecialize on arguments that don't need type specialization")

            # Show top offenders
            sorted_specs = sort(collect(over_specialized), by=x->x.second, rev=true)
            for (fname, count) in sorted_specs[1:min(3, end)]
                push!(suggestions, "  • $(fname): $(count) specializations")
            end
        end

        # 2. Check for large module contributions
        sorted_sizes = sort(collect(module_sizes), by=x->x.second, rev=true)
        if length(sorted_sizes) > 0 && sorted_sizes[1].second > 1000
            top_module = sorted_sizes[1].first
            push!(suggestions, "Module '$top_module' contributes significantly to binary size")
            push!(suggestions, "Consider if all functionality from this module is necessary")
        end

        # 3. Check total function count
        if total_funcs > 100
            push!(suggestions, "High function count ($(total_funcs)) detected")
            push!(suggestions, "Consider refactoring to reduce compiled code size")
        end

        # 4. Specific optimization suggestions
        if any(m -> occursin("LinearAlgebra", m), modules)
            push!(suggestions, "LinearAlgebra detected - ensure you're using concrete array types")
        end

        if any(m -> occursin("Statistics", m), modules)
            push!(suggestions, "Statistics detected - consider custom implementations for simple operations")
        end

    catch e
        @debug "Dependency analysis failed" exception=e
    end

    # Calculate bloat score (0-100, lower is better)
    bloat_score = min(100.0, (
        (total_funcs / 10.0) +  # 10 functions = 1 point
        (length(modules) * 5.0) +  # Each module = 5 points
        (length(specializations) / 2.0)  # 2 specializations = 1 point
    ))

    unused = _detect_unused_imports(f, types)

    report = DependencyReport(
        total_funcs,
        collect(modules),
        module_sizes,
        unused,
        specializations,
        suggestions,
        bloat_score
    )

    if verbose
        print_dependency_report(report)
    end

    return report
end

"""
Detect potentially unused imports (heuristic-based)
"""
function _detect_unused_imports(f, types)
    # This is a placeholder for more sophisticated analysis
    # In practice, we'd need to analyze which functions are actually called
    # vs what's imported
    return String[]
end

"""
Print dependency analysis report
"""
function print_dependency_report(report::DependencyReport)
    println("\n" * "="^70)
    println("DEPENDENCY ANALYSIS")
    println("="^70)

    println("\n📊 BLOAT SCORE: $(round(report.bloat_score, digits=1))/100")
    println("   (Lower is better)")

    println("\n📦 OVERVIEW:")
    println("   Total Functions: $(report.total_functions)")
    println("   Unique Modules: $(length(report.unique_modules))")

    if !isempty(report.unique_modules)
        println("\n📚 MODULES DETECTED:")
        for (i, module_name) in enumerate(sort(report.unique_modules)[1:min(10, end)])
            size_estimate = get(report.module_sizes, module_name, 0)
            println("   $(i). $module_name (~$(size_estimate) instructions)")
        end
        if length(report.unique_modules) > 10
            println("   ... and $(length(report.unique_modules) - 10) more")
        end
    end

    if !isempty(report.specialization_count)
        # Show most specialized functions
        sorted = sort(collect(report.specialization_count), by=x->x.second, rev=true)
        top_specialized = sorted[1:min(5, end)]

        if any(p -> p.second > 3, top_specialized)
            println("\n⚠️  OVER-SPECIALIZED FUNCTIONS:")
            for (fname, count) in top_specialized
                if count > 3
                    println("   • $(fname): $(count) versions")
                end
            end
        end
    end

    if !isempty(report.unused_imports)
        println("\n🗑️  POTENTIALLY UNUSED IMPORTS:")
        for import_name in report.unused_imports[1:min(5, end)]
            println("   • $import_name")
        end
    end

    if !isempty(report.suggestions)
        println("\n💡 OPTIMIZATION SUGGESTIONS:")
        for (i, suggestion) in enumerate(report.suggestions)
            if !startswith(suggestion, "  ")  # Don't number sub-items
                println("   $(i). $suggestion")
            else
                println("   $suggestion")
            end
        end
    end

    if report.bloat_score < 30
        println("\n✅ Code appears well-optimized with minimal dependencies")
    elseif report.bloat_score < 60
        println("\n⚠️  Moderate dependency bloat detected - review suggestions above")
    else
        println("\n❌ Significant dependency bloat - strongly recommend optimization")
    end

    println("\n📝 TIPS:")
    println("   • Use concrete types instead of abstract types")
    println("   • Add @nospecialize to arguments that don't need type-specific code")
    println("   • Avoid pulling in large stdlib modules for simple operations")
    println("   • Consider StaticTools.jl alternatives to Base functions")

    println("="^70)
end

"""
    suggest_nospecialize(f, types)

Suggest where to add @nospecialize annotations.

# Example
```julia
function my_func(x::Int, y)  # y is not type-annotated
    return x + 1
end

suggestions = suggest_nospecialize(my_func, (Int, Any))
```
"""
function suggest_nospecialize(f, types; verbose=true)
    suggestions = String[]

    try
        # Get method signature
        methods_list = methods(f, types)

        if length(methods_list) == 0
            if verbose
                println("No methods found for the given signature")
            end
            return suggestions
        end

        method = first(methods_list)
        sig = method.sig

        # Analyze type parameters
        if sig isa UnionAll || sig isa DataType
            if verbose
                println("\n🔍 Analyzing method signature...")
                println("   Method: $method")
            end

            # Check for abstract types or Any
            for (i, T) in enumerate(types)
                if T == Any || isabstracttype(T)
                    push!(suggestions, "Argument $i has type $T - consider @nospecialize if not performance-critical")
                end
            end
        end

        if isempty(suggestions)
            push!(suggestions, "All argument types are concrete - specialization is appropriate")
        end

        if verbose
            println("\n💡 @nospecialize Suggestions:")
            for suggestion in suggestions
                println("   • $suggestion")
            end
        end

    catch e
        @debug "Failed to analyze for @nospecialize" exception=e
    end

    return suggestions
end

"""
    estimate_dependency_size(module_name::String, report::DependencyReport)

Estimate the size contribution of a specific module.

Returns the number of instructions attributed to that module.
"""
function estimate_dependency_size(module_name::String, report::DependencyReport)
    return get(report.module_sizes, module_name, 0)
end

"""
    compare_dependency_impact(f1, types1, f2, types2)

Compare the dependency impact of two different implementations.

Useful for evaluating refactoring choices.

# Example
```julia
function impl1(x)
    return sin(x) + cos(x)  # Uses Base math
end

function impl2(x)
    # Custom implementation
    return custom_sin(x) + custom_cos(x)
end

comparison = compare_dependency_impact(impl1, (Float64,), impl2, (Float64,))
```
"""
function compare_dependency_impact(f1, types1, f2, types2; verbose=true)
    println("\n🔬 Comparing Dependency Impact\n")

    println("Analyzing implementation 1...")
    report1 = analyze_dependency_bloat(f1, types1, verbose=false)

    println("Analyzing implementation 2...")
    report2 = analyze_dependency_bloat(f2, types2, verbose=false)

    if verbose
        println("\n" * "="^70)
        println("DEPENDENCY COMPARISON")
        println("="^70)

        println("\n📊 Implementation 1:")
        println("   Functions: $(report1.total_functions)")
        println("   Modules: $(length(report1.unique_modules))")
        println("   Bloat Score: $(round(report1.bloat_score, digits=1))")

        println("\n📊 Implementation 2:")
        println("   Functions: $(report2.total_functions)")
        println("   Modules: $(length(report2.unique_modules))")
        println("   Bloat Score: $(round(report2.bloat_score, digits=1))")

        println("\n📈 Difference:")
        func_diff = report2.total_functions - report1.total_functions
        module_diff = length(report2.unique_modules) - length(report1.unique_modules)
        bloat_diff = report2.bloat_score - report1.bloat_score

        println("   Functions: $(func_diff > 0 ? "+" : "")$(func_diff)")
        println("   Modules: $(module_diff > 0 ? "+" : "")$(module_diff)")
        println("   Bloat Score: $(bloat_diff > 0 ? "+" : "")$(round(bloat_diff, digits=1))")

        if bloat_diff < -5
            println("\n✅ Implementation 2 is significantly leaner")
        elseif bloat_diff > 5
            println("\n⚠️  Implementation 1 is leaner")
        else
            println("\n➡️  Both implementations have similar dependency impact")
        end

        println("="^70)
    end

    return (report1=report1, report2=report2)
end

export DependencyReport, analyze_dependency_bloat, suggest_nospecialize,
       estimate_dependency_size, compare_dependency_impact
