# MacroTraits.jl Review Report

Date: 2026-04-02

## Scope

This review covers the current public macro interface, the documented usage model, the observable runtime and expansion behavior of the macros, and the logical interdependencies between the generated pieces.

Files reviewed:

- [src/MacroTraits.jl](src/MacroTraits.jl)
- [README.md](README.md)
- [docs/src/index.md](docs/src/index.md)
- [test/runtests.jl](test/runtests.jl)

Validation performed:

- Read source and docs.
- Ran the README-style happy-path example.
- Inspected macro expansion for typed signatures.
- Exercised one edge case where the dispatcher is given a typed first argument.

## Executive Summary

The core idea works: the package can define a trait, route through a dispatcher, and dispatch on trait state-specific worker methods. The main issue at the start of this review was not nonfunctionality; it was that the user interface, documentation, and tests did not fully agree with the implementation.

Those issues have now been addressed in the current workspace revision. `@trait_dispatch` preserves the public first-argument signature, the documentation matches the implemented four-macro model, open-world extension has a dedicated `@trait_map` API, internal worker naming is namespaced instead of relying on `_function_name`, and the tests now exercise the real supported contract.

## Findings

### 1. High (Resolved): public first-argument constraints are now preserved

Relevant code:

- [src/MacroTraits.jl](src/MacroTraits.jl#L105-L118)
- [README.md](README.md#L155-L159)
- [test/runtests.jl](test/runtests.jl#L33-L51)

Current behavior:

- `@trait_dispatch` preserves the first argument exactly as written in the public method signature.
- A typed dispatcher such as `@trait_dispatch process_items(x::Vector{Int}, y) :: Sequence` now expands to a public method that keeps `x::Vector{Int}` in its signature.
- A mismatched call now fails at the public API boundary rather than leaking into the hidden worker.

Current expansion shape:

```julia
@trait_dispatch process_items(x::Vector{Int}, y) :: Sequence
```

expands to a public method equivalent to:

```julia
function process_items(x::Vector{Int}, y)
    return _process_items(Sequence(x), x, y)
end
```

Impact:

- The public API now matches the source-level contract.
- Typed entry points reject mismatched calls where users expect them to fail.
- The internal worker no longer receives calls that should have been rejected by the public method.

Recommendation outcome:

- Resolved as recommended.

Implementation status:

- Fixed in the current workspace revision.
- `@trait_dispatch` now preserves the first argument exactly as written in the public method signature.
- Regression coverage was added to verify that mismatched calls fail at the public API boundary rather than at the hidden worker method.

### 2. High (Resolved): documentation and implementation now describe the same system

Relevant files:

- [README.md](README.md#L7-L16)
- [README.md](README.md#L95-L110)
- [README.md](README.md#L155-L159)
- [docs/src/index.md](docs/src/index.md#L7-L20)
- [docs/src/index.md](docs/src/index.md#L42-L52)
- [src/MacroTraits.jl](src/MacroTraits.jl#L3-L179)

Current behavior:

- The README and docs now describe the actual four-macro model: `@def_trait`, `@trait_dispatch`, `@trait_function`, and `@trait_map`.
- The docs now describe runtime routing in terms of `Trait(x)` producing a trait-state value that is forwarded to an internal worker.
- Stale claims about `dispatch_trait`, `::Type{Trait}`, and `@generated` behavior have been removed.
- The typed first-argument note now matches the current dispatcher implementation.

Impact:

- The mental model presented to users now matches the generated code shape.
- Extension authors are directed toward the supported extension path.
- The docs no longer teach behaviors that the package does not implement.

Recommendation outcome:

- Resolved as recommended, with the addition of `@trait_map` as an explicit fourth macro in the public model.

Implementation status:

- Fixed in the current workspace revision.
- README and docs now describe the actual four-macro model.
- Claims about `dispatch_trait`, `::Type{Trait}`, and `@generated` behavior were removed.
- The typed first-argument note now matches the current implementation.

### 3. Medium (Resolved): internal worker naming is now namespaced rather than `_function_name`

Relevant code:

- [src/MacroTraits.jl](src/MacroTraits.jl#L5-L5)
- [src/MacroTraits.jl](src/MacroTraits.jl#L108-L118)
- [src/MacroTraits.jl](src/MacroTraits.jl#L135-L177)
- [test/runtests.jl](test/runtests.jl#L92-L103)

Current behavior:

- `@trait_dispatch foo(x) :: Trait` generates a namespaced internal worker symbol through `trait_worker_name`.
- `@trait_function foo(...) :: State ...` targets the same namespaced internal worker.
- User-defined underscore helpers such as `_process_items_collision` no longer collide with the trait worker path.

Impact:

- The macros are still interdependent, but the coupling is now mediated through an internal helper function instead of a user-visible underscore naming convention.
- Collision risk with common helper names is materially reduced.
- The public API no longer depends on users avoiding `_function_name` identifiers in their own code.

Why this matters:

- The interface remains declarative, but the internal worker symbol is now clearly an implementation detail owned by MacroTraits.

Recommendation outcome:

- Resolved by generating a namespaced worker symbol.

Implementation status:

- Fixed in the current workspace revision.
- MacroTraits now uses a namespaced internal worker symbol instead of the `_function_name` convention.
- Regression coverage was added to verify that user-defined underscore helpers no longer collide with trait worker methods.

### 4. Medium (Resolved): open-world extension now has a dedicated public macro

Relevant code and docs:

- [src/MacroTraits.jl](src/MacroTraits.jl#L7-L15)
- [src/MacroTraits.jl](src/MacroTraits.jl#L61-L72)
- [README.md](README.md#L75-L93)
- [README.md](README.md#L157-L159)
- [docs/src/index.md](docs/src/index.md#L17-L18)
- [docs/src/index.md](docs/src/index.md#L46-L48)

Current behavior:

- Trait resolution methods are still generated with `Base.@assume_effects :foldable` and `Base.@constprop :aggressive`.
- Open-world extension is now exposed as `@trait_map`, which reuses the same mapping generation logic as `@def_trait`.
- The docs and README now recommend `@trait_map` instead of asking users to reproduce the compiler annotations by hand.

Impact:

- The default extension path now preserves the same compiler annotations as built-in mappings.
- Extension authors no longer need to copy low-level mapping boilerplate for the normal open-world case.

Recommendation outcome:

- Resolved by adding `@trait_map` and documenting it as the preferred extension path.

Implementation status:

- Fixed in the current workspace revision.
- A dedicated `@trait_map` macro now provides open-world trait extension without requiring users to hand-write compiler annotations.
- README and docs now recommend `@trait_map` as the default extension path.

### 5. Medium (Resolved): documentation now distinguishes public entry-point docs from implementation docs

Relevant code and docs:

- [README.md](README.md#L95-L110)
- [README.md](README.md#L113-L139)
- [docs/src/index.md](docs/src/index.md#L50-L52)
- [src/MacroTraits.jl](src/MacroTraits.jl#L123-L177)

Current behavior:

- Public entry-point docs are documented as belonging on `@trait_dispatch`.
- Implementation-specific docs are documented as belonging on `@trait_function` methods.
- The documentation no longer implies that implementation docstrings are automatically merged into the public function symbol.

Impact:

- The documentation now matches the actual separation between public entry point and internal implementation methods.
- Users are less likely to assume that method-level implementation docs will surface as a single public API doc.

Recommendation outcome:

- Resolved by documenting the behavior explicitly.

Implementation status:

- Fixed in the current workspace revision.
- README and docs now distinguish between public entry-point docs on `@trait_dispatch` and implementation docs on `@trait_function`.

### 6. High (Resolved): the test suite now covers the package contract

Relevant file:

- [test/runtests.jl](test/runtests.jl#L1-L105)

Current state:

- The test suite covers basic dispatch, multi-argument dispatch, typed first-argument preservation, open-world extension via `@trait_map`, unmapped-type failures, and worker-name collision isolation.

Coverage now includes:

- Basic happy-path trait creation and dispatch.
- Multi-argument dispatch.
- Open-world extension.
- Error behavior for unmapped types.
- Typed first-argument dispatcher behavior.
- Worker-name collision behavior.
- Documentation examples as executable tests.

Impact:

- The supported contract is now exercised directly by the test suite.
- Regressions in dispatcher signature preservation, extension behavior, and worker isolation are more likely to be caught immediately.

Recommendation outcome:

- Resolved for the core supported interface patterns.

Implementation status:

- Fixed in the current workspace revision.
- The test suite now covers basic dispatch, multi-argument dispatch, typed first-argument preservation, open-world extension, unmapped-type failures, and worker-name collision isolation.

## User Interface Reconsideration

### What is good in the current interface

- The four-macro model is still compact.
- The happy path is readable.
- The state-based worker dispatch model is understandable once expanded mentally.
- Open-world extension is now a first-class part of the public API.

### Where the interface still needs care

- The worker remains an implementation detail, so users still benefit from understanding that `@trait_dispatch` and `@trait_function` cooperate through generated internals.
- Public and implementation documentation are now clearly separated, but Julia help/discoverability will still reflect that separation in the method table.
- Manual trait-resolution methods are still possible, so the semantic contract for those advanced cases remains worth documenting carefully.

### Suggested direction

If the goal is a stable and understandable user experience, the current revision is substantially closer to that target. Further work should focus on refinement rather than basic contract repair.

Recommended priorities:

1. Keep public signatures exact and stable.
2. Keep worker-function coupling internal and collision-resistant.
3. Prefer first-class macros for supported extension paths.
4. Keep docs and examples tied to executable behavior.
5. Expand tests before further surface expansion.

## Micro Behaviors And Interdependencies

The following low-level behaviors materially affect processing:

1. Trait resolution is value-based, not type-token-based.
   - The dispatcher computes `Trait(x)` and passes a state instance into the worker.

2. The dispatcher and implementation macros are coupled through `trait_worker_name(func_name)`.
   - This remains the key hidden interdependency in the system, but it is now owned explicitly by MacroTraits.

3. The outer dispatcher method governs the public contract, while the inner worker governs trait-state-specific correctness.
   - Typed first-argument mismatches now fail at the public API boundary rather than at the worker layer.

4. Compile-time assumptions are still part of the extension surface.
   - `@trait_map` now provides a safe default path that preserves those assumptions automatically.

5. Documentation and tests are now much closer to the enforcement loop.
   - The remaining risk is future drift if new API claims are added without matching tests or examples.

## Recommended Next Steps

1. Consider whether worker symbols should remain deterministic or move behind an even more opaque registry-like mechanism.
2. Decide how much of the advanced manual trait-resolution path should be documented versus intentionally left as internal expertise.
3. Expand tests to cover documentation examples more directly, ideally with doctest-style coverage.
4. Revisit error surfaces so internal worker names are minimized in any remaining user-facing failures.
5. Continue updating the report as a current-state engineering note rather than a historical bug list.

## Bottom Line

MacroTraits.jl now presents a substantially more honest and internally consistent interface than it did at the start of this review. The main design repairs identified here have been implemented: public signatures are preserved, the documentation matches the code, open-world extension has a first-class API, worker naming is collision-resistant, and the tests cover the actual package contract. The remaining work is refinement, not basic contract repair.
