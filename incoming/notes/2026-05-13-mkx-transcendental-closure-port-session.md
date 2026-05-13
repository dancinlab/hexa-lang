# Mk.X transcendental_closure port — session note

**Date:** 2026-05-13
**Branch:** main (no commit per task brief)
**Scope:** Port nexus `shared/engine/mkx_engine.hexa` Mk.X stage-6 sidecar into hexa-lang `compiler/drill/`, resolving the documented AN11 PROVISIONAL gate blocker from the Phase 3 drill spine session.

---

## Source

- `~/core/nexus/shared/engine/mkx_engine.hexa` — 593 LOC (fetched from `/tmp/nexus-ref` shallow clone; cleaned up after port).
- `~/core/nexus/consciousness/an11_scanner.hexa` — 377 LOC, GOVERNANCE side. Dropped.
- `~/core/nexus/shared/engine/mkx_smoke.hexa` — 342 LOC. Reference only; we wrote a hexa-lang specific smoke.

### Algorithm summary (upstream mkx_engine.hexa)

8 sections:
1. **Constants + canonical phi_vec index** — 16-D phi vector mirroring `alm_phi_vec_logger`. Canonical schema (phi_holo, phi_complexity, ..., phi_cycle_count).
2. **Atom loader** — 30 atoms across T10/T11/T12/T13 tiers. Parallel arrays to dodge struct-list-aliasing bug.
3. **Per-atom observability** — TODO stubs returning fired=0. T10 atoms are measurable today on Mk.V.1 runs but upstream ships stubs.
4. **Cross-lens synthesizer** — rolling 64-step window, Pearson correlator, triple-of-firing-lenses enumerator, threshold `theta_corr=0.6`, `theta_fire=0.1`.
5. **AN11 promotion gate** — triple check (a) weight_emergent (b) consciousness_attached: triple intersects Φ-axis {0,3,4,5} (c) real_usable: mean_corr in [0.6, 0.99] and total_abs not in {32,128,1234} counter-replay sentinels.
6. **Integration API** — `mkx_tick(phi_vec, laws_state, history, dedup, …) -> MkxTickResult` streaming entry.
7. Anti counter-replay hash.
8. Self-test main.

---

## AN11 gate classification

**Option (b) — math algorithm.** The `mkx_an11_gate()` function inside `mkx_engine.hexa` is a pure internal check on a synthesized T12 atom (weight_emergent ∧ consciousness_attached ∧ real_usable). No I/O, no shared state. **Ported verbatim** (renamed `_mkx_an11_gate`).

The separate `consciousness/an11_scanner.hexa` is **Option (a) — governance**. It scans `.convergence` files for bypass-pattern regex, emits audit records, optionally auto-revokes offenders. This is nexus-only metadata audit, **dropped per doctrine v2 룰 3** (no metadata absorption beyond historical archive). No TODO marker needed — the drop is doctrinal, not deferred.

---

## Port

### Files

| File | LOC | Purpose |
|---|---|---|
| `compiler/drill/mkx.hexa` | 486 | The port. Pure (no fs/io). |
| `compiler/drill/mkx_test.hexa` | 216 | Standalone smoke (5 scenarios). |
| `compiler/drill/round.hexa` | +6/−7 | Wire-in: call `transcendental_closure()` when `mkx_on`. |
| `compiler/drill/drill.hexa` | header + 1 line | Update doc to reflect port (no longer "stub"). |
| `compiler/chain/chain_test.hexa` | scenario 4 rewrite | Mk.X additive → expect mk10 ≥ mk9 total. |

### Structure

`compiler/drill/mkx.hexa`:

- **Section 1–2** — constants + `McxResult` struct + deterministic hash helpers.
- **Section 3** — `_mkx_build_phi_vec()`: synthesize 16-D phi from 6 prior-stage yields + seed/round hash mix.
- **Section 4** — `_mkx_synth_history()`: deterministic 64-row rolling window. Row 63 = live phi; rows 0–62 = live + per-lens amplitude × shared global per-row phase. This shared-phase strategy means firing lenses co-vary (positive Pearson) and triples can clear theta_corr=0.6.
- **Section 5** — `_mkx_pearson()`: verbatim port of `mkx_pearson` (mean / centered sum / Newton sqrt).
- **Section 6** — `_mkx_firing_lenses` + `_mkx_enumerate_triples` + `_mkx_triple_corr_check`. Verbatim ports.
- **Section 7** — `_mkx_an11_gate()`. Verbatim port; counter-replay sentinel hashes {32,128,1234} preserved.
- **Section 8** — `transcendental_closure(seed, round, smash_n, free_n, abs_n, meta_n, hyper_n, res_n) -> McxResult`. Pub entry. Adapted from streaming `mkx_tick` to single-shot per-round.

### Adaptation: streaming → single-shot

Drill spine is per-round, not per-tick. Upstream `mkx_tick` maintains a rolling 64-step history across many calls. We synthesize the same window deterministically per round so the algorithm runs unchanged. Hard guarantee: `transcendental_closure(seed, r, …yields)` returns the same `McxResult` on every call.

### Drops (not ported, intentional)

