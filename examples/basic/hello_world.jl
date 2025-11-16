# Basic Example: Hello World
# This example shows the simplest possible statically compiled Julia program

using StaticCompiler

# Define a simple function that returns 0 (success exit code)
function hello_world()
    # Note: We can't use Base.println in static compilation
    # We'll just return success for now
    return 0
end

# Compile to standalone executable
exe = compile_executable(hello_world, (), "/tmp", "hello_world")

println("✅ Compiled to: $exe")
println("📦 Size: $(round(filesize(exe)/1024, digits=1)) KB")

# Run it
run(`$exe`)
println("✅ Program executed successfully!")
