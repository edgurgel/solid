defmodule Solid.NumberHelper do
  @moduledoc false

  @spec to_integer(term) :: {:ok, integer} | {:error, binary}
  def to_integer(input) when is_integer(input), do: {:ok, input}

  def to_integer(input) do
    case Integer.parse(to_string(input)) do
      {integer, _} -> {:ok, integer}
      _ -> {:error, "invalid integer"}
    end
  end

  @doc """
  Text form of a float: the shortest digits that read back as the same float,
  in scientific notation when the exponent is below -4 or at least 15.

      2.5     -> "2.5"
      100.0   -> "100.0"
      1.0e15  -> "1.0e+15"
      1.0e-5  -> "1.0e-05"
  """
  @spec float_to_string(float) :: String.t()
  def float_to_string(float) when is_float(float) do
    %Decimal{sign: sign, coef: coef, exp: exp} = decimal = Decimal.from_float(float)
    digits = Integer.digits(coef)
    exponent = length(digits) - 1 + exp

    if coef != 0 and (exponent < -4 or exponent >= 15) do
      [first | rest] = digits |> Enum.reverse() |> Enum.drop_while(&(&1 == 0)) |> Enum.reverse()
      fraction = if rest == [], do: "0", else: Enum.join(rest)
      exponent_sign = if exponent < 0, do: "-", else: "+"
      exponent_digits = exponent |> abs() |> Integer.to_string() |> String.pad_leading(2, "0")

      "#{if sign < 0, do: "-"}#{first}.#{fraction}e#{exponent_sign}#{exponent_digits}"
    else
      Decimal.to_string(decimal, :xsd)
    end
  end
end
