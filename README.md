# Solid

[![Build Status](https://github.com/edgurgel/solid/workflows/CI/badge.svg?branch=master)](https://github.com/edgurgel/solid/actions?query=workflow%3ACI)
[![Module Version](https://img.shields.io/hexpm/v/solid.svg)](https://hex.pm/packages/solid)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/solid/)
[![Total Download](https://img.shields.io/hexpm/dt/solid.svg)](https://hex.pm/packages/solid)
[![License](https://img.shields.io/hexpm/l/solid.svg)](https://github.com/edgurgel/solid/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/edgurgel/solid.svg)](https://github.com/edgurgel/solid/commits/master)

Solid is an implementation in Elixir of the template language [Liquid](https://shopify.github.io/liquid/). It uses [nimble_parsec](https://github.com/plataformatec/nimble_parsec) to generate the parser.

## Basic Usage

```elixir
iex> template = "My name is {{ user.name }}"
iex> {:ok, template} = Solid.parse(template)
iex> Solid.render!(template, %{ "user" => %{ "name" => "José" } }) |> to_string
"My name is José"
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

## Installation

The package can be installed with:

```elixir
def deps do
  [{:solid, "~> 0.14"}]
end
```

## Custom tags

To implement a new tag you need to create a new module that implements the `Tag` behaviour:

```elixir
defmodule MyCustomTag do
  import NimbleParsec
  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Solid.Parser.Literal.whitespace(min: 0)

    ignore(string("{%"))
    |> ignore(space)
    |> ignore(string("my_tag"))
    |> ignore(space)
    |> ignore(string("%}"))
  end

  @impl true
  def render(_tag, _context, _options) do
    [text: "my first tag"]
  end
end
```

- `spec` defines how to parse your tag;
- `render` defines how to render your tag.

Now we need to add the tag to the parser

```elixir
defmodule MyParser do
  use Solid.Parser.Base, custom_tags: [MyCustomTag]
end
```

And finally pass the custom parser as an option:

```elixir
"{% my_tag %}"
|> Solid.parse!(parser: MyParser)
|> Solid.render()
```

## Custom filters

While calling `Solid.render` one can pass a module with custom filters:

```elixir
defmodule MyCustomFilters do
  def add_one(x), do: x + 1
end

"{{ number | add_one }}"
|> Solid.parse!()
|> Solid.render(%{ "number" => 41}, custom_filters: MyCustomFilters)
|> IO.puts()
# 42
```

Extra options can be passed as last argument to custom filters if an extra argument is accepted:

```elixir
defmodule MyCustomFilters do
  def asset_url(path, opts) do
    opts[:host] <> path
  end
end

opts = [custom_filters: MyCustomFilters, host: "http://example.com"]

"{{ file_path | asset_url }}"
|> Solid.parse!()
|> Solid.render(%{ "file_path" => "/styles/app.css"}, opts)
|> IO.puts()
# http://example.com/styles/app.css
```

## Strict rendering

`Solid.render/3` doesn't raise or return errors unless `strict_variables: true` or `strict_filters: true` are passed as options.

If there are any missing variables/filters `Solid.render/3` returns `{:error, errors, result}` where errors is the list of collected errors and `result` is the rendered template.

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

And then pass it as an option to render `cache_module: CachexCache`.

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

If the `Solid.Matcher` protocol is not enough one can provide their own module like this:

```elixir
defmodule MyMatcher do
  def match(data, keys), do: {:ok, 42}
end

# ...
Solid.render(template, %{"number" => 4}, matcher_module: MyMatcher)
```

## Contributing

When adding new functionality or fixing bugs consider adding a new test case here inside `test/cases`. These cases are tested against the Ruby gem so we can try to stay as close as possible to the original implementation.

## TODO

- [x] Integration tests using Liquid gem to build fixtures; [#3](https://github.com/edgurgel/solid/pull/3)
- [x] All the standard filters [#8](https://github.com/edgurgel/solid/issues/8)
- [x] Support to custom filters [#11](https://github.com/edgurgel/solid/issues/11)
- [x] Tags (if, case, unless, etc)
  - [x] `for`
    - [x] `else`
    - [x] `break`
    - [x] `continue`
    - [x] `limit`
    - [x] `offset`
    - [x] Range (3..5)
    - [x] `reversed`
    - [x] `forloop` object
  - [x] `raw` [#18](https://github.com/edgurgel/solid/issues/18)
  - [x] `cycle` [#17](https://github.com/edgurgel/solid/issues/17)
  - [x] `capture` [#19](https://github.com/edgurgel/solid/issues/19)
  - [x] `increment` [#16](https://github.com/edgurgel/solid/issues/16)
  - [x] `decrement` [#16](https://github.com/edgurgel/solid/issues/16)
- [x] Boolean operators [#2](https://github.com/edgurgel/solid/pull/2)
- [x] Whitespace control [#10](https://github.com/edgurgel/solid/issues/10)

## Copyright and License

Copyright (c) 2016-2022 Eduardo Gurgel Pinho

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
