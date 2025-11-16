# Build configuration management (using native Julia serialization)

"""
Build configuration for static compilation
"""
struct BuildConfig
    # Optimization
    profile_name::String  # "SIZE", "SPEED", "AGGRESSIVE", "DEBUG", "SIZE_LTO", "SPEED_LTO"
    custom_cflags::Vector{String}

    # Features
    cache_enabled::Bool
    strip_binary::Bool

    # Post-processing
    upx_compression::Bool
    upx_level::Symbol

    # Metadata
    name::String
    version::String
    description::String
end

# Default constructor
function BuildConfig(;
    profile::OptimizationProfile=PROFILE_SIZE,
    custom_cflags::Vector{String}=String[],
    cache_enabled::Bool=true,
    strip_binary::Bool=true,
    upx_compression::Bool=false,
    upx_level::Symbol=:best,
    name::String="application",
    version::String="0.1.0",
    description::String=""
)
    # Convert profile to name
    profile_name = profile_to_name(profile)

    return BuildConfig(
        profile_name, custom_cflags,
        cache_enabled, strip_binary,
        upx_compression, upx_level,
        name, version, description
    )
end

function profile_to_name(profile::OptimizationProfile)
    if profile === PROFILE_SIZE
        return "SIZE"
    elseif profile === PROFILE_SPEED
        return "SPEED"
    elseif profile === PROFILE_AGGRESSIVE
        return "AGGRESSIVE"
    elseif profile === PROFILE_DEBUG
        return "DEBUG"
    elseif profile === PROFILE_SIZE_LTO
        return "SIZE_LTO"
    elseif profile === PROFILE_SPEED_LTO
        return "SPEED_LTO"
    else
        return "CUSTOM"
    end
end

function name_to_profile(name::String)
    if name == "SIZE"
        return PROFILE_SIZE
    elseif name == "SPEED"
        return PROFILE_SPEED
    elseif name == "AGGRESSIVE"
        return PROFILE_AGGRESSIVE
    elseif name == "DEBUG"
        return PROFILE_DEBUG
    elseif name == "SIZE_LTO"
        return PROFILE_SIZE_LTO
    elseif name == "SPEED_LTO"
        return PROFILE_SPEED_LTO
    else
        return PROFILE_SIZE
    end
end

"""
    save_config(config::BuildConfig, filepath::String)

Save build configuration to a file using Julia serialization.

# Example
```julia
config = BuildConfig(
    profile=PROFILE_AGGRESSIVE,
    upx_compression=true,
    name="myapp",
    version="1.0.0"
)
save_config(config, "build.jlconfig")
```
"""
function save_config(config::BuildConfig, filepath::String)
    open(filepath, "w") do io
        serialize(io, config)
    end
    println("✅ Configuration saved to: $filepath")
end

"""
    load_config(filepath::String)

Load build configuration from a file.

# Example
```julia
config = load_config("build.jlconfig")
exe = compile_with_config(my_func, (Int,), config)
```
"""
function load_config(filepath::String)
    if !isfile(filepath)
        error("Configuration file not found: $filepath")
    end

    config = open(filepath, "r") do io
        deserialize(io)
    end

    if !(config isa BuildConfig)
        error("Invalid configuration file format")
    end

    return config
end

"""
    compile_with_config(f, types, config::BuildConfig; path=tempdir())

Compile a function using a build configuration.

# Example
```julia
config = load_config("build.jlconfig")
exe = compile_with_config(my_func, (Int,), config, path="/tmp")
```
"""
function compile_with_config(f, types, config::BuildConfig; path::String=tempdir())
    println("📋 Using build configuration: $(config.name) v$(config.version)")

    if !isempty(config.description)
        println("   $(config.description)")
    end

    # Get profile
    profile = name_to_profile(config.profile_name)

    # Build compiler flags
    cflags = Cmd(config.custom_cflags)

    # Compile with profile
    exe = compile_executable_optimized(
        f, types, path, config.name,
        profile=profile,
        strip_binary=config.strip_binary,
        cflags=cflags
    )

    # Apply UPX compression if requested
    if config.upx_compression
        compress_with_upx(exe, level=config.upx_level)
    end

    return exe
end

"""
    create_default_config(filepath::String)

Create a default build configuration file.

# Example
```julia
create_default_config("build.jlconfig")
# Edit and then use:
config = load_config("build.jlconfig")
```
"""
function create_default_config(filepath::String)
    config = BuildConfig(
        profile=PROFILE_SIZE,
        name="myapp",
        version="0.1.0",
        description="My static application"
    )

    save_config(config, filepath)

    println("""
    ✅ Default configuration created!

    Load and use with:
        config = load_config("$filepath")
        exe = compile_with_config(my_func, types, config)
    """)
end

"""
    show_config(config::BuildConfig)

Display build configuration in a readable format.
"""
function Base.show(io::IO, config::BuildConfig)
    println(io, "BuildConfig:")
    println(io, "  Name: $(config.name) v$(config.version)")
    if !isempty(config.description)
        println(io, "  Description: $(config.description)")
    end
    println(io, "  Profile: $(config.profile_name)")
    println(io, "  Cache: $(config.cache_enabled ? "enabled" : "disabled")")
    println(io, "  Strip: $(config.strip_binary)")
    println(io, "  UPX: $(config.upx_compression ? "enabled ($(config.upx_level))" : "disabled")")
    if !isempty(config.custom_cflags)
        println(io, "  Custom flags: $(join(config.custom_cflags, " "))")
    end
end

export BuildConfig, save_config, load_config, compile_with_config, create_default_config
