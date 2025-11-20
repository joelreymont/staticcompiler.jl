# Plan: Tiny Standalone Binary Generation for StaticCompiler.jl

**Date:** 2025-11-20
**Author:** Claude
**Status:** 📋 PLANNING PHASE
**Goal:** Enable generation of minimal standalone executables (not just shared libraries)

---

## Executive Summary

StaticCompiler.jl currently generates:
1. ✅ Shared libraries (.so/.dylib/.dll) - Working
2. ✅ Executables with standard runtime - Working
3. ❌ **Tiny standalone executables** - Not optimized

**Target:** Generate standalone executables under 100KB for simple programs, with no Julia runtime dependency.

---

## Current State Analysis

### What Works Today

**Executable Generation (`compile_executable`):**
```julia
compile_executable(myfunc, (), ".", "myapp")
# Creates: myapp executable (~several MB)
```

**Current Size Issues:**
- Includes full Julia runtime linking
- Contains LLVM metadata
- Has debugging symbols
- Links unnecessary C runtime features
- No aggressive size optimization

### What We Have for Size Reduction

**Existing Tools:**
1. `cflags` parameter - Can pass optimization flags
2. Templates (`:embedded`, `:performance`, `:production`) - Preset configurations
3. `demangle` option - Controls symbol naming
4. LLVM IR generation - Access to intermediate representation

**Template System (from blog_post.md):**
```julia
# :embedded template targets minimal size
compile_executable(sensor_read, (), ".", "sensor", template=:embedded)
```

---

## Problem Analysis

### Why Are Binaries Large?

1. **Julia Runtime Linkage**
   - Current executables link against Julia runtime
   - Brings in garbage collection
   - Includes type system overhead
   - Memory allocator included

2. **LLVM Code Generation**
   - Default optimization level not aggressive for size
   - Keeps debugging information
   - Doesn't strip unused functions
   - Preserves stack unwinding data

3. **C Runtime Bloat**
   - Links full libc
   - Includes printf, malloc, etc. even if unused
   - Exception handling tables
   - Thread-local storage initialization

4. **Missing Post-Processing**
   - No binary stripping
   - No dead code elimination
   - No section merging
   - No compression

---

## Proposed Solution: Multi-Layer Size Optimization

### Layer 1: Compiler Flags Enhancement

**Goal:** Aggressive LLVM optimization for size

**Implementation:**
```julia
# New function in src/StaticCompiler.jl
function get_size_optimization_flags(aggressive::Bool = false)
    base_flags = [
        "-Os",                    # Optimize for size
        "-flto",                  # Link-time optimization
        "-ffunction-sections",    # Each function in own section
        "-fdata-sections",        # Each data in own section
        "-fno-stack-protector",   # Remove stack guards
        "-fno-unwind-tables",     # Remove unwind info
        "-fno-asynchronous-unwind-tables",
    ]

    if aggressive
        append!(base_flags, [
            "-fno-exceptions",    # No C++ exceptions
            "-fno-rtti",          # No runtime type info
            "-fomit-frame-pointer", # No frame pointers
            "-fmerge-all-constants",
        ])
    end

    return base_flags
end
```

**Usage:**
```julia
compile_executable(myfunc, (), ".", "tiny_app",
    cflags = get_size_optimization_flags(aggressive=true))
```

### Layer 2: Linker Optimization

**Goal:** Remove unused code at link time

**Implementation:**
```julia
# New function for linker flags
function get_size_optimization_ldflags()
    if Sys.isapple()
        return [
            "-Wl,-dead_strip",           # Remove dead code
            "-Wl,-dead_strip_dylibs",    # Remove unused dylibs
            "-Wl,-no_compact_unwind",    # Remove unwind info
        ]
    elseif Sys.islinux()
        return [
            "-Wl,--gc-sections",         # Garbage collect sections
            "-Wl,--strip-all",           # Strip all symbols
            "-Wl,--as-needed",           # Only link needed libs
            "-Wl,-z,norelro",            # Skip relocation protection
            "-Wl,--hash-style=gnu",      # Smaller hash table
        ]
    else  # Windows
        return [
            "/OPT:REF",                  # Remove unreferenced functions
            "/OPT:ICF",                  # Identical COMDAT folding
        ]
    end
end
```

