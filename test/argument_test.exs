defmodule Solid.ArgumentTest do
  use ExUnit.Case, async: true
  import Solid.Argument
  alias Solid.UndefinedVariableError

  describe "get/3" do
    test "basic var" do
      context = %Solid.Context{vars: %{"key" => 123}}
      assert {:ok, 123, ^context} = get([field: ["key"]], context)
    end

    test "basic value" do
      context = %Solid.Context{}
      assert {:ok, "value", ^context} = get([value: "value"], %Solid.Context{})
    end

    test "nested vars" do
      context = %Solid.Context{vars: %{"key1" => %{"key2" => 123}}}
      assert {:ok, 123, ^context} = get([field: ["key1", "key2"]], context)
    end

    test "array access" do
      context = %Solid.Context{vars: %{"key" => [1, [1, 2, 3], 3]}}
      assert {:ok, 2, ^context} = get([field: ["key", 1, 1]], context)
    end

    test "array access not found" do
      context = %Solid.Context{vars: %{"key" => "a string"}}
      assert {:error, nil, ^context} = get([field: ["key", 1]], context)
    end

    test "array access not found with strict_variables" do
      context = %Solid.Context{vars: %{"key" => "a string"}}
      assert {:error, nil, context} = get([field: ["key", 1]], context, strict_variables: true)
      assert context.errors == [%UndefinedVariableError{variable: ["key", 1]}]
    end

    test "array access and nested" do
      context = %Solid.Context{vars: %{"key" => [%{"foo" => "bar1"}, %{"foo" => "bar2"}]}}
      assert {:ok, "bar2", ^context} = get([field: ["key", 1, "foo"]], context)
    end

    test "nil value" do
      context = %Solid.Context{vars: %{"value" => nil}}
      assert {:ok, nil, ^context} = get([field: ["value"]], context)
    end

    test "nil value with strict_variables" do
      context = %Solid.Context{vars: %{"value" => nil}}
      assert {:ok, nil, ^context} = get([field: ["value"]], context, strict_variables: true)
    end

    test "true value" do
      context = %Solid.Context{vars: %{"value" => true}}
      assert {:ok, true, ^context} = get([field: ["value"]], context)
    end

    test "false value" do
      context = %Solid.Context{vars: %{"value" => false}}
      assert {:ok, false, ^context} = get([field: ["value"]], context)
    end
  end

  describe "get/3 with filters" do
    test "basic filter" do
      context = %Solid.Context{vars: %{"key" => nil}}

      assert {:ok, 456, ^context} =
               get([field: ["key"]], context,
                 filters: [filter: ["default", {:arguments, [value: 456]}]]
               )
    end

    test "basic filter strict_variables" do
      context = %Solid.Context{vars: %{}}
      filters = [filter: ["default", {:arguments, [value: 456]}]]

      assert {:error, 456, context} =
               get([field: ["key"]], context, filters: filters, strict_variables: true)

      assert context.errors == [%UndefinedVariableError{variable: ["key"]}]
    end

    test "missing filter strict_filters" do
      context = %Solid.Context{vars: %{"key" => 123}}
      filters = [filter: ["unknown", {:arguments, [value: 456]}]]

      assert {:ok, 123, context} =
               get([field: ["key"]], context, filters: filters, strict_filters: true)

      assert context.errors == [%Solid.UndefinedFilterError{filter: "unknown"}]
    end

    test "missing arg and filter with strict_variables and strict_filters" do
      context = %Solid.Context{vars: %{}}
      filters = [filter: ["unknown", {:arguments, []}]]

      assert {:error, nil, context} =
               get([field: ["key"]], context,
                 filters: filters,
                 strict_variables: true,
                 strict_filters: true
               )

      assert context.errors == [
               %Solid.UndefinedFilterError{
                 filter: "unknown"
               },
               %UndefinedVariableError{variable: ["key"]}
             ]
    end

    test "multiple filters" do
      context = %Solid.Context{vars: %{"key" => nil}}

      filters = [
        filter: ["default", {:arguments, [value: "text"]}],
        filter: ["upcase", {:arguments, []}]
      ]

      assert {:ok, "TEXT", ^context} = get([field: ["key"]], context, filters: filters)
    end

    test "filter with named arguments" do
      filters = [
        filter: [
          "substitute",
          {:arguments, [named_arguments: ["today", {:value, "2022/01/01"}]]}
        ]
      ]

      context = %Solid.Context{}

      assert {:ok, "today is 2022/01/01", ^context} =
               get([value: "today is %{today}"], context,
                 filters: filters,
                 custom_filters: Solid.CustomFilters
               )
    end

    test "filter with named arguments strict_variables" do
      filters = [
        filter: [
          "substitute",
          {:arguments, [named_arguments: ["today", {:field, ["a field"]}]]}
        ]
      ]

      context = %Solid.Context{}

      assert {:ok, "today is ", context} =
               get([value: "today is %{today}"], context,
                 filters: filters,
                 custom_filters: Solid.CustomFilters,
                 strict_variables: true
               )

      assert context.errors == [%UndefinedVariableError{variable: ["a field"]}]
    end
  end
end
