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

  # Inside a liquid tag each line is a tag, so `endcomment` can only end the
  # comment at the start of a line: here for the first one, then after each newline
  defp ignore_body(%{mode: :liquid_tag} = context) do
    case end_tag(context.rest, context.line, context.column, context) do
      {:ok, context} -> {:ok, context}
      :not_found -> ignore_body(context.rest, context.line, context.column, :liquid_tag, context)
    end
  end

  defp ignore_body(context) do
    ignore_body(context.rest, context.line, context.column, :normal, context)
  end

  defp ignore_body(text, line, column, mode, context) do
    case text do
      <<"\n", rest::binary>> when mode == :liquid_tag ->
        case end_tag(text, line, column, context) do
          {:ok, context} -> {:ok, context}
          :not_found -> ignore_body(rest, line + 1, 1, mode, context)
        end

      <<"\n", rest::binary>> ->
        ignore_body(rest, line + 1, 1, mode, context)

      <<"{%", rest::binary>> ->
        case end_tag(text, line, column, context) do
          {:ok, context} -> {:ok, context}
          :not_found -> ignore_body(rest, line, column + 2, mode, context)
        end

      "" ->
        {:error, "Comment tag not terminated", %{line: line, column: column}}

      <<_c, rest::binary>> ->
        ignore_body(rest, line, column + 1, mode, context)
    end
  end

  defp end_tag(text, line, column, context) do
    context = %{context | rest: text, line: line, column: column}

    case Solid.Parser.maybe_tokenize_tag("endcomment", context) do
      {:tag, _tag_name, _tokens, context} -> {:ok, context}
      {:not_found, _context} -> :not_found
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
