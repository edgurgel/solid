# Solid [![Build Status](https://travis-ci.org/edgurgel/solid.svg?branch=master)](https://travis-ci.org/edgurgel/solid)

Solid is an implementation in Elixir of the template engine Liquid. It uses [nimble_parsec](https://github.com/plataformatec/nimble_parsec) to generate the parser.

## Basic Usage

```elixir
iex> template = "My name is {{ user.name }}"
iex> {:ok, template} = Solid.parse(template)
iex> Solid.render(template, %{ "user" => %{ "name" => "José" } }) |> to_string
"My name is José"
```

## Installation

The package can be installed with:

```elixir
def deps do
  [{:solid, "~> 0.4.0"}]
end
```


## TODO

* [x] Integration tests using Liquid gem to build fixtures; [#3](https://github.com/edgurgel/solid/pull/3)
* [ ] All the standard filters [#8](https://github.com/edgurgel/solid/issues/8)
* [x] Support to custom filters [#11](https://github.com/edgurgel/solid/issues/11)
* [ ] Tags (if, case, unless, etc)
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
  - [ ] `cycle` [#17](https://github.com/edgurgel/solid/issues/17)
  - [x] `capture` [#19](https://github.com/edgurgel/solid/issues/19)
  - [x] `increment` [#16](https://github.com/edgurgel/solid/issues/16)
  - [x] `decrement` [#16](https://github.com/edgurgel/solid/issues/16)
* [x] Boolean operators [#2](https://github.com/edgurgel/solid/pull/2)
* [ ] Whitespace control [#10](https://github.com/edgurgel/solid/issues/10)
