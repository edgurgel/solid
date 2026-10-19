defmodule Solid.Tags.RawTag do
  alias Solid.ParserContext
  @enforce_keys [:loc, :text]
  defstruct [:loc, :text]

  @behaviour Solid.Tag

  @impl true
  def parse("raw", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:tokens, [{:end, _}]} <- {:tokens, tokens},
         {:ok, raw_body, context} <- parse_raw_body(context) do
      {:ok, %__MODULE__{loc: loc, text: raw_body}, context}
    else
      {:tokens, tokens} -> {:error, "Unexpected token", Solid.Parser.meta_head(tokens)}
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  @whitespace_bytes ~c" \f\r\t\v"

  defp parse_raw_body(%ParserContext{mode: :normal} = context) do
    parse_raw_body(context.rest, 0, 0, context.line, context.column, context)
  end

  defp parse_raw_body(context) do
    parse_liquid_raw_body(context.rest, 0, context.line, context.column, context)
  end

  defp parse_raw_body(text, len, keep, line, column, context) do
    case text do
      <<"\n", rest::binary>> ->
        parse_raw_body(rest, len + 1, keep, line + 1, 1, context)

      <<c, rest::binary>> when c in @whitespace_bytes ->
        parse_raw_body(rest, len + 1, keep, line, column + 1, context)

      <<"{%", rest::binary>> ->
        case end_tag(text, line, column, context) do
          # check for whitespace control: {%-
          {:ok, end_context} ->
            body_len = if match?(<<"-", _::binary>>, rest), do: keep, else: len
            {:ok, binary_part(context.rest, 0, body_len), end_context}

          :not_found ->
            parse_raw_body(rest, len + 2, len + 2, line, column + 2, context)
        end

      "" ->
        {:error, "Raw tag not terminated", %{line: line, column: column}}

      <<_c, rest::binary>> ->
        parse_raw_body(rest, len + 1, len + 1, line, column + 1, context)
    end
  end

  defp parse_liquid_raw_body(text, len, line, column, context) do
    case text do
      <<"\n", rest::binary>> ->
        case end_tag(text, line, column, context) do
          {:ok, end_context} -> {:ok, binary_part(context.rest, 0, len), end_context}
          :not_found -> parse_liquid_raw_body(rest, len + 1, line + 1, 1, context)
        end

      "" ->
        {:error, "Raw tag not terminated", %{line: line, column: column}}

      <<_c, rest::binary>> ->
        parse_liquid_raw_body(rest, len + 1, line, column + 1, context)
    end
  end

  defp end_tag(text, line, column, context) do
    context = %{context | rest: text, line: line, column: column}

    case Solid.Parser.maybe_tokenize_tag("endraw", context) do
      {:tag, _tag_name, _tokens, context} -> {:ok, context}
      {:not_found, _context} -> :not_found
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, _options) do
      {tag.text, context}
    end
  end

  defimpl Solid.Block do
    def blank?(tag), do: Solid.Text.blank_text?(tag.text)
  end
end
