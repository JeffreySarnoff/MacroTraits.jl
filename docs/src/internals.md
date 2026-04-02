# Internals

This page describes how each macro contributes to the generated system and how the pieces work together.

## Design Intent

MacroTraits keeps the public surface small and the generated internals predictable.

- Trait resolution is ordinary Julia method dispatch.
- The public function remains the user-facing boundary.
- Worker functions are private implementation detail.
- Expansion-time validation rejects signatures that would make the generated code ambiguous or surprising.

## `@def_trait`

`@def_trait TraitName begin ... end` performs three jobs:

1. It defines the abstract trait type.
2. It defines one concrete trait-state type for each mapping line.
3. It emits trait-resolution methods like `TraitName(::SomeType) = SomeState()`.

Conceptually, this:

```julia
@def_trait Sequence begin
    DynamicVector => [Vector]
    StaticTuple   => [Tuple, NamedTuple]
end
```

produces a trait type, concrete state markers, and foldable trait-resolution methods.

It also emits a fallback `TraitName(x::Any)` method that throws a `MethodError`. That keeps unmapped types failing at trait resolution rather than silently falling through to an unrelated implementation.

## `@trait_map`

`@trait_map TraitName StateName => TypeExpr` extends an existing trait after the original declaration.

It reuses the same mapping-generation path as `@def_trait`, but only emits additional trait-resolution methods. It does not redefine the trait type or trait-state structs.

This is the intended open-world extension mechanism.

## `@trait_dispatch`

`@trait_dispatch f(args...) :: TraitName` defines the public entry point and a namespaced hidden worker.

The expansion flow is:

1. Parse and validate the annotated call shape.
2. Preserve the user-written public signature exactly.
3. Compute `TraitName(first_argument)` inside the generated method.
4. Forward the resulting trait-state value plus the original arguments to the hidden worker.

Important properties:

- Only the first argument determines the trait.
- The public signature is not widened by MacroTraits.
- A `gensym` temporary avoids accidental local-name capture.
- A `GlobalRef` binds helper calls back to `MacroTraits`, so expansion in another module remains hygienic.

## `@trait_function`

`@trait_function` supplies the trait-state-specific implementations for the hidden worker.

Both supported forms:

```julia
@trait_function f(x) :: SomeState begin
    ...
end

@trait_function f(x) :: SomeState = value
```

normalize to the same internal worker-method shape. The first argument of the generated worker is the trait-state marker, followed by the original arguments.

This means the trait state is part of the internal dispatch key, while the public function remains clean for callers.

## Macro Interplay

The macros are intended to be used as a pipeline:

1. `@def_trait` creates the trait vocabulary.
2. `@trait_dispatch` creates the public function boundary.
3. `@trait_function` fills in implementations for each trait state.
4. `@trait_map` extends the vocabulary later when downstream code introduces new types.

Operationally, a call looks like this:

1. Caller invokes the public function.
2. The public function computes the trait from the first argument.
3. The generated code invokes the hidden worker with the trait-state instance and original arguments.
4. Julia dispatch selects the matching worker method.

## Error Boundaries

MacroTraits deliberately keeps errors aligned with the public API.

- If no trait mapping exists, trait resolution fails as `TraitName(::Type)`.
- If a trait mapping exists but no implementation exists, the failure is reshaped to the public function rather than exposing the internal worker in the normal error path.
- If the signature shape is unsupported, macro expansion throws an `ArgumentError` before methods are generated.

This separation helps users understand whether the problem is missing mapping, missing implementation, or invalid macro input.

## Supported Signature Surface

MacroTraits accepts only simple positional arguments in the forms `name` and `name::Type`.

The parser rejects:

- default values
- keyword arguments
- varargs
- destructuring arguments

This is a deliberate constraint. It keeps the generated worker signatures straightforward and avoids hidden semantic differences between the public function and the worker methods.

## Hygiene And Private Boundaries

The implementation uses three important internal rules to keep macro expansion predictable:

1. Generated worker names are namespaced by MacroTraits rather than using a short `_name` convention.
2. Temporary locals inside generated functions use `gensym`.
3. Internal helper references are emitted with `GlobalRef` so caller modules do not need to define MacroTraits internals.

These details matter most when the macros are expanded in downstream modules or in codebases that already have similarly named bindings.
