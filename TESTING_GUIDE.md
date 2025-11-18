# Testing Guide for StaticCompiler.jl Bug Fixes

**Date:** 2025-11-18
**Session:** v3
**Branch:** `claude/static-compiler-01MzDXCnFRXaJXWpJ3o2Fnvk`

## Overview

This guide provides instructions for testing the bug fixes implemented in this session. Julia is not available in the current environment, so these tests must be run externally.

## Bug Fixes to Test

1. ✅ Module loading in `bin/analyze`
2. ✅ Correct API usage in `bin/analyze-code`
3. ✅ Template override handling in `compile_shlib`
4. ✅ Template support in `compile_executable`
5. ✅ Type coercion in `bin/batch-compile`

## Prerequisites

```bash
# Install Julia (version 1.10 or later)
# https://julialang.org/downloads/

# Clone and checkout the branch
git clone https://github.com/joelreymont/staticcompiler.jl.git
cd staticcompiler.jl
git checkout claude/static-compiler-01MzDXCnFRXaJXWpJ3o2Fnvk

# Install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Test Suite

### 1. Run Full Test Suite

```bash
# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'
```

**Expected:** All tests should pass

### 2. Run Test Groups

```bash
# Core tests
ENV["GROUP"]="Core" julia --project=. -e 'using Pkg; Pkg.test()'

# Integration tests
ENV["GROUP"]="Integration" julia --project=. -e 'using Pkg; Pkg.test()'

# Optimization tests
ENV["GROUP"]="Optimizations" julia --project=. -e 'using Pkg; Pkg.test()'

# Advanced tests (property-based, fuzzing)
ENV["GROUP"]="Advanced" julia --project=. -e 'using Pkg; Pkg.test()'

# Quality tests
ENV["GROUP"]="Quality" julia --project=. -e 'using Pkg; Pkg.test()'
```

## Specific Bug Fix Tests

### Test 1: Module Loading (bin/analyze)

**Bug Fixed:** Module loading with `@eval using` before analysis

```bash
# Create a test module
cat > TestModule.jl << 'EOF'
module TestModule
    export test_func
    test_func(x::Int) = x * 2
end
EOF

# Test the analyze command (should load module automatically)
julia --project=. bin/analyze --module TestModule analyze
```

**Expected:**
- No `UndefVarError: TestModule not defined`
- Module loads successfully
- Analysis runs

**Failure Indicator:**
- `Error: Could not load module 'TestModule'` if module not in path
- OR successful analysis if module is accessible

### Test 2: API Function Call (bin/analyze-code)

**Bug Fixed:** Changed from `analyze_function` to `quick_check`

```julia
# Create test file
cat > test_code.jl << 'EOF'
using StaticCompiler

function simple_add(a::Int, b::Int)
    return a + b
end
EOF

# Run analysis
julia --project=. bin/analyze-code test_code.jl simple_add Int,Int
```

**Expected:**
- No `UndefVarError: analyze_function not defined`
- Shows analysis results with score
- Shows compilation readiness

**Output Should Include:**
```
Overall Score: XX/100
Ready: ✅ YES or ❌ NO
Status: ✅ PASS or ❌ FAIL
```

### Test 3: Template Override (compile_shlib)

**Bug Fixed:** User-provided parameters now override template defaults

```julia
# test_template_override.jl
using StaticCompiler
using StaticTools

function test_func(x::Int)
    return x * 2
end

# Test 1: Template default should apply
println("Test 1: Template default (verify=true from :production template)")
try
    compile_shlib(test_func, (Int,), tempdir(), "test1",
                  template=:production)
    println("✅ Template applied")
catch e
    println("❌ Error: $e")
end

# Test 2: User override should work
println("\nTest 2: User override (verify=false overrides template)")
compile_shlib(test_func, (Int,), tempdir(), "test2",
              template=:production,
              verify=false)  # Should override template's verify=true
println("✅ Override worked (no verification ran)")

# Test 3: Explicit min_score should override
println("\nTest 3: Explicit min_score override")
compile_shlib(test_func, (Int,), tempdir(), "test3",
              template=:production,
              min_score=50)  # Should override template's min_score
println("✅ min_score override worked")
```

**Run:**
```bash
julia --project=. test_template_override.jl
```

**Expected:**
- Test 1: Shows "Using template: :production" and runs verification
- Test 2: No verification output (override worked)
- Test 3: Uses min_score=50 instead of template default

### Test 4: Template Support in compile_executable

**Bug Fixed:** Added template parameter and handling to `compile_executable`

```julia
# test_executable_template.jl
using StaticCompiler
using StaticTools

function hello()
    println(c"Hello from template test!")
    return 0
end

# Test 1: Use embedded template
println("Test 1: compile_executable with :embedded template")
compile_executable(hello, (), tempdir(), "hello_embedded",
                   template=:embedded)
println("✅ Embedded template worked")

