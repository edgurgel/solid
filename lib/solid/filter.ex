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
  Concatenates two strings and returns the concatenated value.

  iex> Solid.Filter.append("www.example.com", "/index.html")
  "www.example.com/index.html"
  """
  @spec append(any, any) :: String.t
  def append(input, string), do: "#{input}#{string}"

  @doc """
  Makes the first character of a string capitalized.

  iex> Solid.Filter.capitalize("my great title")
  "My great title"
  iex> Solid.Filter.capitalize(1)
  "1"
  """
  @spec capitalize(any) :: String.t
  def capitalize(input), do: to_string(input) |> String.capitalize

  @doc """
  Rounds the input up to the nearest whole number. Liquid tries to convert the input to a number before the filter is applied.
  """
  @spec ceil(number | String.t) :: number
  def ceil(input) when is_binary(input) do
     {float, _} = Float.parse(input)
     ceil(float)
  end
  def ceil(input) when is_integer(input), do: input
  def ceil(input), do: Float.ceil(input) |> trunc

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
  Divides a number by the specified number.

  The result is rounded down to the nearest integer (that is, the floor) if the divisor is an integer.

  {{ 16 | divided_by: 4 }}
  iex> Solid.Filter.divided_by(16, 4)
  4
  iex> Solid.Filter.divided_by(5, 3)
  1
  iex> Solid.Filter.divided_by(20, 7)
  2
  """
  @spec divided_by(number, number) :: number
  def divided_by(input, operand) when is_integer(operand) do
    (input / operand) |> Float.floor |> trunc
  end
  def divided_by(input, operand) when is_float(operand) do
    input / operand
  end

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
  Returns the first item of an array.

  iex> Solid.Filter.first([1, 2, 3])
  1
  iex> Solid.Filter.first([])
  nil
  """
  @spec first(list) :: any
  def first(input), do: List.first(input)

  @doc """
  Rounds a number down to the nearest whole number.
  Solid tries to convert the input to a number before the filter is applied.

  iex> Solid.Filter.floor(1.2)
  1
  iex> Solid.Filter.floor(2.0)
  2
  iex> Solid.Filter.floor("3.5")
  3
  """
  @spec floor(number | String.t) :: integer
  def floor(input) when is_binary(input) do
    {float, _} = Float.parse(input)
    floor(float)
  end
  def floor(input), do: Float.floor(input) |> trunc

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
  Returns the last item of an array.

  iex> Solid.Filter.last([1, 2, 3])
  3
  iex> Solid.Filter.last([])
  nil
  """
  @spec last(list) :: any
  def last(input), do: List.last(input)

  @doc """
  Removes all whitespaces (tabs, spaces, and newlines) from the beginning of a string.
  The filter does not affect spaces between words.

  iex> Solid.Filter.lstrip("          So much room for activities!          ")
  "So much room for activities!          "
  """
  @spec lstrip(String.t) :: String.t
  def lstrip(input), do: String.trim_leading(input)

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

  @doc """
  Subtracts a number from another number.

  iex> Solid.Filter.minus(4, 2)
  2
  iex> Solid.Filter.minus(16, 4)
  12
  iex> Solid.Filter.minus(183.357, 12)
  171.357
  """
  @spec minus(number, number) :: number
  def minus(input, number), do: input - number

  @doc """
  Adds a number to another number.

  iex> Solid.Filter.plus(4, 2)
  6
  iex> Solid.Filter.plus(16, 4)
  20
  iex> Solid.Filter.plus(183.357, 12)
  195.357
  """
  @spec plus(number, number) :: number
  def plus(input, number), do: input + number

  @doc """
  Adds the specified string to the beginning of another string.

  iex> Solid.Filter.prepend("/index.html", "www.example.com")
  "www.example.com/index.html"
  """
  @spec prepend(any, any) :: String.t
  def prepend(input, string), do: "#{string}#{input}"

  @doc """
  Removes every occurrence of the specified substring from a string.

  iex> Solid.Filter.remove("I strained to see the train through the rain", "rain")
  "I sted to see the t through the "
  """
  @spec remove(String.t, String.t) :: String.t
  def remove(input, string) do
    String.replace(input, string, "")
  end
  @doc """
  Removes only the first occurrence of the specified substring from a string.

  iex> Solid.Filter.remove_first("I strained to see the train through the rain", "rain")
  "I sted to see the train through the rain"
  """
  @spec remove_first(String.t, String.t) :: String.t
  def remove_first(input, string) do
    String.replace(input, string, "", global: false)
  end
end
