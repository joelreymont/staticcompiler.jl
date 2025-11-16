#!/usr/bin/env julia

# Dependency Bloat Analysis Demo
# This example demonstrates how to analyze and minimize dependency bloat

using StaticCompiler

println("=== Dependency Bloat Analysis Demo ===\n")

# Example 1: Simple function with minimal dependencies
println("1️⃣  Simple arithmetic function:")
function simple_calc(x::Int, y::Int)
    return x * 2 + y
end

report1 = analyze_dependency_bloat(simple_calc, (Int, Int), verbose=false)
println("   Total Functions: $(report1.total_functions)")
println("   Unique Modules: $(length(report1.unique_modules))")
println("   Bloat Score: $(round(report1.bloat_score, digits=1))/100")

# Example 2: Function using more stdlib
println("\n2️⃣  Function using Float operations:")
function float_calc(x::Float64, y::Float64)
    return sin(x) + cos(y) + sqrt(x * y)
end

report2 = analyze_dependency_bloat(float_calc, (Float64, Float64), verbose=false)
println("   Total Functions: $(report2.total_functions)")
println("   Unique Modules: $(length(report2.unique_modules))")
println("   Bloat Score: $(round(report2.bloat_score, digits=1))/100")

# Example 3: Over-specialized function
println("\n3️⃣  Analyzing function specialization:")
function generic_add(x, y)  # No type annotations = many specializations
    return x + y
end

suggestions = suggest_nospecialize(generic_add, (Any, Any), verbose=false)
println("   Specialization Suggestions:")
for suggestion in suggestions
    println("      • $suggestion")
end

# Example 4: Comparing two implementations
println("\n4️⃣  Comparing implementations:")

# Implementation 1: Using stdlib
function impl_stdlib(x::Float64)
    return sin(x) + cos(x)
end

# Implementation 2: Simple custom version (hypothetical)
function impl_custom(x::Float64)
    # In practice, you might use custom implementations
    # or StaticTools alternatives
    return x * x + x  # Simplified for demo
end

println("   Comparing stdlib vs custom implementations...")
comparison = compare_dependency_impact(impl_stdlib, (Float64,), impl_custom, (Float64,), verbose=false)

println("\n   Implementation 1 (stdlib):")
println("      Functions: $(comparison.report1.total_functions)")
println("      Bloat Score: $(round(comparison.report1.bloat_score, digits=1))")

println("\n   Implementation 2 (custom):")
println("      Functions: $(comparison.report2.total_functions)")
println("      Bloat Score: $(round(comparison.report2.bloat_score, digits=1))")

diff_score = comparison.report2.bloat_score - comparison.report1.bloat_score
if diff_score < 0
    println("\n   ✅ Custom implementation is leaner by $(round(abs(diff_score), digits=1)) points")
else
    println("\n   ⚠️  Stdlib implementation is leaner by $(round(diff_score, digits=1)) points")
end

# Example 5: Detailed analysis
println("\n5️⃣  Detailed dependency analysis:")
function detailed_example(x::Int, y::Float64)
    result = Float64(x) + floor(y)
    return Int(result)
end

report_detailed = analyze_dependency_bloat(detailed_example, (Int, Float64), verbose=false)

println("\n   📚 Modules Detected:")
for (i, mod_name) in enumerate(sort(report_detailed.unique_modules)[1:min(5, end)])
    size_est = estimate_dependency_size(mod_name, report_detailed)
    println("      $(i). $mod_name (~$(size_est) instructions)")
end

if !isempty(report_detailed.suggestions)
    println("\n   💡 Optimization Suggestions:")
    for (i, suggestion) in enumerate(report_detailed.suggestions[1:min(3, end)])
        if !startswith(suggestion, "  ")
            println("      $(i). $suggestion")
        end
    end
end

# Summary
println("\n📊 Dependency Analysis Benefits:")
println("   ✅ Identify bloat from unused modules")
println("   ✅ Detect over-specialized functions")
println("   ✅ Compare implementation approaches")
println("   ✅ Get actionable optimization suggestions")
println("   ✅ Estimate size contribution per module")

println("\n💡 Optimization Tips:")
println("   • Use concrete types instead of Any")
println("   • Add @nospecialize for generic arguments")
println("   • Consider StaticTools.jl alternatives to Base")
println("   • Avoid pulling in heavy stdlib for simple operations")
println("   • Compare bloat scores when refactoring")

println("\n🎯 Bloat Score Guide:")
println("   0-30:   Excellent (lean code)")
println("   30-60:  Good (moderate dependencies)")
println("   60-100: Poor (significant bloat, optimize!)")
