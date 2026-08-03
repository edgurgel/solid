defmodule Solid.StandardFilter.Dispatch do
  @moduledoc false

  # Generates a `dispatch/2` function with one clause per public function of
  # `Solid.StandardFilter`, so filters are resolved by direct pattern matching
  # on the filter name and argument count instead of `String.to_existing_atom/1`
  # plus `Kernel.apply/3` guarded by try/rescue.
  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module, :def)

    dispatch_clauses =
      for {name, arity} <- definitions do
        args = Macro.generate_arguments(arity, env.module)

        quote do
          defp dispatch(unquote(to_string(name)), [unquote_splicing(args)]) do
            {:ok, unquote(name)(unquote_splicing(args))}
          end
        end
      end

    arities = Map.new(definitions, fn {name, arity} -> {to_string(name), {name, arity}} end)

    quote do
      unquote(dispatch_clauses)

      defp dispatch(filter, _args) do
        case unquote(Macro.escape(arities)) do
          %{^filter => {name, expected_arity}} ->
            {:arity_error, name, expected_arity}

          _ ->
            :error
        end
      end
    end
  end
end
