defmodule Solid.UndefinedVariableError do
  @type t :: %__MODULE__{}
  defexception [:variable, :loc]

  @impl true
  def message(exception) do
    variable = exception.variable

    variable_name =
      if is_list(variable) do
        Enum.join(variable, ".")
      else
        variable
      end

    line = exception.loc.line
    reason = "Undefined variable #{variable_name}"
    "#{line}: #{reason}"
  end
end
