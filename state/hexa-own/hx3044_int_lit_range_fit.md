# HX3044 — int-literal range-fit REJECT (Warning-band MVP)

## What
Closes the "range-fit deferred" TODO in `compiler/check/types.hexa`'s int-literal
assignability arm. A positive integer literal assigned to a narrower signed `iN`
annotation whose value exceeds the width's signed MAX now emits `HX3044`
(Warning band) at the let-check site.

Reference-matched to rustc's `overflowing_literals` lint
(`let x: i8 = 300` → "literal out of range for `i8`", range `-128..=127`).

## Predicate
`_types_int_lit_fits(expected: Type, src: Expr) -> bool` (types.hexa) — scans the
literal's `.text` digits DIRECTLY (decimal, or `0x`/`0X` hex; `_` separators
skipped defensively — the lexer already strips them) with an OVERFLOW-GUARDED
i64 accumulation (stage0 has no bigint):

- guard `val > (max - digit) / base` checked BEFORE each multiply-add; never
  itself overflows since `max` is i64-representable and `digit < base`.
- digit→value via explicit `==` if-ladders (`_types_dec_digit_val` /
  `_types_hex_digit_val`, the `is_digit_ch` lexer idiom) — NO `to_int`, no char
  arithmetic assumption.
- FP-guard: any unrecognised form (empty text, stray non-digit) → returns
  `true` (fits) → never a false REJECT.

## Bounds table (signed, positive-magnitude MAX — `_types_int_max_for`)
| type | MIN | MAX |
|------|-----|-----|
| i8   | -128 | 127 |
| i16  | -32768 | 32767 |
| i32  | -2147483648 | 2147483647 |
| i64  | -9223372036854775808 | 9223372036854775807 |

Width types i8/i16/i32/i64 ARE representable as `integer_kind`
(`_is_integer_kind` / `_types_lower_type_ref` map them), so range-fit is
expressible. Unsigned `u*` are a `named:<n>` sentinel (NOT integer_kind) → out
of scope; this rung is SIGNED-iN only.

## Wiring
- `_emit_hx3044(expected, sp, out)` — emits `Severity::Warning` ALWAYS
  (does NOT use `_types_strict_for`), so it can never abort the shipping path.
- Fired at the r1 literal arm of the let-check site (types.hexa `_infer_expr`
  Let arm, under the always-on `_types_static_on` FLIP-3 flagless gate),
  INDEPENDENT of HX3011: `let x: i8 = 300` IS kind-assignable (integer-lit →
  integer-kind coercion accepts it) so HX3011 stays silent while HX3044 catches
  the value overflow.
- catalog `HX3044` DiagSpec added (diag/catalog.hexa, next-free after HX3043);
  catalog-hexa-1 parity held: `DiagSpec {` count == `fix_it_kind:` count == 88.

## Corpus-0 audit
`git grep` for narrow-int (`i8`/`i16`/`i32`) let bindings with an integer-literal
RHS across the shipping tree (excluding `*_test.hexa` + `compiler/test/`):
**0 real bindings** — every hit is inside a comment/docstring. hexa's shipping
tree is i64-only, so HX3044 fires on ZERO real source (corpus-0 by construction).
Types erase at MIR → codegen `.text` byte-identical → byteeq-3-target neutral is
the proof (no separate build needed).

## Tests (types_test.hexa, self-contained modules, labels bd–bh)
- (bd) `let x: i8 = 300`  → 1 HX3044 (Warning)
- (be) `let x: i8 = 127`  → 0 (i8::MAX boundary fit)
- (bf) `let x: i64 = 9223372036854775807` → 0 (i64::MAX; accumulator reaches MAX
  exactly, no wrap)
- (bg) `let x: i32 = 2147483648` → 1 HX3044 (Warning; i32::MAX+1)
- (bh) `let x: i32 = 2147483647` → 0 (i32::MAX boundary fit)

## Scope / follow-up
- **Warning-band MVP**; STRICT-Error re-band + multi-site fan-out
  (return / assign / field / call-arg) = follow-up.
- **Positive literals only** — a negative literal arrives as
  `UnOp(-, LiteralInt)` (not `_types_is_lit_int`), so `let x: i8 = -128` is a
  documented follow-up.
