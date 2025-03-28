defmodule Solid.AccessVariable do
  @enforce_keys [:loc, :variable]
  defstruct [:loc, :variable]
  @type t :: %__MODULE__{loc: Solid.Parser.Loc.t(), variable: Solid.Variable.t()}

  defimpl String.Chars do
    def to_string(access), do: Kernel.to_string(access.variable)
  end
end