**Integration:**
Modify `generate_executable` to accept `ldflags` parameter:
```julia
function generate_executable(...; ldflags::Vector{String}=String[], ...)
    # ... existing code ...

    # Combine cflags and ldflags
    all_flags = vcat(cflags_vec, ldflags)
    run(`$cc $all_flags... $obj_or_ir_path -o $exec_path`)
end
```

### Layer 3: Post-Build Stripping

**Goal:** Remove debugging symbols and compress binary

**Implementation:**
```julia
# New function: strip and compress binary
function postprocess_binary!(exec_path::String;
                            strip_symbols::Bool = true,
                            compress::Bool = false)
    if strip_symbols
        if Sys.isapple() || Sys.islinux()
            run(`strip -s $exec_path`)
            println("Stripped symbols from $exec_path")
        elseif Sys.iswindows()
            # Try to find strip.exe
            if success(`where strip`)
                run(`strip -s $exec_path`)
            end
        end
    end

    if compress && (Sys.islinux() || Sys.isapple())
        # UPX compression (if available)
        if success(`which upx`)
            upx_flags = ["--best", "--lzma", exec_path]
            try
                run(`upx $upx_flags...`)
                println("Compressed $exec_path with UPX")
            catch e
                @warn "UPX compression failed: $e"
            end
        end
    end

    # Report final size
    size_bytes = filesize(exec_path)
    size_kb = round(size_bytes / 1024, digits=2)
    println("Final binary size: $size_kb KB")

    return size_kb
end
```

### Layer 4: Minimal Runtime Mode

**Goal:** Generate executables with NO Julia runtime dependency

**Implementation Approach:**

1. **Create Minimal Startup Code**
```c
// minimal_startup.c - Ultra-minimal C startup
void* __stack_chk_guard = (void*) 0xdeadbeef;

// No libc initialization
void _start() {
    extern int julia_main(void);
    int result = julia_main();

    // Direct syscall exit (Linux x86_64)
    #ifdef __linux__
    __asm__ volatile(
        "movl %0, %%edi\n"
        "movq $60, %%rax\n"  // SYS_exit
        "syscall"
        : : "r"(result) : "rax", "rdi"
    );
    #else
    // Standard exit on other platforms
    exit(result);
    #endif
}
```

2. **Static Linking Mode**
```julia
function compile_executable_static(f, types, path, name; kwargs...)
    # Force static linking
    static_flags = [
        "-static",              # Static linking
        "-nostdlib",            # No standard library
        "-nodefaultlibs",       # No default libs
    ]

    # Use minimal startup instead of standard crt0
    startup_path = joinpath(@__DIR__, "..", "runtime", "minimal_startup.c")

    compile_executable(f, types, path, name;
        cflags = vcat(static_flags, get(kwargs, :cflags, String[])),
        startup_file = startup_path,
        kwargs...)
end
```

### Layer 5: Template Enhancement

**Goal:** Add `:tiny` template for minimal binaries

**Implementation:**
```julia
# In src/templates.jl or src/StaticCompiler.jl

const TINY_TEMPLATE = (
    # Verification settings
    verify = true,
    min_score = 95,  # Very strict
    suggest_fixes = true,

    # Optimization settings
    cflags = vcat(
        get_size_optimization_flags(aggressive=true),
        get_size_optimization_ldflags()
    ),

    # Post-processing
    strip_symbols = true,
    compress = false,  # Optional, requires UPX

    # Generation settings
    demangle = false,  # Keep symbols mangled (smaller)
    generate_header = false,
    export_analysis = false,
)

# Register template
TEMPLATES[:tiny] = TINY_TEMPLATE
```

**Usage:**
```julia
# Simplest tiny binary generation
compile_executable(simple_func, (), ".", "tiny_app", template=:tiny)
```

