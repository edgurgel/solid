defmodule Solid.Tags.CommentTag do
  @moduledoc """
  `{% comment %}` block. The body is skipped, not parsed:

  * A nested `{% comment %}` is parsed as a comment of its own, so the outer
    comment ends at the `{% endcomment %}` that balances it.
  * A nested `{% raw %}` is parsed as a raw tag, so an `endcomment` inside it
    does not count and a missing `endraw` is an error.
  * Any other tag or output markup is skipped as a whole. An unclosed `{{` or
    `{%` therefore swallows the `{% endcomment %}` that follows it.
  """

  alias Solid.{Lexer, Parser}
  alias Solid.Parser.Loc
  alias Solid.Tags.RawTag

  @enforce_keys [:loc]
  defstruct [:loc]

  @behaviour Solid.Tag

  @impl true
  def parse("comment", loc, context) do
    with {:ok, _tokens, context} <- Lexer.tokenize_tag_end(context),
         {:ok, context} <- ignore_body(context) do
      {:ok, %__MODULE__{loc: loc}, context}
    end
  end

  # Inside a liquid tag every line is a tag
  defp ignore_body(%{mode: :liquid_tag} = context), do: body_tag(context)

  defp ignore_body(context) do
    case :binary.match(context.rest, ["{%", "{{"]) do
      :nomatch ->
        not_terminated(context)

      {pos, 2} ->
        context = Parser.skip(context, pos)

        case context.rest do
          "{{" <> _ -> skip_object(context)
          "{%" <> _ -> body_tag(context)
        end
    end
  end

  defp body_tag(context) do
    loc = %Loc{line: context.line, column: context.column}

    case Lexer.tokenize_tag_start(context) do
      {:ok, "endcomment", after_name} ->
        case Lexer.tokenize_tag_end(after_name) do
          {:ok, _tokens, context} -> {:ok, context}
          {:error, _reason, _rest, _loc} -> skip_tag(after_name)
        end

      {:ok, "comment", after_name} ->
        with {:ok, _comment, context} <- parse("comment", loc, after_name) do
          ignore_body(context)
        end

      {:ok, "raw", after_name} ->
        with {:ok, _raw, context} <- RawTag.parse("raw", loc, after_name) do
          ignore_body(context)
        end

      {:ok, _other_tag, after_name} ->
        skip_tag(after_name)

      # `{% liquid ... %}` inside a comment
      {:liquid_tag, after_name} ->
        skip_tag(after_name)

      {:end_liquid_tag, context} ->
        not_terminated(context)

      {:error, _reason, _rest, _loc} ->
        skip_tag(Parser.skip(context, 2))
    end
  end

  # Skip the rest of a tag: up to `%}`, or to the end of the line inside a liquid tag
  defp skip_tag(%{mode: :liquid_tag} = context) do
    case :binary.match(context.rest, ["\n", "%}"]) do
      {pos, 1} -> ignore_body(Parser.skip(context, pos + 1))
      # The liquid tag ends before the comment does
      {_pos, 2} -> not_terminated(context)
      :nomatch -> not_terminated(context)
    end
  end

  defp skip_tag(context) do
    case :binary.match(context.rest, "%}") do
      {pos, 2} -> ignore_body(Parser.skip(context, pos + 2))
      :nomatch -> not_terminated(context)
    end
  end

  # `{{` runs to the next `}`. When a `{%` comes first, it runs to the end of
  # that tag instead, swallowing it
  defp skip_object(context) do
    rest = context.rest

    case :binary.match(rest, ["}", "{%"], scope: {2, byte_size(rest) - 2}) do
      {pos, 1} -> ignore_body(Parser.skip(context, pos + 1))
      {pos, 2} -> skip_tag(Parser.skip(context, pos + 2))
      :nomatch -> not_terminated(context)
    end
  end

  defp not_terminated(context) do
    context = Parser.skip(context, byte_size(context.rest))
    {:error, "Comment tag not terminated", %{line: context.line, column: context.column}}
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
