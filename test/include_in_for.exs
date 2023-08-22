defmodule IncludeInForTest do
  use ExUnit.Case, async: true

  defmodule Test.SolidFileSystem do
    @behaviour Solid.FileSystem

    @impl true
    def read_template_file("second", _opts) do
      "{{ items.size }}"
    end

    def read_template_file("third", _opts) do
      ~s({% render "first", pages: pages %})
    end

    def read_template_file("fourth", _opts) do
      ~s({% render "third", pages: pages %})
    end

    def read_template_file("first", _opts) do
      ~s({% for item in pages.blocks %}{% render item.template, items: item.items %}{% endfor %})
    end
  end

  describe "render!/3" do
    test "basic render" do
      template = ~s({% render "fourth", pages: pages  %})
      parsed = Solid.parse!(template)

      context = %{
        "pages" => %{
          "blocks" => [
            %{
              "template" => "second",
              "items" => [0, 1, 2]
            }
          ]
        }
      }

      assert Solid.render!(parsed, context, file_system: {Test.SolidFileSystem, nil})
             |> to_string() ==
               "3"
    end
  end
end
