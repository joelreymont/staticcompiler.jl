# Optimization Presets
# Predefined configurations for common optimization scenarios

"""
    OptimizationPreset

Predefined optimization configuration for common use cases.

# Fields
- `name::Symbol` - Preset identifier
- `description::String` - What this preset optimizes for
- `optimization_profile::Symbol` - Which OptimizationProfile to use
- `build_config::Union{BuildConfig, Nothing}` - Build configuration
- `wizard_config::Union{WizardConfig, Nothing}` - Wizard configuration
- `pgo_config::Union{PGOConfig, Nothing}` - PGO configuration
- `ci_config::Union{CIConfig, Nothing}` - CI configuration
- `use_upx::Bool` - Whether to use UPX compression
- `strip_binary::Bool` - Whether to strip symbols
- `enable_lto::Bool` - Whether to enable link-time optimization
- `benchmark_enabled::Bool` - Whether to run benchmarks
- `recommended_for::Vector{String}` - Use case recommendations
"""
struct OptimizationPreset
    name::Symbol
    description::String
    optimization_profile::Symbol
    build_config::Union{BuildConfig, Nothing}
    wizard_config::Union{WizardConfig, Nothing}
    pgo_config::Union{PGOConfig, Nothing}
    ci_config::Union{CIConfig, Nothing}
    use_upx::Bool
    strip_binary::Bool
    enable_lto::Bool
    benchmark_enabled::Bool
    recommended_for::Vector{String}
end

"""
    PRESET_EMBEDDED

Optimized for embedded systems and IoT devices.
Focuses on minimal binary size and memory footprint.
"""
const PRESET_EMBEDDED = OptimizationPreset(
    :embedded,
    "Minimal binary size for embedded systems and IoT devices",
    :PROFILE_SIZE_LTO,
    BuildConfig(
        optimization_profile = :PROFILE_SIZE_LTO,
        strip_binary = true,
        use_upx = true,
        upx_level = 9,
        enable_lto = true,
        compile_for_size = true,
        optimization_flags = ["-Os", "-flto"]
    ),
    WizardConfig(
        priority = :size,
        max_binary_size_kb = 50,
        interactive = false,
        enable_upx = true,
        strip_symbols = true
    ),
    PGOConfig(
        target_metric = :size,
        iterations = 2,
        benchmark_samples = 20
    ),
    CIConfig(
        max_binary_size_kb = 100,
        min_performance_score = 50.0,
        fail_on_allocations = true
    ),
    true,   # use_upx
    true,   # strip_binary
    true,   # enable_lto
    false,  # benchmark_enabled
    [
        "Embedded systems",
        "IoT devices",
        "Microcontrollers",
        "Resource-constrained environments",
        "Firmware"
    ]
)

"""
    PRESET_SERVERLESS

Optimized for serverless/FaaS platforms.
Balances small size with fast startup time.
"""
const PRESET_SERVERLESS = OptimizationPreset(
    :serverless,
    "Fast startup and small size for serverless/FaaS platforms",
    :PROFILE_SIZE,
    BuildConfig(
        optimization_profile = :PROFILE_SIZE,
        strip_binary = true,
        use_upx = false,  # UPX can slow startup
        enable_lto = false,
        compile_for_size = true,
        optimization_flags = ["-O2"]
    ),
    WizardConfig(
        priority = :balanced,
        max_binary_size_kb = 500,
        interactive = false,
        enable_upx = false,
        strip_symbols = true
    ),
    PGOConfig(
        target_metric = :balanced,
        iterations = 3,
        benchmark_samples = 30
    ),
    CIConfig(
        max_binary_size_kb = 1000,
        min_performance_score = 70.0,
        fail_on_allocations = false
    ),
    false,  # use_upx
    true,   # strip_binary
    false,  # enable_lto
    true,   # benchmark_enabled
    [
        "AWS Lambda",
        "Google Cloud Functions",
        "Azure Functions",
        "Serverless platforms",
        "Edge computing"
    ]
)

"""
    PRESET_HPC

Optimized for high-performance computing.
Maximizes execution speed regardless of binary size.
"""
const PRESET_HPC = OptimizationPreset(
    :hpc,
    "Maximum performance for high-performance computing",
    :PROFILE_AGGRESSIVE,
    BuildConfig(
        optimization_profile = :PROFILE_AGGRESSIVE,
        strip_binary = false,
        use_upx = false,
        enable_lto = true,
        compile_for_size = false,
        optimization_flags = ["-O3", "-flto", "-march=native", "-mtune=native"]
    ),
    WizardConfig(
        priority = :speed,
        max_binary_size_kb = 10000,  # 10MB OK for HPC
        interactive = false,
        enable_upx = false,
        strip_symbols = false
    ),
    PGOConfig(
        target_metric = :speed,
        iterations = 5,
        benchmark_samples = 100,
        improvement_threshold = 1.0
    ),
    CIConfig(
        max_binary_size_kb = 50000,
        min_performance_score = 90.0,
        fail_on_allocations = true,
        min_security_score = 50.0
    ),
    false,  # use_upx
    false,  # strip_binary
    true,   # enable_lto
    true,   # benchmark_enabled
    [
        "Scientific computing",
        "Numerical simulations",
        "Data processing",
        "Machine learning inference",
        "Computational research"
    ]
)

