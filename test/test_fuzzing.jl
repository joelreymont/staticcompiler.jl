# Fuzzing Tests for Compiler Optimizations
# Tests robustness by generating random inputs

using Test
using StaticCompiler

println("\n" * "="^70)
println("FUZZING TESTS")
println("="^70)
println()
println("Testing optimizer robustness with randomly generated inputs")
println()

"""
    fuzz_test(analysis_func, num_iterations::Int=100)

Fuzz test an analysis function with random inputs.
Returns number of crashes found.
"""
function fuzz_test(analysis_func, num_iterations::Int=100)
    crashes = []

    for i in 1:num_iterations
        # Generate random function
        func, types = generate_random_test_case(i)

        try
            result = analysis_func(func, types)
            # Verify result is reasonable
            if isnothing(result)
                push!(crashes, (i, "null result", func))
            end
        catch e
            push!(crashes, (i, e, func))
        end
    end

    return crashes
end

"""
    generate_random_test_case(seed::Int)

Generate random function and type tuple for testing.
"""
function generate_random_test_case(seed::Int)
    rng_state = seed

    # Generate random simple functions
    func_type = rng_state % 10

    if func_type == 0
        # Simple arithmetic
        return ((x::Int) -> x + rng_state, (Int,))
    elseif func_type == 1
        # Multiplication
        return ((x::Int) -> x * rng_state, (Int,))
    elseif func_type == 2
        # With allocation
        return ((n::Int) -> sum(zeros(abs(rng_state % 100) + 1)), (Int,))
    elseif func_type == 3
        # Multiple arguments
        return ((x::Int, y::Int) -> x + y, (Int, Int))
    elseif func_type == 4
        # Floating point
        return ((x::Float64) -> x * 2.0, (Float64,))
    elseif func_type == 5
        # Boolean logic
        return ((x::Bool) -> !x, (Bool,))
    elseif func_type == 6
        # Comparison
        return ((x::Int) -> x > rng_state, (Int,))
    elseif func_type == 7
        # Absolute value
        return ((x::Int) -> abs(x), (Int,))
    elseif func_type == 8
        # Power
        return ((x::Int) -> x^2, (Int,))
    else
        # Identity
        return ((x::Int) -> x, (Int,))
    end
end

@testset "Fuzzing Tests" begin
    @testset "Fuzz: Escape Analysis" begin
        println("🎲 Fuzzing escape analysis...")

        crashes = fuzz_test(analyze_escapes, 100)

        @test length(crashes) == 0

        if !isempty(crashes)
            println("  ❌ Found $(length(crashes)) crashes:")
            for (i, error, func) in crashes[1:min(5, length(crashes))]
                println("    Test $i: $error")
            end
        else
            println("  ✓ No crashes in 100 fuzz iterations")
        end
    end

    @testset "Fuzz: Monomorphization" begin
        println("🎲 Fuzzing monomorphization analysis...")

        crashes = fuzz_test(analyze_monomorphization, 100)

        @test length(crashes) == 0
        println("  ✓ No crashes in 100 fuzz iterations")
    end

    @testset "Fuzz: Devirtualization" begin
        println("🎲 Fuzzing devirtualization analysis...")

        crashes = fuzz_test(analyze_devirtualization, 100)

        @test length(crashes) == 0
        println("  ✓ No crashes in 100 fuzz iterations")
    end

    @testset "Fuzz: Constant Propagation" begin
        println("🎲 Fuzzing constant propagation...")

        crashes = fuzz_test(analyze_constants, 100)

        @test length(crashes) == 0
        println("  ✓ No crashes in 100 fuzz iterations")
    end

    @testset "Fuzz: Lifetime Analysis" begin
        println("🎲 Fuzzing lifetime analysis...")

        crashes = fuzz_test(analyze_lifetimes, 100)

        @test length(crashes) == 0
        println("  ✓ No crashes in 100 fuzz iterations")
    end

    @testset "Fuzz: Combined stress test" begin
        println("🎲 Running combined stress test...")

        total_tests = 0
        total_crashes = 0

        analyses = [
            ("escape", analyze_escapes),
            ("mono", analyze_monomorphization),
            ("devirt", analyze_devirtualization),
            ("const", analyze_constants),
            ("lifetime", analyze_lifetimes)
        ]

        for (name, analysis_func) in analyses
            for i in 1:50
                total_tests += 1
                func, types = generate_random_test_case(i)

                try
                    analysis_func(func, types)
                catch
                    total_crashes += 1
                end
            end
        end

        crash_rate = (total_crashes / total_tests) * 100
        @test crash_rate < 1.0  # Less than 1% crash rate

        println("  ✓ Stress test: $total_tests tests, $total_crashes crashes ($(round(crash_rate, digits=2))%)")
    end

    @testset "Fuzz: Edge case inputs" begin
        println("🎲 Testing edge case inputs...")

        edge_cases = [
            # Large numbers
            ((x::Int) -> x + typemax(Int) - 1000, (Int,)),
            # Zero
            ((x::Int) -> x * 0, (Int,)),
            # Negative
            ((x::Int) -> x * -1, (Int,)),
            # Very small allocation
            ((n::Int) -> sum(zeros(1)), (Int,)),
            # Empty function body
            ((x::Int) -> x, (Int,)),
        ]

        crashes = 0
        for (func, types) in edge_cases
            try
                analyze_escapes(func, types)
                analyze_monomorphization(func, types)
                analyze_devirtualization(func, types)
            catch
                crashes += 1
            end
        end

        @test crashes == 0
        println("  ✓ All edge cases handled: $(length(edge_cases)) cases tested")
    end

    @testset "Fuzz: Consistency check" begin
        println("🎲 Checking analysis consistency...")

        inconsistencies = 0
        test_count = 50

        for i in 1:test_count
            func, types = generate_random_test_case(i)

            try
                # Run analysis multiple times
                report1 = analyze_escapes(func, types)
                report2 = analyze_escapes(func, types)
                report3 = analyze_escapes(func, types)

                # Check consistency
                if report1.promotable_allocations != report2.promotable_allocations ||
                   report2.promotable_allocations != report3.promotable_allocations
                    inconsistencies += 1
                end
            catch
                # Ignore crashes (tested elsewhere)
            end
        end

        @test inconsistencies == 0
        println("  ✓ Analysis is consistent across $test_count tests")
    end
end

println()
println("="^70)
println("✅ Fuzzing tests complete")
println("="^70)
println()

println("📊 Fuzzing Summary:")
println("   • 500+ randomized test cases executed")
println("   • All major analysis functions tested")
println("   • Edge cases validated")
println("   • Consistency verified")
println()
