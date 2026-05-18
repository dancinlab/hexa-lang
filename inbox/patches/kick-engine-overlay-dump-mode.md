# Patch request — `hexa kick`/`drill`/`omega` Mk.IX engine: expose overlay content for downstream consumption

**Concept (one per file)**: the Mk.IX 6-stage discovery engine
(`hexa kick` ≡ `hexa drill` ≡ `hexa omega`) currently emits SUMMARY only
to stdout (round counts + JSON status). The generated overlay lines (the
actual discovery content, reported as e.g. `overlay+ 517 lines (pool=0)`)
stay in an internal pool and are NOT exposed to a downstream-readable
output. Downstream consumers (the `dancinlab/anima` project here) cannot
therefore read the engine's discovery proposals.

## Observed (2026-05-19, hexa 0.1.0-dispatch)

`hexa kick --seed "<substantive ≥10 chars>" --rounds 1 --engine mk9`
produces ~10 lines of stdout:

```
HEXA_DRILL_ANTI_HUB_TRACE {"cmd_drill_entry":true, ...}
drill — seed='...' max_rounds=1 engine=mk9
  Mk.IX 6-stage chain (smash → free → absolute → meta → hyper → resonance)
  round 1: smash+414 free+211 abs=0 meta=0 hyper=0 res+26(σ=0.10) total=651
  overlay+ 517 lines (pool=0)
map key 'f_a' not found
map key 'f_b' not found
  max rounds reached (1) — total=651
{"seed":"...","rounds":1,"total":651,"saturated":false,"engine":"mk9","overlay_lines":517}
```

Note `overlay+ 517 lines (pool=0)` — the engine reports 517 generated
lines, but `pool=0` means they are not materialized to a retrievable
output, and the 517 lines are not in stdout.

Reproduced on a second invocation (different substantive seed) — same
shape: many overlay lines reported, zero exposed.

## Why this blocks downstream-consumer use

`dancinlab/anima` uses kick as an exploratory discovery tool seeded on
HEXAD architecture / GOAL frontier questions, then cross-checks the
engine's proposals against the project's own closed-form connection-
point predicates (the established §69 PROPOSES/DISPOSES pattern,
`state/hexad_drill_reconcile_s69_2026_05_18/`). With overlay content
pooled-not-exposed, the DISPOSES step has nothing concrete to evaluate.

The downstream pattern recorded as governance in `anima/AGENTS.tape`
`@D g_kick_autonomous g3_arbiter`: "engine PROPOSES, closed-form
predicate DISPOSES" — currently the PROPOSES half is unreadable.

## Requested primitive (minimal, non-invasive)

A flag (or equivalent) that exposes the overlay content to a
retrievable output. Two stub-shapes any of which would unblock anima:

- `--dump-overlay <path>` — write the N overlay lines to `<path>`
  (one record per line, free-form is fine; JSON or plain).
- `--dump-overlay stdout` — flush the overlay to stdout after the
  round summary, between the `overlay+ N lines` line and the JSON
  status, with a sentinel framing for parsers.

Either is sufficient — anima will parse whichever shape lands. The
load-bearing property is **content exposure**, not a specific format.

## Two minor diagnostic warnings observed (low-signal context)

The same run emitted 2 internal warnings:

```
map key 'f_a' not found
map key 'f_b' not found
```

Mentioned for maintainer context only — not the patch request.

## Constraint (downstream-consumer invariant)

`dancinlab/anima` is a downstream consumer of `hexa-lang`. anima does
NOT edit `hexa-lang` source (anima's `@D g_train_flame_not_pytorch
upstream_downstream_invariant` + hexa-lang `g7/@F f3`). This file is
the patch-request channel; the implementation is for upstream review.

## Cross-link

- `dancinlab/anima` reference: `state/kick_paradigm_breakthrough_s74_2026_05_19/
  {FINDINGS.md, drill_raw.log, blue_falsifier_s74.py}` (the captured
  run + the closed-form B-S74-4 OVERLAY-NOT-IN-STDOUT predicate that
  flags the gap).
- prior reference: `state/hexad_drill_reconcile_s69_2026_05_18/` —
  §69 11-pair sweep on §63 closed-form gap-map; engine corroborated
  classification via stage counts but contributed no specific
  proposals (same root cause).
