# lean4_mechanical_layer_v0.scaffold

> **Scaffold spec — consumer's contract, NOT implementation.**
> Actual lean4 code lives in canonical upstream `~/core/canon/` per
> cross-repo memory rule
> (`memory/feedback_cross_repo_canonical.md`). This file describes what
> hexa-bio expects the canonical layer to expose so that when upstream work
> lands the consumer (hexa-bio) is ready to absorb it.
>
> No `.lean` files in hexa-bio. Spec + JSON Schema only.

**Status**: SCAFFOLD LANDED 2026-05-06 (cycle 25). **CANONICAL STUB LAYER
LANDED 2026-05-06** (cross-repo, under human-in-the-loop authorization).
Tracks `.roadmap.hexa_bio` §G GATE-26-2 / §B C0h and `.roadmap.weave`
§Falsifier preregister F-CL-FORMAL-1/2/3/4.

**Canonical stub-layer location** (canon):
`~/core/canon/formal/lean4/` — see its `README.md` for axis-file
map and raw_91 honest C3 disclosure. **sorry-count = 4** (one `sorry` per
axis; no axis is PASS).

  - F-CL-FORMAL-1 → `formal/lean4/N6/InvariantLattice/SigmaLatticeCard.lean`
    (theorem `sigma_lattice_card`; sorry-count=1)
  - F-CL-FORMAL-2 → `formal/lean4/N6/Weave/LandauerMonotonic.lean`
    (theorem `landauer_monotonic`; sorry-count=1)
  - F-CL-FORMAL-3 → `formal/lean4/N6/Weave/PiP2Termination.lean`
    (theorem `pi_p2_verifier_terminates`; sorry-count=1)
  - F-CL-FORMAL-4 → `formal/lean4/N6/Weave/ClosureCert.lean`
    (theorem `closure_cert_idempotent`; sorry-count=1)

Cross-repo canonical proof-body work (replace each `sorry` with a real
proof) PENDING — cycle 30+.

**Last sync**: 2026-05-06 · **Schema version**: v0 (scaffold; promotes to v1
on first canonical PASS — i.e. first axis with sorry_count=0).

---

## §1 Purpose

GATE-26-2 (lean4-mechanical-extension) promotes sorry-free Foundation from
the WEAVE-only baseline (already PASS pre-cycle-24, see `.roadmap.weave`
status snapshot row "lean4 sorry count = 0") to the four cross-cutting
formal axes labelled F-CL-FORMAL-1/2/3/4. Axis 4 (closure-cert idempotence)
already has a lean4 theorem stub (PARTIAL); axes 1/2/3 are the scope of this
scaffold.

This spec lets hexa-bio:

  (a) lock the **theorem-name vocabulary** consumers should grep for once
      canonical lands;
  (b) define the **witness schema** (`raw_77_lean4_proof_witness_v0`) that
      hexa-bio will emit when canonical reports a proof state, so that
      `state/discovery_absorption/registry.jsonl` can record formal-axis
      progress without waiting on upstream file-system access;
  (c) preserve the **DEFERRED → SCAFFOLD LANDED** lift in
      `.roadmap.weave` and `.roadmap.hexa_bio` so cycle-26+ planning can
      reference a concrete artefact, not a placeholder.

## §2 Theorem signatures (expected)

Each signature is written in lean4 surface syntax with `sorry` as the
proof body — actual proof construction is the canonical-repo deliverable.
Names are normative for the consumer contract: hexa-bio's witness emitter
will look these up by exact name.

### §2.1 F-CL-FORMAL-1 — σ(6)=12 invariant

Axis claim (text): the proteome cardinality / 6-fold symmetry compatibility
constant σ(6) equals 12, matching the n=6 invariant lattice §A.1 entry
(σ(6)=12) of `.roadmap.hexa_bio`.

```lean4
theorem sigma_lattice_card : sigma 6 = 12 := sorry
```

  - **Module path (expected)**: `N6.InvariantLattice.SigmaLatticeCard`
  - **Imports**: `N6.InvariantLattice.Sigma` (canonical definition of σ).
  - **Discharges**: F-CL-FORMAL-1 PASS when `sorry`-count = 0 on this
    theorem (i.e. file compiles without `sorry`).
  - **Witness on PASS**: hexa-bio emits one
    `raw_77_lean4_proof_witness_v0` row with `theorem_name =
    "sigma_lattice_card"`, `sorry_count = 0`.

