# Drug-redesign sandbox — one-target modality-space map

**Status**: case-study artefact. ONE-TARGET SANDBOX, NOT a redesign
recommendation. Reading this document does NOT change the hexa-bio
core-5 axes or expansion-layer registrations.

## §0 Honest scope

This is the most dangerous artefact in the repo to over-claim about, so
the scope is stated up front and reinforced in every section below.

- **One target.** SARS-CoV-2 Mpro. One real FDA-approved drug.
  nirmatrelvir / Paxlovid (Pfizer; FDA EUA 2022, full approval 2023).
- **Sandbox, NOT a redesign.** The artefact runs four axis sims
  against the SAME target and reports the model SIGNATURES side by
  side. It is an HONEST MODALITY-SPACE MAP — what each axis lens
  predicts about a drug-like molecule with that mechanism would look
  like as an in-silico model — NOT a proposal that any of the three
  alternative lenses is "better than" nirmatrelvir.
- **No clinical / efficacy / regulatory claim.** Every PASS is
  IN-SILICO simulator + metadata internal consistency ONLY
  (governance g8 / forbidden-pattern f2). It is NEVER a binding-
  affinity measurement, NEVER a potency / selectivity / efficacy
  prediction, NEVER a redesign recommendation.
- **The original drug is the clinically-validated truth.** The
  in-silico signature for the L1 (status-quo, reversible-covalent
  nitrile) lens models nirmatrelvir's modality CLASS, not nirmatrelvir
  itself. The three alternative lenses (L2/L3/L4) are research /
  illustrative projections of what the modality space LOOKS like under
  different axis assumptions; they are NOT actual redesign proposals.
- **NOT the 200-disease re-mapping.** `AXIS/HIERARCHY.tape` Log keeps
  the broad 200-disease re-mapping explicitly deferred. This sandbox
  is one target, four lenses, four model signatures.

## §1 The target — SARS-CoV-2 Mpro and the real drug

**SARS-CoV-2 Mpro** (3CLpro / nsp5 / main protease) is a viral cysteine
protease with a catalytic Cys145 / His41 dyad. It is functionally
obligate-dimeric: each protomer's N-finger inserts into a cleft of the
partner, stabilising the active-site pocket. Mpro cleaves the viral
polyprotein at ~11 conserved sites, releasing functional non-structural
proteins (Nsp4-Nsp16).

**nirmatrelvir** (the protease-inhibitor component of Paxlovid) is a
reversible-covalent small-molecule inhibitor with a nitrile warhead;
the nitrile carbon forms a thioimidate adduct with the Cys145 thiolate
— a reversible covalent linkage (measurable koff, finite residence
time), distinct from the irreversible acrylamide-warhead modality of
e.g. ibrutinib / sotorasib.

### Drug-precedent references (own precedent only — g3 / f1)
- **nirmatrelvir**: Owen *et al.*, *Science* 374:1586 (2021) —
  PF-07321332 discovery; Boras *et al.*, *Nat. Commun.* 12:6055 (2021)
  — Cys145 thioimidate adduct; FDA EUA (2022-12-22); FDA NDA 217188
  Paxlovid full approval (2023-05-25).
- **Mpro dimerization (L4 background)**: Goyal & Goyal,
  *Protein Sci.* 22:1547 (2013) — dimerization-disruption as a research
  strategy. No FDA-approved Mpro PPI disruptor exists.

## §2 The four lenses

The sandbox redesigns nirmatrelvir's MODALITY through four axis lenses
against the same target. Each lens is the in-silico signature of an
axis sim already in the repo:

| # | Lens | Sub-axis :> parent axis | Layer | Parent sim |
|---|---|---|---|---|
| **L1** | reversible covalent (**status quo**) | `REVERSIBLE-COVALENT` `:> COVALENT` | sub-axis | `_python_bridge/module/reversible_covalent_sim.py` |
| **L2** | irreversible covalent (acrylamide; illustrative re-engineering) | `COVALENT` | expansion-main | `_python_bridge/module/covalent_inhibition_sim.py` |
| **L3** | degradation (PROTAC; illustrative) | `PROTAC` `:> BIFUNCTIONAL` | sub-axis | `_python_bridge/module/protac_sim.py` |
| **L4** | PPI disruption (Mpro dimerization; illustrative) | `PPI` `:> QUANTUM` | sub-axis | `_python_bridge/module/ppi_sim.py` |

