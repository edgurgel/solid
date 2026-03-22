defmodule Solid.Integration.LinesTest do
  use ExUnit.Case, async: true

  @tags Solid.Tag.default_tags()
        |> Map.put("current_line", CustomTags.CurrentLine)

  defmodule TestFileSystem do
    @behaviour Solid.FileSystem

    @impl true
    def read_template_file("current_line", _opts) do
      {:ok, "{% current_line %}"}
    end
  end

  defp render(template, options \\ []) do
    template
    |> Solid.parse!(tags: @tags)
    |> Solid.render!(%{}, options)
    |> IO.iodata_to_binary()
  end

  describe "line number processing" do
    test "text" do
      template = """
      text
      {% current_line %}
      text
      """

      assert render(template) ==
               """
               text
               2
               text
               """
    end

    test "comment" do
      template = """
      {% comment %} {% assign x = 1 %} {% endcomment -%}
      {% current_line %}
      """

      assert render(template) ==
               """
               2
               """
    end

    test "raw" do
      template = """
      {% raw %}{% assign x = 1 %}{% endraw %}
      {% current_line %}
      """

      assert render(template) ==
               """
               {% assign x = 1 %}
               2
               """
    end

    test "render tag with current_line" do
      template = """
      text
      {% render "current_line" %}
      text
      """

      options = [file_system: {TestFileSystem, nil}]

      assert render(template, options) ==
               """
               text
               1
               text
               """
    end
  end
end
