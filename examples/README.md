# StaticCompiler.jl Examples

This directory contains 19 comprehensive examples demonstrating all features of StaticCompiler.jl v1.0.0.

## Quick Start

### Run an Example

```bash
cd examples/basic
julia hello_world.jl
```

See the full examples guide at: https://github.com/tshort/StaticCompiler.jl/tree/master/examples

## Example Categories

- **basic/** - Simple getting-started examples (hello_world, fibonacci)
- **getting_started/** - Smart optimization introduction  
- **optimization/** - Optimization techniques (recommendations, size, config)
- **performance/** - Performance features (cache, benchmark, parallel)
- **advanced/** - Advanced workflows (PGO, wizard, reports, complete workflow)
- **analysis/** - Analysis tools (SIMD, security, memory layout)
- **presets/** - Preset system demonstrations
- **ci/** - CI/CD integration examples

## Learning Path

### Beginner
1. `basic/hello_world.jl` - Simplest executable
2. `basic/fibonacci.jl` - Shared library
3. `getting_started/smart_optimization.jl` - Auto-optimization

### Intermediate  
4. `optimization/automated_recommendations.jl` - AI suggestions
5. `performance/cache_demo.jl` - 77x speedup
6. `presets/presets_demo.jl` - Preset comparison

### Advanced
7. `advanced/pgo_demo.jl` - Profile-Guided Optimization
8. `advanced/wizard_demo.jl` - Interactive TUI
9. `advanced/complete_workflow_demo.jl` - Full production workflow

## Quick Reference

```julia
# Smart Optimization (Easiest!)
smart_optimize(my_func, (Int,), "dist", "my_func")

# Presets
compile_with_preset(my_func, (Int,), "dist", "my_func", :release)

# Profile-Guided Optimization
pgo_compile(my_func, (Int,), (100,), "dist", "my_func")

# Interactive TUI
interactive_optimize(my_func, (Int,), "dist", "my_func")

# Analysis
recommend_optimizations(my_func, (Int,))
generate_comprehensive_report(my_func, (Int,))
```

## Running All Examples

```bash
# Run all examples
find examples -name "*.jl" -exec julia {} \;
```

For detailed documentation on each example, see the individual source files.
