# Benchmarks

```sh
mix run bench/run.exs
```

Each fixture in `bench/fixtures/` becomes one Benchee job, measured twice: once
for `Solid.parse/2` and once for `Solid.render/3` on the already-parsed
template. See the comment at the top of `bench/run.exs` for the environment
variables that narrow the run (`ONLY`) or adjust timings (`WARMUP`, `TIME`,
`MEMORY`).

## Fixtures

`bench/fixtures/` is vendored verbatim from golden-liquid's
[`benchmark_fixtures`](https://github.com/jg-rp/golden-liquid/tree/main/benchmark_fixtures)
directory, taken at commit
[`65c2f76`](https://github.com/jg-rp/golden-liquid/commit/65c2f76ea64ef20647c295b000df5fcd9fc471cd)
(2026-06-18). [golden-liquid](https://github.com/jg-rp/golden-liquid) is a
cross-implementation test suite for the Liquid template language, MIT licensed.

Using the upstream fixtures unchanged means our numbers stay comparable with
other Liquid implementations that benchmark against the same set. Each fixture
is a directory:

- `data.json` — the render context.
- `templates/index.liquid` — the entry-point template, which may pull in the
  other templates in `templates/` via `{% include %}` or `{% render %}`.
- `expected_result.txt` — the output the reference implementation produces.

The numbering skips `003` upstream, so the five directories here (`001`, `002`,
`004`, `005`, `006`) are the complete set.

`001` and `006` use the deprecated `{% include %}` tag, which Solid does not
support; `bench/run.exs` reports and drops any fixture it cannot parse, so those
two are skipped rather than measured.

### Updating

Re-copy the upstream directory as-is and bump the commit reference above — keep
the fixtures unmodified so the comparison with other implementations holds.
