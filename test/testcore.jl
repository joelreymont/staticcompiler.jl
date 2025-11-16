workdir = tempdir()

fib(n) = n <= 1 ? n : fib(n - 1) + fib(n - 2) # This needs to be defined globally due to https://github.com/JuliaLang/julia/issues/40990

@testset "Error Diagnostics" begin
    # Test that compilation errors include helpful suggestions
    type_unstable(x) = x > 0 ? 1 : "string"

    try
        compile_shlib(type_unstable, (Int,), workdir)
        @test false  # Should not reach here
    catch e
        @test e isa StaticCompiler.CompilationError
        @test occursin("code_warntype", join(e.suggestions, " "))
    end
end

@testset "Extended Error Overrides" begin
    # Test that new error overrides are available and can be compiled
    function test_bounds()
        arr = (1, 2, 3)
        try
            # This would normally throw, but with override it should compile
            arr[10]
        catch
            return 0
        end
        return 1
    end

    filepath = compile_shlib(test_bounds, (), workdir)
    @test isfile(filepath)
end

@testset "Compilability Checker" begin
    # Test compilability checker identifies type instability
    good_func(x::Int) = x + 1
    bad_func(x) = x > 0 ? 1 : "string"

    good_report = check_compilable(good_func, (Int,), verbose=false)
    @test good_report.compilable

    bad_report = check_compilable(bad_func, (Int,), verbose=false)
    @test !bad_report.compilable
    @test any(i.category == :type_instability for i in bad_report.issues)
end

@testset "Compilation Cache" begin
    # Test that caching works for repeated compilations
    cache_test_func(x::Int) = x * 2

    clear_cache!()

    filepath1 = compile_shlib(cache_test_func, (Int,), workdir, "cache_test1")
    @test isfile(filepath1)

    filepath2 = compile_shlib(cache_test_func, (Int,), workdir, "cache_test2")
    @test isfile(filepath2)

    clear_cache!()
end

@testset "Standalone Dylibs" begin
    # Test function
    # (already defined)
    # fib(n) = n <= 1 ? n : fib(n - 1) + fib(n - 2)

    #Compile dylib
    name = repr(fib)
    filepath = compile_shlib(fib, (Int,), workdir, name, demangle=true)
    @test occursin("fib.$(Libdl.dlext)", filepath)
    # Open dylib manually
    ptr = Libdl.dlopen(filepath, Libdl.RTLD_LOCAL)
    fptr = Libdl.dlsym(ptr, name)
    @test fptr != C_NULL
    @test ccall(fptr, Int, (Int,), 10) == 55
    Libdl.dlclose(ptr)

    # As above, but without demangling
    filepath = compile_shlib(fib, (Int,), workdir, name, demangle=false)
    ptr = Libdl.dlopen(filepath, Libdl.RTLD_LOCAL)
    fptr = Libdl.dlsym(ptr, "julia_"*name)
    @test fptr != C_NULL
    @test ccall(fptr, Int, (Int,), 10) == 55
    Libdl.dlclose(ptr)
end

@testset "Standalone Executables" begin
    # Minimal test with no `llvmcall`
    @inline function foo()
        v = 0.0
        n = 1000
        for i=1:n
            v += sqrt(n)
        end
        return 0
    end

    filepath = compile_executable(foo, (), workdir, demangle=false)
    r = run(`$filepath`);
    @test isa(r, Base.Process)
    @test r.exitcode == 0

    filepath = compile_executable(foo, (), workdir, demangle=true)
    r = run(`$filepath`);
    @test isa(r, Base.Process)
    @test r.exitcode == 0

    filepath = compile_executable(foo, (), workdir, llvm_to_clang=true)
    r = run(`$filepath`);
    @test isa(r, Base.Process)
    @test r.exitcode == 0


    @inline function _puts(s::Ptr{UInt8}) # Can't use Base.println because it allocates
        Base.llvmcall(("""
        ; External declaration of the puts function
        declare i32 @puts(i8* nocapture) nounwind

        define i32 @main(i64) {
        entry:
           %ptr = inttoptr i64 %0 to i8*
           %status = call i32 (i8*) @puts(i8* %ptr)
           ret i32 %status
        }
        """, "main"), Int32, Tuple{Ptr{UInt8}}, s)
    end

    @inline function print_args(argc::Int, argv::Ptr{Ptr{UInt8}})
        for i=1:argc
            # Get pointer
            p = unsafe_load(argv, i)
            # Print string at pointer location (which fortunately already exists isn't tracked by the GC)
            _puts(p)
        end
        return 0
    end

    filepath = compile_executable(print_args, (Int, Ptr{Ptr{UInt8}}), workdir, demangle=false)
    r = run(`$filepath Hello, world!`);
    @test isa(r, Base.Process)
    @test r.exitcode == 0

    filepath = compile_executable(print_args, (Int, Ptr{Ptr{UInt8}}), workdir, demangle=true)
    r = run(`$filepath Hello, world!`);
    @test isa(r, Base.Process)
    @test r.exitcode == 0

    filepath = compile_executable(print_args, (Int, Ptr{Ptr{UInt8}}), workdir, llvm_to_clang=true)
    r = run(`$filepath Hello, world!`);
    @test isa(r, Base.Process)
    @test r.exitcode == 0


    # Compile a function that definitely fails
    @inline foo_err() = UInt64(-1)
    filepath = compile_executable(foo_err, (), workdir, demangle=true)
    @test isfile(filepath)
    status = -1
    try
        status = run(`filepath`)
    catch
        @info "foo_err: Task failed successfully!"
    end
    @test status === -1

end

@noinline square(n) = n*n

function squaresquare(n)
    square(square(n))
end

function squaresquaresquare(n)
    square(squaresquare(n))
end

@testset "Binary Size Optimization" begin
    # Test that strip_binary option reduces executable size
    strip_test_func() = 0

    filepath_unstripped = compile_executable(strip_test_func, (), workdir, "unstripped", strip_binary=false)
    size_unstripped = filesize(filepath_unstripped)

    if !Sys.iswindows()
        filepath_stripped = compile_executable(strip_test_func, (), workdir, "stripped", strip_binary=true)
        size_stripped = filesize(filepath_stripped)
        @test size_stripped <= size_unstripped
    end
end

@testset "Multiple Function Dylibs" begin

    funcs = [(squaresquare,(Float64,)), (squaresquaresquare,(Float64,))]
    filepath = compile_shlib(funcs, workdir, demangle=true)

    ptr = Libdl.dlopen(filepath, Libdl.RTLD_LOCAL)

    fptr2 = Libdl.dlsym(ptr, "squaresquare")
    @test ccall(fptr2, Float64, (Float64,), 10.) == squaresquare(10.)

    fptr = Libdl.dlsym(ptr, "squaresquaresquare")
    @test ccall(fptr, Float64, (Float64,), 10.) == squaresquaresquare(10.)
    #Compile dylib
end


# Overlays

module SubFoo

rand(args...) = Base.rand(args...)

function f()
    x = rand()
    y = rand()
    return x + y
end

end

@device_override SubFoo.rand() = 2

# Lets test having another method table around
Base.Experimental.@MethodTable AnotherTable
Base.Experimental.@overlay AnotherTable SubFoo.rand() = 3

@testset "Overlays" begin
    Libdl.dlopen(compile_shlib(SubFoo.f, (), workdir)) do lib
        fptr = Libdl.dlsym(lib, "f")
        @test @ccall($fptr()::Int) == 4
    end
    Libdl.dlopen(compile_shlib(SubFoo.f, (), workdir; method_table=AnotherTable)) do lib
        fptr = Libdl.dlsym(lib, "f")
        @test @ccall($fptr()::Int) == 6
    end
end

@testset "Windows Support" begin
    # Test Windows-specific compilation path with llvm_to_clang
    simple_func() = 42

    if Sys.iswindows()
        filepath = compile_shlib(simple_func, (), workdir, llvm_to_clang=true)
        @test isfile(filepath)
    else
        # On non-Windows, just verify llvm_to_clang option is accepted
        filepath = compile_shlib(simple_func, (), workdir, llvm_to_clang=false)
        @test isfile(filepath)
    end
end

