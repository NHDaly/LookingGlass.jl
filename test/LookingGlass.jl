using LookingGlass
using Test

module MF
    foo(x) = 2x
    bar(x) = foo(x) + 1
    module Inner
        f() = 1
    end

    g = 2
end

@test Set(LookingGlass.module_functions_names(MF)) == Set([:foo, :bar])
@test Set(LookingGlass.module_functions(MF)) == Set([MF.foo, MF.bar])
@test Set(LookingGlass.module_objects(MF)) ⊇ Set([MF.g, MF.Inner, typeof(MF.foo), typeof(MF.bar), MF.foo, MF.bar])

@testset "func_specializations()" begin
    @test length(Set(LookingGlass.func_specializations(MF.foo))) == 0
    MF.foo(2)
    @test length(Set(LookingGlass.func_specializations(MF.foo))) == 1
end

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
