defmodule Solid.StandardFilterTest do
  use ExUnit.Case, async: true
  alias Solid.StandardFilter
  doctest Solid.StandardFilter

  @loc %Solid.Parser.Loc{line: 1, column: 1}

  describe "apply/4" do
    test "basic filter" do
      assert StandardFilter.apply("upcase", ["ac"], @loc, []) == {:ok, "AC"}
    end

    test "argument error" do
      assert StandardFilter.apply("base64_url_safe_decode", [1], @loc, []) == {
               :error,
               %Solid.ArgumentError{
                 message: "invalid base64 provided to base64_url_safe_decode",
                 loc: @loc
               }
             }
    end

    test "wrong arity" do
      assert StandardFilter.apply("upcase", ["ac", "extra", "arg"], @loc, []) == {
               :error,
               %Solid.WrongFilterArityError{
                 filter: :upcase,
                 expected_arity: 1,
                 arity: 3,
                 loc: @loc
               }
             }
    end

    test "filter not found" do
      assert StandardFilter.apply("no_filter_here", [1, 2, 3], @loc, []) == {:ok, 1}
    end

    test "filter not found with strict_filters" do
      assert StandardFilter.apply("no_filter_here", [1, 2, 3], @loc, strict_filters: true) ==
               {
                 :error,
                 %Solid.UndefinedFilterError{filter: "no_filter_here", loc: @loc},
                 1
               }
    end
  end

  test "it applies a function as custom filter" do
    user_locale = "en"

    custom_filters = fn
      "format_number", [num] ->
        {:ok, "#{user_locale}: #{num}"}

      "format_number", [num, locale] ->
        {:ok, "#{locale}: #{num}"}

      _, _ ->
        :error
    end

    assert "en: 41" ==
             "{{ number | format_number }}"
             |> Solid.parse!()
             |> Solid.render!(%{"number" => 41}, custom_filters: custom_filters)
             |> to_string()

    assert "fr: 41" ==
             "{{ number | format_number: 'fr' }}"
             |> Solid.parse!()
             |> Solid.render!(%{"number" => 41}, custom_filters: custom_filters)
             |> to_string()
  end

  test "custom filter throw undefined error" do
    assert ["41"] ==
             "{{ number | format_number }}"
             |> Solid.parse!()
             |> Solid.render!(%{"number" => 41},
               custom_filters: fn _func, _args ->
                 apply(Map, :does_not_exist, [])
               end
             )
  end
end
