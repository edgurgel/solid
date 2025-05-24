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

  import Solid.NumberHelper, only: [to_integer: 1]

  @typep parameter :: :limit | :offset | :cols

  @type t :: %__MODULE__{
          loc: Parser.Loc.t(),
          variable: Variable.t(),
          enumerable: Argument.t(),
          parameters: %{parameter => Argument.t()},
          body: [Parser.entry()]
        }

  @enforce_keys [:loc, :variable, :enumerable, :parameters, :body]
  defstruct [:loc, :variable, :enumerable, :parameters, :body]

  @behaviour Solid.Tag

  @impl true
  def parse("tablerow", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, variable, tokens} <- Variable.parse(tokens),
         {:ok, tokens} <- consume_in(tokens),
         {:ok, enumerable, tokens} <- Argument.parse(tokens),
         {:ok, parameters, tokens} <- parse_parameters(tokens),
         {:end, [{:end, _}]} <- {:end, tokens},
         {:ok, body, _tag_name, _tokens, context} <-
           Parser.parse_until(context, ~w(endtablerow), "Expected endtablerow") do
      {:ok,
       %__MODULE__{
         loc: loc,
         enumerable: enumerable,
         variable: variable,
         parameters: parameters,
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

  defp drop_comma([{:comma, _meta} | tokens]), do: tokens
  defp drop_comma(tokens), do: tokens

  defp parse_parameters(tokens, acc \\ %{}) do
    tokens
    |> drop_comma
    |> case do
      [{:end, _}] = tokens ->
        {:ok, acc, tokens}

      [{:identifier, _, param}, {:colon, _} | tokens] when param in ~w(limit offset cols) ->
        case Argument.parse(tokens) do
          {:ok, argument, tokens} ->
            parse_parameters(tokens, Map.put(acc, String.to_existing_atom(param), argument))

          _ ->
            {:error, "Invalid parameter for #{param}", Parser.meta_head(tokens)}
        end

      _ ->
        {:error, "Expected parameters are offset, limit and cols", Parser.meta_head(tokens)}
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      with {:ok, enumerable, context} <- enumerable(tag.enumerable, context, options),
           {:ok, enumerable, length, context} <-
             apply_parameters(enumerable, tag, context, options) do
        render_table_row(enumerable, length, tag, context, options)
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

    defp render_table_row([], _length, _tag, context, _options), do: {"", context}

    defp render_table_row(enumerable, length, tag, context, options) do
      enumerable_key = tag.variable.identifier
      {:ok, cols, context} = cols(length, tag, context, options)

      try do
        {html, context} =
          enumerable
          |> Stream.chunk_every(cols)
          |> Stream.with_index(1)
          |> Enum.reduce({[], context}, fn {chunk, row}, {tr_acc, context} ->
            tr =
              if row == 1, do: ~s(<tr class="row#{row}">\n), else: ~s(<tr class="row#{row}">)

            {tds, context} =
              chunk
              |> Stream.with_index(1)
              |> Enum.reduce({[], context}, fn {item, col}, {acc, context} ->
                index = row * cols + col - cols

                context =
                  context
                  |> set_enumerable_value(enumerable_key, item)
                  |> put_tablerowloop(col, row, cols, index, length)

                try do
                  {content, context} = Solid.render(tag.body, context, options)
                  td = ~s(<td class="col#{col}">#{content}</td>)
                  {[td | acc], context}
                catch
                  {:break_exp, result, context} ->
                    td = ~s(<td class="col#{col}">#{result}</td>)

                    throw({:result, [td, Enum.reverse(acc), tr | tr_acc], context})

                  {:continue_exp, result, context} ->
                    td = ~s(<td class="col#{col}">#{result}</td>)
                    {[td | acc], context}
                end
              end)

            tds = Enum.reverse(tds)

            {["</tr>\n", tds, tr | tr_acc], context}
          end)

        context = cleanup_context(context, enumerable_key)
        {Enum.reverse(html), context}
      catch
        {:result, result, context} ->
          context = cleanup_context(context, enumerable_key)
          {Enum.reverse(["</tr>\n" | result]), context}
      end
    end

    defp cleanup_context(context, enumerable_key) do
      iteration_vars = Map.drop(context.iteration_vars, [enumerable_key, "tablerowloop"])
      %{context | iteration_vars: iteration_vars}
    end

    defp put_tablerowloop(context, col, row, cols_max, index, length) do
      tablerowloop = build_tablerowloop(col, row, cols_max, index, length)
      iteration_vars = Map.put(context.iteration_vars, "tablerowloop", tablerowloop)
      %{context | iteration_vars: iteration_vars}
    end

    defp build_tablerowloop(col, row, cols_max, index, length) do
      %{
        "col" => col,
        "col0" => col - 1,
        "col_first" => col == 1,
        "col_last" => col == cols_max,
        "first" => col == 1 and row == 1,
        "row" => row,
        "index" => index,
        "index0" => index - 1,
        "last" => index == length,
        "length" => length,
        "rindex" => length - index + 1,
        "rindex0" => length - index
      }
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

    defp apply_parameters(enumerable, tag, context, options) do
      length = Enum.count(enumerable)

      with {:ok, start, context} <- offset(tag, context, options),
           {:ok, finish, context} <- limit(tag, length, context, options) do
        enumerable = Enum.slice(enumerable, start..finish//1)
        {:ok, enumerable, length, context}
      end
    end

    defp offset(tag, context, options) do
      if argument = tag.parameters[:offset] do
        {:ok, offset, context} = Argument.get(argument, context, [], options)

        case to_integer(offset) do
          {:ok, offset} -> {:ok, offset, context}
          {:error, _message} -> {:ok, 0, context}
        end
      else
        {:ok, 0, context}
      end
    end

    defp limit(tag, length, context, options) do
      if argument = tag.parameters[:limit] do
        {:ok, limit, context} = Argument.get(argument, context, [], options)

        case to_integer(limit) do
          {:ok, limit} -> {:ok, limit - 1, context}
          {:error, message} -> {:error, message, context}
        end
      else
        {:ok, length, context}
      end
    end

    defp cols(length, tag, context, options) do
      if argument = tag.parameters[:cols] do
        {:ok, cols, context} = Argument.get(argument, context, [], options)

        case to_integer(cols) do
          {:ok, cols} -> {:ok, cols, context}
          {:error, _message} -> {:ok, length, context}
        end
      else
        {:ok, length, context}
      end
    end
  end
end
