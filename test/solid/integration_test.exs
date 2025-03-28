scenarios_dir = "test/solid/integration/scenarios"

for scenario <- File.ls!(scenarios_dir) do
  module_name = Module.concat([Solid.Integration.Scenarios, :"#{scenario}Test"])

  defmodule module_name do
    use ExUnit.Case, async: true
    import Solid.Helpers
    @moduletag :integration

    @liquid_input_file "#{scenarios_dir}/#{scenario}/input.liquid"
    @json_input_file "#{scenarios_dir}/#{scenario}/input.json"
    @template_directory "#{scenarios_dir}/#{scenario}"
    @external_resource @liquid_input_file
    @external_resource @json_input_file

    @tag scenario: scenario
    test "scenario #{scenario}" do
      liquid_input = File.read!(@liquid_input_file)
      json_input = File.read!(@json_input_file)
      opts = [custom_filters: Solid.CustomFilters]
      assert_render(liquid_input, json_input, @template_directory, opts)
    end
  end
end
