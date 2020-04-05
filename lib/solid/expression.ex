defmodule Solid.Expression do
  @moduledoc """
  Expression evaluation for the following binary operators:
    == != > < >= <=
  Also combine expressions with `and`, `or`
  """

  alias Solid.Argument

  @type value :: number | iolist | boolean | nil

  @doc """
  Evaluate a single expression
  iex> Solid.Expression.eval({"Beer Pack", :contains, "Pack"})
  true
  iex> Solid.Expression.eval({1, :==, 2})
  false
  iex> Solid.Expression.eval({1, :==, 1})
  true
  iex> Solid.Expression.eval({1, :!=, 2})
  true
  iex> Solid.Expression.eval({1, :!=, 1})
  false
  iex> Solid.Expression.eval({1, :<, 2})
  true
  iex> Solid.Expression.eval({1, :<, 1})
  false
  iex> Solid.Expression.eval({1, :>, 2})
  false
  iex> Solid.Expression.eval({2, :>, 1})
  true
  iex> Solid.Expression.eval({1, :>=, 1})
  true
  iex> Solid.Expression.eval({1, :>=, 0})
  true
  iex> Solid.Expression.eval({1, :>=, 2})
  false
  iex> Solid.Expression.eval({1, :<=, 1})
  true
  iex> Solid.Expression.eval({1, :<=, 0})
  false
  iex> Solid.Expression.eval({1, :<=, 2})
  true
  iex> Solid.Expression.eval({"Meat", :contains, "Pack"})
  false
  iex> Solid.Expression.eval({["Beer", "Pack"], :contains, "Pack"})
  true
  iex> Solid.Expression.eval({["Meat"], :contains, "Pack"})
  false
  iex> Solid.Expression.eval({nil, :contains, "Pack"})
  false
  iex> Solid.Expression.eval({"Meat", :contains, nil})
  false
  iex> Solid.Expression.eval(true)
  true
  iex> Solid.Expression.eval(false)
  false
  iex> Solid.Expression.eval(nil)
  false
  iex> Solid.Expression.eval(1)
  true
  iex> Solid.Expression.eval("")
  true
  iex> Solid.Expression.eval({0, :<=, nil})
  false
  iex> Solid.Expression.eval({1.0, :<, nil})
  false
  iex> Solid.Expression.eval({nil, :>=, 1.0})
  false
  iex> Solid.Expression.eval({nil, :>, 0})
  false
  """
  @spec eval({value, atom, value} | value) :: boolean
  def eval({nil, :contains, _v2}), do: false
  def eval({_v1, :contains, nil}), do: false
  def eval({v1, :contains, v2}) when is_list(v1), do: v2 in v1
  def eval({v1, :contains, v2}), do: String.contains?(v1, v2)
  def eval({v1, :<=, nil}) when is_number(v1), do: false
  def eval({v1, :<, nil}) when is_number(v1), do: false
  def eval({nil, :>=, v2}) when is_number(v2), do: false
  def eval({nil, :>, v2}) when is_number(v2), do: false
  def eval({v1, op, v2}), do: apply(Kernel, op, [v1, v2])

  def eval(value) do
    if value do
      true
    else
      false
    end
  end

  @doc """
  Evaluate a list of expressions combined with `or`, `and`
  """
  @spec eval(list, map) :: boolean
  def eval(exps, context) when is_list(exps) do
    exps
    |> Enum.chunk_every(2)
    |> Enum.reverse()
    |> Enum.reduce(nil, fn
      [exp, :bool_and], acc ->
        do_eval(exp, context) and acc

      [exp, :bool_or], acc ->
        do_eval(exp, context) or acc

      [exp], nil ->
        do_eval(exp, context)
    end)
  end

  defp do_eval([arg1: v1, op: [op], arg2: v2], context) do
    v1 = Argument.get(v1, context)
    v2 = Argument.get(v2, context)
    eval({v1, op, v2})
  end

  defp do_eval(value, context), do: eval(Argument.get([value], context))
end
