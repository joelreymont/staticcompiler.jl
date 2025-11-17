# Benchmarking Guide - StaticCompiler.jl

**Version:** 2.0
**Date:** 2025-11-17
**Status:** Complete

---

## Overview

This guide covers performance benchmarking for StaticCompiler.jl optimizations, including running benchmarks, interpreting results, establishing baselines, and detecting regressions.

---

## Quick Start

###Run All Benchmarks
```bash
julia --project=. test/test_optimization_benchmarks.jl
```

### Establish Baseline
```bash
julia --project=. benchmarks/establish_baseline.jl
```

### Compare with Baseline
```julia
julia> include("benchmarks/establish_baseline.jl")
julia> results = run_benchmarks()  # Your benchmark data
julia> compare_with_baseline(results)
```

---

## Benchmark Structure

### Benchmark Categories

1. **Escape Analysis Impact**
   - Allocation elimination measurement
   - Nested allocation optimization
   - Memory savings estimation

2. **Monomorphization Impact**
   - Abstract type overhead measurement
   - Type specialization benefits

3. **Devirtualization Impact**
   - Virtual call elimination
   - Method dispatch optimization

4. **Constant Propagation Impact**
   - Dead code elimination
   - Constant folding benefits

5. **Lifetime Analysis Impact**
   - Auto-free detection
   - Memory leak identification

6. **Combined Optimizations**
   - Real-world data processing
   - Multiple optimization interactions

---

## Running Benchmarks

### All Benchmarks

```bash
julia --project=. test/test_optimization_benchmarks.jl
```

**Output:**
```
======================================================================
OPTIMIZATION IMPACT BENCHMARKS
======================================================================

📊 Benchmarking: Escape Analysis - Allocation Optimization
   Unoptimized analysis:
      Allocations found: 2
      Stack-promotable: 0

   Optimized analysis:
      Allocations found: 1
      Stack-promotable: 1

   ✅ Escape analysis impact verified

[... more benchmarks ...]

✅ All optimization impacts validated! 🎉
```

### Individual Optimization Benchmarks

```julia
# In Julia REPL
julia> include("test/test_optimization_benchmarks.jl")

# Run specific benchmark category
# (Benchmarks run automatically when file is included)
```

---

## Establishing Baselines

### Why Baselines Matter

Baselines provide reference measurements for:
- Detecting performance regressions
- Tracking improvements over time
- Validating optimization claims
- CI/CD integration

### Create Baseline

```bash
julia --project=. benchmarks/establish_baseline.jl
```

**Output:**
```
======================================================================
ESTABLISHING BASELINE BENCHMARKS
======================================================================

📊 Running baseline benchmarks...

✅ Baseline established: benchmarks/baseline/baseline.json

Baseline Summary:
  Julia version: 1.10.10
  System: Linux x86_64
  CPU: Intel Core i7
  Timestamp: 2025-11-17T10:30:00
```

### Baseline Structure

```json
{
  "timestamp": "2025-11-17T10:30:00",
  "julia_version": "1.10.10",
  "system": {
    "os": "Linux",
    "arch": "x86_64",
    "cpu": "Intel Core i7",
    "threads": 8
  },
  "benchmarks": {
    "escape_analysis": {
      "allocation_elimination": {
        "binary_size_reduction_pct": 9.6,
        "execution_time_ns": 1250000,
        "memory_saved_bytes": 1024
      }
    }
  }
}
```

---

## Regression Detection

### Comparing with Baseline

```julia
julia> include("benchmarks/establish_baseline.jl")

julia> # Your benchmark results
julia> current_results = Dict(
    "escape_analysis" => Dict(
        "allocation_elimination" => Dict(
            "binary_size_reduction_pct" => 8.5  # Regression!
        )
    )
)

julia> compare_with_baseline(current_results)
```

**Output:**
```
======================================================================
REGRESSION ANALYSIS
======================================================================

⚠️  REGRESSIONS DETECTED:
  ❌ escape_analysis / allocation_elimination / binary_size_reduction_pct: 11.5% worse

✅ IMPROVEMENTS:
  ✓ None

======================================================================
```

