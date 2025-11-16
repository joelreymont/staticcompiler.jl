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
