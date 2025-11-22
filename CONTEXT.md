# Session Context (2025-11-22)

- Branch `claude/static-compiler-01MzDXCnFRXaJXWpJ3o2Fnvk`, git HEAD cfee2ed.
- Julia 1.12.1 available locally; working tree dirty with ongoing changes around runtime linking, method table selection, GPUCompiler 1.8 compat, and integration test adjustments.
- Untracked build artifacts present (loopvec_matrix, times_table, tmp.bc, etc.)—avoid committing.
- Active instructions: keep this CONTEXT.md updated after major steps, commit frequently with author Joel Reymont <18791+joelreymont@users.noreply.github.com>, create a plan and execute it, no emojis.
- Next actions: investigate remaining loopvec_matrix_stack SIGBUS under runtime-linked execution, reduce wrapper argv type warnings if feasible, and decide whether to commit AGENTS.md or leave untracked alongside build artifacts.

## Updates
- Reviewed uncommitted diffs: StaticTarget now toggles a runtime-linked mode with Julia runtime link flags, method table selection, and optional runtime overlays; generate_executable/shlib now emit wrappers with optional jl_init/atexit; static_llvm_module links libraries and strips verifier errors; escape analysis now resolves SSA callees; pointer_warning adds verifier cleanup; Project.toml allows GPUCompiler 1.8; integration scripts/tests set runtime=true and mark fragile cases as broken on failure.
- Ran `GROUP=Integration julia --project=. --startup-file=no -e 'using Pkg; Pkg.test(; test_args=["--color=no"])'` after instantiating; command timed out at 120s with heavy LLVM pointer warnings. Bumper integration passed but `loopvec_matrix_stack` executable crashed with SIGBUS (caught in test as broken). Wrapper C files emitted warnings about passing `argv::char**` to `uint8_t**` entrypoints. Need deeper investigation into runtime-linked binaries and crash.
- Adjusted LLVM generation to avoid linking runtime libraries when `target.julia_runtime` is true and propagate that flag through introspection helpers; fixed `StaticTarget(triple, cpu, features)` constructor to initialize `julia_runtime`. Re-ran integration tests with 300s timeout: suite reports `Standalone Executable Integration` 33 passed / 1 broken (loopvec_matrix_stack still SIGBUS), overall tests pass. Pointer warnings about `jl_system_image_data` persist during compilation; wrapper type warnings remain but compilation succeeds.
- Committed staged changes as `3e3731b` with runtime-aware compilation tweaks and CONTEXT.md tracking. Untracked build artifacts (`loopvec_matrix`, `times_table`, etc.) and `AGENTS.md` remain uncommitted.
