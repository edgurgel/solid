defmodule Solid.Filter do
  @moduledoc """
  Standard filters
  """

  @doc """
  Allows you to specify a fallback in case a value doesn’t exist.
  `default` will show its value if the left side is nil, false, or empty

  iex> Solid.Filter.default(123, 456)
  123

  iex> Solid.Filter.default(nil, 456)
  456

  iex> Solid.Filter.default(false, 456)
  456

  iex> Solid.Filter.default([], 456)
  456
  """
  @spec default(any, any) :: any
  def default(nil, value), do: value
  def default(false, value), do: value
  def default([], value), do: value
  def default(input, _), do: input

  @doc """
  Makes each character in a string uppercase.
  It has no effect on strings which are already all uppercase.

  iex> Solid.Filter.upcase("aBc")
  "ABC"

  iex> Solid.Filter.upcase(456)
  "456"

  iex> Solid.Filter.upcase(nil)
  ""
  """
  @spec upcase(any) :: String.t
  def upcase(input), do: input |> to_string |> String.upcase

  @doc """
  Makes each character in a string lowercase.
  It has no effect on strings which are already all lowercase.

  iex> Solid.Filter.downcase("aBc")
  "abc"

  iex> Solid.Filter.downcase(456)
  "456"

  iex> Solid.Filter.downcase(nil)
  ""
  """
  @spec downcase(any) :: String.t
  def downcase(input), do: input |> to_string |> String.downcase

  @doc """
  Replaces every occurrence of an argument in a string with the second argument.

  iex> Solid.Filter.replace("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put your helmet on"
  """
  def replace(input, string, replacement \\ "") do
    input |> to_string |> String.replace(string, replacement)
  end
end
