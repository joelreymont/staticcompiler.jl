# Interactive Optimization Wizard
# Guides users through selecting optimal compilation settings

"""
Optimization wizard configuration
"""
mutable struct WizardConfig
    function_ref::Any
    types::Tuple
    priority::Symbol  # :size, :speed, :balanced
    target_platform::Symbol  # :desktop, :embedded, :server, :mobile
    deployment::Symbol  # :development, :staging, :production
    size_budget_kb::Union{Int, Nothing}
    requires_upx::Bool
    requires_strip::Bool
    custom_flags::Vector{String}
    analysis_results::Union{Nothing, Dict}

    WizardConfig(f, types) = new(
        f, types, :balanced, :desktop, :development,
        nothing, false, false, String[], nothing
    )
end

"""
    optimization_wizard(f, types; interactive=true)

Interactive wizard to guide users through optimization choices.

# Arguments
- `f`: Function to compile
- `types`: Type signature tuple
- `interactive`: If true, asks questions interactively. If false, uses defaults.

# Example
```julia
config = optimization_wizard(my_func, (Int, Float64))
exe = compile_with_wizard_config(my_func, (Int, Float64), config)
```
"""
function optimization_wizard(f, types; interactive=true)
    config = WizardConfig(f, types)

    println("\n" * "="^70)
    println("🧙 STATICCOMPILER.JL OPTIMIZATION WIZARD")
    println("="^70)
    println("\nThis wizard will help you choose the best compilation settings")
    println("for your use case.\n")

    # Step 1: Analyze the function first
    println("📊 Step 1: Analyzing your function...")
    try
        # Run quick analysis
        alloc_profile = analyze_allocations(f, types, verbose=false)
        inline_info = analyze_inlining(f, types, verbose=false)
        bloat_info = analyze_bloat(f, types, verbose=false)

        config.analysis_results = Dict(
            :allocations => alloc_profile,
            :inlining => inline_info,
            :bloat => bloat_info
        )

        println("   ✅ Analysis complete")

        # Show key findings
        if alloc_profile.total_allocations > 0
            println("   ⚠️  Found $(alloc_profile.total_allocations) allocations")
        end
        if bloat_info.total_functions > 50
            println("   ⚠️  Large number of functions: $(bloat_info.total_functions)")
        end
    catch e
        println("   ℹ️  Skipping analysis (not critical): $e")
    end

    if !interactive
        println("\n📋 Using default balanced configuration")
        return _apply_defaults(config)
    end

    # Step 2: What's most important?
    println("\n🎯 Step 2: What's your main priority?")
    println("   1. Small binary size (embedded, distribution)")
    println("   2. Fast runtime performance (servers, HPC)")
    println("   3. Balanced (good size and speed)")
    println("   4. Fast compilation (development)")

    choice = _get_choice(1:4, 3)
    config.priority = [:size, :speed, :balanced, :compilation_speed][choice]

    # Step 3: Target platform
    println("\n💻 Step 3: Target platform?")
    println("   1. Desktop/Server (x86-64, plenty of resources)")
    println("   2. Embedded system (ARM, limited resources)")
    println("   3. Mobile device")
    println("   4. High-performance cluster")

    choice = _get_choice(1:4, 1)
    config.target_platform = [:desktop, :embedded, :mobile, :server][choice]

    # Step 4: Deployment stage
    println("\n🚀 Step 4: Deployment stage?")
    println("   1. Development (need fast iteration)")
    println("   2. Staging (testing optimizations)")
    println("   3. Production (maximum optimization)")

    choice = _get_choice(1:3, 1)
    config.deployment = [:development, :staging, :production][choice]

    # Step 5: Size budget (if size is priority)
    if config.priority == :size
        println("\n📦 Step 5: Do you have a size budget?")
        println("   1. Yes, I need the binary under a certain size")
        println("   2. No, just make it as small as possible")

        if _get_choice(1:2, 2) == 1
            println("\n   Enter size budget in KB (e.g., 100):")
            print("   > ")
            budget_str = readline()
            try
                config.size_budget_kb = parse(Int, budget_str)
                println("   📏 Size budget set to $(config.size_budget_kb) KB")
            catch
                println("   ℹ️  Invalid input, skipping size budget")
            end
        end
    end

    # Step 6: UPX compression
    upx_available, _ = test_upx_available()
    if upx_available && config.priority in [:size, :balanced]
        println("\n📦 Step 6: Use UPX compression?")
        println("   UPX can reduce binary size by 50-70%")
        println("   1. Yes, compress with UPX")
        println("   2. No, skip compression")

        config.requires_upx = (_get_choice(1:2, 1) == 1)
    end

    # Step 7: Symbol stripping
    println("\n🔧 Step 7: Strip debug symbols?")
    println("   Stripping reduces size by ~10% but makes debugging harder")
    println("   1. Yes, strip symbols (recommended for production)")
    println("   2. No, keep symbols (recommended for development)")

    default_strip = config.deployment == :production ? 1 : 2
    config.requires_strip = (_get_choice(1:2, default_strip) == 1)

    # Step 8: Advanced options
    println("\n⚙️  Step 8: Advanced optimizations?")
    println("   1. Use recommended settings (recommended)")
    println("   2. Customize compiler flags")

    if _get_choice(1:2, 1) == 2
        println("\n   Enter custom CFLAGS (space-separated, e.g., -march=native -O3):")
        print("   > ")
        flags_str = readline()
        if !isempty(strip(flags_str))
            config.custom_flags = split(flags_str)
        end
    end

    # Generate final recommendation
    println("\n" * "="^70)
    println("📋 RECOMMENDED CONFIGURATION")
    println("="^70)
    _print_wizard_config(config)

    println("\n🎯 Would you like to:")
    println("   1. Use this configuration")
    println("   2. Start over")
    println("   3. Exit without saving")

    choice = _get_choice(1:3, 1)
    if choice == 2
        return optimization_wizard(f, types, interactive=true)
    elseif choice == 3
        println("   👋 Exiting wizard")
        return nothing
    end

    println("\n✅ Configuration ready!")
    return config
