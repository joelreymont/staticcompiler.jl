# Interactive TUI Guide

StaticCompiler.jl includes an interactive terminal user interface (TUI) for exploring optimization options without writing code.

## Quick Start

```julia
using StaticCompiler

# Define your function
function fibonacci(n::Int)
    if n <= 1
        return n
    end
    a, b = 0, 1
    for _ in 2:n
        a, b = b, a + b
    end
    return b
end

# Launch interactive mode
interactive_optimize(fibonacci, (Int,), "dist", "fib", args=(30,))
```

## Main Menu

The interactive TUI presents a menu-driven interface:

```
======================================================================
StaticCompiler.jl - Interactive Optimization
======================================================================

Function: fibonacci
Types: (Int64,)
Output: dist/fib

======================================================================
MAIN MENU
======================================================================

1. Quick compile (auto-select best preset)
2. Choose optimization preset
3. Compare presets
4. Run Profile-Guided Optimization (PGO)
5. Cross-compile for target platform
6. View available presets
7. View cross-compilation targets
8. Advanced settings
9. Exit

Choice:
```

## Features

### 1. Quick Compile

Automatically analyze your function and select the best preset:

```
Choice: 1

Quick Compile (Smart Optimization)
----------------------------------------------------------------------

Analyzing function and selecting optimal preset...

Analysis complete!
Recommended preset: embedded
Strategy: Small function with allocations - minimizing size

Compiling with preset: embedded
...
✓ Compilation complete!
  Binary: dist/fib
  Size: 14.2 KB
  Preset used: embedded
```

### 2. Choose Preset

Manually select an optimization preset:

```
Choice: 2

Choose Optimization Preset
----------------------------------------------------------------------

1. embedded          - Minimal binary size for embedded systems
2. serverless        - Fast startup for serverless/cloud functions
3. hpc               - Maximum performance for HPC workloads
4. desktop           - Balanced optimization for desktop apps
5. development       - Fast compile time for development
6. release           - Production-ready with all optimizations

Choose preset (number): 1

Compiling with preset: embedded
...
✓ Compilation complete!
  Size: 14.2 KB
```

### 3. Compare Presets

Compare multiple presets side-by-side:

```
Choice: 3

Compare Presets
----------------------------------------------------------------------

Select presets to compare:

1. embedded
2. serverless
3. hpc
4. desktop
5. development
6. release

Enter preset numbers (comma-separated, e.g., 1,3,5): 1,2,3

Comparing: embedded, serverless, hpc

Use parallel processing? (y/n): y

Processing batch 1: [embedded, serverless, hpc]
  ✓ embedded (1/3)
  ✓ serverless (2/3)
  ✓ hpc (3/3)

======================================================================
COMPARISON RESULTS
======================================================================

Preset          | Binary Size  | Performance  | Overall Score
----------------------------------------------------------------------
embedded        | 14.2 KB      | 125 μs       | 85.0
serverless      | 18.5 KB      | 98 μs        | 87.5
hpc             | 22.1 KB      | 75 μs        | 90.2
```

### 4. Profile-Guided Optimization

Run iterative PGO for maximum optimization:

```
Choice: 4

Profile-Guided Optimization
----------------------------------------------------------------------

PGO Configuration:

Target metric (speed/size/balanced) [speed]: speed
Number of iterations [3]: 3

Running PGO with 3 iterations targeting speed...

Iteration 1/3
  Using profile: PROFILE_DEBUG
  Median time: 145 μs
  Recommended next: PROFILE_SPEED

Iteration 2/3
  Using profile: PROFILE_SPEED
  Median time: 98 μs
  Change: 32.41% faster
  Recommended next: PROFILE_AGGRESSIVE

Iteration 3/3
  Using profile: PROFILE_AGGRESSIVE
  Median time: 75 μs
  Change: 23.47% faster
  Recommended next: PROFILE_AGGRESSIVE

✓ PGO complete!
  Best profile: PROFILE_AGGRESSIVE
  Improvement: 48.28%
```

