# Structured logging system for StaticCompiler

using Dates

"""
    LogLevel

Enumeration of log levels.
"""
@enum LogLevel begin
    DEBUG = 1
    INFO = 2
    WARN = 3
    ERROR = 4
    SILENT = 5
end

"""
    LogConfig

Configuration for logging behavior.

# Fields
- `level::LogLevel` - Minimum level to log (default: INFO)
- `log_to_file::Bool` - Write logs to file (default: false)
- `log_file::String` - Path to log file
- `log_to_stdout::Bool` - Write logs to stdout (default: true)
- `use_colors::Bool` - Use ANSI colors in terminal (default: true)
- `timestamp_format::String` - Timestamp format string
- `include_source::Bool` - Include source location (default: false)
- `json_format::Bool` - Output logs as JSON (default: false)
"""
struct LogConfig
    level::LogLevel
    log_to_file::Bool
    log_file::String
    log_to_stdout::Bool
    use_colors::Bool
    timestamp_format::String
    include_source::Bool
    json_format::Bool
end

# Default configuration
function LogConfig(;
    level::LogLevel=INFO,
    log_to_file::Bool=false,
    log_file::String=joinpath(homedir(), ".staticcompiler", "logs", "staticcompiler.log"),
    log_to_stdout::Bool=true,
    use_colors::Bool=true,
    timestamp_format::String="yyyy-mm-dd HH:MM:SS",
    include_source::Bool=false,
    json_format::Bool=false
)
    return LogConfig(level, log_to_file, log_file, log_to_stdout, use_colors,
                    timestamp_format, include_source, json_format)
end

# Global logger configuration
const GLOBAL_LOG_CONFIG = Ref{LogConfig}(LogConfig())

"""
    set_log_config(config::LogConfig)

Set global logging configuration.

# Example
```julia
set_log_config(LogConfig(level=DEBUG, log_to_file=true))
```
"""
function set_log_config(config::LogConfig)
    GLOBAL_LOG_CONFIG[] = config
end

"""
    get_log_config()

Get current logging configuration.
"""
function get_log_config()
    return GLOBAL_LOG_CONFIG[]
end

# ANSI color codes
const COLOR_CODES = Dict(
    DEBUG => "\e[36m",     # Cyan
    INFO => "\e[32m",      # Green
    WARN => "\e[33m",      # Yellow
    ERROR => "\e[31m",     # Red
    SILENT => ""
)

const COLOR_RESET = "\e[0m"

# Level names
const LEVEL_NAMES = Dict(
    DEBUG => "DEBUG",
    INFO => "INFO",
    WARN => "WARN",
    ERROR => "ERROR",
    SILENT => ""
)

# Level symbols for short display
const LEVEL_SYMBOLS = Dict(
    DEBUG => "🔍",
    INFO => "ℹ️",
    WARN => "⚠️",
    ERROR => "❌",
    SILENT => ""
)

"""
    format_log_message(level::LogLevel, message::String, context::Dict=Dict(); config::LogConfig=get_log_config())

Format a log message according to configuration.

# Arguments
- `level` - Log level
- `message` - Log message
- `context` - Additional context information
- `config` - Log configuration

# Returns
- Formatted log message string
"""
function format_log_message(level::LogLevel, message::String, context::Dict=Dict(); config::LogConfig=get_log_config())
    if config.json_format
        # JSON format
        log_obj = Dict(
            "timestamp" => Dates.format(now(), config.timestamp_format),
            "level" => LEVEL_NAMES[level],
            "message" => message
        )

        if !isempty(context)
            log_obj["context"] = context
        end

        return to_json_string(log_obj)
    else
        # Plain text format
        parts = String[]

        # Timestamp
        timestamp = Dates.format(now(), config.timestamp_format)
        push!(parts, timestamp)

        # Level with color and symbol
        level_str = if config.use_colors
            color = COLOR_CODES[level]
            symbol = LEVEL_SYMBOLS[level]
            "$(color)$(symbol) $(LEVEL_NAMES[level])$(COLOR_RESET)"
        else
            LEVEL_NAMES[level]
        end
        push!(parts, rpad(level_str, 10))

        # Message
        push!(parts, message)

        # Context
        if !isempty(context)
            context_str = join(["$k=$v" for (k, v) in context], ", ")
            push!(parts, "[$(context_str)]")
        end

        return join(parts, " | ")
    end
end

