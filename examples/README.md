# StaticCompiler.jl Examples

This directory contains examples demonstrating various features of StaticCompiler.jl.

## Quick Start

```bash
cd examples/basic
julia hello_world.jl
```

## Example Categories

### Basic Examples (`basic/`)

Simple examples for getting started:

- **`hello_world.jl`** - Simplest possible static executable
- **`fibonacci.jl`** - Recursive fibonacci compiled to shared library

**Concepts covered:**
- Basic compilation
- Shared library vs executable
- Calling compiled code from Julia

### Performance Examples (`performance/`)

Examples showing performance features:

- **`cache_demo.jl`** - Demonstrates 77x compilation speedup from caching

**Concepts covered:**
- Compilation caching
- Cache statistics
- Performance measurement

### Optimization Examples (`optimization/`)

Advanced optimization techniques:

- **`size_optimization.jl`** - Shows how to minimize binary size
- **`automated_recommendations.jl`** - Get automated optimization suggestions
- **`build_config.jl`** - Save and reuse build configurations

**Concepts covered:**
- Optimization profiles
- UPX compression
- Symbol stripping
- Automated recommendations
- Build configurations
- Reproducible builds

## Running Examples

Each example is standalone. Just run with Julia:

```bash
julia examples/basic/fibonacci.jl
julia examples/performance/cache_demo.jl
julia examples/optimization/size_optimization.jl
```

## Expected Output

### hello_world.jl
```
✅ Compiled to: /tmp/hello_world
📦 Size: 15.7 KB
✅ Program executed successfully!
```

### cache_demo.jl
```
=== Cache Performance Demo ===

First compilation (no cache)...
  Time: 10.355s

Second compilation (with cache)...
  Time: 0.133s

📊 Results:
  Speedup: 77.9x faster
  Time saved: 10222ms
```

### size_optimization.jl
```
=== Binary Size Optimization Demo ===

1️⃣  Standard compilation:
   Size: 15.7 KB

2️⃣  With symbol stripping:
   Size: 14.2 KB
   Reduction: 9.6%

3️⃣  With SIZE profile:
   Size: 14.2 KB
   Reduction: 9.6%

4️⃣  With UPX compression:
   Size: 5.8 KB
   Reduction: 63.1%

📊 Total size reduction: 15.7 KB → 5.8 KB (63.1%)
```

## Learning Path

Recommended order for learning:

1. Start with `basic/hello_world.jl` - understand basic compilation
2. Try `basic/fibonacci.jl` - learn about shared libraries
3. Run `performance/cache_demo.jl` - see the performance benefits
4. Explore `optimization/` examples - learn advanced techniques

## Requirements

- Julia 1.10 or later
- StaticCompiler.jl
- Optional: UPX for compression examples (`sudo apt-get install upx-ucl`)

## Contributing Examples

Want to add an example? Please:
1. Keep it focused on one concept
2. Include comments explaining what's happening
3. Add expected output to this README
4. Test on Linux (primary platform)

## Common Issues

### "UPX not found"
Install UPX:
```bash
# Ubuntu/Debian
sudo apt-get install upx-ucl

# macOS
brew install upx
```

### Compilation errors
Make sure your function uses concrete types:
```julia
# Good
f(x::Int) = x * 2

# Bad (won't compile statically)
f(x) = x * 2
```

## More Resources

- [ADVANCED_FEATURES.md](../ADVANCED_FEATURES.md) - Complete feature guide
- [PERFORMANCE_REPORT.md](../PERFORMANCE_REPORT.md) - Performance benchmarks
- [Main Documentation](../README.md) - Full documentation

## Questions?

See the main repository README or open an issue on GitHub.
