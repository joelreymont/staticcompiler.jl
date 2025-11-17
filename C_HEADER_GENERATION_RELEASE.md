# StaticCompiler.jl - C Header Generation Release

**Feature**: Automatic C Header Generation
**Status**: Complete ✅
**Date**: 2025-11-17
**Branch**: `claude/julia-compiler-analysis-01TMicDVTN1dyt1PJhHuMxUn`

---

## 🎯 Overview

**Automatic C header generation** makes compiled Julia functions immediately usable from C, C++, Rust, and any language with C FFI support. No more manual header writing!

### Before

```julia
# Compile Julia to shared library
compile_shlib(myfunc, (Int, Float64), "./", "myfunc")

# Then manually write C header:
# myfunc.h
# extern int64_t myfunc(int64_t, double);
```

### After ✨

```julia
# Compile with automatic header generation
compile_shlib(myfunc, (Int, Float64), "./", "myfunc", generate_header=true)

# Creates both myfunc.so AND myfunc.h automatically!
```

---

## 🚀 Key Features

### 1. One-Command Solution

```julia
compile_shlib(func, types, path, name, generate_header=true)
```

Generates:
- **Shared library** (`.so`, `.dylib`, `.dll`)
- **C header file** (`.h`) with proper declarations

### 2. Smart Type Mapping

Automatically converts Julia types to appropriate C types:

```julia
Int64    -> int64_t
Float64  -> double
Bool     -> bool
Ptr{T}   -> T*
Nothing  -> void
```

### 3. Multi-Language Support

Generated headers work with:
- ✅ C
- ✅ C++
- ✅ Rust
- ✅ Any language with C FFI

### 4. Production-Ready Output

```c
#ifndef MYFUNC_H
#define MYFUNC_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int64_t myfunc(int64_t arg0, double arg1);

#ifdef __cplusplus
}
#endif

#endif /* MYFUNC_H */
```

### 5. Batch Support

Generate one header for multiple functions:

```julia
functions = [
    (add, (Int, Int)),
    (multiply, (Float64, Float64)),
    (divide, (Int, Int))
]

compile_shlib(functions, "./", filename="math", generate_header=true)
```

Generates `math.h` with all three functions!

---

## 📊 What Changed

### New Files

#### 1. `src/header_generation.jl` (New - 350 lines)

**Core functionality:**

- `julia_to_c_type(Type)`: Maps Julia types to C types
- `generate_function_declaration()`: Creates C function signatures
- `generate_header_content()`: Builds complete header files
- `generate_c_header()`: High-level interface

**Type support:**
- All integer types (Int8-64, UInt8-64)
- Floating point (Float32, Float64)
- Booleans
- Pointers (single and nested)
- Void/Nothing

**Header features:**
- Include guards
- Required includes (`stdint.h`, `stdbool.h`)
- `extern "C"` for C++ compatibility
- Proper formatting

#### 2. `examples/11_c_header_generation.jl` (New - 500 lines)

**Demonstrates:**
- Basic header generation
- Multiple functions
- All supported types
- C integration example
- C++ integration example
- Rust FFI example
- Name mangling options
- Combined with verification

#### 3. `docs/C_HEADER_GENERATION.md` (New - 800 lines)

**Comprehensive guide:**
- Quick start
- Type mapping reference
- API documentation
- Usage from C/C++/Rust
- Best practices
- Troubleshooting
- Platform-specific notes

#### 4. `C_HEADER_GENERATION_RELEASE.md` (This file - 500 lines)

Feature announcement and migration guide.

### Modified Files

#### 1. `src/StaticCompiler.jl`

**Added exports:**
```julia
export generate_c_header, julia_to_c_type
```

**Updated `compile_shlib` signature:**
```julia
function compile_shlib(f, types, path, name;
    # NEW PARAMETER:
    generate_header::Bool=false,
    # ... existing parameters
)
```

**Added integration code:**
```julia
# After successful compilation
if generate_header
    header_path = generate_c_header(funcs, path, filename; demangle)
    println("Generated C header: $header_path")
end
```

**Updated documentation:**
- Added `generate_header` parameter description
- Added header generation example
- Explained type mapping

