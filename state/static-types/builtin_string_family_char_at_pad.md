# static-types — builtin string-family scalar returns (char_at / pad_start / pad_end)

## Rung
Extend `_types_builtin_method_ret` (compiler/check/types.hexa) with the 3 remaining
MONOMORPHIC scalar-string builtins. Synergy sibling of the array-repr rung
(#4737/#4745: split/lines/bytes/chars). NO new diagnostic code — reuses the
existing return-place HX3004 / typed-let HX3011 rungs. HX3049 stays free.

## Reference-match (runtime bodies read at source)
- `char_at` → self/codegen.hexa gen2_method_builtin emits `str_char_at` →
  `hexa_str_char_at` (self/runtime_core.c:5198). Body returns `hexa_str(buf)`
  (single-char) on success and `hexa_str("")` on a non-string receiver / empty;
  OOB THROWS. Every non-throw path returns TAG_STR → monomorphic, receiver-
  INDEPENDENT string. Scalar mirror of chars()'s [string] element (runtime uses
  TAG_STR for single chars — a [char]/char element would false-reject a valid
  string sink, so we mint `_types_t_string()`, not char).
- `pad_start` → emits `str_pad_left` (self/codegen.hexa:10263) — the SAME runtime
  symbol as the already-typed `pad_left`. → string.
- `pad_end` → emits `str_pad_right` (self/codegen.hexa:10266) — SAME symbol as
  `pad_right`. → string. (pad_left/pad_right kept for backward compat; pad_start/
  pad_end are the JS/Python-idiomatic names — anima M4 hxa-20260423-003.)

## SKIPPED (not monomorphic — measured, not assumed)
- `sum` → `hexa_sum` (self/runtime.c:12952) returns `hexa_int` OR `hexa_float`
  by ELEMENT VALUES (`has_float` scan) → polymorphic. Cannot type without a
  false-reject on the other tag. Same for `product`, `max`, `min`.
- `keys/values/map/filter/enumerate/reversed/sorted/…` → polymorphic element or
  receiver-dependent → stay unknown (documented conservative under-reject).

## Discipline
- byteeq-neutral: types erase at MIR; severity never reaches codegen. PR-CI
  byteeq 3-target is the proof.
- FP=0 by construction: corpus census — `.char_at(` = 64 in-tree uses, all
  string-context (compares to string literals + one untyped-param arg
  `_is_c_ident_char(c)` → HX3003 needs a KNOWN param type, untyped → no fire);
  `.pad_start(`/`.pad_end(` = 0 in-tree uses. Zero numeric sinks. A genuine
  `-> i64 { return s.char_at(i) }` mismatch now correctly REJECTs (true positive).

## Test (types_test contract)
Cases (co)–(cr) — return-place HX3004:
- (co) char_at→string ACCEPT (0 HX3004)
- (cp) char_at→i64 MISMATCH (1 HX3004) — PROVES char_at=string, not i64
- (cq) pad_start→string ACCEPT (0 HX3004)
- (cr) pad_end→string ACCEPT (0 HX3004)

## Verdict
Table-extension synergy, not a new REJECT rung (the byteeq-neutral REJECT
frontier is CLOSED per WALL-A convergence). This is the inference-table axis.

## Next ① round
See depletion analysis in the PR: the remaining untyped builtins are all
polymorphic (element/receiver-dependent) — the monomorphic scalar/array subset
is now EXHAUSTED (i64/f64/bool/string scalars + [string]/[i64] arrays + these 3).
