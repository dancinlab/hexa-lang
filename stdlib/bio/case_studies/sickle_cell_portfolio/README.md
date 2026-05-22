# Sickle Cell Disease (SCD) portfolio — in-silico case study (one-disease pilot)

**Status**: case-study artefact. ONE-DISEASE PILOT, NOT the deferred
200-disease re-mapping. Reading this document does NOT change the
hexa-bio core-5 axes or expansion-layer registrations.

SCD is — to the author's knowledge at the time of writing — the most
thoroughly axis-mapped SCD-relevant disease portfolio in this repo: it
is the rare disease with FDA-approved drugs spanning **multiple
distinct modality classes** (small-molecule hemoglobin modulator;
ribonucleotide reductase inhibitor; antioxidant substrate;
CRISPR-based ex-vivo gene editing; lentiviral gene therapy; humanized
anti-P-selectin mAb). The portfolio is rich precisely because the
honest record carries six FDA-approved drugs across three
structurally-distinct categories.

## §0 Honest scope

This is a per-disease in-silico composition of two existing axis sims
against the single FDA-approved CDER small molecule that maps cleanly
onto in-repo axes — voxelotor. It is:

- a HONEST one-disease pilot, NOT the deferred 200-disease re-mapping;
- an in-silico simulator-consistency composition only — NOT a
  clinical, therapeutic, efficacy, regulatory, immunogenic, or
  portfolio-recommendation claim (governance g8 / f2);
- a real-drug demonstration that the cross-axis machinery handles a
  drug whose mechanism is genuinely DUAL: voxelotor is simultaneously
  a protein-protein-interaction disruptor AND an allosteric R/T
  modulator. Both readings are present in the published mechanism
  literature; the portfolio records BOTH axis mappings rather than
  forcing a choice.

## §1 The SCD FDA-approved drug landscape (six drugs, three categories)

