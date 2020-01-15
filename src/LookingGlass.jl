"""
    LookingGlass.jl

This package contains a collection of code reflection and investigation utilities that can
be (potentially) useful for understanding, analyzing, and investigating julia code.

Most of the reflection functions are named hierarchically by what they reflect over. For
example:
- `func_specializations(f)` lists all specializations for a given function.
- `module_functions(m::Module)` lists all the functions in a given module.
- `module_globals_names(m::Module)` lists the names of all global variables in a given module.

There are also other non-reflection-focused utilities, such as `@quot`.
"""
module LookingGlass
import Base.Iterators

"""
    @quot 2 + 3

Macro for debugging during metaprogramming; it simply returns the exact expression that a
macro gets as input. This can be helpful if you're wondering what inputs a macro can expect.
"""
macro quot(e) QuoteNode(e) end

# ---------------------------------------------------------------------------
# -- Utilities for Functions
# ---------------------------------------------------------------------------

"""
    func_specializations(f) -> Dict((method,signature) => MethodInstance)

Return all the specializations (MethodInstances) of each method of the given function (or
callable object), if there are any.

Specializations (also called MethodInstances) are the compiler-generated code for a method,
generated by specializing the method for specific argument types.

Most often, it's just the keys that are interesting, if you want to know _what_ specializations
a function has, rather than accessing the MethodInstances themselves (they're
compiler-internal and sort of gross):

```julia-repl
julia> foo(x) = 2x
foo (generic function with 1 method)

julia> foo(2) + foo(2.0)
8.0

julia> keys(LookingGlass.func_specializations(foo))
Base.KeySet for a Dict{Tuple{Method,DataType},Core.TypeMapEntry} with 2 entries. Keys:
  (foo(x) in Main at none:1, Tuple{typeof(foo),Int64})
  (foo(x) in Main at none:1, Tuple{typeof(foo),Float64})
```
"""
func_specializations(f) =
    Dict((m, s.sig) => s
        for m in methods(f).ms
        # m.specializations returns a custom iterate, which we collect here via `s.next`
        for s in Channel() do ch
            s = m.specializations
            while s isa Core.TypeMapEntry  # TODO: Can there be other things in here besides TypeMapEntry?
                put!(ch, s)
                s=s.next
            end
        end)

"""
    func_backedges(f) -> Dict((method, signature) => [backedges...])

Return all the backedges on all specializations of a function, if there are any.
Backedges are a compiler-internal mechanism used for recursively invalidating the cached
compilations of a method -- its MethodInstances -- if the inlined code for any functions it
calls changes. This is the mechanism that fixes the infamous Julia #265 Issue.

Since these are _back_ edges, not _forward_ edges, if a function `foo` has a backedge listed
to function `bar`, this means `bar` has _inlined `foo`_ when it was compiled, so if the code
for `foo` is redefined by the user, `bar` needs to be recompiled the next time it's called.

```julia-repl
julia> foo(x) = 2x
foo (generic function with 1 method)

julia> bar(x) = foo(x) + 1
bar (generic function with 1 method)

julia> bar(1)
3

julia> LookingGlass.func_backedges(foo)
Dict{Any,Array{Any,1}} with 2 entries:
  (foo(x) in Main at none:1, Tuple{typeof(foo),Int64}) => Any[MethodInstance for bar(::Int64)]
  :MethodTable                                         => Any[]
```

Backedges on a function's MethodTable means changes to _any methods_ (including adding
a method) will trigger recompilation of the target function.
"""
function func_backedges(f)
    out = Dict{Tuple, Vector{Any}}(
        # Method backedges
        k => try s.func.backedges catch ; [] end
        for (k,s) in func_specializations(f)
    )
    # MethodTable backedges
    for (typ, method) in
            # MethodTable edges are pairs of (type, method_instance) (but stored as a flat array)
            try Tuple.(Iterators.partition(methods(f).mt.backedges, 2)) catch ; [] end
        methods = get!(out, (:MethodTable, typ), [])
        push!(methods, method)
    end
    out
end



# ---------------------------------------------------------------------------
# -- Utilities for Modules
# ---------------------------------------------------------------------------

"""
    module_submodules(m::Module; recursive=true, base=false) -> Vector{Module}
Return a list of all Modules that are submodules of `m`. If `recursive=true`, this returns
all recursive submodules. If `recursive=false`, it returns only direct children of `m`.

By default, it skips Julia's `Base` and `Core` modules, but you can enable those with
`base=true`.
NOTE: currently, `module_submodules(Main, recursive=true, base=true)` will trigger a
StackOverflowError, since recursively listing submodules of `Core` or `Base` infinite loops.
"""
module_submodules(m::Module; recursive=true, base=false) =
    if recursive
        _module_recursive_submodules(m, base=base)
    else
        _module_direct_submodules(m, base=base)
    end

