# Configuration file support (TOML)
# Allows persistent configuration of logging, caching, and optimization settings

"""
    CompilerConfig

Main configuration structure for StaticCompiler.jl.

# Fields
- `logging::LogConfig` - Logging configuration
- `caching::ResultCacheConfig` - Result caching configuration
- `parallel::ParallelConfig` - Parallel processing configuration
- `default_preset::Symbol` - Default optimization preset
- `default_cross_target::Union{Symbol, Nothing}` - Default cross-compilation target
"""
struct CompilerConfig
    logging::LogConfig
    caching::ResultCacheConfig
    parallel::ParallelConfig
    default_preset::Symbol
    default_cross_target::Union{Symbol, Nothing}
end

"""
    ParallelConfig

Configuration for parallel processing.

# Fields
- `max_concurrent::Int` - Maximum concurrent tasks (default: auto-detect)
- `enable_parallel::Bool` - Enable parallel processing (default: true)
"""
struct ParallelConfig
    max_concurrent::Int
    enable_parallel::Bool

    function ParallelConfig(;
        max_concurrent::Int = get_optimal_concurrency(),
        enable_parallel::Bool = true
    )
        new(max_concurrent, enable_parallel)
    end
end

"""
    load_config(filepath::String="StaticCompiler.toml")

Load configuration from TOML file.

# Arguments
- `filepath` - Path to TOML configuration file (default: "StaticCompiler.toml")

# Returns
- `CompilerConfig` with loaded settings

# Example
```julia
# Create a StaticCompiler.toml file:
# [logging]
# level = "INFO"
# log_to_file = true
# log_file = "staticcompiler.log"
#
# [caching]
# enabled = true
# max_age_days = 30
#
# [parallel]
# max_concurrent = 4
# enable_parallel = true

config = load_config()
apply_config(config)
```
"""
function load_config(filepath::String="StaticCompiler.toml")
    if !isfile(filepath)
        log_info("No configuration file found at $filepath, using defaults")
        return default_config()
    end

    log_info("Loading configuration from $filepath")

    # Parse TOML manually (no TOML dependency)
    config_dict = parse_toml_file(filepath)

    # Extract logging config
    log_config = if haskey(config_dict, "logging")
        log_dict = config_dict["logging"]
        LogConfig(
            level = parse_log_level(get(log_dict, "level", "INFO")),
            log_to_file = get(log_dict, "log_to_file", false),
            log_file = get(log_dict, "log_file", DEFAULT_LOG_FILE),
            log_to_stdout = get(log_dict, "log_to_stdout", true),
            use_colors = get(log_dict, "use_colors", true),
            timestamp_format = get(log_dict, "timestamp_format", DEFAULT_TIMESTAMP_FORMAT),
            include_source = get(log_dict, "include_source", false),
            json_format = get(log_dict, "json_format", false)
        )
    else
        LogConfig()
    end

    # Extract caching config
    cache_config = if haskey(config_dict, "caching")
        cache_dict = config_dict["caching"]
        ResultCacheConfig(
            enabled = get(cache_dict, "enabled", true),
            cache_dir = get(cache_dict, "cache_dir", DEFAULT_CACHE_DIR),
            max_age_days = get(cache_dict, "max_age_days", 30)
        )
    else
        ResultCacheConfig()
    end

    # Extract parallel config
    parallel_config = if haskey(config_dict, "parallel")
        par_dict = config_dict["parallel"]
        ParallelConfig(
            max_concurrent = get(par_dict, "max_concurrent", get_optimal_concurrency()),
            enable_parallel = get(par_dict, "enable_parallel", true)
        )
    else
        ParallelConfig()
    end

    # Extract defaults
    default_preset = if haskey(config_dict, "defaults")
        Symbol(get(config_dict["defaults"], "preset", "desktop"))
    else
        :desktop
    end

    default_target = if haskey(config_dict, "defaults") && haskey(config_dict["defaults"], "cross_target")
        Symbol(config_dict["defaults"]["cross_target"])
    else
        nothing
    end

    CompilerConfig(log_config, cache_config, parallel_config, default_preset, default_target)
