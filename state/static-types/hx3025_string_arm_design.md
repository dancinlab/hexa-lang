# R1 — HX3025 string-arm extension (round4 §3 R1)

Label **(an)** · branch `feat/st-hx3025-string-arm` · NO new HX code (extends existing HX3025).

## What

`s[i]` GET on a KNOWN `string` base is now a REJECT (HX3025, Rust E0608), joining the
already-landed int/float/bool/char scalar arms. This is an extension of the existing HX3025
site, not a new diagnostic — spec structure is unchanged, so the catalog uniqueness gate is N/A.

## Why it is a legal REJECT

An `s[i]` GET can never succeed at runtime: the C-substrate `hexa_array_get` wrapper detects
the string tag (`HX_IS_STR`) and throws `string[i]: use .chars()[i] or substring`
(`self/runtime_core_emit.hexa` ~3395 `hexa_throw`). Same aborting mechanism as the scalar arms
→ the "guaranteed-runtime-error → REJECT" contract (identical to HX3024/HX3026) covers it.

Conservative under-reject preserved: fires ONLY for a KNOWN string base; unknown/unit/HexaVal/
array/map/named all stay SILENT. No separate corpus census is required — the census that the
older comment deferred is unnecessary because the checker only fires on a KNOWN-string base, so
corpus-clean is proven by the PR-CI build itself (the (ai)/(al) landing method).

## Diffs

1. `compiler/check/types.hexa` :3355 — appended `|| base_t.kind == "string"` to the scalar-index
   HX3025 condition; the v1-exclude comment (~:3347) replaced with the runtime rationale.
2. `compiler/diag/catalog.hexa` :521 — HX3025 explain: "string is deliberately EXCLUDED in v1"
   replaced with coverage wording (chars()/substring fix guidance).
3. `.github/workflows/static-types-corpus.yml` :175 — census regex
   `HX30(1[167]|2[45])` → `HX30(1[167]|2[4-6])`. ALSO fixes #4618's missing HX3026 in the grep.
4. `compiler/check/types_test.hexa` — new label **(an)**, inserted after the (am) block, before
   the summary: string `s[0]` → 1 HX3025 error; `cs = s.chars()` then `cs[0]` → clean (unknown
   local base, under-reject silent); `*_test.hexa` fixture clone → 1 HX3025 warning (carve-out).

## byteeq argument

types.hexa is a diagnostic-only pass (main.hexa `type_check` yields the diag array only; `lower`
restarts from raw AST) → result-type change cannot touch emitted bytes directly. The only new
Error fires on a KNOWN string base, so corpus-clean is proven by the PR-CI build; the fixture
path stays in the Warning band via `_types_strict_for`.

## Verification

NON-CI `compiler/check/types_test.hexa` requires a pool bare-run on BOTH backends before merge
(aprime-only = FALSE-green). Deferred to the orchestrator per round4 §4.
