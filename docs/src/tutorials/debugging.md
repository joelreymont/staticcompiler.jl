# Debugging Failed Compilations

This guide helps you diagnose and fix compilation failures when using StaticCompiler.jl.

## Quick Diagnostic Tools

### Check Compilability First

Before attempting full compilation, use the compilability checker:

```julia
using StaticCompiler

report = check_compilable(my_function, (Int, Float64))
```

This will identify common issues:
- Type instabilities
- GC allocations
- Runtime calls
- Inference failures

### Inspect Type Inference

Use `static_code_typed` to see what the compiler infers:

```julia
static_code_typed(my_function, (Int, Float64))
```

Look for:
- Non-concrete return types (Union, Any)
- Type parameters that aren't resolved
- Unexpected type widening

### Inspect LLVM IR

View the generated LLVM code:

```julia
static_code_llvm(my_function, (Int, Float64))
```

Search for problematic patterns:
- `jl_alloc_*` - GC allocations
- `jl_throw` - Error handling
- `jl_*` - Other runtime calls

## Common Error Patterns

### Type Instability

**Symptom:** "did not infer to a concrete type"

**Example:**
```julia
# Bad: returns different types
function unstable(x)
    if x > 0
        return 1
    else
        return "negative"
    end
end
```

**Fix:** Ensure all code paths return the same concrete type:
```julia
# Good: always returns Int
function stable(x)
    if x > 0
        return 1
    else
        return -1
    end
end
```

**Diagnosis:**
```julia
using InteractiveUtils
@code_warntype unstable(1)  # Shows Union{Int, String}
```

### GC Allocations

**Symptom:** References to `jl_alloc` in error messages or LLVM IR

**Example:**
```julia
# Bad: allocates Array
function with_array(n)
    arr = zeros(n)
    sum(arr)
end
```

**Fix:** Use stack-allocated or manually managed memory:
```julia
using StaticTools

# Good: uses MallocArray
function with_malloc(n)
    arr = MallocArray{Float64}(undef, n)
    for i in 1:n
        arr[i] = 0.0
    end
    result = sum(arr)
    free(arr)
    return result
end
```

### Runtime Calls

**Symptom:** References to `jl_` functions in LLVM IR

**Example:**
```julia
# Bad: throws error (requires runtime)
function with_error(x)
    if x < 0
        error("negative value")
    end
    return sqrt(x)
end
```

**Fix:** Add device override:
```julia
@device_override @noinline Base.error(msg) = @print_and_throw c"Error occurred"

# Or handle errors manually
function no_error(x)
    if x < 0
        return NaN
    end
    return sqrt(x)
end
```

### Global Variables

**Symptom:** Compilation fails with references to global state

**Example:**
```julia
# Bad: mutable global
COUNTER = 0

function increment()
    global COUNTER += 1
    return COUNTER
end
```

**Fix:** Pass state through arguments:
```julia
# Good: state as argument
function increment(counter::Int)
    return counter + 1
end
```

Const globals are acceptable:
```julia
const CONFIG = (max_iter=1000, tol=1e-6)

function use_config()
    return CONFIG.max_iter
end
```

## Debugging Workflow

1. **Start simple:** Test with minimal examples first
2. **Check compilability:** Use `check_compilable` to get early warnings
3. **Inspect inference:** Use `@code_warntype` to find type issues
4. **View LLVM:** Use `static_code_llvm` to find runtime calls
5. **Iterative fixes:** Fix issues one at a time and retest

## Using Cthulhu for Deep Inspection

[Cthulhu.jl](https://github.com/JuliaDebug/Cthulhu.jl) provides interactive type inference exploration:

```julia
using Cthulhu
@descend my_function(1, 2.0)
```

Navigate through function calls to find:
- Where type instabilities originate
- Which calls allocate
- What methods are being called

## Getting Help

If you're stuck:

1. Simplify your function to the minimal failing example
2. Check that it works with regular Julia first
3. Use `check_compilable` to get diagnostic information
4. Create an issue at https://github.com/tshort/StaticCompiler.jl/issues with:
   - Minimal reproducible example
   - Output of `check_compilable`
   - Julia version and StaticCompiler version
