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
  "17"
  iex> Solid.StandardFilter.abs(17)
  "17"
  iex> Solid.StandardFilter.abs("-17.5")
  "17.5"
  """
  @spec abs(term) :: String.t()
  def abs(input) do
    input
    |> to_decimal()
    |> Decimal.abs()
    |> then(fn result ->
      if original_float?(input) do
        decimal_to_float(result)
      else
        try_decimal_to_integer(result)
      end
    end)
  end

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
  "5"
  iex> Solid.StandardFilter.at_least(2, 4)
  "4"
  """
  @spec at_least(term, term) :: String.t()
  def at_least(input, minimum) do
    Decimal.max(to_decimal(input), to_decimal(minimum))
    |> to_string()
  end

  @doc """
  Limits a number to a maximum value.

  iex> Solid.StandardFilter.at_most(5, 3)
  "3"
  iex> Solid.StandardFilter.at_most(2, 4)
  "2"
  """
  @spec at_most(term, term) :: String.t()
  def at_most(input, maximum) do
    Decimal.min(to_decimal(input), to_decimal(maximum))
    |> to_string()
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
  @spec ceil(term) :: String.t()
  def ceil(input) do
    input
    |> to_decimal()
    |> Decimal.round(0, :ceiling)
    |> to_string()
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
  @spec date(term, term) :: String.t()
  def date(date, format) when format in [nil, ""] or is_struct(format, Empty), do: date

  def date(date, format) when is_map(date) and is_binary(format) do
    try do
      Calendar.strftime(date, format)
    rescue
      _ -> ""
    end
  end

  def date(date, format) when is_integer(date) do
    case DateTime.from_unix(date, :second) do
      {:ok, datetime} -> date(datetime, format)
      _ -> ""
    end
  end

  def date(date, format) when date in ["now", "today"] do
    date(NaiveDateTime.utc_now(), format)
  end

  def date(date, format) when is_binary(date) do
    # Try out best to parse whatever comes
    parsers = [
      # Use our own epoch date parser so that negative unix is not allowed
      # Because that's how the ruby gem works
      Solid.EpochDateTimeParser,
      DateTimeParser.Parser.Serial,
      DateTimeParser.Parser.Tokenizer
    ]

    case DateTimeParser.parse_datetime(date, assume_time: true, parsers: parsers) do
      {:ok, datetime} ->
        date(datetime, format)

      _ ->
        date
    end
  end

  def date(date, _), do: date

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
  "4"
  iex> Solid.StandardFilter.divided_by(5, 3)
  "1"
  iex> Solid.StandardFilter.divided_by(20, 7)
  "2"
  """
  @spec divided_by(term, term) :: String.t()
  def divided_by(input, operand) do
    input_number = to_decimal(input)
    operand_number = to_decimal(operand)

    if original_float?(input) or original_float?(operand) do
      Decimal.div(input_number, operand_number)
      |> decimal_to_float()
    else
      Decimal.div_int(input_number, operand_number)
      |> try_decimal_to_integer()
    end
  rescue
    Decimal.Error ->
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
  "1"
  iex> Solid.StandardFilter.floor(2.0)
  "2"
  iex> Solid.StandardFilter.floor("3.5")
  "3"
  """
  @spec floor(term) :: String.t()
  def floor(input) do
    input
    |> to_decimal
    |> Decimal.round(0, :floor)
    |> to_string()
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
  "5"
  """
  @spec join(term, term) :: term
  def join(input, glue \\ " ") do
    input
    |> to_enum()
    |> Enum.map(&to_str/1)
    |> Enum.join(to_str(glue))
  end

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
  []
  """
  @spec split(term, term) :: list(String.t())
  def split(input, pattern), do: to_str(input) |> String.split(to_str(pattern), trim: true)

  @doc """
  Map through a list of hashes accessing `property`

  iex> Solid.StandardFilter.map([%{"a" => "A"}, %{"a" => 1}], "a")
  ["A", 1]
  """
  def map(input, property) when is_list(input) do
    input
    |> List.flatten()
    |> Enum.map(fn item ->
      cond do
        is_map(item) and not is_struct(item) ->
          item[property]

        is_integer(item) ->
          raise %Solid.ArgumentError{message: "cannot select the property '#{property}'"}

        true ->
          nil
      end
    end)
  end

  def map(input, property) when is_map(input) and not is_struct(input), do: input[property]
  def map(input, _property) when is_binary(input), do: ""

  def map(_input, property) do
    raise %Solid.ArgumentError{message: "cannot select the property '#{property}'"}
  end

  @doc """
  Subtracts a number from another number.

  iex> Solid.StandardFilter.minus(4, 2)
  "2"
  iex> Solid.StandardFilter.minus(16, 4)
  "12"
  iex> Solid.StandardFilter.minus(183.357, 12)
  "171.357"
  """
  @spec minus(term, term) :: String.t()
  def minus(input, number) do
    input
    |> to_decimal()
    |> Decimal.sub(to_decimal(number))
    |> then(fn result ->
      if original_float?(input) or original_float?(number) do
        decimal_to_float(result)
      else
        try_decimal_to_integer(result)
      end
    end)
  end

  @doc """
  Subtracts a number from another number.

  iex> Solid.StandardFilter.modulo(3, 2)
  "1"
  iex> Solid.StandardFilter.modulo(24, 7)
  "3"
  iex> Solid.StandardFilter.modulo(183.357, 12)
  "3.357"
  """
  @spec modulo(term, term) :: String.t()
  def modulo(dividend, divisor) do
    dividend_decimal = to_decimal(dividend)
    divisor_decimal = to_decimal(divisor)

    if Decimal.equal?(Decimal.new(0), divisor_decimal) do
      raise %Solid.ArgumentError{message: "divided by 0"}
    end

    result = Decimal.rem(dividend_decimal, divisor_decimal)

    if original_float?(dividend) or original_float?(divisor) do
      decimal_to_float(result)
    else
      try_decimal_to_integer(result)
    end
  end

  @doc """
  Adds a number to another number.

  iex> Solid.StandardFilter.plus(4, 2)
  "6"
  iex> Solid.StandardFilter.plus(16, 4)
  "20"
  iex> Solid.StandardFilter.plus("16", 4)
  "20"
  iex> Solid.StandardFilter.plus(183.357, 12)
  "195.357"
  iex> Solid.StandardFilter.plus("183.357", 12)
  "195.357"
  iex> Solid.StandardFilter.plus("183.ABC357", 12)
  "195"
  """
  @spec plus(term, term) :: String.t()
  def plus(input, number) do
    input
    |> to_decimal()
    |> Decimal.add(to_decimal(number))
    |> then(fn result ->
      if original_float?(input) or original_float?(number) do
        decimal_to_float(result)
      else
        try_decimal_to_integer(result)
      end
    end)
  end

  @doc """
  Returns sum of all elements in an enumerable
  Allowing for an optional property to be passed in

  iex> Solid.StandardFilter.sum([])
  "0"
  iex> Solid.StandardFilter.sum([1, 2, 3])
  "6"
  iex> Solid.StandardFilter.sum(1..3)
  "6"
  iex> Solid.StandardFilter.sum([%{"a" => 1}, %{"a" => 10}])
  "0"
  iex> Solid.StandardFilter.sum([%{"a" => 1}, %{"a" => 10}], "a")
  "11"
  """
  @spec sum(term, term) :: String.t()
  def sum(input, property \\ nil) do
    property = if property, do: to_str(property), else: nil

    input
    |> to_enum
    |> Stream.map(fn value ->
      cond do
        property == nil ->
          to_decimal(value)

        true ->
          cond do
            is_struct(value, Empty) or is_binary(value) or is_boolean(value) or is_nil(value) ->
              0

            is_map(value) ->
              to_decimal(value[property] || 0)

            true ->
              raise %Solid.ArgumentError{message: "cannot select the property '#{property}'"}
          end
      end
    end)
    |> Enum.reduce(Decimal.new(0), fn value, acc ->
      Decimal.add(acc, value)
    end)
    |> to_string()
  end

  defp to_enum(input) do
    cond do
      is_list(input) -> List.flatten(input)
      is_struct(input, Range) -> Enum.to_list(input)
      is_tuple(input) -> Tuple.to_list(input)
      true -> [input]
    end
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
  @spec replace(term, term, term) :: String.t()
  def replace(input, string, replacement \\ "") do
    String.replace(to_str(input), to_str(string), to_str(replacement))
  end

  defp to_str(%Empty{}), do: ""

  # defp to_str(%datetime_module{} = datetime)
  #      when datetime_module in [DateTime, NaiveDateTime, Date, Time] do
  #   to_string(datetime)
  # end

  defp to_str(input) when is_map(input), do: inspect(input)
  defp to_str(input) when is_list(input), do: inspect(input)

  defp to_str(input) when is_float(input) do
    input
    |> Decimal.from_float()
    |> Decimal.to_string(:xsd)
  end

  defp to_str(input), do: to_string(input)

  @doc """
  Replaces only the first occurrence of the first argument in a string with the second argument.

  iex> Solid.StandardFilter.replace_first("Take my protein pills and put my helmet on", "my", "your")
  "Take your protein pills and put my helmet on"
  """
  @spec replace_first(String.t(), String.t(), String.t()) :: String.t()
  def replace_first(input, string, replacement \\ "") do
    input |> to_str() |> String.replace(to_str(string), to_str(replacement), global: false)
  end

  @doc """
  Replaces only the last occurrence of the first argument in a string with the second argument.

  iex> Solid.StandardFilter.replace_last("Take my protein pills and put my helmet on", "my", "your")
  "Take my protein pills and put your helmet on"
  iex> Solid.StandardFilter.replace_last("hello", "l", "p")
  "helpo"
  iex> Solid.StandardFilter.replace_last("hello", "ll", "")
  "heo"
  iex> Solid.StandardFilter.replace_last("abab", "b", "c")
  "abac"
  iex> Solid.StandardFilter.replace_last("abab", "a", "c")
  "abcb"
  iex> Solid.StandardFilter.replace_last("aaaaa", "a", "b")
  "aaaab"
  iex> Solid.StandardFilter.replace_last("aaaaa", "aa", "b")
  "aaab"
  iex> Solid.StandardFilter.replace_last("foo", "bar", "baz")
  "foo"
  iex> Solid.StandardFilter.replace_last("foo", "f", "b")
  "boo"
  iex> Solid.StandardFilter.replace_last("Take my protein", nil, "#")
  "Take my protein#"
  """
  @spec replace_last(String.t(), String.t(), String.t()) :: String.t()
  def replace_last(input, string, replacement) do
    input = to_str(input)
    string_arg = to_str(string)
    replacement = to_str(replacement)

    case last_index(input, string_arg) do
      nil ->
        if string_arg == "" do
          input <> replacement
        else
          input
        end

      index ->
        prefix = :binary.part(input, 0, index)

        suffix =
          :binary.part(
            input,
            index + byte_size(string_arg),
            byte_size(input) - (index + byte_size(string_arg))
          )

        prefix <> replacement <> suffix
    end
  end

  defp last_index(input, string) do
    input_len = byte_size(input)
    string_len = byte_size(string)

    if string_len == 0 do
      nil
    else
      0..(input_len - string_len)
      |> Enum.reverse()
      |> Enum.find(fn i ->
        :binary.part(input, i, string_len) == string
      end)
    end
  end

  @doc """
  Reverses the order of the items in an array. reverse cannot reverse a string.

  iex> Solid.StandardFilter.reverse(["a", "b", "c"])
  ["c", "b", "a"]
  """
  @spec reverse(term) :: list
  def reverse(input) do
    input
    |> to_enum()
    |> Enum.reverse()
  end

  @doc """
  Rounds an input number to the nearest integer or,
  if a number is specified as an argument, to that number of decimal places.

  iex> Solid.StandardFilter.round(1.2)
  "1"
  iex> Solid.StandardFilter.round(2.7)
  "3"
  iex> Solid.StandardFilter.round(183.357, 2)
  "183.36"
  iex> Solid.StandardFilter.round(nil, 2)
  0
  iex> Solid.StandardFilter.round(5.666, 1.2)
  "5.7"
  """
  @spec round(term, term) :: number | String.t()
  def round(input, precision \\ nil)

  def round(input, precision) when is_binary(input) do
    precision = to_integer(precision)

    input
    |> to_decimal()
    |> Decimal.round(precision)
    |> then(fn result ->
      if original_float?(input) and precision > 0 do
        decimal_to_float(result)
      else
        try_decimal_to_integer(result)
      end
    end)
  end

  def round(input, _precision) when is_integer(input) do
    input
  end

  def round(input, precision) when is_float(input) do
    precision = to_integer(precision)

    Decimal.from_float(input)
    |> Decimal.round(precision)
    |> Decimal.normalize()
    |> to_string()
  end

  def round(_, _), do: 0

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from the right side of a string.

  iex> Solid.StandardFilter.rstrip("          So much room for activities!          ")
  "          So much room for activities!"
  """
  @spec rstrip(term) :: String.t()
  def rstrip(input), do: String.trim_trailing(to_str(input))

  @doc """
  Returns the number of characters in a string or the number of items in an array.

  iex> Solid.StandardFilter.size("Ground control to Major Tom.")
  28
  iex> Solid.StandardFilter.size(~w(ground control to Major Tom.))
  5
  """
  @spec size(term) :: non_neg_integer
  def size(input) when is_binary(input), do: String.length(input)

  def size(range) when is_struct(range, Range), do: Enum.count(range)

  def size(input) when (not is_struct(input) and is_map(input)) or is_list(input) do
    Enum.count(input)
  end

  def size(_), do: 0

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

  iex> Solid.StandardFilter.slice([1, 2, 3], 1, 2)
  [2, 3]
  """
  @spec slice(term, term, term) :: String.t() | list
  def slice(input, offset, length \\ nil)

  def slice(input, offset, length) do
    offset = to_integer!(offset)

    length =
      if length do
        max(0, to_integer!(length))
      else
        1
      end

    if is_list(input) do
      Enum.slice(input, offset, length)
    else
      input
      |> to_str()
      |> String.slice(offset, length)
    end
  end

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.StandardFilter.sort(~w(zebra octopus giraffe SallySnake))
  ~w(SallySnake giraffe octopus zebra)
  """
  @spec sort(list) :: list
  def sort(input), do: Enum.sort(to_enum(input))

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.StandardFilter.sort_natural(~w(zebra octopus giraffe SallySnake))
  ~w(giraffe octopus SallySnake zebra)

  iex> Solid.StandardFilter.sort_natural(123)
  "123"
  """
  @spec sort_natural(any) :: any
  def sort_natural(input) when is_list(input) or is_struct(input, Range) do
    input
    |> to_enum()
    |> Enum.sort(&(String.downcase(to_string(&1)) <= String.downcase(to_string(&2))))
  end

  def sort_natural(input) do
    to_string(input)
  end

  @doc """
  Removes all whitespace (tabs, spaces, and newlines) from both the left and right side of a string.
  It does not affect spaces between words.

  iex> Solid.StandardFilter.strip("          So much room for activities!          ")
  "So much room for activities!"
  """
  @spec strip(term) :: String.t()
  def strip(input), do: String.trim(to_str(input))

  @doc """
  Multiplies a number by another number.

  iex> Solid.StandardFilter.times(3, 2)
  "6"
  iex> Solid.StandardFilter.times(24, 7)
  "168"
  iex> Solid.StandardFilter.times(183.357, 12)
  "2200.284"
  """
  @spec times(term, term) :: String.t()
  def times(input, operand) do
    input
    |> to_decimal()
    |> Decimal.mult(to_decimal(operand))
    |> then(fn result ->
      if original_float?(input) or original_float?(operand) do
        decimal_to_float(result)
      else
        try_decimal_to_integer(result)
      end
    end)
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
  def truncate(input, length \\ 50, ellipsis \\ "...") do
    length = to_integer!(length)
    input = to_str(input)
    ellipsis = to_str(ellipsis)

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
  @spec truncatewords(term, term, term) :: String.t()
  def truncatewords(input, max_words \\ 15, ellipsis \\ "...")
  def truncatewords(nil, _max_words, _ellipsis), do: ""

  def truncatewords(input, max_words, ellipsis) do
    input = to_str(input)
    max_words = to_integer!(max_words)
    max_words = max(max_words, 1)
    ellipsis = to_str(ellipsis)

    words =
      input
      |> String.split([" ", "\n", "\t"], trim: true)

    if length(words) > max_words do
      Enum.take(words, max_words)
      |> Enum.intersperse(" ")
      |> to_string
      |> Kernel.<>(ellipsis)
    else
      input
    end
  end

  @doc """
  Removes any duplicate elements in an array.

  Output
  iex> Solid.StandardFilter.uniq(~w(ants bugs bees bugs ants))
  ~w(ants bugs bees)
  """
  @spec uniq(list) :: list
  def uniq(input) do
    input
    |> to_enum()
    |> Enum.uniq()
  end

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
  "Test <br />\\ntext<br />\\n with line breaks."

  iex> Solid.StandardFilter.newline_to_br([[["Test \\ntext\\r\\n with "] | "line breaks."]])
  "Test <br />\\ntext<br />\\n with line breaks."
  """
  @spec newline_to_br(iodata()) :: String.t()
  def newline_to_br(iodata) do
    binary = IO.iodata_to_binary(iodata)
    pattern = :binary.compile_pattern(["\r\n", "\n"])
    String.replace(binary, pattern, "<br />\n")
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
  @spec where(term, term, term) :: list
  def where(input, key, value) do
    if value == nil do
      where(input, key)
    else
      input = to_enum(input)
      for map <- input, Map.has_key?(map, key), map[key] == value, do: map
    end
  end

  @spec where(term, term) :: list
  def where(input, key) do
    input
    |> to_enum
    |> Enum.flat_map(fn item ->
      if is_integer(item) do
        raise %Solid.ArgumentError{message: "cannot select the property '#{key}'"}
      end

      if is_map(item) && Map.has_key?(item, key) do
        [item]
      else
        []
      end
    end)
  end

  @doc """
  Removes any HTML tags from a string.

  This mimics the regex based approach of the ruby library.

  Output
  iex> Solid.StandardFilter.strip_html("Have <em>you</em> read <strong>Ulysses</strong>?")
  "Have you read Ulysses?"
  iex> Solid.StandardFilter.strip_html("<!-- foo bar \\n test -->test")
  "test"
  """
  @html_blocks ~r{(<script.*?</script>)|(<!--.*?-->)|(<style.*?</style>)}s
  @html_tags ~r|<.*?>|s
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

  defp to_integer!(input) when is_integer(input), do: input

  defp to_integer!(input) when is_binary(input) do
    String.to_integer(input)
  rescue
    _ -> raise %Solid.ArgumentError{message: "invalid integer"}
  end

  defp to_integer!(_), do: raise(%Solid.ArgumentError{message: "invalid integer"})

  defp to_integer(input) when is_integer(input), do: input
  defp to_integer(input) when is_float(input), do: Kernel.round(input)

  defp to_integer(input) when is_binary(input) do
    case Integer.parse(input) do
      {integer, _} -> integer
      _ -> 0
    end
  end

  defp to_integer(_), do: 0

  @zero Decimal.new(0)

  defp to_decimal(input) when is_binary(input) do
    # It must accept "1ABC" being integer 1
    # It must NOT accept "1.0ABC" being float 1.0
    # That's just how Liquid ruby does

    if Regex.match?(~r/\A-?\d+\.\d+\z/, input) do
      case Decimal.parse(input) do
        {decimal, ""} -> decimal
        _ -> @zero
      end
    else
      case Integer.parse(input) do
        {integer, _} -> Decimal.new(integer)
        _ -> @zero
      end
    end
  end

  defp to_decimal(input) when is_integer(input), do: Decimal.new(input)
  defp to_decimal(input) when is_float(input), do: Decimal.from_float(input)
  defp to_decimal(_input), do: @zero

  defp decimal_to_float(value) do
    if Decimal.integer?(value) do
      "#{Decimal.to_integer(value)}" <> ".0"
    else
      value
      |> Decimal.normalize()
      |> Decimal.to_float()
      |> to_string
    end
  end

  defp try_decimal_to_integer(value) do
    if Decimal.integer?(value) do
      "#{Decimal.to_integer(value)}"
    else
      decimal_to_float(value)
    end
  end

  defp original_float?(input) when is_float(input), do: true
  defp original_float?(input) when is_binary(input), do: Regex.match?(~r/\A-?\d+\.\d+\z/, input)
  defp original_float?(_), do: false
end
