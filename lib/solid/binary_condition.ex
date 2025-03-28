defmodule Solid.BinaryCondition do
  alias Solid.{Argument, Filter}
  alias Solid.Literal.Empty

  defstruct [
    :loc,
    :child_condition,
    :left_argument,
    :operator,
    :right_argument,
    left_argument_filters: [],
    right_argument_filters: []
  ]

  @type t :: %__MODULE__{
          loc: Solid.Parser.Loc.t(),
          child_condition: {:and | :or, t | Solid.UnaryCondition.t()} | nil,
          left_argument: Argument.t(),
          left_argument_filters: [Filter.t()],
          operator: Solid.Lexer.operator(),
          right_argument: Argument.t(),
          right_argument_filters: [Filter.t()]
        }

  @spec eval({term, Solid.Lexer.operator(), term}) :: {:ok, boolean} | {:error, binary}
  def eval({v1, :==, %Empty{}}) when is_map(v1) and not is_struct(v1), do: {:ok, v1 == %{}}
  def eval({%Empty{}, :==, v2}) when is_map(v2) and not is_struct(v2), do: {:ok, v2 == %{}}

  def eval({v1, :==, %Empty{}}) when is_list(v1), do: {:ok, v1 == []}
  def eval({%Empty{}, :==, v2}) when is_list(v2), do: {:ok, v2 == []}

  def eval({v1, _, %Empty{}}) when is_map(v1) and not is_struct(v1), do: {:ok, false}
  def eval({%Empty{}, _, v2}) when is_map(v2) and not is_struct(v2), do: {:ok, false}

  def eval({v1, _, v2})
      when (is_map(v1) or is_map(v2)) and not is_struct(v1) and not is_struct(v2),
      do: {:ok, false}

  def eval({nil, :contains, _v2}), do: {:ok, false}
  def eval({_v1, :contains, nil}), do: {:ok, false}
  def eval({v1, :contains, v2}) when is_list(v1), do: {:ok, v2 in v1}

  def eval({v1, :contains, v2}) when is_binary(v1) and is_binary(v2),
    do: {:ok, String.contains?(v1, v2)}

  def eval({v1, :contains, v2}) when is_binary(v1), do: {:ok, String.contains?(v1, to_string(v2))}

  def eval({_v1, :contains, _v2}), do: {:ok, false}

  def eval({v1, :<=, nil}) when is_number(v1), do: {:ok, false}
  def eval({v1, :<, nil}) when is_number(v1), do: {:ok, false}
  def eval({nil, :>=, v2}) when is_number(v2), do: {:ok, false}
  def eval({nil, :>, v2}) when is_number(v2), do: {:ok, false}

  def eval({v1, op, v2})
      when op in ~w(< <= > >=)a and is_binary(v1) and is_integer(v2) do
    {:error, "comparison of String with #{v2} failed"}
  end

  def eval({v1, op, v2})
      when op in ~w(< <= > >=)a and is_integer(v1) and is_binary(v2) do
    {:error, "comparison of Integer with String failed"}
  end

  def eval({v1, op, v2})
      when op in ~w(< <= > >=)a and is_float(v1) and is_binary(v2) do
    {:error, "comparison of Float with String failed"}
  end

  def eval({v1, :<>, v2}), do: {:ok, apply(Kernel, :!=, [v1, v2])}
  def eval({v1, op, v2}), do: {:ok, apply(Kernel, op, [v1, v2])}
end