end

"""
Helper function to get user choice
"""
function _get_choice(range, default)
    print("   > ")
    flush(stdout)

    # For non-interactive environments, use default
    if !isinteractive()
        println(default)
        return default
    end

    input = readline()
    if isempty(strip(input))
        return default
    end

    try
        choice = parse(Int, input)
        if choice in range
            return choice
        end
    catch
    end

    println("   ℹ️  Invalid choice, using default: $default")
    return default
end

"""
Print wizard configuration summary
"""
function _print_wizard_config(config::WizardConfig)
    println("\nPriority: $(uppercase(string(config.priority)))")
    println("Platform: $(uppercase(string(config.target_platform)))")
    println("Deployment: $(uppercase(string(config.deployment)))")

    if config.size_budget_kb !== nothing
        println("Size Budget: $(config.size_budget_kb) KB")
    end

    println("\nOptimization Profile: $(recommended_profile(config))")
    println("Strip Symbols: $(config.requires_strip)")
    println("UPX Compression: $(config.requires_upx)")

    if !isempty(config.custom_flags)
        println("Custom Flags: $(join(config.custom_flags, " "))")
    end

    # Show warnings based on analysis
    if config.analysis_results !== nothing
        allocs = config.analysis_results[:allocations]
        if allocs.total_allocations > 0 && config.deployment == :production
            println("\n⚠️  WARNING: Function has allocations, may not be fully static")
        end
    end
end

"""
Get recommended optimization profile based on wizard config
"""
function recommended_profile(config::WizardConfig)
    if config.deployment == :development
        return "PROFILE_DEBUG"
    end

    if config.priority == :size
        return config.requires_upx ? "PROFILE_AGGRESSIVE" : "PROFILE_SIZE"
    elseif config.priority == :speed
        return "PROFILE_SPEED"
    elseif config.priority == :compilation_speed
        return "PROFILE_DEBUG"
    else  # :balanced
        return "PROFILE_AGGRESSIVE"
    end
end

"""
Apply default configuration without user interaction
"""
function _apply_defaults(config::WizardConfig)
    config.priority = :balanced
    config.target_platform = :desktop
    config.deployment = :development
    config.requires_strip = false
    config.requires_upx = false
    return config
end

"""
    compile_with_wizard_config(f, types, config; path=tempdir(), name="executable")

Compile using wizard configuration.

# Example
```julia
config = optimization_wizard(my_func, (Int,))
exe = compile_with_wizard_config(my_func, (Int,), config, path="/tmp", name="myapp")
```
"""
function compile_with_wizard_config(f, types, config::WizardConfig; path=tempdir(), name="executable")
    # Select profile
    profile = if config.deployment == :development
        PROFILE_DEBUG
    elseif config.priority == :size
        config.requires_upx ? PROFILE_AGGRESSIVE : PROFILE_SIZE
    elseif config.priority == :speed
        PROFILE_SPEED
    else
        PROFILE_AGGRESSIVE
    end

    println("\n🔨 Compiling with wizard configuration...")
    println("   Profile: $(recommended_profile(config))")

    # Compile
    exe = compile_executable_optimized(
        f, types,
        path, name,
        profile=profile
    )

    # Apply additional options
    if config.requires_upx && !profile.compress_upx
        println("   📦 Applying UPX compression...")
        compress_with_upx(exe, level=:best)
    end

    # Check size budget
    if config.size_budget_kb !== nothing
        size_kb = filesize(exe) / 1024
        if size_kb > config.size_budget_kb
            @warn "Binary size $(round(size_kb, digits=1)) KB exceeds budget of $(config.size_budget_kb) KB"
            println("\n💡 Suggestions to reduce size:")
            println("   • Enable UPX compression")
            println("   • Use PROFILE_SIZE instead")
            println("   • Remove unused dependencies")
        else
            println("   ✅ Binary size $(round(size_kb, digits=1)) KB within budget!")
        end
    end

    println("\n✅ Compilation complete: $exe")
    return exe
end

"""
    quick_wizard(f, types; priority=:balanced)

Quick non-interactive wizard with sensible defaults.

# Arguments
- `priority`: :size, :speed, or :balanced

# Example
```julia
exe = quick_wizard(my_func, (Int,), priority=:size)
```
"""
function quick_wizard(f, types; priority=:balanced, path=tempdir(), name="executable")
    config = WizardConfig(f, types)
    config.priority = priority
    config.deployment = :production
    config.requires_strip = true
    config.requires_upx = (priority == :size)

    println("\n🧙 Quick Wizard ($(uppercase(string(priority))) optimization)")

    return compile_with_wizard_config(f, types, config, path=path, name=name)
end

export WizardConfig, optimization_wizard, compile_with_wizard_config, quick_wizard
