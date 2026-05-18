# RFC — quant_meter: rate-distortion compile-pipeline instrumentation

- **Status**: Draft (P1 landed `ce431e2f`; meter buildable on this branch `76d38693`)
- **Date**: 2026-05-18
- **Location rationale**: co-located with the tracked code. The earlier
  `proposals/` copy drifted to a sibling branch and was stranded; this
  doc travels with `compiler/quant_meter/*.hexa` so it survives shared-tree
  churn (8-session worktree — see memory `compiler-selfbuild-blockers`).
- **RFC number**: unassigned (proposals/ ↔ inbox/rfc_drafts numbering
  contention). Assign on promotion.

---

## 1. Thesis

Compilation is **progressive quantization**: each transform stage removes
a category of representational freedom while preserving semantics; machine
code has ~zero such freedom. quant_meter instruments every IR level with
two measurables and enforces one invariant.

## 2. The two-class model (landed)

| class | def | examples |
|---|---|---|
| **transform** | mutates the IR; representation rate drops | lex · parse · ast_to_hir · hir_to_mir · optimize · codegen · emit |
| **gate** | validates only; representation unchanged (identity) | target_gate · resolve · bind · types · units · citation |

In `compiler/main.hexa` the gate passes already only return `[Diagnostic]`
(no IR mutation) — the transform/gate split is observed, not invented.

## 3. Two tracks (Decision: do not conflate)

- **S** — representation size (P1: AST/HIR node count; P2: HXC serialized
  byte length). **NOT monotone** (SSA / elaboration expands it).
  Observability + regression only.
- **F** — a **vector** of freedom counters, each **monotone
  non-increasing across transform boundaries**. P1: `F_name` (idents still
  string-carried, unresolved), `F_type` (exprs without a pinned monotype),
  `F_ctrl` (un-lowered structured control). No scalar sum (would hide
  which freedom regressed and mix units).

## 4. Rigorous backbone (round-2 — the load-bearing upgrade)

**Cousot & Cousot, "Systematic Design of Program Transformation Frameworks
by Abstract Interpretation," POPL 2002** (DOI 10.1145/503272.503290).
A compiler stage = a *composed semantic abstraction* on trace semantics;
its correctness factors into:

- an **observational abstraction** — the behaviour that must be preserved
  ≡ our `D = 0` (CompCert-style forward simulation on the observable
  trace; Leroy CACM 2009);
- a **performance abstraction** — the cost/representation dimension ≡ our
  `S` and `F`.

The **monotone-F invariant is the monotonicity of the abstraction's lower
adjoint α**. The Galois Connection Calculus (Cousot & Cousot, POPL 2014)
makes per-pass monotonicity compose into a pipeline-wide guarantee as
*adjoint composition* — not an empirical hope.

**Where it holds vs breaks (this justifies §3, it is not a wart):**
abstracting passes (name resolution, type pinning, const-prop) travel the
α direction — F drops, sound loss. *Elaboration / refinement* passes (SSA
construction, control-flow lowering) travel the γ (concretization)
direction — representation *grows*. That is exactly why **S is declared
non-monotone** while **F stays monotone**: freedom (unresolved choice) is
what abstraction removes even when node count grows under elaboration.

## 5. HX2600 — the gate, and its novelty

Each transform boundary `i→i+1` asserts `F_k[i+1] ≤ F_k[i]` ∀k. A rise =
a transform re-introduced freedom = a real lowering bug or a meter
mismeasurement (both defects) → build-failing diagnostic **HX2600**
(`HEXA_QUANT_GATE=0` demotes to warning, bootstrap escape).

