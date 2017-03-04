defmodule Solid.Filter do
  import Kernel, except: [abs: 1]
  @moduledoc """
  Standard filters
  """

  @doc """
  Apply `filter` if it exists. Otherwise return the first input.

  iex> Solid.Filter.apply("upcase", ["ac"])
  "AC"
  iex> Solid.Filter.apply("no_filter_here", [1, 2, 3])
  1
  """
  def apply(filter, args) do
    if filter_exists?(filter, Enum.count(args)) do
      Kernel.apply(__MODULE__, String.to_existing_atom(filter), args)
    else
      List.first(args)
    end
  end

  defp filter_exists?(filter, arity) do
    try do
      filter = String.to_existing_atom(filter)
      function_exported?(__MODULE__, filter, arity)
    rescue
      ArgumentError -> false
    end
  end

  @doc """
  Returns the absolute value of a number.

  iex> Solid.Filter.abs(-17)
  17
  iex> Solid.Filter.abs(17)
  17
  iex> Solid.Filter.abs("-17.5")
  17.5
  """
  @spec abs(number | String.t) :: number
  def abs(input) when is_binary(input) do
     {float, _} = Float.parse(input)
     abs(float)
  end
  def abs(input), do: Kernel.abs(input)

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
  @spec replace(String.t, String.t, String.t) :: String.t
  def replace(input, string, replacement \\ "") do
    input |> to_string |> String.replace(string, replacement)
  end

  @doc """
  Removes all occurrences of nil from a list

  iex> Solid.Filter.compact([1, nil, 2, nil, 3])
  [1, 2, 3]
  """
  @spec compact(list) :: list
  def compact(input) when is_list(input), do: Enum.reject(input, &(&1 == nil))
  def compact(input, property) when is_list(input), do: Enum.reject(input, &(&1[property] == nil))

  @doc """
  Join a list of strings returning one String glued by `glue

  iex> Solid.Filter.join(["a", "b", "c"])
  "a b c"
  iex> Solid.Filter.join(["a", "b", "c"], "-")
  "a-b-c"
  """
  @spec join(list, String.t) :: String.t
  def join(input, glue \\ " ") when is_list(input), do: Enum.join(input, glue)

  @doc """
  Split input string into an array of substrings separated by given pattern.

  iex> Solid.Filter.split("a b c", " ")
  ~w(a b c)
  iex> Solid.Filter.split("", " ")
  [""]
  """
  @spec split(any, String.t) :: List.t
  def split(input, pattern), do: to_string(input) |> String.split(pattern)

  @doc """
  Map through a list of hashes accessing `property`

  iex> Solid.Filter.map([%{"a" => "A"}, %{"a" => 1}], "a")
  ["A", 1]
  """
  def map(input, property) when is_list(input) do
    Enum.map(input, &(&1[property]))
  end
end