### 5. Cross-Compile

Cross-compile for different platforms:

```
Choice: 5

Cross-Compilation
----------------------------------------------------------------------

1. arm64_linux       - ARM64 Linux (glibc)
2. arm64_linux_musl  - ARM64 Linux (musl, static)
3. arm_linux         - ARM32 Linux (hard-float)
4. riscv64_linux     - RISC-V 64-bit Linux
5. x86_64_windows    - x86-64 Windows
6. x86_64_macos      - x86-64 macOS
7. arm64_macos       - ARM64 macOS (Apple Silicon)
8. wasm32            - WebAssembly 32-bit (WASI)
9. embedded_arm      - Embedded ARM Cortex-M4
10. embedded_riscv   - Embedded RISC-V 32-bit

Choose target (number): 1

Select optimization preset:

1. embedded
2. serverless
3. hpc
4. desktop
5. development
6. release

Choose preset (number): 1

Cross-compiling for ARM64 Linux (glibc) with preset embedded...

✓ Cross-compilation complete!
  Size: 14.5 KB
```

### 6. View Presets

Display all available presets with details:

```
Choice: 6

Available Optimization Presets
----------------------------------------------------------------------

embedded:
  Description: Minimal binary size for embedded systems
  Profile: PROFILE_SIZE_LTO
  LTO: true
  UPX: true
  Strip: true
  Recommended for: IoT, microcontrollers, size-constrained

serverless:
  Description: Fast startup for serverless/cloud functions
  Profile: PROFILE_SPEED
  LTO: false
  UPX: false
  Strip: true
  Recommended for: AWS Lambda, cloud functions, fast startup
```

### 7. View Targets

List cross-compilation targets:

```
Choice: 7

Available Cross-Compilation Targets
----------------------------------------------------------------------

arm64_linux:
  Description: ARM64 Linux (glibc)
  Architecture: aarch64
  OS: linux
  Triple: aarch64-unknown-linux-gnu
  CPU: generic

wasm32:
  Description: WebAssembly 32-bit (WASI)
  Architecture: wasm32
  OS: wasm
  Triple: wasm32-unknown-wasi
  CPU: generic
```

### 8. Advanced Settings

Configure logging, caching, and other options:

```
Choice: 8

Advanced Settings
----------------------------------------------------------------------

1. Configure logging
2. View cache statistics
3. Clear cache
4. Configure result caching
5. Back to main menu

Choice: 1

Configure Logging
----------------------------------------------------------------------

Log level (DEBUG/INFO/WARN/ERROR) [INFO]: DEBUG
Log to file? (y/n) [n]: y

✓ Logging configuration updated
  Level: DEBUG
  Log to file: true
```

## Usage Patterns

### Development Workflow

```julia
# 1. Define function
function myapp(n::Int)
    # ... implementation
end

# 2. Launch TUI
interactive_optimize(myapp, (Int,), "dist", "myapp", args=(100,))

# 3. In TUI:
#    - Start with "Quick compile" to get baseline
#    - Use "Compare presets" to find best option
#    - Run "PGO" for final optimization
#    - Use "Cross-compile" for deployment targets
```

### Exploration Mode

```julia
# Launch TUI to explore options
interactive_optimize(test_func, (Int,), "test", "test")

# Try different presets interactively
# Compare results in real-time
# Learn which optimizations work best
```

### Batch Testing

```julia
# Use TUI to test multiple configurations
interactive_optimize(func, types, "dist", "func", args=args)

# Menu navigation:
# 1. Compare all presets
# 2. Note best result
# 3. Cross-compile winners for target platforms
```

## Keyboard Shortcuts

- **Enter** - Confirm selection
- **Number keys** - Select menu option
- **Ctrl+C** - Cancel current operation (returns to menu)
- **9** - Exit from main menu

## Tips

### Efficient Workflow

1. **Start with Quick Compile** - Get immediate results
2. **Compare 2-3 presets** - Find the best for your use case
3. **Run PGO** - Squeeze out final performance
4. **Cross-compile** - Deploy to target platforms