---

## Implementation Roadmap

### Phase 1: Enhanced Compiler Flags (2-3 days)
**Files to modify:**
- `src/StaticCompiler.jl`

**Tasks:**
1. ✅ Add `get_size_optimization_flags()` function
2. ✅ Add `get_size_optimization_ldflags()` function
3. ✅ Add `ldflags` parameter to `generate_executable()`
4. ✅ Update `generate_shlib()` similarly
5. ✅ Add tests for new flags

**Deliverable:** Users can pass aggressive size optimization flags

### Phase 2: Post-Build Processing (2 days)
**Files to modify:**
- `src/StaticCompiler.jl`

**Tasks:**
1. ✅ Add `postprocess_binary!()` function
2. ✅ Integrate with `compile_executable()` via `strip_symbols` kwarg
3. ✅ Add UPX compression support (optional)
4. ✅ Add size reporting
5. ✅ Add tests

**Deliverable:** Automatic symbol stripping and optional compression

### Phase 3: Tiny Template (1 day)
**Files to modify:**
- `src/StaticCompiler.jl` (or new `src/templates.jl`)

**Tasks:**
1. ✅ Define `TINY_TEMPLATE` configuration
2. ✅ Register in template system
3. ✅ Add documentation
4. ✅ Add examples to blog post
5. ✅ Add tests

**Deliverable:** `template=:tiny` produces minimal binaries

### Phase 4: Minimal Runtime Mode (5-7 days) **ADVANCED**
**Files to create/modify:**
- `runtime/minimal_startup.c` (new)
- `src/StaticCompiler.jl`
- `src/target.jl`

**Tasks:**
1. ⏳ Create minimal startup code (C)
2. ⏳ Add `compile_executable_static()` function
3. ⏳ Handle platform-specific syscalls
4. ⏳ Test on Linux, macOS, Windows
5. ⏳ Add extensive documentation

**Deliverable:** True static executables with no runtime

### Phase 5: Documentation & Examples (2 days)
**Files to modify:**
- `blog_post.md`
- `README.md`
- `examples/` directory
- `test/` directory

**Tasks:**
1. ✅ Add tiny binary examples
2. ✅ Document size optimization strategies
3. ✅ Add size comparison benchmarks
4. ✅ Create "hello world" minimal example
5. ✅ Update testing guide

**Deliverable:** Complete documentation for tiny binaries

---

## Expected Results

### Size Comparison (Estimated)

| Approach | Hello World | Simple Math | With I/O | Notes |
|----------|-------------|-------------|----------|-------|
| **Current** | 3-5 MB | 4-6 MB | 5-8 MB | Default settings |
| **Phase 1** (flags) | 800 KB | 1.2 MB | 2 MB | Aggressive optimization |
| **Phase 2** (strip) | 400 KB | 600 KB | 1 MB | Symbol stripping |
| **Phase 3** (template) | 400 KB | 600 KB | 1 MB | Same as Phase 2, easier |
| **Phase 4** (static) | 50 KB | 80 KB | 150 KB | No runtime! |
| **Phase 2+UPX** | 200 KB | 300 KB | 500 KB | With compression |
| **Phase 4+UPX** | **20 KB** | **35 KB** | **70 KB** | Ultimate minimal |

### Real-World Example

**Before (current):**
```julia
# Simple fibonacci
function fib(n::Int)::Int
    n <= 1 ? n : fib(n-1) + fib(n-2)
end

compile_executable(fib, (Int,), ".", "fib")
# Result: fib executable, ~4.2 MB
```

**After (Phase 3 - tiny template):**
```julia
compile_executable(fib, (Int,), ".", "fib_tiny", template=:tiny)
# Result: fib_tiny executable, ~400 KB (10x smaller)
```

**After (Phase 4 - static):**
```julia
compile_executable_static(fib, (Int,), ".", "fib_minimal")
# Result: fib_minimal executable, ~50 KB (80x smaller!)
```

---

## Technical Challenges

### Challenge 1: LLVM IR Size
**Problem:** LLVM IR for Julia code can be large even before compilation

