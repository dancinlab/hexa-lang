# 2026-05-13 — Phase 2 generators absorption session (A5 / A6 / A8)

Phase 2 of the nexus → hexa-lang absorption surface. 3 discovery
generators ported from nexus (`~/core/nexus/cli/`). γ policy enforced:
every algorithm returns `DiscoveryCandidate` (or `HyperResult`) values
in-process — NO atlas writes, NO `discovery_log.append`, NO
`atlas_health.append`, NO `audit_log`. Persistence is Phase 3 work
(rodata seed + runtime overlay per absorption doctrine v2 rule 5).

## Per-algorithm results

| algo | source                                                                | target dir                  | LOC ported | smoke   |
|------|-----------------------------------------------------------------------|-----------------------------|------------|---------|
| A5   | `~/core/nexus/cli/blowup/core/blowup.hexa` (7055 LOC)                 | `compiler/smash/`           | 838        | 6/6 PASS |
| A6   | `~/core/nexus/cli/blowup/compose.hexa` (443) + 5 module files (~3000) | `compiler/free/`            | 427        | 5/5 PASS |
| A8   | `~/core/nexus/cli/blowup/modules/blowup_hyperarithmetic.hexa` (531)   | `compiler/hyperarithmetic/` | 511        | 7/7 PASS |

Total LOC: 1776.

## A5 smash — 9-phase blowup pipeline

**Files:**
- `compiler/smash/candidate.hexa` (102 LOC) — shared `DiscoveryCandidate`
  struct + `mk_axiom` / `mk_derived` / `seed_hash` helpers (also
  re-exported to free.hexa).
- `compiler/smash/phases.hexa` (461 LOC) — all 9 phase implementations
  (P1 normalize, P2 evolve, P3 singularities, P4 7-type corollary
  fanout, P5 5-lens telescope, P6 n=6 invariance, P7 recursive growth,
  P8 wave propagation, P9 meta-DFS).
- `compiler/smash/smash.hexa` (159 LOC) — `pub fn smash(seed, depth)`
  + `smash_batch` + count helpers.
- `compiler/smash/smash_test.hexa` (116 LOC) — 2 seeds + batch smoke.

**Smoke output (6/6 PASS):**
- seed `perfect_number_6` (depth=3) → 368 candidates, 7 axioms,
  P6 grade="10*" tag present.
- seed `sigma_24_invariant` (depth=2) → 323 candidates, all 7 ctypes
  (`ded` / `xfer` / `orbit` / `dual` / `closure` / `recur` / `meta`)
  represented.
- batch (2 seeds, depth=2) → 637 candidates.

**Deferred (TODO Phase 3):**
- P2 ouroboros: real `mutate → verify → converge → saturate` loop
  (currently projects 6 hexad CDESM constants as deterministic axioms).
- P8 wave propagation: true parallelism. Nexus version forks
  per-domain subprocesses and reads `wave_out.log.*`. v1 runs the
  3-domain fan-out sequentially. `TODO(parallelize)` marker in
  `phases.hexa::p8_wave_propagate`.
