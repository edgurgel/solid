defmodule Solid.Integration.CasesTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  @cases_dir "test/cases"

  @test_cases File.ls! @cases_dir
  for test_case <- @test_cases do
    for file <- File.ls! "#{@cases_dir}/#{test_case}/" do
      @external_resource "#{@cases_dir}/#{test_case}/#{file}"
    end
  end

  for test_case <- @test_cases do
    test "case #{test_case}" do
      input_liquid  = File.read!("test/cases/#{unquote(test_case)}/input.liquid")
      input_json    = File.read!("test/cases/#{unquote(test_case)}/input.json")

      solid_output       = render(input_liquid, Poison.decode!(input_json)) |> IO.iodata_to_binary
      {liquid_output, 0} = liquid_render(input_liquid, input_json)
      assert liquid_output == solid_output
    end
  end

  defp liquid_render(input_liquid, input_json) do
    System.cmd("ruby", ["test/liquid.rb", input_liquid, input_json])
  end
end