"""
    PRESET_DESKTOP

Balanced optimization for desktop applications.
Good performance with reasonable binary size.
"""
const PRESET_DESKTOP = OptimizationPreset(
    :desktop,
    "Balanced optimization for desktop applications",
    :PROFILE_SPEED,
    BuildConfig(
        optimization_profile = :PROFILE_SPEED,
        strip_binary = true,
        use_upx = false,
        enable_lto = false,
        compile_for_size = false,
        optimization_flags = ["-O2"]
    ),
    WizardConfig(
        priority = :balanced,
        max_binary_size_kb = 5000,
        interactive = false,
        enable_upx = false,
        strip_symbols = true
    ),
    PGOConfig(
        target_metric = :balanced,
        iterations = 3,
        benchmark_samples = 50
    ),
    CIConfig(
        max_binary_size_kb = 10000,
        min_performance_score = 75.0,
        min_security_score = 80.0
    ),
    false,  # use_upx
    true,   # strip_binary
    false,  # enable_lto
    true,   # benchmark_enabled
    [
        "Desktop applications",
        "GUI applications",
        "Command-line tools",
        "Developer tools",
        "General-purpose applications"
    ]
)

"""
    PRESET_DEVELOPMENT

Optimized for development and debugging.
Fast compilation, debugging symbols preserved.
"""
const PRESET_DEVELOPMENT = OptimizationPreset(
    :development,
    "Fast compilation and debugging support for development",
    :PROFILE_DEBUG,
    BuildConfig(
        optimization_profile = :PROFILE_DEBUG,
        strip_binary = false,
        use_upx = false,
        enable_lto = false,
        compile_for_size = false,
        optimization_flags = ["-O0", "-g"]
    ),
    WizardConfig(
        priority = :balanced,
        max_binary_size_kb = 50000,
        interactive = false,
        enable_upx = false,
        strip_symbols = false
    ),
    nothing,  # No PGO for dev builds
    CIConfig(
        max_binary_size_kb = 100000,
        min_performance_score = 0.0,  # No perf requirements
        fail_on_allocations = false,
        fail_on_security_issues = false
    ),
    false,  # use_upx
    false,  # strip_binary
    false,  # enable_lto
    false,  # benchmark_enabled
    [
        "Development",
        "Debugging",
        "Testing",
        "Prototyping",
        "Local development"
    ]
)

"""
    PRESET_RELEASE

Production release optimization.
Comprehensive optimization with security hardening.
"""
const PRESET_RELEASE = OptimizationPreset(
    :release,
    "Production release with comprehensive optimization and security",
    :PROFILE_SPEED_LTO,
    BuildConfig(
        optimization_profile = :PROFILE_SPEED_LTO,
        strip_binary = true,
        use_upx = false,
        enable_lto = true,
        compile_for_size = false,
        optimization_flags = ["-O3", "-flto"]
    ),
    WizardConfig(
        priority = :speed,
        max_binary_size_kb = 5000,
        interactive = false,
        enable_upx = false,
        strip_symbols = true
    ),
    PGOConfig(
        target_metric = :speed,
        iterations = 5,
        benchmark_samples = 100,
        improvement_threshold = 2.0,
        save_profiles = true
    ),
    CIConfig(
        max_binary_size_kb = 10000,
        min_performance_score = 80.0,
        min_security_score = 90.0,
        fail_on_security_issues = true,
        fail_on_allocations = false
    ),
    false,  # use_upx
    true,   # strip_binary
    true,   # enable_lto
    true,   # benchmark_enabled
    [
        "Production releases",
        "Stable releases",
        "Distribution",
        "End-user deployment",
        "Commercial software"
    ]
)

"""
List of all available presets
"""
const ALL_PRESETS = [
    PRESET_EMBEDDED,
    PRESET_SERVERLESS,
    PRESET_HPC,
    PRESET_DESKTOP,
    PRESET_DEVELOPMENT,
    PRESET_RELEASE
]

