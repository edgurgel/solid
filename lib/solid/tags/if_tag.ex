defmodule Solid.Tags.IfTag do
  @moduledoc """
  Handle if and unless tags
  """
  @behaviour Solid.Tag

  alias Solid.{ConditionExpression, Parser.Loc, Parser}

  @enforce_keys [:loc, :tag_name, :body, :elsifs, :else_body, :condition]
  defstruct [:loc, :tag_name, :body, :elsifs, :else_body, :condition]

  @type t :: %__MODULE__{
          loc: Loc.t(),
          tag_name: :if | :unless,
          elsifs: [{ConditionExpression.condition(), [Parser.entry()]}],
          body: [Parser.entry()],
          else_body: [Parser.entry()],
          condition: ConditionExpression.condition()
        }

  defp ignore_until_end("if", "endif", context), do: {:ok, context}
  defp ignore_until_end("unless", "endunless", context), do: {:ok, context}

  defp ignore_until_end(starting_tag_name, _tag_name, context) do
    tags = if starting_tag_name == "if", do: "endif", else: "endunless"

    case Parser.parse_until(context, tags, "Expected endif") do
      {:ok, _result, _tag_name, _tokens, context} ->
        {:ok, context}

      {:error, "Expected 'endif'", meta} ->
        {:error, "Expected '#{tags}'", meta}

      {:error, reason, meta} ->
        {:error, "Expected '#{tags}'. Got: #{reason}", meta}
    end
  end

  @impl true
  def parse(starting_tag_name, loc, context) when starting_tag_name in ["if", "unless"] do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, condition} <- ConditionExpression.parse(tokens),
         {:ok, body, tag_name, tokens, context} <- parse_body(starting_tag_name, context),
         {:ok, elsifs, tag_name, context} <-
           parse_elsifs(starting_tag_name, tag_name, tokens, context),
         {:ok, else_body, tag_name, context} <-
           parse_else_body(starting_tag_name, tag_name, context),
         # Here we ignore until and endif or endunless is found ignoring extra
         # elses and elsifs
         {:ok, context} <- ignore_until_end(starting_tag_name, tag_name, context) do
      {:ok,
       %__MODULE__{
         tag_name: String.to_existing_atom(starting_tag_name),
         body: Parser.remove_blank_text_if_blank_body(body),
         else_body: Parser.remove_blank_text_if_blank_body(else_body),
         elsifs: elsifs,
         condition: condition,
         loc: loc
       }, context}
    end
  end

  defp parse_body(starting_tag_name, context) do
    tags = if starting_tag_name == "if", do: ~w(elsif else endif), else: ~w(elsif else endunless)
    expected_end_tag = if starting_tag_name == "if", do: "endif", else: "endunless"

    case Parser.parse_until(context, tags, "Expected 'endif'") do
      {:ok, result, tag_name, tokens, context} ->
        {:ok, result, tag_name, tokens, context}

      {:error, "Expected 'endif'", meta} ->
        {:error, "Expected '#{expected_end_tag}'", meta}

      {:error, reason, meta} ->
        {:error, "Expected one of '#{Enum.join(tags, "', '")}' tags. Got: #{reason}", meta}
    end
  end

  defp parse_elsifs(starting_tag_name, tag_name, tokens, context, acc \\ [])

  defp parse_elsifs("if", "endif", _tokens, context, acc),
    do: {:ok, Enum.reverse(acc), "endif", context}

  defp parse_elsifs("unless", "endunless", _tokens, context, acc),
    do: {:ok, Enum.reverse(acc), "endunless", context}

  defp parse_elsifs(_starting_tag_name, "else", _tokens, context, acc),
    do: {:ok, Enum.reverse(acc), "else", context}

  defp parse_elsifs(starting_tag_name, "elsif", tokens, context, acc) do
    tags = if starting_tag_name == "if", do: ~w(else endif), else: ~w(else endunless)

    case Parser.maybe_tokenize_tag(tags, context) do
      {:tag, tag_name, _tokens, context} ->
        {:ok, Enum.reverse(acc), tag_name, context}

      _ ->
        with {:ok, condition} <- ConditionExpression.parse(tokens),
             {:ok, body, tag_name, tokens, context} <- parse_body(starting_tag_name, context) do
          parse_elsifs(starting_tag_name, tag_name, tokens, context, [
            {condition, Parser.remove_blank_text_if_blank_body(body)} | acc
          ])
        end
    end
  end

  defp parse_else_body("if", "endif", context), do: {:ok, [], "endif", context}
  defp parse_else_body("unless", "endunless", context), do: {:ok, [], "endunless", context}

  defp parse_else_body(starting_tag_name, "else", context) do
    tag = if starting_tag_name == "if", do: ~w(endif else elsif), else: ~w(endunless else elsif)
    expected_tag = if starting_tag_name == "if", do: "endif", else: "endunless"

    case Parser.parse_until(context, tag, "Expected 'endif'") do
      {:ok, result, tag_name, _tokens, context} ->
        {:ok, result, tag_name, context}

      {:error, "Expected 'endif'", meta} ->
        {:error, "Expected '#{expected_tag}'", meta}

      {:error, reason, meta} ->
        {:error, "Expected '#{expected_tag}' tag. Got: #{reason}", meta}
    end
  end

  defimpl Solid.Renderable do
    alias Solid.Tags.IfTag

    def render(tag, context, options) do
      eval_main_body!(tag, context, options)

      eval_elsifs!(tag.elsifs, context, options)

      if tag.else_body do
        {tag.else_body, context}
      else
        {[], context}
      end
    catch
      {:result, result, context} -> {result, context}
    end

    defp eval_main_body!(%IfTag{tag_name: :if} = tag, context, options) do
      case ConditionExpression.eval(tag.condition, context, options) do
        {:ok, result, context} ->
          if result, do: throw({:result, tag.body, context})

        {:error, exception, context} ->
          return_error(exception, context)
      end
    end

    defp eval_main_body!(%IfTag{tag_name: :unless} = tag, context, options) do
      case ConditionExpression.eval(tag.condition, context, options) do
        {:ok, result, context} ->
          if !result, do: throw({:result, tag.body, context})

        {:error, exception, context} ->
          return_error(exception, context)
      end
    end

    defp eval_elsifs!(elsifs, context, options) do
      Enum.each(elsifs, fn {condition, body} ->
        case ConditionExpression.eval(condition, context, options) do
          {:ok, result, context} ->
            if result, do: throw({:result, body, context})

          {:error, exception, context} ->
            return_error(exception, context)
        end
      end)
    end

    defp return_error(exception, context) do
      context = Solid.Context.put_errors(context, exception)
      throw({:result, Exception.message(exception), context})
    end
  end
end
