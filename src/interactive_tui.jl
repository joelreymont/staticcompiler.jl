# Interactive Terminal UI for optimization exploration

"""
    interactive_optimize(f, types, output_path, name; args=nothing)

Launch interactive terminal UI for exploring optimization options.

# Arguments
- `f` - Function to compile
- `types` - Type signature
- `output_path` - Output directory
- `name` - Binary name
- `args` - Optional benchmark arguments

# Example
```julia
function fibonacci(n::Int)
    # ... implementation
end

# Launch interactive UI
interactive_optimize(fibonacci, (Int,), "dist", "fib", args=(30,))
```
"""
function interactive_optimize(f, types, output_path, name; args=nothing)
    println("\n" * "="^70)
    println("StaticCompiler.jl - Interactive Optimization")
    println("="^70)
    println()
    println("Function: $(nameof(f))")
    println("Types: $types")
    println("Output: $output_path/$name")
    println()

    while true
        println("="^70)
        println("MAIN MENU")
        println("="^70)
        println()
        println("1. Quick compile (auto-select best preset)")
        println("2. Choose optimization preset")
        println("3. Compare presets")
        println("4. Run Profile-Guided Optimization (PGO)")
        println("5. Cross-compile for target platform")
        println("6. View available presets")
        println("7. View cross-compilation targets")
        println("8. Advanced settings")
        println("9. Exit")
        println()
        print("Choice: ")

        choice = readline()
        println()

        if choice == "1"
            menu_quick_compile(f, types, output_path, name, args)
        elseif choice == "2"
            menu_choose_preset(f, types, output_path, name, args)
        elseif choice == "3"
            menu_compare_presets(f, types, output_path, name, args)
        elseif choice == "4"
            menu_pgo(f, types, output_path, name, args)
        elseif choice == "5"
            menu_cross_compile(f, types, output_path, name)
        elseif choice == "6"
            menu_view_presets()
        elseif choice == "7"
            menu_view_targets()
        elseif choice == "8"
            menu_advanced_settings()
        elseif choice == "9"
            println("Exiting...")
            break
        else
            println("Invalid choice. Please try again.")
        end

        println()
    end
end

function menu_quick_compile(f, types, output_path, name, args)
    println("Quick Compile (Smart Optimization)")
    println("-"^70)
    println()
    println("Analyzing function and selecting optimal preset...")
    println()

    result = smart_optimize(f, types, output_path, name, args=args, target=:auto, verbose=true)

    println()
    println("✓ Compilation complete!")
    println("  Binary: $(result.binary_path)")
    println("  Size: $(format_bytes(result.binary_size))")
    println("  Preset used: $(result.recommended_preset)")
    println()
    pause()
end

function menu_choose_preset(f, types, output_path, name, args)
    println("Choose Optimization Preset")
    println("-"^70)
    println()

    presets = list_presets()

    for (i, (preset_name, preset)) in enumerate(presets)
        println("$i. $(rpad(String(preset_name), 15)) - $(preset.description)")
    end

    println()
    print("Choose preset (number): ")

    choice = readline()
    preset_idx = tryparse(Int, choice)

    if preset_idx === nothing || preset_idx < 1 || preset_idx > length(presets)
        println("Invalid choice.")
        pause()
        return
    end

    preset_name = presets[preset_idx][1]

    println()
    println("Compiling with preset: $preset_name")
    println()

    result = compile_with_preset(f, types, output_path, name, preset_name, args=args, verbose=true)

    println()
    println("✓ Compilation complete!")
    if haskey(result, "binary_size")
        println("  Size: $(format_bytes(result["binary_size"]))")
    end
    println()
    pause()
end

function menu_compare_presets(f, types, output_path, name, args)
    println("Compare Presets")
    println("-"^70)
    println()

    if args === nothing
        println("⚠️  Benchmarking requires arguments.")
        print("Do you want to proceed without benchmarking? (y/n): ")

        if lowercase(strip(readline())) != "y"
            return
        end
    end

    println("Select presets to compare:")
    println()

    available_presets = list_presets()

    for (i, (preset_name, _)) in enumerate(available_presets)
        println("$i. $preset_name")
    end

    println()
    print("Enter preset numbers (comma-separated, e.g., 1,3,5): ")

    input = readline()
    indices = [tryparse(Int, strip(s)) for s in split(input, ',')]

    selected_presets = Symbol[]
    for idx in indices
        if idx !== nothing && idx >= 1 && idx <= length(available_presets)
            push!(selected_presets, available_presets[idx][1])
        end
    end

    if isempty(selected_presets)
        println("No valid presets selected.")
        pause()
        return
    end

    println()
    println("Comparing: $(join(selected_presets, ", "))")
    println()
    println("Use parallel processing? (y/n): ")

    parallel = lowercase(strip(readline())) == "y"

    println()

    if parallel
        results = parallel_compare_presets(
            f, types, args !== nothing ? args : (),
            output_path,
            presets=selected_presets,
            max_concurrent=get_optimal_concurrency(),
            verbose=true
        )
    else
        results = compare_presets(
            f, types, args !== nothing ? args : (),
            output_path,
            presets=selected_presets,
            verbose=true
        )
    end

    println()
    pause()
