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
    vec = []
    module Inner
        i_x = 3
        const i_c = 2
        const i_vec = [2]
    end
end

@test LookingGlass.module_recursive_globals_names(MV) ==
    Dict(
        MV => sort([:gv, :cv, :vec]),
        MV.Inner => sort([:i_x, :i_c, :i_vec]),
        )

@test LookingGlass.module_recursive_globals_names(MV,
                     constness=:const, mutability=:mutable) ==
    Dict(
        MV => sort([]),
        MV.Inner => sort([:i_vec]),
        )
