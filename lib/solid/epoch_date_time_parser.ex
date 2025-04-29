# Fork of DateTimeParser.Parser.Epoch to NOT support negative unix epoch
# https://github.com/dbernheisel/date_time_parser/blob/ead04e6075983411707c9fc414c87725e1904dc6/lib/parser/epoch.ex
# The MIT License (MIT)
# Copyright (c) 2018 David Bernheisel
defmodule Solid.EpochDateTimeParser do
  @moduledoc """
  Parses a Unix Epoch timestamp. This is gated by the number of present digits. It must contain 10
  or 11 seconds, with an optional subsecond up to 10 digits. Negative epoch timestamps are not
  supported.
  """
  @behaviour DateTimeParser.Parser

  @max_subsecond_digits 6
  @epoch_regex ~r|\A(?<seconds>\d{10,11})(?:\.(?<subseconds>\d{1,10}))?\z|

  @impl DateTimeParser.Parser
  def preflight(%{string: string} = parser) do
    case Regex.named_captures(@epoch_regex, string) do
      nil -> {:error, :not_compatible}
      results -> {:ok, %{parser | preflight: results}}
    end
  end

  @impl DateTimeParser.Parser
  def parse(%{preflight: preflight} = parser) do
    %{"seconds" => raw_seconds, "subseconds" => raw_subseconds} = preflight
    has_subseconds = raw_subseconds != ""

    with {:ok, seconds} <- parse_seconds(raw_seconds, has_subseconds),
         {:ok, subseconds} <- parse_subseconds(raw_subseconds) do
      from_tokens(parser, {seconds, subseconds})
    end
  end

  @spec parse_seconds(String.t(), boolean()) :: {:ok, integer()}
  defp parse_seconds(raw_seconds, has_subseconds)

  defp parse_seconds(raw_seconds, _) do
    with {seconds, ""} <- Integer.parse(raw_seconds) do
      {:ok, seconds}
    end
  end

  @spec parse_subseconds(String.t()) :: {:ok, {integer(), integer()}}
  defp parse_subseconds(""), do: {:ok, {0, 0}}

  defp parse_subseconds(raw_subseconds) do
    with {subseconds, ""} <- Float.parse("0.#{raw_subseconds}") do
      microseconds = (subseconds * :math.pow(10, 6)) |> trunc()
      precision = min(String.length(raw_subseconds), @max_subsecond_digits)

      truncated_microseconds =
        microseconds
        |> Integer.digits()
        |> Enum.take(@max_subsecond_digits)
        |> Integer.undigits()

      {:ok, {truncated_microseconds, precision}}
    end
  end

  defp from_tokens(%{context: context}, {seconds, {microseconds, precision}}) do
    truncated_microseconds =
      microseconds
      |> Integer.digits()
      |> Enum.take(@max_subsecond_digits)
      |> Integer.undigits()

    with {:ok, datetime} <- DateTime.from_unix(seconds) do
      for_context(context, %{datetime | microsecond: {truncated_microseconds, precision}})
    end
  end

  defp for_context(:best, result) do
    DateTimeParser.Parser.first_ok(
      [
        fn -> for_context(:datetime, result) end,
        fn -> for_context(:date, result) end,
        fn -> for_context(:time, result) end
      ],
      "cannot convert #{inspect(result)} to context :best"
    )
  end

  defp for_context(:datetime, datetime), do: {:ok, datetime}
  defp for_context(:date, datetime), do: {:ok, DateTime.to_date(datetime)}
  defp for_context(:time, datetime), do: {:ok, DateTime.to_time(datetime)}

  defp for_context(context, result) do
    {:error, "cannot convert #{inspect(result)} to context #{context}"}
  end
end
