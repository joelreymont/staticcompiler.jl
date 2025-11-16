# Optimization Example: Automated Recommendations
# Shows how to get optimization suggestions

using StaticCompiler

# Example 1: Well-optimized function
println("=== Example 1: Well-Optimized Function ===\n")

good_func(x::Int) = x * 2 + 1

recs1 = recommend_optimizations(good_func, (Int,), verbose=true)

# Example 2: Function with issues
println("\n\n=== Example 2: Function with Optimization Opportunities ===\n")

# This function has type instability
function bad_func(x)
    if x > 0
        return x  # Returns Int
    else
        return "negative"  # Returns String - type instability!
    end
end

recs2 = recommend_optimizations(bad_func, (Int,), verbose=true)

# Example 3: Quick optimize (automated)
println("\n\n=== Example 3: Quick Optimize (Automated) ===\n")

simple_func(x::Int) = x * x

exe = quick_optimize(simple_func, (Int,), "/tmp", "quick_example")

println("\n✅ Done! Check the recommendations above to improve your code.")
