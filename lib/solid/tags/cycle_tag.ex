defmodule Solid.Tags.CycleTag do
  alias Solid.Argument

  @type t :: %__MODULE__{
          loc: Solid.Parser.Loc.t(),
          values: [Argument.t()],
          name: Argument.t() | nil
        }

  @enforce_keys [:loc, :values, :name]
  defstruct [:loc, :values, :name]

  @behaviour Solid.Tag

  @impl true
  def parse("cycle", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, name, tokens} <- parse_name(tokens),
         {:ok, values, [{:end, _}]} <- parse_values(tokens) do
      {:ok, %__MODULE__{loc: loc, values: values, name: name}, context}
    else
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  defp parse_name(tokens) do
    with {:ok, argument, tokens} <- Argument.parse(tokens),
         [{:colon, _} | rest] <- tokens do
      {:ok, argument, rest}
    else
      _ -> {:ok, nil, tokens}
    end
  end

  defp parse_values(tokens, acc \\ []) do
    with {:ok, argument, tokens} <- Argument.parse(tokens) do
      case tokens do
        [{:end, _}] ->
          {:ok, Enum.reverse([argument | acc]), tokens}

        [{:comma, _} | rest] ->
          parse_values(rest, [argument | acc])

        _ ->
          {:error, "Expected end or comma", Solid.Parser.meta_head(tokens)}
      end
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      {context, result} = Solid.Context.run_cycle(context, tag.name, tag.values)

      if result do
        {:ok, value, context} = Argument.get(result, context, [], options)
        {[to_string(value)], context}
      else
        {[], context}
      end
    end
  end
end