"""
    write_log(level::LogLevel, message::String, context::Dict=Dict(); config::LogConfig=get_log_config())

Write a log message.

# Arguments
- `level` - Log level
- `message` - Log message
- `context` - Additional context
- `config` - Log configuration
"""
function write_log(level::LogLevel, message::String, context::Dict=Dict(); config::LogConfig=get_log_config())
    # Check if we should log this level
    if level < config.level
        return
    end

    formatted = format_log_message(level, message, context, config=config)

    # Write to stdout
    if config.log_to_stdout
        println(formatted)
    end

    # Write to file
    if config.log_to_file
        try
            mkpath(dirname(config.log_file))
            open(config.log_file, "a") do io
                # Strip ANSI codes for file output
                clean_msg = replace(formatted, r"\e\[[0-9;]*m" => "")
                println(io, clean_msg)
            end
        catch e
            # Don't fail if logging fails, but warn to stderr
            println(stderr, "Failed to write log to file: $e")
        end
    end
end

"""
    log_debug(message::String, context::Dict=Dict())

Log a debug message.

# Example
```julia
log_debug("Compiling function", Dict("name" => "myfunc", "types" => "(Int,)"))
```
"""
function log_debug(message::String, context::Dict=Dict())
    write_log(DEBUG, message, context)
end

"""
    log_info(message::String, context::Dict=Dict())

Log an info message.

# Example
```julia
log_info("Compilation completed", Dict("time" => "2.3s", "size" => "1.2MB"))
```
"""
function log_info(message::String, context::Dict=Dict())
    write_log(INFO, message, context)
end

"""
    log_warn(message::String, context::Dict=Dict())

Log a warning message.

# Example
```julia
log_warn("Binary size larger than expected", Dict("size" => "5MB", "expected" => "1MB"))
```
"""
function log_warn(message::String, context::Dict=Dict())
    write_log(WARN, message, context)
end

"""
    log_error(message::String, context::Dict=Dict())

Log an error message.

# Example
```julia
log_error("Compilation failed", Dict("function" => "myfunc", "error" => "type error"))
```
"""
function log_error(message::String, context::Dict=Dict())
    write_log(ERROR, message, context)
end

"""
    with_logging(f::Function, config::LogConfig)

Execute function with temporary logging configuration.

# Example
```julia
with_logging(LogConfig(level=DEBUG)) do
    compile_executable(func, types, path, name)
end
```
"""
function with_logging(f::Function, config::LogConfig)
    old_config = get_log_config()
    try
        set_log_config(config)
        return f()
    finally
        set_log_config(old_config)
    end
end

"""
    log_section(title::String, f::Function; verbose::Bool=true)

Execute function within a logged section with visual separators.

# Example
```julia
log_section("Compilation") do
    compile_executable(func, types, path, name)
end
```
"""
function log_section(title::String, f::Function; verbose::Bool=true)
    if verbose
        log_info("="^70)
        log_info(title)
        log_info("="^70)
    end

    start_time = time()

    try
        result = f()

        if verbose
            elapsed = time() - start_time
            log_info("Section completed", Dict("title" => title, "time" => "$(round(elapsed, digits=2))s"))
            log_info("")
        end

        return result
    catch e
        elapsed = time() - start_time
        log_error("Section failed", Dict("title" => title, "time" => "$(round(elapsed, digits=2))s", "error" => string(e)))
        rethrow(e)
    end
end

"""
    log_progress(message::String, current::Int, total::Int)

Log progress information.

# Example
```julia
for i in 1:10
    log_progress("Processing items", i, 10)
    process_item(i)
end
```
"""
function log_progress(message::String, current::Int, total::Int)
    pct = round(current / total * 100, digits=1)
    log_info(message, Dict("progress" => "$(current)/$(total)", "percent" => "$(pct)%"))
end

"""
    rotate_log_file(config::LogConfig; max_size_mb::Int=10)

Rotate log file if it exceeds maximum size.

# Arguments
- `config` - Log configuration
- `max_size_mb` - Maximum log file size in MB

# Returns
- `true` if rotated, `false` otherwise
"""
function rotate_log_file(config::LogConfig; max_size_mb::Int=10)
    if !config.log_to_file || !isfile(config.log_file)
        return false
    end

    file_size_mb = filesize(config.log_file) / (1024 * 1024)

    if file_size_mb > max_size_mb
        # Rotate: rename current log to .old, start fresh
        old_file = config.log_file * ".old"
        try
            mv(config.log_file, old_file, force=true)
            log_info("Log file rotated", Dict("size" => "$(round(file_size_mb, digits=2))MB"))
            return true
        catch e
            log_warn("Failed to rotate log file", Dict("error" => string(e)))
            return false
        end
    end

    return false
end

"""
    clear_log_file(config::LogConfig)

Clear the log file.

# Returns
- `true` if cleared successfully
"""
function clear_log_file(config::LogConfig)
    if !config.log_to_file
        return false
    end

    try
        if isfile(config.log_file)
            rm(config.log_file, force=true)
        end
        log_info("Log file cleared")
        return true
    catch e
        log_warn("Failed to clear log file", Dict("error" => string(e)))
        return false
    end
end
