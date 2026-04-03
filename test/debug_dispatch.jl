using MacroTraits

@def_trait TestTrait begin
    StateA => [Vector]
    StateB => [Tuple]
end

println("Registry after @def_trait: ", MacroTraits._trait_for_state)

@trait_function foo(x)::StateA = :from_state_a
@trait_function foo(x)::StateB = :from_state_b

println("foo([1,2,3]) = ", foo([1, 2, 3]))
println("foo((1,2,3)) = ", foo((1, 2, 3)))
println("All OK")
