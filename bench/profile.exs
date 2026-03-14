# Profile script for Solid template engine
# Run with: elixir -S mix run bench/profile.exs
#
# We use a manual timing approach since :tools may not be available in all
# OTP configurations with mix.

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

# Profile rendering
IO.puts("=== Profiling RENDER (10 iterations) with :eprof ===\n")

{:ok, _} = :eprof.start()

:eprof.profile([self()], fn ->
  for _ <- 1..10 do
    Solid.render!(parsed_template, context)
  end
end)

:eprof.analyze(:total)
:eprof.stop()

IO.puts("\n\n=== Profiling PARSE (10 iterations) with :eprof ===\n")

{:ok, _} = :eprof.start()

:eprof.profile([self()], fn ->
  for _ <- 1..10 do
    Solid.parse!(template_text)
  end
end)

:eprof.analyze(:total)
:eprof.stop()