| # | Drug (brand) | Sponsor | FDA year | FDA center | Modality | Category |
|---|---|---|---|---|---|---|
| 1 | **voxelotor** (Oxbryta) | Pfizer / Global Blood Therapeutics | 2019 | CDER | hemoglobin oxygen-affinity modulator — α-Val1 Schiff-base linkage; stabilizes R (oxy) state | IN-SCOPE, axis-mapped (PPI + ALLOSTERIC dual) |
| 2 | **hydroxyurea** (Hydrea / Droxia / Siklos) | BMS; Addmedica | 1998 (SCD) | CDER | ribonucleotide reductase inhibitor; induces fetal hemoglobin (HbF) | CDER-in-scope, NO axis mapping |
| 3 | **L-glutamine** (Endari) | Emmaus Medical | 2017 | CDER | oral pharmaceutical-grade L-glutamine; antioxidant nitrogen substrate | CDER-in-scope, NO axis mapping |
| 4 | **exagamglogene autotemcel / exa-cel** (Casgevy) | Vertex / CRISPR Therapeutics | 2023 | **CBER** | ex-vivo CRISPR-Cas9 BCL11A enhancer edit → HbF reactivation | UNPLACED (criterion #4) |
| 5 | **lovotibeglogene autotemcel / lovo-cel** (Lyfgenia) | bluebird bio | 2023 | **CBER** | autologous lentiviral β-globin (T87Q) gene addition | UNPLACED (criterion #4) |
| 6 | **crizanlizumab** (Adakveo) | Novartis | 2019 | **CBER** | humanized anti-P-selectin mAb | UNPLACED (criterion #4) |

Originally-approved years for hydroxyurea (the molecule) are 1967 for
neoplastic disease as Hydrea; the SCD-specific supplemental approval
as Droxia was 1998-02-25. Crizanlizumab's regulatory history is
complicated — the EMA conditional marketing authorization was REVOKED
in 2023 after the STAND confirmatory trial failed to demonstrate
benefit, but FDA approval has remained in place through 2024 at the
time of this writing. Readers should re-check current FDA status on
Drugs@FDA before quoting.

### 1.1 voxelotor (Oxbryta) → DUAL axis mapping (PPI primary + ALLOSTERIC secondary)

Voxelotor binds the α-chain N-terminal Val1 of hemoglobin via a
reversible Schiff-base / aldehyde-imine linkage and stabilizes the R
(oxy) tetramer state. Two simultaneous consequences flow from the
same R-state stabilization:

1. **PPI side (primary).** The α-chain N-terminal contact patch is
   part of the HbS-HbS deoxy-polymer interface that propagates the
   sickle polymer. Reducing the deoxy-HbS population AND occupying
   the α-Val1 contact patch disrupts the HbS-HbS protein-protein
   contact that drives polymerization. This is the mechanism the
   portfolio records as the *primary* axis: `PPI :> QUANTUM`.
   - Real-limit anchor: Bogan & Thorn 1998 binding-hotspot theory;
     druggability of flat hotspot-driven PPIs per Wells & McClendon
     2007. Sickle polymer contact geometry: Wishner & Love 1975;
     Harrington *et al.* 1997.
2. **ALLOSTERIC side (secondary).** R-state stabilization is the
   textbook MWC mechanism. From the modulator's perspective, voxelotor
   is a positive allosteric modulator (PAM) of oxygen binding —
   α > 1, oxygen affinity enhanced, the Hb-O₂ dissociation curve
   shifts left.
   - Real-limit anchor: Monod, Wyman & Changeux 1965 concerted
     two-state allosteric model; ternary-complex / two-state
     extension per Hall 2000 and Christopoulos & Kenakin 2002.
     Perutz's R/T two-state account (Perutz 1970) is the
     domain-specific anchor.

Both readings are simultaneously correct. The portfolio's schema
supports this honestly via a list-of-axes (`axis_mappings`) per
drug — a structural feature that the prior single-axis portfolios
(HIV-1, SMA, BCL-2, KRAS-G12C, migraine, MPro/COVID, type-2 diabetes,
Alzheimer, landscape) do not need.

#### Drug-precedent references (own precedent only — g3 / f1)
- Oksenberg *et al.*, *Br. J. Haematol.* 175:141 (2016) — GBT440 /
  voxelotor discovery + HbS polymerization inhibition.
- Metcalf *et al.*, *ACS Med. Chem. Lett.* 8:321 (2017) — GBT440 /
  voxelotor — R-state HbS stabilization by α-Val1 Schiff-base linkage.
- Vichinsky *et al.*, *N. Engl. J. Med.* 381:509 (2019) — HOPE trial,
  voxelotor in SCD.
- FDA NDA 213137 — voxelotor (Oxbryta) approval, 2019-11-25, CDER.

### 1.2 hydroxyurea / L-glutamine → CDER-in-scope, NO axis mapping

Both drugs are FDA-approved CDER small molecules that fall **inside**
the hexa-bio criterion #4 drug-only/CDER scope, but whose mechanisms
do not map cleanly onto any current in-repo axis:

- **hydroxyurea** is a ribonucleotide reductase inhibitor whose
  clinical effect in SCD is mediated primarily by HbF reactivation —
  a gene-expression / transcriptional response (NO-mediated
  upregulation of γ-globin). It is not a PPI disruptor, not an
  allosteric modulator on a defined MWC two-state target, not an
  RNA-targeting small molecule, not an oligonucleotide, not a capsid
  modulator, not a bifunctional degrader.
- **L-glutamine** is a nitrogen substrate that supports erythrocyte
  NAD⁺ / glutathione redox balance — an antioxidant-substrate
  mechanism. It is metabolic substrate provision, not a target-bound
  small molecule on any current in-repo axis.

The honest call: list them structurally as
`cder_in_scope_but_no_axis_mapping`, not invent a forced axis. This
category is a coverage **fact**, not a coverage **failure**: the
hexa-bio axis tree does not pretend to cover every CDER mechanism
(criterion #4 only requires CDER for inclusion, not that every CDER
mechanism have an axis).

#### Drug-precedent references (own precedent only — g3 / f1)
- Charache *et al.*, *N. Engl. J. Med.* 332:1317 (1995) — Multicenter
  Study of Hydroxyurea in Sickle Cell Anemia.
- FDA NDA 016295 (Hydrea, originally 1967 for neoplastic disease;
  SCD supplemental approval as Droxia 1998-02-25, CDER).
- FDA NDA 208843 — Siklos pediatric SCD approval 2017-12-21 (CDER).
- Niihara *et al.*, *N. Engl. J. Med.* 379:226 (2018) — Phase III
  L-glutamine in SCD.
- FDA NDA 208587 — Endari approval 2017-07-07, CDER.

### 1.3 Casgevy / Lyfgenia / Adakveo → CBER UNPLACED (criterion #4)

Three FDA-approved SCD drugs are **CBER**-regulated biologics —
outside the hexa-bio drug-only/CDER criterion #4 scope. Same UNPLACED
pattern as Zolgensma in the SMA portfolio:

- **exa-cel / Casgevy** (FDA 2023-12-08) — first FDA-approved
  CRISPR-based therapy; ex-vivo CRISPR-Cas9 editing of patient
  CD34+ HSCs at the BCL11A erythroid enhancer to de-repress
  γ-globin and reactivate HbF.
- **lovo-cel / Lyfgenia** (FDA 2023-12-08) — autologous lentiviral
  gene-addition therapy: BB305 vector → modified anti-sickling
  β-globin (T87Q). Carries a boxed-warning label for hematologic
  malignancy risk associated with lentiviral integration.
- **crizanlizumab / Adakveo** (FDA 2019-11-15) — humanized anti-
  P-selectin mAb. Regulatory complexity flagged honestly: EMA
  conditional marketing authorization REVOKED in 2023; FDA approval
  intact through 2024 at the time of this writing.

The witness records all three as `not_in_scope_drugs[]` with
`axis: null`, `in_scope: false`, `category:
cber_unplaced_criterion_4`, `reported_not_run: true`.

#### Drug-precedent references (own precedent only — g3 / f1)
- Frangoul *et al.*, *N. Engl. J. Med.* 384:252 (2021) — CTX001
  (now exa-cel) editing BCL11A enhancer in SCD / TDT.
- FDA STN BL 125787 — exa-cel (Casgevy) approval, 2023-12-08, CBER.
- Kanter *et al.*, *N. Engl. J. Med.* 386:617 (2022) — LentiGlobin /
  lovo-cel in SCD.
- FDA STN BL 125765 — lovo-cel (Lyfgenia) approval, 2023-12-08, CBER.
- Ataga *et al.*, *N. Engl. J. Med.* 376:429 (2017) — SUSTAIN trial,
  crizanlizumab in SCD.
- FDA STN BL 761128 — crizanlizumab (Adakveo) approval, 2019-11-15,
  CBER.

## §2 In-silico runs (deterministic, stdlib-only)

The runner (`sickle_cell_portfolio_runner.py`) imports two parent sims
(f3 — no fork) and exercises voxelotor on BOTH axis sides; it emits a
single aggregated portfolio witness:

- **voxelotor PPI side (primary)** →
  `_python_bridge/module/ppi_sim.py` `interface_profile()` is called
  with a literature-informed surrogate ΔΔG signature for the HbS-HbS
  deoxy-polymer contact patch (per the parent sim's panel convention
  — "illustrative literature-informed surrogates for interface
  CLASSES, not fits to a specific complex"). Bogan & Thorn 1998
  real-limit anchor.
- **voxelotor allosteric side (secondary)** →
  `_python_bridge/module/allosteric_sim.py` `allosteric_profile()` is
  called with a literature-informed α/K_B surrogate for the PAM class
  on the Hb R/T equilibrium. MWC 1965 real-limit anchor.

Each side's PASS is anchored to the parent sim's real-limit citation
(g1). Output rows validate against `portfolio_v1.schema.json`. The
two-step input values (ΔΔG list / mimicry fraction; α / K_B) are
illustrative surrogates for the mechanism CLASS, not measured
binding-energetics — exactly as documented in the parent sims'
honesty notes.

## §3 Structurally-distinct categories (the honest pattern)

The schema separates THREE categories as structurally-distinct fields:

```
in_scope_drugs[]                     # axis-mapped CDER (voxelotor)
cder_in_scope_no_axis_mapping[]      # CDER in-scope, no axis (hydroxyurea, L-glutamine)
not_in_scope_drugs[]                 # CBER UNPLACED (Casgevy, Lyfgenia, crizanlizumab)
```

This is a strict extension of the prior portfolios' two-bucket pattern
(`in_scope_drugs` + `not_in_scope_drugs` / `research_stage_negatives`).
SCD genuinely needs the third bucket: the disease has FDA-approved
CDER drugs whose mechanism is **honest enough to admit** the axis
tree does not yet cover them — distinct from research-stage
negatives (no drug exists yet) and distinct from CBER UNPLACED
(criterion #4 disqualified). Carrying all three buckets is what makes
this portfolio the most thoroughly axis-mapped SCD-relevant disease
portfolio in this repo.

## §4 Cross-axis touch-points

The repo crosses voxelotor-relevant axes:

- **G2 — ALLOSTERIC × CRYPTIC-POCKET**
  (`_python_bridge/module/allosteric_cryptic_pocket_cross.py`):
  proves the MWC two-state model and the cryptic-pocket open/closed
  population coincide identically under R↔open mapping. Voxelotor's
  R-state stabilization is the textbook MWC mechanism G2 formalizes.
- **G3 — PPI × MOLECULAR-GLUE**
  (`_python_bridge/module/ppi_molecular_glue_cross.py`): cited for
  completeness of the cross-axis touch-point map. Voxelotor is a PPI
  disruptor (not a glue), so G3 is referenced as a framework anchor
  for the PPI side, not as a mechanism claim for voxelotor.

This case study composes the existing sims; it does NOT introduce new
chemistry.

## §5 Governance

- **g1 real-limits-first.** The voxelotor PPI side cites Bogan & Thorn
  1998 (binding-hotspot theory) + Wells & McClendon 2007 (flat-PPI
  druggability) + Wishner & Love 1975 / Harrington 1997 (HbS contact
  geometry). The voxelotor allosteric side cites Monod, Wyman &
  Changeux 1965 (MWC concerted two-state) + Hall 2000 / Christopoulos
  & Kenakin 2002 (ternary-complex / two-state extension) + Perutz
  1970 (R/T two-state account of hemoglobin).
- **g3 / f1 / f_lattice_fit**. Drugs are described by their OWN
  published precedent only: voxelotor (Oxbryta, FDA 2019);
  hydroxyurea (Hydrea, FDA 1967; SCD as Droxia 1998); L-glutamine
  (Endari, FDA 2017); Casgevy (CRISPR/Vertex, FDA 2023); Lyfgenia
  (bluebird bio, FDA 2023); crizanlizumab (Adakveo, FDA 2019).
  Nothing is derived from the n=6 lattice.
- **g8 / f2 in-silico-only**. Every PASS verifies in-silico simulator+
  metadata consistency ONLY — NEVER a clinical, therapeutic,
  regulatory, efficacy, or portfolio-recommendation claim. Wet-lab /
  clinical boundary out of scope (`CLOSURE_RESIDUAL_BACKLOG.md` §0).
- **f3 no-fork**. Both parent sims (`ppi_sim`, `allosteric_sim`) are
  IMPORTED via `importlib`, never re-implemented.
- **criterion #4 drug-only / CDER**. The single in-scope drug
  (voxelotor) is CDER. The two CDER-no-axis drugs are CDER but
  honestly recorded as having no current in-repo axis mapping. The
  three CBER drugs (Casgevy, Lyfgenia, crizanlizumab) are honestly
  UNPLACED with no fabricated coverage — same pattern as Zolgensma
  in the SMA portfolio.

## §6 Files

- `README.md` — this document.
- `sickle_cell_portfolio_runner.py` — deterministic stdlib-only
  runner; imports the two parent sims; emits the portfolio witness;
  sentinel `__SICKLE_CELL_PORTFOLIO__ PASS`.
- `portfolio_v1.schema.json` — draft-07 JSON Schema. Supports the
  voxelotor DUAL axis mapping via an `axis_mappings` LIST per drug
  (distinct from prior portfolios' single-axis pattern). Schema-const
  enforcement of all three structurally-distinct honesty categories
  (`in_scope_drugs` / `cder_in_scope_no_axis_mapping` /
  `not_in_scope_drugs`).

Run the runner directly:

```bash
python3 case_studies/sickle_cell_portfolio/sickle_cell_portfolio_runner.py
```

Expected: exit 0, last line `__SICKLE_CELL_PORTFOLIO__ PASS`. The
witness JSON is emitted on stdout and is byte-identical on every run.

## §7 What this case study is NOT

- NOT a portfolio recommendation, ranking, or investment thesis.
- NOT a claim that any one of the six drugs is superior. All six are
  FDA-approved (with the regulatory complexity around crizanlizumab
  flagged honestly).
- NOT a clinical, regulatory, immunogenicity, dosing, or efficacy
  claim.
- NOT a derivation of voxelotor's dual mechanism from the n=6
  lattice. The dual mapping is a property of the published mechanism
  literature, not of any lattice tautology.
- NOT the deferred 200-disease portfolio re-mapping; this is the
  one-disease SCD pilot only.