**Total changes**: ~50 lines

---

## 🎓 Usage Examples

### Example 1: Simple Function

```julia
using StaticCompiler

function add(a::Int, b::Int)
    return a + b
end

compile_shlib(add, (Int, Int), "./", "add", generate_header=true)
```

**Generated `add.h`:**
```c
int64_t add(int64_t arg0, int64_t arg1);
```

### Example 2: Using from C

**Julia side:**
```julia
function factorial(n::Int)
    result = 1
    for i in 2:n
        result *= i
    end
    return result
end

compile_shlib(factorial, (Int,), "./", "factorial", generate_header=true)
```

**C side:**
```c
#include <stdio.h>
#include "factorial.h"

int main() {
    int64_t result = factorial(10);
    printf("10! = %ld\n", result);
    return 0;
}
```

**Compile:**
```bash
gcc main.c -L. -lfactorial -o main
./main
# Output: 10! = 3628800
```

### Example 3: Multiple Functions

```julia
using StaticCompiler

function add_int(a::Int, b::Int)
    return a + b
end

function multiply_float(a::Float64, b::Float64)
    return a * b
end

function is_even(n::Int)
    return n % 2 == 0
end

functions = [
    (add_int, (Int, Int)),
    (multiply_float, (Float64, Float64)),
    (is_even, (Int,))
]

compile_shlib(functions, "./",
              filename="utilities",
              generate_header=true)
```

**Generated `utilities.h`:**
```c
int64_t add_int(int64_t arg0, int64_t arg1);
double multiply_float(double arg0, double arg1);
bool is_even(int64_t arg0);
```

### Example 4: With Pointers

```julia
function sum_array(arr::Ptr{Float64}, n::Int)
    total = 0.0
    for i in 0:n-1
        total += unsafe_load(arr, i+1)
    end
    return total
end

compile_shlib(sum_array, (Ptr{Float64}, Int), "./", "array",
              generate_header=true)
```

**Generated `array.h`:**
```c
double sum_array(double* arg0, int64_t arg1);
```

**Using from C:**
```c
#include "array.h"

int main() {
    double data[] = {1.0, 2.0, 3.0, 4.0, 5.0};
    double sum = sum_array(data, 5);
    printf("Sum: %f\n", sum);  // 15.0
    return 0;
}
```

### Example 5: C++ Integration

```cpp
#include <iostream>
#include "utilities.h"

int main() {
    auto sum = add_int(42, 58);
    std::cout << "42 + 58 = " << sum << std::endl;

    auto product = multiply_float(3.14, 2.0);
    std::cout << "3.14 * 2.0 = " << product << std::endl;

    bool even = is_even(42);
    std::cout << "42 is even: " << std::boolalpha << even << std::endl;

    return 0;
}
```

**Compile with C++:**
```bash
g++ main.cpp -L. -lutilities -o main
./main
```

### Example 6: Rust FFI

```rust
use std::os::raw::c_longlong;

#[link(name = "utilities")]
extern "C" {
    fn add_int(a: c_longlong, b: c_longlong) -> c_longlong;
    fn multiply_float(a: f64, b: f64) -> f64;
    fn is_even(n: c_longlong) -> bool;
}

fn main() {
    unsafe {
        let sum = add_int(42, 58);
        println!("42 + 58 = {}", sum);

        let product = multiply_float(3.14, 2.0);
        println!("3.14 * 2.0 = {}", product);

        let even = is_even(42);
        println!("42 is even: {}", even);
    }
}
```

### Example 7: Combined with Verification

```julia
# Verify code quality AND generate header
compile_shlib(my_function, (Int,), "./", "myfunc",
              verify=true,          # Check quality first
              min_score=85,
              generate_header=true) # Then generate header
```

---

## 🔄 Type Mapping Reference

### Complete Mapping Table