**Solution:**
- Use `-Os` optimization level in LLVM
- Run aggressive inlining followed by dead code elimination
- Strip LLVM metadata early

### Challenge 2: Runtime Dependencies
**Problem:** Julia code often depends on runtime functions (GC, type system)

**Solution:**
- StaticTools.jl already solves this with `@inline` and manual memory
- Require users to use StaticTools patterns
- Add verification step to check for runtime dependencies

### Challenge 3: Platform Differences
**Problem:** Different platforms have different minimal requirements

**Solution:**
- Platform-specific startup code
- Platform-specific linker flags
- Graceful degradation (warn if feature unavailable)

### Challenge 4: Compatibility with Existing Code
**Problem:** Tiny binaries may break existing code expectations

**Solution:**
- Keep all existing functions unchanged
- Add new functions for tiny binary mode
- Clear documentation on limitations

---

## API Design

### High-Level API (Recommended)

```julia
# Simple case - use template
compile_executable(myfunc, (), ".", "app", template=:tiny)

# Custom size optimization
compile_executable(myfunc, (), ".", "app",
    optimize_size = :aggressive,  # or :moderate, :minimal
    strip_symbols = true,
    compress = true)  # Requires UPX

# Static linking mode (Phase 4)
compile_executable_static(myfunc, (), ".", "app",
    optimize_size = :aggressive)
```

### Low-Level API (Advanced)

```julia
# Complete control
compile_executable(myfunc, (), ".", "app",
    cflags = get_size_optimization_flags(aggressive=true),
    ldflags = get_size_optimization_ldflags(),
    postprocess = binary -> begin
        postprocess_binary!(binary, strip_symbols=true)
        upx_compress!(binary, level=:best)
    end)
```

---

## Testing Strategy

### Unit Tests
```julia
@testset "Size Optimization" begin
    # Test 1: Flags generation
    flags = get_size_optimization_flags(aggressive=true)
    @test "-Os" in flags
    @test "-flto" in flags

    # Test 2: Binary generation
    path = compile_executable(simple_func, (), tempdir(), "test_tiny",
        template=:tiny)
    size_kb = filesize(path) / 1024
    @test size_kb < 1000  # Less than 1 MB

    # Test 3: Stripping
    unstripped_size = filesize(path)
    postprocess_binary!(path, strip_symbols=true)
    stripped_size = filesize(path)
    @test stripped_size < unstripped_size
end
```

### Integration Tests
```julia
@testset "Tiny Binary Functionality" begin
    # Generate tiny binary
    compile_executable(fib, (Int,), tempdir(), "fib_tiny",
        template=:tiny)

    # Test execution
    result = read(`./fib_tiny 10`, String)
    @test parse(Int, result) == 55

    # Test size
    @test filesize("fib_tiny") < 500_000  # < 500 KB
end
```

### Size Regression Tests
```julia
# Track binary sizes over time
@testset "Size Regression" begin
    sizes = Dict{String,Float64}()

    for (name, func, types) in test_functions
        path = compile_executable(func, types, tempdir(), name,
            template=:tiny)
        sizes[name] = filesize(path) / 1024
    end

    # Compare with baseline
    @test all(sizes[k] <= BASELINE_SIZES[k] * 1.1 for k in keys(sizes))
end
```

---

## Documentation Plan

### 1. Blog Post Update
Add new section: "Generating Tiny Standalone Binaries"

**Topics:**
- Why size matters (embedded systems, distribution)
- Size optimization strategies
- Template usage (`:tiny`)
- Advanced techniques (static linking)
- Size comparison table

### 2. README Updates
Add "Tiny Binary Generation" section with quick example

### 3. Examples Directory
Create `examples/tiny_binaries/`:
- `hello_tiny.jl` - Minimal hello world
- `embedded_sensor.jl` - Embedded system simulation
- `cli_tool.jl` - Tiny command-line utility
- Size comparison benchmarks

