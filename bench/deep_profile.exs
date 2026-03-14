# Deep profiling: allocation tracking, reduction counting, and call analysis
# Run with: MIX_ENV=dev mix run bench/deep_profile.exs

template_text = File.read!("bench/complex_template.liquid")

products =
  for i <- 1..50 do
    %{
      "name" => "Product #{i}",
      "description" =>
        "This is a wonderful product number #{i} with many great features that you will love and enjoy using every single day of the week",
      "price" => 9.99 + i * 3.5,
      "on_sale" => rem(i, 3) == 0,
      "featured" => rem(i, 7) == 0,
      "tags" => Enum.map(1..max(rem(i, 5), 1), fn j -> "tag-#{j}" end),
      "variants" =>
        Enum.map(1..max(rem(i, 4), 1), fn j ->
          %{
            "name" => "variant #{j}",
            "sku" => "SKU-#{i}-#{j}",
            "stock" => rem(i * j, 20)
          }
        end)
    }
  end

categories =
  for i <- 1..8 do
    %{
      "name" => "Category #{i}",
      "description" =>
        "This is category #{i} which contains various items that are grouped together by their shared characteristics and purpose",
      "items" =>
        Enum.map(1..6, fn j ->
          %{
            "name" => "Item #{i}-#{j}",
            "price" => 5.0 + j * 2.5,
            "rating" => 3 + rem(j, 3)
          }
        end)
    }
  end

context = %{
  "site" => %{
    "title" => "Awesome Store",
    "tagline" => "Quality products for everyone",
    "footer_links" => [
      %{"url" => "/about", "label" => "about us"},
      %{"url" => "/contact", "label" => "contact"},
      %{"url" => "/privacy", "label" => "privacy policy"},
      %{"url" => "/terms", "label" => "terms of service"}
    ]
  },
  "user" => %{
    "logged_in" => true,
    "name" => "john doe",
    "email" => "john@example.com",
    "role" => "admin",
    "notifications" => 5,
    "joined" => "2023-01-15"
  },
  "products" => products,
  "categories" => categories
}

{:ok, parsed_template} = Solid.parse(template_text)

# === 1. MEMORY: measure heap growth per render ===
IO.puts("=== MEMORY PROFILING (single render) ===\n")

:erlang.garbage_collect()
{:memory, mem_before} = Process.info(self(), :memory)
{:heap_size, heap_before} = Process.info(self(), :heap_size)
{:minor_gcs, gcs_before} = Process.info(self(), :minor_gcs)
{:reductions, reds_before} = Process.info(self(), :reductions)

Solid.render!(parsed_template, context)

{:reductions, reds_after} = Process.info(self(), :reductions)
{:memory, mem_after} = Process.info(self(), :memory)
{:heap_size, heap_after} = Process.info(self(), :heap_size)
{:minor_gcs, gcs_after} = Process.info(self(), :minor_gcs)

IO.puts("  Reductions:    #{reds_after - reds_before}")
IO.puts("  Memory delta:  #{div(mem_after - mem_before, 1024)} KB")

IO.puts(
  "  Heap growth:   #{heap_after - heap_before} words (#{div((heap_after - heap_before) * 8, 1024)} KB)"
)

IO.puts("  Minor GCs:     #{gcs_after - gcs_before}")

# === 2. REDUCTIONS profiling with tprof (measures work, not wall time) ===
IO.puts("\n=== REDUCTION PROFILING (1 render, sorted by reductions = work done) ===\n")

{:ok, tprof_pid} = :tprof.start(%{type: :call_count})
:tprof.enable_trace(:all)
:tprof.set_pattern(:_, :_, :_)

Solid.render!(parsed_template, context)

:tprof.disable_trace(:all)
raw = :tprof.collect()
{_inspected, analyzed} = :tprof.inspect(raw, :total, :measurement_desc)

