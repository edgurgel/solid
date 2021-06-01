cases_dir = "test/cases"

for test_case <- File.ls!(cases_dir) do
  module_name = Module.concat([Solid.Integration.Cases, :"#{test_case}Test"])

  defmodule module_name do
    use ExUnit.Case, async: true
    import Solid.Helpers
    @moduletag :integration

    @liquid_input_file "#{cases_dir}/#{test_case}/input.liquid"
    @json_input_file "#{cases_dir}/#{test_case}/input.json"
    @external_resource @liquid_input_file
    @external_resource @json_input_file

    @tag case: test_case
    test "case #{test_case}" do
      liquid_input = File.read!(@liquid_input_file)
      json_input = File.read!(@json_input_file)

      assert_render(liquid_input, json_input)
    end
  end
end
