# Solid [![Build Status](https://travis-ci.org/edgurgel/solid.svg?branch=master)](https://travis-ci.org/edgurgel/solid)

Solid is an implementation in Elixir of the template engine Liquid. It uses [neotoma](https://github.com/seancribbs/neotoma) to generate the parser.

## Basic Usage

```elixir
iex> template = "My name is {{ user.name }}"
iex> Solid.parse(template) |> Solid.render(%{ "user" => %{ "name" => "José" } }) |> to_string
"My name is José"
```

## Installation

The package can be installed with:

```elixir
def deps do
  [{:solid, "~> 0.1.0"}]
end
```


## TODO

* [x] Integration tests using Liquid gem to build fixtures; [#3](https://github.com/edgurgel/solid/pull/3)
* [ ] All the standard filters [#8](https://github.com/edgurgel/solid/issues/8)
* [ ] Support to custom filters [#11](https://github.com/edgurgel/solid/issues/11)
* [ ] Tags (if, case, unless, etc)
  - [x] `for`
    - [ ] `else`
    - [ ] `break`
    - [ ] `continue`
    - [ ] `limit`
    - [ ] `offset`
    - [ ] Range (3..5)
    - [ ] `reversed`
  - [ ] `raw` [#18](https://github.com/edgurgel/solid/issues/18)
  - [ ] `cycle` [#17](https://github.com/edgurgel/solid/issues/17)
  - [ ] `capture` [#19](https://github.com/edgurgel/solid/issues/19)
  - [x] `increment` [#16](https://github.com/edgurgel/solid/issues/16)
  - [x] `decrement` [#16](https://github.com/edgurgel/solid/issues/16)
* [x] Boolean operators [#2](https://github.com/edgurgel/solid/pull/2)
* [ ] Whitespace control [#10](https://github.com/edgurgel/solid/issues/10)
