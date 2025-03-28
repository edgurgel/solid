defmodule Solid.Tags.CommentTag do
  @enforce_keys [:loc]
  defstruct [:loc]

  @behaviour Solid.Tag

  @impl true
  def parse("comment", loc, context) do
    with {:ok, _tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, context} <- ignore_body(context) do
      {:ok, %__MODULE__{loc: loc}, context}
    end
  end

  @whitespaces [" ", "\f", "\r", "\t", "\v"]

  defp ignore_body(context) do
    case context.rest do
      <<"\n", rest::binary>> ->
        if context.mode == :liquid_tag do
          case Solid.Parser.maybe_tokenize_tag("endcomment", context) do
            {:tag, _tag_name, _tokens, context} ->
              {:ok, context}

            {:not_found, context} ->
              ignore_body(%{context | rest: rest, line: context.line + 1, column: 1})
          end
        else
          ignore_body(%{context | rest: rest, line: context.line + 1, column: 1})
        end

      <<c::binary-size(1), rest::binary>> when c in @whitespaces ->
        ignore_body(%{context | rest: rest, column: context.column + 1})

      <<"{%", rest::binary>> ->
        case Solid.Parser.maybe_tokenize_tag("endcomment", context) do
          {:tag, _tag_name, _tokens, context} ->
            {:ok, context}

          {:not_found, context} ->
            ignore_body(%{context | rest: rest, column: context.column + 2})
        end

      "" ->
        {:error, "Comment tag not terminated", %{line: context.line, column: context.column}}

      "endcomment" <> _ ->
        if context.mode == :liquid_tag do
          {:tag, _, _, context} = Solid.Parser.maybe_tokenize_tag("endcomment", context)
          {:ok, context}
        else
          <<_c, rest::binary>> = context.rest
          ignore_body(%{context | rest: rest, line: context.line, column: context.column + 1})
        end

      <<_c, rest::binary>> ->
        ignore_body(%{context | rest: rest, column: context.column + 1})
    end
  end

  defimpl Solid.Renderable do
    def render(_tag, context, _options) do
      {[], context}
    end
  end

  defimpl Solid.Block do
    def blank?(_), do: true
  end
end