_module_recursive_submodules(m; base) = collect(Iterators.flatten(
    [x, _module_recursive_submodules(x, base=base)...]
        for x in _module_direct_submodules(m, base=base)
    ))
_module_direct_submodules(m; base) =
    Module[submodule
        for x in filter(x->name_is_submodule(m,x), names(m, all=true))
        for submodule in (Core.eval(m, x),)  # assign to temporary variable (comprehensions are weird)
        if submodule ∉ (Base, Core)]

name_is_submodule(m::Module, s::Symbol) =
    isdefined(m, s) && isa(Core.eval(m,s), Module) && nameof(m) != s
#module_is_submodule(m::Module, s::Module) = issubmodule(m, nameof(s))  # BROKEN: might just be a name collision. This is not the right way to check this.


"""
    module_functions_names(m::Module) -> Vector{Symbol}
Return a list of the names of all functions defined in Module `m`.
"""
module_functions_names(m::Module) =
    [name
     for name in names(m, all=true)
     if Core.eval(m, name) isa Function && name ∉ (:include, :eval)]
"""
    module_functions(m::Module) -> Dict{Symbol, Function}
Return a list of all the Function objects defined in Module `m`.
"""
module_functions(m::Module) = [Core.eval(m, n) for n in module_functions_names(m)]

"""
    module_globals_names(m; constness=:all, mutability=:all) -> Vector{Symbol}
Return a list of the names of all global variables in Module `m`.

To return only const globals or only non-const globals, set the `constness=` keyword
argument to one of `constness=:const` or `constness=:nonconst`.
To return only mutable globals or only immutable globals, set the `mutability=` keyword
argument to one of `mutability=:mutable` or `mutability=:immutable`.
"""
module_globals_names(m::Module; constness=:all, mutability=:all) =
    [n for n in names(m, all=true)
        if module_name_isglobal(m, n; constness=constness, mutability=mutability)]
function module_name_isglobal(m::Module, n::Symbol; constness, mutability)
    @assert constness ∈ (:all, :const, :nonconst)
    @assert mutability ∈ (:all, :mutable, :immutable)
    try
        if String(n)[1] == '#' return false end
        v = Core.eval(m, n)
        return !isa(v, Union{DataType, UnionAll, Function, Module}) &&
            (constness == :all || (constness == :const && _isconst_global(m, n) ||
                                   constness == :nonconst && !_isconst_global(m, n))) &&
            (mutability == :all || (mutability == :mutable && !isimmutable(v) ||
                                    mutability == :immutable && isimmutable(v)))
    catch
        false
    end
end
"""
    module_globals(m::Module) -> Dict{Symbol, Any}
Return a Dict mapping the name to the value of all global variables in Module `m`.
"""
module_globals(m::Module) = Dict(n => Core.eval(m, n) for n in module_globals_names(m))

function _isconst_global(m::Module, s::Symbol)
    b = _getbinding(m,s)
    b != nothing && b.constp
end
#--- Compiler-Internal Julia Binding struct ------------------------------------------------
# Stores information about a variable binding, which we can interrogate for information
# such as whether a variable is a global `const`.
# NOTE: This is very specific to a given version of Julia.
struct _Binding_t
    name::Ptr{Nothing}
    value::Ptr{Nothing}
    globalref::Ptr{Nothing}
    owner::Ptr{Nothing}
    constp::Bool
end
function _getbinding(m, s)
    p = ccall(:jl_get_binding, Ptr{_Binding_t}, (Any, Any), m, s)
    p == Ptr{Nothing}(0) ? nothing : unsafe_load(p)
end
#-------------------------------------------------------------------------------------------

"""
    module_recursive_globals_names(m; constness=:all, mutability=:all) -> Dict(submodule => name)
Return a list of the names of all global variables for each submodule in Module `m`.

Defaults to all globals, can toggle only const-globals or nonconst-globals via keyword args.
See [`module_recursive_globals`](@ref).
"""
module_recursive_globals_names(m::Module; constness=:all, mutability=:all) =
    merge!(
        Dict(m => module_globals_names(m, constness=constness, mutability=mutability)),
        Dict(
            sm => names
            for sm in module_submodules(m, recursive=true)
            for names in (module_globals_names(sm; constness=constness, mutability=mutability),)
            if !isempty(names)
        ))


end # module