### Regression Thresholds

**Default:** 5% change triggers alert

**Customize:**
```julia
# In your code
const REGRESSION_THRESHOLD = 10.0  # 10% threshold

if pct_change > REGRESSION_THRESHOLD
    @warn "Regression detected"
end
```

---

## Benchmark Metrics

### What We Measure

| Metric | Description | Unit |
|--------|-------------|------|
| **Binary Size** | Compiled executable size | Bytes |
| **Size Reduction** | Percentage decrease | % |
| **Execution Time** | Runtime performance | Nanoseconds |
| **Memory Usage** | Heap allocations | Bytes |
| **Allocation Count** | Number of allocations | Count |
| **Code Size** | IR/LLVM code size | Lines/Bytes |

### Example Measurements

```julia
# Escape Analysis
- Stack-promotable allocations: 15
- Memory savings estimate: 2048 bytes
- Binary size reduction: 9.6%

# Monomorphization
- Abstract types eliminated: 3
- Type specializations: 5
- Compilation success: true

# Devirtualization
- Virtual calls found: 12
- Devirtualizable calls: 8
- Direct call conversion: 66.7%
```

---

## Historical Tracking

### Save Historical Data

```julia
julia> include("benchmarks/establish_baseline.jl")

julia> results = run_your_benchmarks()
julia> save_historical_data(results)
```

**Output:**
```
📝 Historical data saved: benchmarks/history/2025-11-17_10-30-00.json
```

### Analyze Trends

```bash
# List historical benchmarks
ls -lh benchmarks/history/

# Compare two runs
julia> h1 = JSON.parsefile("benchmarks/history/2025-11-17_10-00-00.json")
julia> h2 = JSON.parsefile("benchmarks/history/2025-11-17_11-00-00.json")
julia> compare_runs(h1, h2)
```

---

## Benchmark Best Practices

### 1. Consistent Environment

```bash
# Same Julia version
julia --version

# Same optimization flags
export JULIA_NUM_THREADS=1  # Consistent threading

# Minimal background processes
# Close unnecessary applications
```

### 2. Warmup Runs

```julia
# Run once to warm up JIT
result = benchmark_function(func, args)

# Then run actual benchmark
result = benchmark_function(func, args)
```

### 3. Multiple Samples

```julia
# Take median of multiple runs
results = [benchmark_function(func, args) for _ in 1:10]
median_result = median(results)
```

### 4. Statistical Significance

```julia
using Statistics

times = [measure() for _ in 1:100]
mean_time = mean(times)
std_dev = std(times)
confidence_interval = 1.96 * std_dev / sqrt(length(times))

println("Mean: $mean_time ± $confidence_interval ns")
```

---

## CI/CD Integration

### Automated Benchmarking

Benchmarks run automatically on:
- **Main branch commits** - Full benchmark suite
- **Weekly schedule** - Comprehensive regression detection
- **Pull requests** (optional) - Performance validation

### GitHub Actions Workflow

```yaml
benchmarks:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: julia-actions/setup-julia@v1
    - name: Run benchmarks
      run: julia --project=. test/test_optimization_benchmarks.jl
    - name: Check regressions
      run: julia --project=. benchmarks/establish_baseline.jl
```

### Benchmark Results in PRs

GitHub Actions automatically comments on PRs with:
- Benchmark results
- Comparison with baseline
- Regression warnings
- Performance improvements

---

## Real-World Scenarios

### Embedded System Benchmarks

```bash
julia --project=. test/scenarios/embedded_system.jl
```

**Metrics:**
- Binary size (must be < 32KB)
- Allocation count (should be 0)
- Stack usage
- Real-time constraints

### Scientific Computing Benchmarks

```bash
julia --project=. test/scenarios/scientific_computing.jl
```

**Metrics:**
- Execution time
- Numerical accuracy
- Memory bandwidth
- Vectorization efficiency

### Web Service Benchmarks

```bash
julia --project=. test/scenarios/web_service.jl
```

**Metrics:**
- Request latency (p50, p99)
- Throughput (requests/second)
- Allocation rate
- GC pressure

---

## Interpreting Results

### Good Benchmark

