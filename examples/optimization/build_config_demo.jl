#!/usr/bin/env julia

# Build Configuration Demo
# This example demonstrates how to save and reuse build configurations

using StaticCompiler

println("=== Build Configuration Demo ===\n")

# Test function to compile
function test_function(x::Int)
    return x * x + 2 * x + 1
end

# Example 1: Create and save a size-optimized config
println("1️⃣  Creating size-optimized configuration...")
size_config = BuildConfig(
    profile_name = "SIZE",
    custom_cflags = String[],
    cache_enabled = true,
    strip_binary = true,
    upx_compression = true,
    upx_level = :best,
    name = "my_app",
    version = "1.0.0",
    description = "Size-optimized build for deployment"
)

config_dir = mktempdir()
size_config_file = joinpath(config_dir, "size_config.jls")
save_config(size_config, size_config_file)
println("   ✅ Saved to: $size_config_file")

# Example 2: Create and save a speed-optimized config
println("\n2️⃣  Creating speed-optimized configuration...")
speed_config = BuildConfig(
    profile_name = "SPEED",
    custom_cflags = ["-march=native"],
    cache_enabled = true,
    strip_binary = false,  # Keep symbols for profiling
    upx_compression = false,  # Don't compress for speed
    upx_level = :fast,
    name = "my_app",
    version = "1.0.0",
    description = "Speed-optimized build for performance"
)

speed_config_file = joinpath(config_dir, "speed_config.jls")
save_config(speed_config, speed_config_file)
println("   ✅ Saved to: $speed_config_file")

# Example 3: Load and use saved configuration
println("\n3️⃣  Loading saved configuration...")
loaded_config = load_config(size_config_file)
println("   Profile: $(loaded_config.profile_name)")
println("   Name: $(loaded_config.name)")
println("   Version: $(loaded_config.version)")
println("   Description: $(loaded_config.description)")
println("   Cache: $(loaded_config.cache_enabled)")
println("   Strip: $(loaded_config.strip_binary)")
println("   UPX: $(loaded_config.upx_compression)")

# Example 4: Compile with saved config
println("\n4️⃣  Compiling with saved configuration...")
workdir = mktempdir()
try
    exe_path = compile_with_config(test_function, (Int,), loaded_config, path=workdir)

    if isfile(exe_path)
        size_bytes = filesize(exe_path)
        size_kb = round(size_bytes / 1024, digits=1)
        println("   ✅ Compiled successfully!")
        println("   Path: $exe_path")
        println("   Size: $size_kb KB")

        # Test execution
        result = read(`$exe_path`, String)
        println("   ✅ Execution successful")
    end
catch e
    println("   ⚠️  Compilation skipped (may require additional tools)")
    println("   Error: $e")
end

# Example 5: Compare different configs
println("\n5️⃣  Configuration Comparison:")
println("\n   Size-Optimized Build:")
println("      Profile: $(size_config.profile_name)")
println("      Strip: $(size_config.strip_binary)")
println("      UPX: $(size_config.upx_compression) (level: $(size_config.upx_level))")
println("      Custom flags: $(isempty(size_config.custom_cflags) ? "none" : join(size_config.custom_cflags, " "))")

println("\n   Speed-Optimized Build:")
println("      Profile: $(speed_config.profile_name)")
println("      Strip: $(speed_config.strip_binary)")
println("      UPX: $(speed_config.upx_compression)")
println("      Custom flags: $(join(speed_config.custom_cflags, " "))")

# Summary
println("\n📊 Benefits of Build Configurations:")
println("   ✅ Reproducible builds across environments")
println("   ✅ Easy switching between optimization profiles")
println("   ✅ Version control friendly (save configs in git)")
println("   ✅ Team collaboration on build settings")
println("   ✅ CI/CD integration")

println("\n💡 Usage Tips:")
println("   - Save different configs for dev/staging/production")
println("   - Store configs in your project repo (.jls files)")
println("   - Use descriptive names and versions")
println("   - Document your configuration choices in description field")

# Cleanup
try
    rm(config_dir, recursive=true)
catch
end
