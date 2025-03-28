defmodule Solid.Tags.CounterTag do
  alias Solid.Argument

  @type t :: %__MODULE__{
          loc: Solid.Parser.Loc.t(),
          argument: Argument.t(),
          operation: :increment | :decrement
        }

  @enforce_keys [:loc, :argument, :operation]
  defstruct [:loc, :argument, :operation]

  @behaviour Solid.Tag

  @impl true
  def parse(counter, loc, context) when counter in ~w(increment decrement) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, argument, [{:end, _}]} <- Argument.parse(tokens) do
      {:ok, %__MODULE__{loc: loc, argument: argument, operation: String.to_atom(counter)},
       context}
    else
      {:ok, _var, rest} ->
        {:error, "Unexpected token after argument", Solid.Parser.meta_head(rest)}

      {:error, reason, _, loc} ->
        {:error, reason, loc}

      {:error, reason, loc} ->
        {:error, reason, loc}
    end
  end

  defimpl Solid.Renderable do
    def render(%Solid.Tags.CounterTag{operation: :increment} = tag, context, _options) do
      key = to_string(tag.argument)
      value = Solid.Context.get_counter(context, [key])

      value = value || 0

      context = %{context | counter_vars: Map.put(context.counter_vars, key, value + 1)}

      {[to_string(value)], context}
    end

    def render(%Solid.Tags.CounterTag{operation: :decrement} = tag, context, _options) do
      key = to_string(tag.argument)
      value = Solid.Context.get_counter(context, [key])

      value = (value || 0) - 1

      context = %{context | counter_vars: Map.put(context.counter_vars, key, value)}

      {[to_string(value)], context}
    end
  end
end