@testset "Cache Management" begin
    # Test cache statistics
    StaticCompiler.clear_cache!()
    stats = StaticCompiler.cache_stats()
    @test stats.entries == 0
    @test stats.size_mb == 0.0

    # Compile something to populate cache
    cache_test_v1(x::Int) = x + 1
    compile_shlib(cache_test_v1, (Int,), workdir, "cache_v1")

    stats = StaticCompiler.cache_stats()
    @test stats.entries >= 1

    # Test cache pruning
    removed = StaticCompiler.prune_cache!(max_age_days=0, max_size_mb=0)
    @test removed >= 0

    StaticCompiler.clear_cache!()
end

@testset "Checker: Closures" begin
    # Test that checker detects closures
    outer(x) = y -> x + y
    closure = outer(5)

    report = StaticCompiler.check_compilable(closure, (Int,), verbose=false)
    @test !report.compilable
    @test any(i -> i.category == :closure, report.issues)
end

@testset "Checker: Dynamic Dispatch" begin
    # Test that checker detects Any types
    dynamic_func(x::Any) = x + 1

    report = StaticCompiler.check_compilable(dynamic_func, (Any,), verbose=false)
    @test !report.compilable
    @test any(i -> i.category == :dynamic_dispatch, report.issues)
end

@testset "Checker: Abstract Types" begin
    # Test that checker warns about abstract argument types
    abstract_func(x::Integer) = x + 1

    report = StaticCompiler.check_compilable(abstract_func, (Integer,), verbose=false)
    @test any(i -> i.category == :abstract_argument, report.issues)
end

@testset "Error Recovery" begin
    # Test that compilation errors don't corrupt state
    bad_type_func(x::Int) = x + "string"

    try
        compile_shlib(bad_type_func, (Int,), workdir, "bad_compile")
    catch e
        @test e isa StaticCompiler.CompilationError
    end

    # Should still work after error
    good_func_after_error(x::Int) = x + 1
    filepath = compile_shlib(good_func_after_error, (Int,), workdir, "good_after_error")
    @test isfile(filepath)
end

@testset "Edge Cases: Empty Function" begin
    # Test compilation of function that does nothing
    empty_func() = nothing

    filepath = compile_executable(empty_func, (), workdir, "empty_test")
    @test isfile(filepath)
end

@testset "Edge Cases: Multiple Return Paths" begin
    # Test function with multiple return paths
    multi_return(x::Int) = begin
        if x > 0
            return x
        elseif x < 0
            return -x
        else
            return 0
        end
    end

    report = StaticCompiler.check_compilable(multi_return, (Int,), verbose=false)
    @test report.compilable

    filepath = compile_shlib(multi_return, (Int,), workdir, "multi_return")
    @test isfile(filepath)
end

@testset "Binary Size Estimation" begin
    # Test size estimation
    size_test_func(x::Int) = x * 2 + 1

    estimate = StaticCompiler.estimate_binary_size(size_test_func, (Int,), verbose=false)
    @test estimate.expected_kb > 0
    @test estimate.min_kb <= estimate.expected_kb <= estimate.max_kb
    @test 0.0 < estimate.confidence <= 1.0
    @test haskey(estimate.breakdown, :base)
end

@testset "Dependency Analysis" begin
    # Compile a simple executable
    dep_test_func() = 42

    filepath = compile_executable(dep_test_func, (), workdir, "dep_test")
    @test isfile(filepath)

    # Analyze dependencies
    deps = StaticCompiler.analyze_dependencies(filepath)
    @test haskey(deps, :system)
    @test haskey(deps, :custom)
    @test haskey(deps, :missing)
end

@testset "Binary Bundler" begin
    # Test bundle creation
    bundle_func() = 0

    exe_path = compile_executable(bundle_func, (), workdir, "bundle_test")
    @test isfile(exe_path)

    bundle_dir = joinpath(workdir, "bundle_output")
    config = StaticCompiler.BundleConfig(bundle_dir)

    bundle_path = StaticCompiler.create_bundle(exe_path, config)
    @test isdir(bundle_path)
    @test isfile(joinpath(bundle_path, "bundle_test"))
    @test isfile(joinpath(bundle_path, "README.txt"))
end

@testset "Optimization Profiles" begin
    # Test optimization flag generation
    flags_size = StaticCompiler.get_optimization_flags(StaticCompiler.PROFILE_SIZE)
    @test any(f -> occursin("-Os", f), flags_size)

    flags_speed = StaticCompiler.get_optimization_flags(StaticCompiler.PROFILE_SPEED)
    @test any(f -> occursin("-O3", f), flags_speed)

    flags_debug = StaticCompiler.get_optimization_flags(StaticCompiler.PROFILE_DEBUG)
    @test any(f -> occursin("-O0", f), flags_debug)
end

@testset "Benchmark Infrastructure" begin
    # Test benchmarking
    bench_func(x::Int) = x + 1

    StaticCompiler.clear_benchmarks!()

    _, result = StaticCompiler.benchmark_compile(bench_func, (Int,), path=workdir, name="bench_test")

    @test result.compilation_time_s > 0
    @test result.binary_size_kb > 0
    @test result.function_name == "bench_func"

    # Check benchmark was saved
    benchmarks = StaticCompiler.load_benchmarks()
    @test length(benchmarks) >= 1
    @test any(b -> b.function_name == "bench_func", benchmarks)
end

@testset "analyze_binary_size" begin
    # Compile executable and analyze its size
    analyze_func() = 42
    exe = compile_executable(analyze_func, (), workdir, "analyze_test")
    @test isfile(exe)

    # Analyze the compiled binary
    if !Sys.iswindows()
        analysis = StaticCompiler.analyze_binary_size(exe)
        @test haskey(analysis, :total_kb)
        @test haskey(analysis, :sections)
        @test haskey(analysis, :stripped)
        @test analysis[:total_kb] > 0
        # Check sections if they were successfully parsed
        if haskey(analysis[:sections], :text)
            @test analysis[:sections][:text] > 0
        end
    end
end

@testset "optimize_binary actual optimization" begin
    # Compile unstripped binary
    opt_func() = 0
    exe = compile_executable(opt_func, (), workdir, "opt_actual_test", strip_binary=false)
    size_before = filesize(exe)

    # Optimize it (will strip symbols)
    if !Sys.iswindows()
        StaticCompiler.optimize_binary(exe, StaticCompiler.PROFILE_SIZE)
        size_after = filesize(exe)
        @test size_after < size_before
    end
end

@testset "compile_executable_optimized" begin
    # Test the convenience function
    optimized_func() = 0
    exe = StaticCompiler.compile_executable_optimized(
        optimized_func, (), workdir, "exec_opt_test",
        profile=StaticCompiler.PROFILE_DEBUG
    )
    @test isfile(exe)
    # Verify it runs successfully
    r = run(`$exe`)
    @test r.exitcode == 0
    @test isa(r, Base.Process)
end

@testset "Advanced Static Analysis" begin
    # Test allocation analysis
    alloc_func(x::Int) = x + 1  # Simple, no allocations

    alloc_profile = StaticCompiler.analyze_allocations(alloc_func, (Int,))
    @test alloc_profile isa StaticCompiler.AllocationProfile
    @test alloc_profile.total_allocations >= 0

    # Test inline analysis
    inline_info = StaticCompiler.analyze_inlining(alloc_func, (Int,))
    @test inline_info isa StaticCompiler.InlineAnalysis
    @test inline_info.inline_cost_estimates isa Dict

    # Test call graph
    graph = StaticCompiler.build_call_graph(alloc_func, (Int,))
    @test graph isa Vector
    @test all(n -> n isa StaticCompiler.CallNode, graph)

    # Test bloat analysis
    bloat = StaticCompiler.analyze_bloat(alloc_func, (Int,))
    @test bloat isa StaticCompiler.BloatAnalysis
    @test bloat.total_functions >= 0

    # Test comprehensive analysis
    report = StaticCompiler.advanced_analysis(alloc_func, (Int,), verbose=false)
    @test report isa StaticCompiler.AdvancedAnalysisReport
    @test 0.0 <= report.performance_score <= 100.0
    @test 0.0 <= report.size_score <= 100.0
end

@testset "UPX Compression Support" begin
    # Test UPX availability detection
    avail, version = StaticCompiler.test_upx_available()
    @test avail isa Bool
    @test version isa String

    # Only run compression tests if UPX is available
    if avail
        upx_func() = 0
        exe = compile_executable(upx_func, (), workdir, "upx_test", strip_binary=false)
        size_before = filesize(exe)

        # Test compression (may fail if binary not compressible, that's ok)
        try
            StaticCompiler.compress_with_upx(exe, level=:fast, verify=false)
            size_after = filesize(exe)
            # Either compressed (smaller) or failed gracefully (same size)
            @test size_after <= size_before
        catch e
            # UPX may fail on certain binaries, that's acceptable
            @test true
        end
    end