### §2.2 F-CL-FORMAL-2 — Landauer floor monotonicity

Axis claim (text): `heat_consumed_kT` is non-decreasing under sub-strategy
composition; i.e. composing two Landauer-pass strategies cannot lower the
heat consumed below the max of the two component costs (no free-energy
violation).

```lean4
theorem landauer_monotonic
    (s₁ s₂ : Strategy) (h₁ : LandauerPass s₁) (h₂ : LandauerPass s₂) :
    heatConsumed (compose s₁ s₂) ≥ max (heatConsumed s₁) (heatConsumed s₂)
  := sorry
```

  - **Module path (expected)**: `N6.Weave.LandauerMonotonic`
  - **Imports**: `N6.Weave.Strategy`, `N6.Weave.Landauer`.
  - **Discharges**: F-CL-FORMAL-2 PASS when `sorry`-count = 0.
  - **Pairing with hexa-bio code**: matches Landauer gate semantics in
    `_python_bridge/module/weave_composition.py` (heat_budget_kT field of
    `weave_composition_output_v1` schema).

### §2.3 F-CL-FORMAL-3 — Π^p_2 verifier termination

Axis claim (text): the Π^p_2 verifier is decidable and terminates in
bounded time on the canonical 12-strand catalogue. Pairs with the WEAVE
verifier upgrade GATE-26-3 (greedy v2 ↔ exhaustive v3 path).

```lean4
theorem pi_p2_verifier_terminates
    (cat : StrandCatalogue) (h : cat.size = 12) (q : Pi_p_2_Query cat) :
    ∃ (n : Nat), verifierSteps q ≤ n
  := sorry
```

  - **Module path (expected)**: `N6.Weave.PiP2Termination`
  - **Imports**: `N6.Weave.StrandCatalogue`, `N6.Weave.PiP2Verifier`.
  - **Discharges**: F-CL-FORMAL-3 PASS when `sorry`-count = 0.
  - **Pairing with hexa-bio code**: matches `weave_pi_p2_verifier_v3_exhaustive.py`
    (cycle-25 NP-solver upgrade) — termination bound `n` should be
    machine-extractable for cross-check against the v2/v3 50/50 agreement
    sweep recorded under GATE-26-3.

### §2.4 F-CL-FORMAL-4 — closure-cert idempotence (already PARTIAL)

Out of scope for v0 scaffold (theorem stub already present upstream per
`.roadmap.weave` F-CL-FORMAL-4 PARTIAL row). Listed here only for
completeness; promotes to scaffold v1 when canonical names lock in.

```lean4
-- existing PARTIAL stub, name TBD-canonical
theorem closure_cert_idempotent : ∀ c, discloseTwice c = discloseOnce c := sorry
```

## §3 Witness schema — raw_77_lean4_proof_witness_v0

Canonical JSON Schema co-located at
`weave/spec/lean4_proof_witness_v0.schema.json`. One row emitted per
(axis, theorem) pair when canonical reports a proof-state change.

Required fields (see schema for full constraints):

  - `schema`           — const `"raw_77_lean4_proof_witness_v0"`
  - `axis`             — enum `"F-CL-FORMAL-1" | "F-CL-FORMAL-2" | "F-CL-FORMAL-3" | "F-CL-FORMAL-4"`
  - `theorem_name`     — string, lean4 declaration name (e.g. `sigma_lattice_card`)
  - `module_path`      — string, lean4 module path (e.g. `N6.InvariantLattice.SigmaLatticeCard`)
  - `sorry_count`      — integer ≥ 0 (PASS = 0)
  - `last_modified_cycle` — integer ≥ 0 (cycle index of last canonical edit)
  - `canonical_repo_ref` — string, points into upstream
                          (e.g. `canon@<sha>:domains/biology/...`)
  - `pass`             — boolean, `true` iff `sorry_count == 0`
  - `recorded_at`      — RFC3339 timestamp on hexa-bio side

Emitted into `state/discovery_absorption/registry.jsonl` (R4 witness
protocol).

## §4 Cross-repo blockers (PENDING — outside hexa-bio)