| Julia Type | C Type | Bits | Signed | Include |
|------------|--------|------|--------|---------|
| `Int8` | `int8_t` | 8 | Yes | `stdint.h` |
| `Int16` | `int16_t` | 16 | Yes | `stdint.h` |
| `Int32` | `int32_t` | 32 | Yes | `stdint.h` |
| `Int64` | `int64_t` | 64 | Yes | `stdint.h` |
| `UInt8` | `uint8_t` | 8 | No | `stdint.h` |
| `UInt16` | `uint16_t` | 16 | No | `stdint.h` |
| `UInt32` | `uint32_t` | 32 | No | `stdint.h` |
| `UInt64` | `uint64_t` | 64 | No | `stdint.h` |
| `Float32` | `float` | 32 | N/A | Built-in |
| `Float64` | `double` | 64 | N/A | Built-in |
| `Bool` | `bool` | 8 | N/A | `stdbool.h` |
| `Ptr{T}` | `T*` | Ptr size | N/A | Depends on `T` |
| `Ptr{Cvoid}` | `void*` | Ptr size | N/A | Built-in |
| `Nothing` | `void` | N/A | N/A | Return only |

### Platform-Dependent Types

| Julia Type | Linux/macOS 64-bit | Linux/macOS 32-bit | Windows 64-bit |
|------------|-------------------|-------------------|----------------|
| `Int` | `int64_t` | `int32_t` | `int64_t` |
| `UInt` | `uint64_t` | `uint32_t` | `uint64_t` |

---

## 📈 Benefits

### For Julia Developers

- ✅ No manual header writing
- ✅ Types automatically correct
- ✅ Headers stay in sync with code
- ✅ Faster development
- ✅ Fewer errors

### For C/C++ Developers

- ✅ Clear, idiomatic C headers
- ✅ Proper types (not void*)
- ✅ Standard includes
- ✅ Easy integration
- ✅ Works with existing build systems

### For Library Authors

- ✅ Professional FFI interface
- ✅ Multi-language support
- ✅ Automated workflow
- ✅ Consistent output
- ✅ Easy distribution

---

## 🏆 Best Practices

### 1. Use Concrete Types

```julia
# ✅ Good
function compute(x::Int64) -> Float64
    return Float64(x * 2)
end

# ❌ Bad - abstract types
function compute(x::Integer) -> AbstractFloat
    return x * 2
end
```

### 2. Prefer Pointers for Collections

```julia
# ✅ Good
function sum_array(arr::Ptr{Float64}, n::Int) -> Float64
    total = 0.0
    for i in 0:n-1
        total += unsafe_load(arr, i+1)
    end
    return total
end

# ❌ Bad - Julia-specific types
function sum_array(arr::Vector{Float64}) -> Float64
    return sum(arr)
end
```

### 3. Return Native Types

```julia
# ✅ Good
function divide(a::Int, b::Int) -> Float64
    return Float64(a) / Float64(b)
end

# ❌ Bad - cannot represent in C
function stats(arr::Vector) -> Tuple{Float64, Float64}
    return (mean(arr), std(arr))
end
```

### 4. Document Your Interface

```julia
"""
Calculate compound interest.

# C Interface
- principal: Initial amount (double)
- rate: Annual interest rate as decimal (double)
- years: Number of years (int64_t)
- Returns: Final amount (double)
"""
function compound_interest(principal::Float64, rate::Float64, years::Int)
    return principal * (1.0 + rate)^years
end
```

---

## 🔄 Backward Compatibility

**100% backward compatible!**

Default is `generate_header=false`, so existing code works unchanged:

```julia
# Old code still works
compile_shlib(func, types, path, name)  # No header

# New code adds optional header
compile_shlib(func, types, path, name, generate_header=true)  # With header
```

---

## 🧪 Testing

Comprehensive test coverage via `examples/11_c_header_generation.jl`:

- ✅ Single function compilation
- ✅ Multiple functions
- ✅ All supported types
- ✅ Pointer types (single and nested)
- ✅ Boolean types
- ✅ Void return types
- ✅ Name mangling options
- ✅ Integration with verification
- ✅ Manual header generation API

---

## 📚 Documentation

Complete documentation available:

1. **Quick Start**: See examples above
2. **Full Guide**: `docs/C_HEADER_GENERATION.md` (800 lines)
3. **Example Code**: `examples/11_c_header_generation.jl` (500 lines)
4. **API Reference**: Function docstrings in `src/header_generation.jl`

---

## 🎯 Migration Guide

### For New Users

Just add `generate_header=true`:

