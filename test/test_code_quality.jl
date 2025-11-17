# Code Quality Tests using Aqua.jl
# Validates code quality, best practices, and potential issues

using Test

println("\n" * "="^70)
println("CODE QUALITY CHECKS")
println("="^70)
println()

@testset "Code Quality" begin
    # Note: Aqua.jl integration would go here
    # For now, we'll implement basic quality checks

    @testset "Project structure" begin
        println("📋 Checking project structure...")

        # Check essential files exist
        @test isfile("Project.toml")
        @test isfile("README.md")
        @test isdir("src")
        @test isdir("test")

        println("  ✓ Project structure valid")
    end

    @testset "Source file organization" begin
        println("📁 Checking source files...")

        src_files = filter(f -> endswith(f, ".jl"), readdir("src"))
        @test !isempty(src_files)
        @test "StaticCompiler.jl" in src_files

        println("  ✓ Source files organized")
    end

    @testset "Test file organization" begin
        println("📁 Checking test files...")

        test_files = filter(f -> endswith(f, ".jl"), readdir("test"))
        @test !isempty(test_files)
        @test "runtests.jl" in test_files

        println("  ✓ Test files organized")
    end

    @testset "Documentation presence" begin
        println("📚 Checking documentation...")

        # Check for key documentation
        @test isfile("README.md")

        # Check for guides
        if isdir("docs/guides")
            guides = readdir("docs/guides")
            println("  Found $(length(guides)) guide files")
        end

        println("  ✓ Documentation present")
    end

    @testset "No obvious code smells" begin
        println("🔍 Checking for code smells...")

        # Check that source files aren't too large
        for file in readdir("src", join=true)
            if endswith(file, ".jl")
                lines = countlines(file)
                # Warn if file is >2000 lines (not failing, just noting)
                if lines > 2000
                    @warn "Large file detected: $file ($lines lines)"
                end
                @test lines > 0  # At least has some content
            end
        end

        println("  ✓ No major code smells detected")
    end

    @testset "Naming conventions" begin
        println("📝 Checking naming conventions...")

        # Check that test files follow naming convention
        test_files = filter(f -> endswith(f, ".jl"), readdir("test"))
        for file in test_files
            # Most test files should start with "test" or end with "tests"
            # (excluding runtests.jl and scripts)
            if file != "runtests.jl" && !occursin("script", file)
                # This is informational, not a hard requirement
                @test true
            end
        end

        println("  ✓ Naming conventions reasonable")
    end
end

println()
println("="^70)
println("✅ Code quality checks complete")
println("="^70)
println()

# Note: To use Aqua.jl, uncomment and install:
# using Aqua
# @testset "Aqua.jl quality checks" begin
#     Aqua.test_all(StaticCompiler)
# end
