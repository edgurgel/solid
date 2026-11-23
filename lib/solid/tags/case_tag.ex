defmodule Solid.Tags.CaseTag do
  alias Solid.{Argument, Parser}

  @type t :: %__MODULE__{
          loc: Parser.Loc.t(),
          argument: Argument.t(),
          cases: [{[Argument.t()] | :else, [Parser.entry()]}],
          blank: boolean
        }

  @enforce_keys [:loc, :argument, :cases]
  defstruct [:loc, :argument, :cases, blank: false]

  @behaviour Solid.Tag

  @impl true
  def parse("case", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, argument, [{:end, _}]} <- Argument.parse(tokens),
         {:ok, leading_body, cases, context} <- parse_cases(context) do
      tag = %__MODULE__{loc: loc, argument: argument, cases: cases}
      {:ok, remove_blank_text_if_blank(tag, leading_body), context}
    else
      {:ok, _argument, rest} -> {:error, "Unexpected token", Parser.meta_head(rest)}
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  # Whitespace is stripped from every branch, or from none: a branch that is
  # blank on its own keeps its whitespace when another branch has output, even
  # if that other branch is never rendered. What comes before the first `when`
  # is never rendered either, but output there also keeps the whitespace.
  #
  # The result is stored in `blank` so that an enclosing tag reads it instead of
  # walking this tag's branches again
  defp remove_blank_text_if_blank(tag, leading_body) do
    blank =
      Solid.Block.blank?(leading_body) and
        Enum.all?(tag.cases, fn {_arguments, body} -> Solid.Block.blank?(body) end)

    if blank do
      cases =
        Enum.map(tag.cases, fn {arguments, body} -> {arguments, Parser.remove_text(body)} end)

      %{tag | cases: cases, blank: true}
    else
      tag
    end
  end

  defp parse_cases(context) do
    # Whatever is after {% case %} and before the first when, else or endcase is
    # not rendered, but it decides whether the tag is blank
    with {:ok, leading_body, tag_name, tokens, context} <-
           Parser.parse_until(context, ~w(when else endcase), "Expected endcase"),
         {:ok, cases, context} <- do_parse_cases(tag_name, tokens, context, []) do
      {:ok, leading_body, cases, context}
    end
  end

  defp do_parse_cases("when", tokens, context, acc) do
    with {:ok, arguments} <- parse_arguments(tokens),
         {:ok, result, tag_name, tokens, context} <-
           Parser.parse_until(context, ~w(when else endcase), "Expected endcase") do
      do_parse_cases(tag_name, tokens, context, [
        {arguments, result} | acc
      ])
    end
  end

  defp do_parse_cases("else", tokens, context, acc) do
    with {:tokens, [{:end, _}]} <- {:tokens, tokens},
         {:ok, result, tag_name, tokens, context} <-
           Parser.parse_until(context, ~w(when else endcase), "Expected endcase") do
      do_parse_cases(tag_name, tokens, context, [
        {:else, result} | acc
      ])
    else
      {:tokens, tokens} ->
        {:error, "Unexpected token on else", Parser.meta_head(tokens)}

      error ->
        error
    end
  end

  defp do_parse_cases("endcase", tokens, context, acc) do
    case tokens do
      [{:end, _}] -> {:ok, Enum.reverse(acc), context}
      _ -> {:error, "Unexpected token on endcase", Parser.meta_head(tokens)}
    end
  end

  defp parse_arguments(tokens, acc \\ []) do
    with {:ok, argument, tokens} <- Argument.parse(tokens) do
      case tokens do
        [{:comma, _} | tokens] -> parse_arguments(tokens, [argument | acc])
        [{:identifier, _, "or"} | tokens] -> parse_arguments(tokens, [argument | acc])
        [{:end, _}] -> {:ok, Enum.reverse([argument | acc])}
        _ -> {:error, "Expected ',' or 'or'", Parser.meta_head(tokens)}
      end
    end
  end

  defimpl Solid.Block do
    def blank?(tag), do: tag.blank
  end

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      {:ok, value, context} = Solid.Argument.get(tag.argument, context, [], options)

      {_, acc, context} =
        tag.cases
        |> Enum.reduce({{:else_block, true}, [], context}, fn
          {:else, result}, {{:else_block, true}, acc, context} ->
            {{:else_block, true}, [result | acc], context}

          {:else, _result}, {{:else_block, false}, acc, context} ->
            {{:else_block, false}, acc, context}

          {arguments, result}, {{:else_block, else_block}, acc, context} ->
            {{:else_block, else_block}, inner_acc, context} =
              Enum.reduce(arguments, {{:else_block, else_block}, [], context}, fn argument,
                                                                                  {{:else_block,
                                                                                    else_block},
                                                                                   inner_acc,
                                                                                   context} ->
                {:ok, evaluated_argument, context} =
                  Solid.Argument.get_operand(argument, context, [], options)

                if when_matches?(value, evaluated_argument) do
                  {{:else_block, false}, [result | inner_acc], context}
                else
                  {{:else_block, else_block}, inner_acc, context}
                end
              end)

            {{:else_block, else_block}, [inner_acc | acc], context}
        end)

      {List.flatten(Enum.reverse(acc)), context}
    end

    # `when blank` and `when empty` check the case value like `value == blank`
    defp when_matches?(value, %struct{} = literal)
         when struct in [Solid.Literal.Blank, Solid.Literal.Empty] do
      Solid.BinaryCondition.eval({value, :==, literal}) == {:ok, true}
    end

    defp when_matches?(value, when_value), do: value == when_value
  end
end
