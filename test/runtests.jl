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
end
