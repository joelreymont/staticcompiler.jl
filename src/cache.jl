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
Includes hash of method source to detect code changes.
"""
function cache_key(f, types, target)
    # Get method signatures to detect code changes
    tt = Base.to_tuple_type(types)
    method_hash = try
        m = which(f, tt)
        # Hash the method signature and code location
        hash((m.sig, m.file, m.line, m.module))
    catch
        # If method lookup fails, use function object hash
        hash(f)
    end

    key_string = string(f, types, method_hash, LLVM.triple(target.tm), LLVM.cpu(target.tm), LLVM.features(target.tm))
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

"""
    cache_stats()

Get cache statistics including size and entry count.
"""
function cache_stats()
    cache_dir = get_cache_dir()
    if !isdir(cache_dir)
        return (entries=0, size_mb=0.0)
    end

    files = filter(f -> endswith(f, ".cache"), readdir(cache_dir, join=true))
    total_size = sum(filesize(f) for f in files; init=0)

    return (entries=length(files), size_mb=total_size / 1024 / 1024)
end

"""
    prune_cache!(; max_age_days=30, max_size_mb=1000)

Remove old cache entries to keep cache size manageable.
Removes oldest entries first until size is under max_size_mb.
Also removes entries older than max_age_days.
"""
function prune_cache!(; max_age_days=30, max_size_mb=1000)
    cache_dir = get_cache_dir()
    if !isdir(cache_dir)
        return 0
    end

    files = filter(f -> endswith(f, ".cache"), readdir(cache_dir, join=true))
    current_time = time()
    removed = 0

    # Remove entries older than max_age_days
    max_age_seconds = max_age_days * 24 * 3600
    for file in files
        try
            entry = deserialize(file)
            if current_time - entry.timestamp > max_age_seconds
                rm(file, force=true)
                removed += 1
            end
        catch
            # Remove corrupted cache files
            rm(file, force=true)
            removed += 1
        end
    end

    # Check remaining size
    files = filter(f -> endswith(f, ".cache") && isfile(f), readdir(cache_dir, join=true))
    total_size = sum(filesize(f) for f in files; init=0)
    max_size_bytes = max_size_mb * 1024 * 1024

    # If still over size limit, remove oldest entries
    if total_size > max_size_bytes
        # Sort by modification time (oldest first)
        file_times = [(f, mtime(f)) for f in files]
        sort!(file_times, by=x->x[2])

        current_size = total_size
        for (file, _) in file_times
            if current_size <= max_size_bytes
                break
            end
            fsize = filesize(file)
            rm(file, force=true)
            current_size -= fsize
            removed += 1
        end
    end

    return removed
end

export clear_cache!, cache_stats, prune_cache!
