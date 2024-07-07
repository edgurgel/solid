defmodule Solid.Tag.EchoTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Echo
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Echo.spec(__MODULE__) |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = "{% echo 'abc' | upcase %}" |> Parser.parse()

    context = %Context{}

    assert {[text: "ABC"], ^context} = Echo.render(parsed, context, [])
  end
end
