defmodule SolidTest do
  use ExUnit.Case, async: true
  doctest Solid

  describe "render!/3" do
    test "basic render" do
      template = "var1: {{ var1 }}"

      assert template
             |> Solid.parse!()
             |> Solid.render!(%{"var1" => "value1"})
             |> IO.iodata_to_binary() == "var1: value1"
    end

    test "strict_variables" do
      template = "var1: {{ var1 }}"

      try do
        template
        |> Solid.parse!()
        |> Solid.render!(%{}, strict_variables: true)
      rescue
        e in Solid.RenderError ->
          assert IO.iodata_to_binary(e.result) == "var1: "
          assert e.errors == [%Solid.UndefinedVariableError{variable: ["var1"]}]
      end
    end
  end

  describe "render/3" do
    test "basic render" do
      template = "var1: {{ var1 }}"

      assert {:ok, result} =
               template
               |> Solid.parse!()
               |> Solid.render(%{"var1" => "value1"})

      assert IO.iodata_to_binary(result) == "var1: value1"
    end

    test "strict_variables" do
      template = "var1: {{ var1 }}"

      assert {:error, errors, result} =
               template
               |> Solid.parse!()
               |> Solid.render(%{}, strict_variables: true)

      assert IO.iodata_to_binary(result) == "var1: "
      assert errors == [%Solid.UndefinedVariableError{variable: ["var1"]}]
    end
  end
end
