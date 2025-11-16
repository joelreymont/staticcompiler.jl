# Optimization Example: Binary Size Reduction
# Shows how to minimize binary size

using StaticCompiler

# Simple test function
test_func() = 42

println("=== Binary Size Optimization Demo ===\n")

workdir = mktempdir()

# 1. Standard compilation (no optimization)
println("1️⃣  Standard compilation:")
exe_std = compile_executable(test_func, (), workdir, "standard", strip_binary=false)
size_std = filesize(exe_std) / 1024
println("   Size: $(round(size_std, digits=1)) KB")

# 2. With symbol stripping
println("\n2️⃣  With symbol stripping:")
exe_strip = compile_executable(test_func, (), workdir, "stripped", strip_binary=true)
size_strip = filesize(exe_strip) / 1024
reduction1 = (1 - size_strip/size_std) * 100
println("   Size: $(round(size_strip, digits=1)) KB")
println("   Reduction: $(round(reduction1, digits=1))%")

# 3. With SIZE optimization profile
println("\n3️⃣  With SIZE profile:")
exe_opt = compile_executable_optimized(test_func, (), workdir, "optimized",
                                       profile=PROFILE_SIZE)
size_opt = filesize(exe_opt) / 1024
reduction2 = (1 - size_opt/size_std) * 100
println("   Size: $(round(size_opt, digits=1)) KB")
println("   Reduction: $(round(reduction2, digits=1))%")

# 4. With UPX compression (if available)
avail, version = test_upx_available()
if avail
    println("\n4️⃣  With UPX compression:")
    exe_upx = compile_executable(test_func, (), workdir, "compressed", strip_binary=false)
    size_before = filesize(exe_upx) / 1024

    compress_with_upx(exe_upx, level=:best)

    size_upx = filesize(exe_upx) / 1024
    reduction3 = (1 - size_upx/size_std) * 100
    println("   Size: $(round(size_upx, digits=1)) KB")
    println("   Reduction: $(round(reduction3, digits=1))%")

    println("\n📊 Total size reduction: $(round(size_std, digits=1)) KB → $(round(size_upx, digits=1)) KB ($(round(reduction3, digits=1))%)")
else
    println("\n⚠️  UPX not available. Install with:")
    println("   Ubuntu: sudo apt-get install upx-ucl")
    println("   macOS: brew install upx")
end
