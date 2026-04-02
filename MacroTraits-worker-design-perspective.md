# MacroTraits Worker Design Perspective

Date: 2026-04-02

## Question

Should MacroTraits keep deterministic internal worker names, or move to an explicit registry model?

## Short Answer

The best current design is to keep deterministic worker naming, but keep it namespaced and funneled through a single internal abstraction such as `trait_worker_name`.

I would not move MacroTraits to an explicit runtime registry model at this stage.

The current namespaced deterministic approach is the better fit for the package's design goals:

- simple macro expansion
- predictable generated code
- normal Julia method dispatch
- minimal runtime machinery
- low conceptual overhead for users and maintainers

If MacroTraits later grows features that genuinely require opaque worker identity, late binding, or macro expansion across disconnected compilation boundaries, then a registry-backed design could become justified. Today, that would add complexity faster than it adds value.

## Current State

The package currently uses a deterministic internal worker symbol generated from the public function name:

- [src/MacroTraits.jl](src/MacroTraits.jl#L5)
- [src/MacroTraits.jl](src/MacroTraits.jl#L108)
- [src/MacroTraits.jl](src/MacroTraits.jl#L137)
- [src/MacroTraits.jl](src/MacroTraits.jl#L171)

That means:

1. `@trait_dispatcher foo(x) :: Trait` and `@trait_function foo(...) :: State ...` independently derive the same worker symbol.
2. No mutable shared registry is needed for those macros to cooperate.
3. The worker is still internal, but it is deterministic.

## Evaluation Criteria

The decision should be judged against the properties that matter most for MacroTraits:

1. Expansion simplicity
2. Predictability of generated code
3. Compatibility with Julia precompilation and world-age behavior
4. Ease of reasoning about errors and method tables
5. Collision avoidance
6. Future extensibility
7. API stability

## Option A: Deterministic Namespaced Workers

### Deterministic Model

The macros compute the worker symbol from the public function name through an internal helper:

```julia
trait_worker_name(func_name::Symbol) = Symbol("__macrotraits_trait_worker__", func_name)
```

### Deterministic Strengths

1. Very low machinery cost

There is no registry object to initialize, mutate, serialize, or reconcile across modules. Macro expansion remains straightforward AST generation.

1. Expansion is self-contained

`@trait_dispatcher` and `@trait_function` can cooperate purely by code generation. They do not need runtime negotiation to find each other.

1. Good fit for Julia dispatch

The current design keeps the worker as an ordinary Julia function with ordinary Julia methods. That preserves normal tooling expectations and method-table behavior.

1. Precompilation-friendly

Deterministic generated names are easier to reason about than a registry that may depend on module initialization order or mutable global state.

1. Easy to debug

When needed, developers can inspect the expanded code and see the actual worker symbol directly. That helps during macro debugging and performance investigation.

1. Already good enough for collision resistance

The move from `_foo` to `__macrotraits_trait_worker__foo` materially reduced accidental collisions with ordinary user helpers.

### Deterministic Weaknesses

1. The worker name is still derivable

It is internal, but not opaque. Advanced users can still discover or call it if they go looking.

1. The design still depends on shared naming logic

The coupling moved from a crude naming convention to a namespaced convention, but it is still coupling through symbol derivation.

1. Error surfaces may still expose internals

Some user-facing failures may still mention the worker symbol unless additional error shaping is added.

## Option B: Explicit Registry Model

### Registry Model

Instead of deriving a symbol, the macros would coordinate through a registry that maps a public function identity to a worker identity.

This could take several forms:

1. A mutable runtime dictionary keyed by function symbol or method signature
2. A module-level constant registry populated during macro expansion
3. A generated hidden binding per dispatcher, looked up later by `@trait_function`

### Registry Strengths

1. Truly opaque worker identity

The worker name would not need to be derivable from the public function name.

1. More design headroom for future indirection

A registry can support extra metadata, custom diagnostics, or richer relationships between public entry points and internal workers.

1. Cleaner long-term separation if the system becomes more dynamic

If MacroTraits eventually needs explicit linker-like behavior between declarations and implementations, a registry gives a place to store that metadata.

### Registry Weaknesses

1. Considerably more complexity

The package would need a durable rule for when entries are created, when they are read, what they are keyed by, and what happens if the macros are expanded in a surprising order.

1. More failure modes

Registry misses, duplicate registrations, stale entries, and module-load ordering issues are all new classes of bugs.

1. Harder precompilation story

Any design that depends on mutable global state or initialization sequencing is more delicate under precompilation, package loading, and incremental method definition.

1. Less transparent debugging

Instead of inspecting expansion and seeing a worker symbol directly, maintainers may need to reason about hidden state in addition to generated code.

1. Misaligned with current needs

MacroTraits currently benefits from being small, mostly static, and dispatch-oriented. A registry is more useful when the system is dynamic or plugin-like. MacroTraits is not there today.

## Why I Do Not Recommend a Registry Right Now

The current problem space is mostly solved by the namespaced deterministic approach.

The package already has:

1. stable cooperation between `@trait_dispatcher` and `@trait_function`
2. materially reduced collision risk
3. no need for runtime global coordination
4. a clean path for tests and documentation

A registry would mainly buy stronger opacity, but at the cost of introducing statefulness into a design that is currently attractive because it is mostly pure code generation.

That is the wrong trade at the current scale of the package.

## Best Perspective

The right way to think about this is:

- deterministic naming is not the problem
- unscoped or user-adjacent deterministic naming is the problem

MacroTraits has already crossed the important threshold by moving from `_foo` to a clearly internal, namespaced worker symbol. That preserves the benefits of deterministic expansion while avoiding most of the practical collision cost that motivated the original concern.

So the question is not really "deterministic versus registry" in the abstract. The real question is whether MacroTraits needs hidden runtime coordination badly enough to justify stateful machinery.

My view is no, not yet.

## Recommended Direction

### Recommendation

Keep deterministic names, keep them namespaced, and keep all worker resolution behind one internal helper.

In other words:

1. Do not adopt a runtime registry now.
2. Keep `trait_worker_name` as the single source of truth.
3. Treat worker names as private implementation details in docs and errors.
4. Add tests around the remaining sharp edges rather than replacing the model.

### What to Improve Instead of Adding a Registry

1. Better error shaping

Where practical, convert internal worker-related `MethodError`s into errors that speak in terms of the public trait API.

1. More explicit internal/private boundary

Keep worker naming conventions undocumented except where needed for maintainers.

1. Stronger documentation for advanced extension cases

The remaining complexity is less about naming and more about how advanced users reason about trait resolution and method ownership.

1. More tests around public-versus-internal boundaries

Continue expanding tests that verify internal worker details do not leak into normal usage.

## When a Registry Would Start Making Sense

I would revisit the registry decision only if MacroTraits grows one or more of these needs:

1. Dispatcher and implementation macros must coordinate across disconnected compilation or delayed loading boundaries.
2. Worker identity must be opaque enough that deterministic derivation is itself considered a design failure.
3. The package wants richer metadata attached to each dispatcher-worker pair.
4. The package evolves toward a plugin or framework model rather than a small macro utility.

If those conditions appear, then a registry may become the right architecture. Until then, it is premature.

## Practical Recommendation For This Repository

For this repository specifically, I recommend the following stance:

1. Keep the deterministic namespaced worker model now.
2. Keep the internal helper abstraction so the strategy can change later without rewriting every macro.
3. Add future work only around error-surface cleanup and maintainer-facing documentation.
4. Avoid a registry until a real feature requirement forces it.

## Bottom Line

MacroTraits should keep deterministic worker names for now.

The package already has the right correction: deterministic but strongly namespaced internal workers. That gives most of the benefit of a registry-worthy encapsulation without importing the complexity, statefulness, and new failure modes of an explicit registry model.

The best next design step is not a registry. It is refining the internal/private boundary around the existing deterministic worker design.
