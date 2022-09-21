defmodule Solid.Filter do
  @moduledoc """
  Standard filters
  """

  import Kernel, except: [abs: 1, ceil: 1, round: 1, floor: 1, apply: 2]

  @doc """
  Apply `filter` if it exists. Otherwise return the first input.

  iex> Solid.Filter.apply("upcase", ["ac"], [])
  "AC"
  iex> Solid.Filter.apply("no_filter_here", [1, 2, 3], [])
  1
  """
  def apply(filter, args, opts) do
    custom_module =
      opts[:custom_filters] || Application.get_env(:solid, :custom_filters, __MODULE__)

    args_with_opts = args ++ [opts]

    cond do
      filter_exists?({custom_module, filter, Enum.count(args_with_opts)}) ->
        apply_filter({custom_module, filter, args_with_opts})

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
  Limits a number to a minimum value.

  iex> Solid.Filter.at_least(5, 3)
  5
  iex> Solid.Filter.at_least(2, 4)
  4
  """
  @spec at_least(number, number) :: number
  def at_least(input, minimum), do: max(input, minimum)

  @doc """
  Limits a number to a maximum value.

  iex> Solid.Filter.at_most(5, 3)
  3
  iex> Solid.Filter.at_most(2, 4)
  2
  """
  @spec at_most(number, number) :: number
  def at_most(input, maximum), do: min(input, maximum)

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
  Converts a `DateTime`/`NaiveDateTime` struct into another date format.
  The input may also be a Unix timestamp or an ISO 8601 date string.

  The format for this syntax is the same as `Calendar.strftime/2`.

  To get the current time, pass the special word `"now"` (or `"today"`) to `date`.
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
  def first(input) when is_list(input), do: List.first(input)
  def first(_), do: nil

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
  Concatenates (joins together) multiple arrays.
  The resulting array contains all the items from the input arrays.

  iex> Solid.Filter.concat([1, 2], [3, 4])
  [1, 2, 3, 4]
  """
  @spec concat(list, list) :: list
  def concat(input, list) when is_list(input) and is_list(list) do
    input ++ list
  end

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
  def last(input) when is_list(input), do: List.last(input)
  def last(_), do: nil

  @doc """
  Removes all whitespaces (tabs, spaces, and newlines) from the beginning of a string.
  The filter does not affect spaces between words.

  iex> Solid.Filter.lstrip("          So much room for activities!          ")
  "So much room for activities!          "
  """
  @spec lstrip(String.t()) :: String.t()
  def lstrip(input), do: to_string(input) |> String.trim_leading()

  @doc """
  Split input string into an array of substrings separated by given pattern.

  iex> Solid.Filter.split("a b c", " ")
  ~w(a b c)
  iex> Solid.Filter.split("", " ")
  [""]
  """
  @spec split(any, String.t()) :: list(String.t())
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
  Subtracts a number from another number.

  iex> Solid.Filter.modulo(3, 2)
  1
  iex> Solid.Filter.modulo(24, 7)
  3
  iex> Solid.Filter.modulo(183.357, 12)
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

  iex> Solid.Filter.plus(4, 2)
  6
  iex> Solid.Filter.plus(16, 4)
  20
  iex> Solid.Filter.plus("16", 4)
  20
  iex> Solid.Filter.plus(183.357, 12)
  195.357
  iex> Solid.Filter.plus("183.357", 12)
  195.357
  iex> Solid.Filter.plus("183.ABC357", 12)
  nil
  """
  @spec plus(number, number) :: number
  def plus(input, number) when is_number(input), do: input + number

  def plus(input, number) when is_binary(input) do
    try do
      plus(String.to_integer(input), number)
    rescue
      ArgumentError ->
        plus(String.to_float(input), number)
    end
  rescue
    ArgumentError -> nil
  end

  def plus(_input, number), do: number

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
    input |> to_string |> String.replace(string, "")
  end

  @doc """
  Removes only the first occurrence of the specified substring from a string.

  iex> Solid.Filter.remove_first("I strained to see the train through the rain", "rain")
  "I sted to see the train through the rain"
  """
  @spec remove_first(String.t(), String.t()) :: String.t()
  def remove_first(input, string) do
    input |> to_string |> String.replace(string, "", global: false)
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
  @spec reverse(list) :: list
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
  def rstrip(input), do: to_string(input) |> String.trim_trailing()

  @doc """
  Returns the number of characters in a string or the number of items in an array.

  iex> Solid.Filter.size("Ground control to Major Tom.")
  28
  iex> Solid.Filter.size(~w(ground control to Major Tom.))
  5
  """
  @spec size(String.t() | list) :: non_neg_integer
  def size(input) when is_list(input), do: Enum.count(input)
  def size(input) when is_bitstring(input), do: String.length(input)
  def size(_input), do: 0

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
  @spec slice(String.t(), integer, non_neg_integer | nil) :: String.t()
  def slice(input, offset, length \\ nil)
  def slice(input, offset, nil), do: to_string(input) |> String.at(offset)
  def slice(input, offset, length), do: to_string(input) |> String.slice(offset, length)

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.Filter.sort(~w(zebra octopus giraffe SallySnake))
  ~w(SallySnake giraffe octopus zebra)
  """
  @spec sort(list) :: list
  def sort(input), do: Enum.sort(input)

  @doc """
  Sorts items in an array by a property of an item in the array. The order of the sorted array is case-sensitive.

  iex> Solid.Filter.sort_natural(~w(zebra octopus giraffe SallySnake))
  ~w(giraffe octopus SallySnake zebra)
  """
  @spec sort_natural(list) :: list
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
  def strip(input), do: to_string(input) |> String.trim()

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
    if is_bitstring(input) and String.length(input) > length do
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
  @spec truncatewords(nil | String.t(), non_neg_integer, String.t()) :: String.t()
  def truncatewords(input, max_words, ellipsis \\ "...")
  def truncatewords(nil, _max_words, _ellipsis), do: ""

  def truncatewords(input, max_words, ellipsis) do
    words = to_string(input) |> String.split(" ")

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

  @doc """
  Removes any newline characters (line breaks) from a string.

  Output
  iex> Solid.Filter.strip_newlines("Test \\ntext\\r\\n with line breaks.")
  "Test text with line breaks."

  iex> Solid.Filter.strip_newlines([[["Test \\ntext\\r\\n with "] | "line breaks."]])
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
  iex> Solid.Filter.newline_to_br("Test \\ntext\\r\\n with line breaks.")
  "Test <br />\\ntext<br />\\r\\n with line breaks."

  iex> Solid.Filter.newline_to_br([[["Test \\ntext\\r\\n with "] | "line breaks."]])
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
  iex> Solid.Filter.where(input, "type", "kitchen")
  [%{"id" => 1, "type" => "kitchen"}, %{"id" => 3, "type" => "kitchen"}]

  iex> input = [
  ...>   %{"id" => 1, "available" => true},
  ...>   %{"id" => 2, "type" => false},
  ...>   %{"id" => 3, "available" => true}
  ...> ]
  iex> Solid.Filter.where(input, "available")
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
  iex> Solid.Filter.strip_html("Have <em>you</em> read <strong>Ulysses</strong>?")
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
  iex> Solid.Filter.url_encode("john@liquid.com")
  "john%40liquid.com"

  iex> Solid.Filter.url_encode("Tetsuro Takara")
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
  iex> Solid.Filter.url_decode("%27Stop%21%27+said+Fred")
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
  iex> Solid.Filter.escape("Have you read 'James & the Giant Peach'?")
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

  iex> Solid.Filter.escape_once("1 &lt; 2 &amp; 3")
  "1 &lt; 2 &amp; 3"
  """
  @escape_once_regex ~r{["><']|&(?!([a-zA-Z]+|(#\d+));)}
  @spec escape_once(iodata()) :: String.t()
  def escape_once(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> String.replace(@escape_once_regex, &Solid.HTML.replacements/1)
  end
end
