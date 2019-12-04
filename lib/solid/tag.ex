defmodule Solid.Tag do
  @moduledoc """
  Control flow tags can change the information Liquid shows using programming logic.

  More info: https://shopify.github.io/liquid/tags/control-flow/
  """

  alias Solid.{Expression, Argument, Context}

  @doc """
  Evaluate a tag and return the condition that succeeded or nil
  """
  @spec eval(any, Context.t()) :: {iolist | nil, Context.t()}
  def eval(tag, context) do
    case do_eval(tag, context) do
      {text, context} -> {text, context}
      text -> {text, context}
    end
  end

  defp do_eval([], _context), do: nil

  defp do_eval([{:if_exp, exp} | _] = tag, context) do
    if eval_expression(exp[:expression], context), do: throw({:result, exp})
    elsif_exps = tag[:elsif_exps]

    if elsif_exps do
      result = Enum.find(elsif_exps, &eval_elsif(&1, context))
      if result, do: throw({:result, elem(result, 1)})
    end

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp})
  catch
    {:result, result} -> result[:result]
  end

  defp do_eval([{:unless_exp, exp} | _] = tag, context) do
    unless eval_expression(exp[:expression], context), do: throw({:result, exp})
    elsif_exps = tag[:elsif_exps]

    if elsif_exps do
      result = Enum.find(elsif_exps, &eval_elsif(&1, context))
      if result, do: throw({:result, elem(result, 1)})
    end

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp})
  catch
    {:result, result} -> result[:result]
  end

  defp do_eval([{:case_exp, field} | [{:whens, when_map} | _]] = tag, context) do
    result = when_map[Argument.get(field, context)]

    if result do
      result
    else
      tag[:else_exp][:result]
    end
  end

  defp do_eval([assign_exp: [{:field, [keys: [field_name], accesses: []]}, argument]], context) do
    context = %{
      context
      | vars: Map.put(context.vars, field_name, Argument.get([argument], context))
    }

    {nil, context}
  end

  defp do_eval(
         [capture_exp: [field: [keys: [field_name], accesses: []], result: result]],
         context
       ) do
    {captured, context} = Solid.render(result, context)

    context = %{
      context
      | vars: Map.put(context.vars, field_name, captured)
    }

    {nil, context}
  end

  defp do_eval([counter_exp: [{operation, default}, field]], context) do
    value = Argument.get([field], context, [:counter_vars]) || default
    {:field, [keys: [field_name], accesses: []]} = field

    context = %{
      context
      | counter_vars: Map.put(context.counter_vars, field_name, value + operation)
    }

    {[text: to_string(value)], context}
  end

  defp do_eval([break_exp: _], context) do
    throw({:break_exp, [], context})
  end

  defp do_eval(
         [
           for_exp:
             [
               {:field, [keys: [enumerable_key], accesses: []]},
               {:enumerable, enumerable},
               {:parameters, parameters} | _
             ] = exp
         ],
         context
       ) do
    enumerable =
      enumerable
      |> enumerable(context)
      |> apply_parameters(parameters)

    do_for(enumerable_key, enumerable, exp, context)
  end

  defp do_for(_, [], exp, context) do
    exp = Keyword.get(exp, :else_exp)
    {exp[:result], context}
  end

  defp do_for(enumerable_key, enumerable, exp, context) do
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
          {result, acc_context} = Solid.render(exp, acc_context)
          acc_context = restore_initial_forloop_value(acc_context, acc_context_initial)
          {[result | acc_result], acc_context}
        catch
          {:break_exp, partial_result, context} ->
            throw({:result, [partial_result | acc_result], context})
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
    first = integer_or_field(first, context)
    last = integer_or_field(last, context)
    first..last
  end

  defp enumerable(field, context), do: Argument.get(field, context) || []

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

  defp integer_or_field(value, _context) when is_integer(value), do: value
  defp integer_or_field(field, context), do: Argument.get([field], context)

  defp eval_elsif({:elsif_exp, elsif_exp}, context) do
    eval_expression(elsif_exp[:expression], context)
  end

  defp eval_expression(exps, context), do: Expression.eval(exps, context)
end
