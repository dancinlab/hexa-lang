# HTS Modelling Workgroup — Benchmark #1 (single REBCO tape)

> External reference benchmark — provenance manifest only.
> `absorbed=false` · status: **[skipped: license unclear]**

## Provenance

| field | value |
|---|---|
| source_url | https://htsmodelling.com/benchmark-1/ |
| canonical landing | https://htsmodelling.com/?page_id=748 |
| solutions PDF | https://htsmodelling.com/hubfs/benchmarks/1/downloads/B1_results.pdf |
| license | **unclear** — no explicit license statement on htsmodelling.com; "© 2026 HTS MODELLING WORKGROUP" footer copyright only |
| access date | 2026-05-21 |

## Geometry summary

Single thin rectangular REBCO tape, infinite-strip approximation (2-D Cartesian, plane perpendicular to tape length):

- tape width: **12 mm**
- tape thickness: **1 μm** (HTS layer only)
- critical current: **Ic = 300 A**
- excitation frequency: **50 Hz** (AC transport current)
- background field: zero (transport-current-only variant) or as defined by case

## Required simulations (per upstream)

1. **Single ratio:** I/Ic = 0.5 — extract J(x) and B(x) profiles across tape width.
2. **AC-loss sweep:** I/Ic ∈ {0.1, 0.2, …, 0.9} — extract instantaneous and cycle-averaged dissipated power per unit length.

## Formulation

Upstream is *formulation-agnostic*: this is a benchmark **problem statement**, not a particular implementation. Multiple workgroup submissions cover H, A, T-A, and integral approaches. For our HTS-grade work (RTSC.md §4.2 Axis E) the canonical match is the **H-formulation** (vector field H as the unknown, edge elements, power-law E-J constitutive `E = E_c (J/Jc)^n`).

## Dimension

**2-D Cartesian** (cross-section of an infinitely-long tape). NOT axisymmetric. Our existing `solenoid_axisym.pro` is 2-D axisym, so this benchmark complements rather than overlaps it.

## Required parameters (E-J + Jc)

The benchmark statement does not pin Jc(B,T) — implementers pick one. Common workgroup choices:

- **Power-law E-J:** `E = E_c · (J/Jc)^n`, with E_c = 1e-4 V/m, n typically 21–30 for REBCO at 77 K.
- **Field-dependent Jc:** Kim–Anderson model `Jc(B) = Jc0 / (1 + |B|/B0)^α` or anisotropic `Jc(B, θ)` table.
- Self-field-only studies often hold Jc0 ≈ 2.5e10 A/m² (= 300 A / (12 mm × 1 μm)) constant.

## Canonical citation

- Workgroup landing — https://htsmodelling.com/?page_id=748
- Review (H-formulation): Shen, Grilli, Coombs (2020), SuST 33 033002 — https://arxiv.org/abs/1908.02176
- Origin paper (single time-step 3-D H-FEM): Pecher, Sirois (2008) — https://arxiv.org/abs/0811.2883

## Fetch instructions (developer-side, on demand)

No third-party files are vendored here. To **run** an implementation of this benchmark locally, choose ONE of:

1. **GetDP / life-hts (h-formulation, single tape, 2-D Cartesian)** — see sibling `../life_hts_pancakes_ref/fetch.sh` and adapt the `tape/` subdir (rather than `pancakesHPhi/`). The relevant upstream file is `life-hts/tape/tape.pro` + `tape.geo` + `tape_data.pro`.
2. **COMSOL .mph submissions** — browse https://htsmodelling.com/model-files/ and request a free workgroup account; downloads are gated per-author.

## Smoke-test verdict

N/A — no `.pro` file vendored. Out-of-band smoke check against a locally-cloned `life-hts/tape/tape.pro` (via sibling `../life_hts_pancakes_ref/fetch.sh`) parses through includes cleanly on GetDP 3.5.0 but errors at `lib/lawsAndFunctions.pro:67` with `Unknown Function: RhoPowerLaw` — *upstream targets GetDP 4.0.0*, not a syntax issue. To exercise this benchmark a developer needs GetDP 4.0.0 installed locally. License of the upstream `.pro` files remains unclear; do not vendor.
