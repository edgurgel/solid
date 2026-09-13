defmodule Solid.RenderCountError do
  @type t :: %__MODULE__{max_count: pos_integer, template: String.t(), loc: Solid.Parser.Loc.t()}
  defexception [:max_count, :template, :loc]

  @impl true
  def message(%__MODULE__{max_count: max_count, template: template}) do
    "Maximum of #{max_count} rendered partials exceeded while rendering '#{template}'"
  end
end