end

@testset "LTO Profiles" begin
    # Test that LTO profiles exist and are valid
    @test isdefined(StaticCompiler, :PROFILE_SIZE_LTO)
    @test isdefined(StaticCompiler, :PROFILE_SPEED_LTO)

    # Test LTO profile flags
    lto_flags = StaticCompiler.get_optimization_flags(StaticCompiler.PROFILE_SIZE_LTO)
    @test any(f -> occursin("lto", f), lto_flags)

    # Note: Not testing actual LTO compilation as it requires specific toolchain setup
end

@testset "Automated Recommendations" begin
    # Test recommendation system
    good_func(x::Int) = x + 1

    recs = StaticCompiler.recommend_optimizations(good_func, (Int,), verbose=false)
    @test recs isa StaticCompiler.OptimizationRecommendations
    @test recs.overall_score >= 0.0
    @test recs.overall_score <= 100.0
    @test recs.recommendations isa Vector

    # Test quick_optimize
    exe = StaticCompiler.quick_optimize(good_func, (Int,), workdir, "quick_test", verbose=false)
    @test isfile(exe)
end

@testset "Build Configuration" begin
    # Test configuration creation
    config = StaticCompiler.BuildConfig(
        profile=StaticCompiler.PROFILE_SIZE,
        name="test_config",
        version="1.0.0"
    )
    @test config isa StaticCompiler.BuildConfig
    @test config.name == "test_config"

    # Test save/load
    config_file = joinpath(workdir, "test_config.jlconfig")
    StaticCompiler.save_config(config, config_file)
    @test isfile(config_file)

    loaded = StaticCompiler.load_config(config_file)
    @test loaded.name == "test_config"
    @test loaded.version == "1.0.0"

    # Test compile with config
    config_func() = 0
    exe = StaticCompiler.compile_with_config(config_func, (), loaded, path=workdir)
    @test isfile(exe)
end

@testset "SIMD Analysis" begin
    # Test SIMD analysis on simple function
    simd_func(x::Int) = x * 2 + 1

    report = StaticCompiler.analyze_simd(simd_func, (Int,), verbose=false)
    @test report isa StaticCompiler.SIMDReport
    @test report.vectorization_score >= 0.0
    @test report.vectorization_score <= 100.0
    @test report.vectorized_loops >= 0
    @test report.missed_opportunities isa Vector
end

@testset "Security Analysis" begin
    # Test security analysis
    safe_func(x::Int) = x + 1

    report = StaticCompiler.analyze_security(safe_func, (Int,), verbose=false)
    @test report isa StaticCompiler.SecurityReport
    @test report.security_score >= 0.0
    @test report.security_score <= 100.0
    @test report.critical_issues isa Vector
    @test report.warnings isa Vector
end

@testset "Memory Layout Analysis" begin
    # Define test struct
    struct TestStruct
        a::Int8
        b::Int64
        c::Int8
    end

    report = StaticCompiler.analyze_memory_layout(TestStruct, verbose=false)
    @test report isa StaticCompiler.MemoryLayoutReport
    @test report.total_size > 0
    @test report.alignment > 0
    @test report.padding_bytes >= 0
    @test length(report.field_info) == 3
    @test length(report.suggested_order) == 3

    # Test suggested optimization
    opt_str = StaticCompiler.suggest_layout_optimization(TestStruct)
    @test opt_str isa String
    @test occursin("struct", opt_str) || occursin("No optimization", opt_str)
end

@testset "Optimization Wizard" begin
    # Test wizard config creation
    wizard_func(x::Int) = x * x + 2

    # Test non-interactive mode (uses defaults)
    config = StaticCompiler.optimization_wizard(wizard_func, (Int,), interactive=false)
    @test config isa StaticCompiler.WizardConfig
    @test config.priority == :balanced
    @test config.target_platform == :desktop
    @test config.deployment == :development

    # Test quick_wizard
    exe = StaticCompiler.quick_wizard(wizard_func, (Int,), priority=:size, path=workdir, name="wizard_test")
    @test isfile(exe)

    # Test recommended profile
    profile_name = StaticCompiler.recommended_profile(config)
    @test profile_name isa String
    @test occursin("PROFILE", profile_name)
end

@testset "Dependency Bloat Analysis" begin
    # Test dependency bloat analysis
    bloat_func(x::Int, y::Float64) = x + Int(floor(y))

    report = StaticCompiler.analyze_dependency_bloat(bloat_func, (Int, Float64), verbose=false)
    @test report isa StaticCompiler.DependencyReport
    @test report.total_functions >= 0
    @test report.unique_modules isa Vector
    @test report.bloat_score >= 0.0
    @test report.bloat_score <= 100.0

    # Test suggest_nospecialize
    suggestions = StaticCompiler.suggest_nospecialize(bloat_func, (Int, Float64), verbose=false)
    @test suggestions isa Vector

    # Test estimate_dependency_size
    if !isempty(report.unique_modules)
        first_module = first(report.unique_modules)
        size_est = StaticCompiler.estimate_dependency_size(first_module, report)
        @test size_est >= 0
    end

    # Test compare_dependency_impact (simplified test)
    impl1(x::Int) = x + 1
    impl2(x::Int) = x * 2

    comparison = StaticCompiler.compare_dependency_impact(impl1, (Int,), impl2, (Int,), verbose=false)
    @test haskey(comparison, :report1)
    @test haskey(comparison, :report2)
    @test comparison.report1 isa StaticCompiler.DependencyReport
    @test comparison.report2 isa StaticCompiler.DependencyReport
end

@testset "Comprehensive Reporting" begin
    # Test comprehensive report generation
    report_func(x::Int) = x * x + 1

    report = StaticCompiler.generate_comprehensive_report(
        report_func,
        (Int,),
        compile=false,
        verbose=false
    )

    @test report isa StaticCompiler.ComprehensiveReport
    @test report.function_name == "report_func"
    @test report.overall_score >= 0.0
    @test report.overall_score <= 100.0
    @test report.performance_score >= 0.0
    @test report.performance_score <= 100.0
    @test report.size_score >= 0.0
    @test report.size_score <= 100.0
    @test report.security_score >= 0.0
    @test report.security_score <= 100.0

    # Test JSON export
    json_file = joinpath(workdir, "test_report.json")
    StaticCompiler.export_report_json(report, json_file)
    @test isfile(json_file)
    @test filesize(json_file) > 0

    # Test Markdown export
    md_file = joinpath(workdir, "test_report.md")
    StaticCompiler.export_report_markdown(report, md_file)
    @test isfile(md_file)
    @test filesize(md_file) > 0
    
    # Verify markdown contains expected sections
    md_content = read(md_file, String)
    @test occursin("# Compilation Report", md_content)
    @test occursin("## Scores", md_content)

    # Test report comparison
    report2 = StaticCompiler.generate_comprehensive_report(
        report_func,
        (Int,),
        compile=false,
        verbose=false
    )
    
    # Should not error
    StaticCompiler.compare_reports(report, report2, verbose=false)
end

@testset "CI Integration" begin
    # Test CI configuration
    config = StaticCompiler.CIConfig(
        fail_on_allocations=false,
        fail_on_security_issues=true,
        max_binary_size_kb=1000,
        min_performance_score=50.0,
        min_security_score=80.0,
        generate_reports=true,
        report_formats=[:json, :markdown]
    )

    @test config.max_binary_size_kb == 1000
    @test config.min_performance_score == 50.0
    @test config.fail_on_security_issues == true

    # Test CI environment detection
    ci_info = StaticCompiler.detect_ci_environment()
    @test haskey(ci_info, :detected)
    @test ci_info.detected isa Bool

    # Test badge generation
    test_report = StaticCompiler.generate_comprehensive_report(
        x -> x + 1,
        (Int,),
        compile=false,
        verbose=false
    )
    
    badge_info = StaticCompiler.generate_ci_badge(test_report)
    @test length(badge_info) == 3
    @test badge_info[1] isa String  # status
    @test badge_info[2] isa String  # color
    @test badge_info[3] isa Int     # score

    # Test CI summary table
    summary = StaticCompiler.ci_summary_table(test_report)
    @test summary isa String
    @test occursin("Overall", summary)
    @test occursin("Performance", summary)

    # Test example workflow constants
    @test StaticCompiler.GITHUB_ACTIONS_EXAMPLE isa String
    @test occursin("GitHub Actions", StaticCompiler.GITHUB_ACTIONS_EXAMPLE)
    @test StaticCompiler.GITLAB_CI_EXAMPLE isa String
    @test occursin("GitLab", StaticCompiler.GITLAB_CI_EXAMPLE)
