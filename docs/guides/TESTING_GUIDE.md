# Testing Guide - StaticCompiler.jl

**Version:** 2.0
**Date:** 2025-11-17
**Status:** Complete

---

## Overview

This guide covers all aspects of testing StaticCompiler.jl, including running tests, interpreting results, and contributing new tests.

---

## Quick Start

### Run All Tests
```bash
# From project root
julia --project=. -e 'using Pkg; Pkg.test()'
```

### Run Specific Test Groups
```bash
# Core tests only
ENV["GROUP"]="Core" julia --project=. -e 'using Pkg; Pkg.test()'

# Integration tests only
ENV["GROUP"]="Integration" julia --project=. -e 'using Pkg; Pkg.test()'

# Optimization tests only
ENV["GROUP"]="Optimizations" julia --project=. -e 'using Pkg; Pkg.test()'
```

### Run Individual Test Files
```bash
julia --project=. test/test_advanced_optimizations.jl
julia --project=. test/test_optimization_edge_cases.jl
julia --project=. test/test_correctness_verification.jl
julia --project=. test/test_optimization_benchmarks.jl
```

### Run Real-World Scenarios
```bash
julia --project=. test/scenarios/embedded_system.jl
julia --project=. test/scenarios/scientific_computing.jl
julia --project=. test/scenarios/web_service.jl
```

---

## Test Structure

### Test Organization

```
test/
├── runtests.jl                          # Main test runner
├── testcore.jl                          # Core functionality tests
├── testintegration.jl                   # Integration tests
│
├── test_advanced_optimizations.jl       # Basic optimization tests (27 tests)
├── test_optimization_edge_cases.jl      # Edge case tests (45 tests)
├── test_correctness_verification.jl     # Correctness tests (30 tests)
├── test_optimization_benchmarks.jl      # Performance benchmarks (20 tests)
├── test_coverage_report.jl              # Coverage tracking
│
└── scenarios/                           # Real-world scenarios
    ├── embedded_system.jl               # Embedded systems scenario
    ├── scientific_computing.jl          # Scientific computing scenario
    └── web_service.jl                   # Web service scenario
```

### Test Categories

| Category | Tests | Purpose |
|----------|-------|---------|
| **Core** | 31 | Basic compilation functionality |
| **Integration** | Variable | End-to-end integration tests |
| **Optimizations** | 27 | Basic optimization functionality |
| **Edge Cases** | 45 | Complex scenarios and corner cases |
| **Correctness** | 30 | Semantic preservation verification |
| **Benchmarks** | 20 | Performance impact measurements |
| **Scenarios** | 3 | Real-world use cases |

**Total:** 172+ tests

---

## Running Tests

### Prerequisites

1. **Julia Installation**
   ```bash
   # Verify Julia is installed
   julia --version
   # Should show 1.10 or later
   ```

2. **Install Dependencies**
   ```bash
   cd /path/to/staticcompiler.jl
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

3. **System Requirements**
   - **Linux:** GCC or Clang compiler
   - **macOS:** Xcode command line tools
   - **Windows:** Visual Studio Build Tools or MinGW

### Basic Test Execution

#### All Tests
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

**Expected Output:**
```
Test Summary:                    | Pass  Total
Core Tests                       |   31     31
Integration Tests                |   14     14
Advanced Optimizations           |   27     27
Edge Case Tests                  |   45     45
Correctness Verification         |   30     30
Optimization Benchmarks          |   20     20
─────────────────────────────────────────────
TOTAL                            |  167    167

✅ All tests passed!
```

#### Specific Test Groups

**Core Tests Only** (fastest, ~30s)
```bash
ENV["GROUP"]="Core" julia --project=. -e 'using Pkg; Pkg.test()'
```

**Optimization Tests** (comprehensive, ~2-3 min)
```bash
ENV["GROUP"]="Optimizations" julia --project=. -e 'using Pkg; Pkg.test()'
```

### Advanced Test Execution

#### With Coverage
```bash
julia --project=. --code-coverage=user -e 'using Pkg; Pkg.test()'

# Process coverage
julia --project=. -e '
    using Coverage
    coverage = process_folder()
    LCOV.writefile("coverage.info", coverage)
'
```

#### With Verbose Output
```bash
julia --project=. -e 'using Pkg; Pkg.test(verbose=true)'
```

#### Parallel Testing
```bash
julia --project=. -p 4 -e 'using Pkg; Pkg.test()'
```

---

## Running Benchmarks

### Performance Benchmarks

#### Run All Benchmarks
```bash
julia --project=. test/test_optimization_benchmarks.jl
```

**Expected Output:**
```
======================================================================
OPTIMIZATION IMPACT BENCHMARKS
======================================================================

