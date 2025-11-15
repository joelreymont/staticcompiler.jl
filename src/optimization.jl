# Advanced binary optimization options

@enum OptimizationLevel begin
    OPT_NONE = 0
    OPT_SIZE = 1
    OPT_SPEED = 2
    OPT_AGGRESSIVE = 3
end

struct OptimizationProfile
    level::OptimizationLevel
    lto::Bool                 # Link-time optimization
    strip_debug::Bool         # Remove debug symbols
    strip_all::Bool           # Remove all symbols
    dead_code_elim::Bool      # Dead code elimination
    compress::Bool            # Compress with UPX (if available)
    custom_flags::Vector{String}
end

# Predefined profiles
# Note: LTO disabled by default due to linker plugin issues
# Enable manually with custom flags if your toolchain supports it
const PROFILE_SIZE = OptimizationProfile(
    OPT_SIZE, false, true, true, true, false, ["-Os", "-ffunction-sections", "-fdata-sections"]
)

const PROFILE_SPEED = OptimizationProfile(
    OPT_SPEED, false, false, false, true, false, ["-O3", "-march=native", "-ffast-math"]
)

const PROFILE_AGGRESSIVE = OptimizationProfile(
    OPT_AGGRESSIVE, false, true, true, true, true, ["-O3", "-march=native", "-ffast-math"]
)

const PROFILE_DEBUG = OptimizationProfile(
    OPT_NONE, false, false, false, false, false, ["-g", "-O0"]
)

# LTO-enabled profiles (use only if your toolchain supports it)
const PROFILE_SIZE_LTO = OptimizationProfile(
    OPT_SIZE, true, true, true, true, false,
    ["-Os", "-flto=thin", "-ffunction-sections", "-fdata-sections"]
)

const PROFILE_SPEED_LTO = OptimizationProfile(
    OPT_SPEED, true, false, false, true, false,
    ["-O3", "-flto=thin", "-march=native", "-ffast-math"]
)

"""
    optimize_binary(binary_path, profile::OptimizationProfile)

Apply post-compilation optimizations to a binary.

# Profiles
- `PROFILE_SIZE`: Optimize for minimum size
- `PROFILE_SPEED`: Optimize for maximum speed
- `PROFILE_AGGRESSIVE`: Maximum optimization (size + speed)
- `PROFILE_DEBUG`: Debug build with symbols

# Example
```julia
compile_executable(myfunc, (Int,), "/tmp", "myapp")
optimize_binary("/tmp/myapp", PROFILE_SIZE)
```
"""
function optimize_binary(binary_path::String, profile::OptimizationProfile)
    if !isfile(binary_path)
        error("Binary not found: $binary_path")
    end

    original_size = filesize(binary_path)
    println("Optimizing binary: $binary_path")
    println("Original size: $(round(original_size/1024, digits=1)) KB")

    # Strip debug symbols if requested
    if profile.strip_debug || profile.strip_all
        strip_symbols(binary_path, strip_all=profile.strip_all)
    end

    # Compress with UPX if requested and available
    if profile.compress && upx_available()
        compress_with_upx(binary_path)
    end

    final_size = filesize(binary_path)
    reduction = (1 - final_size/original_size) * 100

    println("Final size: $(round(final_size/1024, digits=1)) KB")
    println("Size reduction: $(round(reduction, digits=1))%")

    return final_size
end

function strip_symbols(binary_path::String; strip_all::Bool=false)
    if !Sys.isunix()
        @warn "Symbol stripping only supported on Unix systems"
        return
    end

    println("Stripping symbols...")

    try
        if strip_all
            run(`strip --strip-all $binary_path`)
        else
            run(`strip --strip-debug $binary_path`)
        end
        println("  Symbols stripped successfully")
    catch e
        @warn "Failed to strip symbols" exception=e
    end
end

function upx_available()
    try
        run(pipeline(`which upx`, devnull, devnull))
        return true
    catch
        return false
    end
end

