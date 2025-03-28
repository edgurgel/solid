defmodule Solid.Tags.RawTag do
  alias Solid.ParserContext
  @enforce_keys [:loc, :text]
  defstruct [:loc, :text]

  @behaviour Solid.Tag

  @impl true
  def parse("raw", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:tokens, [{:end, _}]} <- {:tokens, tokens},
         {:ok, raw_body, context} <- parse_raw_body(context, [], []) do
      {:ok, %__MODULE__{loc: loc, text: IO.iodata_to_binary(raw_body)}, context}
    else
      {:tokens, tokens} -> {:error, "Unexpected token", Solid.Parser.meta_head(tokens)}
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  @whitespaces [" ", "\f", "\r", "\t", "\v"]

  defp parse_raw_body(%ParserContext{mode: :normal} = context, buffer, trailing_ws) do
    case context.rest do
      <<"\n", rest::binary>> ->
        trailing_ws = ["\n" | trailing_ws]

        parse_raw_body(
          %{context | rest: rest, line: context.line + 1, column: 1},
          buffer,
          trailing_ws
        )

      <<c::binary-size(1), rest::binary>> when c in @whitespaces ->
        trailing_ws = [c | trailing_ws]
        parse_raw_body(%{context | rest: rest, column: context.column + 1}, buffer, trailing_ws)

      <<"{%", rest::binary>> ->
        case Solid.Parser.maybe_tokenize_tag("endraw", context) do
          {:tag, _tag_name, _tokens, context} ->
            # check for whitespace control: {%-
            if String.starts_with?(rest, "-") do
              {:ok, Enum.reverse(buffer), context}
            else
              {:ok, Enum.reverse(trailing_ws ++ buffer), context}
            end

          {:not_found, context} ->
            parse_raw_body(
              %{context | rest: rest, column: context.column + 2},
              ["{%" | trailing_ws ++ buffer],
              []
            )
        end

      "" ->
        {:error, "Raw tag not terminated", %{line: context.line, column: context.column}}

      <<c, rest::binary>> ->
        buffer = [c | trailing_ws ++ buffer]
        parse_raw_body(%{context | rest: rest, column: context.column + 1}, buffer, [])
    end
  end

  defp parse_raw_body(context, buffer, trailing_ws) do
    case context.rest do
      <<"\n", rest::binary>> ->
        case Solid.Parser.maybe_tokenize_tag("endraw", context) do
          {:tag, _tag_name, _tokens, context} ->
            {:ok, Enum.reverse(trailing_ws ++ buffer), context}

          {:not_found, context} ->
            trailing_ws = ["\n" | trailing_ws]

            parse_raw_body(
              %{context | rest: rest, line: context.line + 1, column: 1},
              buffer,
              trailing_ws
            )
        end

      <<c::binary-size(1), rest::binary>> when c in @whitespaces ->
        trailing_ws = [c | trailing_ws]
        parse_raw_body(%{context | rest: rest, column: context.column + 1}, buffer, trailing_ws)

      "" ->
        {:error, "Raw tag not terminated", %{line: context.line, column: context.column}}

      <<c, rest::binary>> ->
        buffer = [c | trailing_ws ++ buffer]
        parse_raw_body(%{context | rest: rest, column: context.column + 1}, buffer, [])
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, _options) do
      {tag.text, context}
    end
  end

  defimpl Solid.Block do
    def blank?(tag) do
      String.trim(tag.text) == ""
    end
  end
end
