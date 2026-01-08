defmodule Solid.Parser do
  @moduledoc """
  This module contains functions to parse Liquid templates
  """

  @whitespaces [" ", "\f", "\r", "\t", "\v"]
  alias Solid.Parser.Loc
  alias Solid.ParserContext
  alias Solid.{Object, Lexer, Tag, Text}

  @type errors :: [{binary, Lexer.loc()}]
  @type entry :: Text.t() | Object.t() | Solid.Renderable.t()
  @type parse_tree :: [entry]

  @doc """
  Parse text

  It accepts a :tags option to specify a map of tags to use. See `Solid.Tag.default_tags/0`
  """
  @spec parse(binary, keyword) :: {:ok, parse_tree} | {:error, errors}
  def parse(text, opts \\ []) do
    tags = Keyword.get(opts, :tags)
    parse(%ParserContext{rest: text, line: 1, column: 1, mode: :normal, tags: tags}, [], [])
  end

  defp parse(%ParserContext{rest: ""}, acc, errors) do
    case {acc, errors} do
      {acc, []} -> {:ok, Enum.reverse(acc)}
      {_, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  defp parse(context, acc, errors) do
    case parse_liquid_entry(context) do
      {:ok, result, context} ->
        acc = result ++ acc
        parse(context, acc, errors)

      {:error, reason, loc, context} ->
        errors = [{reason, loc} | errors]
        parse(context, acc, errors)

      :ok ->
        case {acc, errors} do
          {acc, []} -> {:ok, Enum.reverse(acc)}
          {_, errors} -> {:error, Enum.reverse(errors)}
        end
    end
  end

  @doc """
  Parses a Liquid entry until one of the tags is found
  The main use case for this function is to parse nested liquid entries
  until one of the tags is found. For example an if block:

      {% if true % } Text {{ object }} {% endif %}

  using `parse_until(context, "endif", "Expected endif")` will parse every liquid entry
  until an `endif` tag is found, the end of the template is reached or a parsing error occured.

  If one of the tags is found return what was parsed until such tag was found
  If none of the tags are found, returns the error tuple with the `reason`
  """
  @spec parse_until(ParserContext.t(), tags :: [binary] | binary, reason :: binary) ::
          {:ok, parse_tree, binary, Lexer.tokens(), ParserContext.t()}
          | {:error, binary, Lexer.loc()}
  def parse_until(context, tags, reason), do: parse_until(context, tags, reason, [], context.mode)

  defp parse_until(context, tags, reason, acc, expected_mode) do
    case maybe_tokenize_tag(tags, context) do
      {:tag, tag_name, tokens, context} ->
        # Must end on the same mode it started as a liquid tag cant
        # end a block started outside the liquid tag and vice-versa. Not allowed:
        #
        # {% if true %}
        # {% liquid
        #   endif
        # %}
        if context.mode != expected_mode do
          {:error, reason, %{line: context.line, column: context.column}}
        else
          {:ok, Enum.reverse(acc), tag_name, tokens, context}
        end

      _ ->
        case parse_liquid_entry(context) do
          :ok ->
            {:error, reason, %{line: context.line, column: context.column}}

          {:ok, result, context} ->
            parse_until(context, tags, reason, result ++ acc, expected_mode)

          {:error, error, meta, _context} ->
            {:error, error, meta}
        end
    end
  end

  @doc """
  Parses a Liquid entry

  Returns :ok if there is nothing else to parse.
  """
  @spec parse_liquid_entry(ParserContext.t()) ::
          :ok
          | {:ok, [entry], ParserContext.t()}
          | {:error, binary, Lexer.loc(), ParserContext.t()}
  def parse_liquid_entry(%ParserContext{mode: :normal} = context) do
    case context.rest do
      "" ->
        :ok

      <<"{{", _::binary>> ->
        object(context)

      <<"{%", _::binary>> ->
        tag(context)

      _ ->
        case text(context, [], []) do
          {:text, [], context} ->
            # discard empty text
            {:ok, [], context}

          {:text, text, final_context} ->
            {:ok,
             [
               %Text{
                 loc: %Loc{line: context.line, column: context.column},
                 text: IO.iodata_to_binary(text)
               }
             ], final_context}
        end
    end
  end

  def parse_liquid_entry(%ParserContext{mode: :liquid_tag, line: line, column: column} = context) do
    case context.rest do
      "" ->
        {:error, "Liquid tag not terminated", %{line: context.line, column: context.column},
         context}

      _ ->
        case Lexer.tokenize_tag_start(context) do
          {:ok, tag_name, context} ->
            loc = %Loc{line: line, column: column}

            case Tag.parse(tag_name, loc, context) do
              {:ok, tag, context} ->
                {:ok, [tag], context}

              {:error, reason, loc} ->
                {:error, reason, loc, context}
            end

          {:end_liquid_tag, context} ->
            {:ok, [], %{context | mode: :normal}}

          {:error, reason, rest, loc} ->
            {:error, reason, loc, %{context | rest: rest, line: loc[:line], column: loc[:column]}}
        end
    end
  end

  defp text(context, buffer, trailing_ws) do
    case context.rest do
      <<"\n", rest::binary>> ->
        text(%{context | rest: rest, line: context.line + 1, column: 1}, buffer, [
          "\n" | trailing_ws
        ])

      <<c::binary-size(1), rest::binary>> when c in @whitespaces ->
        text(%{context | rest: rest, column: context.column + 1}, buffer, [c | trailing_ws])

      <<"{%-", _::binary>> ->
        {:text, Enum.reverse(buffer), context}

      <<"{{-", _::binary>> ->
        {:text, Enum.reverse(buffer), context}

      <<"{%", _::binary>> ->
        {:text, Enum.reverse(trailing_ws ++ buffer), context}

      <<"{{", _::binary>> ->
        {:text, Enum.reverse(trailing_ws ++ buffer), context}

      "" ->
        {:text, Enum.reverse(trailing_ws ++ buffer), context}

      <<c, rest::binary>> ->
        text(%{context | rest: rest, column: context.column + 1}, [c | trailing_ws ++ buffer], [])
    end
  end

  @doc "Grab the line and column meta information of the first token"
  @spec meta_head(nonempty_list(Lexer.token())) :: Lexer.loc()
  def meta_head([token | _]), do: elem(token, 1)

  @doc "Tries to tokenize a tag entry if the tag name is included in the `tag_names`"
  @spec maybe_tokenize_tag(binary | [binary], ParserContext.t()) ::
          {:tag, binary, Lexer.tokens(), ParserContext.t()} | {:not_found, ParserContext.t()}
  def maybe_tokenize_tag(tag_names, context) do
    opts = [allowed_tag_names: List.wrap(tag_names)]

    if context.mode == :normal and !match?(<<"{%", _::binary>>, context.rest) do
      {:not_found, context}
    else
      case Lexer.tokenize_tag(context, opts) do
        {:ok, tag_name, tokens, context} ->
          {:tag, tag_name, tokens, context}

        _ ->
          {:not_found, context}
      end
    end
  end

  @doc """
  Remove blank text when the entries account for a "blank body". Check `Solid.Block.blank?/1` protocol
  and the implementations
  """
  @spec remove_blank_text_if_blank_body(parse_tree) :: parse_tree
  def remove_blank_text_if_blank_body(entries) do
    if Solid.Block.blank?(entries) do
      Enum.reject(entries, &match?(%Solid.Text{}, &1))
    else
      entries
    end
  end

  defp object(context) do
    case Lexer.tokenize_object(context) do
      {:ok, tokens, context} ->
        case Object.parse(tokens) do
          {:ok, object, [{:end, _}]} ->
            {:ok, [object], context}

          {:error, reason, loc} ->
            {:error, reason, loc, context}
        end

      {:error, "Tag or Object not properly terminated" = reason, rest, loc} ->
        {:error, reason, %{line: context.line, column: context.column},
         %{context | rest: rest, line: loc[:line], column: loc[:column]}}

      {:error, reason, rest, loc} ->
        {:error, reason, loc, %{context | rest: rest, line: loc[:line], column: loc[:column]}}
    end
  end

  defp tag(%ParserContext{line: line, column: column} = context) do
    case Lexer.tokenize_tag_start(context) do
      {:ok, tag_name, context} ->
        loc = %Loc{line: line, column: column}

        case Tag.parse(tag_name, loc, context) do
          {:ok, tag, context} ->
            {:ok, [tag], context}

          {:error, reason, loc} ->
            {:error, reason, loc, context}

          {:error, "Tag or Object not properly terminated" = reason, rest, loc} ->
            {:error, reason, %{line: line, column: column},
             %{context | rest: rest, line: loc[:line], column: loc[:column]}}

          {:error, reason, rest, loc} ->
            {:error, reason, loc, %{context | rest: rest, line: loc[:line], column: loc[:column]}}
        end

      {:liquid_tag, context} ->
        {:ok, [], %{context | mode: :liquid_tag}}

      {:error, reason, rest, loc} ->
        {:error, reason, loc, %{context | rest: rest, line: loc[:line], column: loc[:column]}}
    end
  end
end
