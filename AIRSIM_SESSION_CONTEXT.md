# AirSim.jl Session Context

**Session ID**: claude/airsim-jl-continue-01LNQ18hGymRNpQnJ7K1Q6CG
**Date**: 2025-11-17
**Previous Branch**: claude/airsim-jl-continue-01QgfjcM94y4bfK9mULRWGGi (not found on remote)

## Project Overview

**StaticCompiler.jl** is an experimental package for compiling Julia code to standalone libraries without requiring a system image. It uses GPUCompiler.jl to generate native code.

### Key Features
- Compile Julia functions to native executables (`compile_executable`)
- Compile Julia functions to shared libraries (`compile_shlib`)
- Cross-compilation support via `generate_obj`
- Method overlays for substituting incompatible methods during compilation

### Main Limitations
- No GC-tracked allocations in compiled code
- No global variables in compiled code
- Must use native types (Int, Float64, Ptr) for function arguments/returns
- Type-stable code required
- Error handling requires explicit `@device_override` definitions

### Recommended Practices
- Use stack-allocated types: Tuples, NamedTuples, StaticArrays
- Manual memory management with malloc/free from StaticTools.jl
- Use MallocString and MallocArray instead of String and Array
- Pass complex objects by reference (Ptr) not by value

## AirSim.jl Integration Plan

**Goal**: Create Julia bindings for AirSim and compile them statically using StaticCompiler.jl

### Current Status
- Repository: StaticCompiler.jl (base functionality)
- Current branch: claude/airsim-jl-continue-01LNQ18hGymRNpQnJ7K1Q6CG
- UE Editor: Running and ready
- No AirSim-specific code exists yet in this repository

### Next Steps (Pending User Confirmation)
1. Understand the UE Editor setup and AirSim plugin status
2. Define the Julia bindings architecture for AirSim API
3. Create wrapper functions compatible with StaticCompiler constraints
4. Implement C interface layer between Julia and AirSim C++ API
5. Test compilation of basic AirSim operations

## Repository Structure
```
staticcompiler.jl/
├── src/           # Core StaticCompiler implementation
├── test/          # Test suite with example compilations
│   └── scripts/   # Example Julia programs for static compilation
├── docs/          # Documentation
└── Project.toml   # Julia package manifest
```

## Questions to Address
1. What AirSim functionality should be exposed to Julia?
2. Should we create a separate AirSim.jl package or integrate into StaticCompiler examples?
3. What is the current state of the UE project with AirSim plugin?
4. What are the primary use cases (drone control, computer vision, physics simulation)?

## Session Updates
- **2025-11-17 Initial**: Session started, documentation reviewed, context file created
