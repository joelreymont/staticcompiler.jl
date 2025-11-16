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
- **`build_config_demo.jl`** - Save and reuse build configurations

**Concepts covered:**
- Optimization profiles
- UPX compression
- Symbol stripping
- Automated recommendations
- Build configurations
- Reproducible builds

### Analysis Examples (`analysis/`)

Advanced static analysis tools:

- **`simd_demo.jl`** - Analyze SIMD vectorization opportunities
- **`security_demo.jl`** - Detect potential security vulnerabilities
- **`memory_layout_demo.jl`** - Optimize struct memory layouts

**Concepts covered:**
- SIMD vectorization detection
- Security issue analysis
- Memory layout optimization
- Cache efficiency analysis
- Struct field reordering

## Running Examples

Each example is standalone. Just run with Julia:

```bash
# Basic examples
julia examples/basic/fibonacci.jl

# Performance examples
julia examples/performance/cache_demo.jl

# Optimization examples
julia examples/optimization/size_optimization.jl
julia examples/optimization/build_config_demo.jl

# Analysis examples
julia examples/analysis/simd_demo.jl
julia examples/analysis/security_demo.jl
julia examples/analysis/memory_layout_demo.jl
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

### simd_demo.jl
```
=== SIMD Vectorization Analysis Demo ===

1️⃣  Non-vectorized loop:
   Vectorization Score: 0.0/100
   Issues: Loop detected without SIMD vectorization

2️⃣  SIMD-optimized loop:
   Vectorization Score: 80.0/100
   SIMD Instructions: 4

3️⃣  Vector computation:
   Vectorization Score: 100.0/100
   SIMD Instructions Found:
      - Vector multiplication (SIMD)
      - Vector addition (SIMD)
      - Vector load (SIMD)

📊 Summary:
   Scalar loop:  0.0/100
   SIMD loop:    80.0/100
   Vector ops:   100.0/100
```

### security_demo.jl
```
=== Security Analysis Demo ===

1️⃣  Safe bounded access:
   Security Score: 100.0/100
   Issues Found: 0

2️⃣  Unchecked array access:
   Security Score: 50.0/100
   Issues Found: 1
      1. unchecked_access: Unchecked array access detected

3️⃣  Integer arithmetic:
   Security Score: 80.0/100
   Issues Found: 1
      - integer_overflow

4️⃣  Safe with @boundscheck:
   Security Score: 100.0/100
   Issues Found: 0

📊 Security Score Comparison:
   Safe access:      100.0/100
   Unchecked access: 50.0/100
   Integer ops:      80.0/100
   Bounds-checked:   100.0/100
```

### memory_layout_demo.jl
```
=== Memory Layout Optimization Demo ===

1️⃣  Poorly ordered struct:
   Total Size: 32 bytes
   Padding: 14 bytes (43.8% wasted)
   Cache Efficiency: 50.0%

2️⃣  Well-ordered struct:
   Total Size: 24 bytes
   Padding: 6 bytes (25.0% wasted)
   Cache Efficiency: 37.5%

3️⃣  Complex struct:
   Total Size: 40 bytes
   Padding: 11 bytes
   Potential Savings: 8 bytes
   Suggested Order: value1, value2, counter, flag1, flag2

4️⃣  Already optimal struct:
   Total Size: 24 bytes
   Padding: 0 bytes
   Cache Efficiency: 37.5%

📊 Size Comparison:
   Bad Layout:     32 bytes (14 bytes padding)
   Good Layout:    24 bytes (6 bytes padding)
   Complex Layout: 40 bytes (11 bytes padding)
   Optimal Layout: 24 bytes (0 bytes padding)

💾 Memory Savings: 8 bytes (25.0% reduction)
```

### build_config_demo.jl
```
=== Build Configuration Demo ===

1️⃣  Creating size-optimized configuration...
   ✅ Saved to: /tmp/jl_xxx/size_config.jls

2️⃣  Creating speed-optimized configuration...
   ✅ Saved to: /tmp/jl_xxx/speed_config.jls

3️⃣  Loading saved configuration...
   Profile: SIZE
   Name: my_app
   Version: 1.0.0
   Description: Size-optimized build for deployment
   Cache: true
   Strip: true
   UPX: true

4️⃣  Compiling with saved configuration...
   ✅ Compiled successfully!
   Path: /tmp/jl_xxx/my_app
   Size: 14.2 KB
   ✅ Execution successful

5️⃣  Configuration Comparison:

   Size-Optimized Build:
      Profile: SIZE
      Strip: true
      UPX: true (level: best)
      Custom flags: none

   Speed-Optimized Build:
      Profile: SPEED
      Strip: false
      UPX: false
      Custom flags: -march=native
```

## Learning Path

Recommended order for learning:

1. Start with `basic/hello_world.jl` - understand basic compilation
2. Try `basic/fibonacci.jl` - learn about shared libraries
3. Run `performance/cache_demo.jl` - see the performance benefits
4. Explore `optimization/` examples - learn advanced techniques
5. Try `analysis/` examples - understand code analysis and optimization opportunities

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
