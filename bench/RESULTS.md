# Solid Performance Optimization Results

## Machine
- Apple M3 Max, 16 cores, 48 GB RAM
- Elixir 1.20.0-rc.3, Erlang/OTP 28.4, JIT enabled

## Templates
Three realistic Shopify-style Liquid templates:
- **collection_page**: Product grid with nested variants, tags, price comparisons, filters, pagination
- **cart**: Shopping cart with line items, variant info, properties, price formatting
- **email_receipt**: Order confirmation email with line items, addresses, discounts, dates

## Baseline (before optimization)

### Render Performance
```
Name                                          ips        average    median
render/email_receipt/small(n=10)          11.85 K       84.36 μs    82.58 μs
render/cart/small(n=10)                    9.21 K      108.57 μs   104.54 μs
render/collection_page/small(n=10)         2.86 K      349.83 μs   337.21 μs
render/email_receipt/large(n=100)          2.26 K      442.79 μs   428.29 μs
render/cart/large(n=100)                   0.88 K     1139.42 μs  1067.96 μs
render/collection_page/large(n=100)        0.30 K     3353.42 μs  3277.58 μs
```

### Parse Performance
```
Name                                          ips        average    median
parse/cart                                 3.36 K      298.00 μs   285.38 μs
parse/collection_page                      2.76 K      362.92 μs   355.08 μs
parse/email_receipt                        1.98 K      505.51 μs   492.83 μs
```

### Memory Usage
```
Name                                   Memory usage
render/email_receipt/small(n=10)          144.98 KB
render/cart/small(n=10)                   222.39 KB
render/collection_page/small(n=10)        575.38 KB
render/email_receipt/large(n=100)         907.57 KB
render/cart/large(n=100)                 2161.59 KB
render/collection_page/large(n=100)      5671.48 KB
```

### Scaling (collection_page render)
```
n=  10:     349 μs avg  (34 μs/item)
n=  50:    1768 μs avg  (35 μs/item)
n= 200:   16852 μs avg  (84 μs/item)
```

### Diagnostic Findings (collection_page, n=100)
```
Context.get_in/4:              3,628 variable lookups
Context.get_from_scope/3:     14,512 scope checks  (4.0x per lookup)
Solid.Matcher.impl_for/1:    17,660 protocol dispatches (4.9x per lookup)
Solid.Matcher.Map.match/2:   14,032 map matches (3.9x per lookup)
:lists.keyfind/3:             12,910 linear keyword list scans
Keyword.get/3:                11,498 keyword lookups
StandardFilter.apply_filter/4: 2,292 filter dispatch calls (1.6x per apply)
Enum.reverse/1:               21,510 at n=200 (107.5/item)
```

### Root Causes Identified
1. **Scope lookup does 4x the necessary work**: `get_from_scope` checks ALL scopes
   via reverse+map+reduce even when the value is in the first scope checked.
2. **12,910 linear keyword scans per render**: Options like :matcher_module,
   :strict_variables are looked up via Keyword.get (O(n) list scan) on every
   variable lookup and filter application.
3. **Filter dispatch uses try/rescue**: Each filter call goes through
   String.to_existing_atom + Kernel.apply inside a rescue block. With custom
   filters, each filter is tried twice (custom first, then standard).

---

## After Optimization

### Changes Made

**Fix 1: Short-circuit scope lookup** (`lib/solid/context.ex`)
- `get_from_scope/3` previously reversed the scope list, mapped ALL scopes through
  the matcher, then reduced to pick a winner -- even when the first scope had the value.
- New code iterates scopes in priority order, returns immediately on non-nil hit.
- Preserves the subtle nil-shadowing semantics: `{:ok, nil}` does NOT override a
  non-nil value from a lower-priority scope (pinned by 10 new safety tests).

**Fix 2: Convert keyword options to map at render entry** (`lib/solid.ex`)
- Render options (keyword list from user) are converted to a map once via `Map.new/1`
  at the `Solid.render/3` entry point.
- All downstream code uses `opts[:key]` (Access protocol, O(1) on maps) instead of
  `Keyword.get/3` (O(n) linear scan).
- Eliminates 12,028 linear keyword list scans per render at n=100.

**Fix 3: Avoid try/rescue in filter dispatch** (`lib/solid/standard_filter.ex`)
- `apply_filter/4` previously used `String.to_existing_atom` + `Kernel.apply` inside
  a `rescue` block, catching `ArgumentError` and `UndefinedFunctionError` for control flow.
- New code uses `function_exported?/3` to check before calling, avoiding exception-based
  dispatch for the common case.
- `Solid.ArgumentError` from inside filter bodies (e.g. `divided_by 0`) still propagates correctly.

### After Optimization Render Performance
```
Name                                          ips        average    median
render/email_receipt/small(n=10)          14.24 K       70.21 μs    67.33 μs
render/cart/small(n=10)                   12.35 K       80.99 μs    78.38 μs
render/collection_page/small(n=10)         3.85 K      259.86 μs   251.29 μs
render/email_receipt/large(n=100)          2.95 K      339.11 μs   321.08 μs
render/cart/large(n=100)                   1.23 K      814.51 μs   789.08 μs
render/collection_page/large(n=100)        0.38 K     2611.92 μs  2568.85 μs
```

### Comparison (median times)
```
Template                            Before     After    Improvement
render/email_receipt/small(n=10)    82.58 μs   67.33 μs    -18%
render/cart/small(n=10)            104.54 μs   78.38 μs    -25%
render/collection_page/small(n=10) 337.21 μs  251.29 μs    -26%
render/email_receipt/large(n=100)  428.29 μs  321.08 μs    -25%
render/cart/large(n=100)          1067.96 μs  789.08 μs    -26%
render/collection_page/large(n=100)3277.58 μs 2568.85 μs   -22%
```

### Diagnostic Findings After (collection_page, n=100)
```
                               Before      After     Reduction
get_from_scope per get_in:      4.0x        2.2x       -45%
protocol dispatches:          17,660      11,258        -36%
Matcher.Map.match:            14,032       7,630        -46%
:lists.keyfind/3:             12,910         882        -93%
```

### Scaling After (collection_page render)
```
n=  10:     331 μs avg  (33 μs/item)
n=  50:    1606 μs avg  (32 μs/item)
n= 200:   12688 μs avg  (63 μs/item)
```

### Test Suite
77 doctests + 359 tests (16 new safety tests), 0 failures.
Parse performance unchanged (not targeted).