end

function menu_pgo(f, types, output_path, name, args)
    println("Profile-Guided Optimization")
    println("-"^70)
    println()

    if args === nothing
        println("⚠️  PGO requires benchmark arguments.")
        print("Enter arguments (e.g., for Int type, enter: 100): ")
        arg_input = readline()
        args_val = tryparse(Int, strip(arg_input))

        if args_val === nothing
            println("Invalid argument.")
            pause()
            return
        end

        args = (args_val,)
    end

    println("PGO Configuration:")
    println()
    print("Target metric (speed/size/balanced) [speed]: ")
    metric_input = strip(readline())
    target_metric = isempty(metric_input) ? :speed : Symbol(metric_input)

    print("Number of iterations [3]: ")
    iter_input = strip(readline())
    iterations = isempty(iter_input) ? 3 : parse(Int, iter_input)

    println()
    println("Running PGO with $iterations iterations targeting $target_metric...")
    println()

    config = PGOConfig(
        target_metric=target_metric,
        iterations=iterations,
        auto_apply=true
    )

    result = pgo_compile(f, types, args, output_path, name, config=config, verbose=true)

    println()
    println("✓ PGO complete!")
    println("  Best profile: $(result.best_profile)")
    println("  Improvement: $(round(result.improvement_pct, digits=2))%")
    println()
    pause()
end

function menu_cross_compile(f, types, output_path, name)
    println("Cross-Compilation")
    println("-"^70)
    println()

    targets = list_cross_targets()

    for (i, (target_name, description)) in enumerate(targets)
        println("$i. $(rpad(String(target_name), 20)) - $description")
    end

    println()
    print("Choose target (number): ")

    choice = readline()
    target_idx = tryparse(Int, choice)

    if target_idx === nothing || target_idx < 1 || target_idx > length(targets)
        println("Invalid choice.")
        pause()
        return
    end

    target_name = targets[target_idx][1]
    target = get_cross_target(target_name)

    println()
    println("Select optimization preset:")
    println()

    presets = list_presets()
    for (i, (preset_name, _)) in enumerate(presets)
        println("$i. $preset_name")
    end

    print("Choose preset (number): ")
    preset_choice = readline()
    preset_idx = tryparse(Int, preset_choice)

    if preset_idx === nothing || preset_idx < 1 || preset_idx > length(presets)
        println("Invalid choice.")
        pause()
        return
    end

    preset_name = presets[preset_idx][1]

    println()
    println("Cross-compiling for $(target.description) with preset $preset_name...")
    println()

    result = cross_compile_with_preset(
        f, types,
        joinpath(output_path, "cross_$(target_name)"),
        name,
        preset_name,
        target,
        verbose=true
    )

    println()
    println("✓ Cross-compilation complete!")
    if haskey(result, "binary_size")
        println("  Size: $(format_bytes(result["binary_size"]))")
    end
    println()
    pause()
end

function menu_view_presets()
    println("Available Optimization Presets")
    println("-"^70)
    println()

    presets = list_presets()

    for (preset_name, preset) in presets
        println("$(preset_name):")
        println("  Description: $(preset.description)")
        println("  Profile: $(preset.optimization_profile)")
        println("  LTO: $(preset.enable_lto)")
        println("  UPX: $(preset.use_upx)")
        println("  Strip: $(preset.strip_binary)")
        println("  Recommended for: $(join(preset.recommended_for, ", "))")
        println()
    end

    pause()
end

function menu_view_targets()
    println("Available Cross-Compilation Targets")
    println("-"^70)
    println()

    targets = list_cross_targets()

    for (target_name, description) in targets
        target = get_cross_target(target_name)
        println("$(target_name):")
        println("  Description: $description")
        println("  Architecture: $(target.arch)")
        println("  OS: $(target.os)")
        println("  Triple: $(target.triple)")
        println("  CPU: $(target.cpu)")
        println()
    end

    pause()
end

function menu_advanced_settings()
    println("Advanced Settings")
    println("-"^70)
    println()
    println("1. Configure logging")
    println("2. View cache statistics")
    println("3. Clear cache")
    println("4. Configure result caching")
    println("5. Back to main menu")
    println()
    print("Choice: ")

    choice = readline()
    println()

    if choice == "1"
        menu_configure_logging()
    elseif choice == "2"
        menu_cache_stats()
    elseif choice == "3"
        menu_clear_cache()
    elseif choice == "4"
        menu_configure_cache()
    end