end

"""
    save_config(config::CompilerConfig, filepath::String="StaticCompiler.toml")

Save configuration to TOML file.

# Arguments
- `config` - CompilerConfig to save
- `filepath` - Output path (default: "StaticCompiler.toml")

# Example
```julia
config = CompilerConfig(
    LogConfig(level=DEBUG, log_to_file=true),
    ResultCacheConfig(enabled=true),
    ParallelConfig(max_concurrent=4),
    :release,
    :arm64_linux
)
save_config(config)
```
"""
function save_config(config::CompilerConfig, filepath::String="StaticCompiler.toml")
    log_info("Saving configuration to $filepath")

    open(filepath, "w") do io
        # Logging section
        println(io, "[logging]")
        println(io, "level = \"$(LEVEL_NAMES[config.logging.level])\"")
        println(io, "log_to_file = $(config.logging.log_to_file)")
        println(io, "log_file = \"$(config.logging.log_file)\"")
        println(io, "log_to_stdout = $(config.logging.log_to_stdout)")
        println(io, "use_colors = $(config.logging.use_colors)")
        println(io, "timestamp_format = \"$(config.logging.timestamp_format)\"")
        println(io, "include_source = $(config.logging.include_source)")
        println(io, "json_format = $(config.logging.json_format)")
        println(io)

        # Caching section
        println(io, "[caching]")
        println(io, "enabled = $(config.caching.enabled)")
        println(io, "cache_dir = \"$(config.caching.cache_dir)\"")
        println(io, "max_age_days = $(config.caching.max_age_days)")
        println(io)

        # Parallel section
        println(io, "[parallel]")
        println(io, "max_concurrent = $(config.parallel.max_concurrent)")
        println(io, "enable_parallel = $(config.parallel.enable_parallel)")
        println(io)

        # Defaults section
        println(io, "[defaults]")
        println(io, "preset = \"$(config.default_preset)\"")
        if config.default_cross_target !== nothing
            println(io, "cross_target = \"$(config.default_cross_target)\"")
        end
    end

    log_info("Configuration saved successfully")
end

"""
    apply_config(config::CompilerConfig)

Apply configuration settings globally.

# Arguments
- `config` - CompilerConfig to apply

# Example
```julia
config = load_config()
apply_config(config)
```
"""
function apply_config(config::CompilerConfig)
    log_info("Applying configuration")

    # Apply logging config
    set_log_config(config.logging)

    # Caching config is used on-demand
    # Parallel config is used on-demand

    log_info("Configuration applied successfully")
end

"""
    default_config()

Get default configuration.

# Returns
- `CompilerConfig` with all default settings
"""
function default_config()
    CompilerConfig(
        LogConfig(),
        ResultCacheConfig(),
        ParallelConfig(),
        :desktop,
        nothing
    )
end

"""
    parse_toml_file(filepath::String)

Simple TOML parser (no external dependencies).
Supports basic TOML syntax: sections and key-value pairs.

# Arguments
- `filepath` - Path to TOML file

# Returns
- Dictionary with parsed configuration
"""
function parse_toml_file(filepath::String)
    result = Dict{String, Any}()
    current_section = nothing

    for line in readlines(filepath)
        # Remove comments and whitespace
        line = strip(split(line, '#')[1])

        # Skip empty lines
        if isempty(line)
            continue
        end

        # Section header
        if startswith(line, '[') && endswith(line, ']')
            section_name = strip(line[2:end-1])
            current_section = section_name
            result[section_name] = Dict{String, Any}()
            continue
        end

        # Key-value pair
        if occursin('=', line)
            key, value = split(line, '=', limit=2)
            key = strip(key)
            value = strip(value)

            # Parse value
            parsed_value = parse_toml_value(value)

            if current_section !== nothing
                result[current_section][key] = parsed_value
            else
                result[key] = parsed_value
            end
        end
    end

    return result
