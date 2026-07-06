# R6 Rung A — call-arg borrow conflict scan (E0499/E0502 · HEXA-OWN opt-in)

## What
Extend the E2+E3 borrow-conflict rule (HX3021/E0502 · HX3028/E0499) to borrows
passed as **call arguments**. No new HX code — reuses HX3021/HX3028 emit paths.

## §0 mechanism (from round6_dual_lane_batch_plan §0, O-c row)
`&`/`&mut` borrows were registered + conflict-scanned **only at the let-RHS site**
(`_bck_ref_find_conflict` :756, called from the let arm ~:3304). A borrow passed
as a **call argument** (`f(&mut x, &mut x)` / `f(&x)` while `&mut x` live) was
never scanned → **silent false-negative**.

## Implementation
`compiler/lower/hir_to_mir.hexa` — call arm arg-lowering loop (after the @own move
classification block, ~:2652). For each arg `e.children[i]` that is a bare
`&ident` / `&mut ident` unop over a non-global ident, mirror the let-RHS
scan+register 1:1:
1. `_bck_ref_find_conflict(origin, new_mut)` **before** registering (never matches
   itself).
2. conflict → E3.9 split: both-mut → `_bck_emit_double_mut` (HX3028), else
   `_bck_emit_borrow_conflict` (HX3021).
3. `_bck_ref_track` under a synthetic `$callarg:line:col` name — unique per arg
   site (one AST node = one span), unforgeable as a user binding (leading `$`), so
   a second `&mut x` in the SAME arg list finds the first as a live loan
   (newest-per-name-wins).

Conservative: only bare-ident borrow operands; field/index/call-nested borrow →
silent skip. The `&`/`&mut` unop lowering (:2398) already sets `_bck_in_borrow_rhs`
during the inner ident read, so the arg READ never fires a spurious HX3027.

## Byteeq-neutral
All new work is gated on `_bck_active` (default false — opt-in HEXA_BORROWCK /
HEXA_BORROWCK_STRICT). Flag-OFF path never touches the loan registry → the diag
stream and emitted binary are byte-identical.

## Test (compiler/check/borrowck_test.hexa)
- `hz_callarg_double_mut` — `f(&mut x, &mut x)` → HX3028 ×1 (ON), 0 (OFF), Error-band (STRICT)
- `hz_callarg_mut_while_shared` — `let r = &x; f(&mut x)` → HX3021 ×1
- `fp_callarg_two_shared` — `f(&x, &x)` → 0

## Anchors verified (origin/main cc2e19a80)
- `_bck_ref_find_conflict` — :756
- let-RHS registration/scan — :3286–3337 (E3.9 split :3316–3326)
- call arm arg-lowering loop — :2615–2653 (@own move block :2627)
- `_bck_emit_borrow_conflict` :822 · `_bck_emit_double_mut` :862 · `_bck_ref_track` :726

## Verification
NON-CI pool 3-mode (aiden) — OFF/ON/STRICT.
