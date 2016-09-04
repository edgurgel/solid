ExUnit.start()

defmodule Solid.Helpers do
  def render(text, hash \\ %{}) do
    Solid.parse(text) |> Solid.render(hash) |> to_string
  end
end
