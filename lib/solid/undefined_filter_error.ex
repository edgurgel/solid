defmodule Solid.UndefinedFilterError do
  @type t :: %__MODULE__{}
  defexception [:filter, :loc]

  @impl true
  def message(exception), do: "Undefined filter #{exception.filter}"
end
