defmodule Solid.Tags.RenderTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.RenderTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defmodule TestFileSystem do
    @behaviour Solid.FileSystem

    @impl true
    def read_template_file("second", _opts) do
      {:ok, "hello there"}
    end

    def read_template_file("broken", _opts) do
      {:ok, "{% {{"}
    end

    def read_template_file("vars", _opts) do
      {:ok, "{{ var1[1] }} {{ var2 }}"}
    end

    def read_template_file("with_var", _opts) do
      {:ok, "{{ with_var['key'] }}"}
    end

    def read_template_file("item_file", _opts) do
      {:ok, "{{ item['key'] }}"}
    end

    def read_template_file("forloop", _opts) do
      {:ok,
       "{{forloop.key}}{{ forloop.index }}{{ forloop.rindex }}{{ forloop.first }}{{ forloop.last }}{{ forloop.length }}"}
    end
  end

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "render", context} <- Lexer.tokenize_tag_start(context) do
      RenderTag.parse("render", %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "simple" do
      template = ~s<{% render "file1" %}>

      assert parse(template) ==
               {:ok, %RenderTag{loc: %Loc{line: 1, column: 1}, template: "file1", arguments: %{}},
                %ParserContext{rest: "", line: 1, column: 21, mode: :normal}}
    end

    test "arguments" do
      template = ~s<{% render "file1", var1: arg1, var2: 2 %}>

      assert parse(template) ==
               {:ok,
                %RenderTag{
                  loc: %Loc{line: 1, column: 1},
                  template: "file1",
                  arguments: %{
                    "var1" => %Solid.Variable{
                      original_name: "arg1",
                      loc: %Loc{column: 26, line: 1},
                      identifier: "arg1",
                      accesses: []
                    },
                    "var2" => %Solid.Literal{
                      loc: %Loc{column: 38, line: 1},
                      value: 2
                    }
                  }
                }, %ParserContext{rest: "", line: 1, column: 42, mode: :normal}}
    end

    test "arguments no initial comma" do
      template = "{% render 'inner_object' key: value, title: 'text' %}"

      assert {:ok,
              %Solid.Tags.RenderTag{
                template: "inner_object",
                arguments: %{
                  "key" => %Solid.Variable{identifier: "value"},
                  "title" => %Solid.Literal{value: "text"}
                }
              },
              %Solid.ParserContext{rest: "", line: 1, column: 54, mode: :normal, tags: nil}} =
               parse(template)
    end

    test "with arguments" do
      template = ~s<{% render "file1" with products[0] %}>

      assert parse(template) ==
               {:ok,
                %RenderTag{
                  loc: %Loc{line: 1, column: 1},
                  template: "file1",
                  arguments:
                    {:with,
                     {%Solid.Variable{
                        original_name: "products[0]",
                        loc: %Loc{column: 24, line: 1},
                        identifier: "products",
                        accesses: [
                          %Solid.AccessLiteral{
                            loc: %Loc{column: 33, line: 1},
                            value: 0
                          }
                        ]
                      }, "file1"}}
                }, %ParserContext{rest: "", line: 1, column: 38, mode: :normal}}
    end

    test "with-as arguments" do
      template = ~s<{% render "file1" with products[0] as product %}>

      assert parse(template) ==
               {:ok,
                %RenderTag{
                  loc: %Loc{line: 1, column: 1},
                  template: "file1",
                  arguments:
                    {:with,
                     {%Solid.Variable{
                        original_name: "products[0]",
                        loc: %Loc{column: 24, line: 1},
                        identifier: "products",
                        accesses: [
                          %Solid.AccessLiteral{
                            loc: %Loc{column: 33, line: 1},
                            value: 0
                          }
                        ]
                      }, "product"}}
                }, %ParserContext{rest: "", line: 1, column: 49, mode: :normal}}
    end

    test "for arguments" do
      template = ~s<{% render "file1" for products[0] %}>

      assert parse(template) ==
               {
                 :ok,
                 %RenderTag{
                   loc: %Loc{column: 1, line: 1},
                   arguments: {
                     :for,
                     {
                       %Solid.Variable{
                         original_name: "products[0]",
                         accesses: [
                           %Solid.AccessLiteral{
                             loc: %Loc{column: 32, line: 1},
                             value: 0
                           }
                         ],
                         identifier: "products",
                         loc: %Loc{column: 23, line: 1}
                       },
                       "file1"
                     }
                   },
                   template: "file1"
                 },
                 %ParserContext{
                   column: 37,
                   line: 1,
                   mode: :normal,
                   rest: ""
                 }
               }
    end

    test "for-as arguments" do
      template = ~s<{% render "file1" for products[0] as product %}>

      assert parse(template) ==
               {
                 :ok,
                 %RenderTag{
                   arguments: {
                     :for,
                     {
                       %Solid.Variable{
                         original_name: "products[0]",
                         accesses: [
                           %Solid.AccessLiteral{
                             loc: %Loc{column: 32, line: 1},
                             value: 0
                           }
                         ],
                         identifier: "products",
                         loc: %Loc{column: 23, line: 1}
                       },
                       "product"
                     }
                   },
                   loc: %Loc{column: 1, line: 1},
                   template: "file1"
                 },
                 %ParserContext{column: 48, line: 1, mode: :normal, rest: ""}
               }
    end

    test "wrong args" do
      template = ~s<{% render "file1" in files %}>

      assert parse(template) ==
               {:error, "Expected arguments, 'with' or 'for'", %{column: 19, line: 1}}
    end
  end

  describe "Renderable impl" do
    test "renders basic file" do
      template = ~s<{% render "second" %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) == {[["hello there"]], context}
    end

    test "renders variables" do
      template = ~s<{% render "vars", var1: array, var2: "value2" %}>
      context = %Solid.Context{vars: %{"array" => [1, 2]}}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) == {[["2", " ", "value2"]], context}
    end

    test "renders with" do
      template = ~s<{% render "with_var" with array[1]  %}>
      context = %Solid.Context{vars: %{"array" => [%{"key" => "value1"}, %{"key" => "value2"}]}}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) == {[["value2"]], context}
    end

    test "renders with as" do
      template = ~s<{% render "item_file" with array[1] as item  %}>
      context = %Solid.Context{vars: %{"array" => [%{"key" => "value1"}, %{"key" => "value2"}]}}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) == {[["value2"]], context}
    end

    test "renders for using a list" do
      template = ~s<{% render "with_var" for array  %}>
      context = %Solid.Context{vars: %{"array" => [%{"key" => "value1"}, %{"key" => "value2"}]}}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) ==
               {[["value1"], ["value2"]], context}
    end

    test "renders for using a list as" do
      template = ~s<{% render "item_file" for array as item  %}>
      context = %Solid.Context{vars: %{"array" => [%{"key" => "value1"}, %{"key" => "value2"}]}}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) ==
               {[["value1"], ["value2"]], context}
    end

    test "renders for using a single item" do
      template = ~s<{% render "with_var" for array[1] %}>
      context = %Solid.Context{vars: %{"array" => [%{"key" => "value1"}, %{"key" => "value2"}]}}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) == {[["value2"]], context}
    end

    test "renders for + forloop" do
      template = ~s<{% render "forloop" for array  %}>
      context = %Solid.Context{vars: %{"array" => [%{"key" => "value1"}, %{"key" => "value2"}]}}

      {:ok, tag, _rest} = parse(template)
      options = [file_system: {TestFileSystem, nil}]

      assert Solid.Renderable.render(tag, context, options) ==
               {[
                  ["value1", "1", "2", "true", "false", "2"],
                  ["value2", "2", "1", "false", "true", "2"]
                ], context}
    end
  end
end
