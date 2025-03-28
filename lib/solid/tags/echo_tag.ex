defmodule Solid.Tags.EchoTag do
  @enforce_keys [:loc, :object]
  defstruct [:loc, :object]

  @behaviour Solid.Tag

  @impl true
  def parse("echo", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, object, [{:end, _}]} <- Solid.Object.parse(tokens) do
      {:ok, %__MODULE__{loc: loc, object: object}, context}
    else
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      {:ok, value, context} =
        Solid.Argument.render(tag.object.argument, context, tag.object.filters, options)

      {[value], context}
    end
  end
end
