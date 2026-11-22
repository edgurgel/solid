defmodule Solid.Tags.IfchangedTag do
  @moduledoc """
  `{% ifchanged %}` block. The body is rendered every time, but its output is
  written only when it differs from the output of the previous `ifchanged`
  block rendered in the same template. The first `ifchanged` always writes its
  output.

  All `ifchanged` blocks in a template share the same previous output:

      {% for item in list %}{% ifchanged %}{{ item }}{% endifchanged %}{% endfor %}

  With `list` being `[1, 1, 2, 2, 1]`, it renders `121`.

  A partial loaded with `render` starts with no previous output.
  """

  alias Solid.Parser

  @type t :: %__MODULE__{
          loc: Parser.Loc.t(),
          body: [Parser.entry()],
          blank: boolean
        }

  @enforce_keys [:loc, :body]
  defstruct [:loc, :body, blank: false]

  @behaviour Solid.Tag

  @impl true
  def parse("ifchanged", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:tokens, [{:end, _}]} <- {:tokens, tokens},
         {:ok, body, _tag, _tokens, context} <-
           Parser.parse_until(context, "endifchanged", "Expected 'endifchanged'") do
      {:ok, %__MODULE__{loc: loc, body: body, blank: Solid.Block.blank?(body)}, context}
    else
      {:tokens, tokens} -> {:error, "Unexpected token", Parser.meta_head(tokens)}
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  # A blank body makes this tag blank for the enclosing block, but the body
  # keeps its whitespace: `{% ifchanged %} {% endifchanged %}` writes " "
  defimpl Solid.Block do
    def blank?(tag), do: tag.blank
  end

  defimpl Solid.Renderable do
    @register :ifchanged

    def render(tag, context, options) do
      {output, context} = Solid.render(tag.body, context, options)
      write_if_changed(output, context)
    catch
      # `break` or `continue` stopped the body: compare what was rendered
      # before it, then let the enclosing loop handle the interrupt
      {exp, output, context} when exp in [:break_exp, :continue_exp] ->
        {output, context} = write_if_changed(output, context)
        throw({exp, output, context})
    end

    defp write_if_changed(output, context) do
      output = IO.iodata_to_binary(output)

      if Map.fetch(context.registers, @register) == {:ok, output} do
        {[], context}
      else
        {[output], %{context | registers: Map.put(context.registers, @register, output)}}
      end
    end
  end
end
