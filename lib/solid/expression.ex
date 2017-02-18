defmodule Solid.Expression do
  @moduledoc """
  Expression evaluation for the following binary operators:
    == != > < >= <=
  Also combine expressions with `and`, `or`
  """

  alias Solid.Argument

  @doc """
  Evaluate a single expression
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
  iex> Solid.Expression.eval({"Beer Pack", :contains, "Pack"})
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
  """
  @spec eval({term, atom, term} | boolean) :: boolean
  def eval({nil, :contains, _v2}), do: false
  def eval({_v1, :contains, nil}), do: false
  def eval({v1, :contains, v2}) when is_list(v1), do: v2 in v1
  def eval({v1, :contains, v2}), do: String.contains?(v1, v2)
  def eval({v1, op, v2}), do: apply(Kernel, op, [v1, v2])
  def eval(boolean), do: boolean

  @doc """
  Evaluate a list of expressions combined with `or`, `and
  """
  @spec eval(list, map) :: boolean
  def eval([exp | exps], hash) when is_list(exps) do
     Enum.reduce(exps, do_eval(exp,hash), fn
       [:bool_and, exp], acc ->
         do_eval(exp, hash) and acc
       [:bool_or, exp], acc ->
         do_eval(exp, hash) or acc
     end)
  end

  defp do_eval({v1, op, v2}, hash) do
    v1 = Argument.get(v1, hash)
    v2 = Argument.get(v2, hash)
    eval({v1, op, v2})
  end
  defp do_eval(boolean, _hash), do: eval(boolean)
end