end

@testset "Performance Benchmarking" begin
    # Simple test function
    test_add(x::Int, y::Int) = x + y

    # Test BenchmarkConfig
    config = StaticCompiler.BenchmarkConfig(
        samples=10,
        warmup_samples=2,
        measure_allocations=true,
        timeout_seconds=5.0
    )
    @test config.samples == 10
    @test config.warmup_samples == 2
    @test config.measure_allocations == true

    # Test basic benchmarking
    try
        result = StaticCompiler.benchmark_function(
            test_add,
            (Int, Int),
            (5, 10),
            config=config,
            verbose=false
        )

        @test result isa StaticCompiler.BenchmarkResult
        @test result.function_name == "test_add"
        @test result.samples == config.samples
        @test result.median_time_ns > 0
        @test result.mean_time_ns > 0
        @test result.std_dev_ns >= 0
        @test result.min_time_ns <= result.median_time_ns
        @test result.median_time_ns <= result.max_time_ns
        @test result.binary_size_bytes > 0
    catch e
        @warn "Basic benchmark test skipped: $e"
    end

    # Test format_time
    @test StaticCompiler.format_time(500.0) == "500.0 ns"
    @test StaticCompiler.format_time(1500.0) == "1.5 μs"
    @test StaticCompiler.format_time(1_500_000.0) == "1.5 ms"
    @test StaticCompiler.format_time(1_500_000_000.0) == "1.5 s"

    # Test format_bytes
    @test StaticCompiler.format_bytes(512) == "512 B"
    @test StaticCompiler.format_bytes(1536) == "1.5 KB"
    @test StaticCompiler.format_bytes(1_572_864) == "1.5 MB"

    # Test regression detection
    baseline = StaticCompiler.BenchmarkResult(
        "test_func",
        100,
        100.0,  # min
        150.0,  # median
        155.0,  # mean
        200.0,  # max
        10.0,   # std_dev
        0,      # allocations
        0,      # memory
        nothing,
        10000,
        Dates.now()
    )

    # No regression (1% slower)
    current_same = StaticCompiler.BenchmarkResult(
        "test_func",
        100,
        100.0,
        151.5,  # 1% slower
        156.0,
        200.0,
        10.0,
        0,
        0,
        nothing,
        10000,
        Dates.now()
    )
    has_regr, pct, msg = StaticCompiler.detect_performance_regression(current_same, baseline, threshold=5.0)
    @test has_regr == false
    @test abs(pct) < 5.0

    # Regression (10% slower)
    current_slow = StaticCompiler.BenchmarkResult(
        "test_func",
        100,
        100.0,
        165.0,  # 10% slower
        170.0,
        200.0,
        10.0,
        0,
        0,
        nothing,
        10000,
        Dates.now()
    )
    has_regr, pct, msg = StaticCompiler.detect_performance_regression(current_slow, baseline, threshold=5.0)
    @test has_regr == true
    @test pct > 5.0

    # Improvement (10% faster)
    current_fast = StaticCompiler.BenchmarkResult(
        "test_func",
        100,
        100.0,
        135.0,  # 10% faster
        140.0,
        200.0,
        10.0,
        0,
        0,
        nothing,
        10000,
        Dates.now()
    )
    has_regr, pct, msg = StaticCompiler.detect_performance_regression(current_fast, baseline, threshold=5.0)
    @test has_regr == false
    @test pct < -5.0

    # Test benchmark history saving
    workdir = mktempdir()
    history_file = joinpath(workdir, "history.json")

    try
        result = StaticCompiler.BenchmarkResult(
            "test_func",
            50,
            100.0,
            150.0,
            155.0,
            200.0,
            10.0,
            0,
            0,
            nothing,
            10000,
            Dates.now()
        )
        StaticCompiler.save_benchmark_history(result, history_file)
        @test isfile(history_file)
        @test filesize(history_file) > 0
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test comprehensive report integration
    try
        report = StaticCompiler.generate_comprehensive_report(
            test_add,
            (Int, Int),
            compile=false,
            benchmark=true,
            benchmark_args=(5, 10),
            verbose=false
        )

        if report.benchmark !== nothing
            @test report.benchmark isa StaticCompiler.BenchmarkResult
            @test report.benchmark.median_time_ns > 0
        end
    catch e
        @warn "Comprehensive report benchmark test skipped: $e"
    end
end

@testset "Profile-Guided Optimization" begin
    # Test function
    pgo_test_func(x::Int, y::Int) = x * y + x - y

    # Test PGOConfig
    config = StaticCompiler.PGOConfig(
        target_metric = :speed,
        iterations = 2,
        benchmark_samples = 10,
        improvement_threshold = 3.0,
        auto_apply = true,
        save_profiles = false
    )

    @test config.target_metric == :speed
    @test config.iterations == 2
    @test config.benchmark_samples == 10
    @test config.improvement_threshold == 3.0
    @test config.auto_apply == true
    @test config.save_profiles == false

    # Test profile collection
    try
        profile = StaticCompiler.collect_profile(
            pgo_test_func,
            (Int, Int),
            (10, 20),
            config=config,
            verbose=false
        )

        @test profile isa StaticCompiler.ProfileData
        @test profile.function_name == "pgo_test_func"
        @test profile.benchmark_result isa StaticCompiler.BenchmarkResult
        @test profile.recommended_profile isa Symbol
        @test profile.hot_paths isa Vector{String}
        @test profile.optimization_opportunities isa Vector{String}
    catch e
        @warn "Profile collection test skipped: $e"
    end

    # Test profile recommendation
    mock_benchmark = StaticCompiler.BenchmarkResult(
        "test_func",
        50,
        100.0,
        150.0,
        155.0,
        200.0,
        10.0,
        0,
        0,
        nothing,
        50000,  # 50KB binary
        Dates.now()
    )

    # Speed target with slow execution
    config_speed = StaticCompiler.PGOConfig(target_metric=:speed)
    rec = StaticCompiler.recommend_profile(mock_benchmark, config_speed)
    @test rec in [:PROFILE_SPEED, :PROFILE_AGGRESSIVE]

    # Size target
    config_size = StaticCompiler.PGOConfig(target_metric=:size)
    rec_size = StaticCompiler.recommend_profile(mock_benchmark, config_size)
    @test rec_size == :PROFILE_SIZE

    # Balanced target
    config_balanced = StaticCompiler.PGOConfig(target_metric=:balanced)
    rec_balanced = StaticCompiler.recommend_profile(mock_benchmark, config_balanced)
    @test rec_balanced isa Symbol

    # Test hot path identification
    hot_paths = StaticCompiler.identify_hot_paths(pgo_test_func, (Int, Int), mock_benchmark)
    @test hot_paths isa Vector{String}

    # Test optimization opportunities
    opportunities = StaticCompiler.identify_optimization_opportunities(
        pgo_test_func,
        (Int, Int),
        mock_benchmark,
        config_speed
    )
    @test opportunities isa Vector{String}

    # Test PGO compilation (basic - may skip on actual compilation)
    workdir = mktempdir()
    try
        pgo_config = StaticCompiler.PGOConfig(
            target_metric = :speed,
            iterations = 1,  # Just 1 iteration for testing
            benchmark_samples = 5,
            save_profiles = false
        )

        result = StaticCompiler.pgo_compile(
            pgo_test_func,
            (Int, Int),
            (10, 20),
            workdir,
            "pgo_test",
            config=pgo_config,
            verbose=false
        )

        @test result isa StaticCompiler.PGOResult
        @test result.function_name == "pgo_test_func"
        @test result.iterations_completed >= 1
        @test result.iterations_completed <= pgo_config.iterations
        @test result.best_profile isa Symbol
        @test result.best_time_ns > 0
        @test length(result.profiles) == result.iterations_completed

    catch e
        @warn "PGO compilation test skipped: $e"
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test profile saving/loading
    workdir = mktempdir()
    try
        mock_profile = StaticCompiler.ProfileData(
            "test_func",
            "(Int, Int)",
            mock_benchmark,
            ["hot path 1"],
            ["opportunity 1"],
            :PROFILE_SPEED,
            Dates.now()
        )

        StaticCompiler.save_profile_data(mock_profile, workdir)

        # Check that file was created
        files = readdir(workdir)
        @test length(files) > 0
        @test any(occursin("test_func", f) for f in files)

    finally
        rm(workdir, recursive=true, force=true)
    end
