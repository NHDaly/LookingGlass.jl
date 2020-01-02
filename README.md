# LookingGlass.jl

[![Build Status](https://travis-ci.com/NHDaly/LookingGlass.jl.svg?branch=master)](https://travis-ci.com/NHDaly/LookingGlass.jl)

This package contains a collection of code reflection and investigation utilities that can
be (potentially) useful for understanding, analyzing, and investigating julia code.

Most of the reflection functions are named hierarchically by what they reflect over. For
example:
- `func_specializations(f)` lists all specializations for a given function.
- `module_functions(m::Module)` lists all the functions in a given module.
- `module_globals_names(m::Module)` lists the names of all global variables in a given module.

These functions can be useful when, for example, working on multithreading a package, where you may want to check all potential places where data races can occur -- all global mutable state. This can be covered via:
```julia

```
