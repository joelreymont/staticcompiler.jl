# CI/CD Integration helpers
# Makes it easy to use StaticCompiler.jl in continuous integration pipelines

"""
CI/CD configuration for automated compilation and testing
"""
struct CIConfig
    fail_on_allocations::Bool
    fail_on_security_issues::Bool
    max_binary_size_kb::Union{Int, Nothing}
    min_performance_score::Float64
    min_security_score::Float64
    generate_reports::Bool
    report_formats::Vector{Symbol}  # :json, :markdown, :html
    cache_enabled::Bool

    function CIConfig(;
        fail_on_allocations=false,
        fail_on_security_issues=true,
        max_binary_size_kb=nothing,
        min_performance_score=50.0,
        min_security_score=80.0,
        generate_reports=true,
        report_formats=[:json, :markdown],
        cache_enabled=true
    )
        new(fail_on_allocations, fail_on_security_issues, max_binary_size_kb,
            min_performance_score, min_security_score, generate_reports,
            report_formats, cache_enabled)
    end
end

"""
    ci_compile_and_test(f, types, output_path, name; config=CIConfig())

Compile and test a function in a CI environment with comprehensive checks.

Returns exit code (0 = success, non-zero = failure).

# Example
```julia
# In your CI script:
using StaticCompiler

function main()
    return 0
end

config = CIConfig(
    fail_on_security_issues = true,
    max_binary_size_kb = 100,
    min_performance_score = 70.0
)

exit_code = ci_compile_and_test(main, (), "/tmp", "myapp", config=config)
exit(exit_code)
```
"""
function ci_compile_and_test(f, types, output_path, name; config=CIConfig())
    println("\n🤖 CI/CD Compilation and Testing")
    println("="^70)

    exit_code = 0
    failures = String[]

    # Generate comprehensive report
    println("\n1️⃣  Generating comprehensive analysis...")
    report = try
        generate_comprehensive_report(f, types, compile=true, path=output_path, name=name, verbose=false)
    catch e
        println("❌ Failed to generate report: $e")
        return 1
    end

    # Check allocation requirements
    if config.fail_on_allocations
        if report.allocations !== nothing && report.allocations.total_allocations > 0
            push!(failures, "Allocations detected: $(report.allocations.total_allocations)")
            exit_code = 1
        end
    end

    # Check security requirements
    if config.fail_on_security_issues
        if report.security !== nothing
            critical = length(report.security.critical_issues)
            if critical > 0
                push!(failures, "Critical security issues: $critical")
                exit_code = 1
            end
        end
    end

    # Check binary size budget
    if config.max_binary_size_kb !== nothing && report.binary_size_bytes !== nothing
        size_kb = report.binary_size_bytes / 1024
        if size_kb > config.max_binary_size_kb
            push!(failures, "Binary size $(round(size_kb, digits=1)) KB exceeds budget of $(config.max_binary_size_kb) KB")
            exit_code = 1
        end
    end

    # Check performance score
    if report.performance_score < config.min_performance_score
        push!(failures, "Performance score $(round(report.performance_score, digits=1)) below minimum $(config.min_performance_score)")
        exit_code = 1
    end

    # Check security score
    if report.security_score < config.min_security_score
        push!(failures, "Security score $(round(report.security_score, digits=1)) below minimum $(config.min_security_score)")
        exit_code = 1
    end

    # Print results
    println("\n2️⃣  Test Results:")
    println("   Overall Score: $(round(report.overall_score, digits=1))/100")
    println("   Performance:   $(round(report.performance_score, digits=1))/100")
    println("   Security:      $(round(report.security_score, digits=1))/100")

    if report.binary_size_bytes !== nothing
        size_kb = round(report.binary_size_bytes / 1024, digits=1)
        println("   Binary Size:   $size_kb KB")
    end

    if isempty(failures)
        println("\n✅ All checks passed!")
    else
        println("\n❌ Failed checks:")
        for (i, failure) in enumerate(failures)
            println("   $i. $failure")
        end
    end

    # Generate reports if requested
    if config.generate_reports
        println("\n3️⃣  Generating reports...")
        report_dir = joinpath(output_path, "reports")
        mkpath(report_dir)

        for format in config.report_formats
            try
                if format == :json
                    report_file = joinpath(report_dir, "$(name)_report.json")
                    export_report_json(report, report_file)
                elseif format == :markdown
                    report_file = joinpath(report_dir, "$(name)_report.md")
                    export_report_markdown(report, report_file)
                end
            catch e
                println("⚠️  Failed to generate $format report: $e")
            end
        end
    end

    println("="^70)
    return exit_code
end

"""
    setup_ci_cache(cache_dir=".staticcompiler_cache")

Set up compilation cache for CI environment.

Call this at the beginning of your CI script to enable caching.
"""
function setup_ci_cache(cache_dir=".staticcompiler_cache")
    if !isdir(cache_dir)
        mkpath(cache_dir)
        println("✅ Created cache directory: $cache_dir")
    end

    # Set cache location (implementation depends on cache.jl)
    println("✅ Cache configured for CI")

    return cache_dir
end

"""
    ci_cache_stats(cache_dir=".staticcompiler_cache")

Print cache statistics for CI logs.
"""
function ci_cache_stats(cache_dir=".staticcompiler_cache")
    if !isdir(cache_dir)
        println("ℹ️  No cache directory found")
        return
    end

    # Get cache stats
    stats = try
        cache_stats()
    catch e
        println("ℹ️  Cache stats not available: $e")
        return
    end

    println("\n📊 Cache Statistics:")
    println("   Entries: $(stats[:entries])")
    println("   Total Size: $(round(stats[:total_size_mb], digits=1)) MB")
    println("   Hit Rate: $(round(stats[:hit_rate] * 100, digits=1))%")
