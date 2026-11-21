defmodule Solid.NumberHelperTest do
  use ExUnit.Case, async: true
  alias Solid.NumberHelper

  describe "float_to_string/1" do
    test "uses the shortest digits that read back as the same float" do
      assert NumberHelper.float_to_string(2.5) == "2.5"
      assert NumberHelper.float_to_string(100.0) == "100.0"
      assert NumberHelper.float_to_string(0.1 + 0.2) == "0.30000000000000004"
      assert NumberHelper.float_to_string(0.0) == "0.0"
      assert NumberHelper.float_to_string(-0.0) == "-0.0"
    end

    test "uses fixed notation for exponents from -4 to 14" do
      assert NumberHelper.float_to_string(123_456_789_012_345.6) == "123456789012345.6"
      assert NumberHelper.float_to_string(0.0001) == "0.0001"
      assert NumberHelper.float_to_string(0.000123456) == "0.000123456"
    end

    test "uses scientific notation for exponents of 15 and above" do
      assert NumberHelper.float_to_string(1.0e15) == "1.0e+15"
      assert NumberHelper.float_to_string(12_345_678_901_234_567.0) == "1.2345678901234568e+16"
      assert NumberHelper.float_to_string(1.0e20) == "1.0e+20"
      assert NumberHelper.float_to_string(-2.5e100) == "-2.5e+100"
    end

    test "uses scientific notation for exponents below -4" do
      assert NumberHelper.float_to_string(0.00001) == "1.0e-05"
      assert NumberHelper.float_to_string(-1.5e-10) == "-1.5e-10"
    end
  end
end
