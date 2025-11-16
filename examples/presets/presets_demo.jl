#!/usr/bin/env julia

# Optimization Presets Demo
# Shows how to use predefined optimization configurations

using StaticCompiler

println("=== Optimization Presets Demo ===\n")

# Example function to compile
function calculate_fibonacci(n::Int)
    if n <= 1
        return n
    end
    a, b = 0, 1
    for _ in 2:n
        a, b = b, a + b
    end
    return b
end

# 1. List available presets
println("1. Available optimization presets:\n")
list_presets()

# 2. Compile with EMBEDDED preset
println("\n" * "="^70)
println("2. Compiling with EMBEDDED preset...")
println("   (Optimized for minimal binary size)")
println("="^70)

output_dir_embedded = mktempdir()
try
    result_embedded = compile_with_preset(
        calculate_fibonacci,
        (Int,),
        output_dir_embedded,
        "fib_embedded",
        :embedded,
        args=(30,),
        verbose=false
    )

    println("\n   Preset: EMBEDDED")
    println("   Binary size: $(format_bytes(result_embedded["binary_size"]))")
    if haskey(result_embedded, "compressed_size")
        println("   Compressed: $(format_bytes(result_embedded["compressed_size"]))")
        println("   Compression: $(round((1 - result_embedded["compression_ratio"]) * 100, digits=1))% reduction")
    end
    println("   Overall score: $(round(result_embedded["scores"]["overall"], digits=1))/100")
catch e
    println("   Skipped: $e")
finally
    rm(output_dir_embedded, recursive=true, force=true)
end

# 3. Compile with SERVERLESS preset
println("\n" * "="^70)
println("3. Compiling with SERVERLESS preset...")
println("   (Optimized for fast startup and small size)")
println("="^70)

output_dir_serverless = mktempdir()
try
    result_serverless = compile_with_preset(
        calculate_fibonacci,
        (Int,),
        output_dir_serverless,
        "fib_serverless",
        :serverless,
        args=(30,),
        verbose=false
    )

    println("\n   Preset: SERVERLESS")
    println("   Binary size: $(format_bytes(result_serverless["binary_size"]))")
    if haskey(result_serverless, "benchmark")
        println("   Performance: $(format_time(result_serverless["benchmark"]["median_time_ns"]))")
    end
    println("   Overall score: $(round(result_serverless["scores"]["overall"], digits=1))/100")
catch e
    println("   Skipped: $e")
finally
    rm(output_dir_serverless, recursive=true, force=true)
end

# 4. Compile with HPC preset
println("\n" * "="^70)
println("4. Compiling with HPC preset...")
println("   (Optimized for maximum performance)")
println("="^70)

output_dir_hpc = mktempdir()
try
    result_hpc = compile_with_preset(
        calculate_fibonacci,
        (Int,),
        output_dir_hpc,
        "fib_hpc",
        :hpc,
        args=(30,),
        verbose=false
    )

    println("\n   Preset: HPC")
    if haskey(result_hpc, "benchmark")
        println("   Performance: $(format_time(result_hpc["benchmark"]["median_time_ns"]))")
    end
    if haskey(result_hpc, "pgo")
        println("   PGO iterations: $(result_hpc["pgo"]["iterations"])")
        println("   PGO improvement: $(round(result_hpc["pgo"]["improvement_pct"], digits=1))%")
    end
    println("   Performance score: $(round(result_hpc["scores"]["performance"], digits=1))/100")
catch e
    println("   Skipped: $e")
finally
    rm(output_dir_hpc, recursive=true, force=true)
end

# 5. Compile with DESKTOP preset
println("\n" * "="^70)
println("5. Compiling with DESKTOP preset...")
println("   (Balanced optimization for general use)")
println("="^70)

output_dir_desktop = mktempdir()
try
    result_desktop = compile_with_preset(
        calculate_fibonacci,
        (Int,),
        output_dir_desktop,
        "fib_desktop",
        :desktop,
        args=(30,),
        verbose=false
    )

    println("\n   Preset: DESKTOP")
    println("   Binary size: $(format_bytes(result_desktop["binary_size"]))")
    if haskey(result_desktop, "benchmark")
        println("   Performance: $(format_time(result_desktop["benchmark"]["median_time_ns"]))")
    end
    println("   Overall score: $(round(result_desktop["scores"]["overall"], digits=1))/100")
catch e
    println("   Skipped: $e")
finally
    rm(output_dir_desktop, recursive=true, force=true)
end