"""
    compress_with_upx(binary_path; level=:best, verify=true)

Compress binary with UPX.

# Compression levels
- `:fast` - Fast compression, moderate size reduction
- `:best` - Best compression (default), slower but smaller
- `:brute` - Brute force, maximum compression (very slow)
- `:ultra` - Ultra brute force (extremely slow)

# Example
```julia
compress_with_upx("/tmp/myapp", level=:best, verify=true)
```
"""
function compress_with_upx(binary_path::String; level::Symbol=:best, verify::Bool=true)
    if !upx_available()
        @warn "UPX not found, skipping compression. Install with: apt-get install upx-ucl (Linux) or brew install upx (macOS)"
        return
    end

    println("Compressing with UPX (level: $level)...")

    # Build UPX command based on level
    cmd = `upx`

    if level == :fast
        cmd = `$cmd --fast`
    elseif level == :best
        cmd = `$cmd --best --lzma`
    elseif level == :brute
        cmd = `$cmd --brute --lzma`
    elseif level == :ultra
        cmd = `$cmd --ultra-brute --lzma`
    else
        @warn "Unknown compression level: $level, using :best"
        cmd = `$cmd --best --lzma`
    end

    # Add verification flag
    if !verify
        cmd = `$cmd --no-verify`
    end

    # Compress
    try
        run(`$cmd $binary_path`)
        println("  ✅ Compressed successfully")
    catch e
        # UPX can fail on certain binaries, provide helpful error
        if occursin("NotCompressibleException", string(e)) || occursin("already compressed", string(e))
            @warn "Binary already compressed or not compressible with UPX"
        else
            @warn "UPX compression failed" exception=e
        end
    end
end

"""
    test_upx_available()

Test if UPX is available and working.

Returns a tuple of (available::Bool, version::String)

# Example
```julia
avail, ver = test_upx_available()
if avail
    println("UPX version: \$ver")
end
```
"""
function test_upx_available()
    if !upx_available()
        return (false, "")
    end

    try
        output = read(`upx --version`, String)
        version_match = match(r"upx (\d+\.\d+\.\d+)", output)
        version = version_match !== nothing ? version_match.captures[1] : "unknown"
        return (true, version)
    catch
        return (true, "unknown")
    end
end

"""
    get_optimization_flags(profile::OptimizationProfile)

Get compiler flags for a given optimization profile.
"""
function get_optimization_flags(profile::OptimizationProfile)
    flags = String[]

    # Base optimization level
    if profile.level == OPT_NONE
        push!(flags, "-O0")
    elseif profile.level == OPT_SIZE
        push!(flags, "-Os")
    elseif profile.level == OPT_SPEED
        push!(flags, "-O3")
    elseif profile.level == OPT_AGGRESSIVE
        push!(flags, "-O3")
    end

    # Link-time optimization
    if profile.lto
        push!(flags, "-flto")
    end

    # Dead code elimination
    if profile.dead_code_elim
        push!(flags, "-ffunction-sections")
        push!(flags, "-fdata-sections")
        push!(flags, "-Wl,--gc-sections")
    end

    # Add custom flags
    append!(flags, profile.custom_flags)

    return flags
end

"""
    compile_executable_optimized(f, types, path, name;
                                  profile=PROFILE_SIZE, kwargs...)

Compile an executable with a specific optimization profile.

This is a convenience function that combines compilation and optimization.

# Example
```julia
compile_executable_optimized(fib, (Int,), "/tmp", "fib", profile=PROFILE_SIZE)
```
"""
function compile_executable_optimized(f, types, path::String, name::String;
                                      profile::OptimizationProfile=PROFILE_SIZE,
                                      kwargs...)
    # Get optimization flags
    opt_flags = get_optimization_flags(profile)
    cflags = Cmd(opt_flags)

    # Compile with flags
    exe_path = compile_executable(f, types, path, name;
                                  cflags=cflags,
                                  strip_binary=profile.strip_debug || profile.strip_all,
                                  kwargs...)

    # Apply post-compilation optimizations
    optimize_binary(exe_path, profile)

    return exe_path
end

export OptimizationProfile, OptimizationLevel
export PROFILE_SIZE, PROFILE_SPEED, PROFILE_AGGRESSIVE, PROFILE_DEBUG
export PROFILE_SIZE_LTO, PROFILE_SPEED_LTO
export optimize_binary, compile_executable_optimized, get_optimization_flags
export compress_with_upx, test_upx_available