# Test 2: Use production template
println("\nTest 2: compile_executable with :production template")
compile_executable(hello, (), tempdir(), "hello_production",
                   template=:production)
println("✅ Production template worked")

# Test 3: Template with override
println("\nTest 3: Template with explicit override")
compile_executable(hello, (), tempdir(), "hello_override",
                   template=:embedded,
                   verify=false)  # Override template's verify=true
println("✅ Override worked")
```

**Run:**
```bash
julia --project=. test_executable_template.jl
```

**Expected:**
- Test 1: Shows "Using template: :embedded" with verification
- Test 2: Shows "Using template: :production" with verification
- Test 3: No verification output (override worked)

### Test 5: Type Coercion (bin/batch-compile)

**Bug Fixed:** JSON string values converted to symbols for template parameter

```json
# Create test_batch_config.json
{
  "defaults": {
    "template": "production"
  },
  "functions": [
    {
      "source": "test_code.jl",
      "function": "simple_add",
      "types": "Int,Int",
      "output": "simple_add",
      "shlib": true
    }
  ]
}
```

```bash
# Run batch compilation
julia --project=. bin/batch-compile test_batch_config.json
```

**Expected:**
- No `MethodError` about template type
- String "production" correctly converted to Symbol :production
- Compilation succeeds

**Failure Indicator:**
- `MethodError: no method matching compile_shlib(...; template::String)`

## Blog Post Example Tests

Test the examples from `blog_post.md`:

### Example 2: Automatic Verification

```julia
using StaticCompiler
using StaticTools

function hello()
    println(c"Hello, World!")
    return 0
end

compile_executable(hello, (), "./", "hello_verify", verify=true)
```

**Expected Output:**
```
Running pre-compilation analysis...

  [1/1] Analyzing hello... ✅ (score: 98/100)

✅ All functions passed verification (min score: 80)

Compiling...
```

### Example 3: Embedded Template

```julia
using StaticCompiler
using StaticTools

function sensor_read()
    println(c"Sensor: OK")
    return 0
end

compile_executable(sensor_read, (), "./", "sensor", template=:embedded)
```

**Expected Output:**
```
Using template: :embedded
  Embedded/IoT systems: minimal size, no stdlib

Running pre-compilation analysis...

  [1/1] Analyzing sensor_read... ✅ (score: 100/100)

✅ All functions passed verification (min score: 90)

Compiling...
Generated C header: ./sensor.h
```

## Quick Smoke Test

If you want a quick test to verify basic functionality:

```julia
using StaticCompiler
using StaticTools

# Simple function
function test(x::Int)
    return x * 2
end

# Test 1: Basic compilation
compile_shlib(test, (Int,), tempdir(), "test_basic")
println("✅ Basic compilation works")

# Test 2: With verification
compile_shlib(test, (Int,), tempdir(), "test_verify", verify=true)
println("✅ Verification works")

# Test 3: With template
compile_shlib(test, (Int,), tempdir(), "test_template", template=:production)
println("✅ Template works")

# Test 4: Executable with template
compile_executable(test, (Int,), tempdir(), "test_exe", template=:embedded)
println("✅ Executable template works")

println("\n✅ All smoke tests passed!")
```

## Continuous Integration

If setting up CI, use the provided workflow templates:

```bash
# The repository includes disabled CI workflows
ls .github/workflows/*.yml.disabled

# To enable:
for f in .github/workflows/*.yml.disabled; do
    mv "$f" "${f%.disabled}"
done

git add .github/workflows/
git commit -m "Enable CI workflows"
git push
```

## Troubleshooting

### Julia Not Found
```bash
# Install Julia
wget https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.0-linux-x86_64.tar.gz
tar xzf julia-1.10.0-linux-x86_64.tar.gz
export PATH="$PWD/julia-1.10.0/bin:$PATH"
```

### Dependencies Not Installing
```bash
# Clear and reinstall
rm -rf ~/.julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Tests Failing
```bash
# Run with verbose output
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["--verbose"])'

# Run single test file
julia --project=. test/testcore.jl
```

## Success Criteria

All bug fixes are verified if:

1. ✅ Full test suite passes
2. ✅ Module loading works in bin/analyze
3. ✅ API calls work in bin/analyze-code
4. ✅ Template overrides work correctly
5. ✅ Templates work for compile_executable
6. ✅ Batch compilation handles JSON types correctly
7. ✅ Blog post examples run successfully

## Reporting Results

After running tests, report back with:

```
Test Results Summary:
- Full test suite: PASS/FAIL
- Module loading: PASS/FAIL
- API function calls: PASS/FAIL
- Template overrides: PASS/FAIL
- Executable templates: PASS/FAIL
- Type coercion: PASS/FAIL
- Blog examples: PASS/FAIL

Any errors:
[Paste error messages here]
```

---

**Note:** Julia is not available in the current Claude Code environment. These tests must be run in an environment with Julia 1.10+ installed.
