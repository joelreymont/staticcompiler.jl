# Result caching system for benchmarks and PGO profiles
# Enables faster iteration and historical tracking

using Dates

"""
    ResultCacheConfig

Configuration for result caching (benchmarks and PGO).

# Fields
- `enabled::Bool` - Enable/disable caching
- `cache_dir::String` - Directory for cache files
- `max_age_days::Int` - Maximum age of cache entries (0 = no expiration)
- `auto_clean::Bool` - Automatically clean expired entries
"""
struct ResultCacheConfig
    enabled::Bool
    cache_dir::String
    max_age_days::Int
    auto_clean::Bool
end

# Default cache configuration
function ResultCacheConfig(;
    enabled::Bool=true,
    cache_dir::String=joinpath(homedir(), ".staticcompiler", "results_cache"),
    max_age_days::Int=30,
    auto_clean::Bool=true
)
    return ResultCacheConfig(enabled, cache_dir, max_age_days, auto_clean)
end

"""
    result_cache_key(f, types, args...)

Generate a unique cache key for a function with given types and arguments.

# Example
```julia
key = result_cache_key(myfunc, (Int, Float64), 100, 3.14)
```
"""
function result_cache_key(f, types, args...)
    # Create hash from function name, types, and args
    func_name = string(nameof(f))
    types_str = string(types)
    args_str = string(args)

    # Simple hash combining all components
    combined = func_name * "|" * types_str * "|" * args_str
    return string(hash(combined), base=16)
end

"""
    cache_benchmark_result(result::BenchmarkResult, key::String; config=ResultCacheConfig())

Cache a benchmark result for later retrieval.

# Arguments
- `result` - BenchmarkResult to cache
- `key` - Unique cache key
- `config` - Cache configuration

# Returns
- `String` - Path to cached file

# Example
```julia
key = result_cache_key(myfunc, (Int,), 100)
cache_benchmark_result(result, key)
```
"""
function cache_benchmark_result(result::BenchmarkResult, key::String; config=ResultCacheConfig())
    if !config.enabled
        return nothing
    end

    mkpath(config.cache_dir)

    # Clean old entries if configured
    if config.auto_clean && config.max_age_days > 0
        clean_result_cache(config)
    end

    filepath = joinpath(config.cache_dir, "benchmark_$key.json")

    # Convert to dict for serialization
    data = Dict(
        "type" => "benchmark",
        "key" => key,
        "cached_at" => string(Dates.now()),
        "function_name" => result.function_name,
        "samples" => result.samples,
        "min_time_ns" => result.min_time_ns,
        "median_time_ns" => result.median_time_ns,
        "mean_time_ns" => result.mean_time_ns,
        "max_time_ns" => result.max_time_ns,
        "std_dev_ns" => result.std_dev_ns,
        "allocations" => result.allocations,
        "memory_bytes" => result.memory_bytes,
        "optimization_profile" => string(result.optimization_profile),
        "binary_size_bytes" => result.binary_size_bytes,
        "timestamp" => string(result.timestamp)
    )

    write_json_file(filepath, data)
    return filepath
end

"""
    load_cached_benchmark(key::String; config=ResultCacheConfig())

Load a cached benchmark result.

# Arguments
- `key` - Cache key to look up
- `config` - Cache configuration

# Returns
- `BenchmarkResult` or `nothing` if not found/expired

# Example
```julia
key = result_cache_key(myfunc, (Int,), 100)
result = load_cached_benchmark(key)
```
"""
function load_cached_benchmark(key::String; config=ResultCacheConfig())
    if !config.enabled
        return nothing
    end

    filepath = joinpath(config.cache_dir, "benchmark_$key.json")

    if !isfile(filepath)
        return nothing
    end

    # Check if expired
    if config.max_age_days > 0
        file_time = Dates.unix2datetime(mtime(filepath))
        age_days = Dates.value(Dates.now() - file_time) / (1000 * 60 * 60 * 24)

        if age_days > config.max_age_days
            rm(filepath, force=true)
            return nothing
        end
    end

    try
        data = parse_json_file(filepath)

        # Parse optimization_profile (could be "nothing" or a symbol string)
        opt_profile = if haskey(data, "optimization_profile") && data["optimization_profile"] != "nothing"
            Symbol(data["optimization_profile"])
        else
            nothing
        end

        # Reconstruct BenchmarkResult
        result = BenchmarkResult(
            data["function_name"],
            Int(data["samples"]),
            Float64(data["min_time_ns"]),
            Float64(data["median_time_ns"]),
            Float64(data["mean_time_ns"]),
            Float64(data["max_time_ns"]),
            Float64(data["std_dev_ns"]),
            Int(data["allocations"]),
            Int(data["memory_bytes"]),
            opt_profile,
            Int(data["binary_size_bytes"]),
            DateTime(data["timestamp"])
        )

        return result
    catch e
        @warn "Failed to load cached benchmark: $e"
        return nothing
    end
