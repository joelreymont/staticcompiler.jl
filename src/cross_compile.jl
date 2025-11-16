# Cross-compilation support for different target platforms

"""
    CrossTarget

Represents a cross-compilation target platform.

# Fields
- `name::Symbol` - Target name
- `arch::String` - Architecture (x86_64, aarch64, arm, riscv64, wasm32, etc.)
- `os::String` - Operating system (linux, darwin, windows, freebsd, wasm, none)
- `libc::String` - C library (glibc, musl, none)
- `triple::String` - LLVM target triple
- `cpu::String` - CPU model
- `features::String` - CPU features
- `cflags::Vector{String}` - Additional C compiler flags
- `description::String` - Human-readable description
"""
struct CrossTarget
    name::Symbol
    arch::String
    os::String
    libc::String
    triple::String
    cpu::String
    features::String
    cflags::Vector{String}
    description::String
end

# Predefined cross-compilation targets
const CROSS_TARGET_ARM64_LINUX = CrossTarget(
    :arm64_linux,
    "aarch64",
    "linux",
    "glibc",
    "aarch64-unknown-linux-gnu",
    "generic",
    "",
    String[],
    "ARM64 Linux (glibc)"
)

const CROSS_TARGET_ARM64_LINUX_MUSL = CrossTarget(
    :arm64_linux_musl,
    "aarch64",
    "linux",
    "musl",
    "aarch64-unknown-linux-musl",
    "generic",
    "",
    ["-static"],
    "ARM64 Linux (musl, static)"
)

const CROSS_TARGET_ARM_LINUX = CrossTarget(
    :arm_linux,
    "arm",
    "linux",
    "glibc",
    "arm-unknown-linux-gnueabihf",
    "generic",
    "",
    String[],
    "ARM32 Linux (hard-float)"
)

const CROSS_TARGET_RISCV64_LINUX = CrossTarget(
    :riscv64_linux,
    "riscv64",
    "linux",
    "glibc",
    "riscv64-unknown-linux-gnu",
    "generic-rv64",
    "+m,+a,+f,+d,+c",
    String[],
    "RISC-V 64-bit Linux"
)

const CROSS_TARGET_X86_64_WINDOWS = CrossTarget(
    :x86_64_windows,
    "x86_64",
    "windows",
    "none",
    "x86_64-w64-mingw32",
    "x86-64",
    "",
    String[],
    "x86-64 Windows"
)

const CROSS_TARGET_X86_64_MACOS = CrossTarget(
    :x86_64_macos,
    "x86_64",
    "darwin",
    "none",
    "x86_64-apple-darwin",
    "x86-64",
    "",
    String[],
    "x86-64 macOS"
)

const CROSS_TARGET_ARM64_MACOS = CrossTarget(
    :arm64_macos,
    "aarch64",
    "darwin",
    "none",
    "aarch64-apple-darwin",
    "apple-a14",
    "",
    String[],
    "ARM64 macOS (Apple Silicon)"
)

const CROSS_TARGET_WASM32 = CrossTarget(
    :wasm32,
    "wasm32",
    "wasm",
    "none",
    "wasm32-unknown-wasi",
    "generic",
    "",
    String[],
    "WebAssembly 32-bit (WASI)"
)

const CROSS_TARGET_EMBEDDED_ARM = CrossTarget(
    :embedded_arm,
    "arm",
    "none",
    "none",
    "arm-none-eabi",
    "cortex-m4",
    "+thumb-mode,+v7em,+fp-armv8d16sp",
    ["-nostdlib", "-ffreestanding"],
    "Embedded ARM Cortex-M4"
)

const CROSS_TARGET_EMBEDDED_RISCV = CrossTarget(
    :embedded_riscv,
    "riscv32",
    "none",
    "none",
    "riscv32-unknown-none-elf",
    "generic-rv32",
    "+m,+c",
    ["-nostdlib", "-ffreestanding"],
    "Embedded RISC-V 32-bit"
)

# Map of all predefined targets
const CROSS_TARGETS = Dict{Symbol, CrossTarget}(
    :arm64_linux => CROSS_TARGET_ARM64_LINUX,
    :arm64_linux_musl => CROSS_TARGET_ARM64_LINUX_MUSL,
    :arm_linux => CROSS_TARGET_ARM_LINUX,
    :riscv64_linux => CROSS_TARGET_RISCV64_LINUX,
    :x86_64_windows => CROSS_TARGET_X86_64_WINDOWS,
    :x86_64_macos => CROSS_TARGET_X86_64_MACOS,
    :arm64_macos => CROSS_TARGET_ARM64_MACOS,
    :wasm32 => CROSS_TARGET_WASM32,
    :embedded_arm => CROSS_TARGET_EMBEDDED_ARM,
    :embedded_riscv => CROSS_TARGET_EMBEDDED_RISCV
)

