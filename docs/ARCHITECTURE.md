# StaticCompiler.jl Architecture

This document describes the internal architecture and design decisions of StaticCompiler.jl.

## Overview

StaticCompiler.jl transforms Julia functions into standalone executables through a multi-stage compilation pipeline:

```
Julia Function → Type Analysis → LLVM IR → Native Code → Executable
                      ↓               ↓           ↓
                  Optimization   Optimization  Linking
```

## Core Components

### 1. Compilation Pipeline

**Entry Points:**
- `compile_executable()` - Main entry point for executable compilation
- `compile_shlib()` - Shared library compilation
- `compile_executable_optimized()` - Compilation with optimization profiles

**Pipeline Stages:**
1. **Type Specialization** - Generate type-specific code
2. **LLVM IR Generation** - Convert Julia IR to LLVM IR
3. **Optimization** - Apply LLVM optimization passes
4. **Code Generation** - Generate native assembly
5. **Linking** - Create final executable

### 2. Optimization System

**Components:**
- `optimization.jl` - Optimization profiles and flags
- `presets.jl` - Predefined optimization configurations
- `smart_optimize.jl` - Automatic optimization selection
- `pgo.jl` - Profile-guided optimization

**Optimization Profiles:**
```
PROFILE_DEBUG      → -O0 (no optimization)
PROFILE_SIZE       → -Oz (size)
PROFILE_SPEED      → -O2 (balanced)
PROFILE_AGGRESSIVE → -O3 (maximum speed)
PROFILE_SIZE_LTO   → -Oz + LTO (minimum size)
PROFILE_SPEED_LTO  → -O3 + LTO (maximum speed)
```

**Preset System:**
```
Preset → BuildConfig → OptimizationProfile → Compiler Flags
   ↓         ↓              ↓                      ↓
 UPX      Wizard      get_profile_by_symbol   compile_executable
```

### 3. Analysis Framework

**Static Analysis:**
- `checker.jl` - Compilability checking
- `advanced_analysis.jl` - Allocation, inlining, bloat analysis
- `simd_analysis.jl` - SIMD opportunity detection
- `security_analysis.jl` - Security issue detection
- `dependency_analysis.jl` - Dependency bloat analysis

**Dynamic Analysis:**
- `benchmarking.jl` - Runtime performance measurement
- `pgo.jl` - Profile collection and optimization

**Reporting:**
- `comprehensive_report.jl` - Unified analysis results
- `recommendations.jl` - Optimization suggestions

### 4. Cross-Compilation

**Target Specification:**
```
CrossTarget:
  - Architecture (x86_64, aarch64, riscv64, wasm32)
  - OS (linux, darwin, windows, wasm, none)
  - C library (glibc, musl, none)
  - LLVM triple
  - CPU model
  - Feature flags
```

**Integration:**
```
CrossTarget → StaticTarget → compile_executable
     ↓              ↓              ↓
   Preset    Optimization     Cross-compile
```

### 5. Caching System

**Two-Level Cache:**

1. **Compilation Cache** (`cache.jl`)
   - LLVM IR caching
   - Object code caching
   - SHA-based invalidation

2. **Result Cache** (`result_cache.jl`)
   - Benchmark results
   - PGO profiles
   - Time-based expiration

### 6. Parallel Processing

**Parallelization Points:**
- Preset comparison (`parallel_compare_presets`)
- Profile benchmarking (`parallel_benchmark_profiles`)
- Multi-target cross-compilation

**Implementation:**
```
Tasks → Batching → Concurrent Execution → Result Aggregation
  ↓        ↓              ↓                     ↓
Queue  Max Limit    @task schedule          fetch()
```

### 7. Error Handling

**Exception Hierarchy:**
```
CompilationError (abstract)
  ├─ CompilationFailure
  ├─ BenchmarkError
  └─ PGOError
```

**Safety Mechanisms:**
- `with_cleanup()` - Guaranteed cleanup
- `safe_compile()` - Automatic error recovery
- `retry_on_failure()` - Transient failure handling
- `validate_compilation_result()` - Result verification

