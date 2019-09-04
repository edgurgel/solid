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

  defp do_eval([for_exp: exp], context) do
    {[keys: [enumerable_value], accesses: []], exp} = Keyword.pop_first(exp, :field)
    {enumerable, exp} = Keyword.pop_first(exp, :field)

    {exp, _} = Keyword.pop_first(exp, :result)
    enumerable = Argument.get([field: enumerable], context) || []

    {result, context} =
      enumerable
      |> Enum.reduce({[], context}, fn v, {acc_result, acc_context} ->
        acc_context = %{acc_context | vars: Map.put(acc_context.vars, enumerable_value, v)}
        {result, acc_context} = Solid.render(exp, acc_context)
        {[result | acc_result], acc_context}
      end)

    {[text: Enum.reverse(result)], context}
  end

  defp do_eval([{:if_exp, exp} | _] = tag, context) do
    try do
      if eval_expression(exp[:expression], context), do: throw(exp)
      elsif_exps = tag[:elsif_exps]

      if elsif_exps do
        result = Enum.find(elsif_exps, &eval_elsif(&1, context))
        if result, do: throw(elem(result, 1))
      end

      else_exp = tag[:else_exp]
      if else_exp, do: throw(else_exp)
    catch
      result -> result[:result]
    end
  end

  defp do_eval([{:unless_exp, exp} | _] = tag, context) do
    try do
      unless eval_expression(exp[:expression], context), do: throw(exp)
      elsif_exps = tag[:elsif_exps]

      if elsif_exps do
        result = Enum.find(elsif_exps, &eval_elsif(&1, context))
        if result, do: throw(elem(result, 1))
      end

      else_exp = tag[:else_exp]
      if else_exp, do: throw(else_exp)
    catch
      result -> result[:result]
    end
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
    context = %{context | vars: Map.put(context.vars, field_name, Argument.get([argument], context))}
    {nil, context}
  end

  defp do_eval([counter_exp: [{operation, default}, field]], context) do
    value = (Argument.get([field], context, [:counter_vars]) || default)
    {:field, [keys: [field_name], accesses: []]} = field
    context = %{context | counter_vars: Map.put(context.counter_vars, field_name, value + operation)}
    {[text: to_string(value)], context}
  end

  defp eval_elsif({:elsif_exp, elsif_exp}, context) do
    eval_expression(elsif_exp[:expression], context)
  end

  defp eval_expression(exps, context), do: Expression.eval(exps, context)
end