- Atlas write in P6 (γ enforced — `compiler/atlas/` not touched).
- bias_jitter self-tuning history (nexus ROI#48e) — not ported.
- Adaptive depth cap (nexus ROI#48d) — fixed at `MAX_DEPTH = 5` in
  the recursive growth loop.

**Hexad dependency:** Originally wrote `use "compiler/hexad/static_index"`
to source the 6 axiom-pool constants. The module loader requires
`HEXA_LANG` env (or cwd inside hexa-lang) to resolve `compiler/...`
paths, which the smoke runner doesn't control. Inlined a 6-entry
mini-mirror in `phases.hexa::_hexad_seed_names/_values` cross-checked
against the D2 wave-1 hash (`6c6c8e9a89...`). `TODO(phase3)` in code
to swap back once loader is fixed.

## A6 free — 5-module compose DFS

**Files:**
- `compiler/free/modules.hexa` (182 LOC) — 5 module dispatch
  (field / holographic / quantum / string / toe).
- `compiler/free/free.hexa` (126 LOC) — `pub fn free(seed, dfs_depth)`
  DFS engine + `_dfs_expand` step + bound `MAX_FANOUT_PER_DEPTH=24`
  `MAX_DEPTH=5`.
- `compiler/free/free_test.hexa` (119 LOC) — 2 seeds + depth comparison.

**Smoke output (5/5 PASS):**
- seed `atlas_n6_lattice` (dfs=2) → 91 candidates, all 5 modules
  contributed.
- seed `physics_unified` (dfs=3) → 211 candidates, primary axiom
  present, dfs=3 strictly > dfs=1.

**Deferred (TODO Phase 3):**
- Per-module verifier hook: each of the 5 modules currently runs a
  closed-form heuristic (e.g. `m3_quantum` returns `value * 0.5` as
  "eigenvalue projection"). The nexus engines (~500-2000 LOC each)
  cross-check against reverse-math / Δ₀-absolute classifiers.
- Module-pair interference: nexus modules share state via atlas.n6
  SSOT chaining; v1 port runs each module independently.
- 5-lens consensus boost (kept in A5/smash surface only).
- The 8 extended modules (`absolute` / `meta` / `meta_closure` /
  `hyperarithmetic` / `higher_category` / `topos` / `hott` /
  `motivic` / `derived_algebraic`) NOT ported — out of A6 scope (BG
  said 5-module DFS).

## A8 hyperarithmetic — Mk.IX Π₀² 5-system classifier

**Files:**
- `compiler/hyperarithmetic/checks.hexa` (279 LOC) — H1 Π₀² syntax
  detect / H2 witness-bound reduction / H3 reverse-math 5-system
  check (RCA₀/WKL₀/ACA₀/ATR₀/Π¹₁-CA₀) / H4 n=6 invariance / H5
  composite verdict / `is_tier12_candidate`.
- `compiler/hyperarithmetic/hyperarithmetic.hexa` (84 LOC) —
  `pub struct HyperResult` + `pub fn hyperarithmetic(prop)` +
  `_pretty` formatter + batch.
- `compiler/hyperarithmetic/hyperarithmetic_test.hexa` (148 LOC) —
  5 propositions T1..T5 covering every verdict path.

**Smoke output (7/7 PASS):**
- T1 `perfect number infinite ∀N ∃m>N σ(m)=2m` → hierarchy=PI02.
- T2 `Vinogradov ternary Goldbach ∀n odd, ∃p1,p2,p3 prime` →
  verdict=ABSOLUTE-PASS-PI02, witness-bound=`3n (Helfgott 2013)`.
- T3 `Sylow p-subgroup for all finite G` → verdict=DELEGATE-MK8
  (no ∀∃ alternation in the heuristic parser without bounded markers).
- T4 `Out(S_6) = Z/2 ...` → n6_invariance=N6-UNIQUE, [12*] candidate.
- T5 `Con(ZFC) ∀p ¬derive(p,⊥)` → verdict=REJECT-BLACKLIST.

**Deferred (TODO Phase 3):**
- Full `pi02_parser.hexa.inc` AST classifier (nexus version has a
  stub-fallback hook that points at a file in-progress at another
  agent). v1 port uses the same keyword heuristic; this is a verbatim
  algorithm port, not a runner port.
- `reverse_math_check.hexa.inc` whitelist JSON load (same stub
  fallback). Whitelist is currently hardcoded in `rev_strength_level`.
- `NEXUS_ENGINE_{DEAD,ERROR,WARN}` JSON emission to stderr —
  scaffolding only, belongs to the runner layer, not the algorithm.
- atlas.n6 self-check on init — γ enforced (no atlas dependency).

## γ enforcement status — VERIFIED

- Zero atlas writes across all 3 algorithms. Grep confirms:
  `atlas_health.append` / `discovery_log.append` / `audit_log`
  appear zero times under `compiler/{smash,free,hyperarithmetic}/`.
- All public entry points (`smash`, `free`, `hyperarithmetic`)
  return values — no side-effecting stdout/stderr at the algorithm
  layer beyond the smoke's `println` (which is in the `*_test.hexa`
  smoke driver, not the library).
- `git diff self/main.hexa compiler/atlas/` empty. `tool/hexa_annot/`
  not touched. None of the parallel-BG directories were modified.

## Phase 2 generator status — COMPLETE

3/3 algorithms ported, 3/3 smokes pass (18 individual checks total).
1776 LOC delta. No conflicts with parallel BG outputs (BG-C
archive dirs, verifier-BG `compiler/{honesty,absolute,meta_closure}/`).
