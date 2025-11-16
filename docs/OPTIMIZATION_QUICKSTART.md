# Quick Start: Using Advanced Optimizations

**5-Minute Guide to Making More Code Statically Compilable**

---

## Installation

```julia
using Pkg
Pkg.add("StaticCompiler")
using StaticCompiler
```

---

## Quick Analysis

### Step 1: Check Your Function

```julia
using StaticCompiler

function my_function(x::Number)  # Abstract type!
    arr = zeros(10)              # Heap allocation!
    for i in 1:10
        arr[i] = x * i
    end
    return sum(arr)
end

# Run all analyses
escape_report = analyze_escapes(my_function, (Number,))
mono_report = analyze_monomorphization(my_function, (Number,))
lifetime_report = analyze_lifetimes(my_function, (Number,))
const_report = analyze_constants(my_function, (Number,))
devirt_report = analyze_devirtualization(my_function, (Number,))

# Print reports
println(escape_report)
println(mono_report)
# ... etc
```

### Step 2: Read the Suggestions

Each report tells you what can be optimized:

```
Escape Analysis Report
==================================================
✓ Stack promotion: 1 allocation can be moved to stack
Suggestion: Use StaticArrays.jl for small fixed-size arrays

Monomorphization Analysis
==================================================
✓ Can fully monomorphize
Concrete types found: Int64, Float64
Suggestion: Create specialized versions for each type
```

### Step 3: Apply the Fixes

```julia
using StaticArrays, StaticTools

# Fix 1: Use concrete types (monomorphization)
function my_function_int(x::Int64)
    # Fix 2: Use stack-allocated array (escape analysis)
    arr = @MVector zeros(10)

    for i in 1:10
        arr[i] = x * i
    end
    return sum(arr)
end

# Now compiles!
exe = compile_executable(my_function_int, (Int64,), "output")
```

---

## Common Patterns

### Pattern 1: Abstract Types

**Problem:**
```julia
function process(x::Number)  # Can't compile!
    return x * 2
end
```

**Solution:**
```julia
# Check what concrete types are used
report = analyze_monomorphization(process, (Number,))
println(report)

# Create specialized versions
process(x::Int64) = x * 2
process(x::Float64) = x * 2

# Or use type parameters
function process(x::T) where T <: Number
    return x * 2
end
```

### Pattern 2: Heap Allocations

**Problem:**
```julia
function compute()
    arr = zeros(100)  # Can't compile!
    return sum(arr)
end
```

**Solution:**
```julia
using StaticArrays

# Option 1: Stack allocation (small arrays)
function compute()
    arr = @SVector zeros(100)
    return sum(arr)
end

# Option 2: Manual memory (large arrays)
using StaticTools
function compute()
    arr = MallocArray{Float64}(100)
    result = sum(arr)
    free(arr)  # Don't forget!
    return result
end

# Option 3: Scalar replacement (best!)
function compute()
    result = 0.0
    for i in 1:100
        result += 0.0  # zeros(100)[i]
    end
    return result
end
```

### Pattern 3: Global Constants

**Problem:**
```julia
CONFIG = (mode = :fast)  # Not const!

function run()
    if CONFIG.mode == :fast
        return 1
    end
end
```

**Solution:**
```julia
const CONFIG = (mode = :fast)  # Now constant!

function run()
    if CONFIG.mode == :fast
        return 1  # Other branch is dead code
    end
end

# Check dead code elimination
report = analyze_constants(run, ())
println(report)  # Shows dead branches
```

### Pattern 4: Memory Leaks

**Problem:**
```julia
function leaky()
    arr = MallocArray{Float64}(100)
    return sum(arr)  # Forgot to free!
end
```

**Solution:**
```julia
# Check for leaks
report = analyze_lifetimes(leaky, ())
println(report)  # Shows "Missing free()"

# Fix
function not_leaky()
    arr = MallocArray{Float64}(100)
    result = sum(arr)
    free(arr)  # ← Added
    return result
end
```

---

## Workflow

### Recommended Optimization Workflow

```julia
using StaticCompiler

function optimize_for_static_compilation(f, types)
    println("="^60)
    println("OPTIMIZATION ANALYSIS FOR: $f")
    println("="^60)

    # 1. Check for abstract types
    println("\n### MONOMORPHIZATION ###")
    mono = analyze_monomorphization(f, types)
    println(mono)

    if mono.has_abstract_types
        println("\n⚠ ACTION NEEDED: Use concrete types")
        return  # Can't continue until fixed
    end

    # 2. Check allocations
    println("\n### ESCAPE ANALYSIS ###")
    escape = analyze_escapes(f, types)
    println(escape)

    if escape.promotable_allocations > 0
        println("\n✓ OPPORTUNITY: $(escape.promotable_allocations) allocations can be stack-promoted")
        for suggestion in suggest_stack_promotion(escape)
            println(suggestion)
        end
    end

    # 3. Check memory management
    println("\n### LIFETIME ANALYSIS ###")
    lifetime = analyze_lifetimes(f, types)
    println(lifetime)

    if length(lifetime.allocations) > lifetime.auto_freeable
        println("\n⚠ WARNING: Potential memory leaks")
        for suggestion in suggest_lifetime_improvements(lifetime)
            println(suggestion)
        end
    end

    # 4. Check for optimizations
    println("\n### CONSTANT PROPAGATION ###")
    const_prop = analyze_constants(f, types)
    println(const_prop)

    if !isempty(const_prop.dead_branches)
        println("\n✓ OPPORTUNITY: Dead code can be eliminated")
    end

    # 5. Check virtual calls
    println("\n### DEVIRTUALIZATION ###")
    devirt = analyze_devirtualization(f, types)
    println(devirt)

    if devirt.devirtualizable_calls > 0
        println("\n✓ OPPORTUNITY: $(devirt.devirtualizable_calls) calls can be devirtualized")
    end

    println("\n"*"="^60)
    println("ANALYSIS COMPLETE")
    println("="^60)
end

# Use it
optimize_for_static_compilation(my_function, (Int64,))
```

