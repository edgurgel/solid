defmodule Solid.Tag do
  @moduledoc """
  Control flow tags can change the information Liquid shows using programming logic.

  More info: https://shopify.github.io/liquid/tags/control-flow/
  """

  alias Solid.{Expression, Argument, Context}

  @doc """
  Evaluate a tag and return the condition that succeeded or nil
  """
  @spec eval(any, Context.t()) :: {iolist, Context.t()}
  def eval(tag, context) do
    case do_eval(tag, context) do
      {text, context} -> {text, context}
      text -> {text, context}
    end
  end

  defp do_eval([], _context), do: nil

  defp do_eval({:for_exp, exp}, context) do
    {enumerable, exp} = Keyword.pop_first(exp, :field)
    {enumerable_value, exp} = Keyword.pop_first(exp, :field)

    {exp, _} = Keyword.pop_first(exp, :text)
    enumerable = Argument.get({:field, enumerable}, context) || []

    result =
      enumerable
      |> Enum.reduce([], fn v, acc ->
        context = Map.put(context.vars, enumerable_value, v)
        [Solid.render(exp, context) | acc]
      end)
      |> Enum.reverse()

    [{:string, result}, []]
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
      result -> result[:text]
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
      result -> result[:text]
    end
  end

  defp do_eval([{:case_exp, [field]} | [{:whens, when_map} | _]] = tag, context) do
    result = when_map[Argument.get(field, context)]

    if result do
      result[:text]
    else
      tag[:else_exp][:text]
    end
  end

  defp do_eval({:assign_exp, {:field, field}, argument}, context) do
    context = %{context | vars: Map.put(context.vars, field, Argument.get(argument, context))}
    {nil, context}
  end

  defp do_eval(:comment, _context), do: nil

  defp eval_elsif({:elsif_exp, elsif_exp}, context) do
    eval_expression(elsif_exp[:expression], context)
  end

  defp eval_expression(exps, context), do: Expression.eval(exps, context)
end