# analyzed is [{mfa, {count}}]
solid_fns =
  analyzed
  |> Enum.flat_map(fn {_label, items} -> items end)
  |> Enum.filter(fn {{mod, _, _}, _} ->
    mod_str = Atom.to_string(mod)

    String.starts_with?(mod_str, "Elixir.Solid") or
      String.starts_with?(mod_str, "Elixir.Decimal") or
      String.starts_with?(mod_str, "Elixir.Keyword") or
      String.starts_with?(mod_str, "Elixir.Enum") or
      mod_str in ["lists", "maps", "erlang"]
  end)
  |> Enum.sort_by(fn {_, {count}} -> count end, :desc)
  |> Enum.take(60)

IO.puts(String.pad_trailing("Function", 65) <> String.pad_leading("Calls", 12))
IO.puts(String.duplicate("-", 77))

for {{mod, fun, arity}, {count}} <- solid_fns do
  name = "#{inspect(mod)}.#{fun}/#{arity}" |> String.slice(0..63)
  IO.puts(String.pad_trailing(name, 65) <> String.pad_leading("#{count}", 12))
end

:tprof.stop()

# === 3. STRUCTURAL AUDIT: count how many times key operations happen ===
IO.puts("\n\n=== STRUCTURAL ANALYSIS ===\n")

# Count parse tree size
tree = parsed_template.parsed_template
IO.puts("Parse tree top-level nodes: #{length(tree)}")

# Count total nodes recursively
defmodule TreeCounter do
  def count(nodes) when is_list(nodes), do: Enum.reduce(nodes, 0, &(count(&1) + &2))
  def count(%Solid.Text{}), do: 1
  def count(%Solid.Object{}), do: 1

  def count(%Solid.Tags.ForTag{body: body, else_body: else_body}),
    do: 1 + count(body) + count(else_body)

  def count(%Solid.Tags.IfTag{tag: tag}) do
    1 + count(tag.body) + Enum.reduce(tag.elsifs, 0, fn e, acc -> acc + count(e.body) end) +
      count(tag.else_body || [])
  end

  def count(%Solid.Tags.CaptureTag{body: body}), do: 1 + count(body)
  def count(%Solid.Tags.TablerowTag{body: body}), do: 1 + count(body)
  def count(_), do: 1
end

IO.puts("Total parse tree nodes: #{TreeCounter.count(tree)}")

# Count filter applications in the template
defmodule FilterCounter do
  def count(nodes) when is_list(nodes), do: Enum.reduce(nodes, 0, &(count(&1) + &2))
  def count(%Solid.Object{filters: filters}), do: length(filters)

  def count(%Solid.Tags.ForTag{body: body, else_body: else_body}),
    do: count(body) + count(else_body)

  def count(%Solid.Tags.IfTag{tag: tag}) do
    count(tag.body) + Enum.reduce(tag.elsifs, 0, fn e, acc -> acc + count(e.body) end) +
      count(tag.else_body || [])
  end

  def count(%Solid.Tags.CaptureTag{body: body}), do: count(body)
  def count(%Solid.Tags.TablerowTag{body: body}), do: count(body)
  def count(_), do: 0
end

IO.puts("Total filter applications in template: #{FilterCounter.count(tree)}")

# Show context scope lookup pattern
IO.puts("\nContext scope lookup: default scopes = [:iteration_vars, :vars, :counter_vars]")
IO.puts("  -> get_from_scope reverses to [:counter_vars, :vars, :iteration_vars]")
IO.puts("  -> then maps EACH scope through Matcher.match (3 protocol dispatches per variable)")
IO.puts("  -> then reduces results to pick non-nil winner")

IO.puts(
  "  -> For 50 products * ~10 var lookups each = ~500 lookups * 3 scopes = 1500 match calls"
)

# Size of context vars at peak
IO.puts("\nContext var map sizes:")
IO.puts("  counter_vars keys: #{map_size(context)}")
IO.puts("  counter_vars['products'] length: #{length(context["products"])}")