📊 Benchmarking: Escape Analysis
   Compiling unoptimized version...
   Compiling optimized version...
   Binary sizes:
      Unoptimized: 15700 bytes
      Optimized:   14200 bytes
      Reduction:   9.6%
   ✅ Optimization impact verified

[... more benchmarks ...]

======================================================================
All optimization impacts validated! 🎉
======================================================================
```

#### Establish Baseline
```bash
julia --project=. benchmarks/establish_baseline.jl
```

This creates `benchmarks/baseline/baseline.json` for regression detection.

#### Compare with Baseline
```julia
julia> include("benchmarks/establish_baseline.jl")
julia> # Run your benchmarks
julia> compare_with_baseline(results)
```

---

## Running Real-World Scenarios

### Embedded System Scenario
```bash
julia --project=. test/scenarios/embedded_system.jl
```

**Tests:**
- Temperature sensor data processing
- PWM signal generation
- Circular buffer management
- Binary size validation

**Expected:** All tests pass, demonstrates memory-constrained optimization

### Scientific Computing Scenario
```bash
julia --project=. test/scenarios/scientific_computing.jl
```

**Tests:**
- Matrix-vector operations
- Numerical integration
- Particle dynamics simulation
- Iterative solvers
- FFT operations
- Loop optimization

**Expected:** All tests pass, demonstrates high-performance computing

### Web Service Scenario
```bash
julia --project=. test/scenarios/web_service.jl
```

**Tests:**
- Request parsing
- Response formatting
- Rate limiting
- Cache key generation
- Input validation
- Request routing
- Connection pooling
- Error handling

**Expected:** All tests pass, demonstrates low-latency optimization

---

## Interpreting Test Results

### Successful Test Run

```
Test Summary:                    | Pass  Total
Edge Case Tests                  |   45     45

✅ All edge case tests completed successfully!
```

**Interpretation:** All tests passed, no issues found.

### Failed Test

```
Test Summary:                    | Pass  Fail  Total
Edge Case Tests                  |   44      1     45

❌ Test failed: Complex nested allocations
   Expected: 2 allocations
   Got: 3 allocations
```

**Action:**
1. Review the failing test
2. Check if it's an expected change
3. Update test if behavior changed intentionally
4. Fix code if it's a regression

### Performance Regression

```
⚠️  REGRESSIONS DETECTED:
  ❌ escape_analysis / allocation_elimination / binary_size_reduction_pct: 15.2% slower
```

**Action:**
1. Investigate recent changes
2. Profile the affected code
3. Optimize or revert changes
4. Update baseline if intentional

---

## Test Coverage Report

### Generate Coverage Report
```bash
julia --project=. test/test_coverage_report.jl
```

**Output:**
```
================================================================================
TEST COVERAGE REPORT
================================================================================

📊 OPTIMIZATION TEST COVERAGE
--------------------------------------------------------------------------------
  ✅ Escape Analysis: 15 tests
     - Basic functionality tests
     - Edge case tests
     - Correctness verification tests
     - Performance benchmarks

  ✅ Monomorphization: 16 tests
     - [... details ...]

[... more categories ...]

📈 COVERAGE SUMMARY
--------------------------------------------------------------------------------
  Overall coverage: 95.0%

  ✅ EXCELLENT: Comprehensive test coverage
```

---

## Adding New Tests

### Test File Template

```julia
# tests/test_my_feature.jl
using Test
using StaticCompiler
using StaticTools

@testset "My Feature" begin
    @testset "Basic functionality" begin
        # Test basic behavior
        function my_func(x::Int)
            return x * 2
        end

        report = analyze_my_feature(my_func, (Int,))
        @test !isnothing(report)
        @test report.some_metric > 0

        println("  ✓ Basic functionality verified")
    end

    @testset "Edge cases" begin
        # Test edge cases
        @test !isnothing(analyze_my_feature(identity, (Int,)))

        println("  ✓ Edge cases handled")
    end

    @testset "Correctness" begin
        # Verify correctness
        @test verify_my_feature_correctness(my_func, (Int,))

        println("  ✓ Correctness verified")
    end
