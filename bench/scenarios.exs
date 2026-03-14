# Benchmark all integration test scenarios - parse and render separately.
# Outputs a table suitable for before/after comparison.
#
# Run with: MIX_ENV=test mix run bench/scenarios.exs
#
# Uses the same templates and data as the integration tests.

scenarios_dir = "test/solid/integration/scenarios"
scenarios = File.ls!(scenarios_dir) |> Enum.sort()

# Build opts matching integration tests
opts = [custom_filters: Solid.CustomFilters]

# Warmup + measure helper
defmodule Bench do
  def measure(fun, warmup \\ 50, iterations \\ 200) do
    # Warmup
    for _ <- 1..warmup, do: fun.()

    # Measure
    times =
      for _ <- 1..iterations do
        {us, _} = :timer.tc(fun)
        us
      end

    sorted = Enum.sort(times)
    median = Enum.at(sorted, div(iterations, 2))
    avg = div(Enum.sum(times), iterations)
    p99 = Enum.at(sorted, round(iterations * 0.99) - 1)
    {median, avg, p99}
  end
end

# Header
IO.puts(
  String.pad_trailing("scenario", 22) <>
    String.pad_leading("parse_med", 12) <>
    String.pad_leading("parse_avg", 12) <>
    String.pad_leading("parse_p99", 12) <>
    String.pad_leading("render_med", 12) <>
    String.pad_leading("render_avg", 12) <>
    String.pad_leading("render_p99", 12) <>
    String.pad_leading("total_med", 12)
)

IO.puts(String.duplicate("-", 106))

parse_totals = []
render_totals = []

{parse_totals, render_totals} =
  Enum.reduce(scenarios, {[], []}, fn scenario, {parse_acc, render_acc} ->
    liquid_file = Path.join([scenarios_dir, scenario, "input.liquid"])
    json_file = Path.join([scenarios_dir, scenario, "input.json"])
    template_dir = Path.join(scenarios_dir, scenario)

    liquid_input = File.read!(liquid_file)
    json_input = File.read!(json_file)
    context = Jason.decode!(json_input)

    scenario_opts =
      if File.ls!(template_dir) |> Enum.any?(&String.starts_with?(&1, "_")) do
        file_system = Solid.LocalFileSystem.new(template_dir)
        [{:file_system, {Solid.LocalFileSystem, file_system}} | opts]
      else
        opts
      end

    # Measure parse
    {parse_med, parse_avg, parse_p99} =
      Bench.measure(fn -> Solid.parse!(liquid_input, scenario_opts) end)

    # Pre-parse for render measurement
    parsed = Solid.parse!(liquid_input, scenario_opts)

    # Measure render
    {render_med, render_avg, render_p99} =
      Bench.measure(fn ->
        case Solid.render(parsed, context, scenario_opts) do
          {:ok, _result, _errors} -> :ok
          {:error, _errors, _result} -> :ok
        end
      end)

    IO.puts(
      String.pad_trailing(scenario, 22) <>
        String.pad_leading("#{parse_med}", 12) <>
        String.pad_leading("#{parse_avg}", 12) <>
        String.pad_leading("#{parse_p99}", 12) <>
        String.pad_leading("#{render_med}", 12) <>
        String.pad_leading("#{render_avg}", 12) <>
        String.pad_leading("#{render_p99}", 12) <>
        String.pad_leading("#{parse_med + render_med}", 12)
    )

    {[parse_med | parse_acc], [render_med | render_acc]}
  end)

IO.puts(String.duplicate("-", 106))

total_parse = Enum.sum(parse_totals)
total_render = Enum.sum(render_totals)

IO.puts(
  String.pad_trailing("TOTAL", 22) <>
    String.pad_leading("#{total_parse}", 12) <>
    String.pad_leading("", 12) <>
    String.pad_leading("", 12) <>
    String.pad_leading("#{total_render}", 12) <>
    String.pad_leading("", 12) <>
    String.pad_leading("", 12) <>
    String.pad_leading("#{total_parse + total_render}", 12)
)

IO.puts("\nAll times in microseconds (μs). Median of 200 iterations after 50 warmup.")