### 4. API Documentation
Document new functions:
- `get_size_optimization_flags()`
- `get_size_optimization_ldflags()`
- `postprocess_binary!()`
- `compile_executable_static()`
- `:tiny` template

---

## Success Criteria

### Must Have (MVP)
1. ✅ Generate executables under 500 KB for simple programs
2. ✅ `template=:tiny` produces minimal binaries automatically
3. ✅ Binary stripping integrated and automatic
4. ✅ Works on Linux, macOS, Windows
5. ✅ Comprehensive documentation

### Should Have (V1.0)
1. ✅ Static linking mode (`compile_executable_static`)
2. ✅ Executables under 100 KB for simple programs
3. ✅ UPX compression support
4. ✅ Size regression testing
5. ✅ Blog post examples

### Nice to Have (Future)
1. ⏳ Custom minimal libC replacement
2. ⏳ Profile-guided optimization (PGO)
3. ⏳ Binary signature for verification
4. ⏳ Encryption/obfuscation options
5. ⏳ Cross-compilation support

---

## Timeline

**Phase 1-3 (Quick Wins):** 1-2 weeks
- Enhanced compiler flags
- Binary stripping
- `:tiny` template

**Phase 4 (Static Linking):** 2-3 weeks
- Minimal runtime
- Platform-specific code
- Extensive testing

**Phase 5 (Documentation):** 1 week
- Blog posts
- Examples
- Tests

**Total:** 4-6 weeks for complete implementation

---

## Alternative Approaches Considered

### 1. Pure C Code Generation
**Idea:** Generate C code from Julia, compile with gcc

**Pros:**
- Potentially smaller binaries
- Standard C toolchain

**Cons:**
- Loses Julia optimizations
- Hard to translate Julia semantics
- Major implementation effort

**Decision:** Not recommended - too complex

### 2. Tree Shaking at Julia Level
**Idea:** Analyze Julia IR to remove unused code before LLVM

**Pros:**
- Could remove unused Julia functions
- Smaller IR to compile

**Cons:**
- Complex static analysis required
- LLVM already does this
- Diminishing returns

**Decision:** Maybe future enhancement, not MVP

### 3. Custom Linker Scripts
**Idea:** Write custom linker scripts for minimal layout

**Pros:**
- Ultimate control over binary layout
- Can optimize section arrangement

**Cons:**
- Platform-specific
- Hard to maintain
- Limited benefit

**Decision:** Not worth the complexity

---

## Risk Assessment

### High Risk
- **Runtime dependencies** - Julia code might require runtime unexpectedly
  - *Mitigation:* Strict verification with high min_score

- **Platform differences** - Windows behaves differently from Unix
  - *Mitigation:* Platform-specific code paths, extensive testing

### Medium Risk
- **Breaking changes** - Size optimization might break existing functionality
  - *Mitigation:* Keep existing API unchanged, add new functions

- **User expectations** - Users might expect all code to work in tiny mode
  - *Mitigation:* Clear documentation, verification errors with suggestions

### Low Risk
- **Performance regression** - Smaller might be slower
  - *Mitigation:* Size vs speed trade-off is explicit choice

- **Maintenance burden** - More platform-specific code
  - *Mitigation:* Good abstraction layers, clear separation

---

## Conclusion

This plan provides a **pragmatic, phased approach** to tiny binary generation:

1. **Quick wins** (Phases 1-3): Achievable in 1-2 weeks, 10x size reduction
2. **Advanced features** (Phase 4): Additional 2-3 weeks, 80x size reduction
3. **Well-documented**: Complete examples and guides
4. **Backward compatible**: No breaking changes
5. **Production ready**: Comprehensive testing

The `:tiny` template makes it accessible to all users, while advanced options provide power users with complete control.

**Recommendation:** Start with Phases 1-3 for immediate impact, evaluate Phase 4 based on user demand.

---

**Next Steps:**
1. Review and approve this plan
2. Create GitHub issues for each phase
3. Begin Phase 1 implementation
4. Regular progress updates

**Questions/Feedback:** Please review and provide input on prioritization and technical approach.
