# Unreleased

## Enhancements

* New filters `has`, `reject`, `find` and `find_index` (#220). Like `where`, they take a property
  name and an optional value. Without a value they test whether the property is truthy:
  * `has` returns `true` when at least one item matches
  * `reject` returns the items that don't match
  * `find` returns the first item that matches, and `find_index` its index. Both return `nil` when
    nothing matches
* `sort`, `sort_natural` and `uniq` accept a property: `{{ products | sort: "price" }}` (#220).
  Items without the property sort last, and `uniq: "key"` keeps the first item for each value
* New `{% ifchanged %}` tag: writes its body only when the output differs from the previous
  `ifchanged` output in the template. A partial loaded with `render` starts fresh (#218)
* A `liquid` line inside `{% liquid %}` now works, and `liquid liquid echo 'a'` nests. A tag opened
  on such a line must end on the same line (#222). Before, it was the error "Unexpected tag
  'liquid'"

## Bug fixes

* Hashes render as `{"a"=>1, "b"=>[nil, "x"]}` instead of `%{"a" => 1, "b" => [nil, "x"]}`, both
  in `{{ hash }}` and when passed to string filters such as `append`. Lists passed to string
  filters use the same format: `[{}, "x"]` instead of `[%{}, "x"]` (#218)
* Floats use scientific notation when their exponent is below -4 or at least 15, everywhere they
  are turned into text: `{{ 0.00001 }}` renders `1.0e-05` and `{{ 1.0e15 }}` renders `1.0e+15`.
  String filters such as `append` now follow the same rule (#218)
* `for` and `tablerow` no longer loop once over a value that can't be iterated, such as a number,
  `true` or a struct. `for` renders its `else` body instead (#218)
* A negative `offset` in `for` and `tablerow` now counts as `0`, and a negative `limit` loops zero
  times. Previously both counted back from the end of the collection (#218)
* `contains` now checks a hash's keys, so `{% if hash contains "a" %}` is `true` when `hash` has
  the key `"a"`. `contains` with `false` on either side is always `false` (#218)
* `split: " "` now splits on any run of whitespace, including tabs and newlines, not only on
  spaces (#218)
* `where: "key"`, without a value, keeps only the items whose `key` is truthy. Previously it kept
  every item that had the key, even when its value was `false` or `nil` (#218)
* `sort_natural` puts `nil` values last, and no longer raises on lists that contain hashes (#218)
* `for` and `tablerow` loops over strings (#218):
  * An empty string loops zero times instead of once
  * A non-empty string loops once, as a whole, and ignores `offset` and `limit`
* `tablerow` fixes (#218):
  * Loops over a hash's key/value pairs, like `for`, instead of rendering the hash as one cell
  * `nil` and `false` render nothing, and an empty collection renders an empty row
    (`<tr class="row1">\n</tr>\n`)
  * `tablerowloop.length` counts the items left after `offset` and `limit`, not the whole
    collection
* `offset: continue` resumes right after the last item the previous loop iterated (#218)
* `{% comment %}` blocks (#218):
  * A nested `{% comment %}` is balanced: the outer comment ends at the `{% endcomment %}` that
    matches it, not the first one found
  * A `{% raw %}` inside a comment is honoured, so an `{% endcomment %}` inside it doesn't end the
    comment
  * Other tags inside a comment are skipped as a whole, so `{% endcommentx %}` or an
    `{% endcomment %}` inside an unclosed tag no longer ends the comment
* Whitespace in blank `if`, `unless`, `case` and `for` blocks (#218):
  * It is stripped from every branch, or from none: a blank branch keeps its whitespace when
    another branch, including `else`, has output. Text between `{% case %}` and the first `when`
    counts too
  * Nested blocks are now taken into account, so an `if` that only holds a blank `if` is blank too
  * `tablerow` never strips whitespace from its body, as every cell renders inside its own `<td>`
  * A `{% raw %}` block that holds whitespace is no longer blank, so its whitespace is kept
* `where` fixes (#220):
  * A list that holds `nil`, a boolean or a float now returns `nil` instead of skipping those items
  * On a list of strings, a string has the property `"oo"` when it contains `"oo"`, so
    `["zoo", "bar"] | where: "oo"` returns `["zoo"]`. Before, it returned `[]`, and raised when
    given a value
* `sort` puts `nil` values last, and raises "cannot sort values of incompatible types" on a list
  that mixes types, such as `[1, "a"]` (#220)
* `{% assign %}` without `=` after the target, such as `{% assign a %}`, is now the parse error
  "Expected '='" instead of a crash (#221)
* A block opened in a `{% liquid %}` tag must close in that same tag. Before, a later
  `{% liquid %}` tag could close it: `{% liquid if true %}x{% liquid endif %}` is now the parse
  error "Expected 'endif'" (#222)

# 1.4.0 (2026-11-15)

## Enhancements

* Looking up a key on a struct that does not implement `Solid.Matcher` (e.g. `{{ user.email }}`
  where `user` is a plain struct) now reports `Solid.MatcherNotImplementedError` when
  `strict_variables: true`, instead of `Solid.UndefinedVariableError`. This also applies to
  built-in structs such as `Date` or `Decimal`. Non-strict rendering is unchanged (renders `nil`)

## Bug fixes

* Only ASCII whitespace counts as `blank`, matching Ruby Liquid's `/\A\s*\z/` check.
  Unicode whitespace such as `U+00A0` (non-breaking space) or `U+3000` (ideographic
  space) is no longer stripped from blank tag bodies, and no longer compares equal to
  the `blank` literal
* Inside `{% liquid %}`, `endcomment` now only ends a `comment` at the start of a line,
  matching Ruby Liquid. Previously `endcomment` anywhere in the comment ended it, and a
  line such as `endcommentx`, or an `endcomment` without the closing `%}`, raised
  `MatchError` instead of returning a parse error
* Variables named `size` or `first` now read their own value, matching Ruby Liquid.
  Previously `{% assign size = "big" %}{{ size }}` rendered `0` (the size of Solid's
  internal loop scope), an undefined `{{ first }}` rendered the first render variable,
  and `{{ first }}` inside a `for` loop raised `Protocol.UndefinedError`. `hash.size`
  and `hash.first` are unchanged (#215)
* A custom `matcher_module` is no longer asked about a name missing from the `for` loop
  or `assign`ed variables, so `size` and `first` read their own value there too. It is
  still asked about every name in the render data. A matcher that hands the whole render
  data to `Solid.Matcher` still reads an undefined `size`/`first` as the render data's
  size or first entry, in `{{ size }}` and as the starting value of `{% increment size %}`
  or `{% decrement size %}`: see the README for a matcher that avoids it (#215)

## Performance

* Optimise lexing further: tag names, identifiers, numbers and strings are now sliced
  out of the input with `binary_part/3` instead of accumulating and reversing a byte
  buffer for every token
* Check `blank` without allocating a trimmed copy of the string
* Parse `comment` and `raw` tag bodies without copying the parser context on every
  byte, and slice the `raw` body out of the input instead of building it byte by byte

# 1.3.4 (2026-09-13)

## Bug fixes

* Fix `!=`/`<>` comparisons against `blank` and `empty`, which were always `true` for
  strings, lists and `nil`. They are now the exact negation of the `==` comparison
* Treat whitespace-only strings and `false` as `blank`, matching Ruby Liquid

## Performance

* Optimise parsing and lexing by matching on raw bytes instead of extracting and comparing single-character sub-binaries
* Optimise argument scope resolution

# 1.3.3

## Features

* Add `squish` filter

## Bug fixes

* Fix custom filters being silently skipped when their module has not been loaded yet

## Security

* Fix denial-of-service where `for`/`tablerow` loops over a range literal (e.g. `(1..1000000000)`) eagerly materialized the whole range into a list before applying `limit`/`offset`, allowing a short attacker-controlled template to exhaust memory. Ranges are now kept lazy so `limit`/`offset` are applied in constant time.

# 1.3.2 (2026-06-14)

## Bug fixes

* Fix `empty` and `blank` comparison cases

# 1.3.1 (2026-06-10)

## Bug fixes

* Update `decimal`

# 1.3.0 (2026-04-25)

## Features

* Add support to `filters_in_conditional_tags` option during parsing to account for a feature that Solid pre-1.0.0 supported that diverged from Liquid. It enables teampltes like:

```liquid
{% if items | size > 0 %}...{% endif %}
{% if name | upcase == "JOHN" %}...{% endif %}
{% unless items | size > 0 %}...{% endunless %}
```

# 1.2.4 (2026-04-18)

## Bug fixes

* Fix identifier with the prefix contains

# 1.2.3 (2026-03-22)

## Bug fixes

* Fix custom tags rendering on partial templates

# 1.2.2 (2026-02-07)

## Bug fixes

* Fix decimal handling - floats and integers are now only converted to string at rendering time. (#193)

# 1.2.1 (2026-01-28)

## Enhancements

* Differentiate between brackets and dot accesses in AccessLiteral. (#189)
## Bug fixes

* Fix incorrect content reversal in case tags. (#191)

# 1.2.0 (2025-12-12)

## Enhancements

* Accept function as custom_filters

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