### 8. Logging System

**Log Flow:**
```
log_info() → format_log_message() → write_log() → {stdout, file}
                    ↓
              LogConfig (level, format, destination)
```

**Structured Logging:**
- Plain text format (human-readable)
- JSON format (machine-parseable)
- Context dictionaries
- Log rotation

### 9. Interactive TUI

**Menu System:**
```
Main Menu → Sub-Menu → Action → Result Display → Return
    ↓          ↓         ↓            ↓             ↓
  Choice   Validation Execute    Format Output  Continue
```

**Integration:**
- Uses all core APIs
- Provides guided workflows
- Real-time feedback

## Data Flow

### Compilation Data Flow

```
Function + Types
       ↓
CompilabilityReport (check_compilable)
       ↓
ComprehensiveReport (analyze)
       ↓
OptimizationRecommendations
       ↓
Preset Selection (smart_optimize or manual)
       ↓
BuildConfig + OptimizationProfile
       ↓
Compiler Flags (get_optimization_flags)
       ↓
compile_executable(cflags=...)
       ↓
Binary File
       ↓
Post-processing (UPX, strip)
       ↓
Final Binary
```

### PGO Data Flow

```
Initial Compilation (PROFILE_DEBUG)
       ↓
Benchmark + Profile Collection
       ↓
Analysis + Recommendations
       ↓
Recompile (recommended profile)
       ↓
Benchmark + Compare
       ↓
Iterate until convergence
       ↓
Best Result
```

### Cross-Compilation Data Flow

```
CrossTarget Selection
       ↓
StaticTarget Creation (triple, cpu, features)
       ↓
Preset + Optimization Flags
       ↓
Cross-Compiler Invocation (cflags + target)
       ↓
Target Binary
       ↓
Validation (size, format)
       ↓
Result
```

## Design Patterns

### 1. Builder Pattern

**BuildConfig:**
```julia
config = BuildConfig(
    optimization_flags=["-O3", "-march=native"],
    strip_binary=true,
    use_lto=true,
    upx_level=9
)
```

### 2. Strategy Pattern

**Optimization Profiles:**
```julia
profiles = [PROFILE_SIZE, PROFILE_SPEED, PROFILE_AGGRESSIVE]
for profile in profiles
    flags = get_optimization_flags(profile)
    compile_with_flags(flags)
end
```

### 3. Template Method

**Preset Compilation:**
```julia
function compile_with_preset(f, types, path, name, preset)
    # Template: analysis → compile → optimize → post-process
    analyze()
    compile()
    optimize()
    post_process()
end
```

### 4. Observer Pattern

**Logging:**
```julia
log_section("Compilation") do
    # Automatically logs start/end/timing
    compile(...)
end
```

### 5. Factory Pattern

**Target Creation:**
```julia
target = get_cross_target(:arm64_linux)  # Factory creates CrossTarget
```

## Module Organization

```
StaticCompiler.jl
├── Core Compilation
│   ├── interpreter.jl
│   ├── target.jl
│   ├── static_compiler.jl
│   └── cache.jl
├── Analysis
│   ├── checker.jl
│   ├── advanced_analysis.jl
│   ├── simd_analysis.jl
│   ├── security_analysis.jl
│   ├── dependency_analysis.jl
│   └── comprehensive_report.jl
├── Optimization
│   ├── optimization.jl (profiles)
│   ├── presets.jl (configurations)
│   ├── smart_optimize.jl (auto-selection)
│   ├── pgo.jl (profile-guided)
│   └── recommendations.jl
├── Benchmarking
│   ├── benchmark.jl (legacy)
│   └── benchmarking.jl (new system)
├── Cross-Compilation
│   └── cross_compile.jl
├── Infrastructure
│   ├── constants.jl
│   ├── logging.jl
│   ├── error_handling.jl
│   ├── json_utils.jl
│   ├── result_cache.jl
│   └── parallel.jl
├── User Interface
│   ├── interactive_tui.jl
│   ├── optimization_wizard.jl
│   └── ci_integration.jl
└── Utilities
    ├── binary_size.jl
    ├── bundler.jl
    ├── build_config.jl
    └── memory_layout.jl
```

