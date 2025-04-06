defmodule Solid.Tags.ForTag do
  alias Solid.{Argument, Parser, Variable}

  import Solid.NumberHelper, only: [to_integer: 1]

  @typep parameter :: :limit | :offset

  @type t :: %__MODULE__{
          loc: Parser.Loc.t(),
          variable: Variable.t(),
          enumerable: Argument.t(),
          reversed: boolean,
          parameters: %{parameter => Argument.t()},
          body: [Parser.entry()],
          else_body: [Parser.entry()]
        }

  @enforce_keys [:loc, :enumerable, :variable, :reversed, :parameters, :body, :else_body]
  defstruct [:loc, :enumerable, :variable, :reversed, :parameters, :body, :else_body]

  @behaviour Solid.Tag

  @impl true
  def parse("for", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, variable, tokens} <- Variable.parse(tokens),
         {:ok, tokens} <- consume_in(tokens),
         {:ok, enumerable, tokens} <- Argument.parse(tokens),
         {:ok, reversed, tokens} <- parse_reversed(tokens),
         {:ok, parameters, tokens} <- parse_parameters(tokens),
         {:end, [{:end, _}]} <- {:end, tokens},
         {:ok, body, tag_name, _tokens, context} <-
           Parser.parse_until(context, ~w(else endfor), "Expected endfor"),
         {:ok, else_body, context} <- parse_else_body(tag_name, context) do
      {:ok,
       %__MODULE__{
         loc: loc,
         enumerable: enumerable,
         variable: variable,
         reversed: reversed,
         parameters: parameters,
         body: Parser.remove_blank_text_if_blank_body(body),
         else_body: Parser.remove_blank_text_if_blank_body(else_body)
       }, context}
    else
      {:end, tokens} -> {:error, "Unexpected token", Parser.meta_head(tokens)}
      error -> error
    end
  end

  defp parse_else_body("endfor", context), do: {:ok, [], context}

  defp parse_else_body("else", context) do
    with {:ok, result, _tag_name, _tokens, context} <-
           Parser.parse_until(context, "endfor", "Expected endfor") do
      {:ok, result, context}
    end
  end

  defp consume_in(tokens) do
    case tokens do
      [{:identifier, _meta, "in"} | tokens] -> {:ok, tokens}
      _ -> {:error, "Expected 'in'", Parser.meta_head(tokens)}
    end
  end

  defp parse_reversed(tokens) do
    case tokens do
      [{:identifier, _meta, "reversed"} | tokens] -> {:ok, true, tokens}
      _ -> {:ok, false, tokens}
    end
  end

  defp parse_parameters(tokens, acc \\ %{}) do
    tokens
    |> drop_comma
    |> case do
      [{:end, _}] = tokens ->
        {:ok, acc, tokens}

      [{:identifier, _, param}, {:colon, _} | tokens] when param in ~w(limit offset) ->
        case Argument.parse(tokens) do
          {:ok, argument, tokens} ->
            parse_parameters(tokens, Map.put(acc, String.to_existing_atom(param), argument))

          _ ->
            {:error, "Invalid parameter for #{param}", Parser.meta_head(tokens)}
        end

      _ ->
        {:error, "Expected parameters are offset and limit", Parser.meta_head(tokens)}
    end
  end

  defp drop_comma([{:comma, _meta} | tokens]), do: tokens
  defp drop_comma(tokens), do: tokens

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      for_name = "#{tag.variable.identifier}-#{tag.enumerable}"

      with {:ok, enumerable, context} <- enumerable(tag.enumerable, context, options),
           {:ok, enumerable, context} <-
             apply_parameters(enumerable, tag, for_name, context, options) do
        do_for(enumerable, tag, for_name, context, options)
      else
        {:error, message, context} ->
          exception = %Solid.ArgumentError{loc: tag.loc, message: message}
          context = Solid.Context.put_errors(context, exception)
          {Exception.message(exception), context}
      end
    end

    defp do_for([], tag, _for_name, context, _options), do: {tag.else_body, context}

    defp do_for(
           enumerable,
           %Solid.Tags.ForTag{variable: variable} = tag,
           for_name,
           context,
           options
         ) do
      length = Enum.count(enumerable)
      enumerable_key = variable.identifier
      parent_forloop = context.iteration_vars["forloop"]

      try do
        {result, context} =
          enumerable
          |> Enum.with_index(0)
          |> Enum.reduce({[], context}, fn {v, index}, {acc_result, acc_context} ->
            acc_context =
              acc_context
              |> set_enumerable_value(enumerable_key, v)
              |> maybe_put_forloop_map(for_name, enumerable_key, index, length, parent_forloop)

            try do
              {result, acc_context} = Solid.render(tag.body, acc_context, options)
              {[result | acc_result], acc_context}
            catch
              {:break_exp, result, context} ->
                throw({:result, [result | acc_result], context})

              {:continue_exp, result, context} ->
                {[result | acc_result], context}
            end
          end)

        context = cleanup_context(context, enumerable_key, parent_forloop)

        {Enum.reverse(result), context}
      catch
        {:result, result, context} ->
          context = cleanup_context(context, enumerable_key, parent_forloop)

          {Enum.reverse(result), context}
      end
    end

    defp cleanup_context(context, enumerable_key, parent_forloop) do
      context = %{
        context
        | iteration_vars: Map.delete(context.iteration_vars, enumerable_key)
      }

      if enumerable_key != "forloop" and parent_forloop != nil do
        %{
          context
          | iteration_vars: Map.put(context.iteration_vars, "forloop", parent_forloop)
        }
      else
        %{context | iteration_vars: Map.delete(context.iteration_vars, "forloop")}
      end
    end

    defp set_enumerable_value(acc_context, key, value) do
      iteration_vars = Map.put(acc_context.iteration_vars, key, value)
      %{acc_context | iteration_vars: iteration_vars}
    end

    defp maybe_put_forloop_map(acc_context, for_name, key, index, length, parent_forloop)
         when key != "forloop" do
      map = build_forloop_map(index, length, parent_forloop, for_name)
      iteration_vars = Map.put(acc_context.iteration_vars, "forloop", map)
      %{acc_context | iteration_vars: iteration_vars}
    end

    defp maybe_put_forloop_map(acc_context, _for_name, _key, _index, _length, _parent_forloop) do
      acc_context
    end

    defp build_forloop_map(index, length, parentloop, forloop_name) do
      %{
        "index" => index + 1,
        "index0" => index,
        "rindex" => length - index,
        "rindex0" => length - index - 1,
        "first" => index == 0,
        "last" => length == index + 1,
        "length" => length,
        "parentloop" => parentloop,
        "name" => forloop_name
      }
    end

    defp enumerable(enumerable, context, options) do
      {:ok, enumerable, context} = Argument.get(enumerable, context, [], options)
      enumerable = enumerable || []

      case enumerable do
        enumerable
        when is_list(enumerable) or (is_map(enumerable) and not is_struct(enumerable)) ->
          {:ok, enumerable, context}

        %Range{first: first, last: last} when first <= last ->
          {:ok, Enum.to_list(first..last), context}

        %Range{} ->
          {:ok, [], context}

        other ->
          {:ok, [other], context}
      end
    end

    defp apply_parameters(enumerable, tag, for_name, context, options) do
      with {:ok, start, context} <- offset(tag, for_name, context, options),
           {:ok, finish, context} <- limit(enumerable, tag, context, options) do
        last_offset = start + finish
        context = %{context | registers: Map.put(context.registers, for_name, last_offset + 1)}
        enumerable = Enum.slice(enumerable, start..last_offset//1)
        {:ok, apply_reversed(enumerable, tag), context}
      end
    end

    defp offset(tag, for_name, context, options) do
      if argument = tag.parameters[:offset] do
        if continue?(argument) do
          {:ok, context.registers[for_name] || 0, context}
        else
          {:ok, offset, context} = Argument.get(argument, context, [], options)

          case to_integer(offset) do
            {:ok, offset} -> {:ok, offset, context}
            {:error, message} -> {:error, message, context}
          end
        end
      else
        {:ok, 0, context}
      end
    end

    defp continue?(%Variable{identifier: "continue", accesses: []}) do
      true
    end

    defp continue?(_), do: false

    defp limit(enumerable, tag, context, options) do
      if argument = tag.parameters[:limit] do
        {:ok, limit, context} = Argument.get(argument, context, [], options)

        case to_integer(limit) do
          {:ok, limit} -> {:ok, limit - 1, context}
          {:error, message} -> {:error, message, context}
        end
      else
        {:ok, Enum.count(enumerable), context}
      end
    end

    defp apply_reversed(enumerable, tag) do
      if tag.reversed do
        Enum.reverse(enumerable)
      else
        enumerable
      end
    end
  end
end
