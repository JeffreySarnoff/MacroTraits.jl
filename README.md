# MacroTraits.jl

[![CI](https://github.com/JeffreySarnoff/MacroTraits.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JeffreySarnoff/MacroTraits.jl/actions/workflows/CI.yml)
[![Documentation](https://github.com/JeffreySarnoff/MacroTraits.jl/actions/workflows/Docs.yml/badge.svg)](https://github.com/JeffreySarnoff/MacroTraits.jl/actions/workflows/Docs.yml)
[![codecov](https://codecov.io/gh/JeffreySarnoff/MacroTraits.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JeffreySarnoff/MacroTraits.jl)

MacroTraits.jl provides a small trait-dispatch surface built around four macros.

## Mental Model

1. `@def_trait` defines a trait abstract type, trait-state types, and trait resolution methods.
2. `@trait_dispatcher` defines the public function plus a hidden worker function.
3. `@trait_function` adds methods to the hidden worker keyed by trait state.
4. `@trait_map` adds new type-to-state mappings to an existing trait.

At call time, the public function computes `Trait(x)` for the first argument and forwards the trait-state value plus the original arguments to the hidden worker. The worker name is intentionally internal and namespaced by MacroTraits rather than using a simple `_function_name` convention.

If a trait resolves successfully but no matching `@trait_function` implementation exists for that trait state and signature, the call fails as the public function rather than exposing the internal worker in the normal error path.

## Example 1: Basic Single-Argument Trait

This example shows the most fundamental use case: categorizing generic types into traits and routing a single-argument function.

```julia
# 1. Setup the trait
@def_trait Sequence begin
    DynamicVector => [Vector]
    StaticTuple   => [Tuple, NamedTuple]
end

# 2. Create the public dispatcher and hidden worker
@trait_dispatcher process_items(x) :: Sequence

# 3. Add trait-state-specific worker methods
@trait_function process_items(x) :: DynamicVector begin
    return "Vector logic compiled. Length: $(length(x))"
end

@trait_function process_items(x) :: StaticTuple begin
    return "Tuple logic compiled. Length: $(length(x))"
end

# 4. Test it!
process_items([1, 2, 3]) 
# "Vector logic compiled. Length: 3"
```

## Example 2: Multi-Argument Dispatch

`@trait_dispatcher` routes on the trait of the first argument and passes the remaining arguments through unchanged to the hidden worker method.

```julia
# Define a public method that routes on `data`
@trait_dispatcher scale_data(data, factor) :: Sequence

# Implement the vector variation
@trait_function scale_data(data, factor) :: DynamicVector begin
    data .*= factor 
    return data
end

# Implement the tuple variation
@trait_function scale_data(data, factor) :: StaticTuple begin
    return map(v -> v * factor, data) 
end

# Usage:
v = [1.0, 2.0]
scale_data(v, 10.0) 
# Output: [10.0, 20.0] (v is mutated)

t = (1.0, 2.0)
scale_data(t, 10.0) 
# Output: (10.0, 20.0) (returns new tuple, t is unchanged)
```

## Example 3: Open-World Extensibility

Because trait resolution is ordinary Julia method dispatch, downstream users can map their own types to an existing trait without editing the original `@def_trait` block.

```julia
struct MyCustomTree
    leaves::Int
end

# Optional functionality used by the example implementation
Base.length(t::MyCustomTree) = t.leaves

# Map the new type into the existing trait system
@trait_map Sequence StaticTuple => MyCustomTree

my_tree = MyCustomTree(5)

process_items(my_tree) 
```

## Public Docs Versus Implementation Docs

Place the public API docstring on `@trait_dispatcher`. Place implementation-specific docstrings on `@trait_function` methods.

```julia
"""
    process_items(x)

Public entry point for Sequence-based routing.
"""
@trait_dispatcher process_items(x) :: Sequence

"""
Implementation for dynamically sized collections.
"""
@trait_function process_items(x) :: DynamicVector = :dynamic
```

## Advanced Extension Notes

For most extension work, prefer `@trait_map`.

If you need to define trait resolution methods manually, keep these rules:

1. Return a trait-state instance such as `StaticTuple()`, not a type object.
2. Preserve the same semantic contract as the generated methods: trait resolution should be safe to treat as foldable and aggressively const-propagated when you annotate it that way.
3. Do not call MacroTraits internal worker functions directly. They are implementation details, not supported extension points.

## Best Practice Example

```julia
"""
    Sequence

An industrial trait determining if a collection is dynamically or statically sized.
"""
@def_trait Sequence begin
    DynamicVector => [Vector]
    StaticTuple   => [Tuple, NamedTuple]
end

"""
    process_items(x)

Routes incoming data to highly optimized mapping logic depending on its `Sequence`.
"""
@trait_dispatcher process_items(x) :: Sequence

"""
Applies dynamic, in-place scaling to arrays.
"""
@trait_function process_items(x::Vector{Float64}) :: DynamicVector begin
    x .*= 2.0
    return x
end
```

## `@trait_function`

```julia
# Uses the Two-Argument Macro (Block Form)
@trait_function process_items(x) :: DynamicVector begin
    println("Performing heavy lifting...")
    return "Vector logic. Length: $(length(x))"
end

# Uses the Single-Argument Macro (One-Liner Form)
@trait_function process_items(x) :: StaticTuple = "Tuple logic. Length: $(length(x))"
```

## Technical Note

`@trait_dispatcher` preserves the public signature exactly as you write it, including a typed first argument. `@trait_function` preserves the signature you write on the hidden worker method. For example, if you define `@trait_dispatcher trait_dispatch(x::Vector{Int64}) :: Sequence` and `@trait_function trait_dispatch(x::Vector{Int64}) :: DynamicVector = ...`, a call such as `trait_dispatch(Float32[1, 2, 3])` fails at the public API boundary instead of falling through to an internal worker-method error.

The supported signature surface is intentionally narrow: positional arguments written as `name` or `name::Type`. Default values, keyword arguments, varargs, and destructuring are rejected during macro expansion with explicit `ArgumentError`s.

For open-world extension, prefer `@trait_map` over writing trait resolution methods by hand so the mapping follows the same compiler annotations as mappings generated by `@def_trait`.

## Installation

```julia
using Pkg
Pkg.add("MacroTraits")
```

## Development

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
Pkg.test()
```

## License

MIT