# 6. Compile with DEVELOPMENT preset
println("\n" * "="^70)
println("6. Compiling with DEVELOPMENT preset...")
println("   (Fast compilation for debugging)")
println("="^70)

output_dir_dev = mktempdir()
try
    result_dev = compile_with_preset(
        calculate_fibonacci,
        (Int,),
        output_dir_dev,
        "fib_dev",
        :development,
        args=(30,),
        verbose=false
    )

    println("\n   Preset: DEVELOPMENT")
    println("   Binary size: $(format_bytes(result_dev["binary_size"]))")
    println("   Compilation time: $(result_dev["total_time_seconds"])s")
    println("   (No optimizations, debugging symbols preserved)")
catch e
    println("   Skipped: $e")
finally
    rm(output_dir_dev, recursive=true, force=true)
end

# 7. Compile with RELEASE preset
println("\n" * "="^70)
println("7. Compiling with RELEASE preset...")
println("   (Production-ready with all optimizations)")
println("="^70)

output_dir_release = mktempdir()
try
    result_release = compile_with_preset(
        calculate_fibonacci,
        (Int,),
        output_dir_release,
        "fib_release",
        :release,
        args=(30,),
        verbose=false
    )

    println("\n   Preset: RELEASE")
    println("   Binary size: $(format_bytes(result_release["binary_size"]))")
    if haskey(result_release, "benchmark")
        println("   Performance: $(format_time(result_release["benchmark"]["median_time_ns"]))")
    end
    println("   Security score: $(round(result_release["scores"]["security"], digits=1))/100")
    println("   Overall score: $(round(result_release["scores"]["overall"], digits=1))/100")
catch e
    println("   Skipped: $e")
finally
    rm(output_dir_release, recursive=true, force=true)
end

# 8. Compare multiple presets
println("\n" * "="^70)
println("8. Comparing presets...")
println("="^70)

comparison_dir = mktempdir()
try
    comparison = compare_presets(
        calculate_fibonacci,
        (Int,),
        (30,),
        comparison_dir,
        presets=[:embedded, :desktop, :hpc],
        verbose=false
    )

    println("\nComparison Results:")
    println("-"^70)

    for (preset_name, result) in sort(collect(comparison), by=x->string(x[1]))
        println("\n$(uppercase(string(preset_name))):")
        if haskey(result, "binary_size")
            println("  Binary size: $(format_bytes(result["binary_size"]))")
        end
        if haskey(result, "compressed_size")
            println("  Compressed: $(format_bytes(result["compressed_size"]))")
        end
        if haskey(result, "benchmark")
            println("  Performance: $(format_time(result["benchmark"]["median_time_ns"]))")
        end
        println("  Overall score: $(round(result["scores"]["overall"], digits=1))/100")
    end

    # Find best by overall score
    best = findmax(r -> r[2]["scores"]["overall"], comparison)
    println("\n✅ Best overall: $(uppercase(string(best[1][1])))")

catch e
    println("   Comparison skipped: $e")
finally
    rm(comparison_dir, recursive=true, force=true)
end

# Summary
println("\n" * "="^70)
println("PRESET SUMMARY")
println("="^70)
println()
println("Available Presets:")
println()
println("📦 EMBEDDED")
println("   • Minimal binary size (< 50KB target)")
println("   • UPX compression enabled")
println("   • LTO enabled")
println("   • Use for: IoT, embedded systems, firmware")
println()
println("⚡ SERVERLESS")
println("   • Small size + fast startup")
println("   • No UPX (avoids startup delay)")
println("   • Use for: AWS Lambda, Cloud Functions, edge computing")
println()
println("🚀 HPC")
println("   • Maximum performance")
println("   • PGO with 5 iterations")
println("   • Native CPU optimizations")
println("   • Use for: Scientific computing, data processing")
println()
println("💻 DESKTOP")
println("   • Balanced size and performance")
println("   • Good default for most applications")
println("   • Use for: CLI tools, GUI apps, general purpose")
println()
println("🔧 DEVELOPMENT")
println("   • Fast compilation")
println("   • Debugging symbols preserved")
println("   • No optimizations")
println("   • Use for: Active development, debugging")
println()
println("🎯 RELEASE")
println("   • Production-ready")
println("   • Comprehensive optimizations")
println("   • Security hardening")
println("   • Use for: Final releases, distribution")
println()
println("Usage:")
println("   compile_with_preset(func, types, path, name, :preset_name, args=args)")
println()
println("Comparison:")
println("   compare_presets(func, types, args, path, presets=[:embedded, :hpc])")
println()
