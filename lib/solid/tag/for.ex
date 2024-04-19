defmodule Solid.Tag.For do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Literal, Variable, Argument}

  @behaviour Solid.Tag

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    range =
      ignore(string("("))
      |> unwrap_and_tag(choice([integer(min: 1), Variable.field()]), :first)
      |> ignore(string(".."))
      |> unwrap_and_tag(choice([integer(min: 1), Variable.field()]), :last)
      |> ignore(string(")"))
      |> tag(:range)

    limit =
      ignore(string("limit"))
      |> ignore(space)
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(integer(min: 1), :limit)
      |> ignore(space)

    offset =
      ignore(string("offset"))
      |> ignore(space)
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(integer(min: 1), :offset)
      |> ignore(space)

    reversed =
      string("reversed")
      |> replace({:reversed, 0})
      |> ignore(space)

    for_parameters =
      repeat(choice([limit, offset, reversed]))
      |> reduce({Enum, :into, [%{}]})

    ignore(BaseTag.opening_tag())
    |> ignore(string("for"))
    |> ignore(space)
    |> concat(Argument.argument())
    |> ignore(space)
    |> ignore(string("in"))
    |> ignore(space)
    |> tag(choice([Variable.field(), range]), :enumerable)
    |> ignore(space)
    |> unwrap_and_tag(for_parameters, :parameters)
    |> ignore(BaseTag.closing_tag())
    |> tag(parsec({parser, :liquid_entry}), :result)
    |> optional(tag(BaseTag.else_tag(parser), :else_exp))
    |> ignore(BaseTag.opening_tag())
    |> ignore(string("endfor"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(
        [{:field, [enumerable_key]}, {:enumerable, enumerable}, {:parameters, parameters} | _] =
          exp,
        context,
        options
      ) do
    {:ok, enumerable, context} = enumerable(enumerable, context)

    enumerable = apply_parameters(enumerable, parameters)

    do_for(enumerable_key, enumerable, exp, context, options)
  end

  defp do_for(_, [], exp, context, _options) do
    exp = Keyword.get(exp, :else_exp)
    {exp[:result], context}
  end

  defp do_for(enumerable_key, enumerable, exp, context, options) do
    exp = Keyword.get(exp, :result)
    length = Enum.count(enumerable)

    {result, context} =
      enumerable
      |> Enum.with_index(0)
      |> Enum.reduce({[], context}, fn {v, index}, {acc_result, acc_context_initial} ->
        acc_context =
          acc_context_initial
          |> set_enumerable_value(enumerable_key, v)
          |> maybe_put_forloop_map(enumerable_key, index, length)

        try do
          {result, acc_context} = Solid.render(exp, acc_context, options)
          acc_context = restore_initial_forloop_value(acc_context, acc_context_initial)
          {[result | acc_result], acc_context}
        catch
          {:break_exp, result, context} ->
            throw({:result, [result | acc_result], context})

          {:continue_exp, result, context} ->
            {[result | acc_result], context}
        end
      end)

    context = %{context | iteration_vars: Map.delete(context.iteration_vars, enumerable_key)}
    {[text: Enum.reverse(result)], context}
  catch
    {:result, result, context} ->
      context = %{context | iteration_vars: Map.delete(context.iteration_vars, enumerable_key)}
      {[text: Enum.reverse(result)], context}
  end

  defp set_enumerable_value(acc_context, key, value) do
    iteration_vars = Map.put(acc_context.iteration_vars, key, value)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp maybe_put_forloop_map(acc_context, key, index, length) when key != "forloop" do
    map = build_forloop_map(index, length)
    iteration_vars = Map.put(acc_context.iteration_vars, "forloop", map)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp maybe_put_forloop_map(acc_context, _key, _index, _length) do
    acc_context
  end

  defp build_forloop_map(index, length) do
    %{
      "index" => index + 1,
      "index0" => index,
      "rindex" => length - index,
      "rindex0" => length - index - 1,
      "first" => index == 0,
      "last" => length == index + 1,
      "length" => length
    }
  end

  defp restore_initial_forloop_value(acc_context, %{
         iteration_vars: %{"forloop" => initial_forloop}
       }) do
    iteration_vars = Map.put(acc_context.iteration_vars, "forloop", initial_forloop)
    %{acc_context | iteration_vars: iteration_vars}
  end

  defp restore_initial_forloop_value(acc_context, _) do
    acc_context
  end

  defp enumerable([range: [first: first, last: last]], context) do
    {:ok, first, context} = integer_or_field(first, context)
    {:ok, last, context} = integer_or_field(last, context)
    {:ok, first..last, context}
  end

  defp enumerable(field, context) do
    {:ok, value, context} = Solid.Argument.get(field, context)
    {:ok, value || [], context}
  end

  defp apply_parameters(enumerable, parameters) do
    enumerable
    |> offset(parameters)
    |> limit(parameters)
    |> reversed(parameters)
  end

  defp offset(enumerable, %{offset: offset}) do
    Enum.slice(enumerable, offset..-1)
  end

  defp offset(enumerable, _), do: enumerable

  defp limit(enumerable, %{limit: limit}) do
    Enum.slice(enumerable, 0..(limit - 1))
  end

  defp limit(enumerable, _), do: enumerable

  defp reversed(enumerable, %{reversed: _}) do
    Enum.reverse(enumerable)
  end

  defp reversed(enumerable, _), do: enumerable

  defp integer_or_field(value, context) when is_integer(value), do: {:ok, value, context}
  defp integer_or_field(field, context), do: Solid.Argument.get([field], context)
end
