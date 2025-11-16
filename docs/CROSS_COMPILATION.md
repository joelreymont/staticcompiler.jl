# Cross-Compilation Guide

StaticCompiler.jl supports cross-compilation for multiple target platforms, enabling you to build binaries for different architectures and operating systems.

## Quick Start

```julia
using StaticCompiler

# Get a target
target = get_cross_target(:arm64_linux)

# Cross-compile
binary = cross_compile(
    myfunc, (Int,),
    "dist/arm64",
    "myfunc",
    target
)
```

## Available Targets

List all available cross-compilation targets:

```julia
for (name, description) in list_cross_targets()
    println("$name: $description")
end
```

### Supported Platforms

| Target | Architecture | OS | Description |
|--------|--------------|-----|-------------|
| `:arm64_linux` | aarch64 | Linux (glibc) | ARM64 Linux |
| `:arm64_linux_musl` | aarch64 | Linux (musl) | ARM64 Linux (static) |
| `:arm_linux` | arm | Linux (glibc) | ARM32 Linux |
| `:riscv64_linux` | riscv64 | Linux (glibc) | RISC-V 64-bit |
| `:x86_64_windows` | x86_64 | Windows | 64-bit Windows |
| `:x86_64_macos` | x86_64 | macOS | Intel Mac |
| `:arm64_macos` | aarch64 | macOS | Apple Silicon |
| `:wasm32` | wasm32 | WASI | WebAssembly |
| `:embedded_arm` | arm | None (bare-metal) | ARM Cortex-M4 |
| `:embedded_riscv` | riscv32 | None (bare-metal) | RISC-V 32-bit embedded |

## Basic Cross-Compilation

### Simple Cross-Compile

```julia
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

# Compile for ARM64 Linux
target = get_cross_target(:arm64_linux)
binary = cross_compile(
    fibonacci, (Int,),
    "dist/arm64",
    "fibonacci",
    target
)

println("Binary created: $binary")
```

### With Optimization Preset

```julia
# Cross-compile with embedded preset for minimal size
target = get_cross_target(:arm64_linux_musl)
result = cross_compile_with_preset(
    fibonacci, (Int,),
    "dist/arm64_embedded",
    "fibonacci",
    :embedded,  # Size-optimized preset
    target,
    verbose=true
)

println("Binary size: $(format_bytes(result["binary_size"]))")
if haskey(result, "compressed_size")
    println("Compressed: $(format_bytes(result["compressed_size"]))")
end
```

## Advanced Usage

### Comparing Multiple Targets

Compare compilation results across platforms:

```julia
comparison = compare_cross_targets(
    fibonacci, (Int,),
    "dist/comparison",
    :embedded,
    targets=[:arm64_linux, :arm_linux, :riscv64_linux, :x86_64_linux],
    verbose=true
)

# Results include binary size for each target
for (target_name, result) in comparison
    if haskey(result, "binary_size")
        println("$target_name: $(format_bytes(result["binary_size"]))")
    end
end
```

### Custom Target Flags

Add custom compiler flags:

```julia
target = get_cross_target(:arm64_linux)

# Add custom optimization flags
binary = cross_compile(
    fibonacci, (Int,),
    "dist/custom",
    "fibonacci",
    target,
    cflags=`-march=native -mtune=cortex-a72`
)
```

## Platform-Specific Guides

### Linux ARM64

```julia
# Standard glibc build
target = get_cross_target(:arm64_linux)
cross_compile(func, types, "dist", "app", target)

# Static musl build (no dependencies)
target = get_cross_target(:arm64_linux_musl)
cross_compile_with_preset(
    func, types, "dist", "app",
    :embedded, target
)
```

### Windows from Linux/Mac

```julia
target = get_cross_target(:x86_64_windows)
binary = cross_compile_with_preset(
    func, types, "dist/windows", "app",
    :release,
    target
)
# Creates app.exe
```

### macOS Universal Binaries

```julia
# Intel Mac
target_x86 = get_cross_target(:x86_64_macos)
binary_x86 = cross_compile(func, types, "dist/x86", "app", target_x86)

# Apple Silicon
target_arm = get_cross_target(:arm64_macos)
binary_arm = cross_compile(func, types, "dist/arm", "app", target_arm)

# Combine using lipo (externally)
# lipo -create dist/x86/app dist/arm/app -output dist/app_universal
```

### WebAssembly

```julia
target = get_cross_target(:wasm32)
wasm_binary = cross_compile_with_preset(
    func, types, "dist/wasm", "app",
    :serverless,  # Fast startup
    target
)
# Creates app.wasm
```

### Embedded Systems

#### ARM Cortex-M4

```julia
target = get_cross_target(:embedded_arm)
binary = cross_compile_with_preset(
    func, types, "dist/embedded", "firmware",
    :embedded,
    target
)
# No OS, bare-metal binary
```

#### RISC-V Embedded

