ExUnit.start()

defmodule Solid.Helpers do
  def render(text, hash \\ %{}) do
    Solid.parse(text) |> elem(1) |> Solid.render(hash) |> to_string
  end

  def liquid_render(input_liquid, input_json) do
    System.cmd("ruby", ["test/liquid.rb", input_liquid, input_json])
  end
end