Per `f3` (no-fork) all four parent sims are IMPORTED via `importlib`;
the runner re-implements none of their logic.

## §3 In-silico runs (per-lens signature)

The runner `drug_redesign_runner.py` pulls one representative row per
parent sim and emits a `sandbox_v1` witness.

### §3.1 L1 — REVERSIBLE-COVALENT (status quo, nirmatrelvir-style)

- Parent sim: `reversible_covalent_sim.py` — selects the panel's
  `nitrile_nirmatrelvir` row.
- Signature: forward / reverse Eyring rates kon and koff for a covalent
  EQUILIBRIUM with ΔG‡_on ≈ 18 kcal/mol and a near-thermoneutral
  ΔG_rxn ≈ −1.5 kcal/mol; K_eq = kon/koff cross-checked against the
  thermodynamic exp(−ΔG_rxn/RT); residence time τ_res = 1/koff;
  reversibility classification `koff ≥ 1e-4 /s`.
- Real-limit anchor (g1): **Eyring transition-state theory** (Eyring,
  *J. Chem. Phys.* 3:107, 1935). The universal frequency prefactor
  kB·T/h ≈ 6.46e12 /s @ T = 310 K is the hard physical ceiling on every
  elementary covalent rate.

### §3.2 L2 — COVALENT (irreversible acrylamide; illustrative)

- Parent sim: `covalent_inhibition_sim.py` — selects the panel's
  `sotorasib_KRAS_Cys12` row as the SURROGATE for an acrylamide warhead
  acting on a catalytic cysteine.
- Signature: two-step `E + I ⇌(Ki) E·I → kinact → E–I` kinetics;
  kinact/Ki second-order efficiency (Strelow framework); kobs and
  free-enzyme half-life t_1/2 = ln2 / kobs at a 1 µM reference [I];
  Eyring-predicted kinact_TST from ΔG‡_cov ≈ 19 kcal/mol; the implied
  ΔG‡ from the input kinact reported alongside the input ΔG‡ as a
  consistency window.
- Real-limit anchors (g1): **Strelow kinact/Ki framework** (Strelow,
  *J. Biomol. Screen. / SLAS Discov.* 22:3, 2017) — the second-order
  efficiency constant ranks covalent inhibitors the way kcat/Km ranks
  substrates. **Eyring TST** (1935) — the universal prefactor kB·T/h
  is the hard ceiling on every covalent-step rate.
- Why this is illustrative-only: published Mpro warhead chemistry
  deliberately favours REVERSIBLE warheads (nitrile / aldehyde /
  α-ketoamide) for viral-protease selectivity. The acrylamide CLASS is
  used here as a model signature for "what an irreversible covalent
  Mpro inhibitor would LOOK like as an in-silico model" — NOT a
  recommendation to put an acrylamide on Mpro Cys145.

### §3.3 L3 — PROTAC :> BIFUNCTIONAL (illustrative)

- Parent sim: `protac_sim.py` — selects the panel's
  `strongcoop_PROTAC_like` row as an in-silico signature for what a
  strongly-cooperative ternary complex would look like.
- Signature: mass-action ternary-complex equilibrium across a fixed
  [PROTAC] grid; apparent K_d,ternary = K_d(E3) / α (cooperativity
  factor); ternary-fraction peak; the bell-shaped hook effect at high
  [PROTAC]; ubiquitin-transfer-competence × ternary-peak →
  degradation_drive.
- Real-limit anchors (g1): **Douglass three-body equilibrium**
  (Douglass *et al.*, *J. Am. Chem. Soc.* 135:6092, 2013); **Gadd
  cooperativity α** (Gadd *et al.*, *Nat. Chem. Biol.* 13:514, 2017);
  Han, *J. Biol. Chem.* 295:15280 (2020) — ternary mathematical
  solutions; law of mass action θ = 1/2 exactly at [L] = K_d as a
  numerical sanity gate.
