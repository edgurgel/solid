# Diagnostic tool: instruments the hot paths to find algorithmic problems.
#
# This script doesn't just measure time - it counts operations to find:
# 1. O(n) lookups where O(1) is possible (linear scans)
# 2. Redundant allocations (creating the same thing over and over)
# 3. Unnecessary work (computing things that get thrown away)
# 4. Missing short-circuits (doing all the work when partial would suffice)
#
# Run with: MIX_ENV=dev mix run bench/diagnose.exs

Code.require_file("bench/suite.exs")

opts = [custom_filters: BenchFilters]

# Helper: run tprof call_count for a set of patterns, execute a function,
# return a map of "Mod.fun/arity" => count
defmodule Prof do
  def count(patterns, fun) do
    {:ok, _} = :tprof.start(%{type: :call_count})

    for {mod, f, arity} <- patterns do
      :tprof.set_pattern(mod, f, arity)
    end

    :tprof.enable_trace(:all)
    fun.()
    :tprof.disable_trace(:all)

    {:call_count, entries} = :tprof.collect()
    :tprof.stop()

    entries
    |> Enum.map(fn {mod, f, arity, counts} ->
      total = counts |> Enum.map(fn {_label, c, _acc} -> c end) |> Enum.sum()
      {"#{inspect(mod)}.#{f}/#{arity}", total}
    end)
    |> Map.new()
  end
end

IO.puts("=== CALL COUNT SCALING ANALYSIS ===")
IO.puts("Counting calls to key functions at different data sizes.\n")

watched = [
  {Solid.Matcher.Map, :match, 2},
  {Solid.Matcher, :impl_for, 1},
  {Solid.Context, :get_from_scope, 3},
  {Solid.Context, :get_in, 4},
  {Solid.Argument, :get, 4},
  {Solid.Argument, :apply_filters, 4},
  {Solid.StandardFilter, :apply, 4},
  {Solid.Renderable, :render, 3},
  {Solid, :do_render, 3},
  {Solid, :render, 3},
  {Keyword, :get, 2},
  {Keyword, :get, 3},
  {Enum, :reverse, 1},
  {Decimal, :new, 1},
  {Decimal, :from_float, 1},
  {Decimal, :add, 2},
  {Decimal, :mult, 2},
  {Decimal, :to_integer, 1}
]

{:ok, parsed} = Solid.parse(File.read!("bench/templates/collection_page.liquid"))

sizes = [10, 50, 200]

results =
  for n <- sizes do
    ctx = BenchData.collection_context(n)
    counts = Prof.count(watched, fn -> Solid.render!(parsed, ctx, opts) end)
    {n, counts}
  end

IO.puts("Collection page - call counts at different data sizes:")
IO.puts("")

all_fns =
  results
  |> Enum.flat_map(fn {_, counts} -> Map.keys(counts) end)
  |> Enum.uniq()
  |> Enum.sort()

size_cols = sizes |> Enum.map(fn n -> String.pad_leading("n=#{n}", 10) end) |> Enum.join("")

header =
  String.pad_trailing("Function", 50) <>
    size_cols <>
    String.pad_leading("ratio", 10) <>
    String.pad_leading("per-item", 10) <>
    "  verdict"

IO.puts(header)
IO.puts(String.duplicate("-", String.length(header) + 20))

for fn_name <- all_fns do
  counts = Enum.map(results, fn {_n, c} -> Map.get(c, fn_name, 0) end)

  if Enum.any?(counts, &(&1 > 0)) do
    cols = Enum.map(counts, fn c -> String.pad_leading("#{c}", 10) end) |> Enum.join("")

    [small | _] = counts
    large = List.last(counts)
    n_small = hd(sizes)
    n_large = List.last(sizes)

    {ratio_str, per_item_str, verdict} =
      if small > 0 do
        ratio = large / small
        data_ratio = n_large / n_small
        per_item_small = small / n_small
        per_item_large = large / n_large

        ratio_str = "#{Float.round(ratio, 1)}x"
        per_item_str = "#{Float.round(per_item_large, 1)}"

        verdict =
          cond do
            abs(per_item_large - per_item_small) / max(per_item_small, 1) < 0.15 ->
              "OK (linear)"

            ratio > data_ratio * 1.5 ->
              "SUPER-LINEAR!"

            per_item_large > per_item_small * 1.3 ->
              "growing/item!"

            true ->
              "OK"
          end

        {ratio_str, per_item_str, verdict}
      else
        {"n/a", "n/a", ""}
      end

    IO.puts(
      String.pad_trailing(fn_name, 50) <>
        cols <>
        String.pad_leading(ratio_str, 10) <>
        String.pad_leading(per_item_str, 10) <>
        "  " <> verdict
    )
  end
end

# ============================================================
IO.puts("\n\n=== KEYWORD OPTION LOOKUP ANALYSIS ===")
IO.puts("How many linear keyword list scans per render? (collection_page, n=100)\n")

ctx = BenchData.collection_context(100)

kw_counts =
  Prof.count(
    [{Keyword, :get, :_}, {Keyword, :fetch, :_}, {:lists, :keyfind, :_}],
    fn -> Solid.render!(parsed, ctx, opts) end
  )

