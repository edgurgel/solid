defmodule Solid.UndefinedVariableError do
  @type t :: %__MODULE__{}
  defexception [:variable, :original_name, :loc]

  @impl true
  def message(exception) do
    line = exception.loc.line
    reason = "Undefined variable #{exception.original_name}"
    "#{line}: #{reason}"
  end
end