"""
    get_preset(name::Symbol)

Get a preset by name.

# Arguments
- `name` - Preset name (e.g., :embedded, :serverless, :hpc, :desktop, :development, :release)

# Returns
- `OptimizationPreset` if found, `nothing` otherwise

# Example
```julia
preset = get_preset(:embedded)
```
"""
function get_preset(name::Symbol)
    for preset in ALL_PRESETS
        if preset.name == name
            return preset
        end
    end
    return nothing
end

"""
    list_presets(; verbose=true)

List all available optimization presets.

# Arguments
- `verbose` - If true, print detailed information

# Example
```julia
list_presets()
```
"""
function list_presets(; verbose=true)
    if !verbose
        return [p.name for p in ALL_PRESETS]
    end

    println("\n" * "="^70)
    println("AVAILABLE OPTIMIZATION PRESETS")
    println("="^70)
    println()

    for preset in ALL_PRESETS
        println("📦 $(uppercase(string(preset.name)))")
        println("   $(preset.description)")
        println()
        println("   Profile: $(preset.optimization_profile)")
        println("   LTO: $(preset.enable_lto ? "✓" : "✗")")
        println("   Strip: $(preset.strip_binary ? "✓" : "✗")")
        println("   UPX: $(preset.use_upx ? "✓" : "✗")")
        println("   Benchmarking: $(preset.benchmark_enabled ? "✓" : "✗")")
        println()
        println("   Recommended for:")
        for use_case in preset.recommended_for
            println("      • $use_case")
        end
        println()
    end

    return [p.name for p in ALL_PRESETS]
end

"""
    compile_with_preset(f, types, output_path, name, preset::Symbol; args=nothing, verbose=true)

Compile a function using a predefined optimization preset.

# Arguments
- `f` - Function to compile
- `types` - Type signature tuple
- `output_path` - Output directory
- `name` - Binary name
- `preset` - Preset name (:embedded, :serverless, :hpc, :desktop, :development, :release)
- `args` - Arguments for benchmarking (optional)
- `verbose` - Print progress information

# Returns
- Dictionary with compilation results and metrics

# Example
```julia
result = compile_with_preset(
    my_func,
    (Int,),
    "dist",
    "my_app",
    :embedded,
    args=(100,)
)
```
"""
function compile_with_preset(f, types, output_path, name, preset_name::Symbol; args=nothing, verbose=true)
    preset = get_preset(preset_name)
    if preset === nothing
        error("Unknown preset: $preset_name. Available: $(join([p.name for p in ALL_PRESETS], ", "))")
    end

    if verbose
        println("\n" * "="^70)
        println("COMPILING WITH PRESET: $(uppercase(string(preset.name)))")
        println("="^70)
        println("$(preset.description)")
        println()
    end

    results = Dict{String, Any}(
        "preset" => preset.name,
        "function" => string(nameof(f))
    )

    start_time = time()

    # Step 1: Run PGO if configured
    pgo_result = nothing
    if preset.pgo_config !== nothing && args !== nothing
        if verbose
            println("🔄 Running profile-guided optimization...")
        end

        pgo_result = pgo_compile(
            f, types, args, output_path, name,
            config=preset.pgo_config,
            verbose=verbose
        )

        results["pgo"] = Dict(
            "iterations" => pgo_result.iterations_completed,
            "best_profile" => pgo_result.best_profile,
            "improvement_pct" => pgo_result.improvement_pct
        )
    end

    # Step 2: Compile with optimizations
    if verbose
        println("\n🔨 Compiling binary...")
        println("   Profile: $(preset.optimization_profile)")
        println("   LTO: $(preset.enable_lto)")
        println("   Strip: $(preset.strip_binary)")
    end

    binary_path = compile_executable(
        f, types, output_path, name,
        strip_binary=preset.strip_binary
    )

    if isfile(binary_path)
        binary_size = filesize(binary_path)
        results["binary_size"] = binary_size

        if verbose
            println("   ✓ Compiled: $binary_path")
            println("   Size: $(format_bytes(binary_size))")
        end

        # Step 3: Apply UPX if enabled
        if preset.use_upx
            if verbose
                println("\n📦 Compressing with UPX...")
            end

            upx_level = preset.build_config !== nothing ? preset.build_config.upx_level : 9
            success, compressed_size = compress_with_upx(binary_path, level=upx_level, verbose=false)

            if success
                results["compressed_size"] = compressed_size
                results["compression_ratio"] = round(compressed_size / binary_size, digits=3)

                if verbose
                    println("   ✓ Compressed: $(format_bytes(compressed_size))")
                    println("   Ratio: $(round(compressed_size / binary_size * 100, digits=1))%")
                end
            end
        end
    end

    # Step 4: Run benchmarks if enabled
    if preset.benchmark_enabled && args !== nothing
        if verbose
            println("\n⏱️  Running performance benchmarks...")
        end

        bench_config = BenchmarkConfig(samples=50, warmup_samples=10)
        bench_result = benchmark_function(f, types, args, config=bench_config, verbose=false)

        results["benchmark"] = Dict(
            "median_time_ns" => bench_result.median_time_ns,
            "mean_time_ns" => bench_result.mean_time_ns,
            "std_dev_ns" => bench_result.std_dev_ns
        )

        if verbose
            println("   Median: $(format_time(bench_result.median_time_ns))")
            println("   Mean: $(format_time(bench_result.mean_time_ns)) ± $(format_time(bench_result.std_dev_ns))")
        end
    end

    # Step 5: Generate comprehensive report
    if verbose
        println("\n📊 Generating comprehensive report...")
    end

    report = generate_comprehensive_report(
        f, types,
        compile=false,  # Already compiled
        benchmark=false,  # Already benchmarked
        verbose=false
    )

    results["scores"] = Dict(
        "overall" => report.overall_score,
        "performance" => report.performance_score,
        "size" => report.size_score,
        "security" => report.security_score
    )

    total_time = time() - start_time
    results["total_time_seconds"] = round(total_time, digits=2)

    if verbose
        println("\n" * "="^70)
        println("PRESET COMPILATION COMPLETE")
        println("="^70)
        println()
        println("Results:")
        println("   Binary: $binary_path")
        if haskey(results, "binary_size")
            println("   Size: $(format_bytes(results["binary_size"]))")
        end
        if haskey(results, "compressed_size")
            println("   Compressed: $(format_bytes(results["compressed_size"]))")
        end
        if haskey(results, "benchmark")
            println("   Performance: $(format_time(results["benchmark"]["median_time_ns"]))")
        end
        println()
        println("Scores:")
        println("   Overall: $(round(results["scores"]["overall"], digits=1))/100")
        println("   Performance: $(round(results["scores"]["performance"], digits=1))/100")
        println("   Size: $(round(results["scores"]["size"], digits=1))/100")
        println("   Security: $(round(results["scores"]["security"], digits=1))/100")
        println()
        println("Total time: $(results["total_time_seconds"])s")
        println()
    end

    return results