```julia
target = get_cross_target(:embedded_riscv)
binary = cross_compile_with_preset(
    func, types, "dist/riscv", "firmware",
    :embedded,
    target
)
```

## Integration with Presets

All optimization presets work with cross-compilation:

```julia
target = get_cross_target(:arm64_linux)

# Size-optimized
cross_compile_with_preset(func, types, "dist", "app", :embedded, target)

# Speed-optimized
cross_compile_with_preset(func, types, "dist", "app", :hpc, target)

# Balanced
cross_compile_with_preset(func, types, "dist", "app", :desktop, target)
```

## Toolchain Requirements

### Linux Targets

```bash
# Install cross-compilers
sudo apt install gcc-aarch64-linux-gnu  # ARM64
sudo apt install gcc-arm-linux-gnueabihf  # ARM32
sudo apt install gcc-riscv64-linux-gnu  # RISC-V
```

### Windows Targets

```bash
# MinGW for Windows cross-compilation
sudo apt install mingw-w64
```

### macOS Targets

macOS SDK required for cross-compilation from Linux:
```bash
# osxcross toolkit
git clone https://github.com/tpoechtrager/osxcross
cd osxcross
# Follow setup instructions
```

### WebAssembly

```bash
# WASI SDK
wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sdk-20.0-linux.tar.gz
tar xf wasi-sdk-20.0-linux.tar.gz
export WASI_SDK_PATH=/path/to/wasi-sdk-20.0
```

## Detecting Host Platform

Automatically detect the current platform:

```julia
host = detect_host_target()
println("Current platform: $(host.description)")
println("Architecture: $(host.arch)")
println("OS: $(host.os)")
```

## Creating Custom Targets

Define your own cross-compilation target:

```julia
custom_target = CrossTarget(
    :my_custom_target,          # Name
    "aarch64",                  # Architecture
    "linux",                    # OS
    "musl",                     # C library
    "aarch64-unknown-linux-musl",  # LLVM triple
    "cortex-a72",               # CPU
    "+crypto",                  # Features
    ["-static", "-O3"],         # Additional flags
    "Custom ARM64 optimized"    # Description
)

binary = cross_compile(func, types, "dist", "app", custom_target)
```

## Troubleshooting

### Missing Toolchain

**Error:** `clang: error: unknown target triple 'aarch64-unknown-linux-gnu'`

**Solution:** Install the appropriate cross-compiler:
```bash
sudo apt install gcc-aarch64-linux-gnu
```

### Library Dependencies

**Error:** Binary fails to run on target due to missing libraries

**Solution:** Use static linking with musl targets:
```julia
target = get_cross_target(:arm64_linux_musl)  # Static binary
```

### Architecture Mismatch

**Error:** Binary crashes on target device

**Solution:** Verify CPU architecture and features:
```julia
target = get_cross_target(:arm64_linux)
println("Triple: $(target.triple)")
println("CPU: $(target.cpu)")
println("Features: $(target.features)")
```

### Testing Cross-Compiled Binaries

Use QEMU for testing:
```bash
# Install QEMU
sudo apt install qemu-user-static

# Test ARM64 binary
qemu-aarch64-static ./dist/arm64/app

# Test RISC-V binary
qemu-riscv64-static ./dist/riscv64/app
```

## Best Practices

1. **Use musl for portability**: Static musl binaries run everywhere
2. **Test on real hardware**: QEMU is helpful but not perfect
3. **Optimize for target CPU**: Specify exact CPU model when possible
4. **Consider binary size**: Embedded targets need minimal binaries
5. **Static linking**: Reduces deployment complexity

## Performance Comparison

Compare native vs cross-compiled binaries:

```julia
# Native compilation
native_result = compile_with_preset(func, types, "dist/native", "app", :hpc)

# Cross-compilation for ARM64
target = get_cross_target(:arm64_linux)
cross_result = cross_compile_with_preset(func, types, "dist/arm64", "app", :hpc, target)

println("Native: $(format_bytes(native_result["binary_size"]))")
println("ARM64:  $(format_bytes(cross_result["binary_size"]))")
```

## Example Workflow

Complete cross-compilation workflow:

```julia
using StaticCompiler

function process_data(n::Int)
    result = 0
    for i in 1:n
        result += i * i
    end
    return result
end

# 1. Analyze on host platform
report = generate_comprehensive_report(process_data, (Int,))
println("Estimated size: $(report.binary_size_bytes) bytes")

# 2. Choose targets
targets = [:arm64_linux, :riscv64_linux, :x86_64_windows]

# 3. Cross-compile for all targets
comparison = compare_cross_targets(
    process_data, (Int,),
    "dist/multi_platform",
    :embedded,  # Size-optimized
    targets=targets,
    verbose=true
)

# 4. Review results
for (target_name, result) in comparison
    println("$target_name: $(format_bytes(result["binary_size"]))")
end
```
