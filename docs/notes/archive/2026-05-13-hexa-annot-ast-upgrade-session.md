# 2026-05-13 — `tool/hexa_annot/hexa-*` grep-MVP → AST upgrade

Phase 5 item #1 from the absorption follow-up list: replace the 29 grep/awk
heuristic extractors in `tool/hexa_annot/hexa-*` with a single AST-aware
back-end powered by `self/lexer.tokenize()`.

## Approach

**Option α** (as recommended in the brief). One shared `_ast_extract.hexa`
walks the token stream and emits a uniform TSV; bash wrappers post-process
that TSV into each tool's tool-specific JSON shape.

A pure-AST walk via `self/parser.parse()` was the first instinct, but the
parser drops `attrs`/`annotations` on `StructDecl` (only `FnDecl` /
`AsyncFnDecl` / `PureFnDecl` carry them). Touching the parser was out of
scope for this BG, so the extractor uses the lexer-level token stream
directly. That still buys the full precision win — comments and string
literals are already classified, so the "`@foo` inside a `//` comment" and
"`@foo` inside `\"...\"`" false-positives that plagued the grep MVPs all
disappear.

## `_ast_extract.hexa`: shape + key choices

- 321 LOC, single hexa script.
- Imports `self/lexer` only — no parser dependency.
- Walks tokens linearly. For each `At` token: captures the attribute name
  (next Ident/keyword token), the parenthesized arg list (verbatim
  token-joined; StringLit re-quoted; nested parens depth-tracked), then
  skips over chained `@...` annotations + optional `pub` visibility to
  find the next decl keyword (`Fn`/`Struct`/`Enum`/`Let`/`Const`/`Static`/
  `Async`/`Pure`/`Trait`/`Impl`/`Type`).
- For `fn` targets: also captures the body tokens between matching
  `{...}` braces (joined to a string). Used only by `hexa-pure-check`.
- Output: TSV, one row per `@`-token, columns:

  `annot_name`  `target_kind`  `target_name`  `file`  `line`  `raw_args_esc`  `body_text_esc`

  where `*_esc` uses `\n`/`\r`/`\t`/`\\` escaping (the bash wrappers
  decode before re-emitting JSON).
- On per-file read failure: emits one `# error\t<path>\t<msg>` comment
  row and continues — wrappers `grep -v '^# error'` if they care.

Companion: `_ast_extract.sh` (488 LOC) holds the shared bash helpers
(`resolve_files`, `run_ast_extract`, `ast_emit_kindmap_json`,
`ast_kv_extract`, `ast_decode_esc`, `ast_json_escape`). 15+ of the 29
wrappers reduce to ~40-line thin shells that call
`run_ast_extract | ast_emit_kindmap_json "$kinds_csv" "$filter"`.

## 29 tools — per-tool LOC delta

| tool | post LOC | shape |
|---|---|---|
| hexa-pure-check | 107 | custom: `pure_fns[]` + violations |
| hexa-memo-check | 184 | custom: `memos[]` + cache_key_template |
| hexa-catalog | 124 | custom: `commands[]` + flags |
| hexa-readme | 215 | 3-mode: json / readme / changelog |
| hexa-doc | 121 | markdown grouping |
| hexa-codegen-hints | 114 | `hints[]` |
| hexa-distill | 44 | kindmap |
| hexa-effect-map | 69 | kindmap |
| hexa-intent-map | 103 | custom: `intents[]` |
| hexa-meta-map | 193 | kindmap + `phases_covered[]` |
| hexa-phi-map | 128 | quad-bucket + summary aggregates |
| hexa-struct-layout | 129 | per-struct repr/align/pack |
| hexa-self-aware | 43 | kindmap |
| hexa-cognitive | 51 | kindmap (25 kinds) |
| hexa-freedom | 44 | kindmap |
| hexa-infer | 42 | kindmap |
| hexa-learn | 42 | kindmap |
| hexa-safety | 43 | kindmap |
| hexa-antivirus | 43 | kindmap |
| hexa-serve | 42 | kindmap |
| hexa-tenant | 42 | kindmap |
| hexa-eval-run | 42 | kindmap |
| hexa-n6-list | 106 | `n6_tags[]` + by_domain summary |
| hexa-test-list | 150 | `tests[]` + fn-args |
| hexa-schema | 118 | `schemas[]` + struct fields |
| hexa-law-link | 137 | `links[]` + rules.json cross-ref |
| hexa-harness | 182 | kindmap (H-* gate filter) |
| hexa-rule | 237 | collect + migrate dry-run |
| hexa-gate-register | 103 | `gates[]` |
| `_ast_extract.hexa` | 321 | shared back-end |
| `_ast_extract.sh` | 488 | shared bash helpers |

