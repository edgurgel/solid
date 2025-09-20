# 1.1.1 (2025-09-20)

## Enhancements

* Align the `Solid.UndefinedFilterError` message with `Solid.UndefinedVariableError` - include line number

## Bug fixes

* Return `{:error, errors}` tuple when both strict_filters and strict_variables are enforced while rendering a template
* Use correct variable name in the `Solid.UndefinedVariableError` message
* Fix `strip_html` filter to handle multiline comments
* Fix nil argument for `replace_last` filter
* Fix `replace_last` filter bug with duplicate substrings
* Fix non-list inputs in `sort_natural` filter
* Fix `replace_first` filter for nil argument

# 1.0.1 (2025-07-04)

## Bug fixes

* Fix parsing error when tags were incomplete
* Point to the opening tag/object line and column when they are not closed properly

# 1.0.0 (2025-06-16)

## Enhancements

* Error messages are now more detailed;
* Parsing can now fail with a list of errors instead of stopping on the first error;
* `liquid` and the inline comment tag are now supported;

## Bug fixes

## Breaking changes

* Parsing engine has been rewritten from scratch. Any custom tags will need to reimplemented using the `Solid.Parser` & `Solid.Lexer` functions. See existing tags as example;
* `Solid.parse/2` returns more meaningful errors and it tries to parse the whole file even when some errors are found. Example:

```elixir
"""
{{ - }}

{% unknown %}

{% if true %}
{% endunless % }
{% echo 'yo' %}
"""
|> Solid.parse!()

** (Solid.TemplateError) Unexpected character '-'
1: {{ - }}
      ^
Unexpected tag 'unknown'
3: {% unknown %}
   ^
Expected one of 'elsif', 'else', 'endif' tags. Got: Unexpected tag 'endunless'
6: {% endunless % }
   ^
Unexpected tag 'endunless'
6: {% endunless % }
   ^
    (solid 1.0.0-rc.0) lib/solid.ex:77: Solid.parse!/2
    iex:2: (file)
```

* `Solid.render/3` now always return `{:ok, result, errors}` unless `strict_variables` or `strict_filters` are enabled and a filter or a variable was not found during rendering. See examples below:

```elixir
"""
{{ 1 | base64_url_safe_decode }}
"""
|> Solid.parse!()
|> Solid.render(%{})

{:ok,
 ["Liquid error (line 1): invalid base64 provided to base64_url_safe_decode",
  "\n"],
 [
   %Solid.ArgumentError{
     message: "invalid base64 provided to base64_url_safe_decode",
     loc: %Solid.Parser.Loc{line: 1, column: 8}
   }
 ]}
```

```elixir
"{{ missing_var }} 123"
|> Solid.parse!()
|> Solid.render(%{})

{:ok, ["", " 123"], []}
```

```elixir
"{{ missing_var }}"
|> Solid.parse!()
|> Solid.render(%{}, strict_variables: true)

{:error,
 [
   %Solid.UndefinedVariableError{
     variable: ["missing_var"],
     loc: %Solid.Parser.Loc{line: 1, column: 4}
   }
 ], [""]}
```

```elixir
"{{ 1 | my_sum }}"
|> Solid.parse!()
|> Solid.render(%{})

{:ok, ["1"], []}
```

```elixir
"{{ 1 | my_sum }}"
|> Solid.parse!()
|> Solid.render(%{}, strict_filters: true)

{:error,
 [
   %Solid.UndefinedFilterError{
     filter: "my_sum",
     loc: %Solid.Parser.Loc{line: 1, column: 8}
   }
 ], ["1"]}
```

* `Solid.FileSystem.read_template_file/2` now must return a tuple with the file content or an error tuple.