end
```

### Adding to Test Suite

1. **Create test file** in `test/` directory
2. **Add to runtests.jl**:
   ```julia
   if GROUP == "MyGroup" || GROUP == "All"
       include("test_my_feature.jl")
   end
   ```
3. **Run tests** to verify
4. **Update coverage** tracking

---

## Troubleshooting

### Common Issues

#### 1. Tests Won't Run

**Problem:** `ERROR: LoadError: UndefVarError: analyze_escapes not defined`

**Solution:**
```bash
# Reinstall dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

#### 2. Compilation Fails

**Problem:** `ERROR: could not compile function`

**Solution:**
- Ensure C compiler is installed
- Check `gcc --version` or `clang --version`
- On Windows, install Visual Studio Build Tools

#### 3. Tests Timeout

**Problem:** Tests run for >10 minutes

**Solution:**
```bash
# Run specific test group instead
ENV["GROUP"]="Core" julia --project=. -e 'using Pkg; Pkg.test()'
```

#### 4. Memory Issues

**Problem:** `ERROR: Out of memory`

**Solution:**
```bash
# Reduce parallel workers
julia --project=. -p 1 -e 'using Pkg; Pkg.test()'
```

#### 5. Platform-Specific Failures

**Problem:** Tests pass on Linux but fail on Windows

**Solution:**
- Check platform-specific code paths
- Use `Sys.iswindows()`, `Sys.islinux()`, `Sys.isapple()`
- Review test assumptions

### Getting Help

1. **Check existing issues:** https://github.com/tshort/StaticCompiler.jl/issues
2. **Open new issue** with:
   - Julia version
   - OS and version
   - Test output
   - Minimal reproducible example
3. **Community:** Julia Slack #static-compilation channel

---

## Best Practices

### Writing Tests

1. **Clear test names**
   ```julia
   @testset "Escape analysis correctly identifies escaped allocations" begin
       # ...
   end
   ```

2. **Test one thing**
   - Each test should verify a single behavior
   - Multiple assertions OK if testing same property

3. **Include documentation**
   ```julia
   # Test that stack promotion preserves semantics
   # This verifies that moving heap allocations to stack
   # doesn't change the function's output
   @test original_func(10) == optimized_func(10)
   ```

4. **Use descriptive variables**
   ```julia
   # Good
   report = analyze_escapes(my_func, (Int,))

   # Bad
   r = ae(f, (I,))
   ```

### Running Tests Regularly

1. **Before committing:**
   ```bash
   ENV["GROUP"]="Core" julia --project=. -e 'using Pkg; Pkg.test()'
   ```

2. **Before pushing:**
   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

3. **Weekly:**
   ```bash
   julia --project=. test/test_optimization_benchmarks.jl
   ```

---

## CI/CD Integration

### GitHub Actions

Tests run automatically on:
- Every push to main/master/develop
- Every pull request
- Weekly benchmark runs

**View results:** Check "Actions" tab in GitHub

### Local CI Simulation

```bash
# Run the same tests as CI
docker run -v $(pwd):/work julia:1.10 \
    julia --project=/work -e 'using Pkg; Pkg.test()'
```

---

## Performance Testing

### Benchmark Execution Times

| Test Suite | Expected Time |
|------------|---------------|
| Core | ~30 seconds |
| Integration | ~1-2 minutes |
| Optimizations (basic) | ~30 seconds |
| Edge Cases | ~1 minute |
| Correctness | ~1 minute |
| Benchmarks | ~2-3 minutes |
| Scenarios | ~30 seconds each |

**Total (all tests):** ~10-15 minutes

### Optimization

- Run core tests frequently (fastest feedback)
- Run full suite before pushing
- Run benchmarks weekly or on performance changes

---

## Summary

### Quick Reference

```bash
# Install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run specific group
ENV["GROUP"]="Optimizations" julia --project=. -e 'using Pkg; Pkg.test()'

# Run benchmarks
julia --project=. test/test_optimization_benchmarks.jl

# Establish baseline
julia --project=. benchmarks/establish_baseline.jl

# Generate coverage
julia --project=. test/test_coverage_report.jl
```

### Test Statistics

- **Total tests:** 172+
- **Coverage:** 95%
- **All optimizations:** Thoroughly tested
- **Real-world scenarios:** 3 complete examples
- **CI/CD:** Fully integrated

---

**For more information:**
- [Benchmarking Guide](BENCHMARKING_GUIDE.md)
- [CI/CD Integration Guide](CI_CD_INTEGRATION.md)
- [Contributing Guide](../../CONTRIBUTING.md)

**Status:** ✅ Production-Ready Testing Infrastructure
