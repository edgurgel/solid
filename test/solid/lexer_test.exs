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
              ], %ParserContext{rest: "", line: 1, column: 33, mode: :normal}} =
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

    test "identifier that contains contains" do
      context = "{{contains123}}" |> build_context

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:identifier, %{column: 3, line: 1}, "contains123"},
                 {:end, %{column: 14, line: 1}}
               ],
               %ParserContext{rest: "", line: 1, column: 16, mode: :normal}
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

  describe "tokenize_object/1 number edge cases" do
    test "negative integer" do
      context = "{{ -5 }}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok, [{:integer, %{column: 4, line: 1}, -5}, {:end, %{column: 7, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 9, mode: :normal}}
    end

    test "negative float" do
      context = "{{ -5.5 }}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok, [{:float, %{column: 4, line: 1}, -5.5}, {:end, %{column: 9, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 11, mode: :normal}}
    end

    test "negative zero" do
      context = "{{ -0 }}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok, [{:integer, %{column: 4, line: 1}, 0}, {:end, %{column: 7, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 9, mode: :normal}}
    end

    test "range dots are not swallowed by the number" do
      context = "{{ 1..5 }}" |> build_context()

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:integer, %{column: 4, line: 1}, 1},
                 {:dot, %{column: 5, line: 1}},
                 {:dot, %{column: 6, line: 1}},
                 {:integer, %{column: 7, line: 1}, 5},
                 {:end, %{column: 9, line: 1}}
               ],
               %ParserContext{rest: "", line: 1, column: 11, mode: :normal}
             }
    end

    test "integer followed by a dot and an identifier" do
      context = "{{ 5.foo }}" |> build_context()

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:integer, %{column: 4, line: 1}, 5},
                 {:dot, %{column: 5, line: 1}},
                 {:identifier, %{column: 6, line: 1}, "foo"},
                 {:end, %{column: 10, line: 1}}
               ],
               %ParserContext{rest: "", line: 1, column: 12, mode: :normal}
             }
    end

    test "float stops at the second dot" do
      context = "{{ 123.456.789 }}" |> build_context()

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:float, %{column: 4, line: 1}, 123.456},
                 {:dot, %{column: 11, line: 1}},
                 {:integer, %{column: 12, line: 1}, 789},
                 {:end, %{column: 16, line: 1}}
               ],
               %ParserContext{rest: "", line: 1, column: 18, mode: :normal}
             }
    end

    test "a lone dash after a number is unexpected" do
      context = "{{ 5- }}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:error, "Unexpected character '-'", "- }}", %{line: 1, column: 5}}
    end

    test "a number directly before a whitespace-control close" do
      context = "{{ 5-}}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok, [{:integer, %{column: 4, line: 1}, 5}, {:end, %{column: 5, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 8, mode: :normal}}
    end
  end

  describe "tokenize_object/1 identifier edge cases" do
    test "a question mark ends the identifier mid-word" do
      context = "{{ a?b }}" |> build_context()

      assert Lexer.tokenize_object(context) == {
               :ok,
               [
                 {:identifier, %{column: 4, line: 1}, "a?"},
                 {:identifier, %{column: 6, line: 1}, "b"},
                 {:end, %{column: 8, line: 1}}
               ],
               %ParserContext{rest: "", line: 1, column: 10, mode: :normal}
             }
    end

    test "a trailing dash belongs to the whitespace control, not the identifier" do
      context = "{{ foo-}}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok, [{:identifier, %{column: 4, line: 1}, "foo"}, {:end, %{column: 7, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 10, mode: :normal}}
    end

    test "a unicode letter is not a valid identifier byte" do
      context = "{{ café }}" |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:error, "Unexpected character 'é'", "é }}", %{line: 1, column: 7}}
    end
  end

  describe "tokenize_object/1 string edge cases" do
    test "the other quote character is kept verbatim inside the string" do
      context = ~s<{{ "it's" }}> |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok,
                [{:string, %{column: 4, line: 1}, "it's", ?"}, {:end, %{column: 11, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 13, mode: :normal}}
    end

    test "empty string" do
      context = ~s<{{ '' }}> |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok, [{:string, %{column: 4, line: 1}, "", ?'}, {:end, %{column: 7, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 9, mode: :normal}}
    end

    test "multibyte content is sliced out unchanged (columns are byte-based)" do
      context = ~s<{{ "café" }}> |> build_context()

      assert Lexer.tokenize_object(context) ==
               {:ok,
                [{:string, %{column: 4, line: 1}, "café", ?"}, {:end, %{column: 12, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 14, mode: :normal}}
    end
  end

  describe "tokenize_tag/3 tag name edge cases" do
    test "tag name terminated directly by an object close" do
      context = ~s<{% foo}}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:error, "Tag not properly terminated", "}}", %{line: 1, column: 7}}
    end

    test "tag name terminated directly by a whitespace-control tag close" do
      context = ~s<{% foo-%}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:ok, "foo", [{:end, %{column: 7, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 10, mode: :normal}}
    end

    test "tag name terminated directly by a whitespace-control object close is an error" do
      context = ~s<{% foo-}}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:error, "Tag not properly terminated", "-}}", %{line: 1, column: 7}}
    end

    test "a tab terminates the tag name" do
      context = "{%\tfoo\t%}" |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:ok, "foo", [{:end, %{column: 8, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 10, mode: :normal}}
    end

    test "multibyte tag name is sliced out unchanged" do
      context = ~s<{% café bar %}> |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:ok, "café",
                [
                  {:identifier, %{column: 10, line: 1}, "bar"},
                  {:end, %{column: 14, line: 1}}
                ], %ParserContext{rest: "", line: 1, column: 16, mode: :normal}}
    end

    test "a unicode whitespace (non-breaking space) is not a tag name terminator" do
      context = "{% foo bar %}" |> build_context()

      assert Lexer.tokenize_tag(context) ==
               {:ok, "foo bar", [{:end, %{column: 13, line: 1}}],
                %ParserContext{rest: "", line: 1, column: 15, mode: :normal}}
    end
  end

  describe "tokenize_tag_start/3 liquid tag name edge cases" do
    test "liquid tag name terminated directly by the tag close" do
      context = "echo%}\n" |> build_context(:liquid_tag)

      assert Lexer.tokenize_tag_start(context) ==
               {:ok, "echo", %ParserContext{rest: "%}\n", line: 1, column: 5, mode: :liquid_tag}}
    end

    test "a unicode whitespace does not end a liquid sub-tag" do
      context = "echo abc\n%}" |> build_context(:liquid_tag)

      assert {:ok, "echo abc", %ParserContext{rest: "\n%}", mode: :liquid_tag}} =
               Lexer.tokenize_tag_start(context)
    end
  end
end