"""
    get_cross_target(name::Symbol)

Get a predefined cross-compilation target by name.

# Arguments
- `name` - Target name (e.g., :arm64_linux, :wasm32)

# Returns
- `CrossTarget` object

# Example
```julia
target = get_cross_target(:arm64_linux)
println("Compiling for: \$(target.description)")
```
"""
function get_cross_target(name::Symbol)
    if !haskey(CROSS_TARGETS, name)
        available = join(sort(collect(keys(CROSS_TARGETS))), ", ")
        error("Unknown cross-compilation target: $name. Available: $available")
    end
    return CROSS_TARGETS[name]
end

"""
    list_cross_targets()

List all available cross-compilation targets.

# Returns
- Vector of (name, description) tuples

# Example
```julia
for (name, desc) in list_cross_targets()
    println("\$name: \$desc")
end
```
"""
function list_cross_targets()
    return [(name, target.description) for (name, target) in sort(collect(CROSS_TARGETS), by=x->x[1])]
end

"""
    cross_compile(f, types, output_path, name, target::CrossTarget; kwargs...)

Cross-compile a function for a different target platform.

# Arguments
- `f` - Function to compile
- `types` - Type signature
- `output_path` - Output directory
- `name` - Binary name
- `target` - CrossTarget specification
- `kwargs...` - Additional arguments for compile_executable

# Returns
- Path to compiled binary

# Example
```julia
target = get_cross_target(:arm64_linux)
binary = cross_compile(myfunc, (Int,), "dist", "myfunc", target)
```
"""
function cross_compile(f, types, output_path, name, target::CrossTarget; kwargs...)
    log_info("Cross-compiling for target", Dict(
        "target" => target.name,
        "arch" => target.arch,
        "os" => target.os,
        "triple" => target.triple
    ))

    # Create StaticTarget with cross-compilation settings
    static_target = StaticTarget(;
        triple=target.triple,
        cpu=target.cpu,
        features=target.features
    )

    # Combine cross-compilation cflags with any user-provided flags
    cross_cflags = target.cflags
    user_cflags = get(kwargs, :cflags, ``)

    combined_cflags = if !isempty(cross_cflags)
        Cmd(vcat(cross_cflags, user_cflags.exec))
    else
        user_cflags
    end

    # Remove cflags from kwargs and add combined version
    filtered_kwargs = Dict(k => v for (k, v) in kwargs if k != :cflags)

    try
        binary_path = compile_executable(
            f, types, output_path, name;
            target=static_target,
            cflags=combined_cflags,
            filtered_kwargs...
        )

        log_info("Cross-compilation successful", Dict(
            "binary" => binary_path,
            "size" => format_bytes(filesize(binary_path))
        ))

        return binary_path
    catch e
        log_error("Cross-compilation failed", Dict(
            "target" => target.name,
            "error" => string(e)
        ))
        rethrow(e)
    end
end

"""
    cross_compile_with_preset(f, types, output_path, name, preset_name::Symbol, target::CrossTarget; args=nothing, verbose=true)

Cross-compile with an optimization preset for a target platform.

# Arguments
- `f` - Function to compile
- `types` - Type signature
- `output_path` - Output directory
- `name` - Binary name
- `preset_name` - Preset name (e.g., :embedded, :serverless)
- `target` - CrossTarget specification
- `args` - Optional args for benchmarking
- `verbose` - Print progress

# Returns
- Dictionary with compilation results

# Example
```julia
target = get_cross_target(:arm64_linux)
result = cross_compile_with_preset(
    myfunc, (Int,), "dist", "myfunc",
    :embedded, target
)
```
"""
function cross_compile_with_preset(f, types, output_path, name, preset_name::Symbol, target::CrossTarget; args=nothing, verbose=true)
    if verbose
        log_section("Cross-Compilation with Preset") do
            println("Preset: $preset_name")
            println("Target: $(target.name) - $(target.description)")
            println("Architecture: $(target.arch)")
            println("OS: $(target.os)")
            println()
        end
    end

    # Get preset configuration
    preset = get_preset(preset_name)

    # Get optimization flags from preset
    profile = get_profile_by_symbol(preset.optimization_profile)
    opt_flags = get_optimization_flags(profile)

    # Override with build config if available
    if preset.build_config !== nothing && !isempty(preset.build_config.optimization_flags)
        opt_flags = preset.build_config.optimization_flags
    end

    # Combine with cross-compilation flags
    all_cflags = Cmd(vcat(target.cflags, opt_flags))

    # Create static target
    static_target = StaticTarget(;
        triple=target.triple,
        cpu=target.cpu,
        features=target.features
    )

    # Compile
    binary_path = compile_executable(
        f, types, output_path, name,
        target=static_target,
        cflags=all_cflags,
        strip_binary=preset.strip_binary
    )

    results = Dict{String, Any}(
        "binary_path" => binary_path,
        "target" => target.name,
        "preset" => preset_name
    )

    if isfile(binary_path)
        binary_size = filesize(binary_path)
        results["binary_size"] = binary_size

        if verbose
            log_info("Compilation complete", Dict(
                "binary" => binary_path,
                "size" => format_bytes(binary_size)
            ))
        end

        # Apply UPX if enabled (and if binary format supports it)
        if preset.use_upx && target.os in ["linux", "windows", "darwin"]
            if verbose
                log_info("Compressing with UPX...")
            end

            upx_level = preset.build_config !== nothing ? preset.build_config.upx_level : 9
            success, compressed_size = compress_with_upx(binary_path, level=upx_level, verbose=false)

            if success
                results["compressed_size"] = compressed_size
                results["compression_ratio"] = round(compressed_size / binary_size, digits=3)

                if verbose
                    log_info("UPX compression successful", Dict(
                        "original" => format_bytes(binary_size),
                        "compressed" => format_bytes(compressed_size),
                        "ratio" => "$(round((1 - compressed_size/binary_size) * 100, digits=1))%"
                    ))
                end
            end
        end
    end

    return results
