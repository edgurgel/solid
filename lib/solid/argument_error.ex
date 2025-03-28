defmodule Solid.ArgumentError do
  @type t :: %__MODULE__{}
  defexception [:message, :loc]

  @impl true
  def message(exception) do
    "Liquid error (line #{exception.loc.line}): #{exception.message}"
  end
end