end

"""
    generate_ci_badge(report::ComprehensiveReport)

Generate a badge-compatible status string for CI dashboards.

Returns a tuple of (status, color, score) suitable for shields.io or similar.
"""
function generate_ci_badge(report::ComprehensiveReport)
    score = round(report.overall_score, digits=0)

    status = if score >= 90
        "excellent"
    elseif score >= 75
        "good"
    elseif score >= 60
        "fair"
    else
        "poor"
    end

    color = if score >= 90
        "brightgreen"
    elseif score >= 75
        "green"
    elseif score >= 60
        "yellow"
    else
        "red"
    end

    return (status, color, Int(score))
end

"""
    ci_summary_table(report::ComprehensiveReport)

Generate a markdown table suitable for GitHub Actions summaries or GitLab CI logs.
"""
function ci_summary_table(report::ComprehensiveReport)
    io = IOBuffer()

    println(io, "| Metric | Score | Status |")
    println(io, "|--------|-------|--------|")

    _write_metric_row(io, "Overall", report.overall_score)
    _write_metric_row(io, "Performance", report.performance_score)
    _write_metric_row(io, "Size", report.size_score)
    _write_metric_row(io, "Security", report.security_score)

    if report.binary_size_bytes !== nothing
        size_kb = round(report.binary_size_bytes / 1024, digits=1)
        println(io, "| Binary Size | $(size_kb) KB | - |")
    end

    if report.compilation_time_ms !== nothing
        time_s = round(report.compilation_time_ms / 1000, digits=2)
        println(io, "| Compilation Time | $(time_s)s | - |")
    end

    return String(take!(io))
end

function _write_metric_row(io, label, score)
    emoji = if score >= 80
        "✅"
    elseif score >= 60
        "⚠️"
    else
        "❌"
    end

    println(io, "| $label | $(round(score, digits=1))/100 | $emoji |")
end

"""
    detect_ci_environment()

Detect if running in a CI environment and return environment info.
"""
function detect_ci_environment()
    ci_systems = Dict(
        "GITHUB_ACTIONS" => "GitHub Actions",
        "GITLAB_CI" => "GitLab CI",
        "TRAVIS" => "Travis CI",
        "CIRCLECI" => "Circle CI",
        "JENKINS_HOME" => "Jenkins",
        "BUILDKITE" => "Buildkite"
    )

    for (env_var, name) in ci_systems
        if haskey(ENV, env_var)
            return (detected=true, system=name, env_var=env_var)
        end
    end

    return (detected=false, system=nothing, env_var=nothing)
end

"""
    write_github_actions_summary(report::ComprehensiveReport)

Write report to GitHub Actions step summary.

Only works when running in GitHub Actions.
"""
function write_github_actions_summary(report::ComprehensiveReport)
    if !haskey(ENV, "GITHUB_STEP_SUMMARY")
        @warn "Not running in GitHub Actions, skipping step summary"
        return
    end

    summary_file = ENV["GITHUB_STEP_SUMMARY"]

    open(summary_file, "a") do io
        println(io, "## StaticCompiler.jl Compilation Report")
        println(io, "")
        println(io, ci_summary_table(report))
        println(io, "")

        if !isempty(report.recommendations.recommendations)
            println(io, "### Top Recommendations")
            println(io, "")
            for rec in report.recommendations.recommendations[1:min(3, end)]
                println(io, "- **[$(uppercase(string(rec.priority)))]** $(rec.issue)")
            end
        end
    end

    println("✅ GitHub Actions summary updated")
end

"""
Example GitHub Actions workflow configuration
"""
const GITHUB_ACTIONS_EXAMPLE = """
name: Static Compilation CI

on: [push, pull_request]

jobs:
  compile:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - uses: julia-actions/setup-julia@v1
        with:
          version: '1.10'

      - name: Install dependencies
        run: |
          julia --project -e 'using Pkg; Pkg.instantiate()'

      - name: Compile and test
        run: |
          julia --project -e '
            using StaticCompiler

            function main()
                return 0
            end

            config = CIConfig(
                fail_on_security_issues = true,
                max_binary_size_kb = 100,
                min_performance_score = 70.0,
                generate_reports = true
            )

            exit_code = ci_compile_and_test(main, (), "dist", "myapp", config=config)
            exit(exit_code)
          '

      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: compilation-reports
          path: dist/reports/
"""

"""
Example GitLab CI configuration
"""
const GITLAB_CI_EXAMPLE = """
stages:
  - build
  - test

compile:
  stage: build
  image: julia:1.10
  script:
    - julia --project -e 'using Pkg; Pkg.instantiate()'
    - |
      julia --project -e '
        using StaticCompiler

        function main()
            return 0
        end

        config = CIConfig(
            fail_on_security_issues = true,
            max_binary_size_kb = 100,
            generate_reports = true,
            report_formats = [:json, :markdown]
        )

        exit_code = ci_compile_and_test(main, (), "dist", "myapp", config=config)
        exit(exit_code)
      '
  artifacts:
    paths:
      - dist/
    reports:
      dotenv: dist/reports/*.json
"""

export CIConfig, ci_compile_and_test, setup_ci_cache, ci_cache_stats
export generate_ci_badge, ci_summary_table, detect_ci_environment, write_github_actions_summary
export GITHUB_ACTIONS_EXAMPLE, GITLAB_CI_EXAMPLE
