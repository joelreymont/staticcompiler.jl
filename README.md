# StaticCompiler

[![CI](https://github.com/tshort/StaticCompiler.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/tshort/StaticCompiler.jl/actions/workflows/ci.yml)
[![CI (Integration)](https://github.com/tshort/StaticCompiler.jl/actions/workflows/ci-integration.yml/badge.svg)](https://github.com/tshort/StaticCompiler.jl/actions/workflows/ci-integration.yml)
[![CI (Julia nightly)](https://github.com/tshort/StaticCompiler.jl/workflows/CI%20(Julia%20nightly)/badge.svg)](https://github.com/tshort/StaticCompiler.jl/actions/workflows/ci-julia-nightly.yml)
[![CI (Integration nightly)](https://github.com/tshort/StaticCompiler.jl/actions/workflows/ci-integration-nightly.yml/badge.svg)](https://github.com/tshort/StaticCompiler.jl/actions/workflows/ci-integration-nightly.yml)
[![Coverage](https://codecov.io/gh/tshort/StaticCompiler.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tshort/StaticCompiler.jl)

This is an experimental package to compile Julia code to standalone libraries. A system image is not needed.

## Installation and Usage
Installation is the same as any other registered Julia package
```julia
using Pkg
Pkg.add("StaticCompiler")
```

### Standalone compilation
StaticCompiler.jl provides the functions `compile_executable` and `compile_shlib` for compiling a Julia function to a native executable or shared library for use from outside of Julia:
```julia
julia> using StaticCompiler, StaticTools

julia> hello() = println(c"Hello, world!")
hello (generic function with 1 method)

julia> compile_executable(hello, (), "./")
"/Users/user/hello"

shell> ls -alh hello
-rwxrwxr-x. 1 user user 8.4K Oct 20 20:36 hello

shell> ./hello
Hello, world!
```
This approach comes with substantial limitations compared to regular julia code, as you cannot rely on julia's runtime, `libjulia` (see, e.g., [StaticTools.jl](https://github.com/brenhinkeller/StaticTools.jl) for some ways to work around these limitations).

The low-level function `StaticCompiler.generate_obj` (not exported) generates object files. This can be used for more control of compilation. This can be used for example, to cross-compile to other targets.

### Method overlays

Sometimes, a julia function you want to statically compile will do things (such as throwing errors) that aren't supported natively by StaticCompiler. One tool provided for working around this is the `@device_override` macro which lets you swap out a method, but only inside of a StaticCompiler.jl compilation context. For example:

```julia
julia> using Libdl, StaticCompiler

julia> f(x) = g(x) + 1;

julia> g(x) = 2x

julia> @device_override g(x::Int) = x - 10

julia> f(1) # Gives the expected answer in regular julia
3

julia> dlopen(compile_shlib(f, (Int,), "./")) do lib
           fptr = dlsym(lib, "f")
           # Now use the compiled version where g(x) = 2x is replaced with g(x) = x - 10
           @ccall $fptr(1::Int)::Int 
       end
-8
```
Typically, errors should be overrided and replaced with `@print_and_throw`, which is StaticCompiler friendly, i.e.
we define overrides such as
``` julia
@device_override @noinline Base.Math.throw_complex_domainerror(f::Symbol, x) =
    @print_and_throw c"This operation requires a complex input to return a complex result"
```

If for some reason, you wish to use a different method table (defined with `Base.Experimental.@MethodTable` and `Base.Experimental.@overlay`) than the default one provided by StaticCompiler.jl, you can provide it to `compile_executable` and `compile_shlib` via a keyword argument `method_table`.


## Approach

This package uses the [GPUCompiler package](https://github.com/JuliaGPU/GPUCompiler.jl) to generate code.

## Limitations

* GC-tracked allocations and global variables do *not* work with `compile_executable` or `compile_shlib`. This has some interesting consequences, including that all functions _within_ the function you want to compile must either be inlined or return only native types (otherwise Julia would have to allocate a place to put the results, which will fail).
* Since error handling relies on libjulia, you can only throw errors from standalone-compiled (`compile_executable` / `compile_shlib`) code if an explicit overload has been defined for that particular error with `@device_override` (see [quirks.jl](src/quirks.jl)).
* Type instability. Type unstable code cannot currently be statically compiled via this package.
* Extra experimental on Windows (PRs welcome if you encounter issues). Should work in WSL on Windows 10+. 

## Guide for Package Authors

To enable code to be statically compiled, consider the following:

* Use type-stable code.

* Use Tuples, NamedTuples, StaticArrays, and other types where appropriate. These allocate on the stack and don't use Julia's heap allocation.

* Avoid Julia's internal allocations. That means don't bake in use of Arrays or Strings or Dicts. Types from StaticTools can help, like StaticStrings and MallocArrays.

* If need be, manage memory manually, using `malloc` and `free` from StaticTools.jl. This works with `StaticTools.MallocString` and `StaticTools.MallocArray`, or use [Bumper.jl](https://github.com/MasonProtter/Bumper.jl). 

* Don't use global variables that need to be allocated and initialized. Instead of global variables, use context structures that have an initialization function. It is okay to use global Tuples or NamedTuples as the use of these should be baked into compiled code.

* Use context variables to store program state, inputs, and outputs. Parameterize these typese as needed, so your code can handle normal types (Arrays) and static-friendly types (StaticArrays, MallocArrays, or StrideArrays). The SciML ecosystem does this well ([example](https://github.com/SciML/OrdinaryDiffEq.jl/blob/e7f045950615352ddfcb126d13d92afd2bad05e4/src/integrators/type.jl#L82)). Use of these context variables also enables allocations and initialization to be centralized, so these could be managed by the calling routines in Julia, Python, JavaScript, or other language.

* Arguments and returned values from `compile_shlib` must be native objects such as `Int`, `Float64`, or `Ptr`. They cannot be things like `Tuple{Int, Int}` because that is not natively sized. Such objects need to be passed by reference instead of by value.

* If your code needs an array as a workspace, instead of directly creating it, create it as a function argument (where it could default to a standard array creation). That code could be statically compiled if that function argument is changed to a MallocArray or another static-friendly alternative. 

## Guide for Statically Compiling Code

If you're trying to statically compile generic code, you may run into issues if that code uses features not supported by StaticCompiler. One option is to change the code you're calling using the tips above. If that is not easy, you may by able to compile it anyway. One option is to use method overlays to change what methods are called.

[Cthulhu](https://github.com/JuliaDebug/Cthulhu.jl) is a great help in digging into code, finding type instabilities, and finding other sources of code that may break static compilation.

## Advanced Features

StaticCompiler.jl now includes a comprehensive optimization and analysis framework for producing highly-optimized binaries.

### Smart Optimization

Automatically analyze your function and select the best compilation strategy:

```julia
using StaticCompiler

function compute(n::Int)
    result = 0
    for i in 1:n
        result += i * i
    end
    return result
end

# Automatic optimization - analyzes and selects best preset
result = smart_optimize(compute, (Int,), "dist", "compute", args=(1000,))

# One-line quick compile
binary = quick_compile(compute, (Int,), "compute", args=(1000,))
```

### Optimization Presets

Choose from predefined optimization presets for common use cases:

```julia
# Size-optimized for embedded systems
compile_with_preset(func, types, "dist", "app", :embedded, args=args)

# Fast startup for serverless functions
compile_with_preset(func, types, "dist", "app", :serverless, args=args)

# Maximum performance for HPC workloads
compile_with_preset(func, types, "dist", "app", :hpc, args=args)

# Balanced for desktop applications
compile_with_preset(func, types, "dist", "app", :desktop, args=args)

# Production-ready with all optimizations
compile_with_preset(func, types, "dist", "app", :release, args=args)

# Fast compilation for development
compile_with_preset(func, types, "dist", "app", :development, args=args)
```

### Profile-Guided Optimization (PGO)

Iteratively optimize based on runtime profiling:

```julia
# Run PGO with automatic profile selection
result = pgo_compile(
    my_func, (Int,), (1000,),
    "dist", "my_app",
    config=PGOConfig(
        target_metric=:speed,
        iterations=3
    )
)
println("Improvement: $(result.improvement_pct)%")
```

### Cross-Compilation

Cross-compile for multiple target platforms:

```julia
# Get a cross-compilation target
target = get_cross_target(:arm64_linux)

# Cross-compile
binary = cross_compile(my_func, (Int,), "dist/arm64", "my_func", target)

# Cross-compile with optimization preset
result = cross_compile_with_preset(
    my_func, (Int,),
    "dist/arm64",
    "my_func",
    :embedded,  # Size-optimized
    target
)

# Compare multiple targets
comparison = compare_cross_targets(
    my_func, (Int,),
    "dist/comparison",
    :embedded,
    targets=[:arm64_linux, :arm_linux, :riscv64_linux, :x86_64_windows]
)
```

**Supported Platforms:**
- ARM64 Linux (glibc and musl)
- ARM32 Linux
- RISC-V 64-bit Linux
- x86-64 Windows
- x86-64 and ARM64 macOS
- WebAssembly (WASI)
- Embedded ARM Cortex-M4
- Embedded RISC-V 32-bit

### Interactive TUI

Explore optimization options interactively:

```julia
# Launch interactive menu-driven interface
interactive_optimize(my_func, (Int,), "dist", "my_app", args=(100,))
```

The TUI provides:
- Quick compile with auto-optimization
- Manual preset selection
- Side-by-side preset comparison
- Profile-Guided Optimization
- Cross-compilation workflows
- Cache and logging configuration

### Parallel Processing

Speed up comparisons with parallel compilation:

```julia
# Compare multiple presets in parallel
results = parallel_compare_presets(
    my_func, (Int,), (1000,),
    "dist",
    presets=[:embedded, :serverless, :hpc, :desktop],
    max_concurrent=4
)

# Parallel profile benchmarking
benchmark_results = parallel_benchmark_profiles(
    my_func, (Int,), (1000,),
    profiles=[:PROFILE_SIZE, :PROFILE_SPEED, :PROFILE_AGGRESSIVE],
    max_concurrent=3
)
```

### Comprehensive Analysis

Generate detailed analysis reports:

```julia
# Full analysis with compilation and benchmarking
report = generate_comprehensive_report(
    my_func, (Int,),
    compile=true,
    benchmark=true,
    benchmark_args=(1000,)
)

# Export to JSON or Markdown
export_report_json(report, "report.json")
export_report_markdown(report, "report.md")
```

The analysis includes:
- Allocation detection and profiling
- Inlining analysis
- Binary bloat detection
- SIMD vectorization opportunities
- Security issue detection
- Dependency bloat analysis
- Automated optimization recommendations
- Performance benchmarking

### Logging System

Structured logging with multiple output formats:

```julia
using StaticCompiler

# Configure logging
set_log_config(LogConfig(
    level=DEBUG,
    log_to_file=true,
    log_file="staticcompiler.log",
    json_format=false  # or true for JSON
))

# Logging is integrated throughout the system
compile_with_preset(func, types, "dist", "app", :release, verbose=true)
```

**Log Levels:** `DEBUG`, `INFO`, `WARN`, `ERROR`, `SILENT`

**Output Formats:**
- Plain text (human-readable)
- JSON (machine-parseable)
- ANSI colors for terminal output

### Benchmarking

Measure runtime performance:

```julia
# Benchmark a compiled function
result = benchmark_function(my_func, (Int,), (1000,))
println("Median time: $(format_time(result.median_time_ns))")

# Compare optimization profiles
results = compare_optimization_profiles(
    my_func, (Int,), (1000,),
    config=BenchmarkConfig(
        samples=100,
        profiles_to_test=[:PROFILE_SIZE, :PROFILE_SPEED, :PROFILE_AGGRESSIVE]
    )
)
```

### Result Caching

Speed up repeated operations with caching:

```julia
# Enable caching (automatically used by preset comparisons and PGO)
cache_config = ResultCacheConfig(
    enabled=true,
    max_age_days=30,
    cache_dir=".staticcompiler_cache"
)

# Results are automatically cached and reused
comparison = parallel_compare_presets(
    func, types, args, "dist",
    use_cache=true,
    cache_config=cache_config
)
```

## Documentation

For detailed documentation, see:
- [Architecture Guide](docs/ARCHITECTURE.md) - System design and architecture
- [Interactive TUI Guide](docs/INTERACTIVE_TUI.md) - Using the interactive interface
- [Cross-Compilation Guide](docs/CROSS_COMPILATION.md) - Platform-specific cross-compilation
- [Logging Guide](docs/LOGGING_GUIDE.md) - Logging configuration and usage

## Foreign Function Interfacing

Because Julia objects follow C memory layouts, compiled libraries should be usable from most languages that can interface with C. For example, results should be usable with Python's [CFFI](https://cffi.readthedocs.io/en/latest/) package.

For WebAssembly, interface helpers are available at [WebAssemblyInterfaces](https://github.com/tshort/WebAssemblyInterfaces.jl), and users should also see [WebAssemblyCompiler](https://github.com/tshort/WebAssemblyCompiler.jl) for a package more focused on compilation of WebAssebly in general.
