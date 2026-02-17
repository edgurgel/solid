defmodule Solid.ConditionExpression do
  alias Solid.{Argument, BinaryCondition, Context, Lexer, UnaryCondition}

  @type condition :: BinaryCondition.t() | UnaryCondition.t()

  @spec parse(Lexer.tokens()) :: {:ok, condition} | {:error, reason :: term, Lexer.loc()}
  def parse(tokens) do
    with {:ok, first_argument, first_filters, rest} <- Argument.parse_with_filters(tokens) do
      case rest do
        [{:end, _}] ->
          {:ok,
           %Solid.UnaryCondition{
             argument: first_argument,
             argument_filters: first_filters,
             loc: first_argument.loc
           }}

        [{:identifier, _, relation} | rest] when relation in ["and", "or"] ->
          with {:ok, child_condition} <- parse(rest) do
            {:ok,
             %Solid.UnaryCondition{
               argument: first_argument,
               argument_filters: first_filters,
               loc: first_argument.loc,
               child_condition: {String.to_atom(relation), child_condition}
             }}
          end

        [{:comparison, _, operator} | rest] ->
          with {:ok, second_argument, second_filters, rest} <-
                 Argument.parse_with_filters(rest) do
            case rest do
              [{:end, _}] ->
                {:ok,
                 %Solid.BinaryCondition{
                   left_argument: first_argument,
                   left_argument_filters: first_filters,
                   operator: operator,
                   right_argument: second_argument,
                   right_argument_filters: second_filters,
                   loc: first_argument.loc
                 }}

              [{:identifier, _, relation} | rest] when relation in ["and", "or"] ->
                with {:ok, child_condition} <- parse(rest) do
                  {:ok,
                   %Solid.BinaryCondition{
                     left_argument: first_argument,
                     left_argument_filters: first_filters,
                     operator: operator,
                     right_argument: second_argument,
                     right_argument_filters: second_filters,
                     loc: first_argument.loc,
                     child_condition: {String.to_atom(relation), child_condition}
                   }}
                end

              _ ->
                {:error, "Expected condition", Solid.Parser.meta_head(rest)}
            end
          end

        _ ->
          {:error, "Expected Condition", Solid.Parser.meta_head(rest)}
      end
    end
  end

  @spec eval(condition, Context.t(), keyword) ::
          {:ok, boolean, Context.t()} | {:error, Exception.t(), Context.t()}
  def eval(%BinaryCondition{} = condition, context, options) do
    {:ok, left_argument, context} =
      Argument.get(condition.left_argument, context, condition.left_argument_filters, options)

    {:ok, right_argument, context} =
      Argument.get(condition.right_argument, context, condition.right_argument_filters, options)

    case BinaryCondition.eval({left_argument, condition.operator, right_argument}) do
      {:ok, result} -> eval_child_condition(result, condition, context, options)
      {:error, reason} -> {:error, build_error(reason, condition.loc), context}
    end
  end

  def eval(%UnaryCondition{} = condition, context, options) do
    {:ok, argument, context} =
      Argument.get(condition.argument, context, condition.argument_filters, options)

    UnaryCondition.eval(argument)
    |> eval_child_condition(condition, context, options)
  end

  defp eval_child_condition(left_side, condition, context, options) do
    case condition.child_condition do
      {:and, child_condition} ->
        with {:ok, result, context} <- eval(child_condition, context, options) do
          {:ok, left_side and result, context}
        end

      {:or, child_condition} ->
        with {:ok, result, context} = eval(child_condition, context, options) do
          {:ok, left_side or result, context}
        end

      nil ->
        {:ok, left_side, context}
    end
  end

  defp build_error(reason, loc), do: %Solid.ArgumentError{message: reason, loc: loc}
end
