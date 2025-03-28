defmodule Solid.UndefinedVariableError do
  @type t :: %__MODULE__{}
  defexception [:variable, :loc]

  @impl true
  def message(exception) do
    line = exception.loc.line
    reason = "Undefined variable #{exception.variable}"
    "#{line}: #{reason}"
  end
end
