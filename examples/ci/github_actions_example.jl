#!/usr/bin/env julia

# GitHub Actions CI Integration Example
# This shows how to use StaticCompiler.jl in CI/CD pipelines

using StaticCompiler

println("🤖 CI/CD Integration Example\n")

# Detect CI environment
ci_info = detect_ci_environment()
if ci_info.detected
    println("✅ Running in $(ci_info.system)")
else
    println("ℹ️  Not running in CI (simulating)")
end

# Example function to compile
function main()
    println("Hello from statically compiled Julia!")
    return 0
end

# Configure CI checks
config = CIConfig(
    fail_on_allocations = false,          # Don't fail on allocations (for demo)
    fail_on_security_issues = true,       # Fail on security issues
    max_binary_size_kb = 1000,            # Maximum 1MB binary
    min_performance_score = 50.0,         # Minimum 50/100 performance
    min_security_score = 80.0,            # Minimum 80/100 security
    generate_reports = true,              # Generate reports
    report_formats = [:json, :markdown],  # Both formats
    cache_enabled = true                  # Enable caching
)

println("\n📋 CI Configuration:")
println("   Max Binary Size: $(config.max_binary_size_kb) KB")
println("   Min Performance: $(config.min_performance_score)/100")
println("   Min Security: $(config.min_security_score)/100")
println("   Fail on Allocations: $(config.fail_on_allocations)")
println("   Fail on Security: $(config.fail_on_security_issues)")

# Run CI compilation and tests
output_dir = mktempdir()
println("\n🔨 Running CI compilation and tests...")

exit_code = ci_compile_and_test(
    main,
    (),
    output_dir,
    "ci_example",
    config=config
)

if exit_code == 0
    println("\n✅ CI checks passed!")

    # Show generated reports
    report_dir = joinpath(output_dir, "reports")
    if isdir(report_dir)
        println("\n📄 Generated Reports:")
        for file in readdir(report_dir)
            filepath = joinpath(report_dir, file)
            size_kb = round(filesize(filepath) / 1024, digits=1)
            println("   • $file ($size_kb KB)")
        end
    end
else
    println("\n❌ CI checks failed with exit code: $exit_code")
end

# Generate CI badge info
println("\n🏷️  CI Badge Information:")
println("   Use this for shields.io or similar badge services")

# Example for creating a badge
println("\n📊 Example GitHub Actions Workflow:")
println("   See GITHUB_ACTIONS_EXAMPLE for complete workflow YAML")

# Show first few lines of the example
lines = split(GITHUB_ACTIONS_EXAMPLE, "\n")
for line in lines[1:min(15, end)]
    println("   ", line)
end
println("   ... (see full example in ci_integration.jl)")

# Cleanup
println("\n🧹 Cleaning up...")
try
    rm(output_dir, recursive=true)
    println("   ✓ Temp files removed")
catch e
    println("   ⚠️  Cleanup failed: $e")
end

println("\n✅ CI Integration Demo Complete!")
println("\n💡 Next Steps:")
println("   1. Copy the GitHub Actions workflow to .github/workflows/")
println("   2. Adjust CIConfig parameters for your needs")
println("   3. Commit and push to trigger CI")
println("   4. View reports in CI artifacts")

# Return exit code for actual CI usage
exit(exit_code)
