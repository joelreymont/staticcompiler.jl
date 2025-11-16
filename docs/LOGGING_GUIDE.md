# Logging Guide

StaticCompiler.jl includes a comprehensive logging system for debugging, monitoring, and production use.

## Quick Start

```julia
using StaticCompiler

# Use default logging (INFO level to stdout)
compile_executable(func, types, path, name)

# Enable debug logging
set_log_config(LogConfig(level=DEBUG))
compile_executable(func, types, path, name)

# Log to file
set_log_config(LogConfig(
    level=INFO,
    log_to_file=true,
    log_file="/path/to/staticcompiler.log"
))
```

## Log Levels

StaticCompiler supports five log levels:

- **DEBUG** - Detailed information for diagnostics
- **INFO** - General informational messages (default)
- **WARN** - Warning messages for potential issues
- **ERROR** - Error messages for failures
- **SILENT** - Suppress all logging

```julia
# Set log level
set_log_config(LogConfig(level=DEBUG))  # Most verbose
set_log_config(LogConfig(level=ERROR))  # Errors only
set_log_config(LogConfig(level=SILENT)) # No output
```

## Configuration Options

### LogConfig Structure

```julia
LogConfig(;
    level::LogLevel=INFO,                # Minimum level to log
    log_to_file::Bool=false,            # Write to file
    log_file::String="...",              # Log file path
    log_to_stdout::Bool=true,            # Write to terminal
    use_colors::Bool=true,               # ANSI colors
    timestamp_format::String="...",      # Timestamp format
    include_source::Bool=false,          # Include source location
    json_format::Bool=false              # JSON output
)
```

### Examples

**Console logging with colors:**
```julia
config = LogConfig(
    level=INFO,
    use_colors=true,
    log_to_stdout=true
)
set_log_config(config)
```

**File logging for production:**
```julia
config = LogConfig(
    level=WARN,
    log_to_file=true,
    log_file="/var/log/staticcompiler.log",
    log_to_stdout=false,
    json_format=true  # Structured logs
)
set_log_config(config)
```

**Debug mode with source locations:**
```julia
config = LogConfig(
    level=DEBUG,
    include_source=true
)
set_log_config(config)
```

## Logging Functions

### Basic Logging

```julia
log_debug("Detailed diagnostics", Dict("var" => value))
log_info("General information", Dict("status" => "complete"))
log_warn("Warning message", Dict("threshold" => 100))
log_error("Error occurred", Dict("code" => 500))
```

### Contextual Logging

```julia
# Log with context dictionary
log_info("Compilation started", Dict(
    "function" => "myfunc",
    "types" => "(Int,)",
    "output" => "/path/to/binary"
))
```

### Section Logging

```julia
# Automatically log section start/end with timing
log_section("Optimization Phase") do
    optimize_binary(path, level=3)
end
# Output:
# ======================================================================
# Optimization Phase
# ======================================================================
# ... (your output)
# Section completed | title=Optimization Phase | time=2.3s
```

### Progress Logging

```julia
for i in 1:100
    log_progress("Processing items", i, 100)
    process_item(i)
end
# Output:
# INFO | Processing items | progress=1/100 | percent=1.0%
# INFO | Processing items | progress=2/100 | percent=2.0%
# ...
```

## Temporary Logging

Execute code with temporary logging configuration:

```julia
# Normal logging at INFO level
compile_function1()

# Temporarily enable DEBUG for specific operation
with_logging(LogConfig(level=DEBUG)) do
    compile_function2()  # Logged at DEBUG level
end

# Back to INFO level
compile_function3()
```

## Log File Management

### Rotation

Automatically rotate log files when they exceed a size limit:

```julia
config = get_log_config()
rotated = rotate_log_file(config, max_size_mb=10)

if rotated
    println("Log file rotated (was >10MB)")
end
```

### Clearing

Clear the log file:

```julia
config = get_log_config()
cleared = clear_log_file(config)
```

## Output Formats

### Plain Text (Default)

```
2025-01-15 10:30:45 | INFO       | Compilation started | function=myfunc
2025-01-15 10:30:47 | INFO       | Compilation complete | size=1.2MB
```

### JSON Format

```julia
set_log_config(LogConfig(json_format=true))
```

Output:
```json
{"timestamp":"2025-01-15 10:30:45","level":"INFO","message":"Compilation started","context":{"function":"myfunc"}}
{"timestamp":"2025-01-15 10:30:47","level":"INFO","message":"Compilation complete","context":{"size":"1.2MB"}}
```

### With Colors

Terminal output uses ANSI colors:
- 🔍 DEBUG (Cyan)
- ℹ️ INFO (Green)
- ⚠️ WARN (Yellow)
- ❌ ERROR (Red)

## Best Practices

### Production

```julia
# Production configuration
config = LogConfig(
    level=WARN,              # Only warnings and errors
    log_to_file=true,
    log_file="/var/log/app.log",
    log_to_stdout=false,     # Quiet console
    json_format=true         # Structured for parsing
)
set_log_config(config)
```

### Development

```julia
# Development configuration
config = LogConfig(
    level=DEBUG,             # All messages
    log_to_stdout=true,
    use_colors=true,         # Easy reading
    include_source=true      # Debugging aid
)
set_log_config(config)
```

### CI/CD

```julia
# CI/CD configuration
config = LogConfig(
    level=INFO,
    log_to_file=true,
    log_file="build.log",
    use_colors=false,        # No ANSI in logs
    json_format=false        # Human-readable
)
set_log_config(config)
```

## Integration Examples

### With Error Handling

```julia
try
    log_info("Starting compilation")
    compile_executable(func, types, path, name)
    log_info("Compilation successful")
catch e
    log_error("Compilation failed", Dict(
        "error" => string(e),
        "function" => string(nameof(func))
    ))
    rethrow(e)
end
```

### With Benchmarking

```julia
log_section("Performance Benchmarking") do
    config = BenchmarkConfig(samples=100)
    result = benchmark_function(func, types, args, config=config)

    log_info("Benchmark complete", Dict(
        "median_time" => format_time(result.median_time_ns),
        "binary_size" => format_bytes(result.binary_size_bytes)
    ))
end
```

### With PGO

```julia
log_section("Profile-Guided Optimization") do
    pgo_config = PGOConfig(iterations=3)

    log_info("Starting PGO", Dict("iterations" => 3))

    result = pgo_compile(func, types, args, path, name, config=pgo_config)

    log_info("PGO complete", Dict(
        "improvement" => "$(round(result.improvement_pct, digits=2))%",
        "best_profile" => string(result.best_profile)
    ))
end
```

## Performance Considerations

- **File logging**: Minimal overhead (~1-2% for typical workloads)
- **JSON format**: Slightly slower than plain text (~5-10%)
- **SILENT level**: Zero overhead (all logging skipped)
- **Context dictionaries**: Avoid expensive `string()` conversions in hot paths

## Troubleshooting

### Logs not appearing

```julia
# Check current configuration
config = get_log_config()
println("Level: $(config.level)")
println("To stdout: $(config.log_to_stdout)")
println("To file: $(config.log_to_file)")
```

### File permission errors

```julia
# Ensure directory exists and is writable
log_dir = dirname(config.log_file)
if !isdir(log_dir)
    mkpath(log_dir)
end
```

### Too much output

```julia
# Increase log level to reduce verbosity
set_log_config(LogConfig(level=WARN))  # Only warnings and errors
```

### Need debugging information

```julia
# Temporarily enable debug logging
with_logging(LogConfig(level=DEBUG)) do
    # Your problematic code here
end
```
