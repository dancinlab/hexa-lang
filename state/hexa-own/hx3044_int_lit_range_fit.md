# HX3044 — int-literal range-fit REJECT (STRICT + multi-site fan-out + negative-lit)

## What
A positive OR negative integer literal coerced to a narrower signed `iN` type
whose value exceeds the width's range emits `HX3044` at EVERY coercion site.
Reference-matched to rustc's `overflowing_literals` lint
(`let x: i8 = 300` → "literal out of range for `i8`", range `-128..=127`).

**Status: DONE** — STRICT-Error re-band ✅ · multi-site fan-out ✅ ·
negative-literal ✅. (#4699 shipped the Warning-band MVP at the let-site only;
this follow-up completes it.)

## Predicate (types.hexa)
`_types_int_lit_overflows(expected: Type, src: Expr) -> bool` — the single
fan-out predicate wired at all sites. TRUE iff `src` is an int-literal (or the
`UnOp(-)` negation of one) whose value overflows the narrow signed `expected`.
- positive lit → magnitude bounded by MAX (`_types_int_max_for`).
- negated lit `UnOp("-", LiteralInt)` → magnitude bounded by abs(MIN)=MAX+1
  (`_types_int_absmin_for`): i8 accepts `-128`, rejects `-129` / `+128`.
- i64 negated boundary → conservatively accepted (abs(i64::MIN)=2^63 not
  i64-representable; the lexer already bounds i64 magnitude).
- non-integer target / non-int-literal / unrecognised form → FALSE (no fire).

Digit-scan core `_types_int_text_fits(text, maxv)` (extracted from the old
`_types_int_lit_fits`) does the overflow-guarded i64 accumulation shared by the
positive-MAX and negated-absmin paths. `val > (maxv - digit)/base` guard checked
BEFORE each multiply-add; never itself overflows. FP-guard: any unrecognised form
returns true (fits) → never a false REJECT.

## Bounds table (signed)
| type | MIN | MAX | negated-absmin bound |
|------|-----|-----|-----|
| i8   | -128 | 127 | 128 |
| i16  | -32768 | 32767 | 32768 |
| i32  | -2147483648 | 2147483647 | 2147483648 |
| i64  | -9223372036854775808 | 9223372036854775807 | (tolerated) |

Unsigned `u*` are a `named:<n>` sentinel (NOT integer_kind) → out of scope.

## Fan-out sites wired (types.hexa)
| site | location | expected type | literal expr |
|------|----------|---------------|--------------|
| 0  let-binding (positive) | `_infer_expr` Let lit arm | `declared` | `rhs` |
| 0b let-binding (negated)  | `_infer_expr` Let binop/unop arm | `declared` | `rhs` |
| A  return | `_infer_expr` Return arm | `frame_ret` (ctx.fn_return) | `val_src` |
| B  assign | `_infer_expr` Assign ident-LHS arm | `lhs_t` | `e.children[1]` |
| C  struct field-init | `_infer_expr` StructLit arm | `field_t` | `val` |
| D  call-arg | `_types_check_call` arg loop | `want` (param type) | `e.children[1+k]` |

All sites INDEPENDENT of the sibling kind-mismatch diagnostic (HX3011 / HX3003 /
HX3004): an overflowing literal IS kind-assignable (int-lit → int-kind), so the
mismatch diag stays silent while HX3044 catches the value overflow.

No site SKIPPED (all four named fan sites had both expected-type + literal-expr
available). Additional coercion sites NOT in the four named (field-place assign
`s.f = lit`, index-place assign `a[i] = lit`) were left unwired — out of this
follow-up's named scope; low value (corpus-0) and can be a trivial later add.

## Negated-literal coercion fix (adjacent)
`_types_assignable` gained a negated-int-literal arm: `UnOp(-, LiteralInt)` with
both sides integer-kind coerces (rustc treats `-128` as an int literal). Without
it the let binop/unop arm false-fired HX3011 ("mismatched i8 vs i64") on the
valid `let x: i8 = -128`. Pure LOOSENING (removes a false REJECT); only reachable
for a narrow-int negated literal (same-kind i64 already returns via
`_types_equal`) → corpus-0 → real-source diagnostic stream unchanged
(byteeq-neutral). Verified by (bi)/(bj) asserting 0 HX3011.

## STRICT-Error re-band
- #4699 shipped `_emit_hx3044` hardcoding `Severity::Warning` ALWAYS + catalog
  `severity: Severity::Warning`. This follow-up re-bands to the FLIP-3 convention:
  `_emit_hx3044` now uses `_types_strict_for(sp.file)` (real source → Error via
  catalog default, `*_test.hexa`/`compiler/test/` fixture → Warning), and the
  catalog `HX3044` severity is flipped `Warning → Error` (same policy as
  HX3011/HX3024/HX3043).
- Safe precisely because corpus is 0 → no real-source site can abort shipping.

## Corpus-0 audit (per-site, shipping tree excl. `*_test.hexa` + `compiler/test/`)
- **i8/i16 annotations: 0** (all positions — let/return/param/field). Zero.
- **narrow-int struct fields: 0**.
- **i32 usages**: only fn return types / params in akida routers etc.; returns
  are small exit codes (0/1/2); no i32 let/field receives a large literal.
- **large literals (≥2^31)**: all live in i64 RNG/hash/timestamp context
  (`compiler/drill/*`, `emerge.hexa` Knuth-hash, `status_archive` timestamps) —
  never assigned to a narrow-int annotation.
- ⇒ **0 overflowing narrow-int literals at every fan site.** Types erase at MIR
  → codegen `.text` byte-identical → byteeq-3-target neutral is the proof (no
  aiden build needed for byteeq; test run on aiden verifies contract).

## Tests (types_test.hexa, self-contained balanced modules, NEVER union)
- (bd) `let x: i8 = 300` → 1 HX3044 **Error** (re-banded; `case_bd.hexa` real path)
- (be) `let x: i8 = 127` → 0 (i8::MAX boundary)
- (bf) `let x: i64 = 9223372036854775807` → 0 (i64::MAX, no wrap)
- (bg) `let x: i32 = 2147483648` → 1 HX3044 **Error** (re-banded; i32::MAX+1)
- (bh) `let x: i32 = 2147483647` → 0 (i32::MAX boundary)
- (bi) `let x: i8 = -128` → 0 (negated-boundary fit) ★new
- (bj) `let x: i8 = -129` → 1 HX3044 Error (negated overflow) ★new
- (bk) `fn f() -> i8 { return 300 }` → 1 HX3044 Error (fan site A) ★new
- (bl) `let x: i8 ; x = 300` → 1 HX3044 Error (fan site B) ★new
- (bm) `struct S { b: i8 } ; S { b: 300 }` → 1 HX3044 Error (fan site C) ★new
- (bn) `fn g(p: i8) ; g(300)` → 1 HX3044 Error (fan site D) ★new

types_test label next-free after this: `bo`. catalog HX3044 reused (no new code);
catalog-hexa-1 parity held 88/88.
