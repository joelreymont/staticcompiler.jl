# Basic Example: Fibonacci Calculator
# Computes fibonacci numbers using recursion

using StaticCompiler

# Recursive fibonacci (not optimized, just for demonstration)
fib(n) = n <= 1 ? n : fib(n - 1) + fib(n - 2)

# Compile the function
# Note: Static compilation requires concrete types
exe = compile_shlib(fib, (Int,), "/tmp", "fibonacci")

println("✅ Compiled to: $exe")

# We can still use it from Julia
using Libdl
lib = dlopen(exe)
fib_ptr = dlsym(lib, "fib")

result = ccall(fib_ptr, Int, (Int,), 10)
println("fib(10) = $result")

dlclose(lib)
