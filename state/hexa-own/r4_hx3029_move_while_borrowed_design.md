# R4 — HX3029 E0505 move-out-while-borrowed (HEXA-OWN, opt-in)

Round4 lane② rung R4. Anchor = origin/main (branched off `55ebb60d7` #4624; spec anchor
`ed1019282` #4623 — re-verified below). R3-dependent: catalog HX3029 lands after HX3028 (E0499);
orchestrator rebases R4 onto R3 before serial merge.

## What
The last no-new-machine crossing of the loan-registry (E2) × move-classification (M3) families.
An `@own` call-arg MOVES the value out of its binding; if a LIVE loan of that origin exists, the
move invalidates the borrow — Rust E0505 "cannot move out of `x` because it is borrowed". Reuses
the existing E4 write-through scan (mutability-blind: a move breaks BOTH `&` and `&mut` loans, the
same aliasing break as E0506) — **zero new move-state machine**.

## Diffs (all gated on `_bck_active`, default OFF → byteeq-neutral)
1. **hir_to_mir.hexa** @own move site (right after `_bck_note_move`, inside the `_bck_own_param`
   block): `let _bk_mvl = _bck_ref_find_write_through(e.children[i].text); if _bk_mvl >= 0 {
   _bck_emit_move_while_borrowed(...) }`.
2. **hir_to_mir.hexa** `_bck_emit_move_while_borrowed` — cloned from `_bck_emit_use_while_mut`,
   HX3029, shared same-site dedup (`_bck_e_lines`/`_bck_e_cols`), STRICT→Error override.
3. **catalog.hexa** HX3029 DiagSpec (Rust E0505), mirroring HX3027's format; inserted after HX3026
   (on rebase onto R3, moves to after HX3028).
4. **borrowck_test.hexa** hand-built HIR probes (`_build_mvb_module` + `_run_mvb`) — #4470 @own
   inline-carrier not landed, so source-level probing is impossible (same constraint as tp_own).
5. **ARCHITECTURE.json** L5 borrow E-ladder cell — E6/HX3029/E0505 appended.

## Dedup contract — "shared-loan primary"
At an `@own` move of `x` with a **`&mut x`** loan live: the arg ident's own READ (lowered a line
before the move classification) fires HX3027 (E0503) at the move span; the shared same-site dedup
then collapses HX3029 into it. Net: a **`&x` (shared)** loan → HX3029×1; a **`&mut x`** loan →
HX3027×1, HX3029×0. `_tsp` sets col=1 uniformly, so the move-site's HX3027 and HX3029 share
exactly (line,col) and dedup fires; the loan `let r=&mut a` is on a different line so it doesn't
false-collide.

## Test (borrowck_test.hexa `_run_mvb`, 3-mode OFF/ON/STRICT)
- `hz_move_while_shared_borrow` (`let r=&a; g(a)`) → HX3029×1
- `fp_move_while_mut_borrow_dedup` (`let r=&mut a; g(a)`) → HX3027×1, HX3029×0 (dedup assert)
- `fp_move_no_borrow` (`g(a)`, no loan) → 0
- OFF → all 0; STRICT → error-band == HX3029+HX3027 count.

## byteeq argument
Every new emit site is behind `_bck_active` (default false), so the default diagnostic stream and
emitted binary are byte-identical. Move classification fires ONLY at `@own` call args, and `@own`
inline-carrier adoption is 0 in the corpus → even flag-ON produces 0 corpus fire (corpus-clean).

## Anchors re-verified (vs current main #4624)
- move site: `_bck_note_move` call at hir_to_mir.hexa (was spec :2497–2503) — confirmed in the call
  arm's arg loop, inside `if _bck_own_param(callee_text, i-1)`.
- `_bck_ref_find_write_through` (spec :779–789) — mutability-blind live-loan scan, confirmed.
- `_bck_emit_use_while_mut` clone source (spec :892–918) — confirmed.
- catalog HX3026 close / HX3027 format (spec :516–532) — confirmed; HX3029 inserted after HX3026.
- test `tp_own_param_move` / `_hx` (spec :843–919 / :795) — confirmed; driver wiring after
  `_run_tp_own()` (spec :1045–1049 drifted to the driver's tp_own call site — re-anchored).

## Divergence from spec
Spec test-file line anchors (:843–919, :1045–1049) drifted because main advanced #4623→#4624; the
named symbols (`tp_own_param_move`, `_hx`, `_run_tp_own`, driver) were re-anchored by grep and match
the spec's intent exactly. Catalog HX3028 (R3) is absent on this branch (branched off main) — HX3029
inserted after HX3026; orchestrator rebase onto R3 resolves the ordering.