## Key Design Decisions

### 1. No External Dependencies for Core Features

**Rationale:** Minimize compilation footprint and dependencies

**Implementation:**
- Custom JSON parser/serializer
- No external benchmark library
- Built-in logging system

### 2. Separation of Analysis and Compilation

**Rationale:** Enable analysis without compilation overhead

**Implementation:**
```julia
# Analysis phase (fast)
report = generate_comprehensive_report(f, types, compile=false)

# Compilation phase (slow)
binary = compile_with_preset(f, types, ...)
```

### 3. Preset-Based Configuration

**Rationale:** Simplify common use cases, expert mode available

**Implementation:**
- Presets for common scenarios
- Manual configuration for experts
- Smart auto-selection

### 4. Caching at Multiple Levels

**Rationale:** Avoid redundant work

**Layers:**
- LLVM IR cache (compilation results)
- Result cache (benchmark/PGO)
- Preset cache (configuration)

### 5. Parallel-by-Default for Comparisons

**Rationale:** Multi-core utilization for faster workflows

**Implementation:**
- Auto-detect optimal concurrency
- Batch processing to avoid saturation
- Fallback to sequential if needed

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Typical Time |
|-----------|------------|--------------|
| Type checking | O(n) | <1s |
| Analysis | O(n) | 1-5s |
| Compilation | O(n²) | 10-60s |
| PGO | O(k·n²) | 30-180s |
| Benchmarking | O(m) | 1-10s |

*n = code size, k = iterations, m = samples*

### Space Complexity

| Component | Memory Usage | Disk Usage |
|-----------|--------------|------------|
| Compilation | 100-500 MB | 10-50 MB |
| Caching | 50-200 MB | 100-1000 MB |
| Analysis | 10-50 MB | 1-10 MB |

### Scalability

- **Compilation:** Linear with code size
- **Parallel preset comparison:** Near-linear with CPU cores
- **Caching:** Constant-time lookup, linear storage

## Extension Points

### Adding New Optimization Profiles

```julia
const PROFILE_CUSTOM = OptimizationProfile(
    "Custom",
    ["-O3", "-march=native", "-custom-flag"],
    :custom
)
```

### Adding New Presets

```julia
const PRESET_CUSTOM = OptimizationPreset(
    :custom,
    "Custom configuration",
    :PROFILE_SPEED,
    BuildConfig(...),
    # ... other fields
)
```

### Adding New Cross-Targets

```julia
const CROSS_TARGET_CUSTOM = CrossTarget(
    :my_target,
    "arch",
    "os",
    "libc",
    "triple",
    "cpu",
    "features",
    ["flags"],
    "description"
)
```

### Custom Analysis

```julia
function custom_analysis(f, types)
    # Your analysis logic
    return custom_report
end

# Integrate with comprehensive report
report = generate_comprehensive_report(f, types)
custom = custom_analysis(f, types)
```

## Testing Strategy

### Unit Tests

- Individual function testing
- Mock compilation results
- Edge case coverage

### Integration Tests

- End-to-end compilation
- Preset workflows
- Cross-compilation

### Validation Tests

- Binary size verification
- Optimization flag application
- Performance measurement

## Future Architecture

Planned improvements:

1. **Plugin System** - Extensible optimization passes
2. **Distributed Compilation** - Network-based compilation
3. **Advanced Caching** - Content-addressable storage
4. **WASM Backend** - Pure WebAssembly output
5. **GPU Support** - CUDA/ROCm code generation

## Contributing

When adding new features:

1. Follow existing patterns
2. Add comprehensive tests
3. Update documentation
4. Consider performance impact
5. Maintain backward compatibility
