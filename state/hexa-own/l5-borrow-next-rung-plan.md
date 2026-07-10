# HX3052 — E0505/E0504 move-out-of-captured-value-while-borrowed (L5-E14)

Base: origin/main `25057d1b5`. Gate: `HEXA_BORROWCK` (default-OFF), STRICT re-band via `HEXA_BORROWCK_STRICT`. Next-free code = **HX3052** (HX3050/HX3051 taken by unused-let/unused-assign).

## Why this rung
The closure lane already ships **HX3037** (E0507 capture-MOVE of an `@own` bare-ident inside a closure body) but it emits report-only and **never loan-scans the captured name**. So the intersection `let r = &xs; let f = fn(n){ sink(xs) }` — a capture-move of `xs` **while `xs` is borrowed by `r`** — is silent. rustc reports **E0505** ("cannot move out of `xs` because it is borrowed"; closure-specific lineage E0504) here, not E0507. It is per-fn expressible because the enclosing loan registry `_bck_ref_*` is live at the closure-lower site.

> ⚠️ **HONEST FP FRAMING (adversarial-review correction — state/hexa-own/frontier-r1-review-verdicts.md):** this rung is **NOT guaranteed-x0-FP**. Its gate `_bck_ref_find_write_through` (hir_to_mir.hexa:1200-1210) is the **flow-insensitive** loan-liveness scan whose own docstring (hir_to_mir.hexa:1196-1199) declares a documented FP class — a loan stays "live" from its `let` to end-of-fn with **no NLL last-use kill** (the M4 last-use pass only serves the HX3014 group lane, not this registry). So HX3052 **inherits HX3040\'s dead-loan FP class**: when `r`\'s last use is BEFORE the closure (modern rustc/NLL ends the borrow there and ACCEPTS the move) HX3052 still fires. Concrete FP (rustc accepts, HX3052 rejects): `fn hz(){ let xs=[1,2,3]; let r=&xs; println(len(r)); let f=fn(n:i64){ sink(xs) }; f(1) }`. **Parity target = pre-NLL E0505 / conservative-loud-over-quiet** (E2/E3/E4 lane posture), NOT NLL-precise E0505 — do not claim zero-FP.

Sound in hexa: closures capture by heap pointer (`hir_to_mir.hexa:3588-3592` — "env slot aliases the enclosing binding"), so the first call's `@own` move-out invalidates the enclosing loan — exactly the E0505 hazard.

## Infra reused (no new dataflow axis, no schema-add)
- `_bck_closure_capture_move_scan` (hir_to_mir.hexa:3595) — the read-only HExpr walk, called at `_lower_closure` line 7237 under `if _bck_active` guard.
- `_bck_ref_find_write_through(origin)` (hir_to_mir.hexa:1200) — live-loan-of-origin scan, already called at the HX3040 non-call move sites (4756/5240/5647).
- `_bck_ref_names/_bck_ref_mut/_bck_ref_lines` loan-registry columns.
- `_bck_e_lines/_bck_e_cols` shared same-site dedup (HX3037/HX3040 already share it).

## Edits
1. **hir_to_mir.hexa:3611** — replace the bare `_bck_emit_capture_move(...)` with a loan-scan collapse: if `_bck_ref_find_write_through(nm) >= 0` emit the new HX3052, else emit HX3037 as today. (Existing HX3037 tests all lack a `&xs` loan => `-1` => else branch => UNCHANGED.)
2. **hir_to_mir.hexa: after 1508** — new emitter `_bck_emit_capture_move_borrowed(origin, callee, name, borrow_mut, borrow_line, clo_line, sp)`, clone of `_bck_emit_move_while_borrowed_nc` (1574) with `diag_new("HX3052")`, args origin/callee/name/borrow_kind/borrow_line/closure_line, sharing `_bck_e_*` dedup + STRICT re-band.
3. **catalog.hexa: after 765** — new DiagSpec HX3052, Warning/S3/FixItKind::None, template `cannot move out of `{origin}` into the closure (line {closure_line}) because it is borrowed — `{name}` holds a {borrow_kind} loan of it (line {borrow_line})`, explain cites E0505/E0504, HX3040 sibling, by-pointer soundness, double-gate corpus-clean, HX3037 collapse. Keep parity 96/96.
4. **borrowck_test.hexa** — 3 source builders + `_run_capture_move_borrowed_probe` (counts HX3052; stray check auto-asserts HX3037==0), dispatched after line 2930.

## Fixtures
- **positive** `hz_clo_capture_move_borrowed`: `fn sink(@own v:[i64]){println(len(v))}` + `fn hz(){ let xs=[1,2,3]; let r=&xs; let f=fn(n:i64){ sink(xs) }; f(1); println(len(r)) }` => HX3052 x1, HX3037 x0.
- **positive/mutable** `hz_clo_capture_move_mut_borrow`: `let r=&mut xs` => HX3052 x1 (borrow_kind=mutable).
- **control (collapse boundary)** `fp_clo_capture_move_no_loan`: same body, NO `let r=&xs` => HX3037 x1, HX3052 x0 (proves no over-broadening).
- **KNOWN-FP witness (dead-loan / NLL last-use)** `fp_clo_dead_loan_before_closure`: `fn hz(){ let xs=[1,2,3]; let r=&xs; println(len(r)); let f=fn(n:i64){ sink(xs) }; f(1) }` — `r`\'s last use precedes the closure => rustc/NLL ACCEPTS => **HX3052 x1 = a documented FALSE POSITIVE** (flow-insensitive loan liveness, inherited HX3040 class). Recorded as a KNOWN-FP, NOT a want-0. The `fp_clo_capture_move_no_loan` control only removes the loan entirely and does NOT exercise this FP vector.
- OFF sweep: all new probes want 0. STRICT: error-band == want.

## Verify gate (pool)
1. `HEXA_BORROWCK=1` runner => positive x1 / control HX3037 x1 / HX3052 x0, every stray-count 0.
2. `HEXA_BORROWCK_STRICT=1` => HX3052 error-band == want.
3. Flag-unset OFF sweep => new probes want 0 (byteeq witness).
4. `grep -c 'DiagSpec {'` == `grep -c 'fix_it_kind:'` == 96; PR-CI byteeq 3-target + gen3=gen4 + install.sh smoke GREEN on OFF path.

## Byteeq neutrality
Edit (1) is inside a scanner only reached under `if _bck_active` (7236); flag-OFF => never runs => identical diag stream => identical .text. (2) dead code when OFF. (3) catalog metadata, never consulted unless a HX3052 diag is emitted (none when OFF). gen3=gen4 holds; even flag-ON the delta is 0 on real source (double gate @own + live `&` loan, both 0-adoption). Same posture as HX3037/HX3040/HX3042.

## Kill / walls
- **Kill**: positive fixture => HX3052 x0 means `_bck_ref_*` not live at 7237 (would need cross-frame state). Source says it IS live ("BEFORE the loan pass is suspended", 7233); fallback = extend HX3040 non-call coverage instead.
- **Walled higher-leverage (not chosen)**: E0594 field/index-assign-to-immutable is corpus-FIRING but needs a census GO/NO-GO (is `mut` required for place-writes on shared handles?) — not guaranteed-x0-FP. Field-disjoint borrows need place projections in MIR Operand (schema wall). Use-after-move-into-closure is unsound per-fn (by-pointer capture => move at deferred call, not capture).