- Why this is illustrative-only: no FDA-approved PROTAC exists in any
  indication at the witness ts (ARV-471 and ARV-110 are clinical-
  stage). Viral-protease degraders face host-E3-ligase availability
  constraints in infected cells that this surrogate does NOT model.
  The chosen row is a strong-cooperativity REFERENCE, not a real Mpro
  PROTAC.

### §3.4 L4 — PPI :> QUANTUM (Mpro dimerization disruption; illustrative)

- Parent sim: `ppi_sim.py` — selects the `mdm2_p53_cleft` row (an
  α-helix-peptide-cleft hotspot interface) as the SURROGATE for an
  Mpro N-finger / cleft dimerization interface signature.
- Signature: alanine-scanning ΔΔG ledger; Bogan-Thorn hotspot
  threshold (ΔΔG ≥ 2 kcal/mol); hotspot fraction;
  ΔG_interface = −Σ ΔΔG_i; hotspot-mimicry gate
  ΔG_mimic = mimicry_fraction · ΔG_hotspot_cluster; viability if
  ΔG_mimic ≤ −7 kcal/mol; ledger-conservation cross-check.
- Real-limit anchor (g1): **Bogan-Thorn binding-hotspot theory**
  (Bogan & Thorn, *J. Mol. Biol.* 280:1, 1998) — interface binding
  free energy is concentrated in a few hotspot residues, NOT spread
  uniformly over the buried surface; the small-molecule mimic cannot
  recover more energy than the alanine-scanning ledger carries.
  Clackson & Wells, *Science* 267:383 (1995); Wells & McClendon,
  *Nature* 450:1001 (2007) — PPI druggability.
- Why this is illustrative-only: the ΔΔG values are surrogates for an
  interface CLASS, not a measured alanine scan of the Mpro dimer.
  Goyal & Goyal (2013) is cited for the Mpro-dimerization-disruption
  research strategy; venetoclax (FDA 2016, BH3-mimetic BCL-2 disruptor)
  is the cited PPI-drug precedent for the MODALITY, NOT for the
  target.

## §4 Honest framing — what this artefact is and is not

A drug-redesign sandbox is the most dangerous artifact in the repo to
overclaim about. The frame is therefore explicit and is enforced
structurally in the witness JSON.

- **The original drug is the clinical truth.** nirmatrelvir / Paxlovid
  is FDA-approved and clinically validated. The L1 (status-quo) row is
  a MODEL signature of the nitrile-warhead CLASS, not a fit to
  nirmatrelvir's measured Ki / kinact / residence time.
- **The three alternative lenses are research / illustrative.** L2
  (irreversible covalent), L3 (PROTAC), L4 (PPI disruption) describe
  what their respective modalities LOOK like as in-silico signatures.
  None is a proposed redesign of nirmatrelvir.
- **No ranking, no efficacy prediction.** The schema encodes
  `comparison_is_ranking = false` and `not_a_redesign_recommendation =
  true` as schema `const` values; every alternative-lens row carries
  `illustrative_only = true` and `not_a_redesign_recommendation =
  true`. The witness STRUCTURE itself enforces the framing — there is
  no way to emit a passing witness that ranks the lenses or claims
  redesign progress.
- **A5 caveat pattern.** This sandbox echoes the existing A5 cross
  (`reversible_covalent_mpro_vqe_cross.py`) `illustrative_only = true`
  pattern on every alternative-lens row. The A5 cross uses the same
  pattern because qualitative inputs + barrier-proxy modeling choices
  cannot support a non-illustrative claim.

## §5 Cross-links — what this builds on (not what it replaces)

- **A5 cross — REVERSIBLE-COVALENT × Mpro warhead VQE** —
  `_python_bridge/module/reversible_covalent_mpro_vqe_cross.py`. The
  existing bridge that already crosses the L1 modality (reversible
  covalent) with the Mpro warhead library VQE. This sandbox echoes A5's
  `illustrative_only` caveat pattern.