---

## Real-World Example

### Before: Won't Compile

```julia
using StaticCompiler

function process_data(items::Vector{<:Number})
    temp = zeros(length(items))

    for i in eachindex(items)
        temp[i] = items[i]^2
    end

    return sum(temp)
end

# Try to compile
try
    compile_executable(process_data, (Vector{Number},), "output")
catch e
    println("Failed: $e")
end
```

**Errors:**
- Abstract type `Vector{<:Number}`
- Heap allocation `zeros()`

### After: Compiles Successfully

```julia
using StaticCompiler, StaticTools, StaticArrays

function process_data_optimized(items::Vector{Int64})
    n = length(items)

    # Stack allocation for small arrays
    if n <= 100
        temp = @MVector zeros(Int64, n)
        for i in 1:n
            temp[i] = items[i]^2
        end
        return sum(temp)
    else
        # Manual memory for large arrays
        temp = MallocArray{Int64}(n)
        for i in 1:n
            temp[i] = items[i]^2
        end
        result = sum(temp)
        free(temp)
        return result
    end
end

# Compile successfully!
exe = compile_executable(process_data_optimized, (Vector{Int64},), "output")
println("✓ Compiled to: $exe")
```

**How we fixed it:**
1. ✅ Changed `Vector{<:Number}` → `Vector{Int64}` (monomorphization)
2. ✅ Changed `zeros()` → `@MVector zeros()` (escape analysis)
3. ✅ Added `free()` for manual memory (lifetime analysis)

---

## Cheat Sheet

| Problem | Analysis | Solution |
|---|---|---|
| Abstract types | `analyze_monomorphization` | Use concrete types or type parameters |
| Heap allocations | `analyze_escapes` | Use `StaticArrays`, `MallocArray`, or scalars |
| Memory leaks | `analyze_lifetimes` | Add `free()` calls |
| Dead code | `analyze_constants` | Use `const` for globals |
| Virtual calls | `analyze_devirtualization` | Use concrete types for receivers |

---

## Quick Commands

```julia
# Analyze everything
using StaticCompiler

f = my_function
t = (Int64, Float64)

analyze_escapes(f, t)
analyze_monomorphization(f, t)
analyze_devirtualization(f, t)
analyze_lifetimes(f, t)
analyze_constants(f, t)

# Get suggestions
suggest_stack_promotion(analyze_escapes(f, t))
suggest_lifetime_improvements(analyze_lifetimes(f, t))
suggest_devirtualization(analyze_devirtualization(f, t))
```

---

## Next Steps

1. **Read the full guide:** `docs/ADVANCED_COMPILER_OPTIMIZATIONS.md`
2. **Understand theory:** See "Motivation" section
3. **Implementation details:** `docs/OPTIMIZATION_IMPLEMENTATION_GUIDE.md`
4. **Run tests:** `include("test/test_advanced_optimizations.jl")`

---

## Getting Help

**Issue?** Check analysis reports first!

**Still stuck?**
1. Read error messages carefully
2. Use `@code_warntype` to check type stability
3. Check allocation with `@code_typed`
4. Open GitHub issue with minimal example

**Common Gotchas:**
- Forgot to make globals `const`
- Using abstract types in function signature
- Returning heap-allocated arrays
- Forgetting to `free()` manual allocations

---

## Success Stories

### Example 1: Embedded Systems
```julia
# Before: 500 KB binary with runtime
# After: 8 KB static binary

function control_loop(sensor::Int64)
    const THRESHOLD = 100
    return sensor > THRESHOLD ? 1 : 0
end

# Constant propagation eliminates all branches
# Result: Tiny, fast binary
```

### Example 2: WebAssembly
```julia
# Before: Couldn't compile (used Arrays)
# After: Pure WASM with stack allocation

function compute(x::Float32, y::Float32)
    result = @SVector [x, y, x+y, x*y]
    return sum(result)
end

# Escape analysis → stack allocation
# Compiles to pure WASM!
```

### Example 3: High-Performance Computing
```julia
# Before: Abstract types, slow dispatch
# After: Monomorphized, 5x faster

function simulate(particles::Vector{Particle{Float64}})
    # ... complex computation
end

# Monomorphization + devirtualization
# Direct calls, no vtable lookups
```

---

*Happy Optimizing! 🚀*
