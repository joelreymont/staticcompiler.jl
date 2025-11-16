#!/usr/bin/env julia

# Interactive Optimization Wizard Demo
# This example demonstrates the interactive optimization wizard

using StaticCompiler

println("=== Optimization Wizard Demo ===\n")

# Example function to compile
function calculate_sum(arr::Vector{Float64})
    total = 0.0
    for i in 1:length(arr)
        total += arr[i]
    end
    return total
end

# Example 1: Non-interactive wizard with defaults
println("1️⃣  Non-interactive wizard (using defaults):")
config1 = optimization_wizard(calculate_sum, (Vector{Float64},), interactive=false)
println("   Priority: $(config1.priority)")
println("   Deployment: $(config1.deployment)")
println("   Profile: $(recommended_profile(config1))")

# Example 2: Quick wizard for size optimization
println("\n2️⃣  Quick wizard (size-optimized):")
workdir = mktempdir()
try
    exe = quick_wizard(calculate_sum, (Vector{Float64},), priority=:size, path=workdir, name="sum_size")
    if isfile(exe)
        size_kb = round(filesize(exe) / 1024, digits=1)
        println("   ✅ Compiled successfully!")
        println("   Size: $size_kb KB")
    end
catch e
    println("   ⚠️  Compilation skipped: $e")
end

# Example 3: Quick wizard for speed optimization
println("\n3️⃣  Quick wizard (speed-optimized):")
try
    exe = quick_wizard(calculate_sum, (Vector{Float64},), priority=:speed, path=workdir, name="sum_speed")
    if isfile(exe)
        size_kb = round(filesize(exe) / 1024, digits=1)
        println("   ✅ Compiled successfully!")
        println("   Size: $size_kb KB")
    end
catch e
    println("   ⚠️  Compilation skipped: $e")
end

# Example 4: Manual configuration
println("\n4️⃣  Manual wizard configuration:")
config_manual = WizardConfig(calculate_sum, (Vector{Float64},))
config_manual.priority = :balanced
config_manual.deployment = :production
config_manual.requires_strip = true
config_manual.requires_upx = false

println("   Priority: $(config_manual.priority)")
println("   Deployment: $(config_manual.deployment)")
println("   Strip: $(config_manual.requires_strip)")
println("   UPX: $(config_manual.requires_upx)")

# Summary
println("\n📊 Wizard Benefits:")
println("   ✅ No need to understand all optimization flags")
println("   ✅ Guided decision-making process")
println("   ✅ Automatic profile selection")
println("   ✅ Size budget enforcement")
println("   ✅ Platform-specific optimizations")

println("\n💡 For interactive mode:")
println("   Run: config = optimization_wizard(my_func, (types,))")
println("   The wizard will ask you questions to guide optimization choices")

# Cleanup
try
    rm(workdir, recursive=true)
catch
end
