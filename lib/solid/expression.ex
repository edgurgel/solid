defmodule Solid.Expression do
  @moduledoc """
  Expression evaluation for the following binary operators:
    == != > < >= <=

  iex> Solid.Expression.eval(1, :==, 2)
  false
  iex> Solid.Expression.eval(1, :==, 1)
  true
  iex> Solid.Expression.eval(1, :!=, 2)
  true
  iex> Solid.Expression.eval(1, :!=, 1)
  false
  iex> Solid.Expression.eval(1, :<, 2)
  true
  iex> Solid.Expression.eval(1, :<, 1)
  false
  iex> Solid.Expression.eval(1, :>, 2)
  false
  iex> Solid.Expression.eval(2, :>, 1)
  true
  iex> Solid.Expression.eval(1, :>=, 1)
  true
  iex> Solid.Expression.eval(1, :>=, 0)
  true
  iex> Solid.Expression.eval(1, :>=, 2)
  false
  iex> Solid.Expression.eval(1, :<=, 1)
  true
  iex> Solid.Expression.eval(1, :<=, 0)
  false
  iex> Solid.Expression.eval(1, :<=, 2)
  true
  """
  @spec eval(term, atom, term) :: boolean
  def eval(v1, op, v2), do: apply(Kernel, op, [v1, v2])
end
