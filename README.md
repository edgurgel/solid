# Solid
[![Module Version](https://img.shields.io/hexpm/v/solid.svg)](https://hex.pm/packages/solid)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/solid/)
[![Total Download](https://img.shields.io/hexpm/dt/solid.svg)](https://hex.pm/packages/solid)
[![License](https://img.shields.io/hexpm/l/solid.svg)](https://github.com/edgurgel/solid/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/edgurgel/solid.svg)](https://github.com/edgurgel/solid/commits/master)

Solid is an implementation in Elixir of the [Liquid](https://shopify.github.io/liquid/) template language with strict parsing.

## Basic Usage

```elixir
iex> template = "My name is {{ user.name }}"
iex> {:ok, template} = Solid.parse(template)
iex> Solid.render!(template, %{ "user" => %{ "name" => "José" } }) |> to_string
"My name is José"
```

## Installation

The package can be installed with:

```elixir
def deps do
  [{:solid, "~> 1.0"}]
end
```

## Custom tags

To implement a new tag you need to create a new module that implements the `Tag` behaviour. It must implement a `parse/3` function that returns a struct that implements `Solid.Renderable`. Here is a simple example:

```elixir
defmodule CurrentYear do
  @enforce_keys [:loc]
  defstruct [:loc]

  @behaviour Solid.Tag

  @impl true
  def parse("get_current_year", loc, context) do
    with {:ok, [{:end, _}], context} <- Solid.Lexer.tokenize_tag_end(context) do
      {:ok, %__MODULE__{loc: loc}, context}
    end
  end

  defimpl Solid.Renderable do
    def render(_tag, context, _options) do
      {[to_string(Date.utc_today().year)], context}
    end
  end
end
```

Now to use it simply pass a `:tags` option to `Solid.parse/2` including your custom tag:

```elixir
tags = Map.put(Solid.Tag.default_tags(), "get_current_year", CurrentYear)
Solid.parse!("{{ get_current_year }}", tags: tags)
```

One can also pass a subset of the default tags if a more restricted environment is necessary:

```elixir
# No comment tags allowed
tags = Map.delete(Solid.Tag.default_tags(), "comment")
Solid.parse!("{% comment %} {% endcomment %}", tags: tags)
```

An error will be presented as `comment` is not part of the allowed tags:

```elixir
** (Solid.TemplateError) Unexpected tag 'comment'
1: {% comment %} {% endcomment %}
   ^
Unexpected tag 'endcomment'
1: {% comment %} {% endcomment %}
                 ^
    (solid 1.0.0-rc1) lib/solid.ex:51: Solid.parse!/2
    iex:2: (file)
```

## Custom filters

While calling `Solid.render` one can pass a module with custom filters:

```elixir
defmodule MyCustomFilters do
  def add_one(x), do: x + 1
end

"{{ number | add_one }}"
|> Solid.parse!()
|> Solid.render!(%{ "number" => 41}, custom_filters: MyCustomFilters)
|> IO.puts()
# 42
```

## Strict rendering

If there are any missing variables/filters and `strict_variables: true` or `strict_filters: true` are passed as options `Solid.render/3` returns `{:error, errors, result}` where errors is the list of collected errors and `result` is the rendered template.

`Solid.render!/3` raises if `strict_variables: true` is passed and there are missing variables.
`Solid.render!/3` raises if `strict_filters: true` is passed and there are missing filters.

## Caching

In order to cache `render`-ed templates, you can write your own cache adapter. It should implement behaviour `Solid.Caching`. By default it uses `Solid.Caching.NoCache` trivial adapter.

If you want to use for example [Cachex](https://github.com/whitfin/cachex) for that such implemention would look like:

```elixir
defmodule CachexCache do
  @behaviour Solid.Caching

  @impl true
  def get(key) do
    case Cachex.get(:your_cache_name, key) do
      {_, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, value}
      {:error, error_msg} -> {:error, error_msg}
    end
  end

  @impl true
  def put(key, value) do
    case Cachex.put(:my_cache, key, value) do
      {:ok, true} -> :ok
      {:error, error_msg} -> {:error, error_msg}
    end
  end
end

```

And then pass it as an option to render `cache_module: CachexCache`. Now while using `{% render 'etc' %}` this custom cache will be used

## Using structs in context

In order to pass structs to context you need to implement protocol `Solid.Matcher` for that. That protocol consist of one function `def match(data, keys)`. First argument is struct being provided and second is list of string, which are keys passed after `.` to the struct.

For example:

```elixir
defmodule UserProfile do
  defstruct [:full_name]

  defimpl Solid.Matcher do
    def match(user_profile, ["full_name"]), do: {:ok, user_profile.full_name}
  end
end

defmodule User do
  defstruct [:email]

  def load_profile(%User{} = _user) do
    # implementation omitted
    %UserProfile{full_name: "John Doe"}
  end

  defimpl Solid.Matcher do
    def match(user, ["email"]), do: {:ok, user.email}
    def match(user, ["profile" | keys]), do: user |> User.load_profile() |> @protocol.match(keys)
  end
end

template = ~s({{ user.email}}: {{ user.profile.full_name }})
context = %{
  "user" => %User{email: "test@example.com"}
}

template |> Solid.parse!() |> Solid.render!(context) |> to_string()
# => test@example.com: John Doe
```

If the `Solid.Matcher` protocol is not enough one can provide a module like this:

```elixir
defmodule MyMatcher do
  def match(_data, _keys), do: {:ok, 42}
end

# ...
Solid.render!(template, %{"number" => 4}, matcher_module: MyMatcher)
```

## Sigil Support

Solid provides a `~LIQUID` sigil for validating and compiling templates at compile time:

```elixir
import Solid.Sigil

# Validates syntax at compile time
template = ~LIQUID"""
Hello, {{ name }}!
"""

# Use the compiled template
Solid.render!(template, %{"name" => "World"})
```

The sigil will raise helpful CompileError messages with line numbers and context when templates contain syntax errors.
Experimental VSCode syntax highlighting is available with the [Liquid Sigil](https://marketplace.visualstudio.com/items?itemName=JakubSkalecki.liquid-sigil) extension.

## Contributing

When adding new functionality or fixing bugs consider adding a new test case here inside `test/solid/integration/scenarios`. These scenarios are tested against the Ruby gem so we can try to stay as close as possible to the original implementation.

## Copyright and License

Copyright (c) 2016-2025 Eduardo Gurgel Pinho

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