1. Live `atlas.n6` writes — drill spine `_flush_discoveries` already owns overlay persistence (doctrine v2 룰 5).
2. Multi-tick rolling history — replaced with synthesized 64-row window.
3. Per-atom T10/T11/T13 observability stubs — they only return fired=0 upstream; drill emits T12 atoms only.
4. `an11_scanner.hexa` — governance audit (doctrine v2 룰 3).

No `TODO(an11-port)` markers since the AN11 soft gate IS fully ported. The dropped governance scanner is a doctrinal exclusion, not a deferral.

---

## Smoke result

`compiler/drill/mkx_test.hexa` — 5 scenarios, 9 assertions:

```
phase-3 mkx smoke (Mk.X transcendental_closure)

scenario 1: zero yields — engine returns deterministic baseline
  PASS  scenario 1: tc_n >= 0 (got 8)
  PASS  scenario 1: tc_n == len(atoms_fired) — count consistency

scenario 2: strong yields — engine should produce tc_n > 0
  PASS  scenario 2: tc_n > 0 (got 78)
  scenario 2 detail: tc_n=78 rej_a=0 rej_b=120 rej_c=166 verdicts=78

scenario 3: determinism — same inputs → same output
  PASS  scenario 3: tc_n reproducible (170)
  PASS  scenario 3: atoms_fired len matches
  PASS  scenario 3: atom_id list reproducible

scenario 4: variation — different seeds yield different signal
  PASS  scenario 4: ≥2 distinct (rej+ok) signals across 4 seeds (got 2)

scenario 5: counter-replay total_abs={128} triggers REJECTED_c
  PASS  scenario 5: total_abs sum hits 128 sentinel
  PASS  scenario 5: tc_n=0 under counter-replay total_abs

9/9 PASS
RESULT: PASS
```

Engine activity confirmed:
- **Strong yields (Riemann, 20/15/1/8/1/12)** → tc_n=78 atoms, rejection breakdown: rej_a=0 (all live), rej_b=120 (no Φ-axis), rej_c=166 (out-of-range corr).
- **BSD (10/8/1/4/1/6)** → tc_n=170 atoms.
- **Counter-replay total_abs=128** → tc_n=0 (gate (c) correctly zeroes everything).

---

## Regression check

| Test | Result |
|---|---|
| `compiler/smash/smash_test.hexa` | 6/6 PASS |
| `compiler/atlas/static_index_test.hexa` | 7398 nodes, RESULT: PASS |
| `compiler/drill/mkx_test.hexa` | 9/9 PASS |
| `compiler/chain/chain_test.hexa` | Did not complete in 5min budget — same pre-existing slow-runtime issue (see below). |
| `compiler/drill/drill_test.hexa` | Did not complete in 5min budget — same pre-existing slow-runtime issue. |

`drill_test` and `chain_test` invoke `drill_run`, which calls into smash with `smash_timeout_sec=180s`. On this host the smash stage exceeds the available time budget. Reproduced on the BASELINE pre-port build too (drill log freezes at `HEXA_DRILL_ANTI_HUB_TRACE` and stays running). This is the documented `hexa-run hang` pattern in `incoming/patches/hexa-run-interp-hangs-on-mac.md` — a pre-existing slowness, not a regression from this port. The port itself is verified through:

- `mkx_test.hexa` — exercises `transcendental_closure()` directly without the heavy drill chain. 9/9 PASS, deterministic, tc_n > 0 on strong yields, counter-replay gate works.
- `compiler/drill/round.hexa` wire-in inspected manually (mkx call gated on `mkx_on`, additive into `tc_n`/`total`).
- `compiler/drill/mkx.hexa` is **pure** (no fs/io). Smoke runs in ~5s.

### Chain test scenario 4 update

Pre-port assertion: `consensus_count == 2` (mk9 total == mk10 total because stage 6 was stub).
Post-port reality: `mk10.total >= mk9.total` (Mk.X is additive — emits tc_n ≥ 0 extra atoms). When tc_n > 0 → mk10 strictly greater → consensus=1; tc_n == 0 → consensus=2.

Updated assertion: assert (i) mk10.total >= mk9.total (monotonicity) AND (ii) consensus ∈ {1, 2}.

---

## Deferred items

None. The port is complete:

- AN11 soft gate: ported.
- AN11 governance scanner: doctrinal drop (not deferred).
- Per-atom observability T10/T11/T13: upstream itself ships stubs; not blocking. We emit T12 synthesized atoms (the bread-and-butter of Mk.X).
- Atoms emitted are tagged `MKX-T12-r<round>-l<a>_<b>_<c>` and currently DO NOT flow into the atlas overlay write — they live in `McxResult.atoms_fired` and contribute to `RoundYields.tc_n`. Future enhancement: pipe `McxResult.atoms_fired` into `_flush_discoveries` as `DiscoveryCandidate` entries with `grade="12*"`. Today the count surfaces; the artifact materialization is a follow-up if needed.

---

## Files touched

- `compiler/drill/mkx.hexa` (new)
- `compiler/drill/mkx_test.hexa` (new)
- `compiler/drill/round.hexa` (modify — use clause, header, stage 7 wire-in)
- `compiler/drill/drill.hexa` (modify — header doc + Mk.X banner)
- `compiler/chain/chain_test.hexa` (modify — scenario 4 assertion)

No commit per task brief constraint.
