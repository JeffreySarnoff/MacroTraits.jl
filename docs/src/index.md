# MacroTraits.jl

```@meta
CurrentModule = MacroTraits
```

MacroTraits.jl implements trait-based routing with four macros.

## How It Works

1. `@def_trait TraitName begin ... end`
   Defines the trait abstract type, defines the trait-state types, and generates trait resolution methods such as `TraitName(x)`.
2. `@trait_dispatcher f(args...) :: TraitName`
   Defines the public function `f` and a hidden worker function used internally by MacroTraits.
3. `@trait_function f(args...) :: TraitState ...`
   Adds methods to the hidden worker, dispatching on the computed trait-state value.
4. `@trait_map TraitName TraitState => TypeExpr`
   Extends an existing trait with new type-to-state mappings using the same compiler annotations as the generated mappings.

At runtime, the public function computes `TraitName(first_argument)` and forwards that trait-state value plus the original arguments to the hidden worker.

## Example

```julia
@def_trait Sequence begin
    DynamicVector => [Vector]
    StaticTuple   => [Tuple, NamedTuple]
end

@trait_dispatcher process_items(x) :: Sequence

@trait_function process_items(x) :: DynamicVector = :dynamic
@trait_function process_items(x) :: StaticTuple = :static

process_items([1, 2, 3])
# :dynamic

process_items((1, 2, 3))
# :static
```

## Signature Preservation

The public signature written in `@trait_dispatcher` is preserved exactly. If you define `@trait_dispatcher f(x::Vector{Int}) :: Sequence`, then a call with `Vector{Float32}` fails at the public API boundary.

## Notes For Extension Authors

Prefer `@trait_map` when extending an existing trait with new types. It generates the same foldable, constprop trait-resolution methods as `@def_trait`.

## Public Docs

Attach public entry-point documentation to `@trait_dispatcher`. Attach implementation-specific documentation to `@trait_function` methods.
