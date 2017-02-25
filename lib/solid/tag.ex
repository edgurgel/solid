defmodule Solid.Tag do
  @moduledoc """
  Control flow tags can change the information Liquid shows using programming logic.

  More info: https://shopify.github.io/liquid/tags/control-flow/
  """

  alias Solid.{Expression, Argument}

  @doc """
  Evaluate a tag and return the condition that succeeded or nil
  """
  def eval([], _hash), do: nil
  def eval([{:if_exp, exp} | _] = tag, hash) do
    try do
      if eval_expression(exp[:expression], hash), do: throw exp
      elsif_exps = tag[:elsif_exps]
      if elsif_exps do
        result = Enum.find elsif_exps, &(eval_elsif(&1, hash))
        if result, do: throw elem(result, 1)
      end
      else_exp = tag[:else_exp]
      if else_exp, do: throw(else_exp)
    catch
      result -> result[:text]
    end
  end

  def eval([{:unless_exp, exp} | _] = tag, hash) do
    try do
      unless eval_expression(exp[:expression], hash), do: throw exp
      elsif_exps = tag[:elsif_exps]
      if elsif_exps do
        result = Enum.find elsif_exps, &(eval_elsif(&1, hash))
        if result, do: throw elem(result, 1)
      end
      else_exp = tag[:else_exp]
      if else_exp, do: throw(else_exp)
    catch
      result -> result[:text]
    end
  end

  def eval([{:case_exp, [field]} | [{:whens, when_map} | _]] = tag, hash) do
    result = when_map[Argument.get(field, hash)]
    if result do
      result[:text]
    else
      tag[:else_exp][:text]
    end
  end

  defp eval_elsif({:elsif_exp, elsif_exp}, hash) do
    eval_expression(elsif_exp[:expression], hash)
  end

  defp eval_expression(exps, hash), do: Expression.eval(exps, hash)
end
