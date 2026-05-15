# format_pure debt — RESOLVED (2026-05-16)

**Status:** ✅ CLOSED by `9f621602` / merge `03f1a460` on `main`
(also on `stage2-verify`, the branch wilson builds against, via the
same fix). Reporter: wilson. Surfaced by the strbuf migration audit
(`233628cc`), closed after an explicit safe-review pass.

Three issues, all in `self/runtime/{format_pure,string_pure}.hexa`:

## 1. `format_n_pure` / `format_pure` duplicated — FIXED

Defined in BOTH files. `string_pure` is imported before `format_pure`
in `self/hexa_full.hexa`, so the namespace-flatten last-wins rule meant
`string_pure`'s copies were **always shadowed** by `format_pure.hexa`'s
richer `{:.N}`-aware version. The only non-test importer of
`string_pure` is `hexa_full.hexa` (which also pulls `format_pure.hexa`);
`test_string_pure` / `test_format_pure` inline their own fixture copies.
→ Pure divergence risk, zero live consumers. Removed `string_pure`'s
copies; `runtime/format_pure.hexa` is now the single SSOT (a pointer
comment replaces the dead block).

## 2. `>=` / `<=` in `format_pure.hexa` (governance g1) — FIXED

4 sites (not just the 2 originally flagged — line numbers had shifted
post-migration): `dot_idx >= 0`, `n <= prec`, `len(spec) >= 2`,
`48 <= ch <= 57`. All confirmed integer comparisons; rewritten to
offset form (`> -1`, `< prec + 1`, `> 1`, `> 47 && < 58`). Explanatory
comments kept token-free so a grep-based g1 lint stays clean.
`test_format_pure` 21/21 unchanged → semantically identical.

## 3. Undeclared `stdlib/strbuf` dependency — FIXED (found in review)

NOT in the original report — caught during the safe review. The strbuf
migration (`233628cc`) made `format_n_pure` call `strbuf_*` but
`format_pure.hexa` did **not** `use "stdlib/strbuf"`; it only worked
because `hexa_full.hexa` happened to import strbuf first. A direct
`use "runtime/format_pure"` hit `Runtime error: undefined function:
strbuf_finish`. Declared the dependency in `format_pure.hexa` itself —
the module is now self-contained. `strbuf` is a zero-dependency pure
wrapper, so the runtime→stdlib edge introduces no cycle.

## Verification (all green)

- `hexa parse` ×2 clean
- **standalone `use "runtime/format_pure"` with `{:.N}` — now works**
  (`a=x b=7 pi=3.14`); was `undefined function: strbuf_finish` before #3
- self-host `hexa run self/main.hexa --version` → `hexa 0.1.0-dispatch`
  (hexa_full's now-double strbuf import is idempotent)
- `test_format_pure` ALL PASS · `test_string_pure` ALL PASS
- `hxc_a35 --selftest` 11 PASS / 0 FAIL

## Cross-refs

- Parent: `inbox/patches/string-concat-in-unbounded-loop-quadratic-rss.md`
- Migration that surfaced this: `233628cc` (+ merge `b6aa40e2`)
- Resolution: `9f621602` / merge `03f1a460`
- Original (filed) copy: `stage2-verify:incoming/patches/format-n-pure-dup-and-ge-le-in-format-pure.md`
  (pre-`incoming→inbox` rename; this is the resolved copy on `main`)
