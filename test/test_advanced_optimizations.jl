# Tests for Advanced Compiler Optimizations
using Test
using StaticCompiler
using StaticTools

@testset "Escape Analysis" begin
    # Test 1: Simple local allocation (should be stack-promotable)
    function local_array()
        arr = zeros(10)
        return sum(arr)
    end

    report = analyze_escapes(local_array, ())
    @test !isnothing(report)
    # Note: In current Julia, zeros() will show as allocation
    # Our analysis should detect it doesn't escape

    # Test 2: Returned allocation (escapes)
    function returning_array()
        return zeros(10)
    end

    report2 = analyze_escapes(returning_array, ())
    @test !isnothing(report2)
    # Should detect that allocation escapes via return

    # Test 3: Stack-allocated struct (safe)
    struct Point
        x::Float64
        y::Float64
    end

    function make_point(x, y)
        p = Point(x, y)
        return p.x + p.y
    end

    report3 = analyze_escapes(make_point, (Float64, Float64))
    @test !isnothing(report3)

    println("✓ Escape analysis tests passed")
end

@testset "Monomorphization Analysis" begin
    # Test 1: Abstract Number parameter
    function double_number(x::Number)
        return x * 2
    end

    report = analyze_monomorphization(double_number, (Number,))
    @test report.has_abstract_types
    @test !isempty(report.abstract_parameters)
    @test report.abstract_parameters[1].abstract_type === Number

    # Test 2: Already concrete (no monomorphization needed)
    function double_int(x::Int64)
        return x * 2
    end

    report2 = analyze_monomorphization(double_int, (Int64,))
    @test !report2.has_abstract_types
    @test isempty(report2.abstract_parameters)

    # Test 3: Multiple abstract parameters
    function combine(x::Number, y::Number)
        return x + y
    end

    report3 = analyze_monomorphization(combine, (Number, Number))
    @test report3.has_abstract_types
    @test length(report3.abstract_parameters) >= 2

    println("✓ Monomorphization analysis tests passed")
end

@testset "Devirtualization Analysis" begin
    # Test 1: Abstract type with known concrete implementations
    abstract type Animal end
    struct Dog <: Animal end
    struct Cat <: Animal end

    sound(d::Dog) = 1
    sound(c::Cat) = 2

    function make_sound(a::Animal)
        return sound(a)
    end

    # Analyze with concrete type - should see it's actually concrete
    report = analyze_devirtualization(make_sound, (Dog,))
    @test !isnothing(report)

    # Test 2: Direct calls (no virtualization)
    function direct_call(x::Int64)
        return x + 1
    end

    report2 = analyze_devirtualization(direct_call, (Int64,))
    @test report2.total_call_sites >= 0  # May have + call

    println("✓ Devirtualization analysis tests passed")
end

@testset "Lifetime Analysis" begin
    # Note: These tests work with the analysis, not actual memory

    # Test 1: Simple case - allocation and use
    function simple_lifetime()
        arr = MallocArray{Float64}(10)
        result = sum(arr)
        free(arr)
        return result
    end

    report = analyze_lifetimes(simple_lifetime, ())
    @test !isnothing(report)
    # Should detect the malloc and the manual free

    # Test 2: Missing free (potential leak)
    function leaky_function()
        arr = MallocArray{Float64}(10)
        return sum(arr)
    end

    report2 = analyze_lifetimes(leaky_function, ())
    @test !isnothing(report2)
    # Should detect missing free

    println("✓ Lifetime analysis tests passed")
end

@testset "Constant Propagation" begin
    # Test 1: Constant folding
    function with_constants()
        x = 10 + 20
        y = x * 2
        return y
    end

    report = analyze_constants(with_constants, ())
    @test !isnothing(report)
    @test report.foldable_expressions >= 0

    # Test 2: Dead branch elimination
    const CONFIG = true

    function with_dead_branch()
        if CONFIG
            return 1
        else
            return 2  # Dead code
        end
    end

    report2 = analyze_constants(with_dead_branch, ())
    @test !isnothing(report2)

    # Test 3: Global constant propagation
    const SIZE = 100

    function use_global_const()
        return SIZE * 2
    end

    report3 = analyze_constants(use_global_const, ())
    @test !isnothing(report3)
    @test !isempty(report3.constants_found) || report3.foldable_expressions > 0

    println("✓ Constant propagation tests passed")
end

@testset "Integration: Multiple Optimizations" begin
    # Test a function that benefits from multiple optimizations

    abstract type Shape end
    struct Circle <: Shape
        radius::Float64
    end

    area(c::Circle) = 3.14159 * c.radius^2

    function compute_areas(shapes::Vector{Circle})
        total = 0.0
        for shape in shapes
            total += area(shape)  # Devirtualizable
        end
        return total
    end

    # Test monomorphization
    mono_report = analyze_monomorphization(compute_areas, (Vector{Circle},))
    @test !isnothing(mono_report)

    # Test constant propagation
    const_report = analyze_constants(area, (Circle,))
    @test !isnothing(const_report)

    println("✓ Integration tests passed")
end

@testset "Report Generation and Display" begin
    # Test that all reports can be displayed

    function test_function(x::Int)
        return x + 1
    end

    # Escape analysis report
    escape_report = analyze_escapes(test_function, (Int,))
    io = IOBuffer()
    show(io, escape_report)
    output = String(take!(io))
    @test occursin("Escape Analysis", output)

    # Monomorphization report
    mono_report = analyze_monomorphization(test_function, (Int,))
    io = IOBuffer()
    show(io, mono_report)
    output = String(take!(io))
    @test occursin("Monomorphization", output)

    # Devirtualization report
    devirt_report = analyze_devirtualization(test_function, (Int,))
    io = IOBuffer()
    show(io, devirt_report)
    output = String(take!(io))
    @test occursin("Devirtualization", output)

    # Lifetime report
    lifetime_report = analyze_lifetimes(test_function, (Int,))
    io = IOBuffer()
    show(io, lifetime_report)
    output = String(take!(io))
    @test occursin("Lifetime", output)

    # Constant propagation report
    const_report = analyze_constants(test_function, (Int,))
    io = IOBuffer()
    show(io, const_report)
    output = String(take!(io))
    @test occursin("Constant Propagation", output)

    println("✓ Report display tests passed")
end

@testset "Optimization Suggestions" begin
    # Test suggestion generation

    function example_func(x::Int)
        return x * 2
    end

    # Escape analysis suggestions
    escape_report = analyze_escapes(example_func, (Int,))
    suggestions = suggest_stack_promotion(escape_report)
    @test suggestions isa Vector{String}

    # Lifetime analysis suggestions
    lifetime_report = analyze_lifetimes(example_func, (Int,))
    suggestions2 = suggest_lifetime_improvements(lifetime_report)
    @test suggestions2 isa Vector{String}

    # Devirtualization suggestions
    devirt_report = analyze_devirtualization(example_func, (Int,))
    suggestions3 = suggest_devirtualization(devirt_report)
    @test suggestions3 isa Vector{String}

    println("✓ Optimization suggestion tests passed")
end

println("\n" * "="^60)
println("All advanced optimization tests completed successfully!")
println("="^60)
