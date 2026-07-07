# HX3042 — use-of-partially-moved-value (Rust E0382) · round10 rung

**Status:** implemented, opt-in (`HEXA_BORROWCK=1`), byteeq-neutral. Branch
`feat/borrowck-e0382-hx3042-partial-move` off `origin/main` (`ab79e1f64`, round9
#4669; the only newer commit `387deda6e` is an unrelated zeroc arm64 change — the
three target files are byte-identical between the two).

## The "place-granular MovePathData new axis" fear — FALSIFIED

The census verdict feared E0382 needed a HIGH-cost place-granular `MovePathData`
move-path tree (a new axis). Fable measured this against live source and
falsified it, the same way the trilogy fears were falsified:

- **whole-binding use-after-move is already double-covered**: HX3014
  (`_bck_check_use` Rule 2 intra-block + `_bck_nll_check` cross-block, flow-
  sensitive) and HX3012 (typecheck layer, flow-insensitive). So the "safe
  subset" hypothesis (whole-move then re-use) is NOT a new rung — it ships.
- **the only real uncovered residual = field-projection partial move**, and it
  needs no move-path tree: the ONLY move source on the hexa surface is the @own
  call-arg (`_bck_note_move` records whole-binding only; `:485-487` documents
  "no place projections"). So a **flat (group, field-string) pair** suffices.
- index projections are terminated by round9 HX3038 (E0508) / HX3039 (E0507) at
  the move site — and **rustc also builds no per-element move path** for arrays
  (E0508 forbids the move), so this is reference-consistent, not a hole.

Net: **one rung, ~230 LOC**, reusing the shipped `_bcki_check` (HX3035
MaybeUninitialized) gen/kill dataflow skeleton — NOT a new axis.

## The gap it closes

`sink(s.a)` where `s` is an OWNED (non-borrowed) struct local and the callee's
param is `@own`. HX3034's field branch (`:3523`) fires ONLY when the base is a
LIVE ref; an owned base was fully silent (no diag, no move state). After such a
move, `use(s.a)` (field re-read) or `use(s)` (whole use) → should be E0382.

## Mechanism — moved-lane mirror of `_bcki_check`

Reference-matched to rustc `MaybeInitializedPlaces` (move = kill, assign = gen),
inverted to a maybe-moved MAY forward analysis:

- seed = 0 (every place starts initialized — the DUAL of the uninit lane seed 1)
- gen = MOVE (an @own call-arg move of `s.f`)
- kill = a `s.f = v` field reinit
- same bitset, OR-join over `Block.preds`, same convergence guard (`blocks*4+8`)
- keyed by a flat `(group, field-string)` pair; block transfer = last-event-wins

## Wiring (all `_bck_active`-gated, report-only — no MIR mutation)

| step | anchor (symbol) | change |
|---|---|---|
| S1 | after HX3035 registry (`_bcki_e_cols`) | `_bck_pm_*` event log + `_bck_pm_field` ctx + dedup arrays; reset in `_bck_reset_fn` |
| S2 | HX3034 field branch inner `if _bk_mo_ri>=0` (`_bck_emit_move_out_of_borrow`) | add owned-local `else` → `_bck_pm_note_move` (group-keyed; `_mir_lookup>=0`) |
| S3 | field-read arm (`if k=="field"`, before `_lower_hexpr(ctx, e.children[0])`) | ident-base-gated `_bck_pm_field` save/set/restore |
| S4 | `_bck_check_use` (beside M4 push) | `_bck_pm_note_use` gated by `!_bcki_in_place_base` (NOT `_bck_in_borrow_rhs` — `&s` of a partially-moved value is E0382 too) |
| S5 | field_set arm (beside `_bcki_note_init`) | field-specific `_bck_pm_note_kill` |
| S6 | end-of-fn (beside `_bcki_check(entry_id)`) | `_bck_pm_check()` fixpoint + emit |
| S7 | beside `_bcki_check` | `_bck_pm_check` body + `_bck_pm_note_*` + `_bck_emit_use_after_move_pm` (clone of `_bcki_emit_uninit_use`) |
| catalog | after HX3041 DiagSpec | HX3042 complete block (DiagSpec/fix_it_kind 85→86); HX3041 explain fwd-ref `HX3042`→`next free HX30xx` |
| test | before `fn main` | `_run_pm_probe` + 11 probes |

Order-consistency is automatic: `sink(s.a)`'s own base-read USE is logged BEFORE
its MOVE (arg lowering precedes the HX3034 branch), so the move site is silent; a
later use lands after the MOVE and fires. Loop-carried is caught by the back-edge.

## Conservative boundaries (per rustc / honesty)

- single-ident base only; nested `s.a.b` as a move source = silent (like HX3034)
- group-untracked base (call-returned struct), module global, non-@own arg =
  silent; `let y = s.a` is NOT a move (handle-copy)
- a may-join (reinit on ONE branch) FIRES — the sole point more conservative than
  rustc's must-init, tolerated in the write-lane advisory band (pure theoretical
  FP: @own adoption = 0)
- hexa has no Drop, so E0509's drop-of-partially-moved axis is absent

## byteeq / corpus

@own carrier corpus adoption = 0 → even flag-ON the HX3042 diag delta is 0
(corpus-clean). Flag-OFF path never touches any `_bck_pm_*` array → emitted bytes
+ diag stream byte-identical, gen3≡gen4 preserved.

## Companion tests (`_run_pm_probe`, keyed on HX3042 + probe-hygiene stray=0)

hz_pm_use_field / hz_pm_use_whole / hz_pm_double_move / hz_pm_alias /
xb_pm_branch_join (may-join) / xb_pm_loop_carried (back-edge) → ×1 ON;
fp_pm_move_site_only / fp_pm_disjoint / fp_pm_reinit / fp_pm_noown /
fp_pm_global → 0. OFF all 0; STRICT error-band == HX3042 count.