end

"""
    compare_presets(f, types, args, output_dir; presets=[:embedded, :serverless, :desktop], verbose=true)

Compare multiple presets to find the best for your use case.

# Arguments
- `f` - Function to compile
- `types` - Type signature tuple
- `args` - Arguments for benchmarking
- `output_dir` - Output directory
- `presets` - Vector of preset names to compare
- `verbose` - Print comparison table

# Returns
- Dictionary mapping preset names to results

# Example
```julia
comparison = compare_presets(
    my_func,
    (Int,),
    (1000,),
    "compare_output",
    presets=[:embedded, :desktop, :hpc]
)
```
"""
function compare_presets(f, types, args, output_dir; presets=[:embedded, :serverless, :desktop], verbose=true)
    if verbose
        println("\n" * "="^70)
        println("COMPARING PRESETS")
        println("="^70)
        println()
    end

    results = Dict{Symbol, Any}()

    for preset_name in presets
        if verbose
            println("Testing preset: $preset_name")
        end

        result = compile_with_preset(
            f, types,
            joinpath(output_dir, string(preset_name)),
            "test_$(preset_name)",
            preset_name,
            args=args,
            verbose=false
        )

        results[preset_name] = result

        if verbose
            println("   ✓ Complete")
            println()
        end
    end

    # Print comparison table
    if verbose
        println("\n" * "="^70)
        println("PRESET COMPARISON")
        println("="^70)
        println()

        # Table header
        println(rpad("Preset", 15) * " | " *
                rpad("Binary Size", 12) * " | " *
                rpad("Performance", 12) * " | " *
                rpad("Overall Score", 13))
        println("-"^70)

        # Sort by overall score
        sorted = sort(collect(results), by=x->x[2]["scores"]["overall"], rev=true)

        for (preset_name, result) in sorted
            size_str = haskey(result, "compressed_size") ?
                       format_bytes(result["compressed_size"]) :
                       haskey(result, "binary_size") ?
                       format_bytes(result["binary_size"]) :
                       "N/A"

            perf_str = haskey(result, "benchmark") ?
                       format_time(result["benchmark"]["median_time_ns"]) :
                       "N/A"

            score_str = string(round(result["scores"]["overall"], digits=1))

            println(rpad(string(preset_name), 15) * " | " *
                    rpad(size_str, 12) * " | " *
                    rpad(perf_str, 12) * " | " *
                    rpad(score_str, 13))
        end

        println()
        println("Best overall: $(sorted[1][1])")
        println()
    end

    return results
end
