defmodule WhitespaceTrimHelper do
  defmacro test_permutations(name, json \\ "{}", do: input) do
    sanitized_name = name |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join()
    module_name = Module.concat([Solid.Integration.WhitespaceTrimCase, :"#{sanitized_name}Test"])

    quote do
      defmodule unquote(module_name) do
        use ExUnit.Case, async: true
        import Solid.Helpers
        import WhitespaceTrimHelper
        @moduletag :integration

        for {variant, counter} <- Enum.with_index(generate_permutations(unquote(input))) do
          @tag variant_nr: counter, variant: variant
          test "#{unquote(sanitized_name)}: #{counter}", %{variant: variant} do
            assert_render(variant, unquote(json), nil)
          end
        end
      end
    end
  end

  @tags ["{{", "}}", "{%", "%}"]

  def generate_permutations(template) do
    input =
      build_regex()
      |> Regex.split(template)

    versions =
      input
      |> find_tag_indexes()
      |> build_versions(input)

    (versions ++ [build_complete_version(input), input])
    |> Enum.map(&List.to_string/1)
  end

  defp build_regex do
    tags_or = Enum.join(@tags, "|")
    ~r/(?=(#{tags_or}))|(?<=(#{tags_or}))/
  end

  defp find_tag_indexes(list) do
    list
    |> Enum.with_index()
    |> Enum.filter(fn {item, _i} -> Enum.member?(@tags, item) end)
    |> Enum.map(fn {_item, i} -> i end)
  end

  defp build_versions(indexes, input) do
    Enum.map(indexes, fn i ->
      new_item =
        input
        |> Enum.at(i)
        |> to_trimming()

      List.replace_at(input, i, new_item)
    end)
  end

  defp build_complete_version(input) do
    Enum.map(input, fn item ->
      if Enum.member?(@tags, item) do
        to_trimming(item)
      else
        item
      end
    end)
  end

  defp to_trimming("{{"), do: "{{-"
  defp to_trimming("}}"), do: "-}}"
  defp to_trimming("{%"), do: "{%-"
  defp to_trimming("%}"), do: "-%}"
end
