# Dependency bundler for creating truly standalone binaries

struct BundleConfig
    bundle_system_libs::Bool
    bundle_libc::Bool
    create_portable::Bool
    output_dir::String
end

BundleConfig(output_dir) = BundleConfig(false, false, true, output_dir)

"""
    analyze_dependencies(executable_path)

Analyze dynamic library dependencies of a compiled executable.

Returns a dictionary with system libraries, custom libraries, and missing dependencies.
"""
function analyze_dependencies(executable_path::String)
    if !isfile(executable_path)
        error("Executable not found: $executable_path")
    end

    deps = Dict{Symbol, Vector{String}}()
    deps[:system] = String[]
    deps[:custom] = String[]
    deps[:missing] = String[]

    if Sys.islinux()
        analyze_deps_linux!(deps, executable_path)
    elseif Sys.isapple()
        analyze_deps_macos!(deps, executable_path)
    elseif Sys.iswindows()
        analyze_deps_windows!(deps, executable_path)
    end

    return deps
end

function analyze_deps_linux!(deps, executable_path)
    try
        output = read(`ldd $executable_path`, String)
        for line in split(output, '\n')
            line = strip(line)
            if isempty(line)
                continue
            end

            # Parse ldd output: libname.so => /path/to/lib (address)
            if occursin("=>", line)
                parts = split(line, "=>")
                libname = strip(parts[1])

                if length(parts) > 1
                    libpath = strip(split(parts[2], "(")[1])

                    if occursin("not found", libpath)
                        push!(deps[:missing], libname)
                    elseif occursin("/lib/", libpath) || occursin("/usr/lib/", libpath)
                        push!(deps[:system], libpath)
                    else
                        push!(deps[:custom], libpath)
                    end
                end
            end
        end
    catch e
        @warn "Could not analyze dependencies with ldd" exception=e
    end
end

function analyze_deps_macos!(deps, executable_path)
    try
        output = read(`otool -L $executable_path`, String)
        lines = split(output, '\n')[2:end]  # Skip first line (header)

        for line in lines
            line = strip(line)
            if isempty(line)
                continue
            end

            # Parse otool output: /path/to/lib (compatibility version)
            libpath = strip(split(line, "(")[1])

            if occursin("/usr/lib/", libpath) || occursin("/System/", libpath)
                push!(deps[:system], libpath)
            elseif occursin("@rpath", libpath) || occursin("@executable_path", libpath)
                push!(deps[:custom], libpath)
            else
                push!(deps[:custom], libpath)
            end
        end
    catch e
        @warn "Could not analyze dependencies with otool" exception=e
    end
end

function analyze_deps_windows!(deps, executable_path)
    # Windows dependency analysis would require parsing PE headers
    # or using tools like depends.exe
    @warn "Windows dependency analysis not yet implemented"
end

"""
    create_bundle(executable_path, config::BundleConfig)

Create a standalone bundle with all necessary dependencies.

# Example
```julia
compile_executable(myfunc, (Int,), "/tmp", "myapp")
config = BundleConfig("/tmp/bundle")
create_bundle("/tmp/myapp", config)
```
"""
function create_bundle(executable_path::String, config::BundleConfig)
    if !isfile(executable_path)
        error("Executable not found: $executable_path")
    end

    mkpath(config.output_dir)

    # Analyze dependencies
    deps = analyze_dependencies(executable_path)

    # Copy executable
    exe_name = basename(executable_path)
    bundle_exe = joinpath(config.output_dir, exe_name)
    cp(executable_path, bundle_exe, force=true)

    # Make executable
    if Sys.isunix()
        chmod(bundle_exe, 0o755)
    end

    # Create lib directory
    lib_dir = joinpath(config.output_dir, "lib")

    # Copy dependencies
    copied_libs = String[]

    if config.bundle_system_libs
        for lib in deps[:system]
            if isfile(lib) && !should_skip_lib(lib, config)
                mkpath(lib_dir)
                lib_name = basename(lib)
                cp(lib, joinpath(lib_dir, lib_name), force=true)
                push!(copied_libs, lib_name)
            end
        end
    end

    for lib in deps[:custom]
        if isfile(lib)
            mkpath(lib_dir)
            lib_name = basename(lib)
            cp(lib, joinpath(lib_dir, lib_name), force=true)
            push!(copied_libs, lib_name)
        end
    end

    # Create launcher script
    if !isempty(copied_libs)
        create_launcher_script(config.output_dir, exe_name)
    end

    # Create README
    create_bundle_readme(config.output_dir, exe_name, deps, copied_libs)

    println("Bundle created at: $(config.output_dir)")
    println("  Executable: $exe_name")
    println("  Libraries bundled: $(length(copied_libs))")

    if !isempty(deps[:missing])
        println()
        println("Warning: Missing dependencies:")
        for lib in deps[:missing]
            println("  - $lib")
        end
    end

    return config.output_dir
end

function should_skip_lib(libpath, config)
    # Don't bundle libc unless explicitly requested
    if !config.bundle_libc && any(x -> occursin(x, libpath), ["libc.so", "libc.dylib", "libm.so", "libpthread.so"])
        return true
    end

    # Don't bundle Linux kernel interfaces
    if occursin("ld-linux", libpath) || occursin("linux-vdso", libpath)
        return true
    end

    return false
end

function create_launcher_script(bundle_dir, exe_name)
    if Sys.isunix()
        launcher_path = joinpath(bundle_dir, "run.sh")
        open(launcher_path, "w") do io
            write(io, """#!/bin/bash
                # Launcher script for bundled executable

                DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
                export LD_LIBRARY_PATH="\$DIR/lib:\$LD_LIBRARY_PATH"
                export DYLD_LIBRARY_PATH="\$DIR/lib:\$DYLD_LIBRARY_PATH"

                exec "\$DIR/$exe_name" "\$@"
                """)
        end
        chmod(launcher_path, 0o755)
        println("  Created launcher: run.sh")
    end
end

function create_bundle_readme(bundle_dir, exe_name, deps, copied_libs)
    readme_path = joinpath(bundle_dir, "README.txt")
    open(readme_path, "w") do io
        write(io, """
        Standalone Bundle: $exe_name
        ==============================

        This directory contains a bundled executable with its dependencies.

        To run:
        """)

        if !isempty(copied_libs)
            write(io, "  ./run.sh\n\n")
            write(io, "Or directly:\n")
            if Sys.isunix()
                write(io, "  LD_LIBRARY_PATH=./lib ./$exe_name\n\n")
            end
        else
            write(io, "  ./$exe_name\n\n")
        end

        write(io, """
        Contents:
        - $exe_name: Main executable
        """)

        if !isempty(copied_libs)
            write(io, "- lib/: Bundled library dependencies\n")
            write(io, "- run.sh: Launcher script (Unix only)\n")
        end

        write(io, "\n")
        write(io, "Dependencies:\n")
        write(io, "  System libraries: $(length(deps[:system]))\n")
        write(io, "  Custom libraries: $(length(deps[:custom]))\n")
        write(io, "  Bundled libraries: $(length(copied_libs))\n")

        if !isempty(deps[:missing])
            write(io, "\nWarning: Missing dependencies:\n")
            for lib in deps[:missing]
                write(io, "  - $lib\n")
            end
        end

        write(io, """

        This bundle was created by StaticCompiler.jl
        """)
    end
    println("  Created README.txt")
end

export analyze_dependencies, create_bundle, BundleConfig