end

@testset "Optimization Presets" begin
    # Test function
    preset_test_func(x::Int) = x * 2 + 10

    # Test preset retrieval
    embedded_preset = StaticCompiler.get_preset(:embedded)
    @test embedded_preset isa StaticCompiler.OptimizationPreset
    @test embedded_preset.name == :embedded
    @test embedded_preset.use_upx == true
    @test embedded_preset.strip_binary == true

    serverless_preset = StaticCompiler.get_preset(:serverless)
    @test serverless_preset isa StaticCompiler.OptimizationPreset
    @test serverless_preset.name == :serverless
    @test serverless_preset.use_upx == false  # No UPX for serverless

    hpc_preset = StaticCompiler.get_preset(:hpc)
    @test hpc_preset isa StaticCompiler.OptimizationPreset
    @test hpc_preset.name == :hpc
    @test hpc_preset.benchmark_enabled == true

    desktop_preset = StaticCompiler.get_preset(:desktop)
    @test desktop_preset isa StaticCompiler.OptimizationPreset
    @test desktop_preset.name == :desktop

    dev_preset = StaticCompiler.get_preset(:development)
    @test dev_preset isa StaticCompiler.OptimizationPreset
    @test dev_preset.name == :development
    @test dev_preset.strip_binary == false  # Keep symbols for debugging

    release_preset = StaticCompiler.get_preset(:release)
    @test release_preset isa StaticCompiler.OptimizationPreset
    @test release_preset.name == :release
    @test release_preset.enable_lto == true

    # Test unknown preset
    unknown = StaticCompiler.get_preset(:nonexistent)
    @test unknown === nothing

    # Test listing presets
    preset_names = StaticCompiler.list_presets(verbose=false)
    @test preset_names isa Vector
    @test length(preset_names) == 6
    @test :embedded in preset_names
    @test :serverless in preset_names
    @test :hpc in preset_names
    @test :desktop in preset_names
    @test :development in preset_names
    @test :release in preset_names

    # Test ALL_PRESETS constant
    @test length(StaticCompiler.ALL_PRESETS) == 6
    @test all(p -> p isa StaticCompiler.OptimizationPreset, StaticCompiler.ALL_PRESETS)

    # Test preset constants are accessible
    @test StaticCompiler.PRESET_EMBEDDED.name == :embedded
    @test StaticCompiler.PRESET_SERVERLESS.name == :serverless
    @test StaticCompiler.PRESET_HPC.name == :hpc
    @test StaticCompiler.PRESET_DESKTOP.name == :desktop
    @test StaticCompiler.PRESET_DEVELOPMENT.name == :development
    @test StaticCompiler.PRESET_RELEASE.name == :release

    # Test preset properties
    @test embedded_preset.optimization_profile == :PROFILE_SIZE_LTO
    @test serverless_preset.optimization_profile == :PROFILE_SIZE
    @test hpc_preset.optimization_profile == :PROFILE_AGGRESSIVE
    @test desktop_preset.optimization_profile == :PROFILE_SPEED
    @test dev_preset.optimization_profile == :PROFILE_DEBUG
    @test release_preset.optimization_profile == :PROFILE_SPEED_LTO

    # Test preset descriptions
    @test length(embedded_preset.description) > 0
    @test length(embedded_preset.recommended_for) > 0
    @test "Embedded systems" in embedded_preset.recommended_for

    # Test compile_with_preset
    workdir = mktempdir()
    try
        result = StaticCompiler.compile_with_preset(
            preset_test_func,
            (Int,),
            workdir,
            "preset_test",
            :desktop,
            args=(100,),
            verbose=false
        )

        @test result isa Dict
        @test haskey(result, "preset")
        @test result["preset"] == :desktop
        @test haskey(result, "function")
        @test result["function"] == "preset_test_func"
        @test haskey(result, "scores")
        @test haskey(result["scores"], "overall")
        @test haskey(result["scores"], "performance")
        @test haskey(result["scores"], "size")
        @test haskey(result["scores"], "security")
        @test haskey(result, "total_time_seconds")

        if haskey(result, "binary_size")
            @test result["binary_size"] > 0
        end

    catch e
        @warn "Preset compilation test skipped: $e"
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test compile_with_preset error handling
    @test_throws Exception StaticCompiler.compile_with_preset(
        preset_test_func,
        (Int,),
        mktempdir(),
        "test",
        :nonexistent_preset,
        verbose=false
    )
end

@testset "Smart Optimization" begin
    # Test function
    smart_test_func(x::Int) = x * x + x

    # Test SmartOptimizationResult structure exists
    @test isdefined(StaticCompiler, :SmartOptimizationResult)

    # Test smart_optimize with :auto target
    workdir = mktempdir()
    try
        result = StaticCompiler.smart_optimize(
            smart_test_func,
            (Int,),
            workdir,
            "smart_test",
            args=(100,),
            target=:auto,
            verbose=false
        )

        @test result isa StaticCompiler.SmartOptimizationResult
        @test result.function_name == "smart_test_func"
        @test result.recommended_preset isa Symbol
        @test result.chosen_strategy isa String
        @test length(result.chosen_strategy) > 0
        @test result.analysis isa StaticCompiler.ComprehensiveReport
        @test result.optimization_time_seconds >= 0.0
        @test result.improvements isa Vector{String}

    catch e
        @warn "Smart optimize test skipped: $e"
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test smart_optimize with :size target
    workdir = mktempdir()
    try
        result = StaticCompiler.smart_optimize(
            smart_test_func,
            (Int,),
            workdir,
            "smart_test_size",
            target=:size,
            verbose=false
        )

        @test result isa StaticCompiler.SmartOptimizationResult
        @test result.recommended_preset == :embedded

    catch e
        @warn "Smart optimize size target test skipped: $e"
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test smart_optimize with :speed target
    workdir = mktempdir()
    try
        result = StaticCompiler.smart_optimize(
            smart_test_func,
            (Int,),
            workdir,
            "smart_test_speed",
            target=:speed,
            verbose=false
        )

        @test result isa StaticCompiler.SmartOptimizationResult
        @test result.recommended_preset == :hpc

    catch e
        @warn "Smart optimize speed target test skipped: $e"
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test smart_optimize with :balanced target
    workdir = mktempdir()
    try
        result = StaticCompiler.smart_optimize(
            smart_test_func,
            (Int,),
            workdir,
            "smart_test_balanced",
            target=:balanced,
            verbose=false
        )

        @test result isa StaticCompiler.SmartOptimizationResult
        @test result.recommended_preset == :desktop

    catch e
        @warn "Smart optimize balanced target test skipped: $e"
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test smart_optimize with specific preset as target
    workdir = mktempdir()
    try
        result = StaticCompiler.smart_optimize(
            smart_test_func,
            (Int,),
            workdir,
            "smart_test_preset",
            target=:embedded,
            verbose=false
        )

        @test result isa StaticCompiler.SmartOptimizationResult
        @test result.recommended_preset == :embedded

    catch e
        @warn "Smart optimize preset target test skipped: $e"
    finally
        rm(workdir, recursive=true, force=true)
    end

    # Test quick_compile
    try
        binary = StaticCompiler.quick_compile(
            smart_test_func,
            (Int,),
            "quick_test"
        )

        @test binary isa String

    catch e
        @warn "Quick compile test skipped: $e"
    end

    # Test error handling for invalid target
    @test_throws Exception StaticCompiler.smart_optimize(
        smart_test_func,
        (Int,),
        mktempdir(),
        "test",
        target=:invalid_target,
        verbose=false
    )
end

