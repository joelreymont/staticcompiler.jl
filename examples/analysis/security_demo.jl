#!/usr/bin/env julia

# Security Analysis Demo
# This example demonstrates how to detect potential security issues

using StaticCompiler

println("=== Security Analysis Demo ===\n")

# Example 1: Safe bounded access
println("1️⃣  Safe bounded access:")
function safe_access(arr::Vector{Int}, idx::Int)
    if idx >= 1 && idx <= length(arr)
        return arr[idx]
    end
    return 0
end

report1 = analyze_security(safe_access, (Vector{Int}, Int), verbose=false)
println("   Security Score: $(round(report1.security_score, digits=1))/100")
println("   Issues Found: $(length(report1.issues))")

# Example 2: Potentially unsafe access
println("\n2️⃣  Unchecked array access:")
function unchecked_access(arr::Vector{Int}, idx::Int)
    return arr[idx]  # No bounds checking!
end

report2 = analyze_security(unchecked_access, (Vector{Int}, Int), verbose=false)
println("   Security Score: $(round(report2.security_score, digits=1))/100")
println("   Issues Found: $(length(report2.issues))")
if !isempty(report2.issues)
    for (i, issue) in enumerate(report2.issues[1:min(2, end)])
        println("      $(i). $(issue.category): $(issue.description)")
    end
end

# Example 3: Integer overflow risk
println("\n3️⃣  Integer arithmetic:")
function int_multiply(a::Int32, b::Int32)
    return a * b  # Could overflow!
end

report3 = analyze_security(int_multiply, (Int32, Int32), verbose=false)
println("   Security Score: $(round(report3.security_score, digits=1))/100")
println("   Issues Found: $(length(report3.issues))")
if !isempty(report3.issues)
    for issue in report3.issues[1:min(2, end)]
        println("      - $(issue.category)")
    end
end

# Example 4: Safe with bounds checking
println("\n4️⃣  Safe with @boundscheck:")
function bounds_safe(arr::Vector{Int})
    total = 0
    for i in 1:length(arr)
        @boundscheck checkbounds(arr, i)
        total += arr[i]
    end
    return total
end

report4 = analyze_security(bounds_safe, (Vector{Int},), verbose=false)
println("   Security Score: $(round(report4.security_score, digits=1))/100")
println("   Issues Found: $(length(report4.issues))")

# Summary
println("\n📊 Security Score Comparison:")
println("   Safe access:      $(round(report1.security_score, digits=1))/100")
println("   Unchecked access: $(round(report2.security_score, digits=1))/100")
println("   Integer ops:      $(round(report3.security_score, digits=1))/100")
println("   Bounds-checked:   $(round(report4.security_score, digits=1))/100")

println("\n🔒 Best Practices:")
println("   - Always validate array indices before access")
println("   - Use @boundscheck for explicit bounds checking")
println("   - Be careful with integer arithmetic overflow")
println("   - Avoid unsafe pointer operations in production code")
