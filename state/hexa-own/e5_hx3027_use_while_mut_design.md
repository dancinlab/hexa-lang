# HEXA-OWN L5-E5 — HX3027 use-while-mutably-borrowed (Rust E0503)

Rung R3 of `state/hexa-own/round3_dual_lane_batch_plan.json` §3. opt-in
(`HEXA_BORROWCK=1`), byteeq-neutral (all new sites gated on `_bck_active`,
default false). `types.hexa` UNTOUCHED.

## What

The E-ladder's next rung after E4 (E4 changelog: "다음 rung=E5"). E1/E2/E3/E4
cover E0515 / E0502 / E0506; the remaining rustc sibling that fits the
substrate (no place projection needed) is **E0503 — "cannot use `x` because it
was mutably borrowed"**: a READ (use of value) of `x` while a live `&mut x` loan
exists. This is the design decision of the batch plan (E5 was never spec'd).

Unlike E4 write-through (invalidates BOTH `&`/`&mut` loans — any write breaks
aliasing), **E0503 keys on the mutability bit**: a shared `&x` loan permits
concurrent reads, so a use of `x` while only shared loans are live is SILENT.

## Diffs (all re-anchored vs origin/main `ef0599b61`)

Pure clone-extension of the merged E4 write-through machinery.

1. `compiler/lower/hir_to_mir.hexa`
   - `_bck_in_borrow_rhs` module flag (near `_bck_ref_mut`).
   - `_bck_ref_find_mut_loan(origin)` — the E4 write-through END-scan NARROWED
     with `_bck_ref_mut[i]` (mutable loans only). Cloned after
     `_bck_ref_find_write_through`.
   - `_bck_emit_use_while_mut(origin,name,borrow_mut,borrow_line,sp)` — HX3027
     emit + same-site dedup + STRICT caller-severity-override
     (`diag_with_severity`, builder.hexa:244 contract). Cloned after
     `_bck_emit_write_through`.
   - `_bck_check_use` — the E5 rule inserted **before** the `ti < 0` early-return
     (the origin `let mut x = 5` is a scalar, never group-tracked, so keying on
     the loan registry must run before the aggregate-group guard). Suppressed
     when `_bck_in_borrow_rhs`.
   - unop arm — sets `_bck_in_borrow_rhs` (save/restore) around lowering the
     inner ident of a `&`/`&mut` unop.
2. `compiler/diag/catalog.hexa` — HX3027 DiagSpec after HX3023 (mirrors HX3023:
   Severity::Warning, STRICT→Error, flow-insensitive FP class, Rust E0503 cite).
   catalog-uniqueness gate: 61 codes, all unique.
3. `compiler/check/borrowck_test.hexa` — `_run_use_while_mut_probe` +
   `_run_reborrow_suppress_probe` + sources.
4. `ARCHITECTURE.json` — L5 cell current-ized (E1–E5 all merged; the stale
   "#4557 미배선" removed). Single-line Edit (record-only diff).

## §5.2 double-fire audit (REQUIRED by the spec)

- **borrow-RHS self-fire (first borrow)**: `let m = &mut x` lowers the RHS
  `&mut x` at hir_to_mir.hexa (let-arm, `_lower_hexpr(children[0])`) **BEFORE**
  `_bck_ref_track` registers the loan → at the inner-ident read the loan does
  not exist yet → no self-fire even without the flag. Belt-and-suspenders: the
  flag suppresses it anyway.
- **borrow-RHS double-fire (RE-borrow) — CONFIRMED, SUPPRESSION ADDED**:
  `let m = &mut x  let n = &mut x`. When the SECOND `&mut x` RHS is lowered, the
  first loan `m` IS registered → the inner-ident read of `x` matches
  `_bck_ref_find_mut_loan("x")` and WITHOUT suppression would fire HX3027, while
  registration ALSO fires HX3021 (E3 borrow-conflict) → **double-report of one
  mistake**. Semantically E0503 is use-of-VALUE, not address-taking; a re-borrow
  is E0499/E0502 (our HX3021). Fixed with `_bck_in_borrow_rhs`: the re-borrow is
  E3's alone. Probe `fp_reborrow_suppress` asserts **HX3027 = 0, HX3021 = 1**.
- **assign-LHS double-fire (E4)**: an ident assign-LHS (`x = 5`) is resolved via
  `_mir_lookup(lhs.text)` and is **NOT** lowered through `_lower_hexpr` → the
  ident READ hook (`_bck_check_use`) is never reached for the LHS, so E5 cannot
  fire on a write target. E4 write-through (HX3023) is the sole reporter of
  `x = 5` while borrowed. No double-fire; no suppression needed. CLEAN.

## Test matrix (`_run_use_while_mut_probe`, keyed HX3027)

| probe | source | ON | reason |
|---|---|---|---|
| hz_use_while_mut | `let m=&mut x  let y=x+1` | 1 | read x while `&mut` live |
| fp_use_shared | `let r=&x  let y=x` | 0 | shared loan permits reads |
| fp_use_after_kill | `let mut m=&mut x  m=0  let y=x` | 0 | loan killed pre-read |
| fp_use_loan_name | `let m=&mut x  let y=m` | 0 | reads binding, not origin |
| fp_reborrow_suppress | `let m=&mut x  let n=&mut x` | 0 (HX3021=1) | E3 owns re-borrow |

OFF sweep → all 0 (empty stream). STRICT → HX3027 count preserved, every emit
Error-band (`_count_error_band == want`).

## Verification

`borrowck_test.hexa` is NON-CI (hand-run smoke). Requires **pool 3-mode bare-run**
(`aiden`/`summer`, branch-built hexa): OFF / `HEXA_BORROWCK=1` / `HEXA_BORROWCK_STRICT=1`,
BOTH backends (aprime-only = FALSE-green). byteeq 3-target GREEN + selfhost-gates
via PR CI.
