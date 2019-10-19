ExUnit.start()

defmodule Solid.Helpers do
  def render(text, hash \\ %{}) do
    case Solid.parse(text) do
      {:ok, template} ->
        template
        |> Solid.render(hash)
        |> to_string()

      {:error, error} ->
        inspect(error)
    end
  end

  def liquid_render(input_liquid, input_json) do
    System.cmd("ruby", ["test/liquid.rb", input_liquid, input_json])
  end
end