Closest production prior art = **MLIR's mandatory per-pass verifier
contract** ("input valid ⇒ output valid, enforced between every pass; if
many passes check the same invariant, promote it to the verifier").
quant_meter generalizes that discipline **from boolean well-formedness to
a monotone quantitative freedom budget, with transform/gate stage typing
so monotonicity is asserted only where representation actually drops**. No
production compiler enforces a monotone representation/resource metric as
a pipeline build gate (LLVM `-verify-each`, rustc `-Zvalidate-mir`,
Alive2, Crocus/Veri-ISLE are all boolean or per-transform). Position
HX2600 as a **novel internalized static metamorphic relation** — distinct
from existing dynamic/external metamorphic compiler testing.

## 6. Measurement (Decision A — accepted terminal deliverable)

`meter_test.hexa` — synthetic IR, `hexa build` + run **PASS (RC=0)**,
re-verified post-drift on `76d38693`:

```
case: fn classify { if (n) { a } else { while (b) { } } }
    stage   S(nodes)  F_name  F_type  F_ctrl
    ast          10       3       9       2
    hir          10       0       0       2     ← F_name·F_type die at ast_to_hir
    mir          13       0       0       0     ← F_ctrl dies at hir_to_mir; S RISES
```

`F_name`+`F_type` collapsing at the *same* transform = `ast_to_hir`
overload quantified (nanopass anti-pattern). `S` 10→10→13 rising proves
S≠freedom → the §3 two-track split was necessary. HX2600 gate logic
verified 6/6 (clean pairs pass; F_name/F_type/F_ctrl rises flagged).

**Why synthetic:** real-code measurement needs the full
`compiler/main.hexa` self-build, which OOM-kills the interp module_loader
on **every ≤31GB host tried** (macOS, aiden, summer/ubu-2) — a known
interp-retirement infrastructure wall, not a quant_meter defect. User
decision A (2026-05-18): accept the verified synthetic measurement as the
terminal deliverable; real-code/full-build deferred to a separate cycle
(needs >31GB host or a streaming module_loader).

## 7. P2 — formally anchored

| counter | formal definition | citable anchor |
|---|---|---|
| `F_sched` | log #linear-extensions of the data-dependence poset | **Brightwell & Winkler 1991** — #P-complete (mirrors our uncomputable-rate motif; cleanest counter) |
| `F_redund` | distance to the unique LCM/PDCE optimal normal form | **Knoop-Rüthing-Steffen** Lazy Code Motion PLDI'92 / Partial DCE PLDI'94 — `F_redund=0` is a well-defined fixed point |
| `F_res` | unbound live ranges; register pressure proxy | **Pereira & Palsberg**, regalloc post-SSA NP-complete (FoSSaCS'06) + LLVM `ScheduleDAGMILive` RegisterPressureTracker (real production anchor) |
| `S`→bytes | HXC serialized length = MDL/NCD-style computable Kolmogorov upper bound | grounded in NCD literature; **no production precedent** — keep non-monotone/advisory, freeze codec per measurement |

Pass-fission license (resolve the `ast_to_hir` overload): **Patterson &
Ahmed, "The Next 700 Compiler Correctness Theorems," ICFP 2019** +
**Pilsner** transitivity (ICFP 2015) + **CakeML** "one new IL per
compiled-away feature" — fission is correctness-preserving, not stylistic.

## 8. Honest positioning (g3 + g4)

- RD vocabulary ("progressive quantization / rate / distortion") borrowed
  from **TurboQuant (ICLR 2026)** + **PolarQuant (NeurIPS 2025)** —
  current frontier; **terminology only**, no distortion-rate optimality
  claim.
- Real-limit anchors: Kolmogorov full-employment (R uncomputable → F is an
  explicit count proxy) · Brightwell-Winkler #P-completeness (F_sched) ·
  Pereira-Palsberg NP-completeness (F_res) · CompCert observational
  equivalence (D=0). The monotone-F invariant itself = α-monotonicity
  under Cousot-Cousot transformation-by-abstraction.

## 9. Falsifier (principle 5)

"6 stages, one freedom-kind each" was triple-refuted (code audit + 2
independent research agents): ~9 freedom-kinds, ~6 representation
transitions, not aligned. Stage count is **emergent** (LLVM ~2, MLIR
open-ended, CakeML one-IL-per-feature); n=6 is observational coincidence
only, never a derivation.

## 10. Decision gates (user)

1. Promote to a numbered RFC (assign collision-free number).
2. P2 start order: (a) `F_sched` (cleanest formal) / (b) `ast_to_hir`
   fission / (c) interp↔compiled RateVec diff tool.
3. Full self-build: requires >31GB host (runpod) or streaming loader —
   separate cycle, cost/scope decision.
