# Benchee suite for Solid, driven by the template fixtures in `bench/fixtures`.
#
#     mix run bench/run.exs
#
# Each fixture becomes one Benchee job, measured twice: once for `Solid.parse/2`
# and once for `Solid.render/3` on the already-parsed template.
#
# Environment variables:
#
#   ONLY=004,005    only run the listed fixtures (default: every fixture Solid can parse)
#   WARMUP=1        warmup seconds per job (default: 1)
#   TIME=3          measurement seconds per job (default: 3)
#   MEMORY=1        memory measurement seconds per job, 0 to skip (default: 1)

defmodule Bench.FileSystem do
  @moduledoc """
  Reads partials verbatim from `<root>/<name>`.

  The fixtures reference partials by their full file name (e.g.
  `{% render "snippet.liquid" %}`), which `Solid.LocalFileSystem` rejects
  because of the dot in the name.
  """
  @behaviour Solid.FileSystem

  @impl true
  def read_template_file(name, root) do
    case File.read(Path.join(root, name)) do
      {:ok, contents} ->
        {:ok, contents}

      {:error, reason} ->
        {:error, %Solid.FileSystem.Error{reason: "#{name}: #{:file.format_error(reason)}"}}
    end
  end
end

root = Path.join(__DIR__, "fixtures")

seconds = fn name, default ->
  name |> System.get_env(default) |> Float.parse() |> elem(0)
end

only =
  case System.get_env("ONLY") do
    nil -> nil
    csv -> String.split(csv, ",", trim: true)
  end

fixtures =
  root
  |> File.ls!()
  |> Enum.sort()
  |> Enum.filter(&File.dir?(Path.join(root, &1)))
  |> Enum.filter(fn name -> is_nil(only) or name in only end)
  |> Enum.map(fn name ->
    dir = Path.join(root, name)
    template_dir = Path.join(dir, "templates")
    opts = [file_system: {Bench.FileSystem, template_dir}]
    source = File.read!(Path.join(template_dir, "index.liquid"))
    data = dir |> Path.join("data.json") |> File.read!() |> Jason.decode!()

    {name, source, data, opts}
  end)

# A fixture Solid cannot parse (001 and 006 use the deprecated `{% include %}`
# tag) has nothing to measure, so report it and drop it.
{runnable, skipped} =
  Enum.split_with(fixtures, fn {_name, source, _data, opts} ->
    match?({:ok, _template}, Solid.parse(source, opts))
  end)

Enum.each(skipped, fn {name, source, _data, opts} ->
  {:error, error} = Solid.parse(source, opts)
  reason = error |> Exception.message() |> String.split("\n", parts: 2) |> hd()
  IO.puts(:stderr, "skipping #{name}: #{reason}")
end)

if runnable == [], do: Mix.raise("no runnable fixtures in #{root}")

opts_for = fn suite ->
  [
    title: suite,
    warmup: seconds.("WARMUP", "1"),
    time: seconds.("TIME", "3"),
    memory_time: seconds.("MEMORY", "1"),
    print: [fast_warning: false]
  ]
end

parse_jobs =
  Map.new(runnable, fn {name, source, _data, opts} ->
    {name, fn -> Solid.parse!(source, opts) end}
  end)

render_jobs =
  Map.new(runnable, fn {name, source, data, opts} ->
    template = Solid.parse!(source, opts)
    {name, fn -> Solid.render!(template, data, opts) end}
  end)

Benchee.run(parse_jobs, opts_for.("parse"))
Benchee.run(render_jobs, opts_for.("render"))
