# `format_n_pure` duplicated + `>=`/`<=` in format_pure.hexa (pre-existing debt)

**Reporter:** wilson · 2026-05-16
**Surfaced by:** the strbuf O(n²) migration audit (commit `7d10dde2`
`refactor(runtime,stdlib): migrate 3 quadratic accumulator sites`).
Both issues are **pre-existing**, out of scope for that migration, and
were deliberately NOT touched there (no scope creep). Filed here per the
handoff protocol so they are tracked rather than silently carried.

## Issue 1 — `format_n_pure` defined twice (namespace last-wins shadow)

`format_n_pure` is `pub fn`-defined in BOTH:

- `self/runtime/format_pure.hexa` — the richer version (supports the
  `{:.N}` precision spec)
- `self/runtime/string_pure.hexa` — an older sibling, no `{:.N}` support

Both files are imported by `self/hexa_full.hexa`. hexa-lang's module
flatten is **last-wins**, so `format_pure.hexa`'s definition shadows
`string_pure.hexa`'s in the full build. The shadowed copy is still
reachable if `string_pure.hexa` is imported standalone (some tests do).

The strbuf migration touched **both** copies (so the shadowed one
doesn't carry a now-known-fixed quadratic bug), but the duplication
itself is unresolved.

**Risk:** silent divergence — a future edit to one copy (e.g. a bug fix
or a new format spec) won't reach callers of the other. The two have
already drifted once (`{:.N}` support exists in only one).

**Suggested resolution (needs a decision, hence filed not fixed):**
Pick `format_pure.hexa`'s version as canonical; delete the
`string_pure.hexa` copy and re-export / re-point its importers. OR make
`string_pure.hexa` `use` the `format_pure.hexa` one. Either is a
deliberate API decision for the hexa-lang owner, not a mechanical fix.

`self/test_string_pure.hexa` inlines its own fixture copy of
`format_n_pure` for self-containment — that one is a test fixture, not
the SSOT; leave it.

## Issue 2 — `>=` / `<=` in `format_pure.hexa` (governance g1)

`self/runtime/format_pure.hexa:126` and `:133` use `>=` / `<=`
operators. wilson governance **g1 (`no-ge-le-operators`)** — authority
`docs/hexa-lang/RULES.md` — forbids these in `.hexa` (use `<` / `>`
with an offset: `x > y - 1` for `x >= y`). These predate the strbuf
migration; the migration diff introduces **zero** new `>=`/`<=`.

**Mechanical fix** (low risk, no decision needed):

| line | from | to |
|---|---|---|
| ~126 | `a >= b` | `a > b - 1` |
| ~133 | `a <= b` | `a < b + 1` |

(Exact rewrite depends on the surrounding int expressions — read the
two lines in context; for float comparisons the offset trick is wrong,
so confirm the operands are integers first.)

Safe to fix in a standalone `style(runtime): g1 — drop >=/<= in
format_pure.hexa` commit. Filed rather than bundled into the strbuf
migration to keep that diff reviewable and scope-pure.

## Cross-refs

- `incoming/patches/string-concat-in-unbounded-loop-quadratic-rss.md`
  — the parent strbuf work that surfaced these.
- Migration commit: `7d10dde2` (stage2-verify) / `233628cc`
  (`strbuf-migration-internal` branch, off main).
