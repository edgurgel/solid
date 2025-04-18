defmodule Solid.StandardFilter do
  @moduledoc """
  Standard filters
  """

  alias Solid.Literal.Empty

  import Kernel, except: [abs: 1, ceil: 1, round: 1, floor: 1, apply: 2]

  @spec apply(String.t(), list(), Solid.Parser.Loc.t(), keyword()) ::
          {:ok, any()} | {:error, Exception.t(), any()} | {:error, Exception.t()}
  def apply(filter, args, loc, opts) do
    custom_module =
      opts[:custom_filters] || Application.get_env(:solid, :custom_filters, __MODULE__)

    strict_filters = Keyword.get(opts, :strict_filters, false)

    with :error <- apply_filter(custom_module, filter, args, loc),
         :error <- apply_filter(__MODULE__, filter, args, loc) do
      if strict_filters do
        {:error, %Solid.UndefinedFilterError{loc: loc, filter: filter}, List.first(args)}
      else
        {:ok, List.first(args)}
      end
    end
  end

  defp find_correct_function(module, fn_name, arity, loc) do
    module.__info__(:functions)
    |> Enum.find(&(elem(&1, 0) == fn_name))
    |> case do
      {^fn_name, expected_arity} ->
        {:error,
         %Solid.WrongFilterArityError{
           filter: fn_name,
           expected_arity: expected_arity,
           arity: arity,
           loc: loc
         }}

      _ ->
        :error
    end
  end

  defp apply_filter(mod, func, args, loc) do
    func = String.to_existing_atom(func)
    {:ok, Kernel.apply(mod, func, args)}
  rescue
    # Unknown function name atom or unknown function -> fallback
    ArgumentError ->
      :error

    e in Solid.ArgumentError ->
      # augment error with loc
      {:error, %{e | loc: loc}}

    UndefinedFunctionError ->
      find_correct_function(mod, String.to_existing_atom(func), Enum.count(args), loc)
  end

  @doc """
  Returns the absolute value of a number.

  iex> Solid.StandardFilter.abs(-17)
  17
  iex> Solid.StandardFilter.abs(17)
  17
  iex> Solid.StandardFilter.abs("-17.5")
  17.5
  """
  @spec abs(term) :: number
  def abs(input) do
    input
    |> to_number()
    |> Kernel.abs()
  end

  defp to_number(input) when is_binary(input) do
    if Regex.match?(~r/\A-?\d+\.\d+\z/, input) do
      case Float.parse(input) do
        {float, _} -> float
        _ -> 0
      end
    else
      case Integer.parse(input) do
        {integer, _} -> integer
        _ -> 0
      end
    end
  end

  defp to_number(input) when is_number(input), do: input
  defp to_number(_input), do: 0

  @doc """
  Concatenates two strings and returns the concatenated value.

  iex> Solid.StandardFilter.append("www.example.com", "/index.html")
  "www.example.com/index.html"
  """
  @spec append(any, any) :: String.t()
  def append(input, string), do: to_str(input) <> to_str(string)

  @doc """
  Limits a number to a minimum value.

  iex> Solid.StandardFilter.at_least(5, 3)
  5
  iex> Solid.StandardFilter.at_least(2, 4)
  4
  """
  @spec at_least(term, term) :: number
  def at_least(input, minimum) do
    max(to_number(input), to_number(minimum))
  end

  @doc """
  Limits a number to a maximum value.

  iex> Solid.StandardFilter.at_most(5, 3)
  3
  iex> Solid.StandardFilter.at_most(2, 4)
  2
  """
  @spec at_most(term, term) :: number
  def at_most(input, maximum) do
    min(to_number(input), to_number(maximum))
  end

  @doc """
  Makes the first character of a string capitalized.

  iex> Solid.StandardFilter.capitalize("my great title")
  "My great title"
  iex> Solid.StandardFilter.capitalize(1)
  "1"
  """
  @spec capitalize(any) :: String.t()
  def capitalize(input), do: to_str(input) |> String.capitalize()

  @doc """
  Rounds the input up to the nearest whole number. Liquid tries to convert the input to a number before the filter is applied.
  """
  @spec ceil(term) :: number
  def ceil(input) do
    input
    |> to_number()
    |> Kernel.ceil()
  end

  @doc """
  Converts a `DateTime`/`NaiveDateTime` struct into another date format.
  The input may also be a Unix timestamp or an ISO 8601 date string.

  The format for this syntax is the same as `Calendar.strftime/2`.

  To get the current time, pass the special word `"now"` (or `"today"`) to `date`.

  iex> Solid.StandardFilter.date("1970-01-01 00:00:00Z", "%s")
  "0"
  iex> Solid.StandardFilter.date("1970-01-01 00:00:01Z", "%s")
  "1"
  """
  @spec date(DateTime.t() | NaiveDateTime.t() | integer() | String.t(), String.t()) :: String.t()
  def date(date, format) when is_map(date) and is_binary(format) do
    try do
      Calendar.strftime(date, format)
    rescue
      KeyError -> ""
      ArgumentError -> ""
    end
  end

  def date(date, format) when is_integer(date) do
    case DateTime.from_unix(date) do
      {:ok, datetime} -> date(datetime, format)
      _ -> ""
    end
  end

  def date(date, format) when date in ["now", "today"] do
    date(NaiveDateTime.local_now(), format)
  end

  def date(date, format) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, datetime, _} -> date(datetime, format)
      _ -> date
    end
  end

  def date(_, _), do: ""

  @doc """
  Allows you to specify a fallback in case a value doesn’t exist.
  `default` will show its value if the left side is nil, false, or empty

  iex> Solid.StandardFilter.default(123, 456)
  123

  iex> Solid.StandardFilter.default(nil, 456)
  456

  iex> Solid.StandardFilter.default(false, 456)
  456

  iex> Solid.StandardFilter.default([], 456)
  456

  iex> Solid.StandardFilter.default("", 456)
  456
  """

  @empty_values [nil, false, [], "", %{}, %Empty{}]

  @spec default(any, any, map) :: any
  def default(input, value \\ "", opts \\ %{}) do
    allow_false = opts["allow_false"] || false

    case {input, value, allow_false} do
      {false, _, true} -> false
      {input, _, _} when input in @empty_values -> value
      _ -> input
    end
  end

  @doc """
  Divides a number by the specified number.

  The result is rounded down to the nearest integer (that is, the floor) if the divisor is an integer.

  {{ 16 | divided_by: 4 }}
  iex> Solid.StandardFilter.divided_by(16, 4)
  4
  iex> Solid.StandardFilter.divided_by(5, 3)
  1
  iex> Solid.StandardFilter.divided_by(20, 7)
  2
  """
  @spec divided_by(term, term) :: number
  def divided_by(input, operand) do
    do_divided_by(to_number(input), to_number(operand))
  end

  defp do_divided_by(input, operand) when is_integer(input) and is_integer(operand) do
    (input / operand) |> Float.floor() |> trunc
  rescue
    ArithmeticError ->
      raise %Solid.ArgumentError{message: "divided by 0"}
  end

  defp do_divided_by(input, operand) do
    input / operand
  rescue
    ArithmeticError ->
      raise %Solid.ArgumentError{message: "divided by 0"}
  end

  @doc """
  Makes each character in a string uppercase.
  It has no effect on strings which are already all uppercase.

  iex> Solid.StandardFilter.upcase("aBc")
  "ABC"

  iex> Solid.StandardFilter.upcase(456)
  "456"

  iex> Solid.StandardFilter.upcase(nil)
  ""
  """
  @spec upcase(any) :: String.t()
  def upcase(input), do: input |> to_str() |> String.upcase()

  @doc """
  Makes each character in a string lowercase.
  It has no effect on strings which are already all lowercase.

  iex> Solid.StandardFilter.downcase("aBc")
  "abc"

  iex> Solid.StandardFilter.downcase(456)
  "456"

  iex> Solid.StandardFilter.downcase(nil)
  ""
  """
  @spec downcase(any) :: String.t()
  def downcase(input), do: input |> to_str() |> String.downcase()

  @doc """
  Returns the first item of an array.

  iex> Solid.StandardFilter.first([1, 2, 3])
  1
  iex> Solid.StandardFilter.first([])
  nil
  iex> Solid.StandardFilter.first(%{"a" => "b"})
  ["a", "b"]
  """
  @spec first(term) :: any
  def first(input) when is_list(input), do: List.first(input)
  def first(start.._//_), do: start
  # Maps are not ordered making this result not consistent with Ruby's liquid ordered hash
  def first(input) when is_map(input) do
    input
    |> Enum.take(1)
    |> hd()
    |> Tuple.to_list()
  end

  def first(_), do: nil

  @doc """
  Rounds a number down to the nearest whole number.
  Solid tries to convert the input to a number before the filter is applied.

  iex> Solid.StandardFilter.floor(1.2)
  1
  iex> Solid.StandardFilter.floor(2.0)
  2
  iex> Solid.StandardFilter.floor("3.5")
  3
  """
  @spec floor(term) :: integer
  def floor(input) do
    input
    |> to_number
    |> Kernel.floor()
  end

  @doc """
  Removes all occurrences of nil from a list

  iex> Solid.StandardFilter.compact([1, nil, 2, nil, 3])
  [1, 2, 3]
  """
  @spec compact(term) :: list
  def compact(input) when is_list(input), do: Enum.reject(input, &(&1 == nil))
  def compact(input), do: compact([input])
  def compact(input, property) when is_list(input), do: Enum.reject(input, &(&1[property] == nil))

  @doc """
  Concatenates (joins together) multiple arrays.
  The resulting array contains all the items from the input arrays.

  iex> Solid.StandardFilter.concat([1, 2], [3, 4])
  [1, 2, 3, 4]

  iex> Solid.StandardFilter.concat(nil, [3, 4])
  [3, 4]
  """
  @spec concat(list, list) :: list
  def concat(input, list) when is_list(input) and is_list(list) do
    List.flatten(input) ++ list
  end

  def concat(input, list) when is_struct(input, Range) do
    input = Enum.to_list(input)
    concat(input, list)
  end

  def concat(input, list) when is_struct(list, Range) do
    list = Enum.to_list(list)
    concat(input, list)
  end

  def concat(nil, list) when is_list(list), do: concat([], list)
  def concat(input, list) when is_list(list), do: concat([input], list)

  def concat(_, _) do
    raise %Solid.ArgumentError{message: "concat filter requires an array argument"}
  end

  @doc """
  Join a list of strings returning one String glued by `glue`

  iex> Solid.StandardFilter.join(["a", "b", "c"])
  "a b c"
  iex> Solid.StandardFilter.join(["a", "b", "c"], "-")
  "a-b-c"
  iex> Solid.StandardFilter.join(["a", "b", "c"], 5)
  "a5b5c"
  iex> Solid.StandardFilter.join((0..3), "-")
  "0-1-2-3"
  iex> Solid.StandardFilter.join((3..0//-1), "-")
  "3-2-1-0"
  iex> Solid.StandardFilter.join(5, "-")
  5
  """
  @spec join(list, String.t()) :: term
  def join(input, glue \\ " ")
  def join(input, glue) when is_list(input) and is_binary(glue), do: Enum.join(input, glue)
  def join(input, glue) when is_list(input), do: join(input, to_string(glue))

  def join(input, glue) when is_struct(input, Range) do
    input
    |> Enum.to_list()
    |> join(glue)
  end

  def join(input, _glue), do: input

  @doc """
  Returns the last item of an array.

  iex> Solid.StandardFilter.last([1, 2, 3])
  3
  iex> Solid.StandardFilter.last([])
  nil
  """
  @spec last(list) :: any
  def last(input) when is_list(input), do: List.last(input)
  def last(_..finish//_), do: finish
  def last(_), do: nil

  @doc """
  Removes all whitespaces (tabs, spaces, and newlines) from the beginning of a string.
  The filter does not affect spaces between words.

  iex> Solid.StandardFilter.lstrip("          So much room for activities!          ")
  "So much room for activities!          "
  """
  @spec lstrip(term) :: term
  def lstrip(input), do: String.trim_leading(to_str(input))

  @doc """
  Split input string into an array of substrings separated by given pattern.

  iex> Solid.StandardFilter.split("a b c", " ")
  ~w(a b c)
  iex> Solid.StandardFilter.split("", " ")
  [""]
  """
  @spec split(term, term) :: list(String.t())
  def split(input, pattern), do: to_str(input) |> String.split(to_str(pattern))

  @doc """
  Map through a list of hashes accessing `property`

  iex> Solid.StandardFilter.map([%{"a" => "A"}, %{"a" => 1}], "a")
  ["A", 1]
  """
  def map(input, property) when is_list(input) do
    input
    |> List.flatten()
    |> Enum.map(& &1[property])
  end

  def map(input, property) when is_map(input) and not is_struct(input), do: input[property]
  def map(input, _property) when is_binary(input), do: ""

  def map(_input, property) do
    raise %Solid.ArgumentError{message: "cannot select the property '#{property}'"}
  end

  @doc """
  Subtracts a number from another number.

  iex> Solid.StandardFilter.minus(4, 2)
  2
  iex> Solid.StandardFilter.minus(16, 4)
  12
  iex> Solid.StandardFilter.minus(183.357, 12)
  171.357
  """
  @spec minus(term, term) :: term
  def minus(input, number) do
    to_number(input) - to_number(number)
  end

  @doc """
  Subtracts a number from another number.

  iex> Solid.StandardFilter.modulo(3, 2)
  1
  iex> Solid.StandardFilter.modulo(24, 7)
  3
  iex> Solid.StandardFilter.modulo(183.357, 12)
  3.357
  """
  @spec modulo(number, number) :: number
  def modulo(dividend, divisor)
      when is_integer(dividend) and is_integer(divisor),
      do: Integer.mod(dividend, divisor)

  # OTP 20+
  def modulo(dividend, divisor) do
    dividend
    |> :math.fmod(divisor)
    |> Float.round(decimal_places(dividend))
  end

  defp decimal_places(float) do
    string = float |> Float.to_string()
    {start, _} = :binary.match(string, ".")
    byte_size(string) - start - 1
  end

  @doc """
  Adds a number to another number.

  iex> Solid.StandardFilter.plus(4, 2)
  6
  iex> Solid.StandardFilter.plus(16, 4)
  20
  iex> Solid.StandardFilter.plus("16", 4)
  20
  iex> Solid.StandardFilter.plus(183.357, 12)
  195.357
  iex> Solid.StandardFilter.plus("183.357", 12)
  195.357
  iex> Solid.StandardFilter.plus("183.ABC357", 12)
  195
  """
  @spec plus(term, term) :: number
  def plus(input, number) do
    to_number(input) + to_number(number)
  end

  @doc """
  Adds the specified string to the beginning of another string.

  iex> Solid.StandardFilter.prepend("/index.html", "www.example.com")
  "www.example.com/index.html"
  """
  @spec prepend(any, any) :: String.t()
  def prepend(input, string), do: to_str(string) <> to_str(input)

  @doc """
  Removes every occurrence of the specified substring from a string.

  iex> Solid.StandardFilter.remove("I strained to see the train through the rain", "rain")
  "I sted to see the t through the "
  """
  @spec remove(String.t(), String.t()) :: String.t()
  def remove(input, string) do
    String.replace(to_str(input), to_str(string), "")
  end

  @doc """
  Removes only the first occurrence of the specified substring from a string.

  iex> Solid.StandardFilter.remove_first("I strained to see the train through the rain", "rain")
  "I sted to see the train through the rain"
  """
  @spec remove_first(String.t(), String.t()) :: String.t()
  def remove_first(input, string) do
    String.replace(to_str(input), to_str(string), "", global: false)
  end

  @doc """
  Removes only the last occurrence of the specified substring from a string.

  iex> Solid.StandardFilter.remove_last("I strained to see the train through the rain", "rain")
  "I strained to see the train through the "
  """
  @spec remove_last(String.t(), String.t()) :: String.t()
  def remove_last(input, string) do
    replace_last(input, string, "")
  end

  @doc """
  Replaces every occurrence of an argument in a string with the second argument.

  iex> Solid.StandardFilter.replace("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put your helmet on"
  """
  @spec replace(String.t(), String.t(), String.t()) :: String.t()
  def replace(input, string, replacement \\ "") do
    String.replace(to_str(input), to_str(string), to_str(replacement))
  end

  defp to_str(%Empty{}), do: ""
  defp to_str(input) when is_map(input), do: inspect(input)
  defp to_str(input) when is_list(input), do: inspect(input)
  defp to_str(input), do: to_string(input)

  @doc """
  Replaces only the first occurrence of the first argument in a string with the second argument.

  iex> Solid.StandardFilter.replace_first("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put my helmet on"
  """
  @spec replace_first(String.t(), String.t(), String.t()) :: String.t()
  def replace_first(input, string, replacement \\ "") do
    input |> to_string |> String.replace(string, replacement, global: false)
  end

  @doc """
  Replaces only the last occurrence of the first argument in a string with the second argument.

  iex> Solid.StandardFilter.replace_last("Take my protein pills and put my helmet on", "my", "your")
  "Take my protein pills and put your helmet on"
  """
  @spec replace_last(String.t(), String.t(), String.t()) :: String.t()
  def replace_last(input, string, replacement \\ "") do
    input = to_string(input)

    case last_index(input, string) do
      nil ->
        input

      index ->
        {prefix, suffix} = String.split_at(input, index)

        prefix <> replace_first(suffix, string, replacement)
    end
  end

  defp last_index(input, string) do
    do_last_index(input, string, 0, nil)
  end

  defp do_last_index("", _string, _index, last), do: last

  defp do_last_index(input, string, index, last) do
    new_last =
      if String.starts_with?(input, string) do
        index
      else
        last
      end

    do_last_index(String.slice(input, 1..-1//1), string, index + 1, new_last)
  end

  @doc """
  Reverses the order of the items in an array. reverse cannot reverse a string.

  iex> Solid.StandardFilter.reverse(["a", "b", "c"])
  ["c", "b", "a"]
  """
  @spec reverse(list) :: list
  def reverse(input), do: Enum.reverse(input)

  @doc """
  Rounds an input number to the nearest integer or,
  if a number is specified as an argument, to that number of decimal places.

  iex> Solid.StandardFilter.round(1.2)
  1
  iex> Solid.StandardFilter.round(2.7)
  3
  iex> Solid.StandardFilter.round(183.357, 2)
  183.36
  """
  @spec round(term) :: integer
  def round(input, precision \\ nil)

  def round(input, nil) do
    input
    |> to_number()
    |> Kernel.round()
  end

  def round(input, precision) do
    p = :math.pow(10, to_number(precision))
    Kernel.round(to_number(input) * p) / p
  end

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from the right side of a string.

  iex> Solid.StandardFilter.rstrip("          So much room for activities!          ")
  "          So much room for activities!"
  """
  @spec rstrip(String.t()) :: String.t()
  def rstrip(input), do: String.trim_trailing(input)

  @doc """
  Returns the number of characters in a string or the number of items in an array.

  iex> Solid.StandardFilter.size("Ground control to Major Tom.")
  28
  iex> Solid.StandardFilter.size(~w(ground control to Major Tom.))
  5
  """
  @spec size(String.t() | list) :: non_neg_integer
  def size(input) when is_list(input), do: Enum.count(input)
  def size(input), do: String.length(input)

  @doc """
  Returns a substring of 1 character beginning at the index specified by the argument passed in.
  An optional second argument specifies the length of the substring to be returned.

  String indices are numbered starting from 0.

  iex> Solid.StandardFilter.slice("Liquid", 0)
  "L"

  iex> Solid.StandardFilter.slice("Liquid", 2)
  "q"

  iex> Solid.StandardFilter.slice("Liquid", 2, 5)
  "quid"
  iex> Solid.StandardFilter.slice("Liquid", -3, 2)
  "ui"
  """
  @spec slice(String.t(), integer, non_neg_integer | nil) :: String.t()
  def slice(input, offset, length \\ nil)
  def slice(input, offset, nil), do: String.at(input, offset)
  def slice(input, offset, length), do: String.slice(input, offset, length)

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.StandardFilter.sort(~w(zebra octopus giraffe SallySnake))
  ~w(SallySnake giraffe octopus zebra)
  """
  @spec sort(list) :: list
  def sort(input), do: Enum.sort(input)

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.StandardFilter.sort_natural(~w(zebra octopus giraffe SallySnake))
  ~w(giraffe octopus SallySnake zebra)
  """
  @spec sort_natural(list) :: list
  def sort_natural(input) do
    Enum.sort(input, &(String.downcase(&1) <= String.downcase(&2)))
  end

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from both the left and right side of a string.
  It does not affect spaces between words.

  iex> Solid.StandardFilter.strip("          So much room for activities!          ")
  "So much room for activities!"
  """
  @spec strip(String.t()) :: String.t()
  def strip(input), do: String.trim(input)

  @doc """
  Multiplies a number by another number.

  iex> Solid.StandardFilter.times(3, 2)
  6
  iex> Solid.StandardFilter.times(24, 7)
  168
  iex> Solid.StandardFilter.times(183.357, 12)
  2200.284
  """
  @spec times(term, term) :: number
  def times(input, operand) do
    to_number(input) * to_number(operand)
  end

  @doc """
  truncate shortens a string down to the number of characters passed as a parameter.
  If the number of characters specified is less than the length of the string, an ellipsis (…) is appended to the string
  and is included in the character count.

  iex> Solid.StandardFilter.truncate("Ground control to Major Tom.", 20)
  "Ground control to..."

  # Custom ellipsis

  truncate takes an optional second parameter that specifies the sequence of characters to be appended to the truncated string.
  By default this is an ellipsis (…), but you can specify a different sequence.

  The length of the second parameter counts against the number of characters specified by the first parameter.
  For example, if you want to truncate a string to exactly 10 characters, and use a 3-character ellipsis,
  use 13 for the first parameter of truncate, since the ellipsis counts as 3 characters.

  iex> Solid.StandardFilter.truncate("Ground control to Major Tom.", 25, ", and so on")
  "Ground control, and so on"

  # No ellipsis

  You can truncate to the exact number of characters specified by the first parameter
  and show no trailing characters by passing a blank string as the second parameter:

  iex> Solid.StandardFilter.truncate("Ground control to Major Tom.", 20, "")
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

  iex> Solid.StandardFilter.truncatewords("Ground control to Major Tom.", 3)
  "Ground control to..."

  # Custom ellipsis

  `truncatewords` takes an optional second parameter that specifies the sequence of characters to be appended to the truncated string.
  By default this is an ellipsis (…), but you can specify a different sequence.

  iex> Solid.StandardFilter.truncatewords("Ground control to Major Tom.", 3, "--")
  "Ground control to--"

  # No ellipsis

  You can avoid showing trailing characters by passing a blank string as the second parameter:

  iex> Solid.StandardFilter.truncatewords("Ground control to Major Tom.", 3, "")
  "Ground control to"
  """
  @spec truncatewords(nil | String.t(), non_neg_integer, String.t()) :: String.t()
  def truncatewords(input, max_words, ellipsis \\ "...")
  def truncatewords(nil, _max_words, _ellipsis), do: ""

  def truncatewords(input, max_words, ellipsis) do
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
  iex> Solid.StandardFilter.uniq(~w(ants bugs bees bugs ants))
  ~w(ants bugs bees)
  """
  @spec uniq(list) :: list
  def uniq(input), do: Enum.uniq(input)

  @doc """
  Removes any newline characters (line breaks) from a string.

  Output
  iex> Solid.StandardFilter.strip_newlines("Test \\ntext\\r\\n with line breaks.")
  "Test text with line breaks."

  iex> Solid.StandardFilter.strip_newlines([[["Test \\ntext\\r\\n with "] | "line breaks."]])
  "Test text with line breaks."
  """
  @spec strip_newlines(iodata()) :: String.t()
  def strip_newlines(iodata) do
    binary = IO.iodata_to_binary(iodata)
    pattern = :binary.compile_pattern(["\r\n", "\n"])
    String.replace(binary, pattern, "")
  end

  @doc """
  Replaces every newline in a string with an HTML line break (<br />).

  Output
  iex> Solid.StandardFilter.newline_to_br("Test \\ntext\\r\\n with line breaks.")
  "Test <br />\\ntext<br />\\r\\n with line breaks."

  iex> Solid.StandardFilter.newline_to_br([[["Test \\ntext\\r\\n with "] | "line breaks."]])
  "Test <br />\\ntext<br />\\r\\n with line breaks."
  """
  @spec newline_to_br(iodata()) :: String.t()
  def newline_to_br(iodata) do
    binary = IO.iodata_to_binary(iodata)
    pattern = :binary.compile_pattern(["\r\n", "\n"])
    String.replace(binary, pattern, fn x -> "<br />#{x}" end)
  end

  @doc """
  Creates an array including only the objects with a given property value,
  or any truthy value by default.

  Output
  iex> input = [
  ...>   %{"id" => 1, "type" => "kitchen"},
  ...>   %{"id" => 2, "type" => "bath"},
  ...>   %{"id" => 3, "type" => "kitchen"}
  ...> ]
  iex> Solid.StandardFilter.where(input, "type", "kitchen")
  [%{"id" => 1, "type" => "kitchen"}, %{"id" => 3, "type" => "kitchen"}]

  iex> input = [
  ...>   %{"id" => 1, "available" => true},
  ...>   %{"id" => 2, "type" => false},
  ...>   %{"id" => 3, "available" => true}
  ...> ]
  iex> Solid.StandardFilter.where(input, "available")
  [%{"id" => 1, "available" => true}, %{"id" => 3, "available" => true}]
  """
  @spec where(list, String.t(), String.t()) :: list
  def where(input, key, value) do
    for %{} = map <- input, map[key] == value, do: map
  end

  @spec where(list, String.t()) :: list
  def where(input, key) do
    for %{} = map <- input, Map.has_key?(map, key), do: map
  end

  @doc """
  Removes any HTML tags from a string.

  This mimics the regex based approach of the ruby library.

  Output
  iex> Solid.StandardFilter.strip_html("Have <em>you</em> read <strong>Ulysses</strong>?")
  "Have you read Ulysses?"
  """
  @html_blocks ~r{(<script.*?</script>)|(<!--.*?-->)|(<style.*?</style>)}m
  @html_tags ~r|<.*?>|m
  @spec strip_html(iodata()) :: String.t()
  def strip_html(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> String.replace(@html_blocks, "")
    |> String.replace(@html_tags, "")
  end

  @doc """
  URL encodes the string.

  Output
  iex> Solid.StandardFilter.url_encode("john@liquid.com")
  "john%40liquid.com"

  iex> Solid.StandardFilter.url_encode("Tetsuro Takara")
  "Tetsuro+Takara"
  """
  def url_encode(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> URI.encode_www_form()
  end

  @doc """
  URL decodes the string.

  Output
  iex> Solid.StandardFilter.url_decode("%27Stop%21%27+said+Fred")
  "'Stop!' said Fred"
  """
  def url_decode(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> URI.decode_www_form()
  end

  @doc """
  HTML encodes the string.

  Output
  iex> Solid.StandardFilter.escape("Have you read 'James & the Giant Peach'?")
  "Have you read &#39;James &amp; the Giant Peach&#39;?"
  """
  @spec escape(iodata()) :: String.t()
  def escape(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> Solid.HTML.html_escape()
  end

  @doc """
  HTML encodes the string without encoding already encoded characters again.

  This mimics the regex based approach of the ruby library.

  Output
  "1 &lt; 2 &amp; 3"

  iex> Solid.StandardFilter.escape_once("1 &lt; 2 &amp; 3")
  "1 &lt; 2 &amp; 3"
  """
  @escape_once_regex ~r{["><']|&(?!([a-zA-Z]+|(#\d+));)}
  @spec escape_once(iodata()) :: String.t()
  def escape_once(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> String.replace(@escape_once_regex, &Solid.HTML.replacements/1)
  end

  @doc """
  Encodes a string to Base64 format.

  iex> Solid.StandardFilter.base64_encode("apples")
  "YXBwbGVz"
  iex> Solid.StandardFilter.base64_encode(3)
  "Mw=="
  """
  @spec base64_encode(term) :: String.t()
  def base64_encode(input) do
    input
    |> to_string()
    |> Base.encode64()
  end

  @doc """
  Decodes a string in Base64 format.

  iex> Solid.StandardFilter.base64_decode("YXBwbGVz")
  "apples"
  """
  @spec base64_decode(term) :: String.t()
  def base64_decode(nil), do: ""

  def base64_decode(input) do
    input
    |> IO.iodata_to_binary()
    |> Base.decode64!()
  rescue
    ArgumentError ->
      raise %Solid.ArgumentError{message: "invalid base64 provided to base64_decode"}
  end

  @doc """
  Encodes a string to URL-safe Base64 format.

  iex> Solid.StandardFilter.base64_url_safe_encode("apples")
  "YXBwbGVz"

  iex> Solid.StandardFilter.base64_url_safe_encode(3)
  "Mw=="
  """
  @spec base64_url_safe_encode(term) :: String.t()
  def base64_url_safe_encode(input) do
    input
    |> to_string()
    |> Base.url_encode64()
  end

  @doc """
  Decodes a string in URL-safe Base64 format.

  iex> Solid.StandardFilter.base64_url_safe_decode("YXBwbGVz")
  "apples"
  """
  @spec base64_url_safe_decode(iodata()) :: String.t()
  def base64_url_safe_decode(nil), do: ""

  def base64_url_safe_decode(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> Base.url_decode64!()
  rescue
    ArgumentError ->
      raise %Solid.ArgumentError{message: "invalid base64 provided to base64_url_safe_decode"}
  end
end
