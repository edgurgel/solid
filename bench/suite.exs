# Comprehensive benchmark suite with realistic data at multiple scales.
#
# This lets us detect algorithmic complexity: if doubling the data more than
# doubles the time, we have a super-linear problem.
#
# Run with: MIX_ENV=dev mix run bench/suite.exs

defmodule BenchData do
  @moduledoc "Generates realistic Shopify-shaped data at various scales."

  def make_product(i) do
    variant_count = rem(i, 4) + 1

    %{
      "id" => i,
      "title" => "Product #{i} - Premium Widget",
      "description" =>
        "<p>This is a <strong>premium quality</strong> widget made from the finest materials. " <>
          "Perfect for everyday use, this product has been tested and approved by thousands of " <>
          "happy customers around the world.</p>",
      "url" => "/products/product-#{i}",
      "handle" => "product-#{i}",
      "price" => 1999 + i * 100,
      "price_min" => 1999 + i * 100,
      "price_max" => 2999 + i * 100,
      "price_varies" => variant_count > 1,
      "compare_at_price" => if(rem(i, 3) == 0, do: 2999 + i * 100, else: nil),
      "available" => rem(i, 10) != 0,
      "featured_image" => "product-#{i}.jpg",
      "vendor" => "Vendor #{rem(i, 5) + 1}",
      "type" => Enum.at(["Widgets", "Gadgets", "Tools", "Parts"], rem(i, 4)),
      "tags" => Enum.map(1..rem(i, 5), fn j -> "tag-#{j}" end),
      "variants" =>
        Enum.map(1..variant_count, fn j ->
          %{
            "id" => i * 100 + j,
            "title" => Enum.at(["Small", "Medium", "Large", "XL"], j - 1),
            "price" => 1999 + i * 100 + j * 200,
            "compare_at_price" => if(rem(i, 3) == 0, do: 2999 + i * 100 + j * 200, else: nil),
            "available" => rem(j, 3) != 0,
            "sku" => "SKU-#{i}-#{j}"
          }
        end)
    }
  end

  def make_cart_item(i) do
    product = make_product(i)
    variant = hd(product["variants"])

    %{
      "id" => i,
      "title" => product["title"],
      "variant" => variant,
      "product" => product,
      "price" => variant["price"],
      "original_price" => variant["compare_at_price"] || variant["price"],
      "line_price" => variant["price"] * (rem(i, 3) + 1),
      "quantity" => rem(i, 3) + 1,
      "vendor" => product["vendor"],
      "properties" =>
        if rem(i, 4) == 0 do
          [%{"first" => "Engraving", "last" => "Hello World"}]
        else
          []
        end
    }
  end

  def make_order_line_item(i) do
    %{
      "title" => "Product #{i} - Premium Widget",
      "variant_title" => Enum.at(["Small", "Medium", "Large", ""], rem(i, 4)),
      "sku" => "SKU-#{i}",
      "quantity" => rem(i, 3) + 1,
      "price" => 1999 + i * 100
    }
  end

  def collection_context(n_products) do
    %{
      "collection" => %{
        "title" => "All Products",
        "handle" => "all",
        "description" =>
          "Browse our complete collection of premium widgets, gadgets, and tools. " <>
            "We offer the best selection at competitive prices with free shipping on all orders.",
        "products" => Enum.map(1..n_products, &make_product/1),
        "current_page" => 1,
        "total_pages" => div(n_products, 20) + 1
      }
    }
  end

  def cart_context(n_items) do
    items = Enum.map(1..n_items, &make_cart_item/1)
    total = Enum.sum(Enum.map(items, fn i -> i["line_price"] end))

    %{
      "cart" => %{
        "item_count" => n_items,
        "items" => items,
        "total_price" => total,
        "total_discounts" => if(n_items > 3, do: 500, else: 0),
        "note" => if(n_items > 5, do: "Please gift wrap", else: nil)
      }
    }
  end

  def email_context(n_line_items) do
    line_items = Enum.map(1..n_line_items, &make_order_line_item/1)
    subtotal = Enum.sum(Enum.map(line_items, fn i -> i["price"] * i["quantity"] end))

    %{
      "customer" => %{"first_name" => "jane", "last_name" => "doe", "email" => "jane@example.com"},
      "shop" => %{
        "name" => "Widget Emporium",
        "email" => "support@widgets.example.com",
        "money_with_currency_format" => "${{amount}} USD"
      },
      "order" => %{
        "name" => "#1042",
        "created_at" => "2024-03-15T14:30:00Z",
        "line_items" => line_items,
        "subtotal_price" => subtotal,
        "shipping_price" => 599,
        "tax_price" => div(subtotal * 8, 100),
        "total_price" => subtotal + 599 + div(subtotal * 8, 100),
        "discounts" =>
          if n_line_items > 3 do
            [%{"code" => "SAVE10", "amount" => 1000}]
          else
            []
          end,
        "shipping_method" => %{"title" => "Standard Shipping"},
        "shipping_address" => %{
          "first_name" => "Jane",
          "last_name" => "Doe",
          "company" => "Acme Corp",
          "address1" => "123 Main Street",
          "address2" => "Suite 400",
          "city" => "Portland",
          "province_code" => "OR",
          "zip" => "97201",
          "country" => "United States"
        },
        "billing_address" => %{
          "first_name" => "Jane",
          "last_name" => "Doe",
          "company" => "",
          "address1" => "123 Main Street",
          "address2" => "",
          "city" => "Portland",
          "province_code" => "OR",
          "zip" => "97201",
          "country" => "United States"
        }
      }
    }
  end
