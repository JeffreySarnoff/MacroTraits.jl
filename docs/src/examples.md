# Examples

This page moves from the smallest useful pattern to more realistic extension scenarios.

## Simple Use

Use `@def_trait` when you want a single public function to route to different implementations based on the first argument's structural category.

```julia
@def_trait Sequence begin
    DynamicVector => [Vector]
    StaticTuple   => [Tuple, NamedTuple]
end

@trait_dispatch describe_items(x) :: Sequence

@trait_function describe_items(x) :: DynamicVector = "vector length $(length(x))"
@trait_function describe_items(x) :: StaticTuple = "tuple length $(length(x))"

describe_items([1, 2, 3])
# "vector length 3"

describe_items((1, 2, 3))
# "tuple length 3"
```

Use this shape when the public behavior is the same operation, but the implementation differs by category.

## Common Use: Additional Arguments

Only the first argument participates in trait resolution. The remaining arguments pass through unchanged.

```julia
@def_trait SequenceScale begin
    DynamicVectorScale => [Vector]
    StaticTupleScale   => [Tuple]
end

@trait_dispatch scale_items(data, factor) :: SequenceScale

@trait_function scale_items(data, factor) :: DynamicVectorScale = data .* factor
@trait_function scale_items(data, factor) :: StaticTupleScale = map(x -> x * factor, data)

scale_items([1, 2], 10)
# [10, 20]

scale_items((1, 2), 10)
# (10, 20)
```

This is the common case when the trait selects the algorithm family and the remaining arguments provide configuration.

## Common Use: Preserve A Typed Public Boundary

The public signature is preserved exactly as written. That means ordinary Julia method filtering still happens before trait routing.

```julia
@def_trait TypedSequence begin
    TypedVectorState => [Vector]
end

@trait_dispatch process_int_vector(x::Vector{Int}) :: TypedSequence
@trait_function process_int_vector(x::Vector{Int}) :: TypedVectorState = sum(x)

process_int_vector([1, 2, 3])
# 6

process_int_vector(Float32[1, 2, 3])
# MethodError on the public function
```

Use this when the trait is only part of your contract and you still want ordinary Julia dispatch to enforce a narrower API.

## Advanced Application: Open-World Extension

Downstream code can extend an existing trait without editing the original `@def_trait` block.

```julia
@def_trait SequenceExtension begin
    DynamicVectorExtension => [Vector]
    StaticTupleExtension   => [Tuple]
end

@trait_dispatch summarize_items(x) :: SequenceExtension

@trait_function summarize_items(x) :: DynamicVectorExtension = (:dynamic, length(x))
@trait_function summarize_items(x) :: StaticTupleExtension = (:static, length(x))

struct MyTree
    leaves::Int
end

Base.length(tree::MyTree) = tree.leaves

@trait_map SequenceExtension StaticTupleExtension => MyTree

summarize_items(MyTree(5))
# (:static, 5)
```

Use `@trait_map` for this path instead of writing low-level trait methods by hand. It keeps the extension aligned with the generated mappings.

## Advanced Application: Public Docs And Private Implementations

The public function is the stable API surface. The trait-specific methods are implementation detail entry points.

```julia
@def_trait NormalizationStyle begin
    MutableNormalization => [Vector]
end

"""
    normalize_items(x)

Public entry point for normalization based on the `NormalizationStyle` trait.
"""
@trait_dispatch normalize_items(x) :: NormalizationStyle

"""
Implementation for mutable vectors.
"""
@trait_function normalize_items(x) :: MutableNormalization begin
    total = sum(x)
    return x ./ total
end

normalize_items([2.0, 3.0, 5.0])
# [0.2, 0.3, 0.5]
```

Documenting the macros this way keeps user-facing behavior attached to the public symbol rather than to the generated worker methods.
