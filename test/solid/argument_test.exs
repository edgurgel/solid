defmodule Solid.ArgumentTest do
  use ExUnit.Case, async: true

  alias Solid.{
    Argument,
    AccessLiteral,
    Filter,
    Literal,
    UndefinedVariableError,
    Variable
  }

  alias Solid.Parser.Loc

  @loc %Loc{line: 1, column: 1}

  defp parse(template) do
    context = %Solid.ParserContext{rest: "{{#{template}}}", line: 1, column: 1, mode: :normal}
    {:ok, tokens, _context} = Solid.Lexer.tokenize_object(context)
    Argument.parse(tokens)
  end

  defp parse_with_filters(template) do
    context = %Solid.ParserContext{rest: "{{#{template}}}", line: 1, column: 1, mode: :normal}
    {:ok, tokens, _context} = Solid.Lexer.tokenize_object(context)
    Argument.parse_with_filters(tokens)
  end

  describe "parse/1" do
    test "string literal" do
      template = "'a string'"

      assert parse(template) == {
               :ok,
               %Literal{loc: %Loc{column: 3, line: 1}, value: "a string"},
               [{:end, %{line: 1, column: 13}}]
             }
    end

    test "number literal" do
      template = "0"

      assert parse(template) == {
               :ok,
               %Literal{loc: %Loc{column: 3, line: 1}, value: 0},
               [{:end, %{line: 1, column: 4}}]
             }
    end

    test "empty with accesses is a variable" do
      template = "empty[0][1]"

      assert parse(template) == {
               :ok,
               %Variable{
                 original_name: "empty[0][1]",
                 loc: %Loc{line: 1, column: 3},
                 identifier: "empty",
                 accesses: [
                   %AccessLiteral{loc: %Loc{line: 1, column: 9}, access_type: :brackets, value: 0},
                   %AccessLiteral{loc: %Loc{line: 1, column: 12}, access_type: :brackets, value: 1}
                 ]
               },
               [end: %{line: 1, column: 14}]
             }
    end

    test "empty" do
      template = "empty"

      assert parse(template) == {
               :ok,
               %Literal{loc: %Loc{column: 3, line: 1}, value: %Literal.Empty{}},
               [end: %{column: 8, line: 1}]
             }
    end

    test "variable" do
      template = "var123 rest"

      assert parse(template) == {
               :ok,
               %Variable{
                 original_name: "var123",
                 loc: %Loc{column: 3, line: 1},
                 accesses: [],
                 identifier: "var123"
               },
               [
                 {:identifier, %{column: 10, line: 1}, "rest"},
                 {:end, %{line: 1, column: 14}}
               ]
             }
    end

    test "range" do
      template = "(1..3)"

      assert parse(template) == {
               :ok,
               %Solid.Range{
                 loc: %Loc{column: 3, line: 1},
                 finish: %Literal{loc: %Loc{line: 1, column: 7}, value: 3},
                 start: %Literal{loc: %Loc{line: 1, column: 4}, value: 1}
               },
               [end: %{column: 9, line: 1}]
             }
    end

    test "complex range" do
      template = "(a.b['c']..'2')"

      assert parse(template) == {
               :ok,
               %Solid.Range{
                 finish: %Literal{loc: %Loc{column: 14, line: 1}, value: "2"},
                 loc: %Loc{column: 3, line: 1},
                 start: %Variable{
                   original_name: "a.b['c']",
                   loc: %Loc{column: 4, line: 1},
                   accesses: [
                     %AccessLiteral{loc: %Loc{line: 1, column: 6}, access_type: :dot, value: "b"},
                     %AccessLiteral{loc: %Loc{line: 1, column: 8}, access_type: :brackets, value: "c"}
                   ],
                   identifier: "a"
                 }
               },
               [end: %{column: 18, line: 1}]
             }
    end

    test "empty tokens" do
      assert parse("") == {:error, "Argument expected", %{line: 1, column: 3}}
    end
  end

  describe "parse_with_filters/1" do
    test "no filters" do
      template = "'a string'"

      assert parse_with_filters(template) == {
               :ok,
               %Literal{loc: %Loc{column: 3, line: 1}, value: "a string"},
               [],
               [{:end, %{line: 1, column: 13}}]
             }
    end

    test "single filter" do
      template = "var1 | default: 3"

      assert parse_with_filters(template) == {
               :ok,
               %Variable{
                 original_name: "var1",
                 loc: %Loc{column: 3, line: 1},
                 accesses: [],
                 identifier: "var1"
               },
               [
                 %Filter{
                   loc: %Loc{line: 1, column: 10},
                   function: "default",
                   positional_arguments: [
                     %Literal{loc: %Loc{column: 19, line: 1}, value: 3}
                   ],
                   named_arguments: %{}
                 }
               ],
               [end: %{line: 1, column: 20}]
             }
    end

    test "multiple filters" do
      template = "var1 | default: 'a' | upcase and some rest"

      assert parse_with_filters(template) == {
               :ok,
               %Variable{
                 original_name: "var1",
                 accesses: [],
                 identifier: "var1",
                 loc: %Loc{column: 3, line: 1}
               },
               [
                 %Filter{
                   loc: %Loc{line: 1, column: 10},
                   function: "default",
                   positional_arguments: [
                     %Literal{loc: %Loc{column: 19, line: 1}, value: "a"}
                   ],
                   named_arguments: %{}
                 },
                 %Filter{
                   loc: %Loc{column: 25, line: 1},
                   function: "upcase",
                   named_arguments: %{},
                   positional_arguments: []
                 }
               ],
               [
                 {:identifier, %{column: 32, line: 1}, "and"},
                 {:identifier, %{line: 1, column: 36}, "some"},
                 {:identifier, %{line: 1, column: 41}, "rest"},
                 {:end, %{line: 1, column: 45}}
               ]
             }
    end

    test "named arguments" do
      template = "input | substitute: first_name: surname, last_name: 'doe'"

      assert parse_with_filters(template) == {
               :ok,
               %Variable{
                 original_name: "input",
                 accesses: [],
                 identifier: "input",
                 loc: %Loc{column: 3, line: 1}
               },
               [
                 %Filter{
                   function: "substitute",
                   loc: %Loc{column: 11, line: 1},
                   named_arguments: %{
                     "first_name" => %Variable{
                       original_name: "surname",
                       loc: %Loc{column: 35, line: 1},
                       identifier: "surname",
                       accesses: []
                     },
                     "last_name" => %Literal{loc: %Loc{column: 55, line: 1}, value: "doe"}
                   },
                   positional_arguments: []
                 }
               ],
               [end: %{column: 60, line: 1}]
             }
    end

    test "empty tokens" do
      assert parse_with_filters("") == {:error, "Argument expected", %{line: 1, column: 3}}
    end
  end

  describe "get/3" do
    test "basic var" do
      arg = %Variable{original_name: "key", loc: @loc, identifier: "key", accesses: []}
      context = %Solid.Context{vars: %{"key" => 123}}
      assert {:ok, 123, ^context} = Argument.get(arg, context, [])
    end

    test "basic value" do
      arg = %Literal{loc: @loc, value: "value"}
      context = %Solid.Context{}
      assert {:ok, "value", ^context} = Argument.get(arg, context, [])
    end

    test "nested vars" do
      accesses = [%AccessLiteral{loc: @loc, access_type: :dot, value: "key2"}]

      arg = %Variable{
        original_name: "key1.key2",
        loc: @loc,
        identifier: "key1",
        accesses: accesses
      }

      context = %Solid.Context{vars: %{"key1" => %{"key2" => 123}}}
      assert {:ok, 123, ^context} = Argument.get(arg, context, [])
    end

    test "array access" do
      accesses = [
        %AccessLiteral{loc: @loc, access_type: :brackets, value: 1},
        %AccessLiteral{loc: @loc, access_type: :brackets, value: 1}
      ]

      arg = %Variable{
        original_name: "key[1][1]",
        loc: @loc,
        identifier: "key",
        accesses: accesses
      }

      context = %Solid.Context{vars: %{"key" => [1, [1, 2, 3], 3]}}
      assert {:ok, 2, ^context} = Argument.get(arg, context, [])
    end

    test "array access not found" do
      accesses = [%AccessLiteral{loc: @loc, access_type: :brackets, value: 1}]
      arg = %Variable{original_name: "key[1]", loc: @loc, identifier: "key", accesses: accesses}
      context = %Solid.Context{vars: %{"key" => "a string"}}
      assert {:ok, nil, ^context} = Argument.get(arg, context, [])
    end

    test "array access not found with strict_variables" do
      accesses = [%AccessLiteral{loc: @loc, access_type: :brackets, value: 1}]
      arg = %Variable{original_name: "key[1]", loc: @loc, identifier: "key", accesses: accesses}
      context = %Solid.Context{vars: %{"key" => "a string"}}
      assert {:ok, nil, context} = Argument.get(arg, context, [], strict_variables: true)
      assert context.errors == [%UndefinedVariableError{variable: ["key", 1], loc: @loc}]
    end

    test "array access and nested" do
      accesses = [
        %AccessLiteral{loc: @loc, access_type: :brackets, value: 1},
        %AccessLiteral{loc: @loc, access_type: :brackets, value: "foo"}
      ]

      arg = %Variable{
        original_name: "key[1][\"foo\"]",
        loc: @loc,
        identifier: "key",
        accesses: accesses
      }

      context = %Solid.Context{vars: %{"key" => [%{"foo" => "bar1"}, %{"foo" => "bar2"}]}}
      assert {:ok, "bar2", ^context} = Argument.get(arg, context, [])
    end

    test "nil value" do
      arg = %Variable{original_name: "value", loc: @loc, identifier: "value", accesses: []}
      context = %Solid.Context{vars: %{"value" => nil}}
      assert {:ok, nil, ^context} = Argument.get(arg, context, [])
    end

    test "nil value with strict_variables" do
      arg = %Variable{original_name: "value", loc: @loc, identifier: "value", accesses: []}
      context = %Solid.Context{vars: %{"value" => nil}}
      assert {:ok, nil, ^context} = Argument.get(arg, context, [], strict_variables: true)
    end

    test "true value" do
      arg = %Variable{original_name: "value", loc: @loc, identifier: "value", accesses: []}
      context = %Solid.Context{vars: %{"value" => true}}
      assert {:ok, true, ^context} = Argument.get(arg, context, [])
    end

    test "false value" do
      arg = %Variable{original_name: "value", loc: @loc, identifier: "value", accesses: []}
      context = %Solid.Context{vars: %{"value" => false}}
      assert {:ok, false, ^context} = Argument.get(arg, context, [])
    end
  end

  describe "get/3 with filters" do
    test "basic filter" do
      arg = %Variable{original_name: "key", loc: @loc, identifier: "key", accesses: []}

      filters = [
        %Filter{
          loc: @loc,
          function: "default",
          positional_arguments: [%Literal{value: 456, loc: @loc}],
          named_arguments: []
        }
      ]

      context = %Solid.Context{vars: %{"key" => nil}}

      assert {:ok, 456, ^context} = Argument.get(arg, context, filters)
    end

    test "basic filter strict_variables" do
      arg = %Variable{original_name: "key", loc: @loc, identifier: "key", accesses: []}

      filters = [
        %Filter{
          loc: @loc,
          function: "default",
          positional_arguments: [%Literal{value: 456, loc: @loc}],
          named_arguments: []
        }
      ]

      context = %Solid.Context{vars: %{}}

      assert {:ok, 456, context} =
               Argument.get(arg, context, filters, strict_variables: true)

      assert context.errors == [%UndefinedVariableError{variable: ["key"], loc: @loc}]
    end

    test "missing filter strict_filters" do
      arg = %Variable{original_name: "key", loc: @loc, identifier: "key", accesses: []}

      filters = [
        %Filter{
          loc: @loc,
          function: "unknown",
          positional_arguments: [%Literal{value: 456, loc: @loc}],
          named_arguments: []
        }
      ]

      context = %Solid.Context{vars: %{"key" => 123}}

      assert {:ok, 123, context} =
               Argument.get(arg, context, filters, strict_filters: true)

      assert context.errors == [%Solid.UndefinedFilterError{filter: "unknown", loc: @loc}]
    end

    test "wrong arity filter" do
      arg = %Variable{original_name: "key", loc: @loc, identifier: "key", accesses: []}

      filters = [
        %Filter{
          loc: @loc,
          function: "upcase",
          positional_arguments: [%Literal{value: 456, loc: @loc}],
          named_arguments: []
        }
      ]

      context = %Solid.Context{vars: %{"key" => 123}}

      assert {:ok, "Liquid error (line 1): wrong number of arguments (given 2, expected 1)",
              context} =
               Argument.get(arg, context, filters, strict_filters: true)

      assert context.errors == [
               %Solid.WrongFilterArityError{
                 filter: :upcase,
                 loc: @loc,
                 arity: 2,
                 expected_arity: 1
               }
             ]
    end

    test "missing arg and filter with strict_variables and strict_filters" do
      context = %Solid.Context{vars: %{}}
      arg = %Variable{original_name: "key", loc: @loc, identifier: "key", accesses: []}

      filters = [
        %Filter{
          loc: @loc,
          function: "unknown",
          positional_arguments: [%Literal{value: 456, loc: @loc}],
          named_arguments: []
        }
      ]

      assert {:ok, nil, context} =
               Argument.get(arg, context, filters, strict_variables: true, strict_filters: true)

      assert context.errors == [
               %Solid.UndefinedFilterError{filter: "unknown", loc: @loc},
               %UndefinedVariableError{variable: ["key"], loc: @loc}
             ]
    end

    test "multiple filters" do
      context = %Solid.Context{vars: %{"key" => nil}}
      arg = %Variable{original_name: "key", loc: @loc, identifier: "key", accesses: []}

      filters = [
        %Filter{
          loc: @loc,
          function: "default",
          positional_arguments: [%Literal{value: "text", loc: @loc}],
          named_arguments: []
        },
        %Filter{
          loc: @loc,
          function: "upcase",
          positional_arguments: [],
          named_arguments: []
        }
      ]

      assert {:ok, "TEXT", ^context} = Argument.get(arg, context, filters)
    end

    test "filter with named arguments" do
      context = %Solid.Context{vars: %{"name" => "John"}}
      arg = %Literal{loc: @loc, value: "hello %{first_name}, %{last_name}"}

      filters = [
        %Filter{
          function: "substitute",
          loc: @loc,
          named_arguments: %{
            "first_name" => %Variable{
              original_name: "name",
              loc: @loc,
              identifier: "name",
              accesses: []
            },
            "last_name" => %Literal{loc: @loc, value: "doe"}
          },
          positional_arguments: []
        }
      ]

      assert {:ok, "hello John, doe", ^context} =
               Argument.get(arg, context, filters, custom_filters: Solid.CustomFilters)
    end

    test "filter with named arguments strict_variables" do
      context = %Solid.Context{vars: %{}}
      arg = %Literal{loc: @loc, value: "hello %{first_name}, %{last_name}"}

      filters = [
        %Filter{
          function: "substitute",
          loc: @loc,
          named_arguments: %{
            "first_name" => %Variable{
              original_name: "name",
              loc: @loc,
              identifier: "name",
              accesses: []
            },
            "last_name" => %Literal{loc: @loc, value: "doe"}
          },
          positional_arguments: []
        }
      ]

      assert {:ok, "hello , doe", context} =
               Argument.get(arg, context, filters,
                 custom_filters: Solid.CustomFilters,
                 strict_variables: true
               )

      assert context.errors == [%UndefinedVariableError{variable: ["name"], loc: @loc}]
    end
  end
end