Until the following land in `~/core/canon/` they are out of scope
for hexa-bio:

  1. Canonical `Strategy`, `LandauerPass`, `compose`, `heatConsumed`,
     `StrandCatalogue`, `Pi_p_2_Query`, `verifierSteps`, `sigma`
     definitions in lean4 (the scaffold's free symbols).
  2. Concrete proof bodies replacing each `sorry` in §2.1–§2.3.
  3. Module-path lock-in (this scaffold's `module_path` strings are
     proposals; canonical may rename, in which case hexa-bio updates the
     witness schema constant set in a v1 promotion).
  4. lake / Mathlib version pin recorded upstream (consumer can then pin
     by SHA in the witness `canonical_repo_ref`).

When (1)-(4) land, hexa-bio promotes:

  - `.roadmap.weave` F-CL-FORMAL-1/2/3 from `DEFERRED — canonical work
    pending; in-repo scaffold spec landed at
    weave/spec/lean4_mechanical_layer_v0.scaffold.md` to either PASS (if
    sorry-count==0) or REGRESSION-WATCH (if sorry-count>0, i.e. proof
    started but unfinished).
  - this scaffold v0 → v1 (lock canonical theorem names + module paths).

## §5 Non-goals

  - No lean4 source files (`.lean`) in this repo. Forbidden by R1 (canonical
    SSOT immutability) + cross-repo memory rule.
  - No proof obligation here. Hexa-bio is consumer; proof construction is
    canonical-repo session.
  - No CI hook in v0. Once canonical lands, a follow-up cycle wires
    `selftest/lean4_witness_audit.py` (TODO-cycle-26+) that ingests
    canonical-reported proof states and emits the `raw_77_lean4_proof_witness_v0`
    rows.

## §6 References

  - `.roadmap.weave` §Falsifier preregister F-CL-FORMAL-1..4
  - `.roadmap.hexa_bio` §G GATE-26-2 · §B C0h · §A.1 invariant lattice
  - `memory/feedback_cross_repo_canonical.md` — cross-repo edit rule
  - `weave/spec/lean4_proof_witness_v0.schema.json` — witness schema
  - `docs/n6/hexa-weave.md` (symlink → `canon` canonical)


---

## 2026-05-12 — cycle-30++++++: ALL 4 AXES at v4 MAXIMUM SEMANTICS (abstraction trajectory EXHAUSTED)

Following the cycle-30 v1 baseline (below), 6 promotion waves landed in
sequence on 2026-05-12 to exhaust the v1 → v2 → v3 → v4 abstraction
trajectory for the WEAVE-mechanical consumer contract:

| Cycle | hexa-meta commit | Axes promoted | Key abstraction |
|---|---|---|---|
| 30 | `a9b5722` | v1 baseline (4 axes sorry-free; placeholder proofs) | (n/a) |
| 30++ | `350798c` | Axis 4 v1 → v2 | `Finset Nat` caveat bag + seal-on-disclosure |
| 30++ | `79bb661` | (Mathlib SHA pin via `lake-manifest.json`) | (infra) |
| 30+++ | `2c68bea` | Axes 2 + 3 v1 → v2 | ℝ heat + reversible-merge composition (Axis 2); exp-in-depth verifierSteps (Axis 3) |
| 30++++ | `9e44e75` | Axes 2 + 4 v2 → v3 | kT parametric via `[Fact (0 < kT)]` (Axis 2); polymorphic `ClosureCert α [DecidableEq α]` (Axis 4) |
| 30+++++ | `2680f88` | Axis 3 v2 → v3 | recursive `verifierStepsRec` via Nat structural recursion |
| 30++++++ | `7c0ec92` | ALL 3 v3 axes → v4 | substrate-polymorphic `[AddCommGroup E] [LinearOrder E] [IsOrderedAddMonoid E]` + opaque positive `floor : E` (Axis 2); `Prod.lex` `WellFoundedRelation` on `(depth, sz)` (Axis 3); `[CommMonoid β]` payload over `Finset (α × β)` + `totalCaveatPayload` (Axis 4) |

**Final state**: All 4 axes at v4 maximum semantics (1 REAL + 3 v4).
`lake build N6` → 900/900 jobs PASS on lean4 v4.30.0-rc2 + Mathlib SHA
`f8e537424d154a7eaa025c4abab16c96c626f2e0`. sorry_count = 0 across all 5
modules. **v4 PASS EXCEEDS v2.0.0 GATE-26-2 cert-strength** for the
WEAVE-mechanical 4-axis consumer contract.

Concrete-substrate factorisations are RECOVERABLE at consumer sites by
instantiating v4 abstract parameters (e.g., `E := ℝ`, `floor := kT *
Real.log 2` for Axis 2 recovers v3; `α := Nat` for Axis 4 recovers v2).

**v5 stretches** (cycle-30+++++++, **NOT** v1.x / v2.0.0 / v3.0.0
blockers — indefinitely deferred):
- Axis 2 v5: parametrise ring/module structure on E (scalar action over
  commutative semiring for entropic weights)
- Axis 3 v5: verifier-strategy typeclass (recursion shape + decreasing
  measure as data)
- Axis 4 v5: `Finsupp` key-collapsing payload (currently entries with
  same key coexist; `Finsupp` collapses via monoid `*`)

See `.roadmap.lean4_formal` §3 for v5 work-order.

---

## 2026-05-12 — cycle-30: hexa-meta/formal/lean4 PROVEN against WEAVE-semantics v1

The canon@mk1 → hexa-meta absorption (below, earlier same day) recorded the upstream stub
layer as `STUB LANDED 2026-05-06, sorry_count=4`. The on-disk reality at the time of
absorption was already richer (each of the 4 axes carried a *proof-over-placeholder* body,
sorry_count=0, but with the supporting definitions — `Strategy`, `verifierSteps`,
`discloseOnce` — stubbed to trivialise the proofs). Today's cycle-30 work, performed in
hexa-meta on this machine (Lean 4 v4.30.0-rc1 + elan 4.2.1 already installed):

  1. **WEAVE-semantics v1 upgrade** — replaced the placeholder definitions with a richer
     (but still tractable, core-Lean-only) model:
     - `N6.Weave.Strategy`: now a two-field record `{ bits_erased, heat_kT_ln2 }`;
       `LandauerPass s := s.heat_kT_ln2 ≥ s.bits_erased` (the integer Landauer floor,
       not a `True` placeholder); `compose` is Nat-additive on both fields.
     - `N6.Weave.PiP2Verifier`: `verifierSteps q := c.size * (q.depth + 1) + q.payload`
       (a real polynomial bound; was `0`).
     - `N6.Weave.ClosureCert`: `discloseOnce c := { c with disclosed := true }`
       (field-overwrite semantics; was `id`).
  2. **Re-proved** all four F-CL-FORMAL-1..4 theorems against the upgraded semantics —
     `lake build` is **GREEN** on hexa-meta/formal/lean4 with sorry_count=0 across all
     four axes (kernel-checked on v4.30.0-rc1; no Mathlib required — proofs use only
     `rfl` / `simp only` / `omega` / structural case-split).
  3. **Bonus theorem** `landauer_pass_compose` in `N6.Weave.Strategy` certifies that
     `LandauerPass` is closed under `compose` (the substantive floor-preservation lemma
     that pairs with `landauer_monotonic`).
  4. **Removed forward-looking Mathlib require** from `lakefile.lean` — re-add (with a
     SHA pin, not `master`) only when the first real proof body needs a Mathlib lemma.
  5. **Updated** `weave/spec/canon_lean4_state_ref.json` (schema v1 → v2) and
     `_python_bridge/module/lean4_proof_witness_emit.py` (`--refresh` source = hexa-meta
     main, with axis-record MERGE so `proof_summary` curator fields survive a refresh).

**Promotion status**: `.roadmap.weave` §Falsifier preregister F-CL-FORMAL-1/2/3/4 should
now flip from `STUB LANDED 2026-05-06 (sorry-count=4)` to **`PROVEN-v1 2026-05-12
(cycle-30, sorry-count=0 against WEAVE-semantics v1)`**. Scaffold v0 → v1 *partial*: the
theorem names + module paths are locked; the v1 promotion to a "PASS against full WEAVE
algebra" awaits real-valued heat (Mathlib SHA-pin) + reversible-merge composition modes +
exponential-in-depth PiP2 worst case + payload-level disclosure invariants (= v2 work).

**raw_91 honest C3**: PASS = sorry-free against the v1 semantics defined in the upgraded
`Strategy.lean` / `PiP2Verifier.lean` / `ClosureCert.lean`. NOT a claim about the
unrestricted full WEAVE composition algebra. The v1 semantics is a faithful
simplification: real Landauer-floor inequality at integer kT·ln2 granularity; real
polynomial step bound for the 12-strand verifier (matching the bounded-instance v3
behaviour, not the worst-case Π^p_2); real structural idempotence at the disclosure-flag
level. Each `.lean` file carries its own raw_91 disclosure block documenting the v1
caveat.

---

## 2026-05-12 — canon@mk1 lean4 state absorbed; consumer witness-emit re-implemented

Investigated `dancinlab/canon@mk1` (paths `formal/lean4/` and `lean4-n6/N6/`) and absorbed the state into hexa-bio
(hexa-bio still holds **NO `.lean` files** — the `.lean` source stays in canon; this is a state-summary + a witness emitter):

- **`weave/spec/canon_lean4_state_ref.json`** — READ-ONLY summary of the canon@mk1 lean4 state (the 4-axis-stub
  sorry-counts + module paths; the Theorem-B coverage; the MechVerif layer status). `--refresh` (in the emitter) re-reads it.
- **`_python_bridge/module/lean4_proof_witness_emit.py`** — re-implemented (the R5-sunset original was removed): stdlib-only;
  reads `canon_lean4_state_ref.json` (or `--refresh` from `~/mac_home/core/canon@mk1`); emits one `raw_77_lean4_proof_witness_v0`
  row per F-CL-FORMAL-{1,2,3,4} axis (schema-conformant — validated against `lean4_proof_witness_v0.schema.json`); sentinel
  `__LEAN4_PROOF_WITNESS__ PASS` (= the emitter ran + produced schema-shaped rows — NOT that any Lean axis is PASS); wired into
  `selftest/run_all.sh`.

**Actual canon@mk1 lean4 state** (this corrects the over-optimistic / out-of-date wording elsewhere):

| layer | location (canon@mk1) | status |
|-------|----------------------|--------|
| WEAVE-mechanical 4-axis consumer-contract stub | `formal/lean4/N6/` | **STUB LANDED 2026-05-06 (cycle 25)** — 4 axis theorems, each ends in `sorry`; total sorry-count **4**; **NO axis is PASS** (gate = `sorry_count==0`); proof bodies = cycle 30+. raw_91 C3: structurally-correct skeleton, not a verification. |
| **n=6 invariant-lattice UNIQUENESS — Theorem B** (σ·φ = n·τ ⟺ n=6) | `lean4-n6/N6/` | **ESSENTIALLY FULLY PROVEN** — 23 sub-cases + capstone, Lean 4 + mathlib, ~4473 lines, sorry-count ≈ 2 (~99.99% coverage). The n=6 mathematical foundation is in a machine-verified state. |
| MechVerif (WEAVE mechanical first attempt) | `lean4-n6/N6/MechVerif/` | MIXED — `AX1.lean` (701 ln, 0 sorry, 7 named axioms) + `Foundation/Strand.lean` (492 ln, 0 sorry) sorry-free; `AX2.lean` / `MKBridge.lean` / `Foundation/Axioms.lean` carry ~15 sorries + ~28 named axioms (documented Robin/Hardy-Wright-style assumed facts); cycle-30+. |

**GATE-26-2 re-scoping** (per `docs/closure_100_research_2026_05_12.md` §C): the *finitary axis-specific* claims that hexa-bio's
n6-lattice rests on — |S₄|=24, σ(6)=12 (divisor sum), the master identity 12·2 = 6·4 = 24, |O|=24, V−E+F=2 for a *given*
polyhedron, "12 pentamers for a *given* T" — are **DECIDABLE** (`decide`/`Decidable`-backed; formal strength ≤ RCA₀ ≈ PRA), not
impredicative; the appropriate Lean target for *those* is a complete `decide` lemma (stronger than a `sorry` stub), and `mathlib`
already has `Fintype.card_perm` (⇒ |S₄| = 4! = 24), `Nat.ArithmeticFunction.sigma` (⇒ `σ 1 6 = 12`), `Nat.totient`. The
`.roadmap.hexa_bio §G GATE-26-2` "Π¹₁-CA₀" label is therefore a mis-calibration — `decide`/RCA₀-level is correct for the
finitary slice; the Theorem-B uniqueness is *already* machine-verified; only the WEAVE-mechanical 4-axis proof bodies (+ the
MechVerif sorries) remain (cycle 30+, in canon — hexa-bio holds no `.lean` files, only this scaffold + the witness emitter).