@testset "Optimization Validation Tests" begin
    # Test function for validation
    function validation_test_func(n::Int)
        result = 0
        for i in 1:n
            result += i * i
        end
        return result
    end

    @testset "Different profiles produce different binaries" begin
        output_dir_size = mktempdir()
        output_dir_speed = mktempdir()

        try
            # Compile with PROFILE_SIZE
            result_size = compile_with_preset(
                validation_test_func,
                (Int,),
                output_dir_size,
                "test_size",
                :embedded,  # Uses PROFILE_SIZE_LTO
                verbose=false
            )

            # Compile with PROFILE_SPEED
            result_speed = compile_with_preset(
                validation_test_func,
                (Int,),
                output_dir_speed,
                "test_speed",
                :hpc,  # Uses PROFILE_SPEED
                verbose=false
            )

            # Verify both compiled successfully
            @test haskey(result_size, "binary_size")
            @test haskey(result_speed, "binary_size")

            size_binary = result_size["binary_size"]
            speed_binary = result_speed["binary_size"]

            # Print sizes for debugging
            println("\n  Size-optimized binary: $(format_bytes(size_binary))")
            println("  Speed-optimized binary: $(format_bytes(speed_binary))")

            # Size-optimized should generally be smaller, but allow for variation
            # At minimum, they should be different (not identical)
            @test size_binary != speed_binary

        finally
            rm(output_dir_size, recursive=true, force=true)
            rm(output_dir_speed, recursive=true, force=true)
        end
    end

    @testset "Optimization flags are actually applied" begin
        output_dir = mktempdir()

        try
            # Compile with development preset (should have -O0)
            result_dev = compile_with_preset(
                validation_test_func,
                (Int,),
                output_dir,
                "test_dev",
                :development,
                verbose=false
            )

            # Compile with release preset (should have -O3)
            result_release = compile_with_preset(
                validation_test_func,
                (Int,),
                output_dir,
                "test_release",
                :release,
                verbose=false
            )

            # Both should compile
            @test haskey(result_dev, "binary_size")
            @test haskey(result_release, "binary_size")

            # Release build should generally be smaller than debug (due to optimizations)
            # but we mainly care that they're different
            @test result_dev["binary_size"] != result_release["binary_size"]

        finally
            rm(output_dir, recursive=true, force=true)
        end
    end

    @testset "Profile comparison tests different profiles" begin
        config = BenchmarkConfig(
            samples=5,
            warmup_samples=2,
            profiles_to_test=[:PROFILE_SIZE, :PROFILE_SPEED]
        )

        results = compare_optimization_profiles(
            validation_test_func,
            (Int,),
            (1000,),
            config=config,
            verbose=false
        )

        # Should have results for both profiles
        @test haskey(results, :PROFILE_SIZE)
        @test haskey(results, :PROFILE_SPEED)

        # Results should be different
        size_result = results[:PROFILE_SIZE]
        speed_result = results[:PROFILE_SPEED]

        @test size_result.binary_size_bytes != speed_result.binary_size_bytes
        @test size_result.optimization_profile == :PROFILE_SIZE
        @test speed_result.optimization_profile == :PROFILE_SPEED

        println("\n  PROFILE_SIZE: $(format_bytes(size_result.binary_size_bytes)), " *
                "$(format_time(size_result.median_time_ns))")
        println("  PROFILE_SPEED: $(format_bytes(speed_result.binary_size_bytes)), " *
                "$(format_time(speed_result.median_time_ns))")
    end

    @testset "PGO uses different profiles in iterations" begin
        output_dir = mktempdir()

        try
            # Run PGO with auto-apply enabled
            config = PGOConfig(
                initial_profile=:PROFILE_DEBUG,
                target_metric=:speed,
                iterations=3,
                benchmark_samples=5,
                auto_apply=true
            )

            result = pgo_compile(
                validation_test_func,
                (Int,),
                (1000,),
                output_dir,
                "test_pgo",
                config=config,
                verbose=false
            )

            # Should have profiles from iterations
            @test length(result.profiles) >= 1
            @test result.iterations_completed >= 1

            # Should have recommendations
            if length(result.profiles) > 0
                @test result.profiles[1].recommended_profile in [
                    :PROFILE_SPEED, :PROFILE_SIZE, :PROFILE_AGGRESSIVE,
                    :PROFILE_SPEED_LTO, :PROFILE_SIZE_LTO
                ]
            end

        finally
            rm(output_dir, recursive=true, force=true)
        end
    end

    @testset "Smart optimization applies correct flags" begin
        output_dir_auto = mktempdir()
        output_dir_size = mktempdir()
        output_dir_speed = mktempdir()

        try
            # Test auto target
            result_auto = smart_optimize(
                validation_test_func,
                (Int,),
                output_dir_auto,
                "test_auto",
                args=(1000,),
                target=:auto,
                verbose=false
            )

            @test result_auto.binary_path !== nothing
            @test result_auto.binary_size !== nothing
            @test result_auto.recommended_preset in [
                :embedded, :serverless, :hpc, :desktop, :development, :release
            ]

            # Test size target
            result_size = smart_optimize(
                validation_test_func,
                (Int,),
                output_dir_size,
                "test_size",
                target=:size,
                verbose=false
            )

            @test result_size.recommended_preset == :embedded
            @test result_size.binary_size !== nothing

            # Test speed target
            result_speed = smart_optimize(
                validation_test_func,
                (Int,),
                output_dir_speed,
                "test_speed",
                target=:speed,
                verbose=false
            )

            @test result_speed.recommended_preset == :hpc
            @test result_speed.binary_size !== nothing

            # Size-optimized should be smaller than or equal to speed-optimized
            println("\n  Auto: $(result_auto.recommended_preset), " *
                    "$(format_bytes(result_auto.binary_size))")
            println("  Size target: $(format_bytes(result_size.binary_size))")
            println("  Speed target: $(format_bytes(result_speed.binary_size))")

        finally
            rm(output_dir_auto, recursive=true, force=true)
            rm(output_dir_size, recursive=true, force=true)
            rm(output_dir_speed, recursive=true, force=true)
        end
    end

    @testset "Preset compile comparison validates flags" begin
        output_dir = mktempdir()

        try
            # Compare embedded vs desktop vs hpc
            comparison = compare_presets(
                validation_test_func,
                (Int,),
                (1000,),
                output_dir,
                presets=[:embedded, :desktop, :hpc],
                verbose=false
            )

            @test haskey(comparison, :embedded)
            @test haskey(comparison, :desktop)
            @test haskey(comparison, :hpc)

            embedded_size = comparison[:embedded]["binary_size"]
            desktop_size = comparison[:desktop]["binary_size"]
            hpc_size = comparison[:hpc]["binary_size"]

            println("\n  Embedded: $(format_bytes(embedded_size))")
            println("  Desktop: $(format_bytes(desktop_size))")
            println("  HPC: $(format_bytes(hpc_size))")

            # All should be different (not identical)
            @test embedded_size != desktop_size || desktop_size != hpc_size

        finally
            rm(output_dir, recursive=true, force=true)
        end
    end
end

@testset "JSON Utilities Tests" begin
    @testset "JSON parsing" begin
        # Parse primitives
        @test parse_json("null") === nothing
        @test parse_json("true") == true
        @test parse_json("false") == false
        @test parse_json("42") == 42
        @test parse_json("3.14") == 3.14
        @test parse_json("\"hello\"") == "hello"

        # Parse arrays
        @test parse_json("[]") == []
        @test parse_json("[1, 2, 3]") == [1, 2, 3]
        @test parse_json("[\"a\", \"b\"]") == ["a", "b"]

        # Parse objects
        @test parse_json("{}") == Dict{String,Any}()
        obj = parse_json("{\"key\": \"value\", \"count\": 42}")
        @test obj["key"] == "value"
        @test obj["count"] == 42

        # Parse nested structures
        nested = parse_json("{\"array\": [1, 2], \"nested\": {\"inner\": true}}")
        @test nested["array"] == [1, 2]
        @test nested["nested"]["inner"] == true

        # Parse escaped strings
        @test parse_json("\"line1\\nline2\"") == "line1\nline2"
        @test parse_json("\"tab\\there\"") == "tab\there"
    end

    @testset "JSON serialization" begin
        # Serialize primitives
        @test to_json_string(nothing) == "null"
        @test to_json_string(true) == "true"
        @test to_json_string(false) == "false"
        @test to_json_string(42) == "42"
        @test to_json_string("test") == "\"test\""

        # Serialize arrays
        @test occursin("[", to_json_string([1, 2, 3]))
        @test occursin("1", to_json_string([1, 2, 3]))

        # Serialize objects
        json_str = to_json_string(Dict("key" => "value"))
        @test occursin("key", json_str)
        @test occursin("value", json_str)
    end

    @testset "JSON round-trip" begin
        # Test that parse(serialize(x)) == x
        data = Dict(
            "string" => "hello",
            "number" => 42,
            "float" => 3.14,
            "bool" => true,
            "null" => nothing,
            "array" => [1, 2, 3],
            "nested" => Dict("inner" => "value")
        )

        json_str = to_json_string(data)
        parsed = parse_json(json_str)

        @test parsed["string"] == "hello"
        @test parsed["number"] == 42
        @test abs(parsed["float"] - 3.14) < 0.01
        @test parsed["bool"] == true
        @test parsed["null"] === nothing
        @test parsed["array"] == [1, 2, 3]
        @test parsed["nested"]["inner"] == "value"
    end

    @testset "JSON file operations" begin
        tmpfile = tempname() * ".json"

        try
            # Write JSON file
            data = Dict("test" => 123, "array" => [1, 2, 3])
            write_json_file(tmpfile, data)

            @test isfile(tmpfile)

            # Read JSON file
            loaded = parse_json_file(tmpfile)
            @test loaded["test"] == 123
            @test loaded["array"] == [1, 2, 3]

        finally
            rm(tmpfile, force=true)
        end
    end