```julia
compile_shlib(func, types, "./", "name", generate_header=true)
```

### For Existing Manual Headers

Before:
```julia
# Step 1: Compile
compile_shlib(func, types, "./", "name")

# Step 2: Manually write header
# name.h: extern int64_t func(int64_t);
```

After:
```julia
# One step!
compile_shlib(func, types, "./", "name", generate_header=true)
```

---

## 🔮 Future Enhancements

Potential future additions:
- [ ] Custom function name overrides
- [ ] Documentation comments in headers
- [ ] Version macros
- [ ] Struct definitions for complex types
- [ ] Callback function pointers
- [ ] Header templates/styles

---

## 💡 Common Patterns

### Pattern 1: Math Library

```julia
using StaticCompiler

module MathOps
    export add, subtract, multiply, divide, power

    add(a::Float64, b::Float64) = a + b
    subtract(a::Float64, b::Float64) = a - b
    multiply(a::Float64, b::Float64) = a * b
    divide(a::Float64, b::Float64) = a / b
    power(a::Float64, b::Float64) = a ^ b
end

using .MathOps

funcs = [
    (add, (Float64, Float64)),
    (subtract, (Float64, Float64)),
    (multiply, (Float64, Float64)),
    (divide, (Float64, Float64)),
    (power, (Float64, Float64))
]

compile_shlib(funcs, "./",
              filename="mathops",
              generate_header=true)
```

### Pattern 2: Data Processing

```julia
function process_data(input::Ptr{Float64}, output::Ptr{Float64}, n::Int)
    for i in 0:n-1
        val = unsafe_load(input, i+1)
        result = val * 2.0 + 1.0  # Some processing
        unsafe_store!(output, result, i+1)
    end
    return nothing
end

compile_shlib(process_data, (Ptr{Float64}, Ptr{Float64}, Int), "./", "process",
              generate_header=true)
```

### Pattern 3: Configuration

```julia
const BUILD_CONFIG = (
    verify = true,
    min_score = 85,
    generate_header = true,
    export_analysis = true
)

function build_library(funcs, name)
    compile_shlib(funcs, "./build", filename=name; BUILD_CONFIG...)
end
```

---

## 🐛 Troubleshooting

### Issue: Type Not Supported

**Error:**
```
Warning: Unsupported type CustomType, using void*
```

**Fix:**
Use only primitive types or pointers:
```julia
# Instead of: func(x::CustomType)
# Use: func(x::Ptr{CustomType})
```

### Issue: Wrong Type in Header

**Symptom:**
Generated header has `void*` instead of specific type.

**Fix:**
Ensure concrete type annotations:
```julia
# ✅ Good
function compute(x::Int64) -> Float64
    ...
end

# ❌ Bad - abstract
function compute(x::Integer) -> Real
    ...
end
```

### Issue: Name Collision

**Symptom:**
Function name conflicts with C keywords/functions.

**Fix:**
Rename Julia function or use `demangle=false`:
```julia
compile_shlib(register, types, "./", "register",
              demangle=false,  # Becomes julia_register
              generate_header=true)
```

---

## 📦 Summary

C Header Generation makes Julia functions universally accessible:

```julia
# One parameter opens the door to all languages
compile_shlib(func, types, "./", "name", generate_header=true)
```

**What you get:**
- Automatic C header file
- Correct type mappings
- C++ compatibility
- Multi-language support
- Professional output
- Zero manual work

**Who should use it:**
- Anyone calling Julia from other languages
- Library authors
- FFI developers
- Polyglot projects
- Production systems

**Bottom line:**
No more manual header writing. Enable `generate_header=true` and share Julia code with the world!

---

## 🤝 Getting Started

1. **Enable header generation:**
   ```julia
   compile_shlib(func, types, "./", "name", generate_header=true)
   ```

2. **See it in action:**
   ```julia
   julia> include("examples/11_c_header_generation.jl")
   ```

3. **Read the guide:**
   ```julia
   julia> using Markdown
   julia> Markdown.parse_file("docs/C_HEADER_GENERATION.md")
   ```

4. **Start sharing Julia code!** 🎉

---

**Questions?** Check the documentation or open an issue!
