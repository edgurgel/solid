defmodule Solid.ToRubyIntegrationTest do
  use ExUnit.Case, async: false

  alias Solid.ToRuby

  @tag :integration
  test "generated hash string matches ruby's hash.to_s for basic types" do
    map = %{
      "string" => "hello",
      "integer" => 123,
      "float" => 45.6,
      "nested" => %{
        "z_key" => "value",
        "a_key" => "value"
      }
    }

    assert_string_match_in_ruby(map)
  end

  @tag :integration
  test "generated hash string matches ruby's hash.to_s for complex types" do
    map = %{
      "nil_value" => nil,
      "bool_true" => true,
      "bool_false" => false,
      "list_value" => [1, "two", %{"three" => 3}]
    }

    assert_string_match_in_ruby(map)
  end

  defp assert_string_match_in_ruby(map) do
    elixir_generated_string = ToRuby.hash(map)
    json_map = Jason.encode!(map)

    # Ruby script that parses a JSON string, sorts the resulting hash by key,
    # and then prints the hash's string representation.
    ruby_script = """
    require 'json'
    # Recursively sort keys in nested hashes
    def sort_hash(h)
      h.keys.sort.each_with_object({}) do |k, new_h|
        new_h[k] = h[k].is_a?(Hash) ? sort_hash(h[k]) : h[k]
      end
    end
    hash = JSON.parse(ARGV[0])
    sorted_hash = sort_hash(hash)
    print sorted_hash.to_s
    """

    cmd = "ruby"
    args = ["-e", ruby_script, json_map]

    case System.cmd(cmd, args) do
      {ruby_generated_string, 0} ->
        assert elixir_generated_string == ruby_generated_string

      {error_output, exit_code} ->
        flunk("Ruby script failed with exit code #{exit_code}: #{error_output}")
    end
  end
end