```
✅ Escape Analysis Impact:
   - Allocation tracking verified
   - Stack promotion opportunities identified
   - Memory savings estimated: 2048 bytes
```

**Interpretation:** Optimization is working as expected

### Performance Regression

```
⚠️  escape_analysis / allocation_elimination: 15% slower
```

**Actions:**
1. Review recent changes
2. Profile the code
3. Identify bottleneck
4. Fix or revert
5. Re-benchmark

### Performance Improvement

```
✅ IMPROVEMENTS:
   ✓ constant_propagation / dead_code_elimination: 25% faster
```

**Actions:**
1. Document the improvement
2. Update baseline
3. Consider backporting to stable
4. Update documentation

---

## Troubleshooting

### Inconsistent Results

**Problem:** Benchmarks vary by >20% between runs

**Solutions:**
- Close background applications
- Disable CPU frequency scaling
- Use dedicated benchmark server
- Increase sample size

### Benchmarks Too Slow

**Problem:** Full benchmark suite takes >30 minutes

**Solutions:**
```bash
# Run subset of benchmarks
julia --project=. -e '
    include("test/test_optimization_benchmarks.jl")
    # Manually run only specific tests
'
```

### Memory Issues

**Problem:** Benchmarks run out of memory

**Solutions:**
- Run benchmarks sequentially
- Reduce sample size
- Use smaller test cases
- Monitor memory usage

---

## Advanced Benchmarking

### Custom Benchmarks

```julia
using BenchmarkTools  # Optional, for more accurate timing

function my_benchmark()
    # Your code to benchmark
    result = analyze_escapes(my_func, (Int,))

    return result
end

# Measure
@time result = my_benchmark()

# Or with BenchmarkTools
@benchmark my_benchmark()
```

### Profiling

```julia
using Profile

# Profile your benchmark
@profile begin
    for _ in 1:1000
        my_benchmark()
    end
end

# View results
Profile.print()
```

### Comparative Benchmarks

```julia
# Compare two approaches
function approach_a()
    # Implementation A
end

function approach_b()
    # Implementation B
end

time_a = @elapsed for _ in 1:1000; approach_a(); end
time_b = @elapsed for _ in 1:1000; approach_b(); end

improvement = (time_a - time_b) / time_a * 100
println("Approach B is $(round(improvement, digits=1))% faster")
```

---

## Benchmark Reports

### Generate Report

```bash
julia --project=. test/test_optimization_benchmarks.jl > benchmarks/reports/latest.txt
```

### Report Format

```
======================================================================
BENCHMARK SUMMARY
======================================================================

✅ Escape Analysis Impact:
   - Allocation tracking verified
   - Stack promotion opportunities identified

✅ Monomorphization Impact:
   - Abstract type detection verified
   - Type specialization opportunities identified

[... more sections ...]

All optimization impacts validated! 🎉
======================================================================
```

---

## Summary

### Quick Reference

```bash
# Run all benchmarks
julia --project=. test/test_optimization_benchmarks.jl

# Establish baseline
julia --project=. benchmarks/establish_baseline.jl

# Run real-world scenarios
julia --project=. test/scenarios/embedded_system.jl
julia --project=. test/scenarios/scientific_computing.jl
julia --project=. test/scenarios/web_service.jl
```

### Key Metrics

- **Regression Threshold:** 5%
- **Benchmark Duration:** ~2-3 minutes
- **Baseline Location:** `benchmarks/baseline/baseline.json`
- **History Location:** `benchmarks/history/`
- **Reports Location:** `benchmarks/reports/`

### Best Practices

1. ✅ Establish baseline before making changes
2. ✅ Run benchmarks regularly (weekly)
3. ✅ Check for regressions before pushing
4. ✅ Document performance improvements
5. ✅ Use consistent environment
6. ✅ Track historical data

---

**For more information:**
- [Testing Guide](TESTING_GUIDE.md)
- [CI/CD Integration Guide](CI_CD_INTEGRATION.md)
- [Performance Optimization Guide](PERFORMANCE_GUIDE.md)

**Status:** ✅ Production-Ready Benchmarking Infrastructure
