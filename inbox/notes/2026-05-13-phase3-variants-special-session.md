# Phase 3 — Port 7 drill variants & special engines (A14-A18, A20-A21)

date: 2026-05-13
branch: main (no commit)
working dir: /Users/ghost/core/hexa-lang
scope: A14 reign · A15 molt · A16 wake · A17 forge · A18 canon · A20 debate · A21 revive

## Summary

7 new compiler dirs added, each with a main module and a hermetic smoke
test that prints `<N>/<N> PASS` + `RESULT: PASS` and exits cleanly with
HOME redirected under `/tmp`. Total `46/46` smoke checks PASS.

## Per-algorithm port

| algo  | source LOC (nexus)          | ported LOC (main+test)        | smoke      | deferred |
|-------|-----------------------------|-------------------------------|-----------|----------|
| reign | run.hexa 4465-4513 ≈ 128    | 247 + 105 = 352               | 8/8 PASS  | drill-bg-dep |
| molt  | run.hexa 4850-4917 ≈ 135    | 166 + 75 = 241                | 6/6 PASS  | drill-bg-dep |
| wake  | run.hexa 4762-4815 ≈ 88     | 135 + 71 = 206                | 3/3 PASS  | drill-bg-dep |
| forge | run.hexa 4985-5073 ≈ 95     | 166 + 78 = 244                | 5/5 PASS  | drill-bg-dep, canon-idem guard simplified |
| canon | run.hexa 5080-5163 ≈ 89     | 162 + 88 = 250 (canon_engine) | 6/6 PASS  | atlas.n6 hash uses overlay size (not rodata sha) |
| debate| drill/adversarial_debate.hexa 420 + run.hexa 383-397 | 252 + 119 = 371 | 10/10 PASS | drill-bg-dep (3 verdict branches still exercised via stub) |
| revive| revive/revive.hexa 102 + revive_loop.hexa 49 + revive_l0_check.hexa 90 ≈ 241 | 156 + 97 = 253 | 8/8 PASS | revive_master/L0-check shelled out → in-process callback shim |

Total ported LOC: **1917** (main 1284 + test 633).

## canon redirect — CONFIRMED

`compiler/canon_engine/canon_engine.hexa::canon_seal_path()` resolves to
`<HOME>/.hx/data/canon_seal.jsonl`, overridable via `HEXA_CANON_SEAL_PATH`
(used by the smoke). Nexus's `<NEXUS>/state/canon_seal.jsonl` is NOT
touched. Doctrine v2 rule 5 — overlay-side append-only file living next to
`~/.hx/data/atlas.overlay.n6`.

Path resolution proof (from smoke):
- expected: `/tmp/hexa_canon_engine_smoke/.hx/data/canon_seal.jsonl`
- actual:   `/tmp/hexa_canon_engine_smoke/.hx/data/canon_seal.jsonl` ✓

## revive iteration cap — CONFIRMED

`revive_run` takes `max_iter_in: i64` as a mandatory arg. Hard ceiling of
10000 enforced internally (defense-in-depth) regardless of caller value.
Smoke explicitly validates:
- `max_iter=4, L0_AT=9999` → exits at iter 4 with `max_iter_reached`
- `max_iter=50000, L0_AT=2` → clamped, terminates ≤ 10000
- `force_fail + consec_fail_cap=3` → aborts at iter 3 with exit 2
- `L0_AT=3` → terminates at iter 3 with exit 0

No path can loop "infinitely" — every loop is bounded by `max_iter ≤ 10000`.

## debate engine size + port strategy

Source engine `cli/drill/adversarial_debate.hexa` is **420 LOC** (full
parser + N-variant orchestrator). Port strategy: **port-not-stub**. The
verdict logic (L1 CONSENSUS / L2 SOFT_AGREE / L3 DEBATE) is ported in full;
only the drill round subprocess invocation is replaced by `_drill_round_shim`
(marked `TODO(drill-bg-dep)`). The 6-element delta vectors, plan clamping
[1,6], byte-match vs ratio-bound (mx*100 ≤ mn*120) verdict tests, and
`HEXA_DEBATE` arbitration emission are all preserved.

Smoke covers all 3 verdict branches independently (CONSENSUS/SOFT_AGREE/
DEBATE) plus a full end-to-end run.

## drill-bg-dep status

`compiler/drill/` is owned by the parallel drill spine BG. All 7 ports
import `compiler/atlas/overlay` (committed 1f1eef1b) and use a local
`_drill_round_shim` for the drill round body. When `compiler/drill/drill`
lands, each shim is a 5-line swap to `drill_round(seed, depth, fast, ...)`.
TODO markers in each main module flag the call site.

## Constraints honored

- `git diff self/main.hexa` — empty (untouched).
- Existing `compiler/<x>/` dirs not modified (verified via git status).
- Parallel BG dirs (`drill`, `omega`, `surge`, `dream`, `swarm`, `chain`)
  appeared concurrently — not touched by this session.
- Nexus repo not modified (read-only references only).
- English-only code & comments.
- No commit created.

## Files added

```
compiler/reign/reign.hexa                  247
compiler/reign/reign_test.hexa             105
compiler/molt/molt.hexa                    166
compiler/molt/molt_test.hexa                75
compiler/wake/wake.hexa                    135
compiler/wake/wake_test.hexa                71
compiler/forge/forge.hexa                  166
compiler/forge/forge_test.hexa              78
compiler/canon_engine/canon_engine.hexa    162
compiler/canon_engine/canon_engine_test.hexa 88
compiler/debate/debate.hexa                252
compiler/debate/debate_test.hexa           119
compiler/revive/revive.hexa                156
compiler/revive/revive_test.hexa            97
```