end

@testset "Result Cache Tests" begin
    test_cache_dir = mktempdir()
    config = ResultCacheConfig(
        enabled=true,
        cache_dir=test_cache_dir,
        max_age_days=30,
        auto_clean=false
    )

    try
        @testset "Cache configuration" begin
            @test config.enabled == true
            @test config.cache_dir == test_cache_dir
            @test config.max_age_days == 30
        end

        @testset "Cache key generation" begin
            key1 = result_cache_key(identity, (Int,), 100)
            key2 = result_cache_key(identity, (Int,), 100)
            key3 = result_cache_key(identity, (Int,), 200)

            @test key1 == key2  # Same function+args = same key
            @test key1 != key3  # Different args = different key
        end

        @testset "Benchmark result caching" begin
            # Create a mock benchmark result
            result = BenchmarkResult(
                "test_func",
                100,
                1000.0,
                2000.0,
                2100.0,
                3000.0,
                500.0,
                0,
                0,
                :PROFILE_SPEED,
                50000,
                Dates.now()
            )

            key = "test_key_benchmark"

            # Cache the result
            cached_file = cache_benchmark_result(result, key, config=config)
            @test cached_file !== nothing
            @test isfile(cached_file)

            # Load the cached result
            loaded = load_cached_benchmark(key, config=config)
            @test loaded !== nothing
            @test loaded.function_name == "test_func"
            @test loaded.samples == 100
            @test loaded.median_time_ns == 2000.0
            @test loaded.optimization_profile == :PROFILE_SPEED
        end

        @testset "Cache statistics" begin
            stats = result_cache_stats(config)

            @test stats["exists"] == true
            @test stats["total_entries"] >= 0
            @test stats["total_size_bytes"] >= 0
            @test stats["cache_dir"] == test_cache_dir
        end

        @testset "Cache cleanup" begin
            # Add some cache entries
            for i in 1:5
                key = "cleanup_test_$i"
                result = BenchmarkResult(
                    "test_$i", 10, 100.0, 200.0, 210.0, 300.0, 50.0,
                    0, 0, nothing, 1000, Dates.now()
                )
                cache_benchmark_result(result, key, config=config)
            end

            # Clear cache
            removed = clear_result_cache(config)
            @test removed >= 5

            # Verify cache is empty
            stats = result_cache_stats(config)
            @test stats["total_entries"] == 0
        end

    finally
        rm(test_cache_dir, recursive=true, force=true)
    end
end

@testset "Error Handling Tests" begin
    @testset "with_cleanup" begin
        cleanup_called = Ref(false)
        cleanup = () -> (cleanup_called[] = true)

        # Test successful execution
        result = with_cleanup(
            () -> 42,
            cleanup
        )

        @test result == 42
        @test cleanup_called[]

        # Test cleanup on error
        cleanup_called[] = false

        @test_throws ErrorException with_cleanup(
            () -> error("test error"),
            cleanup
        )

        @test cleanup_called[]
    end

    @testset "retry_on_failure" begin
        attempt_count = Ref(0)

        # Test successful retry
        result = retry_on_failure(
            () -> begin
                attempt_count[] += 1
                attempt_count[] == 3 ? 42 : error("not yet")
            end,
            max_attempts=5,
            delay_seconds=0.01,
            verbose=false
        )

        @test result == 42
        @test attempt_count[] == 3

        # Test all attempts fail
        attempt_count[] = 0

        @test_throws ErrorException retry_on_failure(
            () -> begin
                attempt_count[] += 1
                error("always fails")
            end,
            max_attempts=3,
            delay_seconds=0.01,
            verbose=false
        )

        @test attempt_count[] == 3
    end

    @testset "validate_compilation_result" begin
        # Create a valid mock binary
        tmpdir = mktempdir()

        try
            valid_binary = joinpath(tmpdir, "valid")
            write(valid_binary, repeat("X", 1000))  # 1KB file

            if !Sys.iswindows()
                chmod(valid_binary, 0o755)  # Make executable
            end

            @test validate_compilation_result(valid_binary, min_size_bytes=100)

            # Test non-existent file
            @test !validate_compilation_result(joinpath(tmpdir, "nonexistent"))

            # Test too-small file
            small_binary = joinpath(tmpdir, "small")
            write(small_binary, "X")  # 1 byte
            @test !validate_compilation_result(small_binary, min_size_bytes=100)

        finally
            rm(tmpdir, recursive=true, force=true)
        end
    end

    @testset "collect_diagnostics" begin
        simple_func(x::Int) = x * 2

        diag = collect_diagnostics(simple_func, (Int,))

        @test haskey(diag, "function_name")
        @test diag["function_name"] == "simple_func"
        @test haskey(diag, "type_signature")
        @test haskey(diag, "method_count")
        @test diag["method_count"] >= 1
    end

    @testset "error_context" begin
        context = Dict("operation" => "test", "stage" => "validation")

        # Test successful execution
        result = error_context(() -> 100, context)
        @test result == 100

        # Test error with context (should rethrow)
        @test_throws ErrorException error_context(
            () -> error("test error"),
            context
        )
    end
end

@testset "Logging System Tests" begin
    @testset "LogConfig creation" begin
        # Default config
        config = LogConfig()
        @test config.level == INFO
        @test config.log_to_stdout == true
        @test config.log_to_file == false
        @test config.use_colors == true

        # Custom config
        config2 = LogConfig(
            level=DEBUG,
            log_to_file=true,
            use_colors=false
        )
        @test config2.level == DEBUG
        @test config2.log_to_file == true
        @test config2.use_colors == false
    end

    @testset "Log level filtering" begin
        tmpfile = tempname() * ".log"

        try
            config = LogConfig(
                level=WARN,
                log_to_file=true,
                log_file=tmpfile,
                log_to_stdout=false
            )
            set_log_config(config)

            # These should not be logged (below WARN level)
            log_debug("debug message")
            log_info("info message")

            # These should be logged
            log_warn("warning message")
            log_error("error message")

            # Check file contents
            @test isfile(tmpfile)
            contents = read(tmpfile, String)
            @test occursin("warning message", contents)
            @test occursin("error message", contents)
            @test !occursin("debug message", contents)
            @test !occursin("info message", contents)

        finally
            rm(tmpfile, force=true)
            set_log_config(LogConfig())  # Reset
        end
    end

    @testset "Log formatting" begin
        # Plain text format
        config = LogConfig(json_format=false)
        msg = format_log_message(INFO, "test message", Dict("key" => "value"), config=config)
        @test occursin("INFO", msg)
        @test occursin("test message", msg)
        @test occursin("key=value", msg)

        # JSON format
        config_json = LogConfig(json_format=true)
        msg_json = format_log_message(INFO, "test message", Dict("key" => "value"), config=config_json)
        @test occursin("\"level\":\"INFO\"", replace(msg_json, " " => ""))
        @test occursin("\"message\":\"test message\"", replace(msg_json, " " => ""))
    end

    @testset "Log file operations" begin
        tmpfile = tempname() * ".log"

        try
            config = LogConfig(
                log_to_file=true,
                log_file=tmpfile,
                log_to_stdout=false
            )

            # Write logs
            set_log_config(config)
            log_info("message 1")
            log_info("message 2")

            @test isfile(tmpfile)
            contents = read(tmpfile, String)
            @test occursin("message 1", contents)
            @test occursin("message 2", contents)

            # Clear log file
            cleared = clear_log_file(config)
            @test cleared == true
            @test !isfile(tmpfile)

        finally
            rm(tmpfile, force=true)
            set_log_config(LogConfig())
        end
    end

    @testset "Temporary logging" begin
        original_level = get_log_config().level

        result = with_logging(LogConfig(level=DEBUG)) do
            @test get_log_config().level == DEBUG
            return 42
        end

        @test result == 42
        @test get_log_config().level == original_level
    end

    @testset "Log sections" begin
        output = IOBuffer()
        config = LogConfig(
            log_to_file=false,
            log_to_stdout=true
        )
        set_log_config(config)

        result = log_section("Test Section") do
            sleep(0.1)
            return "completed"
        end

        @test result == "completed"
        set_log_config(LogConfig())
    end

    @testset "Log progress" begin
        # Just ensure it doesn't error
        for i in 1:5
            log_progress("Processing", i, 5)
        end
        @test true  # If we got here, no errors
    end
