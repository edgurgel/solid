# Solid

Solid is an implementation in Elixir of the template engine Liquid. It uses [neotoma](https://github.com/seancribbs/neotoma) to generate the parser.

## Basic Usage

```elixir
iex> template = "My name is {{ user.name }}"
iex> Solid.parse(template) |> Solid.render(%{ "user" => %{ "name" => "José" } }) |> to_string
"My name is José"
```

## Installation

The package can be installed as:

  1. Add solid to your list of dependencies in `mix.exs`:

        def deps do
          [{:solid, "~> 0.0.1"}]
        end

  2. Ensure solid is started before your application:

        def application do
          [applications: [:solid]]
        end

## TODO

* [ ] Integration tests using Liquid gem to build fixtures; [#3](https://github.com/edgurgel/solid/pull/3)
* [ ] All the standard filters
* [ ] Tags (if, case, unless, etc)
* [ ] Boolean operators
* [ ] Whitespace control
