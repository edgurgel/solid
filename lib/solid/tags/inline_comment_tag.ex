defmodule Solid.Tags.InlineCommentTag do
  alias Solid.ParserContext

  @enforce_keys [:loc]
  defstruct [:loc]

  @behaviour Solid.Tag

  @impl true
  def parse("#", loc, context) do
    with {:ok, context} <- ignore_body(context) do
      {:ok, %__MODULE__{loc: loc}, context}
    end
  end

  @whitespaces [" ", "\f", "\r", "\t", "\v"]

  defp ignore_body(%ParserContext{mode: :liquid_tag} = context) do
    case context.rest do
      <<"\n", rest::binary>> ->
        {:ok, %{context | rest: rest, line: context.line + 1, column: 1}}

      <<_c, rest::binary>> ->
        ignore_body(%{context | rest: rest, column: context.column + 1})
    end
  end

  defp ignore_body(%ParserContext{mode: :normal} = context) do
    case context.rest do
      <<"%}", rest::binary>> ->
        {:ok, %{context | rest: rest, column: context.column + 2}}

      <<"\n", rest::binary>> ->
        context =
          ignore_whitespace_and_new_line(%{
            context
            | rest: rest,
              line: context.line + 1,
              column: 1
          })

        case context.rest do
          <<"#", rest::binary>> ->
            ignore_body(%{context | rest: rest, column: context.column + 1})

          <<"%}", rest::binary>> ->
            {:ok, %{context | rest: rest, column: context.column + 2}}

          <<"-%}", rest::binary>> ->
            context =
              ignore_whitespace_and_new_line(%{context | rest: rest, column: context.column + 3})

            {:ok, context}

          _ ->
            {:error, "Syntax error in tag '#' - Each line of comments must be prefixed by '#'",
             %{line: context.line, column: context.column}}
        end

      <<_c, rest::binary>> ->
        ignore_body(%{context | rest: rest, column: context.column + 1})
    end
  end

  defp ignore_whitespace_and_new_line(context) do
    case context.rest do
      <<c::binary-size(1), rest::binary>> when c in @whitespaces ->
        ignore_whitespace_and_new_line(%{context | rest: rest, column: context.column + 1})

      <<"\n", rest::binary>> ->
        ignore_whitespace_and_new_line(%{context | rest: rest, line: context.line + 1, column: 1})

      _ ->
        context
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
