# Supervisors

```@meta
CurrentModule = Actors
```

A supervisor is an actor looking after child actors and restarting them as necessary when they exit. We setup a supervisor  `A10` with six child actors `A1`-`A6`:

```julia
julia> A10 = supervisor()  # start supervisor A10 with default strategy :one_for_one
Link{Channel{Any}}(Channel{Any}(32), 1, :supervisor)

julia> A = map(_->spawn(threadid), 1:6);    # spawn A1 - A6

julia> t = map(a->Actors.diag(a, :task), A) # A1 - A6 are running
6-element Vector{Task}:
 Task (runnable) @0x000000016e948560
 Task (runnable) @0x000000016e949660
 Task (runnable) @0x000000016e949880
 Task (runnable) @0x000000016e949bb0
 Task (runnable) @0x000000016e949ee0
 Task (runnable) @0x000000016e94a100

julia> foreach(a->exec(a, supervise, A10), A)
```

We let `A1`-`A6` be [`supervise`](@ref)d by `A10` with default arguments. Thus they are restarted with their `threadid` behavior and they are assumed to be `:transient` (they get restarted if they terminate abnormally). 

## Restart Strategies

Our system now looks similar to the following:

![supervisor](assets/supervisor.svg)

Now, what the supervisor `A10` does if one of its children – say `A4` - exits abnormally, is determined by its supervision strategy and by the child's restart variable and exit reason.

| strategy | brief description |
|:---------|:------------------|
| `:one_for_one` | only the terminated actor is restarted (`A4`), |
| `:one_for_all` | all other child actors are terminated, then all child actors are restarted (`A1`-`A6`), |
| `:rest_for_one` | the children started after the terminated one are terminated, then all terminated ones are restarted (`A4`-`A6`). |

With the default supervision strategy `:one_for_one` only the failed actor gets restarted:

```julia
julia> send(A[4], :boom);                   # let A4 fail
┌ Warning: 2021-02-13 12:55:27 x-d-kuhub-dabab: Exit: supervised Task (failed) @0x000000016e949bb0, MethodError(Base.Threads.threadid, (:boom,), 0x0000000000007458)
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31
┌ Warning: 2021-02-13 12:55:27 x-d-kuhub-dabab: supervisor: restarting
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31

julia> t = map(a->Actors.diag(a, :task), A) # A1-A6 have runnable tasks, but A4 has been restarted
6-element Vector{Task}:
 Task (runnable) @0x000000016e948560
 Task (runnable) @0x000000016e949660
 Task (runnable) @0x000000016e949880
 Task (runnable) @0x000000010e3b8230
 Task (runnable) @0x000000016e949ee0
 Task (runnable) @0x000000016e94a100
```

With the second strategy `:one_for_all`, all supervised actors/tasks get restarted if one of them fails. That allows to restart a group of equitable actors depending on each other.

```julia
julia> set_strategy(A10, :one_for_all)      # change restart strategy
(Actors.Strategy(:one_for_all),)

julia> send(A[4], :boom);                   # let A4 fail again
┌ Warning: 2021-02-13 12:57:16 x-d-kuhub-dabab: Exit: supervised Task (failed) @0x000000010e3b8230, MethodError(Base.Threads.threadid, (:boom,), 0x0000000000007459)
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31
┌ Warning: 2021-02-13 12:57:16 x-d-kuhub-dabab: supervisor: restarting all
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31

julia> t = map(a->Actors.diag(a, :task), A) # all actors have been restarted (got new tasks)
6-element Vector{Task}:
 Task (runnable) @0x000000010e3b8450
 Task (runnable) @0x000000010e3b8670
 Task (runnable) @0x000000010e3b8890
 Task (runnable) @0x000000010e3b8ab0
 Task (runnable) @0x000000010e3b8cd0
 Task (runnable) @0x000000010e3b9000
```

With `:rest_for_one` only the failed actor and the actors that registered for supervision after it are restarted. That allows to restart a failed actor and only those other actors depending on it:

```julia
julia> set_strategy(A10, :rest_for_one)     # change strategy again
(Actors.Strategy(:rest_for_one),)

julia> send(A[4], :boom);                   # let A4 fail
┌ Warning: 2021-02-13 12:58:33 x-d-kuhub-dabab: Exit: supervised Task (failed) @0x000000010e3b8ab0, MethodError(Base.Threads.threadid, (:boom,), 0x000000000000745a)
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31
┌ Warning: 2021-02-13 12:58:33 x-d-kuhub-dabab: supervisor: restarting rest
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31

julia> t = map(a->Actors.diag(a, :task), A) # A4 - A6 have been restarted
6-element Vector{Task}:
 Task (runnable) @0x000000010e3b8450
 Task (runnable) @0x000000010e3b8670
 Task (runnable) @0x000000010e3b8890
 Task (runnable) @0x000000010e3b9220
 Task (runnable) @0x000000010e3b9440
 Task (runnable) @0x000000010e3b9770
```

