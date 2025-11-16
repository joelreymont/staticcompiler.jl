# Performance Example: Compilation Cache Demo
# Shows the dramatic speedup from caching

using StaticCompiler

# A moderately complex function
function compute_primes(n::Int)
    is_prime(x) = x <= 1 ? false : all(i -> x % i != 0, 2:isqrt(x))
    count = 0
    for i in 2:n
        if is_prime(i)
            count += 1
        end
    end
    return count
end

println("=== Cache Performance Demo ===\n")

# Clear cache to start fresh
clear_cache!()

# First compilation (no cache)
println("First compilation (no cache)...")
t1 = @elapsed begin
    exe1 = compile_shlib(compute_primes, (Int,), "/tmp", "primes1")
end
println("  Time: $(round(t1, digits=3))s")

# Second compilation (with cache)
println("\nSecond compilation (with cache)...")
t2 = @elapsed begin
    exe2 = compile_shlib(compute_primes, (Int,), "/tmp", "primes2")
end
println("  Time: $(round(t2, digits=3))s")

# Show improvement
speedup = t1 / t2
println("\n📊 Results:")
println("  Speedup: $(round(speedup, digits=1))x faster")
println("  Time saved: $(round((t1-t2)*1000, digits=0))ms")

# Cache statistics
stats = cache_stats()
println("\n💾 Cache Stats:")
println("  Entries: $(stats.entries)")
println("  Size: $(round(stats.size_mb, digits=1)) MB")

# Clean up
clear_cache!()