end

# Custom filters that mimic Shopify filters (just enough to not error)
defmodule BenchFilters do
  def product_img_url(image, _size), do: "/images/#{image}"

  def money(cents) when is_integer(cents),
    do:
      "$#{div(cents, 100)}.#{rem(cents, 100) |> Integer.to_string() |> String.pad_leading(2, "0")}"

  def money(other), do: "$#{other}"
  def money_with_currency(cents) when is_integer(cents), do: money(cents) <> " USD"
  def money_with_currency(other), do: "$#{other} USD"
  def link_to_vendor(vendor), do: "<a href=\"/collections/vendors?q=#{vendor}\">#{vendor}</a>"
  def link_to_type(type), do: "<a href=\"/collections/types?q=#{type}\">#{type}</a>"
  def asset_url(file), do: "/assets/#{file}"
  def pluralize(count, singular, plural), do: if(count == 1, do: singular, else: plural)
  def json(value), do: inspect(value)
end

# Load and parse templates
templates =
  for name <- ["collection_page", "cart", "email_receipt"] do
    text = File.read!("bench/templates/#{name}.liquid")
    {:ok, parsed} = Solid.parse(text)
    {name, text, parsed}
  end

opts = [custom_filters: BenchFilters]

# Verify all templates render without errors
for {name, _text, parsed} <- templates do
  ctx =
    case name do
      "collection_page" -> BenchData.collection_context(10)
      "cart" -> BenchData.cart_context(5)
      "email_receipt" -> BenchData.email_context(5)
    end

  case Solid.render(parsed, ctx, opts) do
    {:ok, result, []} ->
      IO.puts("#{name}: renders OK (#{byte_size(IO.iodata_to_binary(result))} bytes)")

    {:ok, _result, errors} ->
      IO.puts("#{name}: renders with #{length(errors)} non-strict errors")

    {:error, errors, _result} ->
      IO.puts("#{name}: RENDER FAILED")
      for e <- errors, do: IO.puts("  #{Exception.message(e)}")
  end
end

IO.puts("\n")

# ============================================================
# SCALING BENCHMARK
# Run each template at multiple data sizes to detect
# super-linear behavior.
# ============================================================

IO.puts("=== SCALING TEST (detect super-linear behavior) ===\n")

for {name, _text, parsed} <- templates do
  sizes =
    case name do
      "collection_page" -> [10, 50, 200]
      "cart" -> [5, 25, 100]
      "email_receipt" -> [5, 25, 100]
    end

  IO.puts("--- #{name} ---")

  prev_time = nil

  times =
    for n <- sizes do
      ctx =
        case name do
          "collection_page" -> BenchData.collection_context(n)
          "cart" -> BenchData.cart_context(n)
          "email_receipt" -> BenchData.email_context(n)
        end

      # Warm up
      for _ <- 1..3, do: Solid.render!(parsed, ctx, opts)

      # Measure
      iterations = 50

      {elapsed_us, _} =
        :timer.tc(fn ->
          for _ <- 1..iterations, do: Solid.render!(parsed, ctx, opts)
        end)

      avg_us = div(elapsed_us, iterations)
      per_item = if n > 0, do: div(avg_us, n), else: 0

      IO.puts(
        "  n=#{String.pad_leading("#{n}", 4)}: #{String.pad_leading("#{avg_us}", 7)} µs avg  (#{per_item} µs/item)"
      )

      {n, avg_us}
    end

  # Check scaling factor
  [{n1, t1}, {n2, t2} | _] = times

  if t1 > 0 do
    scale_factor = t2 / t1
    data_factor = n2 / n1
    complexity = :math.log(scale_factor) / :math.log(data_factor)

    label =
      cond do
        complexity < 1.1 -> "~ O(n) -- good"
        complexity < 1.5 -> "~ O(n log n) -- ok"
        complexity < 2.1 -> "~ O(n²) -- BAD"
        true -> "~ O(n^#{Float.round(complexity, 1)}) -- VERY BAD"
      end

    IO.puts(
      "  Scaling: #{Float.round(scale_factor, 2)}x time for #{Float.round(data_factor, 1)}x data -> #{label}"
    )
  end

  IO.puts("")
end

# ============================================================
# BENCHEE DETAILED BENCHMARK
# ============================================================

IO.puts("=== DETAILED BENCHMARKS ===\n")

# Build scenarios
scenarios =
  for {name, text, parsed} <- templates,
      {label_suffix, n} <- [{"small", 10}, {"large", 100}] do
    ctx =
      case name do
        "collection_page" -> BenchData.collection_context(n)
        "cart" -> BenchData.cart_context(n)
        "email_receipt" -> BenchData.email_context(n)
      end

    {"render/#{name}/#{label_suffix}(n=#{n})", fn -> Solid.render!(parsed, ctx, opts) end}
  end

parse_scenarios =
  for {name, text, _parsed} <- templates do
    {"parse/#{name}", fn -> Solid.parse!(text) end}
  end

all_scenarios = (parse_scenarios ++ scenarios) |> Map.new()

Benchee.run(all_scenarios,
  warmup: 2,
  time: 5,
  memory_time: 2
)