end

"""
    parse_toml_value(value::String)

Parse TOML value from string.

# Arguments
- `value` - String value from TOML file

# Returns
- Parsed value (String, Int, Bool, or Float64)
"""
function parse_toml_value(value::String)
    # Boolean
    if value == "true"
        return true
    elseif value == "false"
        return false
    end

    # String (quoted)
    if startswith(value, '"') && endswith(value, '"')
        return value[2:end-1]
    end

    # Integer
    int_val = tryparse(Int, value)
    if int_val !== nothing
        return int_val
    end

    # Float
    float_val = tryparse(Float64, value)
    if float_val !== nothing
        return float_val
    end

    # Default: return as string
    return value
end

"""
    parse_log_level(level_str::String)

Parse log level from string.

# Arguments
- `level_str` - Log level string (DEBUG, INFO, WARN, ERROR, SILENT)

# Returns
- LogLevel enum value
"""
function parse_log_level(level_str::String)
    level_upper = uppercase(strip(level_str))

    if level_upper == "DEBUG"
        return DEBUG
    elseif level_upper == "INFO"
        return INFO
    elseif level_upper == "WARN" || level_upper == "WARNING"
        return WARN
    elseif level_upper == "ERROR"
        return ERROR
    elseif level_upper == "SILENT"
        return SILENT
    else
        log_warn("Unknown log level '$level_str', defaulting to INFO")
        return INFO
    end
end

"""
    create_default_config_file(filepath::String="StaticCompiler.toml")

Create a default configuration file with comments.

# Arguments
- `filepath` - Output path (default: "StaticCompiler.toml")

# Example
```julia
create_default_config_file()
```
"""
function create_default_config_file(filepath::String="StaticCompiler.toml")
    log_info("Creating default configuration file at $filepath")

    open(filepath, "w") do io
        println(io, "# StaticCompiler.jl Configuration File")
        println(io, "# This file configures logging, caching, and optimization defaults")
        println(io)

        println(io, "[logging]")
        println(io, "# Log level: DEBUG, INFO, WARN, ERROR, SILENT")
        println(io, "level = \"INFO\"")
        println(io)
        println(io, "# Write logs to file")
        println(io, "log_to_file = false")
        println(io, "log_file = \"staticcompiler.log\"")
        println(io)
        println(io, "# Write logs to stdout")
        println(io, "log_to_stdout = true")
        println(io)
        println(io, "# Use ANSI colors in terminal")
        println(io, "use_colors = true")
        println(io)
        println(io, "# Include source location in logs")
        println(io, "include_source = false")
        println(io)
        println(io, "# Use JSON format for logs")
        println(io, "json_format = false")
        println(io)
        println(io, "# Timestamp format")
        println(io, "timestamp_format = \"yyyy-mm-dd HH:MM:SS\"")
        println(io)

        println(io, "[caching]")
        println(io, "# Enable result caching")
        println(io, "enabled = true")
        println(io)
        println(io, "# Cache directory")
        println(io, "cache_dir = \".staticcompiler_cache\"")
        println(io)
        println(io, "# Maximum cache age in days")
        println(io, "max_age_days = 30")
        println(io)

        println(io, "[parallel]")
        println(io, "# Maximum concurrent compilation tasks")
        println(io, "# Set to 0 for auto-detect based on CPU cores")
        println(io, "max_concurrent = 0")
        println(io)
        println(io, "# Enable parallel processing")
        println(io, "enable_parallel = true")
        println(io)

        println(io, "[defaults]")
        println(io, "# Default optimization preset")
        println(io, "# Options: embedded, serverless, hpc, desktop, development, release")
        println(io, "preset = \"desktop\"")
        println(io)
        println(io, "# Default cross-compilation target (optional)")
        println(io, "# Uncomment to set a default")
        println(io, "# cross_target = \"arm64_linux\"")
    end

    log_info("Default configuration file created successfully")
end
