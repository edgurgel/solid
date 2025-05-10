defmodule Solid.LexerTest do
  use ExUnit.Case, async: true
  alias Solid.Lexer
  alias Solid.ParserContext

  defp build_context(text, mode \\ :normal) do
    %ParserContext{rest: text, line: 1, column: 1, mode: mode}
  end

  describe "tokenize_tag_start/3" do
    test "special inline comment tag name" do
      context = ~s<{% #### inline comment %}> |> build_context()

      assert {
               :ok,
               "#",
               %ParserContext{
                 column: 5,
                 line: 1,
                 mode: :normal,
                 rest: "### inline comment %}",
                 tags: nil
               }
             } == Lexer.tokenize_tag_start(context)
    end

    test "simple tag" do
      context = ~s<{% echo "I am a tag" | upcase %}> |> build_context()

      assert {:ok, "echo",
              %ParserContext{
                column: 8,
                line: 1,
                mode: :normal,
                rest: " \"I am a tag\" | upcase %}"
              }} == Lexer.tokenize_tag_start(context)
    end

    test "liquid tag" do
      context =
        """
        {% liquid
        echo abc
        echo yolo
        %}
        """
        |> build_context()

      assert {
               :liquid_tag,
               %ParserContext{
                 rest: "\necho abc\necho yolo\n%}\n",
                 line: 1,
                 column: 10,
                 mode: :normal
               }
             } == Lexer.tokenize_tag_start(context)
    end

    test "not a tag" do
      context = ~s<{{ yo }}> |> build_context()

      assert Lexer.tokenize_tag_start(context) == {:error, :not_found}
    end

    test "missing tag name" do
      context = ~s<{%  %}> |> build_context()

      assert Lexer.tokenize_tag_start(context) ==
               {:error, "Empty tag name", "%}", %{line: 1, column: 5}}
    end

    test "missing ws tag name" do
      context = ~s<{%-  -%}> |> build_context()

      assert Lexer.tokenize_tag_start(context) ==
               {:error, "Empty tag name", "-%}", %{line: 1, column: 6}}
    end
  end

  describe "tokenize_tag_start/3 liquid tags" do
    test "parse tag per line" do
      context =
        """
        echo abc
        echo yolo
        %}
        """
        |> build_context(:liquid_tag)

      assert {
               :ok,
               "echo",
               %ParserContext{
                 column: 5,
                 line: 1,
                 mode: :liquid_tag,
                 rest: " abc\necho yolo\n%}\n"
               }
             } == Lexer.tokenize_tag_start(context)
    end

    test "parse inline comment" do
      context =
        """
        ### inline comment
        %}
        """
        |> build_context(:liquid_tag)

      assert {
               :ok,
               "#",
               %ParserContext{
                 column: 2,
                 line: 1,
                 mode: :liquid_tag,
                 rest: "## inline comment\n%}\n",
                 tags: nil
               }
             } == Lexer.tokenize_tag_start(context)
    end

    test "end of liquid tag" do
      context =
        """
        %}
        """
        |> build_context(:liquid_tag)

      assert {:end_liquid_tag, %ParserContext{rest: "\n", line: 1, column: 3, mode: :normal}} ==
               Lexer.tokenize_tag_start(context)
    end
  end

  describe "tokenize_tag_start/3 with allowed tag names" do
    test "expected tag" do
      context = ~s<{% echo "I am a tag" | upcase %}> |> build_context

      assert {:ok, "echo",
              %ParserContext{
                column: 8,
                line: 1,
                mode: :normal,
                rest: " \"I am a tag\" | upcase %}"
              }} =
               Lexer.tokenize_tag_start(context, allowed_tag_names: ["echo"])
    end

    test "unexpected tag" do
      context = ~s<{% echo "I am a tag" | upcase %}> |> build_context

      assert Lexer.tokenize_tag_start(context, allowed_tag_names: ["capture"]) ==
               {:error, :not_expected_tag}
    end

    test "missing tag name" do
      context = ~s<{%  %}> |> build_context()

      assert Lexer.tokenize_tag_start(context, allowed_tag_names: ["capture"]) ==
               {:error, "Empty tag name", "%}", %{line: 1, column: 5}}
    end

    test "missing ws tag name" do
      context = ~s<{%-  -%}> |> build_context()

      assert Lexer.tokenize_tag_start(context, allowed_tag_names: ["capture"]) ==
               {:error, "Empty tag name", "-%}", %{line: 1, column: 6}}
    end
  end

  describe "tokenize_tag/3" do
    test "simple tag" do
      context = ~s<{% echo "I am a tag" | upcase %}> |> build_context()

      assert {:ok, "echo",
              [
                {:string, %{line: 1, column: 9}, "I am a tag", ?"},
                {:pipe, %{line: 1, column: 22}},
                {:identifier, %{line: 1, column: 24}, "upcase"},
                {:end, %{line: 1, column: 31}}
              ],
              %ParserContext{
                column: 33,
                line: 1,
                mode: :normal,
                rest: ""
              }} == Lexer.tokenize_tag(context)
    end

    test "tag not terminated properly" do
      context = ~s<{% echo "I am a tag" | upcase}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:error, "Unexpected character '}'", "}", %{line: 1, column: 30}}
    end

    test "tag terminated as object" do
      context = ~s<{% echo "I am a tag" | upcase}}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {
                 :error,
                 "Tag not properly terminated",
                 "}}",
                 %{column: 30, line: 1}
               }
    end

    test "missing tag name" do
      context = ~s<{%  %}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:error, "Empty tag name", "%}", %{line: 1, column: 5}}
    end

    test "missing ws tag name" do
      context = ~s<{%-  -%}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:error, "Empty tag name", "-%}", %{line: 1, column: 6}}
    end
  end

  describe "tokenize_tag/3 with allowed tag names" do
    test "expected tag" do
      context = ~s<{% echo "I am a tag" | upcase %}> |> build_context

      assert {:ok, "echo",
              [
                {:string, %{line: 1, column: 9}, "I am a tag", ?"},
                {:pipe, %{line: 1, column: 22}},
                {:identifier, %{line: 1, column: 24}, "upcase"},
                {:end, %{line: 1, column: 31}}
              ],
              %ParserContext{rest: "", line: 1, column: 33, mode: :normal}} =
               Lexer.tokenize_tag(context, allowed_tag_names: ["echo"])
    end

    test "unexpected tag" do
      context = ~s<{% echo "I am a tag" | upcase %}> |> build_context

      assert Lexer.tokenize_tag(context, allowed_tag_names: ["capture"]) ==
               {:error, :not_expected_tag}
    end

    test "tag not terminated properly" do
      context = ~s<{% echo "I am a tag" | upcase}> |> build_context

      assert Lexer.tokenize_tag(context, allowed_tag_names: ["echo"]) ==
               {:error, "Unexpected character '}'", "}", %{line: 1, column: 30}}
    end
  end

  describe "tokenize_tag/3 liquid tag" do
    test "simple tag" do
      context =
        """
        echo abc
        echo yolo
        %}
        """
        |> build_context(:liquid_tag)

      assert {
               :ok,
               "echo",
               [
                 {:identifier, %{column: 6, line: 1}, "abc"},
                 {:end, %{column: 9, line: 1}}
               ],
               context
             } = Lexer.tokenize_tag(context)

      assert {
               :ok,
               "echo",
               [
                 {:identifier, %{column: 6, line: 2}, "yolo"},
                 {:end, %{column: 10, line: 2}}
               ],
               context
             } = Lexer.tokenize_tag(context)

      assert {:end_liquid_tag, %ParserContext{rest: "\n", line: 3, column: 3}} =
               Lexer.tokenize_tag(context)
    end

    test "broken tag" do
      context =
        """
        {% this should not be here %}
        echo yolo
        %}
        """
        |> build_context(:liquid_tag)

      assert {
               :ok,
               "{%",
               [
                 {:identifier, %{column: 4, line: 1}, "this"},
                 {:identifier, %{column: 9, line: 1}, "should"},
                 {:identifier, %{column: 16, line: 1}, "not"},
                 {:identifier, %{column: 20, line: 1}, "be"},
                 {:identifier, %{column: 23, line: 1}, "here"},
                 {:end, %{column: 28, line: 1}}
               ],
               %ParserContext{rest: "%}\necho yolo\n%}\n", line: 1, column: 28, mode: :liquid_tag}
             } = Lexer.tokenize_tag(context)
    end
  end

  describe "tokenize_object/1" do
    test "errors" do
      context = "{{ - }}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:error, "Unexpected character '-'", "- }}", %{line: 1, column: 4}}
    end

    test "identifiers" do
      context = "{{abc efg? a123 a-_b?}}" |> build_context()

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:identifier, %{column: 3, line: 1}, "abc"},
                 {:identifier, %{column: 7, line: 1}, "efg?"},
                 {:identifier, %{line: 1, column: 12}, "a123"},
                 {:identifier, %{line: 1, column: 17}, "a-_b?"},
                 {:end, %{line: 1, column: 22}}
               ],
               %ParserContext{rest: "", line: 1, column: 24, mode: :normal}
             }
    end

    test "object not properly terminated" do
      context = ~s<{{"string"%}> |> build_context()

      assert Lexer.tokenize_object(context) ==
               {
                 :error,
                 "Object not properly terminated",
                 "%}",
                 %{line: 1, column: 11}
               }
    end

    test "double quoted string" do
      context = ~s<{{"string"}}> |> build_context

      assert Lexer.tokenize_object(context) ==
               {:ok,
                [{:string, %{column: 3, line: 1}, "string", ?"}, {:end, %{line: 1, column: 11}}],
                %ParserContext{rest: "", line: 1, column: 13, mode: :normal}}
    end

    test "double quoted string with new line" do
      context = ~s<{{"string\n"}}> |> build_context

      assert Lexer.tokenize_object(context) ==
               {
                 :ok,
                 [
                   {:string, %{column: 3, line: 1}, "string\n", ?"},
                   {:end, %{column: 11, line: 2}}
                 ],
                 %Solid.ParserContext{
                   column: 13,
                   line: 2,
                   mode: :normal,
                   rest: "",
                   tags: nil
                 }
               }
    end

    test "single quoted string" do
      context = "{{'string' }}" |> build_context

      assert Lexer.tokenize_object(context) ==
               {:ok,
                [{:string, %{column: 3, line: 1}, "string", ?'}, {:end, %{line: 1, column: 12}}],
                %ParserContext{rest: "", line: 1, column: 14, mode: :normal}}
    end

    test "string not terminated" do
      context = "{{\"string'" |> build_context

      assert Lexer.tokenize_object(context) == {
               :error,
               "String with \" not terminated",
               "\"string'",
               %{line: 1, column: 3}
             }
    end

    test "comparison operators" do
      context = "{{<= == != >= <> < > contains }}" |> build_context

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:comparison, %{column: 3, line: 1}, :<=},
                 {:comparison, %{column: 6, line: 1}, :==},
                 {:comparison, %{column: 9, line: 1}, :!=},
                 {:comparison, %{column: 12, line: 1}, :>=},
                 {:comparison, %{column: 15, line: 1}, :<>},
                 {:comparison, %{column: 18, line: 1}, :<},
                 {:comparison, %{column: 20, line: 1}, :>},
                 {:comparison, %{column: 22, line: 1}, :contains},
                 {:end, %{column: 31, line: 1}}
               ],
               %ParserContext{rest: "", line: 1, column: 33, mode: :normal}
             }
    end

    test "specials" do
      context = "{{. | [ ] : , }}" |> build_context

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 dot: %{column: 3, line: 1},
                 pipe: %{column: 5, line: 1},
                 open_square: %{column: 7, line: 1},
                 close_square: %{column: 9, line: 1},
                 colon: %{column: 11, line: 1},
                 comma: %{column: 13, line: 1},
                 end: %{column: 15, line: 1}
               ],
               %ParserContext{rest: "", line: 1, column: 17, mode: :normal}
             }
    end

    test "integer" do
      context = "{{ 123 456 }}" |> build_context

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:integer, %{column: 4, line: 1}, 123},
                 {:integer, %{column: 8, line: 1}, 456},
                 {:end, %{column: 12, line: 1}}
               ],
               %ParserContext{rest: "", line: 1, column: 14, mode: :normal}
             }
    end

    test "float" do
      context = "{{ 123.5 }}" |> build_context

      assert Lexer.tokenize_object(context) ==
               {:ok,
                [
                  {:float, %{column: 4, line: 1}, 123.5},
                  {:end, %{column: 10, line: 1}}
                ], %ParserContext{rest: "", line: 1, column: 12, mode: :normal}}
    end

    test "number and a dot" do
      context = "{{ 123. }}" |> build_context

      assert Lexer.tokenize_object(context) ==
               {
                 :ok,
                 [
                   {:integer, %{column: 4, line: 1}, 123},
                   {:dot, %{column: 7, line: 1}},
                   {:end, %{column: 9, line: 1}}
                 ],
                 %ParserContext{rest: "", line: 1, column: 11, mode: :normal}
               }
    end

    test "complex input" do
      context = ~s<{{ my_string | replace_last: "cde", 'fgh' }}> |> build_context

      assert Lexer.tokenize_object(context) ==
               {
                 :ok,
                 [
                   {:identifier, %{column: 4, line: 1}, "my_string"},
                   {:pipe, %{column: 14, line: 1}},
                   {
                     :identifier,
                     %{column: 16, line: 1},
                     "replace_last"
                   },
                   {:colon, %{column: 28, line: 1}},
                   {:string, %{column: 30, line: 1}, "cde", ?"},
                   {:comma, %{column: 35, line: 1}},
                   {:string, %{column: 37, line: 1}, "fgh", ?'},
                   {:end, %{column: 43, line: 1}}
                 ],
                 %ParserContext{rest: "", line: 1, column: 45, mode: :normal}
               }
    end
  end
end
