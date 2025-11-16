# Parallel processing support for compilation and benchmarking

using Statistics: median, mean, std

"""
    parallel_compare_presets(f, types, args, output_dir;
                            presets=[:embedded, :serverless, :desktop],
                            max_concurrent=4,
                            use_cache=true,
                            cache_config=ResultCacheConfig(),
                            verbose=true)

Compare multiple presets in parallel for faster evaluation.

# Arguments
- `f` - Function to compile
- `types` - Type signature tuple
- `args` - Arguments for benchmarking
- `output_dir` - Output directory
- `presets` - Vector of preset names to compare
- `max_concurrent` - Maximum concurrent compilations (default: 4)
- `use_cache` - Use result caching (default: true)
- `cache_config` - Cache configuration
- `verbose` - Print progress

# Returns
- Dictionary mapping preset names to results

# Example
```julia
# Compare 6 presets in parallel (4 at a time)
comparison = parallel_compare_presets(
    my_func,
    (Int,),
    (1000,),
    "compare_output",
    presets=[:embedded, :serverless, :hpc, :desktop, :development, :release],
    max_concurrent=4
)
```
"""
function parallel_compare_presets(f, types, args, output_dir;
                                 presets=[:embedded, :serverless, :desktop],
                                 max_concurrent=4,
                                 use_cache=true,
                                 cache_config=ResultCacheConfig(),
                                 verbose=true)
    if verbose
        log_section("PARALLEL PRESET COMPARISON") do
            log_info("Configuration", Dict(
                "presets" => length(presets),
                "max_concurrent" => max_concurrent,
                "caching" => use_cache
            ))
        end
    end

    results = Dict{Symbol, Any}()
    completed = 0
    total = length(presets)

    # Process presets in batches
    for batch_start in 1:max_concurrent:length(presets)
        batch_end = min(batch_start + max_concurrent - 1, length(presets))
        batch = presets[batch_start:batch_end]

        if verbose
            log_info("Processing batch $(div(batch_start - 1, max_concurrent) + 1): $(batch)")
        end

        # Create tasks for each preset in batch
        tasks = Dict{Symbol, Task}()

        for preset_name in batch
            # Check cache first if enabled
            if use_cache
                cache_key = result_cache_key(f, types, preset_name, args)
                cached = load_cached_pgo(cache_key, config=cache_config)

                if cached !== nothing
                    if verbose
                        log_info("$preset_name (from cache)")
                    end
                    results[preset_name] = cached
                    completed += 1
                    continue
                end
            end

            # Create task for compilation
            task = @task begin
                try
                    result = compile_with_preset(
                        f, types,
                        joinpath(output_dir, string(preset_name)),
                        "test_$(preset_name)",
                        preset_name,
                        args=args,
                        verbose=false
                    )

                    # Cache result if enabled
                    if use_cache && haskey(result, "benchmark")
                        cache_key = result_cache_key(f, types, preset_name, args)
                        # Note: caching full result dict, not just benchmark
                        try
                            cache_file = joinpath(cache_config.cache_dir, "preset_$(cache_key).json")
                            write_json_file(cache_file, result)
                        catch e
                            @warn "Failed to cache preset result" preset=preset_name exception=e
                        end
                    end

                    (preset_name, result, nothing)
                catch e
                    (preset_name, nothing, e)
                end
            end

            tasks[preset_name] = task
            schedule(task)
        end

        # Wait for batch to complete
        for (preset_name, task) in tasks
            (name, result, error) = fetch(task)

            if error !== nothing
                @warn "Preset $name failed" exception=error
                continue
            end

            if result !== nothing
                results[name] = result
                completed += 1

                if verbose
                    log_progress("Preset compilation", completed, total)
                end
            end
        end
    end

    # Print comparison table (reuse from sequential version)
    if verbose
        log_section("COMPARISON RESULTS") do
            for preset_name in presets
                if haskey(results, preset_name)
                    result = results[preset_name]

                    size_str = haskey(result, "binary_size") ?
                              format_bytes(result["binary_size"]) :
                              "N/A"

                    perf_str = haskey(result, "benchmark") ?
                              format_time(result["benchmark"]["median_time_ns"]) :
                              "N/A"

                    score_str = haskey(result, "scores") ?
                               "$(round(result["scores"]["overall"], digits=1))" :
                               "N/A"

                    log_info("$(preset_name)", Dict(
                        "binary_size" => size_str,
                        "performance" => perf_str,
                        "overall_score" => score_str
                    ))
                end
            end
        end
    end

    return results
end

