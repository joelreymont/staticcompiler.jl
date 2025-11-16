#!/usr/bin/env julia

# Memory Layout Analysis Demo
# This example demonstrates how to optimize struct memory layouts

using StaticCompiler

println("=== Memory Layout Optimization Demo ===\n")

# Example 1: Poorly ordered struct (lots of padding)
println("1️⃣  Poorly ordered struct:")
struct BadLayout
    a::Int8      # 1 byte + 7 bytes padding
    b::Int64     # 8 bytes
    c::Int8      # 1 byte + 7 bytes padding
    d::Int64     # 8 bytes
end

report1 = analyze_memory_layout(BadLayout, verbose=false)
println("   Total Size: $(report1.total_size) bytes")
println("   Padding: $(report1.padding_bytes) bytes ($(round(report1.padding_bytes/report1.total_size*100, digits=1))% wasted)")
println("   Cache Efficiency: $(round(report1.cache_efficiency, digits=1))%")

# Example 2: Well-ordered struct (minimal padding)
println("\n2️⃣  Well-ordered struct:")
struct GoodLayout
    b::Int64     # 8 bytes
    d::Int64     # 8 bytes
    a::Int8      # 1 byte
    c::Int8      # 1 byte
    # Only 6 bytes padding at end
end

report2 = analyze_memory_layout(GoodLayout, verbose=false)
println("   Total Size: $(report2.total_size) bytes")
println("   Padding: $(report2.padding_bytes) bytes ($(round(report2.padding_bytes/report2.total_size*100, digits=1))% wasted)")
println("   Cache Efficiency: $(round(report2.cache_efficiency, digits=1))%")

# Example 3: Complex struct
println("\n3️⃣  Complex struct:")
struct ComplexLayout
    flag1::Bool      # 1 byte
    value1::Float64  # 8 bytes
    flag2::Bool      # 1 byte
    value2::Float64  # 8 bytes
    counter::Int32   # 4 bytes
end

report3 = analyze_memory_layout(ComplexLayout, verbose=false)
println("   Total Size: $(report3.total_size) bytes")
println("   Padding: $(report3.padding_bytes) bytes")
if report3.potential_savings > 0
    println("   Potential Savings: $(report3.potential_savings) bytes")
    println("   Suggested Order: $(join(report3.suggested_order, ", "))")
end

# Example 4: Already optimal
println("\n4️⃣  Already optimal struct:")
struct OptimalLayout
    large1::Int64    # 8 bytes
    large2::Int64    # 8 bytes
    medium::Int32    # 4 bytes
    small1::Int16    # 2 bytes
    small2::Int8     # 1 byte
    small3::Int8     # 1 byte
    # Perfectly packed!
end

report4 = analyze_memory_layout(OptimalLayout, verbose=false)
println("   Total Size: $(report4.total_size) bytes")
println("   Padding: $(report4.padding_bytes) bytes")
println("   Cache Efficiency: $(round(report4.cache_efficiency, digits=1))%")

# Summary
println("\n📊 Size Comparison:")
println("   Bad Layout:     $(report1.total_size) bytes ($(report1.padding_bytes) bytes padding)")
println("   Good Layout:    $(report2.total_size) bytes ($(report2.padding_bytes) bytes padding)")
println("   Complex Layout: $(report3.total_size) bytes ($(report3.padding_bytes) bytes padding)")
println("   Optimal Layout: $(report4.total_size) bytes ($(report4.padding_bytes) bytes padding)")

savings = report1.total_size - report2.total_size
println("\n💾 Memory Savings: $(savings) bytes ($(round(savings/report1.total_size*100, digits=1))% reduction)")

println("\n💡 Tips for Optimal Layouts:")
println("   - Order fields from largest to smallest")
println("   - Group fields of similar sizes together")
println("   - Keep frequently accessed fields in the same cache line (64 bytes)")
println("   - Use analyze_memory_layout() to verify your struct layouts")
