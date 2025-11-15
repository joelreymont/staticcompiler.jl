# Compilation cache for LLVM modules and object code

using SHA

struct CacheEntry
    llvm_ir::String
    object_code::Vector{UInt8}
    timestamp::Float64
    julia_version::VersionNumber
end

const CACHE_DIR = Ref{String}("")

function get_cache_dir()
    if isempty(CACHE_DIR[])
        CACHE_DIR[] = joinpath(homedir(), ".julia", "staticcompiler_cache", "v$(VERSION.major).$(VERSION.minor)")
    end
    return CACHE_DIR[]
end

"""
    cache_key(f, types, target)

Generate a unique cache key for a function compilation.
"""
function cache_key(f, types, target)
    key_string = string(f, types, LLVM.triple(target.tm), LLVM.cpu(target.tm), LLVM.features(target.tm))
    bytes2hex(sha256(key_string))
end

"""
    get_cached(f, types, target)

Retrieve cached compilation result if available and valid.
"""
function get_cached(f, types, target)
    key = cache_key(f, types, target)
    cache_file = joinpath(get_cache_dir(), key * ".cache")

    if isfile(cache_file)
        try
            entry = deserialize(cache_file)
            # Validate julia version matches
            if entry.julia_version == VERSION
                return entry
            end
        catch
            # Cache corrupted or incompatible, remove it
            rm(cache_file, force=true)
        end
    end

    return nothing
end

"""
    cache_result!(f, types, target, llvm_ir, object_code)

Store compilation result in cache.
"""
function cache_result!(f, types, target, llvm_ir, object_code)
    cache_dir = get_cache_dir()
    mkpath(cache_dir)

    key = cache_key(f, types, target)
    cache_file = joinpath(cache_dir, key * ".cache")

    entry = CacheEntry(llvm_ir, object_code, time(), VERSION)

    try
        serialize(cache_file, entry)
    catch e
        # If caching fails, just continue without cache
        @debug "Failed to write cache" exception=e
    end

    return nothing
end

"""
    clear_cache!()

Remove all cached compilation results.
"""
function clear_cache!()
    cache_dir = get_cache_dir()
    if isdir(cache_dir)
        rm(cache_dir, recursive=true, force=true)
    end
    return nothing
end

export clear_cache!
