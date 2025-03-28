defmodule Solid.Filter do
  @enforce_keys [:loc, :function, :positional_arguments, :named_arguments]
  defstruct [:loc, :function, :positional_arguments, :named_arguments]

  @type t :: %__MODULE__{
          loc: Solid.Parser.Loc.t(),
          function: binary,
          positional_arguments: [Solid.Argument.t()],
          named_arguments: %{binary => Solid.Argument.t()}
        }
end
