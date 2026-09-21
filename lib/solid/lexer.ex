defmodule Solid.Lexer do
  @moduledoc """
  Lexer module for Solid. It is responsible for tokenizing the input text inside an object or a tag.
  """

  alias Solid.ParserContext

  @type operator :: :== | :!= | :> | :>= | :< | :<= | :<> | :contains
  @type special ::
          :dot
          | :pipe
          | :open_round
          | :close_round
          | :open_square
          | :close_square
          | :colon
          | :comma
          | :assignment
  @type line :: pos_integer
  @type column :: pos_integer
  @type token ::
          {:string, loc, binary, ?' | ?"}
          | {:integer, loc, integer}
          | {:float, loc, float}
          | {special, loc}
          | {:comparison, loc, operator}
          | {:identifier, loc, binary}
          | {:end, loc}
  @type tokens :: [token]
  @type loc :: %{line: line, column: column}

  # Whitespace as bytes (integers): matching a byte and comparing against
  # integers is much cheaper than extracting a binary-size(1) sub-binary and
  # comparing it against a list of strings.
  @whitespace_bytes ~c" \f\r\t\v"
  @whitespace_nl_bytes ~c" \f\r\t\v\n"

  @doc "Tokenize the input text inside an object"
  @spec tokenize_object(ParserContext.t()) ::
          {:ok, tokens, ParserContext.t()}
          | {:error, reason :: binary, rest :: binary, loc}
  def tokenize_object(%ParserContext{rest: "{{" <> text, line: line, column: column} = context) do
    # The actual whitespace control is handled elsewhere
    {text, column} = drop(text, column + 2, "-")

    with {:ok, acc, text, line, column} <- tokenize(text, line, column, []),
         {:ok, text, line, column} <- object_end(text, line, column) do
      {:ok, acc, %{context | rest: text, line: line, column: column}}
    end
  end

  @doc "Tokenize the tag name for a tag"
  @spec tokenize_tag_start(ParserContext.t(), keyword) ::
          {:ok, tag_name :: binary, ParserContext.t()}
          | {:liquid_tag, ParserContext.t()}
          | {:end_liquid_tag, ParserContext.t()}
          | {:error, reason :: binary, rest :: binary, loc}
          | {:error, :not_expected_tag}
  def tokenize_tag_start(context, opts \\ []) do
    allowed_tag_names = Keyword.get(opts, :allowed_tag_names, [])

    if context.mode == :liquid_tag do
      do_tokenize_liquid_tag_entry_start(context, allowed_tag_names)
    else
      do_tokenize_tag_start(context, allowed_tag_names)
    end
  end

  defp do_tokenize_liquid_tag_entry_start(context, allowed_tag_names) do
    {text, line, column} = drop_all_whitespace(context.rest, context.line, context.column)

    case text do
      <<"-%}", rest::binary>> ->
        {rest, line, column} = drop_all_whitespace(rest, line, column + 3)
        {:end_liquid_tag, %{context | rest: rest, line: line, column: column}}

      <<"%}", rest::binary>> ->
        {:end_liquid_tag, %{context | mode: :normal, rest: rest, line: line, column: column + 2}}

      _ ->
        with {:ok, tag_name, text, line, column} <-
               tag_name_for_liquid_tag(text, line, column, []),
             true <- validate_tag_name(tag_name, allowed_tag_names) do
          {:ok, tag_name, %{context | rest: text, line: line, column: column}}
        else
          # Different tag name found
          false -> {:error, :not_expected_tag}
          error -> error
        end
    end
  end

  defp do_tokenize_tag_start(
         %ParserContext{rest: "{%" <> text, line: line, column: column} = context,
         allowed_tag_names
       ) do
    # The actual whitespace control is handled elsewhere
    {text, column} = drop(text, column + 2, "-")
    {text, line, column} = drop_all_whitespace(text, line, column)

    with {:ok, tag_name, text, line, column} <- tag_name(text, line, column, []),
         true <- validate_tag_name(tag_name, allowed_tag_names) do
      if tag_name == "liquid" do
        {:liquid_tag, %{context | rest: text, line: line, column: column}}
      else
        {:ok, tag_name, %{context | rest: text, line: line, column: column}}
      end
    else
      # Different tag name found
      false -> {:error, :not_expected_tag}
      error -> error
    end
  end

  defp do_tokenize_tag_start(_, _), do: {:error, :not_found}

  @doc "Tokenize the rest of the tag after the tag name"
  @spec tokenize_tag_end(ParserContext.t()) ::
          {:ok, tokens, ParserContext.t()} | {:error, reason :: binary, rest :: binary, loc}
  def tokenize_tag_end(context) do
    if context.mode == :liquid_tag do
      with {:ok, tokens, text, line, column} <-
             tokenize_for_liquid_tag(context.rest, context.line, context.column, []) do
        {:ok, tokens, %{context | rest: text, line: line, column: column}}
      end
    else
      with {:ok, tokens, text, line, column} <-
             tokenize(context.rest, context.line, context.column, []),
           {:ok, text, line, column} <- tag_end(text, line, column) do
        {:ok, tokens, %{context | rest: text, line: line, column: column}}
      end
    end
  end

  @doc "Tokenize the input text as a complete tag"
  @spec tokenize_tag(ParserContext.t(), keyword) ::
          {:ok, tag_name :: binary, tokens, ParserContext.t()}
          | {:liquid_tag, ParserContext.t()}
          | {:end_liquid_tag, ParserContext.t()}
          | {:error, reason :: binary, rest :: binary, loc}
          | {:error, :not_expected_tag}
  def tokenize_tag(context, opts \\ []) do
    with {:ok, tag_name, context} <- tokenize_tag_start(context, opts),
         {:ok, tokens, context} <- tokenize_tag_end(context) do
      {:ok, tag_name, tokens, context}
    end
  end

  defp validate_tag_name(_tag_name, []), do: true

  defp validate_tag_name(tag_name, allowed_tag_names) do
    Enum.member?(allowed_tag_names, tag_name)
  end

  # Special case for inline comment. Only tag that does not enforce a space
  # after the tag name
  # {% #### valid inline comment %}
  defp tag_name("#" <> text, line, column, []), do: {:ok, "#", text, line, column + 1}

  defp tag_name(text, line, column, []) do
    case tag_name_end(text, 0) do
      0 ->
        {:error, "Empty tag name", text, build_loc(line, column)}

      len ->
        rest = binary_part(text, len, byte_size(text) - len)
        {:ok, binary_part(text, 0, len), rest, line, column + len}
    end
  end

  # A tag name is a contiguous slice ending at `%}`/`}}` (optionally with a
  # leading `-` whitespace-control marker) or the first whitespace byte, so we
  # just count its byte length and let the caller slice it out with binary_part/3.
  defp tag_name_end(text, len) do
    case text do
      <<tag_or_object_end::binary-size(2), _::binary>> when tag_or_object_end in ["%}", "}}"] ->
        len

      <<tag_or_object_ws_end::binary-size(3), _::binary>>
      when tag_or_object_ws_end in ["-%}", "-}}"] ->
        len

      <<char, rest::binary>> when char not in @whitespace_nl_bytes ->
        tag_name_end(rest, len + 1)

      _ ->
        len
    end
  end

  # Special case for inline comment. Only tag that does not enforce a space
  # after the tag name
  # {% #### valid inline comment %}
  defp tag_name_for_liquid_tag("#" <> text, line, column, []),
    do: {:ok, "#", text, line, column + 1}

  defp tag_name_for_liquid_tag(text, line, column, []) do
    case liquid_tag_name_end(text, 0) do
      0 ->
        case text do
          <<"\n", rest::binary>> -> {:error, "Empty tag name", rest, build_loc(line + 1, 1)}
          _ -> {:error, "Empty tag name", text, build_loc(line, column)}
        end

      len ->
        rest = binary_part(text, len, byte_size(text) - len)
        {:ok, binary_part(text, 0, len), rest, line, column + len}
    end
  end

  # Inside a `{% liquid %}` tag the terminators are `%}` or a newline (which ends
  # the individual sub-tag); otherwise the same contiguous-slice logic applies.
  defp liquid_tag_name_end(text, len) do
    case text do
      <<"%}", _::binary>> ->
        len

      <<"\n", _::binary>> ->
        len

      <<char, rest::binary>> when char not in @whitespace_bytes ->
        liquid_tag_name_end(rest, len + 1)

      _ ->
        len
    end
  end

  @comparison_operators ["==", "!=", "<>", "<=", ">="]

  @special_mapping %{
    ?. => :dot,
    ?| => :pipe,
    ?[ => :open_square,
    ?] => :close_square,
    ?( => :open_round,
    ?) => :close_round,
    ?: => :colon,
    ?, => :comma,
    ?= => :assignment
  }

  defp tokenize(text, line, column, acc) do
    case text do
      # End of object or tag
      <<object_or_tag::binary-size(2), _rest::binary>> when object_or_tag in ["}}", "%}"] ->
        acc = [{:end, build_loc(line, column)} | acc]
        {:ok, Enum.reverse(acc), text, line, column}

      # End of object or tag with whitespace control
      <<object_or_tag::binary-size(3), _rest::binary>> when object_or_tag in ["-}}", "-%}"] ->
        acc = [{:end, build_loc(line, column)} | acc]
        {:ok, Enum.reverse(acc), text, line, column}

      # Whitespace
      <<c, rest::binary>> when c in @whitespace_bytes ->
        tokenize(rest, line, column + 1, acc)

      # Newline
      <<"\n", rest::binary>> ->
        tokenize(rest, line + 1, 1, acc)

      # Comparison operators (two characters)
      <<operator::binary-size(2), rest::binary>> when operator in @comparison_operators ->
        acc = [{:comparison, build_loc(line, column), String.to_atom(operator)} | acc]
        tokenize(rest, line, column + 2, acc)

      # Special single-character tokens
      <<special, rest::binary>> when is_map_key(@special_mapping, special) ->
        acc = [{Map.fetch!(@special_mapping, special), build_loc(line, column)} | acc]
        tokenize(rest, line, column + 1, acc)

      # Comparison operators (single character)
      <<operator, rest::binary>> when operator in ~c"<>" ->
        acc = [{:comparison, build_loc(line, column), comparison_operator(operator)} | acc]
        tokenize(rest, line, column + 1, acc)

      # Single or double quotes
      <<quote_char::binary-size(1), _rest::binary>> when quote_char in ["'", "\""] ->
        with {:string, string_value, quotes, rest, end_line, end_column} <-
               tokenize_string(text, line, column) do
          acc = [{:string, build_loc(line, column), string_value, quotes} | acc]
          tokenize(rest, end_line, end_column, acc)
        end

      # Numbers
      <<"-", digit, after_digit::binary>> when digit in ?0..?9 ->
        {type, len} = number_end(after_digit, 2)
        number = binary_part(text, 0, len)
        rest = binary_part(text, len, byte_size(text) - len)
        acc = [number_token(type, build_loc(line, column), number) | acc]
        tokenize(rest, line, column + len, acc)

      <<digit, after_digit::binary>> when digit in ?0..?9 ->
        {type, len} = number_end(after_digit, 1)
        number = binary_part(text, 0, len)
        rest = binary_part(text, len, byte_size(text) - len)
        acc = [number_token(type, build_loc(line, column), number) | acc]
        tokenize(rest, line, column + len, acc)

      # Identifiers (special case for contains)
      <<letter, _::binary>> when letter in ?a..?z or letter in ?A..?Z or letter == ?_ ->
        len = identifier_end(text, 0)
        identifier = binary_part(text, 0, len)
        rest = binary_part(text, len, byte_size(text) - len)

        identifier_or_contains =
          case identifier do
            "contains" -> {:comparison, build_loc(line, column), :contains}
            _ -> {:identifier, build_loc(line, column), identifier}
          end

        tokenize(rest, line, column + len, [identifier_or_contains | acc])

      # Empty string (end of input)
      "" ->
        {:error, "Tag or Object not properly terminated", "", %{line: line, column: column}}

      # Unexpected character
      _ ->
        {:error, "Unexpected character '#{String.first(text)}'", text,
         %{line: line, column: column}}
    end
  end

  defp tokenize_for_liquid_tag(text, line, column, acc) do
    case text do
      # End of liquid tag
      <<"%}", _rest::binary>> ->
        acc = [{:end, build_loc(line, column)} | acc]
        {:ok, Enum.reverse(acc), text, line, column}

      # End of liquid tag with whitespace control
      <<"-%}", _rest::binary>> ->
        acc = [{:end, build_loc(line, column)} | acc]
        {:ok, Enum.reverse(acc), text, line, column}

      # Whitespace
      <<c, rest::binary>> when c in @whitespace_bytes ->
        tokenize_for_liquid_tag(rest, line, column + 1, acc)

      # Newline means end of a tag when inside a liquid tag
      <<"\n", rest::binary>> ->
        acc = [{:end, build_loc(line, column)} | acc]
        {:ok, Enum.reverse(acc), rest, line + 1, 1}

      # Comparison operators (two characters)
      <<operator::binary-size(2), rest::binary>> when operator in @comparison_operators ->
        acc = [{:comparison, build_loc(line, column), String.to_atom(operator)} | acc]
        tokenize_for_liquid_tag(rest, line, column + 2, acc)

      # Special single-character tokens
      <<special, rest::binary>> when is_map_key(@special_mapping, special) ->
        acc = [{Map.fetch!(@special_mapping, special), build_loc(line, column)} | acc]
        tokenize_for_liquid_tag(rest, line, column + 1, acc)

      # Comparison operators (single character)
      <<operator, rest::binary>> when operator in ~c"<>" ->
        acc = [{:comparison, build_loc(line, column), comparison_operator(operator)} | acc]
        tokenize_for_liquid_tag(rest, line, column + 1, acc)

      # Single or double quotes
      <<quote_char::binary-size(1), _rest::binary>> when quote_char in ["'", "\""] ->
        with {:string, string_value, quotes, rest, end_line, end_column} <-
               tokenize_string(text, line, column) do
          acc = [{:string, build_loc(line, column), string_value, quotes} | acc]
          tokenize_for_liquid_tag(rest, end_line, end_column, acc)
        end

      # Numbers
      <<"-", digit, after_digit::binary>> when digit in ?0..?9 ->
        {type, len} = number_end(after_digit, 2)
        number = binary_part(text, 0, len)
        rest = binary_part(text, len, byte_size(text) - len)
        acc = [number_token(type, build_loc(line, column), number) | acc]
        tokenize_for_liquid_tag(rest, line, column + len, acc)

      <<digit, after_digit::binary>> when digit in ?0..?9 ->
        {type, len} = number_end(after_digit, 1)
        number = binary_part(text, 0, len)
        rest = binary_part(text, len, byte_size(text) - len)
        acc = [number_token(type, build_loc(line, column), number) | acc]
        tokenize_for_liquid_tag(rest, line, column + len, acc)

      # Identifiers (special case for contains)
      <<letter, _::binary>> when letter in ?a..?z or letter in ?A..?Z or letter == ?_ ->
        len = identifier_end(text, 0)
        identifier = binary_part(text, 0, len)
        rest = binary_part(text, len, byte_size(text) - len)

        identifier_or_contains =
          case identifier do
            "contains" -> {:comparison, build_loc(line, column), :contains}
            _ -> {:identifier, build_loc(line, column), identifier}
          end

        tokenize_for_liquid_tag(rest, line, column + len, [identifier_or_contains | acc])

      # Empty string (end of input)
      "" ->
        {:error, "Tag or Object not properly terminated", "", %{line: line, column: column}}

      # Unexpected character
      _ ->
        {:error, "Unexpected character '#{String.first(text)}'", text,
         %{line: line, column: column}}
    end
  end

  defp comparison_operator(?<), do: :<
  defp comparison_operator(?>), do: :>

  # Count the byte length of the identifier at the front of the input. An
  # identifier is always a contiguous slice, so the caller grabs it with a single
  # `binary_part/3` instead of accumulating and reversing a byte buffer. `rest`
  # walks forward one byte at a time while `len` counts the bytes consumed.
  defp identifier_end(rest, len) do
    case rest do
      <<char, rest::binary>>
      when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ ->
        identifier_end(rest, len + 1)

      # Checking if the dash belongs to the whitespace control or the identifier
      <<"-", object_or_tag::binary-size(2), _::binary>> when object_or_tag in ["}}", "%}"] ->
        len

      <<"-", rest::binary>> ->
        identifier_end(rest, len + 1)

      # A trailing `?` is part of the identifier
      <<"?", _::binary>> ->
        len + 1

      _ ->
        len
    end
  end

  # A number is a contiguous slice, so we count its byte length (noting whether a
  # `.digit` made it a float) and let the caller slice it out with binary_part/3.
  # `len` starts at the bytes the caller already matched (1 for a bare digit, 2
  # for a leading `-`).
  defp number_end(<<digit, rest::binary>>, len) when digit in ?0..?9,
    do: number_end(rest, len + 1)

  # Only a digit after the dot makes it a float; otherwise the dot is left in the
  # rest (e.g. the `..` of a range, or `5.foo`).
  defp number_end(<<".", digit, rest::binary>>, len) when digit in ?0..?9,
    do: number_end_float(rest, len + 2)

  defp number_end(_text, len), do: {:integer, len}

  defp number_end_float(<<digit, rest::binary>>, len) when digit in ?0..?9,
    do: number_end_float(rest, len + 1)

  defp number_end_float(_text, len), do: {:float, len}

  defp number_token(:integer, loc, number), do: {:integer, loc, String.to_integer(number)}
  defp number_token(:float, loc, number), do: {:float, loc, String.to_float(number)}

  defp tokenize_string(<<quotes, rest::binary>> = text, line, column) do
    case string_end(rest, quotes, line, column + 1, 0) do
      {:ok, len, end_line, end_column} ->
        value = binary_part(rest, 0, len)
        # Drop the content and the closing quote from the remaining input.
        new_rest = binary_part(rest, len + 1, byte_size(rest) - len - 1)
        {:string, value, quotes, new_rest, end_line, end_column}

      {:error, reason} ->
        {:error, reason, text, %{line: line, column: column}}
    end
  end

  # String contents are copied verbatim (no escaping), so the value is a
  # contiguous slice between the quotes. Count its byte length while tracking
  # line/column for the location metadata.
  defp string_end(text, quotes, line, column, len) do
    case text do
      "" ->
        {:error, "String with #{[quotes]} not terminated"}

      <<"\n", rest::binary>> ->
        string_end(rest, quotes, line + 1, column, len + 1)

      <<^quotes, _rest::binary>> ->
        {:ok, len, line, column + 1}

      <<_c, rest::binary>> ->
        string_end(rest, quotes, line, column + 1, len + 1)
    end
  end

  defp tag_end(text, line, column) do
    case text do
      <<"-%}", rest::binary>> ->
        {rest, line, column} = drop_all_whitespace(rest, line, column + 3)
        {:ok, rest, line, column}

      <<"%}", rest::binary>> ->
        {:ok, rest, line, column + 2}

      _ ->
        {:error, "Tag not properly terminated", text, %{line: line, column: column}}
    end
  end

  defp object_end(text, line, column) do
    case text do
      <<"-}}", rest::binary>> ->
        {rest, line, column} = drop_all_whitespace(rest, line, column + 3)
        {:ok, rest, line, column}

      <<"}}", rest::binary>> ->
        {:ok, rest, line, column + 2}

      _ ->
        {:error, "Object not properly terminated", text, %{line: line, column: column}}
    end
  end

  defp build_loc(line, column), do: %{line: line, column: column}

  defp drop(<<char::binary-size(1), rest::binary>>, column, char), do: {rest, column + 1}
  defp drop(text, column, _char), do: {text, column}

  defp drop_all_whitespace(<<"\n", rest::binary>>, line, _column) do
    drop_all_whitespace(rest, line + 1, 1)
  end

  defp drop_all_whitespace(<<c, rest::binary>>, line, column)
       when c in @whitespace_bytes do
    drop_all_whitespace(rest, line, column + 1)
  end

  defp drop_all_whitespace(rest, line, column), do: {rest, line, column}
end
