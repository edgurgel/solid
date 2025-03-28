defmodule Solid.ConditionExpression do
  alias Solid.{Argument, BinaryCondition, Context, Lexer, UnaryCondition}

  @type condition :: BinaryCondition.t() | UnaryCondition.t()

  @spec parse(Lexer.tokens()) :: {:ok, condition} | {:error, reason :: term, Lexer.loc()}
  def parse(tokens) do
    with {:ok, first_argument, rest} <- Argument.parse(tokens) do
      case rest do
        [{:end, _}] ->
          {:ok, %Solid.UnaryCondition{argument: first_argument, loc: first_argument.loc}}

        [{:identifier, _, relation} | rest] when relation in ["and", "or"] ->
          with {:ok, child_condition} <- parse(rest) do
            {:ok,
             %Solid.UnaryCondition{
               argument: first_argument,
               loc: first_argument.loc,
               child_condition: {String.to_atom(relation), child_condition}
             }}
          end

        [{:comparison, _, operator} | rest] ->
          with {:ok, second_argument, rest} <- Argument.parse(rest) do
            case rest do
              [{:end, _}] ->
                {:ok,
                 %Solid.BinaryCondition{
                   left_argument: first_argument,
                   operator: operator,
                   right_argument: second_argument,
                   loc: first_argument.loc
                 }}

              [{:identifier, _, relation} | rest] when relation in ["and", "or"] ->
                with {:ok, child_condition} <- parse(rest) do
                  {:ok,
                   %Solid.BinaryCondition{
                     left_argument: first_argument,
                     operator: operator,
                     right_argument: second_argument,
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
    {:ok, left_argument, context} = Argument.get(condition.left_argument, context, [], options)
    {:ok, right_argument, context} = Argument.get(condition.right_argument, context, [], options)

    case BinaryCondition.eval({left_argument, condition.operator, right_argument}) do
      {:ok, result} -> eval_child_condition(result, condition, context, options)
      {:error, reason} -> {:error, build_error(reason, condition.loc), context}
    end
  end

  def eval(%UnaryCondition{} = condition, context, options) do
    {:ok, argument, context} = Argument.get(condition.argument, context, [], options)

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
