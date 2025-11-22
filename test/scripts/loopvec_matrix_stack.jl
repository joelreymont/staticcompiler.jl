using StaticCompiler
using StaticTools
using LoopVectorization

const LOG_PATH = c"loopvec_stack.log"
flush_log(fp) = ccall(:fflush, Cint, (Ptr{Cvoid},), fp)

const STACK_ROWS = 10
const STACK_COLS = 5

@inline function mul!(C::StackArray, A::StackArray, B::StackArray)
    @turbo for n ∈ axes(C, 2), m ∈ axes(C, 1)
        Cmn = zero(eltype(C))
        for k ∈ indices((A,B), (2,1))
            Cmn += A[m,k] * B[k,n]
        end
        C[m,n] = Cmn
    end
    return C
end

function loopvec_matrix_stack()
    logfp = fopen(LOG_PATH, c"w")
    printf(logfp, c"[loopvec_stack] start\n")
    flush_log(logfp)

    # LHS
    A = StackArray{Float64,2,STACK_ROWS*STACK_COLS,(STACK_ROWS, STACK_COLS)}(undef)
    @turbo for i ∈ axes(A, 1)
        for j ∈ axes(A, 2)
           A[i,j] = i*j
        end
    end
    printf(logfp, c"[loopvec_stack] A filled first=%f last=%f\n", A[1,1], A[STACK_ROWS, STACK_COLS])
    flush_log(logfp)

    # RHS
    B = StackArray{Float64,2,STACK_COLS*STACK_ROWS,(STACK_COLS, STACK_ROWS)}(undef)
    @turbo for i ∈ axes(B, 1)
        for j ∈ axes(B, 2)
           B[i,j] = i*j
        end
    end
    printf(logfp, c"[loopvec_stack] B filled first=%f last=%f\n", B[1,1], B[STACK_COLS, STACK_ROWS])
    flush_log(logfp)

    # # Matrix multiplication
    C = StackArray{Float64,2,STACK_COLS*STACK_COLS,(STACK_COLS, STACK_COLS)}(undef)
    printf(logfp, c"[loopvec_stack] mul! start\n")
    flush_log(logfp)
    mul!(C, B, A)
    printf(logfp, c"[loopvec_stack] mul! done C first=%f last=%f\n", C[1,1], C[STACK_COLS, STACK_COLS])
    flush_log(logfp)

    # Print to stdout
    printf(C)
    # Also print to file
    fp = fopen(c"table.tsv",c"w")
    printf(fp, C)
    fclose(fp)
    printf(logfp, c"[loopvec_stack] finished\n")
    flush_log(logfp)
    fclose(logfp)
end

# Attempt to compile
target = StaticTarget()
StaticCompiler.set_runtime!(target, true)
path = compile_executable(loopvec_matrix_stack, (), "./"; target=target)
