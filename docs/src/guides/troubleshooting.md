# Troubleshooting Guide

## Frequently Asked Questions

### When should I use StaticCompiler vs PackageCompiler?

**Use StaticCompiler when:**
- You need small standalone binaries
- Targeting embedded systems or WebAssembly
- Creating C-compatible libraries
- Fast startup time is critical
- You can write type-stable, allocation-free code

**Use PackageCompiler when:**
- You want to compile existing Julia packages
- Your code uses dynamic features
- You need the full Julia runtime
- Binary size is not a concern

### What Julia version should I use?

StaticCompiler supports Julia 1.8 through 1.11. We recommend using the latest stable release (1.10 or 1.11) for best results.

### Why does my code work in Julia but not with StaticCompiler?

StaticCompiler has fundamental restrictions:
- No GC-tracked allocations (Array, String, Dict)
- Type-stable code only
- Limited error handling
- No runtime type information
- No dynamic dispatch on abstract types

Your code must be rewritten to work within these constraints.

## Common Issues

### Compilation is slow

**Symptoms:** `compile_executable` or `compile_shlib` takes a long time

**Solutions:**
1. Caching is enabled by default. Subsequent compilations of the same function should be faster
2. Clear old cache with `clear_cache!()` if you suspect corruption
3. Type instabilities cause slow inference - fix with `@code_warntype`
4. Large functions take longer - consider splitting into smaller pieces

### Binary size is too large

**Solutions:**
1. Use `strip_binary=true` to remove debug symbols
2. Minimize dependencies in your code
3. Avoid pulling in large libraries
4. Use smaller numeric types where appropriate (Float32 vs Float64)

### Compilation fails on Windows

**Symptoms:** Errors about missing LLVM or clang

**Solutions:**
1. Install LLVM 17 or newer: `choco install llvm`
2. Ensure clang is in PATH: `where clang` should work
3. Windows support uses LLVM IR to Clang pipeline (`llvm_to_clang=true`)
4. Check that LLD linker is available

### Cannot use String or Array

**Question:** How do I work with strings and arrays?

**Answer:** Use StaticTools alternatives:
```julia
using StaticTools

# Instead of String, use StaticString or MallocString
msg = c"Hello, world!"  # StaticString
msg = malloc(100)       # MallocString

# Instead of Array, use MallocArray or StrideArray
arr = MallocArray{Float64}(undef, 100)
# ... use arr ...
free(arr)

# Or use stack-allocated StaticArrays for small fixed sizes
using StaticArrays
arr = @SVector [1.0, 2.0, 3.0]
```

### Error handling doesn't work

**Question:** My error() calls fail to compile

**Answer:** Error handling requires runtime. Use `@device_override`:
```julia
using StaticCompiler

# Override the error function
@device_override @noinline Base.error(msg) = @print_and_throw c"Error occurred"

# Or handle errors manually
function safe_divide(a, b)
    if b == 0
        return NaN
    end
    return a / b
end
```

Common error overrides are already provided in `src/quirks.jl`.

### How do I debug type instabilities?

**Answer:**
1. Use `@code_warntype my_function(args...)`
2. Look for red-highlighted types or `Union` types
3. Use `check_compilable` for automatic detection
4. Add type annotations to variables and return types
5. Use Cthulhu.jl for interactive exploration

### Can I use external libraries?

**Question:** Can I call C libraries or use ccall?

**Answer:** Yes, with caveats:
- `ccall` to C libraries works fine
- Use `@symbolcall` from StaticTools for cleaner syntax
- Cannot use Julia packages that allocate or require runtime
- Libraries must be linked at compile time with `cflags`

Example:
```julia
using StaticTools

function call_c_sqrt(x::Float64)
    @symbolcall sqrt(x::Float64)::Float64
end
```

### Cross-compilation doesn't work

**Question:** How do I compile for a different platform?

**Answer:**
```julia
using StaticCompiler

# Define target
target = StaticTarget(
    Platform("aarch64-linux-gnu"),
    "generic",
    ""
)

# Set cross compiler
set_compiler!(target, "/path/to/aarch64-linux-gnu-gcc")

# Compile
compile_executable(my_function, (), "./output", target=target)
```

Note: You need the appropriate cross-compilation toolchain installed.

### Performance is worse than Julia

**Question:** My statically compiled code is slower than JIT Julia

**Answer:** This can happen because:
1. Julia's JIT can specialize more aggressively
2. Missing optimization flags - try `cflags=-O3`
3. Type instabilities prevent optimization
4. Missing SIMD vectorization - consider LoopVectorization.jl
5. Stack vs heap allocation trade-offs

StaticCompiler is optimized for startup time and binary size, not peak performance.

### Can I use global variables?

**Answer:** Only constant globals:
```julia
# OK: const global
const CONFIG = (n=100, tol=1e-6)

function use_config()
    return CONFIG.n
end

# Not OK: mutable global
COUNTER = 0

function increment()
    global COUNTER += 1  # Will fail
end

# Instead: pass as argument
function increment(counter::Int)
    return counter + 1
end
```

## Platform-Specific Issues

### macOS

- Use native `cc` compiler instead of clang by default
- Custom entry points work differently (uses `-e` flag)
- Strip command may behave differently on M1/M2 machines

### Linux

- Most reliable platform for StaticCompiler
- Check that `strip` utility is available for size optimization
- Cross-compilation works best from Linux hosts

### Windows

- Requires LLVM 17 or newer
- Uses LLVM IR to Clang compilation path
- Strip not supported
- Integration tests may have issues

## Getting More Help

1. Check the [debugging tutorial](../tutorials/debugging.md)
2. Search existing [GitHub issues](https://github.com/tshort/StaticCompiler.jl/issues)
3. Read [StaticTools.jl documentation](https://github.com/brenhinkeller/StaticTools.jl)
4. Ask on [Julia Discourse](https://discourse.julialang.org) with tag `staticcompiler`
5. Create a new issue with minimal reproducible example