end

"""
    compare_cross_targets(f, types, output_dir, preset::Symbol; targets=[:arm64_linux, :x86_64_linux], verbose=true)

Compare compilation results across multiple target platforms.

# Arguments
- `f` - Function to compile
- `types` - Type signature
- `output_dir` - Output directory
- `preset` - Preset to use for all targets
- `targets` - Vector of target names to compare
- `verbose` - Print comparison table

# Returns
- Dictionary mapping target names to results

# Example
```julia
comparison = compare_cross_targets(
    myfunc, (Int,),
    "dist",
    :embedded,
    targets=[:arm64_linux, :arm_linux, :riscv64_linux]
)
```
"""
function compare_cross_targets(f, types, output_dir, preset::Symbol;
                               targets=[:arm64_linux, :x86_64_linux],
                               verbose=true)
    if verbose
        log_section("Cross-Target Comparison") do
            println("Preset: $preset")
            println("Targets: $(length(targets))")
            println()
        end
    end

    results = Dict{Symbol, Any}()

    for target_name in targets
        if verbose
            log_info("Compiling for $target_name...")
        end

        target = get_cross_target(target_name)

        try
            result = cross_compile_with_preset(
                f, types,
                joinpath(output_dir, string(target_name)),
                "test_$(target_name)",
                preset,
                target,
                verbose=false
            )

            results[target_name] = result

            if verbose
                log_info("✓ $target_name completed")
            end
        catch e
            log_error("✗ $target_name failed", Dict("error" => string(e)))
        end
    end

    # Print comparison table
    if verbose
        println()
        log_info("="^70)
        log_info("COMPARISON RESULTS")
        log_info("="^70)
        println()

        println(rpad("Target", 20) * " | " *
                rpad("Architecture", 12) * " | " *
                rpad("Binary Size", 12) * " | " *
                rpad("Compressed", 12))
        println("-"^70)

        for target_name in targets
            if haskey(results, target_name)
                result = results[target_name]
                target = get_cross_target(target_name)

                size_str = haskey(result, "binary_size") ?
                          format_bytes(result["binary_size"]) :
                          "N/A"

                compressed_str = haskey(result, "compressed_size") ?
                                format_bytes(result["compressed_size"]) :
                                "N/A"

                println(rpad(string(target_name), 20) * " | " *
                       rpad(target.arch, 12) * " | " *
                       rpad(size_str, 12) * " | " *
                       rpad(compressed_str, 12))
            end
        end

        println()
    end

    return results
end

"""
    detect_host_target()

Detect the current host platform as a CrossTarget.

# Returns
- `CrossTarget` matching the host system

# Example
```julia
host = detect_host_target()
println("Running on: \$(host.description)")
```
"""
function detect_host_target()
    arch = string(Sys.ARCH)
    os_name = Sys.islinux() ? "linux" :
              Sys.isapple() ? "darwin" :
              Sys.iswindows() ? "windows" :
              "unknown"

    # Try to match against known targets
    for (name, target) in CROSS_TARGETS
        if target.arch == arch && target.os == os_name
            return target
        end
    end

    # Fallback: create a basic target
    triple = if Sys.islinux()
        "$arch-unknown-linux-gnu"
    elseif Sys.isapple()
        "$arch-apple-darwin"
    elseif Sys.iswindows()
        "$arch-w64-mingw32"
    else
        "$arch-unknown-unknown"
    end

    return CrossTarget(
        :host,
        arch,
        os_name,
        "default",
        triple,
        "native",
        "",
        String[],
        "Host platform (detected)"
    )
end
