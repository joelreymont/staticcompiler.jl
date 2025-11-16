# Advanced Features Guide

This guide covers the advanced static analysis, optimization, and compression features available in StaticCompiler.jl.

## Table of Contents

1. [Advanced Static Analysis](#advanced-static-analysis)
2. [Link-Time Optimization (LTO)](#link-time-optimization-lto)
3. [UPX Compression](#upx-compression)
4. [Build Configuration System](#build-configuration-system)
5. [SIMD Vectorization Analysis](#simd-vectorization-analysis)
6. [Security Analysis](#security-analysis)
7. [Memory Layout Optimization](#memory-layout-optimization)
8. [Interactive Optimization Wizard](#interactive-optimization-wizard)
9. [Dependency Bloat Analysis](#dependency-bloat-analysis)
10. [Comprehensive Reporting](#comprehensive-reporting)
11. [CI/CD Integration](#cicd-integration)
12. [Complete Optimization Workflows](#complete-optimization-workflows)

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

## Build Configuration System

Save and reuse build configurations for reproducible builds across environments.

### Creating Build Configurations

```julia
using StaticCompiler

# Create a size-optimized configuration
config = BuildConfig(
    profile_name = "SIZE",
    custom_cflags = String[],
    cache_enabled = true,
    strip_binary = true,
    upx_compression = true,
    upx_level = :best,
    name = "my_app",
    version = "1.0.0",
    description = "Production build for deployment"
)
```

### Saving and Loading Configurations

```julia
# Save configuration to file
save_config(config, "production.jls")

# Load configuration
loaded_config = load_config("production.jls")

# Compile using saved configuration
exe = compile_with_config(my_func, (Int,), loaded_config, path="/tmp")
```

### Use Cases

**Team Collaboration:**
```julia
# Share build configs in your repo
config = create_default_config("SIZE")
save_config(config, ".build/production.jls")

# Team members can use the same settings
team_config = load_config(".build/production.jls")
exe = compile_with_config(my_func, (), team_config)
```

**Multiple Environments:**
```julia
# Development build
dev_config = BuildConfig(
    profile_name="DEBUG",
    strip_binary=false,
    upx_compression=false,
    name="myapp",
    version="dev",
    description="Development build with debug symbols"
)
save_config(dev_config, "configs/dev.jls")

# Production build
prod_config = BuildConfig(
    profile_name="AGGRESSIVE",
    strip_binary=true,
    upx_compression=true,
    upx_level=:best,
    name="myapp",
    version="1.0.0",
    description="Optimized production release"
)
save_config(prod_config, "configs/production.jls")
```

**CI/CD Integration:**
```julia
# In your CI pipeline
config = load_config("configs/\$(ENV["BUILD_TYPE"]).jls")
exe = compile_with_config(main_func, (), config, path="dist/")
```

### Benefits

✅ **Reproducible Builds** - Same settings every time
✅ **Version Control** - Commit configs to git
✅ **Easy Switching** - Toggle between dev/staging/prod
✅ **Documentation** - Settings are self-documenting
✅ **Team Alignment** - Everyone uses the same build settings

---

## SIMD Vectorization Analysis

Detect SIMD vectorization opportunities and optimize loop performance.

### Basic SIMD Analysis

```julia
using StaticCompiler

function process_array(arr::Vector{Float64})
    result = 0.0
    for i in 1:length(arr)
        result += arr[i]
    end
    return result
end

# Analyze SIMD usage
report = analyze_simd(process_array, (Vector{Float64},))

println("Vectorization Score: $(report.vectorization_score)/100")
println("SIMD Instructions: $(length(report.simd_instructions))")
println("Missed Opportunities: $(length(report.missed_opportunities))")
```

**Output:**
```
SIMD VECTORIZATION ANALYSIS
======================================================================

📊 VECTORIZATION SCORE: 0.0/100

⚠️  NO VECTORIZATION: No SIMD operations detected

🔍 MISSED OPPORTUNITIES:
  1. Loop detected without SIMD vectorization
  2. Scalar floating-point operations detected

💡 SUGGESTIONS:
  1. No SIMD vectorization detected. Consider using @simd or LoopVectorization.jl
  2. Ensure loops operate on contiguous arrays for auto-vectorization
  3. Use @inbounds to help the compiler vectorize

📝 EXAMPLE:
  # Add @simd to loops:
  function optimized_loop(arr)
      result = 0.0
      @simd for i in 1:length(arr)
          @inbounds result += arr[i]
      end
      return result
  end
======================================================================
```

### Optimizing with SIMD

```julia
# Improved version with SIMD annotations
function process_array_optimized(arr::Vector{Float64})
    result = 0.0
    @simd for i in 1:length(arr)
        @inbounds result += arr[i]
    end
    return result
end

report_optimized = analyze_simd(process_array_optimized, (Vector{Float64},))
# Vectorization Score: 80.0/100
# SIMD Instructions: 4-8 (depending on architecture)
```

### Understanding the Report

**Vectorization Score:**
- 0-20: No vectorization
- 20-50: Partial vectorization
- 50-80: Good vectorization
- 80-100: Excellent vectorization

**SIMD Instructions Detected:**
- Vector load (SIMD)
- Vector addition (SIMD)
- Vector multiplication (SIMD)
- Vector FMA (Fused Multiply-Add)

**Common Missed Opportunities:**
- Loops without @simd annotation
- Scalar operations in hot loops
- Non-contiguous memory access
- Type instabilities preventing vectorization

### Advanced Optimization

For maximum SIMD performance, consider LoopVectorization.jl:

```julia
using LoopVectorization

function super_fast(arr::Vector{Float64})
    result = 0.0
    @turbo for i in 1:length(arr)
        result += arr[i]
    end
    return result
end

# Analyze to verify vectorization
report = analyze_simd(super_fast, (Vector{Float64},))
# Vectorization Score: 100.0/100
```

---

## Security Analysis

Detect potential security vulnerabilities before compilation.

### Basic Security Analysis

```julia
using StaticCompiler

function unsafe_access(arr::Vector{Int}, idx::Int)
    return arr[idx]  # Unchecked access!
end

# Analyze security issues
report = analyze_security(unsafe_access, (Vector{Int}, Int))

println("Security Score: $(report.security_score)/100")
println("Issues Found: $(length(report.issues))")

for issue in report.issues
    println("  $(issue.severity): $(issue.category)")
    println("  $(issue.description)")
    println("  Fix: $(issue.recommendation)")
end
```

**Output:**
```
SECURITY ANALYSIS REPORT
======================================================================

🔒 SECURITY SCORE: 50.0/100

⚠️  SECURITY ISSUES FOUND: 1

ISSUE 1 [HIGH]:
  Category: unchecked_access
  Location: getindex
  Description: Unchecked array access detected
  Recommendation: Add bounds checking or use @boundscheck

======================================================================
```

### Security Issue Categories

**Buffer Overflow (Critical):**
```julia
# Dangerous: No bounds checking
function unsafe_write(arr::Vector{Int}, idx::Int, val::Int)
    arr[idx] = val  # Could write outside bounds!
end
```

**Integer Overflow (High):**
```julia
# Risk: Integer arithmetic can overflow
function multiply_ints(a::Int32, b::Int32)
    return a * b  # Could overflow!
end
```

**Unsafe Pointers (Critical):**
```julia
# Dangerous: Direct pointer manipulation
function unsafe_pointer_op(ptr::Ptr{Int})
    unsafe_store!(ptr, 42)  # No safety checks!
end
```

**Unchecked Access (High):**
```julia
# Risky: No bounds validation
function unchecked_read(arr::Vector{Int}, idx::Int)
    return arr[idx]
end
```

### Writing Secure Code

```julia
# ✅ Safe: Explicit bounds checking
function safe_access(arr::Vector{Int}, idx::Int)
    if idx >= 1 && idx <= length(arr)
        return arr[idx]
    end
    return 0
end

# ✅ Safe: Using @boundscheck
function bounds_checked(arr::Vector{Int})
    total = 0
    for i in 1:length(arr)
        @boundscheck checkbounds(arr, i)
        total += arr[i]
    end
    return total
end

# Verify security
report = analyze_security(safe_access, (Vector{Int}, Int))
# Security Score: 100.0/100
```

### Severity Levels

- **Critical:** Immediate security risk (buffer overflows, unsafe pointers)
- **High:** Likely to cause issues (unchecked access, integer overflow)
- **Medium:** Potential issues under edge cases
- **Low:** Best practice violations

### Best Practices

1. ✅ Always validate array indices
2. ✅ Use @boundscheck for explicit bounds checking
3. ✅ Be careful with integer arithmetic overflow
4. ✅ Avoid unsafe pointer operations in production
5. ✅ Use safe abstractions instead of manual memory management
6. ✅ Run security analysis before deployment

---

## Memory Layout Optimization

Optimize struct memory layouts to reduce size and improve cache efficiency.

### Basic Memory Layout Analysis

```julia
using StaticCompiler

struct MyStruct
    a::Int8      # 1 byte
    b::Int64     # 8 bytes
    c::Int8      # 1 byte
end

# Analyze memory layout
report = analyze_memory_layout(MyStruct)

println("Total Size: $(report.total_size) bytes")
println("Padding: $(report.padding_bytes) bytes")
println("Potential Savings: $(report.potential_savings) bytes")
println("Suggested Order: $(join(report.suggested_order, ", "))")
```

**Output:**
```
MEMORY LAYOUT ANALYSIS
======================================================================

Analyzing: MyStruct
Total Size: 24 bytes
Alignment: 8 bytes
Padding: 14 bytes (58.3% wasted!)

FIELD LAYOUT:
  a (Int8):    offset 0,  size 1  [7 bytes padding]
  b (Int64):   offset 8,  size 8  [0 bytes padding]
  c (Int8):    offset 16, size 1  [7 bytes padding]

⚠️  OPTIMIZATION OPPORTUNITY!
Potential savings: 8 bytes (33.3% reduction)

SUGGESTED FIELD ORDER:
  b, a, c

Reordering fields from largest to smallest can reduce padding.

📦 CACHE EFFICIENCY: 37.5%
Fields span 1 cache lines (64-byte lines)

======================================================================
```

### Optimizing the Layout

```julia
# Original: 24 bytes with 14 bytes padding
struct BadLayout
    a::Int8      # 1 byte + 7 bytes padding
    b::Int64     # 8 bytes
    c::Int8      # 1 byte + 7 bytes padding
end

# Optimized: 16 bytes with 6 bytes padding
struct GoodLayout
    b::Int64     # 8 bytes
    a::Int8      # 1 byte
    c::Int8      # 1 byte
    # Only 6 bytes padding at end
end

# Verify improvement
report1 = analyze_memory_layout(BadLayout, verbose=false)
report2 = analyze_memory_layout(GoodLayout, verbose=false)

println("Size reduction: $(report1.total_size) → $(report2.total_size) bytes")
# Size reduction: 24 → 16 bytes (33% smaller!)
```

### Automatic Optimization Suggestions

```julia
# Get optimized struct definition
suggestion = suggest_layout_optimization(MyStruct)
println(suggestion)
```

**Output:**
```
# Optimized layout suggestion for MyStruct
# Original size: 24 bytes → Optimized size: 16 bytes (33.3% savings)

struct MyStruct_Optimized
    b::Int64     # 8 bytes (offset: 0)
    a::Int8      # 1 bytes (offset: 8)
    c::Int8      # 1 bytes (offset: 9)
end
```

### Cache Efficiency

Understanding cache line usage:

```julia
struct CacheFriendly
    # All fields fit in one 64-byte cache line
    a::Int64
    b::Int64
    c::Int64
    d::Int64
    e::Int64
end

report = analyze_memory_layout(CacheFriendly, verbose=false)
println("Cache Efficiency: $(report.cache_efficiency)%")
# Cache Efficiency: 62.5% (40 bytes / 64-byte cache line)
```

**Cache Efficiency Score:**
- 80-100%: Excellent (minimal waste)
- 60-80%: Good
- 40-60%: Fair
- <40%: Poor (consider reorganizing)

### Complex Example

```julia
struct DatabaseRecord
    active::Bool         # 1 byte
    timestamp::Int64     # 8 bytes
    flag::Bool          # 1 byte
    user_id::Int64      # 8 bytes
    score::Float32      # 4 bytes
end

report = analyze_memory_layout(DatabaseRecord)
# Original: 40 bytes with 11 bytes padding

# Suggested optimization
struct DatabaseRecord_Optimized
    timestamp::Int64    # 8 bytes
    user_id::Int64     # 8 bytes
    score::Float32     # 4 bytes
    active::Bool       # 1 byte
    flag::Bool         # 1 byte
    # Padding: 2 bytes (95% improvement!)
end
```

### Memory Layout Best Practices

1. ✅ Order fields from largest to smallest
2. ✅ Group fields of similar sizes together
3. ✅ Keep frequently accessed fields in the same cache line
4. ✅ Use `analyze_memory_layout()` to verify layouts
5. ✅ Consider alignment requirements (8-byte for Int64/Float64)
6. ✅ Be aware of cache line boundaries (64 bytes)

### Impact on Performance

**Memory Savings:**
- Reduced struct size → less memory usage
- Better packing → more structs per page
- Fewer cache lines → better locality

**Performance Improvements:**
- Small structs: 10-30% faster iteration
- Large arrays: 20-50% better cache hit rates
- Database records: Significant memory savings

---

## Interactive Optimization Wizard

The Interactive Optimization Wizard guides users through selecting optimal compilation settings based on their requirements.

### Basic Usage

```julia
using StaticCompiler

function my_func(x::Int)
    return x * x + 2
end

# Interactive mode (asks questions)
config = optimization_wizard(my_func, (Int,))
exe = compile_with_wizard_config(my_func, (Int,), config)
```

The wizard will ask about:
- **Priority**: Size, speed, balanced, or compilation speed
- **Target Platform**: Desktop, embedded, mobile, or server
- **Deployment Stage**: Development, staging, or production
- **Size Budget**: Optional maximum binary size
- **UPX Compression**: Whether to compress
- **Symbol Stripping**: Whether to strip debug symbols
- **Advanced Options**: Custom compiler flags

### Quick Wizard (Non-Interactive)

For automated builds or CI/CD:

```julia
# Quick size optimization
exe = quick_wizard(my_func, (Int,), priority=:size, path="/tmp", name="myapp")

# Quick speed optimization
exe = quick_wizard(my_func, (Int,), priority=:speed, path="/tmp", name="myapp")

# Balanced optimization
exe = quick_wizard(my_func, (Int,), priority=:balanced, path="/tmp", name="myapp")
```

### Manual Configuration

Create custom wizard configurations programmatically:

```julia
config = WizardConfig(my_func, (Int,))
config.priority = :size
config.deployment = :production
config.requires_strip = true
config.requires_upx = true
config.size_budget_kb = 50  # Fail if > 50 KB

exe = compile_with_wizard_config(my_func, (Int,), config, path="/tmp", name="myapp")
```

### Size Budget Enforcement

Set a size budget to ensure binaries don't exceed limits:

```julia
config = WizardConfig(my_func, (Int,))
config.size_budget_kb = 100  # Warn if binary > 100 KB

exe = compile_with_wizard_config(my_func, (Int,), config)

# If binary exceeds budget, you'll get:
# ⚠️  Binary size 125.3 KB exceeds budget of 100 KB
# 💡 Suggestions to reduce size:
#    • Enable UPX compression
#    • Use PROFILE_SIZE instead
#    • Remove unused dependencies
```

### Benefits

✅ **Lower Barrier to Entry** - No need to understand all flags
✅ **Guided Decisions** - Wizard asks relevant questions
✅ **Optimal Settings** - Automatic profile selection
✅ **Educational** - Learn about optimization options
✅ **Reproducible** - Save wizard configs for reuse

### Wizard Workflow

1. **Analyzes** your function to identify issues
2. **Asks questions** about your priorities and constraints
3. **Recommends** an optimal optimization profile
4. **Warns** about potential problems (e.g., allocations)
5. **Compiles** with selected settings
6. **Validates** against size budgets if specified

### Use Cases

**Development:**
```julia
exe = quick_wizard(my_func, (), priority=:compilation_speed)
```

**Production Deployment:**
```julia
config = optimization_wizard(my_func, (), interactive=true)
# Wizard guides you through optimal production settings
exe = compile_with_wizard_config(my_func, (), config)
```

**Embedded Systems:**
```julia
config = WizardConfig(my_func, ())
config.priority = :size
config.target_platform = :embedded
config.size_budget_kb = 32  # Strict size limit
config.requires_upx = true
exe = compile_with_wizard_config(my_func, (), config)
```

---

## Dependency Bloat Analysis

Analyze function dependencies to identify bloat and minimize binary size.

### Basic Dependency Analysis

```julia
using StaticCompiler

function my_func(x::Int, y::Float64)
    return x + Int(floor(y))
end

report = analyze_dependency_bloat(my_func, (Int, Float64))
```

**Output:**
```
DEPENDENCY ANALYSIS
======================================================================

📊 BLOAT SCORE: 28.5/100
   (Lower is better)

📦 OVERVIEW:
   Total Functions: 23
   Unique Modules: 3

📚 MODULES DETECTED:
   1. Base (~245 instructions)
   2. Core (~89 instructions)
   3. Math (~124 instructions)

💡 OPTIMIZATION SUGGESTIONS:
   1. Consider using @nospecialize on arguments that don't need type specialization
   2. Avoid pulling in large stdlib modules for simple operations

✅ Code appears well-optimized with minimal dependencies
======================================================================
```

### Bloat Score Interpretation

- **0-30**: Excellent (lean code, minimal dependencies)
- **30-60**: Good (moderate dependencies, acceptable)
- **60-100**: Poor (significant bloat, needs optimization)

### Detecting Over-Specialization

Find functions with too many type specializations:

```julia
function generic_add(x, y)  # No type annotations
    return x + y
end

suggestions = suggest_nospecialize(generic_add, (Any, Any))
# Suggestions:
#   • Argument 1 has type Any - consider @nospecialize if not performance-critical
#   • Argument 2 has type Any - consider @nospecialize if not performance-critical
```

**Fix:**
```julia
function generic_add(@nospecialize(x), @nospecialize(y))
    return x + y
end

# Now generates fewer specializations
```

### Comparing Implementations

Compare dependency impact of different approaches:

```julia
# Implementation 1: Using stdlib
function impl1(x::Float64)
    return sin(x) + cos(x)
end

# Implementation 2: Custom approximation
function impl2(x::Float64)
    return custom_sin(x) + custom_cos(x)
end

comparison = compare_dependency_impact(impl1, (Float64,), impl2, (Float64,))
```

**Output:**
```
DEPENDENCY COMPARISON
======================================================================

📊 Implementation 1:
   Functions: 45
   Modules: 5
   Bloat Score: 48.5

📊 Implementation 2:
   Functions: 18
   Modules: 2
   Bloat Score: 22.0

📈 Difference:
   Functions: -27
   Modules: -3
   Bloat Score: -26.5

✅ Implementation 2 is significantly leaner
======================================================================
```

### Estimating Module Size Contribution

```julia
report = analyze_dependency_bloat(my_func, (Int,))

# Check size contribution of a specific module
base_size = estimate_dependency_size("Base", report)
println("Base contributes ~$base_size instructions")
```

### Optimization Strategies

**1. Use Concrete Types:**
```julia
# Bad: Abstract types pull in many specializations
function bad(x::Real)
    return x * 2
end

# Good: Concrete types
function good(x::Float64)
    return x * 2
end
```

**2. Add @nospecialize:**
```julia
# For generic algorithms that don't need specialization
function process(@nospecialize(data), threshold::Float64)
    # Generic processing that works on any type
    return filter(x -> x > threshold, data)
end
```

**3. Avoid Heavy Stdlib:**
```julia
# Instead of LinearAlgebra for simple operations
using LinearAlgebra
result = dot(a, b)  # Pulls in entire LinearAlgebra

# Use manual implementation
result = sum(a[i] * b[i] for i in 1:length(a))
```

**4. Use StaticTools Alternatives:**
```julia
# Instead of Base.println
using StaticTools
@print_and_throw "error message"

# Instead of regular Arrays
arr = MallocArray{Int}(10)  # Static allocation
```

### Best Practices

1. ✅ Run `analyze_dependency_bloat()` before optimizing
2. ✅ Compare bloat scores when refactoring
3. ✅ Use `@nospecialize` for generic arguments
4. ✅ Prefer concrete types over abstract types
5. ✅ Consider StaticTools.jl for stdlib alternatives
6. ✅ Profile before removing optimizations
7. ✅ Benchmark final binary to verify improvements

### Common Issues and Solutions

**High Bloat Score:**
- Add `@nospecialize` to generic functions
- Replace abstract types with concrete types
- Use simpler implementations for basic operations
- Avoid unnecessary stdlib imports

**Too Many Specializations:**
- Add `@nospecialize` annotation
- Use union types instead of separate methods
- Consider using Val{} for dispatch instead of types

**Large Module Contributions:**
- Implement custom versions of simple operations
- Use StaticTools.jl alternatives
- Avoid importing full modules for single functions

---

## Comprehensive Reporting

Generate unified reports combining all analysis tools with export capabilities.

### Basic Usage

```julia
using StaticCompiler

function my_func(x::Int)
    return x * x + 2
end

# Generate comprehensive report
report = generate_comprehensive_report(my_func, (Int,), compile=true)
```

**Output:**
```
COMPREHENSIVE COMPILATION REPORT
======================================================================

📋 SUMMARY
   Function: my_func
   Signature: (Int,)
   Generated: 2025-01-16 12:34:56

💾 BINARY
   Path: /tmp/my_func
   Size: 15.2 KB
   Compilation Time: 1234.5 ms

🎯 OVERALL SCORES
   Overall:     85.3/100
   Performance: 90.5/100
   Size:        78.0/100
   Security:    95.5/100
======================================================================
```

### Report Structure

The `ComprehensiveReport` struct contains:
- Timestamp and function metadata
- Binary path and size
- All analysis results (allocations, SIMD, security, etc.)
- Aggregated scores (overall, performance, size, security)
- Compilation metrics (time, cache status)

### Exporting Reports

Export to JSON for automated processing:

```julia
export_report_json(report, "report.json")
```

**Generated JSON structure:**
```json
{
  "timestamp": "2025-01-16T12:34:56",
  "function_name": "my_func",
  "scores": {
    "overall": 85.3,
    "performance": 90.5,
    "size": 78.0,
    "security": 95.5
  },
  "allocations": {
    "total": 0,
    "bytes": 0
  },
  "simd": {
    "score": 80.0,
    "vectorized": 4
  }
}
```

Export to Markdown for documentation:

```julia
export_report_markdown(report, "report.md")
```

**Generated Markdown:**
```markdown
# Compilation Report

**Function:** `my_func`
**Signature:** `(Int,)`

## Scores

| Metric | Score |
|--------|-------|
| Overall | 85.3/100 |
| Performance | 90.5/100 |
| Size | 78.0/100 |
| Security | 95.5/100 |
```

### Tracking Improvements

Compare reports to track optimization progress:

```julia
# Initial implementation
report1 = generate_comprehensive_report(version1, (Int,), compile=false)

# After optimization
report2 = generate_comprehensive_report(version2, (Int,), compile=false)

# Compare
compare_reports(report1, report2)
```

**Output:**
```
REPORT COMPARISON
======================================================================

📅 Timeline:
   Report 1: 2025-01-16 10:00:00
   Report 2: 2025-01-16 11:00:00

📊 Score Changes:
   ✓ Overall: 75.0 → 85.3 (↑ 10.3)
   ✓ Performance: 80.0 → 90.5 (↑ 10.5)
   ✓ Size: 70.0 → 78.0 (↑ 8.0)
   • Security: 95.5 → 95.5 (→ 0.0)

💾 Binary Size:
   ✓ Size (KB): 20.5 → 15.2 (↑ 5.3)
======================================================================
```

### Use Cases

**1. Continuous Monitoring:**
```julia
# Generate daily reports
report = generate_comprehensive_report(main, (), compile=true)
export_report_json(report, "reports/$(Dates.today()).json")
```

**2. Pre-Release Validation:**
```julia
report = generate_comprehensive_report(release_func, types, compile=true)

if report.security_score < 90.0
    error("Security score too low for release")
end

if report.binary_size_bytes > 100_000
    @warn "Binary size exceeds 100KB"
end
```

**3. Refactoring Verification:**
```julia
before = generate_comprehensive_report(old_impl, types, compile=false)
after = generate_comprehensive_report(new_impl, types, compile=false)

compare_reports(before, after)
```

---

## CI/CD Integration

Integrate StaticCompiler.jl into continuous integration pipelines.

### Basic CI Configuration

```julia
using StaticCompiler

function main()
    println("Hello from CI!")
    return 0
end

config = CIConfig(
    fail_on_allocations = false,
    fail_on_security_issues = true,
    max_binary_size_kb = 100,
    min_performance_score = 70.0,
    min_security_score = 80.0,
    generate_reports = true,
    report_formats = [:json, :markdown]
)

exit_code = ci_compile_and_test(main, (), "dist", "myapp", config=config)
exit(exit_code)
```

### Configuration Options

**CIConfig Parameters:**

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `fail_on_allocations` | Bool | Fail if allocations detected | `false` |
| `fail_on_security_issues` | Bool | Fail on critical security issues | `true` |
| `max_binary_size_kb` | Int? | Maximum binary size in KB | `nothing` |
| `min_performance_score` | Float64 | Minimum performance score (0-100) | `50.0` |
| `min_security_score` | Float64 | Minimum security score (0-100) | `80.0` |
| `generate_reports` | Bool | Generate reports | `true` |
| `report_formats` | Vector{Symbol} | Report formats (:json, :markdown) | `[:json, :markdown]` |
| `cache_enabled` | Bool | Enable compilation cache | `true` |

### GitHub Actions Integration

Complete workflow example:

```yaml
name: Static Compilation CI

on: [push, pull_request]

jobs:
  compile:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - uses: julia-actions/setup-julia@v1
        with:
          version: '1.10'

      - name: Install dependencies
        run: |
          julia --project -e 'using Pkg; Pkg.instantiate()'

      - name: Compile and test
        run: |
          julia --project ci/compile.jl

      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: compilation-reports
          path: dist/reports/

      - name: Check compilation status
        if: failure()
        run: echo "Compilation checks failed"
```

**ci/compile.jl:**
```julia
using StaticCompiler

function main()
    return 0
end

config = CIConfig(
    fail_on_security_issues = true,
    max_binary_size_kb = 100,
    min_performance_score = 70.0
)

exit_code = ci_compile_and_test(main, (), "dist", "app", config=config)
exit(exit_code)
```

### GitHub Actions Step Summary

Automatically add reports to GitHub Actions step summary:

```julia
report = generate_comprehensive_report(main, (), compile=true)

# This writes to $GITHUB_STEP_SUMMARY if running in GitHub Actions
write_github_actions_summary(report)
```

Shows in GitHub Actions UI:

```markdown
## StaticCompiler.jl Compilation Report

| Metric | Score | Status |
|--------|-------|--------|
| Overall | 85.3/100 | ✅ |
| Performance | 90.5/100 | ✅ |
| Size | 78.0/100 | ⚠️ |
| Security | 95.5/100 | ✅ |
```

### GitLab CI Integration

**.gitlab-ci.yml:**
```yaml
stages:
  - build
  - test

compile:
  stage: build
  image: julia:1.10
  script:
    - julia --project -e 'using Pkg; Pkg.instantiate()'
    - julia --project ci/compile.jl
  artifacts:
    paths:
      - dist/
    reports:
      junit: dist/reports/*.xml
```

### CI Environment Detection

Automatically detect CI environment:

```julia
ci_info = detect_ci_environment()

if ci_info.detected
    println("Running in $(ci_info.system)")
    # Adjust configuration for CI
else
    println("Running locally")
end
```

Supports detection of:
- GitHub Actions
- GitLab CI
- Travis CI
- Circle CI
- Jenkins
- Buildkite

### Badge Generation

Generate badge data for shields.io:

```julia
report = generate_comprehensive_report(my_func, types)
status, color, score = generate_ci_badge(report)

# Use in shields.io URL:
# https://img.shields.io/badge/compilation-{status}-{color}
# Example: https://img.shields.io/badge/compilation-excellent-brightgreen
```

**Badge Mapping:**

| Score Range | Status | Color |
|-------------|--------|-------|
| 90-100 | excellent | brightgreen |
| 75-89 | good | green |
| 60-74 | fair | yellow |
| 0-59 | poor | red |

### Automated Failure Criteria

The CI system automatically fails when:

1. **Allocations** (if `fail_on_allocations = true`):
   - Any heap allocations detected

2. **Security Issues** (if `fail_on_security_issues = true`):
   - Any critical security issues found
   - Buffer overflows, unsafe pointer operations

3. **Binary Size** (if `max_binary_size_kb` set):
   - Binary exceeds specified size limit

4. **Performance Score** (if `min_performance_score` set):
   - Performance score below minimum

5. **Security Score** (if `min_security_score` set):
   - Security score below minimum

### Multi-Environment Configuration

Different configs for different environments:

```julia
# Development
dev_config = CIConfig(
    fail_on_allocations = false,
    min_performance_score = 50.0,
    generate_reports = false
)

# Staging
staging_config = CIConfig(
    fail_on_security_issues = true,
    min_performance_score = 70.0,
    generate_reports = true
)

# Production
prod_config = CIConfig(
    fail_on_allocations = true,
    fail_on_security_issues = true,
    max_binary_size_kb = 50,
    min_performance_score = 80.0,
    min_security_score = 90.0,
    generate_reports = true
)

# Select based on environment
env = get(ENV, "ENVIRONMENT", "development")
config = if env == "production"
    prod_config
elseif env == "staging"
    staging_config
else
    dev_config
end

exit_code = ci_compile_and_test(main, (), "dist", "app", config=config)
```

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

✅ **Build Configuration System**
- Save and load build configurations
- Reproducible builds across environments
- Version control friendly
- CI/CD integration

✅ **SIMD Vectorization Analysis**
- Detect vectorization opportunities
- Identify missed optimizations
- Performance scoring (0-100)
- Actionable suggestions with code examples

✅ **Security Analysis**
- Detect buffer overflows and unsafe pointers
- Identify unchecked array accesses
- Find integer overflow risks
- Security scoring (0-100)
- Severity levels (critical, high, medium, low)

✅ **Memory Layout Optimization**
- Analyze struct padding and alignment
- Suggest optimal field ordering
- Cache efficiency analysis
- Automated optimization suggestions
- 10-50% memory savings possible

✅ **Interactive Optimization Wizard**
- Guided optimization decision-making
- Automatic profile selection based on priorities
- Size budget enforcement
- Support for interactive and non-interactive modes
- Platform-specific recommendations

✅ **Dependency Bloat Analysis**
- Identify module size contributions
- Detect over-specialized functions
- Compare implementation approaches
- Bloat scoring (0-100, lower is better)
- @nospecialize suggestions

✅ **Complete Workflows**
- Size optimization
- Performance optimization
- Balanced optimization
- Debug builds

Use these tools to create optimal, secure, and performant static binaries for any use case!
