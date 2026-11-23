defmodule Solid.Tags.DocTag do
  @moduledoc """
  `{% doc %}` block. It documents a template and renders nothing:

      {% doc %}
        Renders a product card.

        @param {object} product - The product to show.
      {% enddoc %}

  The body is not parsed at all: it runs to the first `{% enddoc %}`, so
  unclosed `{{` or `{%` markup inside it is fine. Neither tag takes arguments,
  and a `{% doc %}` inside the body is an error. A `doc` block is not allowed
  inside a `{% liquid %}` tag.

  The body is kept as `text`, exactly as written (whitespace control on the
  tags doesn't trim it), so tools can read a template's documentation from its
  parse tree.
  """

  alias Solid.{Lexer, Parser}

  @enforce_keys [:loc, :text]
  defstruct [:loc, :text]

  @type t :: %__MODULE__{loc: Solid.Parser.Loc.t(), text: binary}

  @behaviour Solid.Tag

  @impl true
  def parse("doc", loc, %{mode: :liquid_tag}) do
    {:error, "The doc tag is not allowed inside a liquid tag", Map.from_struct(loc)}
  end

  def parse("doc", loc, tag_context) do
    with {:ok, tokens, context} <- Lexer.tokenize_tag_end(tag_context),
         :ok <- expect_no_arguments(tokens),
         {:ok, text, context} <- body(context, untrimmed_body_start(tag_context)) do
      {:ok, %__MODULE__{loc: loc, text: text}, context}
    else
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  defp expect_no_arguments([{:end, _}]), do: :ok
  defp expect_no_arguments(tokens), do: {:error, "Unexpected token", Parser.meta_head(tokens)}

  # The text right after `{% doc %}`, including the whitespace that `{% doc -%}`
  # trims. The tag has no arguments, so it ends at the first `%}`.
  defp untrimmed_body_start(tag_context) do
    {pos, 2} = :binary.match(tag_context.rest, "%}")
    binary_part(tag_context.rest, pos + 2, byte_size(tag_context.rest) - pos - 2)
  end

  # `start` is the text right after `{% doc %}`. The body is its prefix up to
  # the `{% enddoc %}`.
  defp body(context, start) do
    case :binary.match(context.rest, "{%") do
      :nomatch ->
        context = Parser.skip(context, byte_size(context.rest))
        {:error, "Doc tag not terminated", %{line: context.line, column: context.column}}

      {pos, 2} ->
        tag_context = Parser.skip(context, pos)

        case Parser.maybe_tokenize_tag(["doc", "enddoc"], tag_context) do
          {:tag, "enddoc", tokens, after_tag} ->
            with :ok <- expect_no_arguments(tokens) do
              body_size = byte_size(start) - byte_size(tag_context.rest)
              {:ok, binary_part(start, 0, body_size), after_tag}
            end

          {:tag, "doc", _tokens, _after_tag} ->
            {:error, "Nested doc tags are not allowed",
             %{line: tag_context.line, column: tag_context.column}}

          {:not_found, _} ->
            body(Parser.skip(tag_context, 2), start)
        end
    end
  end

  defimpl Solid.Renderable do
    def render(_tag, context, _options), do: {[], context}
  end

  # A doc with a body is not blank, so it keeps the whitespace around it in
  # an `if` or `for` body. Only an empty doc is blank.
  defimpl Solid.Block do
    def blank?(tag), do: tag.text == ""
  end
end
