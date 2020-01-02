using LookingGlass
using Test

module MF
    foo(x) = 2x
    bar(x) = foo(x) + 1
    module Inner
        f() = 1
    end
end

@test Set(LookingGlass.module_functions_names(MF)) == Set([:foo, :bar])
@test Set(LookingGlass.module_functions(MF)) == Set([MF.foo, MF.bar])

module MV
    gv = 2
    const cv = 2
    module Inner
        i_x = 3
        const i_c = 2
    end
end

@test LookingGlass.module_recursive_globals_names(MV) ==
    Dict(
        MV => sort([:gv, :cv]),
        MV.Inner => sort([:i_x, :i_c]),
        )

@test LookingGlass.module_recursive_globals_names(MV, consts=true, nonconsts=false) ==
    Dict(
        MV => sort([:cv]),
        MV.Inner => sort([:i_c]),
        )
