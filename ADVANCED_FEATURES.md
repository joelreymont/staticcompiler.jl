# Advanced Features Guide

This guide covers the advanced static analysis, optimization, and compression features available in StaticCompiler.jl.

## Table of Contents

1. [Advanced Static Analysis](#advanced-static-analysis)
2. [Link-Time Optimization (LTO)](#link-time-optimization-lto)
3. [UPX Compression](#upx-compression)
4. [Complete Optimization Workflows](#complete-optimization-workflows)

---

## Advanced Static Analysis

StaticCompiler.jl provides comprehensive static analysis tools to help you understand and optimize your code before compilation.

### Allocation Analysis

Identify allocations that prevent static compilation:

```julia
using StaticCompiler

function process_data(x::Int)
    result = x * 2
    return result
end

# Analyze allocations
profile = analyze_allocations(process_data, (Int,))

println("Total allocations: $(profile.total_allocations)")
println("Estimated heap usage: $(profile.estimated_bytes) bytes")
println("Heap escapes: $(profile.heap_escapes)")
```

**Output:**
```
Total allocations: 0
Estimated heap usage: 0 bytes
Heap escapes: 0
✅ Function is allocation-free!
```

### Inline Analysis

See what gets inlined and what doesn't:

```julia
inline_info = analyze_inlining(my_func, (Int, Float64))

println("Inlined calls: $(length(inline_info.inlined_calls))")
println("Not inlined: $(length(inline_info.not_inlined))")

for (fname, cost) in inline_info.inline_cost_estimates
    println("  $fname: cost $cost")
end
```

This helps you identify:
- Functions that should be marked `@inline`
- Opportunities to reduce call overhead
- Where type instabilities prevent inlining

### Call Graph Analysis

Visualize function dependencies:

```julia
graph = build_call_graph(my_func, (Int,), max_depth=3)

for node in graph
    println("$(node.function_name) (depth: $(node.depth))")
    println("  Calls: $(join(node.calls, ", "))")
    if !isempty(node.called_by)
        println("  Called by: $(join(node.called_by, ", "))")
    end
end
```

**Use cases:**
- Understanding code structure
- Finding circular dependencies
- Optimizing call chains

### Binary Bloat Analysis

Identify what's making your binaries large:

```julia
bloat = analyze_bloat(my_func, (Int,))

println("Total functions: $(bloat.total_functions)")
println("Large functions (>1KB): $(length(bloat.large_functions))")

println("\nTop contributors to binary size:")
for (name, size) in bloat.large_functions[1:5]
    println("  $name: ~$(round(size/1024, digits=1)) KB")
end

println("\nOptimization suggestions:")
for suggestion in bloat.suggested_consolidations
    println("  • $suggestion")
end
```

**Output example:**
```
Total functions: 23
Large functions (>1KB): 3

Top contributors to binary size:
  julia_main: ~2.3 KB
  julia_helper_1: ~1.5 KB
  julia_compute: ~1.2 KB

Optimization suggestions:
  • Consider splitting large functions into smaller helpers
  • Many type specializations detected - consider using @nospecialize
```

### Comprehensive Analysis

Run all analyses at once:

```julia
report = advanced_analysis(my_func, (Int, Float64))

println("Performance score: $(report.performance_score)/100")
println("Size score: $(report.size_score)/100")
```

**Complete output:**
```
======================================================================
ADVANCED STATIC ANALYSIS REPORT
======================================================================

📊 PERFORMANCE SCORE: 85.0/100
📦 SIZE SCORE: 72.0/100

--- ALLOCATION ANALYSIS ---
Total allocations: 2
Estimated heap usage: 128 bytes
Heap escapes: 1
⚠️  Allocations detected - may prevent static compilation
   Use StaticTools.MallocArray or refactor to avoid allocations

--- INLINING ANALYSIS ---
Inlined calls: 5
Not inlined: 2
Functions not inlined:
  1. helper_func (cost: 15)
  2. compute (cost: 23)

--- CALL GRAPH ---
Total functions: 8
Call hierarchy:
  my_func → calls 3 function(s)
    helper_func → calls 2 function(s)
      compute → calls 1 function(s)

--- BINARY BLOAT ANALYSIS ---
Total functions in IR: 23
Large functions (>1KB): 3
Top contributors to binary size:
  1. julia_main: ~2.3 KB
  2. julia_helper_1: ~1.5 KB
  3. julia_compute: ~1.2 KB
Redundant specializations: 5

💡 OPTIMIZATION SUGGESTIONS:
  • Consider splitting large functions into smaller helpers
  • Many type specializations detected - consider using @nospecialize

======================================================================
```

---

## Link-Time Optimization (LTO)

LTO performs cross-module optimizations at link time, potentially improving both performance and binary size.

### Using LTO Profiles

StaticCompiler provides LTO-enabled optimization profiles:

```julia
using StaticCompiler

# SIZE-optimized with LTO
exe = compile_executable_optimized(
    my_func, (Int,),
    "/tmp", "myapp",
    profile=PROFILE_SIZE_LTO
)

# SPEED-optimized with LTO
exe = compile_executable_optimized(
    my_func, (Int,),
    "/tmp", "myapp",
    profile=PROFILE_SPEED_LTO
)
```

### Important Notes About LTO

⚠️ **Toolchain Requirements:**
- LTO requires proper LLVM/Clang toolchain setup
- The LLVMgold plugin must be available
- Some systems may not have compatible linkers

⚠️ **When LTO Might Fail:**
```
/usr/bin/ld: error loading plugin: LLVMgold.so: cannot open shared object file
```

**Solution:** Use non-LTO profiles (default) or install a complete LLVM toolchain.

### LTO Benefits

**When LTO Works:**
- 5-15% additional size reduction (beyond dead code elimination)
- Better cross-function optimizations
- More aggressive inlining across translation units
- Improved constant propagation

**Trade-offs:**
- Longer compilation times (2-3x slower)
- Higher memory usage during linking
- Requires compatible toolchain

### Custom LTO Configuration

Create custom LTO profiles:

```julia
# Thin LTO for faster compilation
custom_lto = OptimizationProfile(
    OPT_SIZE,
    true,  # enable LTO
    true,  # strip debug
    true,  # strip all symbols
    true,  # dead code elimination
    false, # no UPX
    ["-Os", "-flto=thin", "-ffunction-sections"]
)

exe = compile_executable_optimized(my_func, (), "/tmp", "app", profile=custom_lto)
```

**LTO Options:**
- `-flto` - Full LTO (best optimization, slowest)
- `-flto=thin` - Thin LTO (good compromise)
- `-flto=auto` - Auto-determine based on cores

---

## UPX Compression

UPX (Ultimate Packer for eXecutables) can compress binaries by 50-70% with no runtime performance penalty.

### Installation

```bash
# Ubuntu/Debian
sudo apt-get install upx-ucl

# macOS
brew install upx

# Arch Linux
sudo pacman -S upx
```

### Basic Usage

```julia
using StaticCompiler

# Compile executable
exe = compile_executable(my_func, (), "/tmp", "myapp")

# Compress with UPX
compress_with_upx(exe)
```

**Output:**
```
Compressing with UPX (level: best)...
        File size         Ratio      Format      Name
   --------------------   ------   -----------   -----------
     16384 ->      6144   37.50%   linux/amd64   myapp
✅ Compressed successfully
```

### Compression Levels

UPX provides multiple compression levels:

```julia
# Fast compression (50-60% reduction, very fast)
compress_with_upx(exe, level=:fast)

# Best compression (60-70% reduction, slower)
compress_with_upx(exe, level=:best)

# Brute force (70-75% reduction, much slower)
compress_with_upx(exe, level=:brute)

# Ultra brute force (75-80% reduction, extremely slow)
compress_with_upx(exe, level=:ultra)
```

### Checking UPX Availability

```julia
avail, version = test_upx_available()

if avail
    println("UPX version $version is available")
    compress_with_upx(my_exe)
else
    println("UPX not installed")
end
```

### Using UPX in Profiles

Enable automatic UPX compression:

```julia
# AGGRESSIVE profile includes UPX compression
exe = compile_executable_optimized(
    my_func, (), "/tmp", "myapp",
    profile=PROFILE_AGGRESSIVE
)
```

Or create a custom compressed profile:

```julia
compressed_profile = OptimizationProfile(
    OPT_SIZE,
    false, # no LTO
    true,  # strip debug
    true,  # strip all
    true,  # dead code elim
    true,  # compress with UPX
    ["-Os", "-ffunction-sections", "-fdata-sections"]
)

exe = compile_executable_optimized(my_func, (), "/tmp", "app", profile=compressed_profile)
```

### UPX Performance Impact

**Size Reduction Examples:**
```
Original: 1,024 KB
After strip: 924 KB (-9.8%)
After UPX:  350 KB (-65.8% total)
```

**Runtime Performance:**
- First execution: ~10-50ms decompression overhead
- Subsequent executions: No overhead (stays decompressed in memory)
- Overall: Negligible impact for most applications

**When to Use UPX:**
- ✅ Distribution of small utilities
- ✅ Embedded systems with limited storage
- ✅ Reducing download sizes
- ✅ Deployments where size matters
- ❌ Frequently executed daemons (small overhead on startup)
- ❌ Security-critical applications (may trigger AV false positives)

---

## Complete Optimization Workflows

### Workflow 1: Maximum Size Reduction

```julia
using StaticCompiler

# 1. Analyze to understand bloat
report = advanced_analysis(my_func, (Int,), verbose=true)

# 2. Compile with size optimization
exe = compile_executable_optimized(
    my_func, (Int,),
    "/tmp", "myapp",
    profile=PROFILE_SIZE
)

# 3. Compress with UPX
compress_with_upx(exe, level=:best)

# 4. Analyze final binary
final_analysis = analyze_binary_size(exe)
println("Final size: $(final_analysis[:total_kb]) KB")
```

**Expected Results:**
```
Original (unoptimized): 25.5 KB
After PROFILE_SIZE:     15.7 KB (-38%)
After UPX compression:   6.2 KB (-76% total)
```

### Workflow 2: Maximum Performance

```julia
# 1. Check for allocations and type instabilities
report = advanced_analysis(my_func, (Int,))
if report.allocations.total_allocations > 0
    @warn "Allocations detected - may impact performance"
end

# 2. Compile with speed optimization
exe = compile_executable_optimized(
    my_func, (Int,),
    "/tmp", "myapp",
    profile=PROFILE_SPEED
)

# 3. Benchmark
using BenchmarkTools
@btime run(`$exe`)
```

### Workflow 3: Balanced Optimization

```julia
# Use AGGRESSIVE profile for balanced optimization
exe = compile_executable_optimized(
    my_func, (Int,),
    "/tmp", "myapp",
    profile=PROFILE_AGGRESSIVE
)

# This combines:
# - Fast math optimizations (-ffast-math)
# - Native CPU instructions (-march=native)
# - Dead code elimination
# - Symbol stripping
# - UPX compression
```

### Workflow 4: Debugging Build

```julia
# Compile with debug info
exe = compile_executable_optimized(
    my_func, (Int,),
    "/tmp", "myapp",
    profile=PROFILE_DEBUG
)

# Debug with gdb
run(`gdb $exe`)
```

---

## Optimization Profiles Reference

| Profile | Size | Speed | LTO | Strip | UPX | Use Case |
|---------|------|-------|-----|-------|-----|----------|
| `PROFILE_SIZE` | ⭐⭐⭐ | ⭐ | ❌ | ✅ | ❌ | Minimal binaries |
| `PROFILE_SIZE_LTO` | ⭐⭐⭐⭐ | ⭐ | ✅ | ✅ | ❌ | Maximum size reduction |
| `PROFILE_SPEED` | ⭐ | ⭐⭐⭐ | ❌ | ❌ | ❌ | High performance |
| `PROFILE_SPEED_LTO` | ⭐ | ⭐⭐⭐⭐ | ✅ | ❌ | ❌ | Maximum performance |
| `PROFILE_AGGRESSIVE` | ⭐⭐⭐⭐ | ⭐⭐⭐ | ❌ | ✅ | ✅ | Best overall |
| `PROFILE_DEBUG` | ⭐ | ⭐ | ❌ | ❌ | ❌ | Development |

---

## Best Practices

### 1. Always Analyze First

```julia
# Don't just compile blindly
report = advanced_analysis(my_func, (Int,))

# Fix issues before compiling
if report.allocations.total_allocations > 0
    # Refactor to remove allocations
end

if report.performance_score < 70
    # Investigate performance issues
end
```

### 2. Choose the Right Profile

```julia
# Development: Fast iteration
PROFILE_DEBUG

# Production: Balanced
PROFILE_AGGRESSIVE

# Embedded: Minimal size
PROFILE_SIZE + UPX

# HPC: Maximum speed
PROFILE_SPEED_LTO
```

### 3. Benchmark Your Changes

```julia
# Before optimization
exe1 = compile_executable(my_func, (), "/tmp", "before")
before_size = filesize(exe1) / 1024
before_time = @elapsed run(`$exe1`)

# After optimization
exe2 = compile_executable_optimized(my_func, (), "/tmp", "after", profile=PROFILE_AGGRESSIVE)
after_size = filesize(exe2) / 1024
after_time = @elapsed run(`$exe2`)

println("Size: $(before_size) KB → $(after_size) KB ($(round((1-after_size/before_size)*100, digits=1))% reduction)")
println("Time: $(before_time) s → $(after_time) s")
```

### 4. Iterate and Refine

```julia
# 1. Analyze
report = advanced_analysis(my_func, (Int,))

# 2. Identify bottlenecks
for (name, size) in report.bloat.large_functions
    println("Large function: $name ($size bytes)")
end

# 3. Refactor problematic code
# ... make changes ...

# 4. Re-analyze to verify improvements
new_report = advanced_analysis(my_func, (Int,))
println("Performance: $(report.performance_score) → $(new_report.performance_score)")
```

---

## Troubleshooting

### LTO Fails with Plugin Error

```
Error: LLVMgold.so: cannot open shared object file
```

**Solution:** Use non-LTO profiles (they're the default now):
```julia
# These work without LTO
PROFILE_SIZE  # instead of PROFILE_SIZE_LTO
PROFILE_SPEED # instead of PROFILE_SPEED_LTO
```

### UPX Compression Fails

```
Warning: UPX not found
```

**Solution:** Install UPX:
```bash
sudo apt-get install upx-ucl  # Linux
brew install upx              # macOS
```

### Binary Already Compressed

```
Warning: Binary already compressed or not compressible with UPX
```

**Solution:** This is normal if you already compressed it. UPX can't compress itself.

### Analysis Shows Many Allocations

```
⚠️  Allocations detected - may prevent static compilation
```

**Solution:** Refactor to use StaticTools:
```julia
# Instead of:
arr = [1, 2, 3, 4, 5]

# Use:
using StaticTools
arr = MallocArray{Int}(5)
```

---

## Summary

StaticCompiler.jl now provides:

✅ **Advanced Static Analysis**
- Allocation profiling
- Inline analysis
- Call graph visualization
- Binary bloat detection

✅ **Link-Time Optimization**
- Thin LTO for better performance
- Size and speed profiles
- Automatic toolchain detection

✅ **UPX Compression**
- 50-70% size reduction
- Multiple compression levels
- Automatic availability detection

✅ **Complete Workflows**
- Size optimization
- Performance optimization
- Balanced optimization
- Debug builds

Use these tools to create optimal static binaries for any use case!
