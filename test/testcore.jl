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
