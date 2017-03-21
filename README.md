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
```elixir
def deps do
  [{:solid, "~> 0.0.1"}]
end
```
  2. Ensure solid is started before your application:

```elixir
def application do
  [applications: [:solid]]
end
```

## TODO

* [x] Integration tests using Liquid gem to build fixtures; [#3](https://github.com/edgurgel/solid/pull/3)
* [ ] All the standard filters [#8](https://github.com/edgurgel/solid/issues/8)
* [ ] Tags (if, case, unless, etc)
* [x] Boolean operators [#2](https://github.com/edgurgel/solid/pull/2)
* [ ] Whitespace control
