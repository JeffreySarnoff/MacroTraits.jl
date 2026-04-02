module MacroTraits

export @def_trait, @trait_map, @trait_dispatcher, @trait_function

trait_worker_name(func_name::Symbol) = Symbol("__macrotraits_trait_worker__", func_name)

function trait_mapping_exprs(trait_name, state_name, types_expr)
    types = types_expr isa Expr && types_expr.head === :vect ? types_expr.args : [types_expr]
    exprs = Any[]
    for t in types
        push!(exprs, quote
            Base.@assume_effects :foldable Base.@constprop :aggressive $trait_name(::$t) = $state_name()
        end)
    end
    return exprs
end

macro def_trait(trait_name, block)
    if !isa(trait_name, Symbol)
        throw(ArgumentError("Trait name must be a Symbol"))
    end
    if !(block isa Expr && block.head === :block)
        throw(ArgumentError("Expected a begin/end block for trait mappings"))
    end

    exprs = Any[]

    # 1. Emit Abstract Type
    push!(exprs, :(Base.@__doc__ abstract type $trait_name end))

    # 2. CLEAN FALLBACK: Dispatch on any instance `x::Any`.
    # This naturally acts as the lowest-priority fallback method.
    push!(exprs, quote
        Base.@assume_effects :foldable Base.@constprop :aggressive function $trait_name(x::Any)
            throw(MethodError($trait_name, (typeof(x),)))
        end
    end)

    # 3. Parse mappings
    for line in block.args
        if line isa LineNumberNode
            push!(exprs, line)
            continue
        end

        if line isa Expr && line.head === :call && line.args[1] === :(=>)
            state_name = line.args[2]
            types_expr = line.args[3]

            push!(exprs, :(struct $state_name <: $trait_name end))

            append!(exprs, trait_mapping_exprs(trait_name, state_name, types_expr))
        else
            throw(ArgumentError("Malformed mapping. Expected `StateName => Type` or `StateName => [Type1, Type2]`"))
        end
    end

    return esc(Expr(:toplevel, exprs...))
end

macro trait_map(trait_name, mapping)
    if !isa(trait_name, Symbol)
        throw(ArgumentError("Trait name must be a Symbol"))
    end
    if !(mapping isa Expr && mapping.head === :call && mapping.args[1] === :(=>))
        throw(ArgumentError("Expected syntax: @trait_map TraitName StateName => Type or [Type1, Type2]"))
    end

    state_name = mapping.args[2]
    types_expr = mapping.args[3]

    return esc(Expr(:toplevel, trait_mapping_exprs(trait_name, state_name, types_expr)...))
end

macro trait_dispatcher(expr)
    if !(expr isa Expr && expr.head === :(::))
        throw(ArgumentError("Expected syntax: @trait_dispatcher function_name(args...) :: TraitName"))
    end

    call_sig = expr.args[1]
    trait_name = expr.args[2]

    if !(call_sig isa Expr && call_sig.head === :call)
        throw(ArgumentError("Left side of `::` must be a function call, e.g., `func(x)`"))
    end

    func_name = call_sig.args[1]
    args = call_sig.args[2:end]

    if isempty(args)
        throw(ArgumentError("Trait dispatcher requires at least one argument to route."))
    end

    arg_symbols = Symbol[]
    for arg in args
        if arg isa Symbol
            push!(arg_symbols, arg)
        elseif arg isa Expr && arg.head === :(::)
            push!(arg_symbols, arg.args[1])
        else
            throw(ArgumentError("Complex signatures are not supported. Use simple `name` or `name::Type`."))
        end
    end

    # Keep the first argument exactly as written so the public method signature
    # matches the user's source-level contract.
    target_arg = arg_symbols[1]
    inner_func = trait_worker_name(func_name)

    return esc(Expr(:toplevel, quote
        Base.@__doc__ function $func_name end
        function $inner_func end

        function $func_name($(args...))
            # Because $trait_name is flagged :foldable and :aggressive,
            # the compiler evaluates this perfectly at compile time.
            return $inner_func($trait_name($target_arg), $(arg_symbols...))
        end
    end))
end

# 1. Block Form (Handles multi-line `begin ... end` implementations)
macro trait_function(sig, body)
    if !(sig isa Expr && sig.head === :(::))
        throw(ArgumentError("Expected signature like: function_name(args...) :: TraitState"))
    end

    call_sig = sig.args[1]
    state_name = sig.args[2]

    if !(call_sig isa Expr && call_sig.head === :call)
        throw(ArgumentError("Left side of `::` must be a function call, e.g., `func(x)`"))
    end

    func_name = call_sig.args[1]
    args = call_sig.args[2:end]
    inner_func = trait_worker_name(func_name)

    inner_sig = Expr(:call, inner_func, :(::$state_name), args...)

    return esc(Expr(:toplevel, quote
        Base.@__doc__ $inner_sig = $body
    end))
end

# 2. Single-Argument Form (Handles one-liner `=` assignments)
macro trait_function(expr)
    # Ensure it's an assignment expression
    if !(expr isa Expr && expr.head === :(=))
        throw(ArgumentError("Expected assignment form: @trait_function func(x) :: State = ..."))
    end

    # Safely unpack the signature and the body
    sig = expr.args[1]
    body = expr.args[2]

    # Validate the signature
    if !(sig isa Expr && sig.head === :(::))
        throw(ArgumentError("Expected signature like: function_name(args...) :: TraitState"))
    end

    call_sig = sig.args[1]
    state_name = sig.args[2]

    if !(call_sig isa Expr && call_sig.head === :call)
        throw(ArgumentError("Left side of `::` must be a function call, e.g., `func(x)`"))
    end

    func_name = call_sig.args[1]
    args = call_sig.args[2:end]
    inner_func = trait_worker_name(func_name)

    # Explicitly construct the AST without macro-recursion
    inner_sig = Expr(:call, inner_func, :(::$state_name), args...)

    return esc(Expr(:toplevel, quote
        Base.@__doc__ $inner_sig = $body
    end))
end

end  # module MacroTraits
