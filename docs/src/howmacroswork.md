How the macros work (MacroTraits.jl — the active file)
There are four macros. Together they implement the Holy Traits pattern where dispatch is routed through a type-level trait function rather than the argument type directly.

@def_trait

```
@def_trait SequenceTrait begin
    DynamicVector => [Vector]
    StaticTuple  => [Tuple, NamedTuple]
end
```
Expands to:
```

1. abstract type SequenceTrait end   # the trait umbrella type

2. A fallback SequenceTrait(x::Any) that throws MethodError for unmapped types

3. For each mapping line:

struct DynamicVector <: SequenceTrait end  # a singleton state type

SequenceTrait(::Vector) = DynamicVector()  # the trait classifier
     (marked :foldable/:aggressive so the compiler eliminates it at compile time)
```

@trait_dispatch

@trait_dispatch process(x, y) :: SequenceTrait

Expands to:

```
function process end

function __macrotraits_trait_worker__process end

function process(x, y)
    local _state = SequenceTrait(x)    # classify via trait
    invoke_trait_worker(process, 
        __macrotraits_trait_worker__process,
        _state, 
        x, y)

                         # dispatch to worker
end
```
The first argument is always the one routed through the trait. The worker name is mangled to avoid collisions. invoke_trait_worker re-raises MethodError against the public function if no worker method matches, hiding the internal indirection from the user.

@trait_function

@trait_function process(x, y) :: DynamicVector = x .* y
# or block form:
@trait_function process(x, y) :: StaticTuple begin 
    map(v -> v * y, x)
end

Expands to a method on the private worker:


__macrotraits_trait_worker__process(::DynamicVector, x, y) = x .* y
The ::StateName annotation selects which trait branch this implements, not a type constraint on the arguments.

@trait_map

@trait_map SequenceTrait StaticTuple => MyType
Adds a new classifier method after @def_trait, enabling open-world extension without reopening the original definition:


SequenceTrait(::MyType) = StaticTuple()
Call flow at runtime

```
process([1,2], 3)
  → SequenceTrait([1,2])          # returns DynamicVector()  → __macrotraits_trait_worker__process(DynamicVector(), [1,2], 3)  
  → [3, 6]
```

Because SequenceTrait is annotated :foldable and :constprop :aggressive, Julia's compiler resolves the trait branch at compile time — the runtime call is a direct dispatch with zero overhead.

What TraitMacros.jl contains
That file holds a work-in-progress version with the auto-dispatch feature — it is not included from MacroTraits.jl yet, so it has no effect on the running package.