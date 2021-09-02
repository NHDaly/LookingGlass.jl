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
    @test length(LookingGlass.func_specializations(MF.foo)) == 0
    MF.foo(2)
    @test length(LookingGlass.func_specializations(MF.foo)) == 1
end

@testset "func_backedges()" begin
    @test length(first(LookingGlass.func_backedges(MF.foo))[2]) == 0
    MF.bar(2)
    @test length(first(LookingGlass.func_backedges(MF.foo))[2]) == 1
end

module Outer
    const g_outer = 1
end
module MV
    gv = 2
    const cv = 2
    vec = []
    module A
        const g_a = 1
    end
    module Inner
        i_x = 3
        const i_c = 2
        const i_vec = [2]

        import ...Outer
    end
end

@test LookingGlass.module_recursive_globals_names(MV) ==
    Dict(
        MV => sort([:gv, :cv, :vec]),
        MV.Inner => sort([:i_x, :i_c, :i_vec]),
        MV.A => sort([:g_a]),
        )

@test LookingGlass.module_recursive_globals_names(MV,
                     constness = :const, mutability = :mutable) ==
    Dict(
        MV => sort([]),
        MV.Inner => sort([:i_vec]),
        MV.A => sort([]),
        )

@test LookingGlass.module_recursive_globals_names(MV,
                     constness = :const, imported = true) ==
    Dict(
        MV => sort([:cv]),
        MV.Inner => sort([:i_c, :i_vec]),
        MV.A => sort([:g_a]),
        Outer => sort([:g_outer]),  # imported via MV.Inner
        )

@test LookingGlass.module_recursive_globals(MV) ==
    Dict(
        (MV, :gv) => MV.gv,
        (MV, :cv) => MV.cv,
        (MV, :vec) => MV.vec,
        (MV.Inner, :i_x) => MV.Inner.i_x,
        (MV.Inner, :i_c) => MV.Inner.i_c,
        (MV.Inner, :i_vec) => MV.Inner.i_vec,
        (MV.A, :g_a) => MV.A.g_a,
        )

@test LookingGlass.module_recursive_globals(MV, imported=true) ==
    Dict(
        (MV, :gv) => MV.gv,
        (MV, :cv) => MV.cv,
        (MV, :vec) => MV.vec,
        (MV.Inner, :i_x) => MV.Inner.i_x,
        (MV.Inner, :i_c) => MV.Inner.i_c,
        (MV.Inner, :i_vec) => MV.Inner.i_vec,
        (MV.A, :g_a) => MV.A.g_a,
        (Outer, :g_outer) => MV.Inner.Outer.g_outer,  # imported via MV.Inner
        )

@test LookingGlass.module_recursive_globals(MV, imported=true, constness=:const) ==
    Dict(
        (MV, :cv) => MV.cv,
        (MV.Inner, :i_c) => MV.Inner.i_c,
        (MV.Inner, :i_vec) => MV.Inner.i_vec,
        (MV.A, :g_a) => MV.A.g_a,
        (Outer, :g_outer) => MV.Inner.Outer.g_outer,  # imported via MV.Inner
        )