- **mpro warhead library VQE** —
  `tests/mpro_warhead_library_vqe_v7.py`. Already covers the Mpro
  Cys145 warhead-class space; the sandbox builds on it (not modified)
  and adds three more axis lenses (L2 / L3 / L4) around it.
- **Parent sims (all four IMPORTED via importlib — f3 no-fork)**:
  - L1 — `_python_bridge/module/reversible_covalent_sim.py`
  - L2 — `_python_bridge/module/covalent_inhibition_sim.py`
  - L3 — `_python_bridge/module/protac_sim.py`
  - L4 — `_python_bridge/module/ppi_sim.py`
- **Sister case-study patterns** — `case_studies/hiv1_portfolio/`
  and `case_studies/sma_portfolio/` are the parity templates this
  sandbox follows (deterministic stdlib-only runner; draft-07 schema
  with honesty consts; explicit cross-link block).

## §6 Governance

- **g1 real-limits-first**: each lens row carries its parent sim's
  real-limit citation: L1 Eyring TST (Eyring 1935; Singh 2011;
  Boike 2022); L2 Strelow kinact/Ki (Strelow 2017) + Eyring TST
  (Eyring 1935); L3 Douglass three-body (Douglass 2013) + Gadd
  cooperativity α (Gadd 2017) + Han (2020); L4 Bogan-Thorn binding-
  hotspot theory (Bogan & Thorn 1998) + Clackson-Wells (1995) + Wells-
  McClendon (2007).
- **g3 / f1 / f_lattice_fit honesty-external**: each modality is
  described by its OWN precedent — nirmatrelvir for L1; the
  acrylamide-warhead drug class (ibrutinib / sotorasib / afatinib) for
  L2; the PROTAC class (Sakamoto 2001; ARV-471; ARV-110) for L3; the
  BH3-mimetic class (venetoclax / navitoclax) and Goyal & Goyal (2013)
  for L4. **No quantity is derived from the n=6 lattice.**
- **g8 / f2 in-silico-only**: every PASS verifies IN-SILICO simulator +
  metadata internal consistency ONLY. NEVER a redesign claim, NEVER a
  clinical / therapeutic / efficacy / potency / selectivity /
  regulatory claim. nirmatrelvir is the validated truth; L2/L3/L4 are
  illustrative.
- **f3 no-fork**: all four parent sims are IMPORTED via `importlib`;
  none of their logic is re-implemented. The runner is a composer, not
  a re-prover.
- **Scope discipline**: ONE-TARGET sandbox. NOT the deferred 200-
  disease re-mapping (`AXIS/HIERARCHY.tape` Log). Core-5 axes
  UNCHANGED; no expansion-layer registrations are touched.

## §7 Files

- `README.md` — this document.
- `drug_redesign_runner.py` — deterministic stdlib-only runner;
  imports the four parent sims; emits the sandbox witness; sentinel
  `__DRUG_REDESIGN_SANDBOX__ PASS`.
- `sandbox_v1.schema.json` — draft-07 schema; honesty constants
  (`comparison_is_ranking = false`, `not_a_redesign_recommendation =
  true`, `original_drug_remains_the_clinical_truth = true`,
  `all_alternative_lenses_illustrative = true`) are enforced as
  schema `const` values so the witness STRUCTURE itself encodes the
  framing.

## §8 Log

- 2026-05-16 — Drug-redesign sandbox case study created. One target
  (SARS-CoV-2 Mpro), one real FDA-approved drug (nirmatrelvir /
  Paxlovid). Four axis lenses (L1 REVERSIBLE-COVALENT status quo;
  L2 COVALENT irreversible illustrative; L3 PROTAC :> BIFUNCTIONAL
  illustrative; L4 PPI :> QUANTUM illustrative). All four parent sims
  IMPORTED via importlib (f3 no-fork). Each alternative-lens row
  carries `illustrative_only = true` and
  `not_a_redesign_recommendation = true`, echoing the A5 caveat
  pattern. Honesty constants encoded in the schema. Sentinel
  `__DRUG_REDESIGN_SANDBOX__ PASS` (acceptance 10/10). Core-5 axes
  UNCHANGED; no shared files edited.