end

function menu_configure_logging()
    println("Configure Logging")
    println("-"^70)
    println()

    print("Log level (DEBUG/INFO/WARN/ERROR) [INFO]: ")
    level_input = strip(uppercase(readline()))
    level = if isempty(level_input)
        INFO
    elseif level_input == "DEBUG"
        DEBUG
    elseif level_input == "WARN"
        WARN
    elseif level_input == "ERROR"
        ERROR
    else
        INFO
    end

    print("Log to file? (y/n) [n]: ")
    log_to_file = lowercase(strip(readline())) == "y"

    config = LogConfig(
        level=level,
        log_to_file=log_to_file
    )

    set_log_config(config)

    println()
    println("✓ Logging configuration updated")
    println("  Level: $(LEVEL_NAMES[level])")
    println("  Log to file: $log_to_file")
    println()
    pause()
end

function menu_cache_stats()
    println("Cache Statistics")
    println("-"^70)
    println()

    # Compilation cache
    comp_stats = cache_stats()
    println("Compilation Cache:")
    println("  Entries: $(comp_stats.entries)")
    println("  Size: $(round(comp_stats.size_mb, digits=2)) MB")
    println()

    # Result cache
    result_config = ResultCacheConfig()
    result_stats = result_cache_stats(result_config)

    println("Result Cache:")
    println("  Exists: $(result_stats["exists"])")
    if result_stats["exists"]
        println("  Entries: $(result_stats["total_entries"])")
        println("  Size: $(format_bytes(result_stats["total_size_bytes"]))")
        println("  Benchmarks: $(result_stats["benchmark_count"])")
        println("  PGO: $(result_stats["pgo_count"])")
    end

    println()
    pause()
end

function menu_clear_cache()
    println("Clear Cache")
    println("-"^70)
    println()

    print("Clear compilation cache? (y/n): ")
    if lowercase(strip(readline())) == "y"
        clear_cache!()
        println("✓ Compilation cache cleared")
    end

    print("Clear result cache? (y/n): ")
    if lowercase(strip(readline())) == "y"
        config = ResultCacheConfig()
        removed = clear_result_cache(config)
        println("✓ Result cache cleared ($removed entries)")
    end

    println()
    pause()
end

function menu_configure_cache()
    println("Configure Result Caching")
    println("-"^70)
    println()

    current = get_log_config()

    print("Enable result caching? (y/n) [y]: ")
    enabled = lowercase(strip(readline())) != "n"

    print("Max age in days [30]: ")
    age_input = strip(readline())
    max_age = isempty(age_input) ? 30 : parse(Int, age_input)

    println()
    println("✓ Cache configuration would be updated")
    println("  (Note: This is a demonstration - actual configuration would be persisted)")
    println()
    pause()
end

function pause()
    print("Press Enter to continue...")
    readline()
end

"""
    quick_interactive_menu()

Launch a quick interactive menu for common tasks.

# Example
```julia
quick_interactive_menu()
```
"""
function quick_interactive_menu()
    println("\n" * "="^70)
    println("StaticCompiler.jl - Quick Menu")
    println("="^70)
    println()
    println("1. Compile a function (you'll define it)")
    println("2. View documentation")
    println("3. View examples")
    println("4. Exit")
    println()
    print("Choice: ")

    choice = readline()

    if choice == "1"
        println("\nThis feature requires defining a function in the REPL.")
        println("Please use: interactive_optimize(your_function, types, path, name)")
    elseif choice == "2"
        show_documentation()
    elseif choice == "3"
        show_examples()
    end
end

function show_documentation()
    println("\n" * "="^70)
    println("StaticCompiler.jl Documentation")
    println("="^70)
    println()
    println("Quick Start:")
    println("  1. Define your function")
    println("  2. Call: interactive_optimize(func, (types...), path, name)")
    println()
    println("Online Documentation:")
    println("  https://github.com/brenhinkeller/StaticCompiler.jl")
    println()
    pause()
end

function show_examples()
    println("\n" * "="^70)
    println("Examples")
    println("="^70)
    println()
    println("Example 1: Simple function")
    println("  function add(x::Int, y::Int)")
    println("      return x + y")
    println("  end")
    println("  interactive_optimize(add, (Int, Int), \"dist\", \"add\")")
    println()
    println("Example 2: With benchmarking")
    println("  function fib(n::Int)")
    println("      # ... implementation")
    println("  end")
    println("  interactive_optimize(fib, (Int,), \"dist\", \"fib\", args=(30,))")
    println()
    pause()
end
