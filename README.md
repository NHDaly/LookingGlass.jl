# LookingGlass.jl

[![Build Status](https://travis-ci.com/NHDaly/LookingGlass.jl.svg?branch=master)](https://travis-ci.com/NHDaly/LookingGlass.jl)

This package contains a collection of code reflection and investigation utilities that can
be (potentially) useful for understanding, analyzing, and investigating julia code and the
julia compiler.

Most of the reflection functions are named hierarchically by what they reflect over. For
example:
- `func_specializations(f)` lists all specializations for a given function.
- `module_functions(m::Module)` lists all the functions in a given module.
- `module_globals_names(m::Module)` lists the names of all global variables in a given module.

## Function Utilities

I've used `func_specializations()` and `func_backedges()` quite a bit when trying to
understand decisions the compiler makes.

For example, we can see that julia doesn't specialize functions for Type arguments by default:
```julia
julia> isintegertype(t) = t <: Integer
isintegertype (generic function with 1 method)

julia> isintegertype(Int)
true

julia> isintegertype(Float32)
false

julia> keys(LookingGlass.func_specializations(isintegertype))
Base.KeySet for a Dict{Tuple{Method,DataType},Core.TypeMapEntry} with 1 entry. Keys:
  (isintegertype(t) in Main at none:1, Tuple{typeof(isintegertype),Type})
```

But it _does_ specialize on Type arguments if you access them via a `where` clause:
```julia
julia> isintegertype(::Type{T}) where T = T <: Integer
isintegertype (generic function with 2 methods)

julia> isintegertype(Int)
true

julia> isintegertype(Float32)
false

julia> keys(LookingGlass.func_specializations(isintegertype))
Base.KeySet for a Dict{Tuple{Method,DataType},Core.TypeMapEntry} with 3 entries. Keys:
  (isintegertype(t) in Main at none:1, Tuple{typeof(isintegertype),Type})
  (isintegertype(::Type{T}) where T in Main at none:1, Tuple{typeof(isintegertype),Type{Float32}})
```

And you can use `func_backedges(f)` to observe inlining, among other things.
```julia
julia> foo(x) = 2x
foo (generic function with 1 method)

julia> bar(x) = foo(x) + 1
bar (generic function with 1 method)

julia> foo(2)
4

julia> LookingGlass.func_backedges(foo)
Dict{Any,Array{Any,1}} with 2 entries:
  (foo(x) in Main at none:1, Tuple{typeof(foo),Int64}) => Any[]
  :MethodTable                                         => Any[]
```

## Module Utilities

These functions provide reflection over Modules. This can be useful for example, when
working on multithreading a package, where you may want to check for potential places where
data races can occur -- all global mutable state. This can be covered via:
```julia
julia> # Non-const global variables
julia> LookingGlass.module_recursive_globals_names(FixedPointDecimals, constness=:nonconst, mutability=:all)
Dict{Module,Array{Symbol,1}} with 1 entry:
  FixedPointDecimals => Symbol[]

julia> # And const-mutable global variables
julia> LookingGlass.module_recursive_globals_names(FixedPointDecimals, constness=:const, mutability=:mutable)
Dict{Module,Array{Symbol,1}} with 1 entry:
  FixedPointDecimals => Symbol[]
```

So we can see that FixedPointDecimals looks good. :) (Note that of course this doesn't cover
all potential data races in a package, just some obvious good places to start looking.)