### Benchmarking

Always provide `args` for accurate benchmarking:

```julia
# With args - enables benchmarking
interactive_optimize(func, (Int,), "dist", "func", args=(100,))

# Without args - compilation only
interactive_optimize(func, (Int,), "dist", "func")
```

### Parallel Processing

When comparing presets, use parallel processing for speed:

```
Use parallel processing? (y/n): y
```

This can be 2-4x faster for multiple presets.

### Result Caching

Enable caching in advanced settings to speed up repeated operations:

```
Advanced Settings > Configure result caching > Enable (y)
```

## Integration with Scripts

The TUI can be launched from scripts:

```julia
#!/usr/bin/env julia

using StaticCompiler

function main()
    # Define function
    function app(n::Int)
        # ... implementation
    end

    # Launch interactive mode
    interactive_optimize(app, (Int,), "dist", "app", args=(1000,))
end

main()
```

Run with: `julia script.jl`

## Quick Menu

For simple tasks, use the quick menu:

```julia
quick_interactive_menu()
```

This provides a simplified interface for common operations.

## Advanced Features

### Custom Configurations

Create custom configurations before launching TUI:

```julia
# Set logging
set_log_config(LogConfig(level=DEBUG))

# Configure caching
cache_config = ResultCacheConfig(enabled=true, max_age_days=7)

# Launch TUI
interactive_optimize(func, types, path, name, args=args)
```

### Automation

While the TUI is interactive, you can automate decisions by providing default configurations:

```julia
# Pre-configure settings
set_log_config(LogConfig(level=INFO, log_to_file=true))

# Launch TUI - will use pre-configured settings
interactive_optimize(func, types, path, name)
```

## Troubleshooting

### TUI Not Responding

Press `Ctrl+C` to cancel current operation and return to menu.

### Invalid Input

The TUI validates all input and displays error messages:

```
Invalid choice. Please try again.
```

Simply re-enter a valid choice.

### Compilation Errors

Errors are displayed with context:

```
⚠️ Preset embedded failed
Error: type not supported for static compilation
```

Check function compatibility with StaticCompiler requirements.

## Comparison: TUI vs API

| Feature | TUI | API |
|---------|-----|-----|
| Ease of use | ✓✓✓ Very easy | ✓✓ Requires code |
| Exploration | ✓✓✓ Interactive | ✓ Manual |
| Automation | ✓ Limited | ✓✓✓ Full control |
| Batch operations | ✓✓ Sequential | ✓✓✓ Parallel |
| Learning curve | ✓✓✓ Minimal | ✓✓ Moderate |

**Recommendation:**
- Use TUI for exploration and learning
- Use API for automation and CI/CD

## Example Session

Complete example session:

```julia
julia> using StaticCompiler

julia> function compute(n::Int)
           result = 0
           for i in 1:n
               result += i * i
           end
           return result
       end
compute (generic function with 1 method)

julia> interactive_optimize(compute, (Int,), "dist", "compute", args=(1000,))

======================================================================
StaticCompiler.jl - Interactive Optimization
======================================================================

Function: compute
Types: (Int64,)
Output: dist/compute

======================================================================
MAIN MENU
======================================================================

1. Quick compile (auto-select best preset)
2. Choose optimization preset
3. Compare presets
4. Run Profile-Guided Optimization (PGO)
5. Cross-compile for target platform
6. View available presets
7. View cross-compilation targets
8. Advanced settings
9. Exit

Choice: 1

Quick Compile (Smart Optimization)
----------------------------------------------------------------------

Analyzing function and selecting optimal preset...
Recommended preset: desktop

Compiling with preset: desktop
✓ Compilation complete!
  Binary: dist/compute
  Size: 18.3 KB
  Preset used: desktop

Press Enter to continue...

Choice: 9
Exiting...
```

## Future Enhancements

The TUI is designed to be extensible. Future versions may include:

- Visual progress bars
- Interactive charts for benchmark comparisons
- Saved configurations
- Command history
- Tab completion
- Mouse support
