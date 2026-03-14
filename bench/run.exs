# Benchmark script for Solid template engine
# Run with: mix run bench/run.exs

template_text = File.read!("bench/complex_template.liquid")

# Build complex context data
products =
  for i <- 1..50 do
    %{
      "name" => "Product #{i}",
      "description" =>
        "This is a wonderful product number #{i} with many great features that you will love and enjoy using every single day of the week",
      "price" => 9.99 + i * 3.5,
      "on_sale" => rem(i, 3) == 0,
      "featured" => rem(i, 7) == 0,
      "tags" => Enum.map(1..rem(i, 5), fn j -> "tag-#{j}" end),
      "variants" =>
        Enum.map(1..rem(i, 4), fn j ->
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

# Pre-parse for render-only benchmarks
{:ok, parsed_template} = Solid.parse(template_text)

# Verify it works
{:ok, result, _errors} = Solid.render(parsed_template, context)
output = IO.iodata_to_binary(result)
IO.puts("Template renders to #{byte_size(output)} bytes")
IO.puts("---")

Benchee.run(
  %{
    "parse" => fn -> Solid.parse!(template_text) end,
    "render" => fn -> Solid.render!(parsed_template, context) end,
    "parse+render" => fn ->
      template = Solid.parse!(template_text)
      Solid.render!(template, context)
    end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
