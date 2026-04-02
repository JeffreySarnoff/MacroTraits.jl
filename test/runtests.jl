using Test
using MacroTraits

@testset "MacroTraits.jl" begin
    @testset "basic trait dispatch" begin
        @def_trait SequenceBasic begin
            DynamicVectorBasic => [Vector]
            StaticTupleBasic => [Tuple, NamedTuple]
        end

        @trait_dispatcher process_items_basic(x)::SequenceBasic
        @trait_function process_items_basic(x)::DynamicVectorBasic = :dynamic
        @trait_function process_items_basic(x)::StaticTupleBasic = :static

        @test process_items_basic([1, 2, 3]) == :dynamic
        @test process_items_basic((1, 2, 3)) == :static
    end

    @testset "multi-argument dispatch" begin
        @def_trait SequenceMulti begin
            DynamicVectorMulti => [Vector]
            StaticTupleMulti => [Tuple, NamedTuple]
        end

        @trait_dispatcher scale_data_multi(data, factor)::SequenceMulti
        @trait_function scale_data_multi(data, factor)::DynamicVectorMulti = data .* factor
        @trait_function scale_data_multi(data, factor)::StaticTupleMulti = map(v -> v * factor, data)

        @test scale_data_multi([1, 2], 3) == [3, 6]
        @test scale_data_multi((1, 2), 3) == (3, 6)
    end

    @testset "typed dispatcher preserves first-argument constraints" begin
        @def_trait SequenceTyped begin
            DynamicVectorTyped => [Vector]
        end

        @trait_dispatcher process_items_typed(x::Vector{Int})::SequenceTyped
        @trait_function process_items_typed(x::Vector{Int})::DynamicVectorTyped = :ok

        @test process_items_typed([1, 2, 3]) == :ok

        err = try
            process_items_typed(Float32[1, 2, 3])
            nothing
        catch caught
            caught
        end

        @test err isa MethodError
        @test err.f === process_items_typed
    end

    @testset "open-world extension uses trait_map" begin
        @def_trait SequenceExtension begin
            DynamicVectorExtension => [Vector]
            StaticTupleExtension => [Tuple]
        end

        @trait_dispatcher process_items_extension(x)::SequenceExtension
        @trait_function process_items_extension(x)::DynamicVectorExtension = :dynamic
        @trait_function process_items_extension(x)::StaticTupleExtension = :static

        struct MyCustomTreeExtension
            leaves::Int
        end

        @trait_map SequenceExtension StaticTupleExtension => MyCustomTreeExtension

        @test process_items_extension(MyCustomTreeExtension(5)) == :static
    end

    @testset "unmapped types fail during trait resolution" begin
        @def_trait SequenceUnmapped begin
            DynamicVectorUnmapped => [Vector]
        end

        @trait_dispatcher process_items_unmapped(x)::SequenceUnmapped
        @trait_function process_items_unmapped(x)::DynamicVectorUnmapped = :dynamic

        err = try
            process_items_unmapped((1, 2, 3))
            nothing
        catch caught
            caught
        end

        @test err isa MethodError
        @test err.f === SequenceUnmapped
    end

    @testset "worker naming no longer collides with underscore helpers" begin
        _process_items_collision(x) = :user_helper

        @def_trait SequenceCollision begin
            DynamicVectorCollision => [Vector]
        end

        @trait_dispatcher process_items_collision(x)::SequenceCollision
        @trait_function process_items_collision(x)::DynamicVectorCollision = :trait_path

        @test _process_items_collision([1, 2, 3]) == :user_helper
        @test process_items_collision([1, 2, 3]) == :trait_path
    end

    @testset "missing trait implementation fails at public API" begin
        @def_trait SequenceMissingImpl begin
            DynamicVectorMissingImpl => [Vector]
            StaticTupleMissingImpl => [Tuple]
        end

        @trait_dispatcher process_items_missing_impl(x)::SequenceMissingImpl
        @trait_function process_items_missing_impl(x)::DynamicVectorMissingImpl = :dynamic

        err = try
            process_items_missing_impl((1, 2, 3))
            nothing
        catch caught
            caught
        end

        @test err isa MethodError
        @test err.f === process_items_missing_impl
    end

    @testset "dispatcher temporary names are hygienic" begin
        @def_trait SequenceHygienic begin
            DynamicVectorHygienic => [Vector]
            StaticTupleHygienic => [Tuple]
        end

        @trait_dispatcher process_items_hygienic(trait_state)::SequenceHygienic
        @trait_function process_items_hygienic(trait_state)::DynamicVectorHygienic = (:dynamic, trait_state)
        @trait_function process_items_hygienic(trait_state)::StaticTupleHygienic = (:static, trait_state)

        @test process_items_hygienic([1, 2, 3]) == (:dynamic, [1, 2, 3])
        @test process_items_hygienic((1, 2, 3)) == (:static, (1, 2, 3))
    end

    @testset "macros expand hygienically in another module" begin
        mod = Module(:HygieneModule)
        Core.eval(mod, :(using Main.MacroTraits))

        Core.eval(mod, quote
            @def_trait SequenceExternal begin
                DynamicVectorExternal => [Vector]
                StaticTupleExternal => [Tuple]
            end

            @trait_dispatcher process_items_external(trait_state)::SequenceExternal
            @trait_function process_items_external(trait_state)::DynamicVectorExternal = (:dynamic, trait_state)
            @trait_function process_items_external(trait_state)::StaticTupleExternal = (:static, trait_state)
            @trait_map SequenceExternal StaticTupleExternal => NamedTuple
        end)

        @test Core.eval(mod, :(process_items_external([1, 2, 3]))) == (:dynamic, [1, 2, 3])
        @test Core.eval(mod, :(process_items_external((1, 2, 3)))) == (:static, (1, 2, 3))
        @test Core.eval(mod, :(process_items_external((a=1, b=2)))) == (:static, (a=1, b=2))
    end

    @testset "unsupported complex signatures are rejected explicitly" begin
        dispatcher_default = try
            @macroexpand @trait_dispatcher process_items_default(x=1)::SequenceBasic
            nothing
        catch caught
            caught
        end
        @test dispatcher_default isa ArgumentError
        @test occursin("does not support default values", sprint(showerror, dispatcher_default))

        dispatcher_varargs = try
            @macroexpand @trait_dispatcher process_items_varargs(x...)::SequenceBasic
            nothing
        catch caught
            caught
        end
        @test dispatcher_varargs isa ArgumentError
        @test occursin("does not support varargs", sprint(showerror, dispatcher_varargs))

        dispatcher_destructure = try
            @macroexpand @trait_dispatcher process_items_tuple((x, y))::SequenceBasic
            nothing
        catch caught
            caught
        end
        @test dispatcher_destructure isa ArgumentError
        @test occursin("does not support destructuring", sprint(showerror, dispatcher_destructure))

        trait_function_keyword = try
            @macroexpand @trait_function process_items_keyword(x; y)::DynamicVectorBasic = :bad
            nothing
        catch caught
            caught
        end
        @test trait_function_keyword isa ArgumentError
        @test occursin("does not support keyword arguments", sprint(showerror, trait_function_keyword))

        trait_function_non_symbol_typed = try
            @macroexpand @trait_function process_items_nonsymbol((x, y)::Tuple)::DynamicVectorBasic = :bad
            nothing
        catch caught
            caught
        end
        @test trait_function_non_symbol_typed isa ArgumentError
        @test occursin("typed arguments of the form `name::Type`", sprint(showerror, trait_function_non_symbol_typed))
    end
end
