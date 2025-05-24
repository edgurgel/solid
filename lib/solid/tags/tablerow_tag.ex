defmodule Solid.Tags.TablerowTag do
  @moduledoc """
  Generates an HTML table. Must be wrapped in opening <table> and closing </table> HTML tags.

  Input:

  <table>
  {% tablerow product in collection.products %}
  {{ product.title }}
  {% endtablerow %}
  </table>

  Output:

  <table>
    <tr class="row1">
      <td class="col1">
        Cool Shirt
      </td>
      <td class="col2">
        Alien Poster
      </td>
      <td class="col3">
        Batman Poster
      </td>
      <td class="col4">
        Bullseye Shirt
      </td>
      <td class="col5">
        Another Classic Vinyl
      </td>
      <td class="col6">
        Awesome Jeans
      </td>
    </tr>
  </table>
  """

  alias Solid.{Argument, Parser, Variable}

  defstruct [:loc, :variable, :enumerable, :body]

  @behaviour Solid.Tag

  @impl true
  def parse("tablerow", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, variable, tokens} <- Variable.parse(tokens),
         {:ok, tokens} <- consume_in(tokens),
         {:ok, enumerable, tokens} <- Argument.parse(tokens),
         {:end, [{:end, _}]} <- {:end, tokens},
         {:ok, body, _tag_name, _tokens, context} <-
           Parser.parse_until(context, ~w(endtablerow), "Expected endtablerow") do
      {:ok,
       %__MODULE__{
         loc: loc,
         enumerable: enumerable,
         variable: variable,
         body: Parser.remove_blank_text_if_blank_body(body)
       }, context}
    else
      {:end, tokens} -> {:error, "Unexpected token", Parser.meta_head(tokens)}
      error -> error
    end
  end

  defp consume_in(tokens) do
    case tokens do
      [{:identifier, _meta, "in"} | tokens] -> {:ok, tokens}
      _ -> {:error, "Expected 'in'", Parser.meta_head(tokens)}
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      with {:ok, enumerable, context} <- enumerable(tag.enumerable, context, options) do
        render_table_row(enumerable, tag, context, options)
      else
        {:error, message, context} ->
          exception = %Solid.ArgumentError{loc: tag.loc, message: message}
          context = Solid.Context.put_errors(context, exception)
          {Exception.message(exception), context}
      end
    end

    defp set_enumerable_value(acc_context, key, value) do
      iteration_vars = Map.put(acc_context.iteration_vars, key, value)
      %{acc_context | iteration_vars: iteration_vars}
    end

    defp render_table_row([], _tag, context, _options), do: {"", context}

    defp render_table_row(enumerable, tag, context, options) do
      enumerable_key = tag.variable.identifier

      rows =
        enumerable
        |> Enum.with_index(1)
        |> Enum.map(fn {item, index} ->
          context = set_enumerable_value(context, enumerable_key, item)
          {content, _context} = Solid.render(tag.body, context, options)
          ~s(<td class="col#{index}">#{content}</td>)
        end)

      row_class = "row1"
      html = ~s(<tr class="#{row_class}">\n#{Enum.join(rows, "")}</tr>\n)
      {html, context}
    end

    defp enumerable(enumerable, context, options) do
      {:ok, enumerable, context} = Argument.get(enumerable, context, [], options)
      enumerable = enumerable || []

      case enumerable do
        enumerable when is_list(enumerable) ->
          {:ok, enumerable, context}

        %Range{first: first, last: last} when first <= last ->
          {:ok, Enum.to_list(first..last), context}

        %Range{} ->
          {:ok, [], context}

        other ->
          {:ok, [other], context}
      end
    end
  end
end
