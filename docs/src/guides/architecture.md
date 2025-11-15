# Architecture Overview

## System Architecture

StaticCompiler.jl transforms Julia functions into standalone executables or shared libraries without requiring the Julia runtime.

### Compilation Pipeline

```
Julia Source Code
        |
        v
[Type Inference]
  (StaticInterpreter)
        |
        v
[Method Resolution]
  (Overlay Tables)
        |
        v
[LLVM Code Generation]
  (GPUCompiler)
        |
        v
[Safety Validation]
  (Pointer Warnings)
        |
        v
[Object Code]
        |
        v
[Linking]
  (Clang/LLD)
        |
        v
Standalone Binary
```

### Core Components

#### 1. StaticInterpreter (src/interpreter.jl)

Custom type inference engine that:
- Extends `Core.Compiler.AbstractInterpreter`
- Maintains separate code cache for static compilation
- Handles method table overlays for version compatibility
- Performs pre-inference validation

**Key Features:**
- No runtime type information
- Requires concrete types throughout
- Uses method overlays for stdlib replacements

#### 2. StaticTarget (src/target.jl)

Target platform specification for compilation:
- Defines CPU architecture, features, and OS
- Supports cross-compilation
- Configures compiler toolchain
- Manages LLVM target machines

**Usage:**
```julia
# Native target
target = StaticTarget()

# Custom target
target = StaticTarget(
    Platform("aarch64-linux-gnu"),
    "cortex-a72",
    "+neon"
)
```

#### 3. Method Overlays (src/quirks.jl, src/target.jl)

Replaces Julia stdlib functions with static-friendly versions:
- Error handling -> `@print_and_throw`
- Math domain errors -> Static messages
- Array bounds checks -> Static checks
- Bumper.jl integration

**Implementation:**
```julia
@device_override @noinline Base.throw_boundserror(A, I) =
    @print_and_throw c"Out-of-bounds array access"
```

Method overlays use Julia's `@overlay` system to provide alternative implementations only during static compilation.

#### 4. Code Generation (src/StaticCompiler.jl)

Main compilation functions:
- `compile_executable` - Creates standalone executables
- `compile_shlib` - Creates shared libraries
- `generate_obj` - Low-level object file generation
- `static_llvm_module` - LLVM IR generation

**Workflow:**
1. Validate input types are concrete
2. Run type inference with StaticInterpreter
3. Generate LLVM module via GPUCompiler
4. Validate for pointer safety
5. Emit object code or LLVM IR
6. Link with system compiler

#### 5. Safety Validation (src/pointer_warning.jl)

Scans LLVM IR for unsafe patterns:
- Integer-to-pointer conversions (`inttoptr`)
- References to Julia runtime objects
- Potential undefined behavior

Warnings help identify code that may fail at runtime.

#### 6. Compilation Cache (src/cache.jl)

Performance optimization through caching:
- SHA-256 based cache keys
- Stores LLVM IR and object code
- Per-Julia-version cache directories
- Automatic invalidation on version mismatch

#### 7. Diagnostics (src/diagnostics.jl)

Error analysis and helpful suggestions:
- Pattern matching on error messages
- Context-specific advice
- Wraps compilation exceptions

#### 8. Compilability Checker (src/checker.jl)

Pre-compilation analysis:
- Type stability validation
- LLVM IR inspection
- Runtime call detection
- Structured issue reporting

## Compilation Phases

### Phase 1: Type Inference

Uses `StaticInterpreter` to:
1. Resolve all method calls to concrete implementations
2. Infer concrete types for all variables
3. Apply method overlays where needed
4. Build typed IR

**Requirements:**
- All types must be inferrable to concrete types
- No `Union` types in returns or variables
- No abstract type dispatch

### Phase 2: LLVM Code Generation

GPUCompiler transforms typed IR to LLVM:
1. Lower Julia IR to LLVM IR
2. Apply optimizations
3. Validate generated code
4. Check for runtime dependencies