for {name, count} <- Enum.sort_by(kw_counts, fn {_, c} -> -c end) do
  IO.puts("  #{name}: #{count} calls")
end

# ============================================================
IO.puts("\n\n=== DECIMAL USAGE ANALYSIS ===")
IO.puts("How many Decimal operations per render? (collection_page, n=100)\n")

dec_counts =
  Prof.count(
    [{Decimal, :_, :_}],
    fn -> Solid.render!(parsed, ctx, opts) end
  )

sorted_dec = Enum.sort_by(dec_counts, fn {_, c} -> -c end)
total = Enum.sum(Enum.map(sorted_dec, fn {_, c} -> c end))
IO.puts("  Total Decimal.* calls: #{total}")
IO.puts("")

for {name, count} <- Enum.take(sorted_dec, 20) do
  IO.puts("  #{name}: #{count}")
end

# ============================================================
IO.puts("\n\n=== CONTEXT SCOPE LOOKUP ANALYSIS ===")
IO.puts("How many scope checks per variable lookup? (collection_page, n=100)\n")

scope_counts =
  Prof.count(
    [
      {Solid.Context, :get_from_scope, :_},
      {Solid.Context, :get_in, :_},
      {Solid.Matcher.Map, :match, :_},
      {Solid.Matcher, :match, :_},
      {Solid.Matcher, :impl_for, :_}
    ],
    fn -> Solid.render!(parsed, ctx, opts) end
  )

for {name, count} <- Enum.sort_by(scope_counts, fn {_, c} -> -c end) do
  IO.puts("  #{name}: #{count}")
end

get_in_count = scope_counts["Solid.Context.get_in/4"] || 0
scope_count = scope_counts["Solid.Context.get_from_scope/3"] || 0
matcher_map_count = scope_counts["Solid.Matcher.Map.match/2"] || 0
matcher_dispatch = scope_counts["Solid.Matcher.impl_for/1"] || 0

if get_in_count > 0 do
  IO.puts("")
  IO.puts("  #{Float.round(scope_count / get_in_count, 1)} get_from_scope calls per get_in")
  IO.puts("  #{Float.round(matcher_dispatch / get_in_count, 1)} protocol dispatches per get_in")

  IO.puts(
    "  #{Float.round(matcher_map_count / get_in_count, 1)} Matcher.Map.match calls per get_in"
  )

  IO.puts("")
  IO.puts("  FINDING: Every variable lookup checks ALL 3 scopes even when")
  IO.puts("  the value is found in the first scope checked. Each scope check")
  IO.puts("  does a protocol dispatch (impl_for) + the actual match.")
  IO.puts("  A short-circuiting lookup would eliminate ~2/3 of this work.")
end

# ============================================================
IO.puts("\n\n=== FILTER DISPATCH ANALYSIS ===")
IO.puts("How does StandardFilter.apply work? (collection_page, n=100)\n")

filter_counts =
  Prof.count(
    [
      {Solid.StandardFilter, :apply, :_},
      {Solid.StandardFilter, :apply_filter, :_},
      {Kernel, :apply, :_},
      {:erlang, :apply, :_}
    ],
    fn -> Solid.render!(parsed, ctx, opts) end
  )

for {name, count} <- Enum.sort_by(filter_counts, fn {_, c} -> -c end) do
  IO.puts("  #{name}: #{count}")
end

IO.puts("")
IO.puts("  FINDING: StandardFilter.apply uses try/rescue with String.to_existing_atom")
IO.puts("  on EVERY filter call. If a custom_filters module is provided, it first tries")
IO.puts("  the custom module (which will rescue UndefinedFunctionError), then falls")
IO.puts("  through to StandardFilter. This means most filters go through two try/rescue blocks.")

# ============================================================
IO.puts("\n\n=== SUMMARY OF FINDINGS ===\n")

IO.puts("""
1. SCOPE LOOKUP WASTE: Every variable lookup does #{Float.round(scope_count / max(get_in_count, 1), 1)}x the
   necessary work. get_from_scope checks all scopes via Enum.reverse + Enum.map
   + Enum.reduce, even when the value is in the first scope. For n=100 products
   this is #{scope_count - get_in_count} unnecessary scope checks.

2. PROTOCOL DISPATCH OVERHEAD: #{matcher_dispatch} protocol dispatches
   (Matcher.impl_for) for #{get_in_count} variable lookups. Each dispatch does a
   module lookup. With consolidated protocols in prod this is fast, but in dev
   mode it's slow. More importantly, WE ALREADY KNOW the type -- it's always a
   Map for the scope vars.

3. KEYWORD OPTIONS: #{kw_counts[":lists.keyfind/3"] || 0} linear list scans
   for options that never change during a render. These should be resolved once
   at the top of render and passed as a map or struct.

4. DECIMAL ARITHMETIC: #{total} Decimal.* calls for a page with 100 products.
   Most of these are for simple integer operations like `price | money` where
   native integer math would suffice.

5. FILTER DISPATCH: Every filter call goes through try/rescue + atom conversion.
   With a custom_filters module, each filter is tried TWICE (custom first, then
   standard) with exception-based control flow.
""")
