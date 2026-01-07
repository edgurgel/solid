defmodule Solid.UndefinedFilterError do
  @type t :: %__MODULE__{}
  defexception [:filter, :loc]

  @impl true
  def message(exception) do
    line = exception.loc.line
    reason = "Undefined filter #{exception.filter}"
    "#{line}: #{reason}"
  end
end
