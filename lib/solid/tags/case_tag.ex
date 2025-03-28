defmodule Solid.Tags.CaseTag do
  alias Solid.{Argument, Parser}

  @type t :: %__MODULE__{
          loc: Parser.Loc.t(),
          argument: Argument.t(),
          cases: [{[Argument.t()] | :else, [Parser.entry()]}]
        }

  @enforce_keys [:loc, :argument, :cases]
  defstruct [:loc, :argument, :cases]

  @behaviour Solid.Tag

  @impl true
  def parse("case", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, argument, [{:end, _}]} <- Argument.parse(tokens),
         {:ok, cases, context} <- parse_cases(context) do
      {:ok, %__MODULE__{loc: loc, argument: argument, cases: cases}, context}
    else
      {:ok, _argument, rest} -> {:error, "Unexpected token", Parser.meta_head(rest)}
      {:error, reason, _rest, loc} -> {:error, reason, loc}
      error -> error
    end
  end

  defp parse_cases(context) do
    # We just want to parse whatever is after {% case %} and before the first when, else or endcase
    with {:ok, _, tag_name, tokens, context} <-
           Parser.parse_until(context, ~w(when else endcase), "Expected endcase") do
      do_parse_cases(tag_name, tokens, context, [])
    end
  end

  defp do_parse_cases("when", tokens, context, acc) do
    with {:ok, arguments} <- parse_arguments(tokens),
         {:ok, result, tag_name, tokens, context} <-
           Parser.parse_until(context, ~w(when else endcase), "Expected endcase") do
      do_parse_cases(tag_name, tokens, context, [
        {arguments, Parser.remove_blank_text_if_blank_body(result)} | acc
      ])
    end
  end

  defp do_parse_cases("else", tokens, context, acc) do
    with {:tokens, [{:end, _}]} <- {:tokens, tokens},
         {:ok, result, tag_name, tokens, context} <-
           Parser.parse_until(context, ~w(when else endcase), "Expected endcase") do
      do_parse_cases(tag_name, tokens, context, [
        {:else, Parser.remove_blank_text_if_blank_body(result)} | acc
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
                  Solid.Argument.get(argument, context, [], options)

                if evaluated_argument == value do
                  {{:else_block, false}, [result | inner_acc], context}
                else
                  {{:else_block, else_block}, inner_acc, context}
                end
              end)

            {{:else_block, else_block}, [inner_acc | acc], context}
        end)

      {Enum.reverse(List.flatten(acc)), context}
    end
  end
end
