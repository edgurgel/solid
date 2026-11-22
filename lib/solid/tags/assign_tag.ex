defmodule Solid.Tags.AssignTag do
  alias Solid.{Argument, Parser, Object}

  @type t :: %__MODULE__{
          loc: Parser.Loc.t(),
          argument: Argument.t(),
          object: Object.t()
        }

  @enforce_keys [:loc, :argument, :object]
  defstruct [:loc, :argument, :object]

  @behaviour Solid.Tag

  @impl true
  def parse("assign", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, argument, tokens} <- Argument.parse(tokens),
         {:ok, tokens} <- expect_assignment(tokens),
         {:ok, object, [{:end, _}]} <- Solid.Object.parse(tokens) do
      {:ok, %__MODULE__{loc: loc, argument: argument, object: object}, context}
    else
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  defp expect_assignment([{:assignment, _} | tokens]), do: {:ok, tokens}
  defp expect_assignment(tokens), do: {:error, "Expected '='", Parser.meta_head(tokens)}

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      {:ok, new_value, context} =
        Solid.Argument.get(tag.object.argument, context, tag.object.filters, options)

      context = %{context | vars: Map.put(context.vars, to_string(tag.argument), new_value)}

      {[], context}
    end
  end

  defimpl Solid.Block do
    def blank?(_), do: true
  end
end
