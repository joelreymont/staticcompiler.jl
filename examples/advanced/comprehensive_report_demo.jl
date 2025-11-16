#!/usr/bin/env julia

# Comprehensive Reporting Demo
# Shows how to generate complete analysis reports

using StaticCompiler

println("=== Comprehensive Reporting Demo ===\n")

# Example function
function calculate_factorial(n::Int)
    if n <= 1
        return 1
    end
    return n * calculate_factorial(n - 1)
end

# Generate comprehensive report
println("1️⃣  Generating comprehensive report...")
report = generate_comprehensive_report(
    calculate_factorial,
    (Int,),
    compile=false,  # Set to true to also compile
    verbose=false
)

println("\n📊 Overall Scores:")
println("   Overall:     $(round(report.overall_score, digits=1))/100")
println("   Performance: $(round(report.performance_score, digits=1))/100")
println("   Size:        $(round(report.size_score, digits=1))/100")
println("   Security:    $(round(report.security_score, digits=1))/100")

# Export reports to different formats
println("\n2️⃣  Exporting reports...")
output_dir = mktempdir()

try
    # Export to JSON
    json_file = joinpath(output_dir, "report.json")
    export_report_json(report, json_file)

    # Export to Markdown
    md_file = joinpath(output_dir, "report.md")
    export_report_markdown(report, md_file)

    println("   Reports saved to: $output_dir")

    # Show a preview of the markdown
    println("\n3️⃣  Markdown Report Preview:")
    println("   " * "-"^60)
    content = read(md_file, String)
    for line in split(content, "\n")[1:min(20, end)]
        println("   ", line)
    end
    if length(split(content, "\n")) > 20
        println("   ... (truncated)")
    end
    println("   " * "-"^60)
catch e
    println("   ⚠️  Report export skipped: $e")
end

# Example: Compare two implementations
println("\n4️⃣  Comparing implementations...")

# Implementation 1: Recursive (original)
function factorial_recursive(n::Int)
    if n <= 1
        return 1
    end
    return n * factorial_recursive(n - 1)
end

# Implementation 2: Iterative
function factorial_iterative(n::Int)
    result = 1
    for i in 2:n
        result *= i
    end
    return result
end

report1 = generate_comprehensive_report(factorial_recursive, (Int,), verbose=false)
report2 = generate_comprehensive_report(factorial_iterative, (Int,), verbose=false)

# Compare them
compare_reports(report1, report2, verbose=true)

# Summary
println("\n📝 Comprehensive Reporting Features:")
println("   ✅ Combines all analysis tools in one report")
println("   ✅ Export to JSON and Markdown formats")
println("   ✅ Compare different implementations")
println("   ✅ Track improvements over time")
println("   ✅ CI/CD integration ready")

println("\n💡 Usage Tips:")
println("   - Generate reports in CI pipelines for tracking")
println("   - Export to JSON for automated processing")
println("   - Use Markdown reports for documentation")
println("   - Compare reports to validate refactoring")

# Cleanup
try
    rm(output_dir, recursive=true)
catch
end