end

"""
    cache_pgo_result(result::PGOResult, key::String; config=ResultCacheConfig())

Cache a PGO result for later retrieval.

# Arguments
- `result` - PGOResult to cache
- `key` - Unique cache key
- `config` - Cache configuration

# Returns
- `String` - Path to cached file
"""
function cache_pgo_result(result::PGOResult, key::String; config=ResultCacheConfig())
    if !config.enabled
        return nothing
    end

    mkpath(config.cache_dir)

    if config.auto_clean && config.max_age_days > 0
        clean_result_cache(config)
    end

    filepath = joinpath(config.cache_dir, "pgo_$key.json")

    # Convert to dict for serialization
    data = Dict(
        "type" => "pgo",
        "key" => key,
        "cached_at" => string(Dates.now()),
        "function_name" => result.function_name,
        "initial_profile" => string(result.initial_profile),
        "best_profile" => string(result.best_profile),
        "iterations_completed" => result.iterations_completed,
        "total_time_seconds" => result.total_time_seconds,
        "improvement_pct" => result.improvement_pct,
        "final_binary_size" => result.final_binary_size,
        "timestamp" => string(result.timestamp),
        "profiles_count" => length(result.profiles)
    )

    write_json_file(filepath, data)
    return filepath
end

"""
    load_cached_pgo(key::String; config=ResultCacheConfig())

Load a cached PGO result (metadata only, not full profiles).

# Arguments
- `key` - Cache key to look up
- `config` - Cache configuration

# Returns
- `Dict` with PGO metadata or `nothing` if not found/expired
"""
function load_cached_pgo(key::String; config=ResultCacheConfig())
    if !config.enabled
        return nothing
    end

    filepath = joinpath(config.cache_dir, "pgo_$key.json")

    if !isfile(filepath)
        return nothing
    end

    # Check if expired
    if config.max_age_days > 0
        file_time = Dates.unix2datetime(mtime(filepath))
        age_days = Dates.value(Dates.now() - file_time) / (1000 * 60 * 60 * 24)

        if age_days > config.max_age_days
            rm(filepath, force=true)
            return nothing
        end
    end

    try
        data = parse_json_file(filepath)
        return data
    catch e
        @warn "Failed to load cached PGO result: $e"
        return nothing
    end
end

"""
    clean_result_cache(config::ResultCacheConfig)

Remove expired cache entries.

# Arguments
- `config` - Cache configuration

# Returns
- `Int` - Number of entries removed
"""
function clean_result_cache(config::ResultCacheConfig)
    if !isdir(config.cache_dir) || config.max_age_days == 0
        return 0
    end

    removed = 0
    cutoff_time = Dates.now() - Dates.Day(config.max_age_days)

    for file in readdir(config.cache_dir, join=true)
        if !isfile(file)
            continue
        end

        file_time = Dates.unix2datetime(mtime(file))

        if file_time < cutoff_time
            try
                rm(file, force=true)
                removed += 1
            catch
            end
        end
    end

    return removed
end

"""
    clear_result_cache(config::ResultCacheConfig)

Remove all cache entries.

# Arguments
- `config` - Cache configuration

# Returns
- `Int` - Number of entries removed
"""
function clear_result_cache(config::ResultCacheConfig)
    if !isdir(config.cache_dir)
        return 0
    end

    removed = 0
    for file in readdir(config.cache_dir, join=true)
        if isfile(file)
            try
                rm(file, force=true)
                removed += 1
            catch
            end
        end
    end

    return removed
end

"""
    result_cache_stats(config::ResultCacheConfig)

Get statistics about the cache.

# Arguments
- `config` - Cache configuration

# Returns
- `Dict` with cache statistics
"""
function result_cache_stats(config::ResultCacheConfig)
    if !isdir(config.cache_dir)
        return Dict(
            "exists" => false,
            "total_entries" => 0,
            "total_size_bytes" => 0,
            "benchmark_count" => 0,
            "pgo_count" => 0
        )
    end

    files = readdir(config.cache_dir, join=true)
    total_size = sum(filesize(f) for f in files if isfile(f); init=0)
    benchmark_count = count(f -> startswith(basename(f), "benchmark_"), files)
    pgo_count = count(f -> startswith(basename(f), "pgo_"), files)

    return Dict(
        "exists" => true,
        "total_entries" => length(files),
        "total_size_bytes" => total_size,
        "benchmark_count" => benchmark_count,
        "pgo_count" => pgo_count,
        "cache_dir" => config.cache_dir
    )
end