"""
    parallel_benchmark_profiles(f, types, args;
                               profiles=[:PROFILE_SIZE, :PROFILE_SPEED, :PROFILE_AGGRESSIVE],
                               max_concurrent=3,
                               config=BenchmarkConfig(),
                               verbose=true)

Benchmark multiple optimization profiles in parallel.

# Arguments
- `f` - Function to benchmark
- `types` - Type signature
- `args` - Benchmark arguments
- `profiles` - Profiles to test
- `max_concurrent` - Maximum concurrent benchmarks
- `config` - BenchmarkConfig
- `verbose` - Print progress

# Returns
- Dictionary mapping profile names to BenchmarkResult

# Example
```julia
results = parallel_benchmark_profiles(
    myfunc,
    (Int,),
    (1000,),
    profiles=[:PROFILE_SIZE, :PROFILE_SPEED, :PROFILE_AGGRESSIVE, :PROFILE_DEBUG],
    max_concurrent=4
)
```
"""
function parallel_benchmark_profiles(f, types, args;
                                    profiles=[:PROFILE_SIZE, :PROFILE_SPEED, :PROFILE_AGGRESSIVE],
                                    max_concurrent=3,
                                    config=BenchmarkConfig(),
                                    verbose=true)
    if verbose
        log_section("Parallel Profile Benchmarking") do
            log_info("Configuration", Dict(
                "profiles" => length(profiles),
                "max_concurrent" => max_concurrent
            ))
        end
    end

    results = Dict{Symbol, BenchmarkResult}()

    # Process in batches
    for batch_start in 1:max_concurrent:length(profiles)
        batch_end = min(batch_start + max_concurrent - 1, length(profiles))
        batch = profiles[batch_start:batch_end]

        # Create tasks
        tasks = Dict{Symbol, Task}()

        for profile in batch
            task = @task begin
                output_dir = mktempdir()
                binary_name = string(nameof(f), "_", lowercase(string(profile)))
                binary_path = joinpath(output_dir, binary_name)

                try
                    # Compile with profile
                    profile_obj = get_profile_by_symbol(profile)
                    opt_flags = get_optimization_flags(profile_obj)
                    cflags = Cmd(opt_flags)

                    compile_shlib(f, types, binary_path, name=binary_name, cflags=cflags)

                    if !isfile(binary_path * ".so")
                        return (profile, nothing, "Compilation failed")
                    end

                    binary_size = stat(binary_path * ".so").size

                    # Load and benchmark
                    lib = Libdl.dlopen(binary_path * ".so")
                    func_ptr = Libdl.dlsym(lib, "julia_$(nameof(f))")

                    compiled_func = if length(types) == 1
                        (x) -> ccall(func_ptr, types[1], (types[1],), x)
                    elseif length(types) == 2
                        (x, y) -> ccall(func_ptr, types[1], (types...,), x, y)
                    else
                        error("Benchmarking supports up to 2 arguments")
                    end

                    # Warmup
                    for _ in 1:config.warmup_samples
                        compiled_func(args...)
                    end

                    # Benchmark
                    times = Vector{Float64}(undef, config.samples)
                    for i in 1:config.samples
                        t0 = time_ns()
                        compiled_func(args...)
                        times[i] = Float64(time_ns() - t0)
                    end

                    result = BenchmarkResult(
                        string(nameof(f)),
                        config.samples,
                        minimum(times),
                        median(times),
                        mean(times),
                        maximum(times),
                        std(times),
                        0,
                        0,
                        profile,
                        binary_size,
                        Dates.now()
                    )

                    Libdl.dlclose(lib)
                    rm(output_dir, recursive=true, force=true)

                    return (profile, result, nothing)

                catch e
                    rm(output_dir, recursive=true, force=true)
                    return (profile, nothing, string(e))
                end
            end

            tasks[profile] = task
            schedule(task)
        end

        # Wait for batch
        for (profile, task) in tasks
            (name, result, error) = fetch(task)

            if error !== nothing
                verbose && log_warn("$name failed: $error")
                continue
            end

            if result !== nothing
                results[name] = result
                verbose && log_info("$name", Dict(
                    "binary_size" => format_bytes(result.binary_size_bytes),
                    "median_time" => format_time(result.median_time_ns)
                ))
            end
        end
    end

    return results
end

"""
    get_optimal_concurrency()

Determine optimal number of concurrent tasks based on system resources.

# Returns
- Recommended number of concurrent tasks

# Example
```julia
max_concurrent = get_optimal_concurrency()
println("Using $max_concurrent concurrent tasks")
```
"""
function get_optimal_concurrency()
    # Get number of CPU cores
    num_cores = Sys.CPU_THREADS

    # Use 75% of cores, minimum 2, maximum 8
    optimal = max(2, min(8, Int(ceil(num_cores * 0.75))))

    return optimal
end