Total `tool/hexa_annot/` LOC delta: **-5504 lines** (29 wrappers
7689 → 2185, plus 488+321 = 809 new shared infra). Net **~-4700 LOC**.

## Schema bumps

- All 29 wrappers now emit `"version":"0.2","source":"ast"` (previously
  `"0.1"` / `"grep-mvp"`).
- `test/hexa_annot_smoke.sh::is_valid_grep_mvp_json` updated to accept
  both forms — backwards-compat with any external tooling that still
  scans for the legacy prefix.

## Smoke result

```
Result: 29/29 PASS
```

(after the `is_valid_grep_mvp_json` matcher update — same 2-line patch
that recognizes the `0.2`/`ast` form alongside the legacy `0.1`/`grep-mvp`.)

## Precision wins (AST catches what grep missed)

Diff of `total` counts on `test/fixtures/annot_sample.hexa`:

| tool | grep MVP | AST | delta | reason |
|---|---|---|---|---|
| `hexa-freedom` | 9 | 10 | +1 | `@indeterminate` recognized; grep MVP had a stale kind list missing `indeterminate` (legacy header said `causal_power` instead). AST sees it via the lexer's @-token classification. |
| `hexa-readme` | 3 | 4 | +1 | `@api_doc(section="public")` caught. Grep MVP required `body=` arg present. |
| `hexa-test-list` | 0 | 2 | +2 | `@test(name="t1")` and `@bench(name="b1")` — grep MVP required bare `@test`/`@bench` with no parens. |

Three additional improvements that don't show as count diffs but are real:

1. **Comment immunity** — `// @effect(io) fn foo()` in a docstring is no
   longer collected (grep MVP would flag it).
2. **String-literal immunity** — `"... @foo(bar) ..."` inside a
   `StringLit` no longer matches.
3. **Struct-targeting** — `@repr` / `@align` / `@pack` / `@schema`
   correctly attach to struct decls (the AST extractor's
   `target_kind="struct"` flag); the kindmap family of wrappers
   explicitly filter to `target_kind="fn"` so name-collisions (e.g.
   `@align` on `safety` vs `struct-layout`) no longer cross-contaminate.

## Known limitations / follow-ups

- `_ast_extract.hexa` walks tokens, not the parsed AST tree. Pros: works
  for struct attributes (the parser drops them). Cons: cannot resolve
  semantic queries like "this @memo fn calls exec()" with full type
  context — `hexa-pure-check`'s body-substring scan is still heuristic
  (just operates on a token-joined body instead of a regex on raw text).
- The shared `ast_emit_kindmap_json` awk helper forces `target_kind=fn`
  for the kindmap family — if a tool ever wants struct/enum-attached
  collection it needs a one-off custom emitter (struct-layout / schema
  already do this).
- `hexa-doc` and `hexa-readme` use a path-based `infer_project()`
  heuristic on the first input file (legacy behavior). Not AST-related.
- `hexa-rule --mode migrate --apply` still surfaces "unsupported in MVP"
  — the rewrite path was MVP-stubbed by the original wave-1 absorption
  and is out of scope for this BG.

## Files touched

- `tool/hexa_annot/_ast_extract.hexa` — NEW, 321 LOC
- `tool/hexa_annot/_ast_extract.sh` — NEW, 488 LOC
- `tool/hexa_annot/hexa-*` — 29 wrappers rewritten
- `test/hexa_annot_smoke.sh` — matcher accepts both `0.1`/`grep-mvp` and
  `0.2`/`ast` JSON prefixes

No `self/lexer.hexa` / `self/parser.hexa` / `self/codegen_c2.hexa`
changes (the brief's hard constraint).
