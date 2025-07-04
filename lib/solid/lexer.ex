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

  @whitespaces [" ", "\f", "\r", "\t", "\v"]

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

  @whitespaces_including_new_line @whitespaces ++ ["\n"]

  # Special case for inline comment. Only tag that does not enforce a space
  # after the tag name
  # {% #### valid inline comment %}
  defp tag_name("#" <> text, line, column, []), do: {:ok, "#", text, line, column + 1}

  defp tag_name(text, line, column, buffer) do
    case text do
      <<tag_or_object_end::binary-size(2), _::binary>> when tag_or_object_end in ["%}", "}}"] ->
        case buffer do
          [] -> {:error, "Empty tag name", text, build_loc(line, column)}
          _ -> {:ok, transform_buffer(buffer), text, line, column}
        end

      <<tag_or_object_ws_end::binary-size(3), _::binary>>
      when tag_or_object_ws_end in ["-%}", "-}}"] ->
        case buffer do
          [] -> {:error, "Empty tag name", text, build_loc(line, column)}
          _ -> {:ok, transform_buffer(buffer), text, line, column}
        end

      <<char::binary-size(1), rest::binary>> when char not in @whitespaces_including_new_line ->
        tag_name(rest, line, column + 1, [char | buffer])

      _ ->
        case buffer do
          [] -> {:error, "Empty tag name", text, build_loc(line, column)}
          _ -> {:ok, transform_buffer(buffer), text, line, column}
        end
    end
  end

  # Special case for inline comment. Only tag that does not enforce a space
  # after the tag name
  # {% #### valid inline comment %}
  defp tag_name_for_liquid_tag("#" <> text, line, column, []),
    do: {:ok, "#", text, line, column + 1}

  defp tag_name_for_liquid_tag(text, line, column, buffer) do
    case text do
      <<tag_or_object_end::binary-size(2), _::binary>> when tag_or_object_end in ["%}"] ->
        case buffer do
          [] -> {:error, "Empty tag name", text, build_loc(line, column)}
          _ -> {:ok, transform_buffer(buffer), text, line, column}
        end

      <<"\n", rest::binary>> ->
        case buffer do
          [] -> {:error, "Empty tag name", rest, build_loc(line + 1, 1)}
          _ -> {:ok, transform_buffer(buffer), text, line, column}
        end

      <<char::binary-size(1), rest::binary>> when char not in @whitespaces ->
        tag_name_for_liquid_tag(rest, line, column + 1, [char | buffer])

      _ ->
        case buffer do
          [] -> {:error, "Empty tag name", text, build_loc(line, column)}
          _ -> {:ok, transform_buffer(buffer), text, line, column}
        end
    end
  end

  @digits 0..9 |> Enum.map(&Kernel.to_string/1)

  @comparison_operators ["==", "!=", "<>", "<=", ">="]

  @special_mapping %{
    "." => :dot,
    "|" => :pipe,
    "[" => :open_square,
    "]" => :close_square,
    "(" => :open_round,
    ")" => :close_round,
    ":" => :colon,
    "," => :comma,
    "=" => :assignment
  }
  @specials Map.keys(@special_mapping)
  @letters Enum.map(?a..?z, &<<&1>>) ++ Enum.map(?A..?Z, &<<&1>>) ++ ["_"]

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
      <<c::binary-size(1), rest::binary>> when c in @whitespaces ->
        tokenize(rest, line, column + 1, acc)

      # Newline
      <<"\n", rest::binary>> ->
        tokenize(rest, line + 1, 1, acc)

      # Comparison operators (two characters)
      <<operator::binary-size(2), rest::binary>> when operator in @comparison_operators ->
        acc = [{:comparison, build_loc(line, column), String.to_atom(operator)} | acc]
        tokenize(rest, line, column + 2, acc)

      # Special single-character tokens
      <<special::binary-size(1), rest::binary>> when special in @specials ->
        acc = [{Map.fetch!(@special_mapping, special), build_loc(line, column)} | acc]
        tokenize(rest, line, column + 1, acc)

      # Comparison operators (single character)
      <<operator::binary-size(1), rest::binary>> when operator in ["<", ">"] ->
        acc = [{:comparison, build_loc(line, column), String.to_atom(operator)} | acc]
        tokenize(rest, line, column + 1, acc)

      # "contains" keyword
      <<"contains", rest::binary>> ->
        acc = [{:comparison, build_loc(line, column), :contains} | acc]
        tokenize(rest, line, column + 8, acc)

      # Single or double quotes
      <<quote_char::binary-size(1), _rest::binary>> when quote_char in ["'", "\""] ->
        with {:string, string_value, quotes, rest, end_line, end_column} <-
               tokenize_string(text, line, column) do
          acc = [{:string, build_loc(line, column), string_value, quotes} | acc]
          tokenize(rest, end_line, end_column, acc)
        end

      # Numbers
      <<"-", digit::binary-size(1), rest::binary>> when digit in @digits ->
        case number_1(rest, line, column + 2, [digit, "-"]) do
          {:integer, number, rest, end_line, end_column} ->
            acc = [{:integer, build_loc(line, column), String.to_integer(number)} | acc]
            tokenize(rest, end_line, end_column, acc)

          {:float, number, rest, end_line, end_column} ->
            acc = [{:float, build_loc(line, column), String.to_float(number)} | acc]
            tokenize(rest, end_line, end_column, acc)
        end

      <<digit::binary-size(1), rest::binary>> when digit in @digits ->
        case number_1(rest, line, column + 1, [digit]) do
          {:integer, number, rest, end_line, end_column} ->
            acc = [{:integer, build_loc(line, column), String.to_integer(number)} | acc]
            tokenize(rest, end_line, end_column, acc)

          {:float, number, rest, end_line, end_column} ->
            acc = [{:float, build_loc(line, column), String.to_float(number)} | acc]
            tokenize(rest, end_line, end_column, acc)
        end

      # Identifiers
      <<letter::binary-size(1), rest::binary>> when letter in @letters ->
        {:identifier, identifier, rest, end_line, end_column} =
          identifier(rest, line, column + 1, [letter])

        acc = [{:identifier, build_loc(line, column), identifier} | acc]
        tokenize(rest, end_line, end_column, acc)

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
      <<c::binary-size(1), rest::binary>> when c in @whitespaces ->
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
      <<special::binary-size(1), rest::binary>> when special in @specials ->
        acc = [{Map.fetch!(@special_mapping, special), build_loc(line, column)} | acc]
        tokenize_for_liquid_tag(rest, line, column + 1, acc)

      # Comparison operators (single character)
      <<operator::binary-size(1), rest::binary>> when operator in ["<", ">"] ->
        acc = [{:comparison, build_loc(line, column), String.to_atom(operator)} | acc]
        tokenize_for_liquid_tag(rest, line, column + 1, acc)

      # "contains" keyword
      <<"contains", rest::binary>> ->
        acc = [{:comparison, build_loc(line, column), :contains} | acc]
        tokenize_for_liquid_tag(rest, line, column + 8, acc)

      # Single or double quotes
      <<quote_char::binary-size(1), _rest::binary>> when quote_char in ["'", "\""] ->
        with {:string, string_value, quotes, rest, end_line, end_column} <-
               tokenize_string(text, line, column) do
          acc = [{:string, build_loc(line, column), string_value, quotes} | acc]
          tokenize_for_liquid_tag(rest, end_line, end_column, acc)
        end

      # Numbers
      <<"-", digit::binary-size(1), rest::binary>> when digit in @digits ->
        case number_1(rest, line, column + 2, [digit, "-"]) do
          {:integer, number, rest, end_line, end_column} ->
            acc = [{:integer, build_loc(line, column), String.to_integer(number)} | acc]
            tokenize_for_liquid_tag(rest, end_line, end_column, acc)

          {:float, number, rest, end_line, end_column} ->
            acc = [{:float, build_loc(line, column), String.to_float(number)} | acc]
            tokenize_for_liquid_tag(rest, end_line, end_column, acc)
        end

      <<digit::binary-size(1), rest::binary>> when digit in @digits ->
        case number_1(rest, line, column + 1, [digit]) do
          {:integer, number, rest, end_line, end_column} ->
            acc = [{:integer, build_loc(line, column), String.to_integer(number)} | acc]
            tokenize_for_liquid_tag(rest, end_line, end_column, acc)

          {:float, number, rest, end_line, end_column} ->
            acc = [{:float, build_loc(line, column), String.to_float(number)} | acc]
            tokenize_for_liquid_tag(rest, end_line, end_column, acc)
        end

      # Identifiers
      <<letter::binary-size(1), rest::binary>> when letter in @letters ->
        {:identifier, identifier, rest, end_line, end_column} =
          identifier(rest, line, column + 1, [letter])

        acc = [{:identifier, build_loc(line, column), identifier} | acc]
        tokenize_for_liquid_tag(rest, end_line, end_column, acc)

      # Empty string (end of input)
      "" ->
        {:error, "Tag or Object not properly terminated", "", %{line: line, column: column}}

      # Unexpected character
      _ ->
        {:error, "Unexpected character '#{String.first(text)}'", text,
         %{line: line, column: column}}
    end
  end

  @word_characters Enum.map(?a..?z, &<<&1>>) ++
                     Enum.map(?A..?Z, &<<&1>>) ++
                     Enum.map(0..9, &Kernel.to_string/1) ++ ["_"]

  defp identifier(text, line, column, buffer) do
    case text do
      <<char::binary-size(1), rest::binary>> when char in @word_characters ->
        identifier(rest, line, column + 1, [char | buffer])

      # Checking if the dash belongs to the whitespace control or the identifier
      <<"-", object_or_tag::binary-size(2), _::binary>> when object_or_tag in ["}}", "%}"] ->
        {:identifier, transform_buffer(buffer), text, line, column}

      <<"-", rest::binary>> ->
        identifier(rest, line, column + 1, ["-" | buffer])

      <<"?", rest::binary>> ->
        identifier = transform_buffer(["?" | buffer])

        {:identifier, identifier, rest, line, column + 1}

      _ ->
        {:identifier, transform_buffer(buffer), text, line, column}
    end
  end

  defp number_1(text, line, column, buffer) do
    case text do
      <<digit::binary-size(1), rest::binary>> when digit in @digits ->
        number_1(rest, line, column + 1, [digit | buffer])

      # if there is a number after the dot we have a float
      <<".", next::binary-size(1), rest::binary>> when next in @digits ->
        number_2(next <> rest, line, column + 1, ["." | buffer])

      <<".", _rest::binary>> ->
        {:integer, transform_buffer(buffer), text, line, column}

      _ ->
        {:integer, transform_buffer(buffer), text, line, column}
    end
  end

  defp number_2(text, line, column, buffer) do
    case text do
      <<number::binary-size(1), rest::binary>> when number in @digits ->
        number_2(rest, line, column + 1, [number | buffer])

      _ ->
        {:float, transform_buffer(buffer), text, line, column}
    end
  end

  defp transform_buffer(buffer) do
    buffer
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp tokenize_string(<<quotes, rest::binary>> = text, line, column) do
    case string_value(rest, quotes, line, column + 1, []) do
      {:string, string_value, quotes, rest, end_line, end_column} ->
        {:string, string_value, quotes, rest, end_line, end_column}

      {:error, reason} ->
        {:error, reason, text, %{line: line, column: column}}
    end
  end

  defp string_value(text, quotes, line, column, buffer) do
    case text do
      "" ->
        {:error, "String with #{[quotes]} not terminated"}

      <<"\n", rest::binary>> ->
        string_value(rest, quotes, line + 1, column, ["\n" | buffer])

      <<c, rest::binary>> when c != quotes ->
        string_value(rest, quotes, line, column + 1, [c | buffer])

      <<^quotes, rest::binary>> ->
        {:string, transform_buffer(buffer), quotes, rest, line, column + 1}
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

  defp drop_all_whitespace(<<c::binary-size(1), rest::binary>>, line, column)
       when c in @whitespaces do
    drop_all_whitespace(rest, line, column + 1)
  end

  defp drop_all_whitespace(rest, line, column), do: {rest, line, column}
end
