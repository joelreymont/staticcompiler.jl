using StaticCompiler
using StaticTools
using LoopVectorization

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
    # LHS
    A = StackArray{Float64,2,STACK_ROWS*STACK_COLS,(STACK_ROWS, STACK_COLS)}(undef)
    @turbo for i ∈ axes(A, 1)
        for j ∈ axes(A, 2)
           A[i,j] = i*j
        end
    end

    # RHS
    B = StackArray{Float64,2,STACK_COLS*STACK_ROWS,(STACK_COLS, STACK_ROWS)}(undef)
    @turbo for i ∈ axes(B, 1)
        for j ∈ axes(B, 2)
           B[i,j] = i*j
        end
    end

    # # Matrix multiplication
    C = StackArray{Float64,2,STACK_COLS*STACK_COLS,(STACK_COLS, STACK_COLS)}(undef)
    mul!(C, B, A)

    # Print to stdout
    printf(C)
    # Also print to file
    fp = fopen(c"table.tsv",c"w")
    printf(fp, C)
    fclose(fp)
end

# Attempt to compile
target = StaticTarget()
StaticCompiler.set_runtime!(target, true)
path = compile_executable(loopvec_matrix_stack, (), "./"; target=target)
