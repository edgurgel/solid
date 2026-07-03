defmodule Solid.RenderDepthError do
  @type t :: %__MODULE__{max_depth: pos_integer, template: String.t()}
  defexception [:max_depth, :template]

  @impl true
  def message(%__MODULE__{max_depth: max_depth, template: template}) do
    "Maximum render depth of #{max_depth} exceeded while rendering '#{template}'"
  end
end
