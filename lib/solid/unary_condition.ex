defmodule Solid.UnaryCondition do
  defstruct [:loc, :child_condition, :argument, argument_filters: []]

  @type t :: %__MODULE__{
          loc: Solid.Parser.Loc.t(),
          argument: Solid.Argument.t(),
          argument_filters: [Solid.Filter.t()],
          child_condition: {:and | :or, t | Solid.BinaryCondition.t()}
        }

  def eval(value) do
    if value do
      true
    else
      false
    end
  end
end