For all failures we got warnings, but we can query the last failures from the supervisor and get more information about them:

```julia
julia> failed = Actors.diag(A10, :err)      # the three failed tasks can be queried from the supervisor
3-element Vector{Task}:
 Task (failed) @0x000000016e949bb0
 Task (failed) @0x000000010e3b8230
 Task (failed) @0x000000010e3b8ab0

julia> failed[1]                            # exceptions and stacktraces are available
Task (failed) @0x000000016e949bb0
MethodError: no method matching threadid(::Symbol)
....
```

## Child restart options

Child restart options with supervise allow for finer child-specific control of restarting:

| restart option | brief description |
|:---------------|:------------------|
| `:permanent` |  the child actor is always restarted, |
| `:temporary` | the child is never restarted, regardless of the supervision strategy, |
| `:transient` | the child is restarted only if it terminates abnormally, i.e., with an exit reason other than `:normal` or `:shutdown`. |

## Supervisor API

Supervisors allow some automation and control of error handling in an actor system. They have the following API:

| API function | brief description |
|:-------------|:------------------|
| [`supervisor`](@ref) | start a supervisor actor, |
| [`supervise`](@ref) | add the current actor to a supervisor's child list, |
| [`unsupervise`](@ref) | delete the current actor from a supervisor's child list, |
| [`start_actor`](@ref) | tell a supervisor to start an actor as a child, |
| [`start_task`](@ref) | tell a supervisor to start a task as a child, |
| [`delete_child`](@ref) | tell a supervisor to remove an actor from its child list, |
| [`terminate_child`](@ref) | tell a supervisor to terminate a child and to remove it from its child list, |
| [`set_strategy`](@ref) | tell a supervisor to change its supervision strategy, |
| [`count_children`](@ref) | tell a supervisor to return a children count, |
| [`which_children`](@ref) | tell a supervisor to return a list of its children. |

With options we can limit how often a supervisor tries to restart children in a given timeframe. If it exceeds this limit, it terminates itself and all of its children with a warning.

## Actor State Across Restarts

By default a supervisor restarts an actor with the behavior and acquaintances it had before exiting or shutdown. An actor thus maintains its state over a restart:

```julia
julia> incr(x, by=0) = x[end] += by       # define an accumulator
incr (generic function with 2 methods)

julia> myactor = spawn(incr, [10])        # start an actor accumulating from 10
Link{Channel{Any}}(Channel{Any}(32), 1, :default)

julia> exec(myactor, supervise, sv)       # put it under supervision
(Actors.Child{Link{Channel{Any}}}(Link{Channel{Any}}(Channel{Any}(32), 1, :default), nothing, :transient),)

julia> foreach(x->call(myactor, x), 1:10) # accumulate

julia> send(myactor, :boom);              # let it fail
┌ Warning: 2021-02-13 12:58:37 x-d-kuhub-dabab: Exit: supervised Task (failed) @0x000000016e4cb200, MethodError(+, (65, :boom), 0x00000000000073ef)
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31
┌ Warning: 2021-02-13 12:58:37 x-d-kuhub-dabab: supervisor: restarting
└ @ Actors ~/.julia/dev/Actors/src/logging.jl:31

julia> call(myactor)                      # it has maintained its state
65
```

## Termination and Restart Callbacks

But there are cases where you want a different user-defined fallback strategy for actor restart, for example to

- restart it with a different algorithm/behavior or data set or
- do some cleanup before restarting it,
- save and restore a checkpoint.

For that you can define callback functions invoked at actor termination, restart or initialization:

| callback | short description |
|:---------|:------------------|
| [`term!`](@ref) | termination callback; if defined, it is called at actor exit with argument `reason` (exit reason), |
| restart | `cb`, called by a supervisor at actor restart with argument `bhv` (last actor behavior); must return a [`Link`](@ref) to a spawned actor (or a `Task`); |
| [`init!`](@ref) | initialization callback; if defined, it is called by a supervisor at actor restart if no restart callback is defined; must return a [`Link`](@ref) to a spawned actor. | 

Those callbacks must follow some conventions.

## Task Supervision 

## Supervisory trees

Often you may be interested in building a hierarchical structure containing all actors and tasks in your application. This is called a supervisory tree, and there is the [`Supervisors`](https://github.com/JuliaActors/Supervisors.jl) package facilitating to build that.
