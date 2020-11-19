#
# This file is part of the Actors.jl Julia package, 
# MIT license, part of https://github.com/JuliaActors
#

using Test, SafeTestsets, Distributed

function redirect_devnull(f)
    open(@static(Sys.iswindows() ? "nul" : "/dev/null"), "w") do io
        redirect_stdout(io) do
            f()
        end
    end
end

length(procs()) == 1 && addprocs(1)

@safetestset "Basics"        begin include("test_basics.jl") end
@testset "Distributed"       begin include("test_distr.jl") end
@safetestset "Communication" begin include("test_com.jl") end
@safetestset "API"           begin include("test_api.jl") end
@safetestset "Tasks"         begin include("test_task.jl") end

println("running examples, output suppressed!")
redirect_devnull() do
    @safetestset "Factorial"     begin include("../examples/factorial.jl") end
    @safetestset "Fib"           begin include("../examples/fib.jl") end
    @safetestset "Simple"        begin include("../examples/simple.jl") end
    @safetestset "Stack"         begin include("../examples/stack.jl") end
end
