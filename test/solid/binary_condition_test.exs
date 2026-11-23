defmodule Solid.BinaryConditionTest do
  use ExUnit.Case, async: true
  alias Solid.Literal.{Blank, Empty}

  import Solid.BinaryCondition

  describe "eval/2" do
    test "numbers and comparison operators" do
      assert eval({1, :==, 1}) == {:ok, true}
      assert eval({1, :!=, 2}) == {:ok, true}
      assert eval({1, :<>, 2}) == {:ok, true}
      assert eval({1, :<, 2}) == {:ok, true}
      assert eval({2, :>, 1}) == {:ok, true}
      assert eval({1, :>=, 1}) == {:ok, true}
      assert eval({2, :>=, 1}) == {:ok, true}
      assert eval({1, :<=, 2}) == {:ok, true}
      assert eval({1, :<=, 1}) == {:ok, true}
      assert eval({1, :>, -2}) == {:ok, true}
      assert eval({-2, :<, 2}) == {:ok, true}
      assert eval({1.0, :>, -1.0}) == {:ok, true}
      assert eval({-1.0, :<, 1.0}) == {:ok, true}

      assert eval({1, :==, 2}) == {:ok, false}
      assert eval({1, :!=, 1}) == {:ok, false}
      assert eval({1, :<>, 1}) == {:ok, false}
      assert eval({1, :<, 0}) == {:ok, false}
      assert eval({2, :>, 4}) == {:ok, false}
      assert eval({1, :>=, 3}) == {:ok, false}
      assert eval({2, :>=, 4}) == {:ok, false}
      assert eval({1, :<=, 0}) == {:ok, false}
    end

    test "literals" do
      assert eval({%{}, :==, %Empty{}}) == {:ok, true}
      assert eval({%Empty{}, :==, %{}}) == {:ok, true}
      assert eval({%{}, :==, %Blank{}}) == {:ok, true}
      assert eval({%Blank{}, :==, %{}}) == {:ok, true}

      assert eval({[], :==, %Empty{}}) == {:ok, true}
      assert eval({%Empty{}, :==, []}) == {:ok, true}
      assert eval({[], :==, %Blank{}}) == {:ok, true}
      assert eval({%Blank{}, :==, []}) == {:ok, true}

      assert eval({"", :==, %Empty{}}) == {:ok, true}
      assert eval({%Empty{}, :==, ""}) == {:ok, true}
      assert eval({"", :==, %Blank{}}) == {:ok, true}
      assert eval({%Blank{}, :==, ""}) == {:ok, true}

      assert eval({nil, :==, %Empty{}}) == {:ok, false}
      assert eval({%Empty{}, :==, nil}) == {:ok, false}
      assert eval({nil, :==, %Blank{}}) == {:ok, true}
      assert eval({%Blank{}, :==, nil}) == {:ok, true}

      assert eval({false, :==, %Empty{}}) == {:ok, false}
      assert eval({%Empty{}, :==, false}) == {:ok, false}
      assert eval({false, :==, %Blank{}}) == {:ok, true}
      assert eval({%Blank{}, :==, false}) == {:ok, true}

      assert eval({true, :==, %Empty{}}) == {:ok, false}
      assert eval({true, :==, %Blank{}}) == {:ok, false}

      assert eval({" \t ", :==, %Empty{}}) == {:ok, false}
      assert eval({%Empty{}, :==, " \t "}) == {:ok, false}
      assert eval({" \t ", :==, %Blank{}}) == {:ok, true}
      assert eval({%Blank{}, :==, " \t "}) == {:ok, true}
    end

    test "blank and empty with <, <=, > and >= are false" do
      for literal <- [%Blank{}, %Empty{}],
          op <- [:<, :<=, :>, :>=],
          value <- [1, -1, 1.5, "", "a", nil, false, true, [], %{}, literal] do
        assert eval({literal, op, value}) == {:ok, false}
        assert eval({value, op, literal}) == {:ok, false}
      end
    end

    test "blank and empty are never equal to each other or themselves" do
      for left <- [%Blank{}, %Empty{}], right <- [%Blank{}, %Empty{}] do
        assert eval({left, :==, right}) == {:ok, false}
        assert eval({left, :!=, right}) == {:ok, true}
        assert eval({left, :<>, right}) == {:ok, true}
      end
    end

    test "literals negated" do
      for op <- [:!=, :<>] do
        for {value, blank?, empty?} <- [
              {nil, true, false},
              {false, true, false},
              {true, false, false},
              {"", true, true},
              {" ", true, false},
              {"x", false, false},
              {[], true, true},
              {["a"], false, false},
              {%{}, true, true},
              {%{"a" => 1}, false, false},
              {0, false, false},
              {1, false, false}
            ] do
          assert eval({value, op, %Blank{}}) == {:ok, not blank?}
          assert eval({%Blank{}, op, value}) == {:ok, not blank?}
          assert eval({value, op, %Empty{}}) == {:ok, not empty?}
          assert eval({%Empty{}, op, value}) == {:ok, not empty?}
        end
      end
    end

    test "contains" do
      assert eval({"jose", :contains, "o"}) == {:ok, true}
      assert eval({"jose", :contains, "jose"}) == {:ok, true}

      assert eval({"jose", :contains, "john"}) == {:ok, false}
    end

    test "contains is false when either side is nil or false" do
      assert eval({[1, false], :contains, false}) == {:ok, false}
      assert eval({[1, nil], :contains, nil}) == {:ok, false}
      assert eval({"false", :contains, false}) == {:ok, false}
      assert eval({%{"a" => 1}, :contains, false}) == {:ok, false}
      assert eval({false, :contains, "a"}) == {:ok, false}
      assert eval({nil, :contains, "a"}) == {:ok, false}
    end

    test "contains on a map checks its keys" do
      assert eval({%{"foo" => "bar"}, :contains, "foo"}) == {:ok, true}
      assert eval({%{"foo" => "bar"}, :contains, "bar"}) == {:ok, false}
      assert eval({%{}, :contains, "foo"}) == {:ok, false}
    end

    test "number and string" do
      assert eval({1, :<, "jose"}) == {:error, "comparison of Integer with String failed"}
      assert eval({"jose", :<, 1}) == {:error, "comparison of String with 1 failed"}

      assert eval({1, :==, "jose"}) == {:ok, false}

      assert eval({1.0, :<, "jose"}) == {:error, "comparison of Float with String failed"}
      assert eval({"jose", :<, 1.0}) == {:ok, false}
      assert eval({1.0, :==, "jose"}) == {:ok, false}
    end
  end
end
