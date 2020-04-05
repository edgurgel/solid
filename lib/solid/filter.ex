defmodule Solid.Filter do
  import Kernel, except: [abs: 1, ceil: 1, round: 1, floor: 1]

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
    custom_module = Application.get_env(:solid, :custom_filters, __MODULE__)

    cond do
      filter_exists?({custom_module, filter, Enum.count(args)}) ->
        apply_filter({custom_module, filter, args})

      filter_exists?({__MODULE__, filter, Enum.count(args)}) ->
        apply_filter({__MODULE__, filter, args})

      true ->
        List.first(args)
    end
  end

  defp apply_filter({m, f, a}) do
    Kernel.apply(m, String.to_existing_atom(f), a)
  end

  defp filter_exists?({module, function, arity}) do
    try do
      function = String.to_existing_atom(function)
      function_exported?(module, function, arity)
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
  @spec abs(number | String.t()) :: number
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
  @spec append(any, any) :: String.t()
  def append(input, string), do: "#{input}#{string}"

  @doc """
  Makes the first character of a string capitalized.

  iex> Solid.Filter.capitalize("my great title")
  "My great title"
  iex> Solid.Filter.capitalize(1)
  "1"
  """
  @spec capitalize(any) :: String.t()
  def capitalize(input), do: to_string(input) |> String.capitalize()

  @doc """
  Rounds the input up to the nearest whole number. Liquid tries to convert the input to a number before the filter is applied.
  """
  @spec ceil(number | String.t()) :: number
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
    (input / operand) |> Float.floor() |> trunc
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
  @spec upcase(any) :: String.t()
  def upcase(input), do: input |> to_string |> String.upcase()

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
  @spec downcase(any) :: String.t()
  def downcase(input), do: input |> to_string |> String.downcase()

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
  @spec floor(number | String.t()) :: integer
  def floor(input) when is_binary(input) do
    {float, _} = Float.parse(input)
    floor(float)
  end

  def floor(input), do: Float.floor(input) |> trunc

  @doc """
  Removes all occurrences of nil from a list

  iex> Solid.Filter.compact([1, nil, 2, nil, 3])
  [1, 2, 3]
  """
  @spec compact(list) :: list
  def compact(input) when is_list(input), do: Enum.reject(input, &(&1 == nil))
  def compact(input, property) when is_list(input), do: Enum.reject(input, &(&1[property] == nil))

  @doc """
  Join a list of strings returning one String glued by `glue`

  iex> Solid.Filter.join(["a", "b", "c"])
  "a b c"
  iex> Solid.Filter.join(["a", "b", "c"], "-")
  "a-b-c"
  """
  @spec join(list, String.t()) :: String.t()
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
  @spec lstrip(String.t()) :: String.t()
  def lstrip(input), do: String.trim_leading(input)

  @doc """
  Split input string into an array of substrings separated by given pattern.

  iex> Solid.Filter.split("a b c", " ")
  ~w(a b c)
  iex> Solid.Filter.split("", " ")
  [""]
  """
  @spec split(any, String.t()) :: List.t()
  def split(input, pattern), do: to_string(input) |> String.split(pattern)

  @doc """
  Map through a list of hashes accessing `property`

  iex> Solid.Filter.map([%{"a" => "A"}, %{"a" => 1}], "a")
  ["A", 1]
  """
  def map(input, property) when is_list(input) do
    Enum.map(input, & &1[property])
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
  @spec prepend(any, any) :: String.t()
  def prepend(input, string), do: "#{string}#{input}"

  @doc """
  Removes every occurrence of the specified substring from a string.

  iex> Solid.Filter.remove("I strained to see the train through the rain", "rain")
  "I sted to see the t through the "
  """
  @spec remove(String.t(), String.t()) :: String.t()
  def remove(input, string) do
    String.replace(input, string, "")
  end

  @doc """
  Removes only the first occurrence of the specified substring from a string.

  iex> Solid.Filter.remove_first("I strained to see the train through the rain", "rain")
  "I sted to see the train through the rain"
  """
  @spec remove_first(String.t(), String.t()) :: String.t()
  def remove_first(input, string) do
    String.replace(input, string, "", global: false)
  end

  @doc """
  Replaces every occurrence of an argument in a string with the second argument.

  iex> Solid.Filter.replace("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put your helmet on"
  """
  @spec replace(String.t(), String.t(), String.t()) :: String.t()
  def replace(input, string, replacement \\ "") do
    input |> to_string |> String.replace(string, replacement)
  end

  @doc """
  Replaces only the first occurrence of the first argument in a string with the second argument.

  iex> Solid.Filter.replace_first("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put my helmet on"
  """
  @spec replace_first(String.t(), String.t(), String.t()) :: String.t()
  def replace_first(input, string, replacement \\ "") do
    input |> to_string |> String.replace(string, replacement, global: false)
  end

  @doc """
  Reverses the order of the items in an array. reverse cannot reverse a string.

  iex> Solid.Filter.reverse(["a", "b", "c"])
  ["c", "b", "a"]
  """
  @spec reverse(list) :: List.t()
  def reverse(input), do: Enum.reverse(input)

  @doc """
  Rounds an input number to the nearest integer or,
  if a number is specified as an argument, to that number of decimal places.

  iex> Solid.Filter.round(1.2)
  1
  iex> Solid.Filter.round(2.7)
  3
  iex> Solid.Filter.round(183.357, 2)
  183.36
  """
  @spec round(number) :: integer
  def round(input, precision \\ nil)
  def round(input, nil), do: Kernel.round(input)

  def round(input, precision) do
    p = :math.pow(10, precision)
    Kernel.round(input * p) / p
  end

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from the right side of a string.

  iex> Solid.Filter.rstrip("          So much room for activities!          ")
  "          So much room for activities!"
  """
  @spec rstrip(String.t()) :: String.t()
  def rstrip(input), do: String.trim_trailing(input)

  @doc """
  Returns the number of characters in a string or the number of items in an array.

  iex> Solid.Filter.size("Ground control to Major Tom.")
  28
  iex> Solid.Filter.size(~w(ground control to Major Tom.))
  5
  """
  @spec size(String.t() | list) :: non_neg_integer
  def size(input) when is_list(input), do: Enum.count(input)
  def size(input), do: String.length(input)

  @doc """
  Returns a substring of 1 character beginning at the index specified by the argument passed in.
  An optional second argument specifies the length of the substring to be returned.

  String indices are numbered starting from 0.

  iex> Solid.Filter.slice("Liquid", 0)
  "L"

  iex> Solid.Filter.slice("Liquid", 2)
  "q"

  iex> Solid.Filter.slice("Liquid", 2, 5)
  "quid"
  iex> Solid.Filter.slice("Liquid", -3, 2)
  "ui"
  """
  @spec slice(String.t(), integer, non_neg_integer) :: String.t()
  def slice(input, offset, length \\ nil)
  def slice(input, offset, nil), do: String.at(input, offset)
  def slice(input, offset, length), do: String.slice(input, offset, length)

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.Filter.sort(~w(zebra octopus giraffe SallySnake))
  ~w(SallySnake giraffe octopus zebra)
  """
  @spec sort(List.t()) :: List.t()
  def sort(input), do: Enum.sort(input)

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.Filter.sort_natural(~w(zebra octopus giraffe SallySnake))
  ~w(giraffe octopus SallySnake zebra)
  """
  @spec sort_natural(List.t()) :: List.t()
  def sort_natural(input) do
    Enum.sort(input, &(String.downcase(&1) <= String.downcase(&2)))
  end

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from both the left and right side of a string.
  It does not affect spaces between words.

  iex> Solid.Filter.strip("          So much room for activities!          ")
  "So much room for activities!"
  """
  @spec strip(String.t()) :: String.t()
  def strip(input), do: String.trim(input)

  @doc """
  Multiplies a number by another number.

  iex> Solid.Filter.times(3, 2)
  6
  iex> Solid.Filter.times(24, 7)
  168
  iex> Solid.Filter.times(183.357, 12)
  2200.284
  """
  @spec times(number, number) :: number
  def times(input, operand), do: input * operand

  @doc """
  truncate shortens a string down to the number of characters passed as a parameter.
  If the number of characters specified is less than the length of the string, an ellipsis (…) is appended to the string
  and is included in the character count.

  iex> Solid.Filter.truncate("Ground control to Major Tom.", 20)
  "Ground control to..."

  # Custom ellipsis

  truncate takes an optional second parameter that specifies the sequence of characters to be appended to the truncated string.
  By default this is an ellipsis (…), but you can specify a different sequence.

  The length of the second parameter counts against the number of characters specified by the first parameter.
  For example, if you want to truncate a string to exactly 10 characters, and use a 3-character ellipsis,
  use 13 for the first parameter of truncate, since the ellipsis counts as 3 characters.

  iex> Solid.Filter.truncate("Ground control to Major Tom.", 25, ", and so on")
  "Ground control, and so on"

  # No ellipsis

  You can truncate to the exact number of characters specified by the first parameter
  and show no trailing characters by passing a blank string as the second parameter:

  iex> Solid.Filter.truncate("Ground control to Major Tom.", 20, "")
  "Ground control to Ma"
  """
  @spec truncate(String.t(), non_neg_integer, String.t()) :: String.t()
  def truncate(input, length, ellipsis \\ "...") do
    if String.length(input) > length do
      length = max(0, length - String.length(ellipsis))
      slice(input, 0, length) <> ellipsis
    else
      input
    end
  end

  @doc """
  Shortens a string down to the number of words passed as the argument.
  If the specified number of words is less than the number of words in the string, an ellipsis (…) is appended to the string.

  iex> Solid.Filter.truncatewords("Ground control to Major Tom.", 3)
  "Ground control to..."

  # Custom ellipsis

  `truncatewords` takes an optional second parameter that specifies the sequence of characters to be appended to the truncated string.
  By default this is an ellipsis (…), but you can specify a different sequence.

  iex> Solid.Filter.truncatewords("Ground control to Major Tom.", 3, "--")
  "Ground control to--"

  # No ellipsis

  You can avoid showing trailing characters by passing a blank string as the second parameter:

  iex> Solid.Filter.truncatewords("Ground control to Major Tom.", 3, "")
  "Ground control to"
  """
  @spec truncatewords(String.t(), non_neg_integer, String.t()) :: String.t()
  def truncatewords(input, max_words, ellipsis \\ "...") do
    words = String.split(input, " ")

    if length(words) > max_words do
      Enum.take(words, max_words)
      |> Enum.intersperse(" ")
      |> to_string
      |> Kernel.<>(ellipsis)
    end
  end

  @doc """
  Removes any duplicate elements in an array.

  Output
  iex> Solid.Filter.uniq(~w(ants bugs bees bugs ants))
  ~w(ants bugs bees)
  """
  @spec uniq(list) :: list
  def uniq(input), do: Enum.uniq(input)
end
