defmodule Solid.Tag.RawTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Raw
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Raw.spec(__MODULE__) |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} =
      "{% raw %} {{liquid}} {% increment counter %} {% endraw %}" |> Parser.parse()

    assert {[text: ~c" {{liquid}} {% increment counter %} "], %Context{}} ==
             Raw.render(parsed, %Context{}, [])
  end
end