**Output:** LLVM Module containing optimized IR

### Phase 3: Safety Validation

Scan for problematic patterns:
- `jl_alloc_*` - GC allocations
- `jl_throw` - Error handling
- `jl_*` - Runtime calls
- `inttoptr` - Pointer operations

### Phase 4: Code Emission

Generate native code:
- On most platforms: Object files (.o)
- On Windows: LLVM IR (.ll) for Clang

Platform-specific handling:
- **Unix/macOS:** Direct object code generation
- **Windows:** LLVM IR -> Clang -> Object code

### Phase 5: Linking

Create final binary:
- **Executables:** Link with wrapper main()
- **Shared libraries:** Create .so/.dylib/.dll
- Apply platform-specific flags
- Optional symbol stripping

## Design Patterns

### 1. Zero Runtime Dependencies

All code must be self-contained:
- No libjulia references
- No GC integration
- No dynamic dispatch
- No runtime type information

### 2. Manual Memory Management

Users must manage memory explicitly:
- `malloc`/`free` for heap allocation
- Stack allocation for small data
- Bumper.jl for RAII-style management

### 3. Static Dispatch Only

All function calls resolved at compile time:
- Concrete types only
- Monomorphization of generic code
- No abstract type dispatch
- Method overlays for specialization

### 4. Error Handling Without Exceptions

Cannot use Julia exceptions:
- `@print_and_throw` for fatal errors
- Return error codes or NaN
- Manual error propagation
- Device overrides for stdlib errors

## Integration Points

### GPUCompiler.jl

StaticCompiler builds on GPUCompiler:
- Reuses LLVM code generation
- Borrows optimization pipeline
- Inherits cross-compilation support
- Uses similar CompilerJob abstraction

### StaticTools.jl

Provides static-friendly primitives:
- `MallocArray` - Heap arrays without GC
- `MallocString` - Manual string management
- `StaticString` - Stack-allocated strings
- `@symbolcall` - Clean C FFI syntax

### LLVM.jl

Direct LLVM manipulation:
- IR inspection
- Module transformation
- Target machine configuration
- Platform-specific code generation

## Extension Points

### Adding Error Overrides

To support new throwing functions:
```julia
@device_override @noinline Base.my_throwing_func(x) =
    @print_and_throw c"My error message"
```

### Custom Targets

Define new compilation targets:
```julia
target = StaticTarget(platform, cpu, features)
set_compiler!(target, "/path/to/compiler")
compile_executable(f, types, path; target=target)
```

### Diagnostic Extensions

Add new error patterns:
```julia
# In src/diagnostics.jl
function diagnose_error(err::Exception, func, types)
    # Add custom pattern matching
    if occursin("my_pattern", string(err))
        push!(suggestions, "My helpful suggestion")
    end
    # ...
end
```

## Performance Considerations

### Compilation Time

Factors affecting compilation speed:
- Type inference complexity
- Number of specialized methods
- LLVM optimization level
- Caching effectiveness

### Binary Size

Factors affecting output size:
- Number of compiled functions
- Library dependencies
- Debug information (strip to reduce)
- LLVM optimization trade-offs

### Runtime Performance

Static compilation provides:
- Fast startup (no JIT warmup)
- Predictable performance
- Small memory footprint

But may sacrifice:
- Peak throughput vs JIT
- Adaptive optimization
- Dynamic specialization

## Limitations

### Fundamental Constraints

Cannot be worked around:
- No GC-tracked memory
- No dynamic types
- No runtime compilation
- No reflection

### Current Limitations

May be improved in future:
- Limited error handling coverage
- Type inference edge cases
- Windows experimental support
- Cross-compilation validation

## Future Directions

Potential improvements:
- Expanded stdlib coverage
- Better diagnostic messages
- Incremental compilation
- More optimization passes
- WebAssembly tooling
- Embedded platform support