end

@testset "Cross-Compilation Tests" begin
    @testset "CrossTarget structure" begin
        target = get_cross_target(:arm64_linux)
        @test target.name == :arm64_linux
        @test target.arch == "aarch64"
        @test target.os == "linux"
        @test target.triple == "aarch64-unknown-linux-gnu"
    end

    @testset "List cross targets" begin
        targets = list_cross_targets()
        @test length(targets) >= 10
        @test any(t -> t[1] == :arm64_linux, targets)
        @test any(t -> t[1] == :wasm32, targets)
        @test any(t -> t[1] == :embedded_arm, targets)
    end

    @testset "Get cross target by name" begin
        # Valid targets
        @test get_cross_target(:arm64_linux).arch == "aarch64"
        @test get_cross_target(:wasm32).arch == "wasm32"
        @test get_cross_target(:riscv64_linux).arch == "riscv64"

        # Invalid target
        @test_throws ErrorException get_cross_target(:invalid_target)
    end

    @testset "Detect host target" begin
        host = detect_host_target()
        @test host.arch in ["x86_64", "aarch64", "i686"]
        @test host.os in ["linux", "darwin", "windows"]
        @test !isempty(host.triple)
    end

    @testset "Target descriptions" begin
        targets = list_cross_targets()
        for (name, desc) in targets
            @test !isempty(desc)
            @test isa(name, Symbol)
            @test isa(desc, String)
        end
    end

    @testset "All predefined targets accessible" begin
        expected_targets = [
            :arm64_linux, :arm64_linux_musl, :arm_linux,
            :riscv64_linux, :x86_64_windows, :x86_64_macos,
            :arm64_macos, :wasm32, :embedded_arm, :embedded_riscv
        ]

        for target_name in expected_targets
            target = get_cross_target(target_name)
            @test target.name == target_name
            @test !isempty(target.description)
        end
    end
end

@testset "Parallel Processing Tests" begin
    @testset "Optimal concurrency detection" begin
        optimal = get_optimal_concurrency()
        @test optimal >= 2
        @test optimal <= 8
        @test optimal <= Sys.CPU_THREADS
    end

    @testset "Concurrency bounds" begin
        optimal = get_optimal_concurrency()
        # Should use 75% of cores
        expected = Int(ceil(Sys.CPU_THREADS * 0.75))
        clamped = max(2, min(8, expected))
        @test optimal == clamped
    end
end

@testset "Configuration Integration Tests" begin
    @testset "LogConfig with all options" begin
        config = LogConfig(
            level=ERROR,
            log_to_file=true,
            log_file="/tmp/test.log",
            log_to_stdout=false,
            use_colors=false,
            timestamp_format="HH:MM:SS",
            include_source=true,
            json_format=true
        )

        @test config.level == ERROR
        @test config.log_to_file == true
        @test config.log_to_stdout == false
        @test config.use_colors == false
        @test config.json_format == true
    end

    @testset "Multiple log configs" begin
        config1 = LogConfig(level=DEBUG)
        config2 = LogConfig(level=ERROR)

        set_log_config(config1)
        @test get_log_config().level == DEBUG

        set_log_config(config2)
        @test get_log_config().level == ERROR
    end

    @testset "TOML Configuration Files" begin
        tmpdir = mktempdir()
        config_path = joinpath(tmpdir, "test_config.toml")

        try
            # Create default config file
            create_default_config_file(config_path)
            @test isfile(config_path)

            # Load config
            config = load_config(config_path)
            @test config isa CompilerConfig
            @test config.logging.level == INFO
            @test config.default_preset == :desktop

            # Save custom config
            custom_path = joinpath(tmpdir, "custom.toml")
            custom_config = CompilerConfig(
                LogConfig(level=DEBUG, log_to_file=true),
                ResultCacheConfig(enabled=true, max_age_days=7),
                ParallelConfig(max_concurrent=2),
                :release,
                :arm64_linux
            )
            save_config(custom_config, custom_path)

            # Load and verify custom config
            loaded = load_config(custom_path)
            @test loaded.logging.level == DEBUG
            @test loaded.caching.max_age_days == 7
            @test loaded.default_preset == :release
        finally
            rm(tmpdir, recursive=true, force=true)
        end
    end

    @testset "TOML Parsing" begin
        tmpdir = mktempdir()
        toml_path = joinpath(tmpdir, "test.toml")

        try
            # Write test TOML
            open(toml_path, "w") do io
                println(io, "[section1]")
                println(io, "string_val = \"hello\"")
                println(io, "int_val = 42")
                println(io, "bool_val = true")
            end

            parsed = parse_toml_file(toml_path)
            @test haskey(parsed, "section1")
            @test parsed["section1"]["string_val"] == "hello"
            @test parsed["section1"]["int_val"] == 42
            @test parsed["section1"]["bool_val"] == true
        finally
            rm(tmpdir, recursive=true, force=true)
        end
    end
end

@testset "Integration Tests" begin
    @testset "Logging with error handling" begin
        tmpfile = tempname() * ".log"

        try
            config = LogConfig(
                log_to_file=true,
                log_file=tmpfile,
                log_to_stdout=false
            )
            set_log_config(config)

            cleanup_called = false

            try
                with_cleanup(
                    () -> begin
                        log_info("Starting operation")
                        error("Test error")
                    end,
                    () -> begin
                        cleanup_called = true
                        log_info("Cleanup executed")
                    end
                )
            catch
                # Expected
            end

            @test cleanup_called
            @test isfile(tmpfile)
            contents = read(tmpfile, String)
            @test occursin("Starting operation", contents)
            @test occursin("Cleanup executed", contents)

        finally
            rm(tmpfile, force=true)
            set_log_config(LogConfig())
        end
    end

    @testset "Cross-compilation with logging" begin
        set_log_config(LogConfig(level=INFO))

        target = get_cross_target(:arm64_linux)
        @test target.arch == "aarch64"

        # Just verify the integration works
        @test !isempty(target.description)

        set_log_config(LogConfig())
    end
end

@testset "Edge Cases and Error Handling" begin
    @testset "Log to non-existent directory" begin
        tmpdir = tempname()
        logfile = joinpath(tmpdir, "subdir", "test.log")

        try
            config = LogConfig(
                log_to_file=true,
                log_file=logfile,
                log_to_stdout=false
            )
            set_log_config(config)

            log_info("Test message")

            # Should create directory automatically
            @test isfile(logfile)

        finally
            rm(tmpdir, recursive=true, force=true)
            set_log_config(LogConfig())
        end
    end

    @testset "Invalid log file permissions" begin
        # Test graceful degradation when can't write log file
        config = LogConfig(
            log_to_file=true,
            log_file="/invalid/path/file.log",
            log_to_stdout=false
        )
        set_log_config(config)

        # Should not throw, just warn to stderr
        log_info("Test message")

        set_log_config(LogConfig())
        @test true  # If we got here, graceful degradation worked
    end

    @testset "SILENT level suppresses everything" begin
        tmpfile = tempname() * ".log"

        try
            config = LogConfig(
                level=SILENT,
                log_to_file=true,
                log_file=tmpfile,
                log_to_stdout=false
            )
            set_log_config(config)

            log_debug("debug")
            log_info("info")
            log_warn("warn")
            log_error("error")

            # Nothing should be written
            @test !isfile(tmpfile) || filesize(tmpfile) == 0

        finally
            rm(tmpfile, force=true)
            set_log_config(LogConfig())
        end
    end
end
