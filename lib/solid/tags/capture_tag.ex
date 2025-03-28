defmodule Solid.Tags.CaptureTag do
  alias Solid.{Argument, Parser}

  @type t :: %__MODULE__{
          loc: Parser.Loc.t(),
          argument: Argument.t(),
          body: [Parser.entry()]
        }

  @enforce_keys [:loc, :argument, :body]
  defstruct [:loc, :argument, :body]

  @behaviour Solid.Tag

  @impl true
  def parse("capture", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, argument, [{:end, _}]} <- Argument.parse(tokens),
         {:ok, body, _tag, _tokens, context} <-
           Parser.parse_until(context, "endcapture", "Expected endcapture") do
      {:ok, %__MODULE__{loc: loc, argument: argument, body: body}, context}
    else
      {:ok, _, tokens} -> {:error, "Unexpected token", Parser.meta_head(tokens)}
      error -> error
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      {captured, context} = Solid.render(tag.body, context, options)

      context = %{
        context
        | vars: Map.put(context.vars, to_string(tag.argument), IO.iodata_to_binary(captured))
      }

      {[], context}
    end
  end

  defimpl Solid.Block do
    def blank?(_), do: true
  end
end
