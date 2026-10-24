defmodule Solid.MatcherNotImplementedError do
  @type t :: %__MODULE__{}
  defexception [:struct, :variable, :loc]

  @impl true
  def message(exception) do
    line = exception.loc.line
    reason = "Protocol Solid.Matcher not implemented for #{inspect(exception.struct)}"
    "#{line}: #{reason}"
  end
end
