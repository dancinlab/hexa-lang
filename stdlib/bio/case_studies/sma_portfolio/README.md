# SMA portfolio — case study

Spinal muscular atrophy (SMA) is the rare disease where **three FDA-approved
drugs target the same disease via three distinct modalities**. Two of the
three map cleanly onto hexa-bio expansion-layer axes; the third is honestly
UNPLACED. This case study writes that fact up.

## §0 Honest scope

This is a **one-disease pilot** — SMA only. It is NOT the 200-disease
portfolio re-mapping that the AXIS/HIERARCHY.tape log flags as deferred
work; that effort remains deferred. The deliverable here is:

1. a portfolio writeup of the three FDA-approved SMA drugs and how they
   map (or honestly do not map) onto the hexa-bio axis tree;
2. a deterministic stdlib-only Python runner that exercises the two
   axis-mapped sims and emits a portfolio witness JSON;
3. a draft-07 JSON Schema for that witness, with **separate fields** for
   the in-scope drugs and the honestly UNPLACED drug (so the UNPLACED
   handling is a *structural* feature of the witness, not a comment).

This case study **EXTENDS** the existing single-disease SMN2 modality
comparison (`_python_bridge/module/rna_modality_comparison_smn2_cross.py`
— Project A3 in `AXIS/HIERARCHY.tape` §2.5) into a fuller portfolio
writeup; it does **NOT** duplicate or supersede A3.

Every PASS here is **in-silico simulator-consistency only** (governance
g8 / f2). It is NEVER a therapeutic, clinical, splicing-correction,
efficacy, immunogenic, regulatory, or portfolio-recommendation claim.

## §1 The three FDA-approved SMA drugs and their modality mapping

SMA is caused by loss of `SMN1`; the near-identical paralog `SMN2` carries
a single C>T variant in exon 7 that makes exon 7 mostly SKIPPED, producing
an unstable truncated SMN protein. The three FDA-approved drugs each hit
this biology in a physically different way:

| # | Drug (brand) | Sponsor | FDA year | FDA center | Modality | Axis mapping |
|---|---|---|---|---|---|---|
| 1 | **risdiplam** (Evrysdi) | Roche / PTC Therapeutics / SMA Foundation | 2020 | CDER | small molecule — SMN2 exon-7 5'-splice-site splicing modulator | `RNA-TARGETING-SMALL-MOLECULE` (`:>` `RIBOZYME` core) |
| 2 | **nusinersen** (Spinraza) | Biogen / Ionis | 2016 | CDER | antisense oligonucleotide — masks the ISS-N1 intronic splicing silencer in SMN2 intron 7 | `OLIGONUCLEOTIDE` (expansion-main) |
| 3 | **onasemnogene abeparvovec** (Zolgensma) | Novartis (AveXis) | 2019 | **CBER** | AAV9-mediated SMN1 gene therapy — one-time intravenous infusion of an scAAV9 vector carrying functional SMN1 cDNA | **UNPLACED** — `GENETIC-MEDICINE`, no code axis (see §3) |

### 1.1 risdiplam (Evrysdi) → `RNA-TARGETING-SMALL-MOLECULE`

risdiplam is an orally-bioavailable small molecule that binds the SMN2
pre-mRNA exon-7 region and stabilizes the U1 snRNP / 5'-splice-site
interaction, shifting the RNA structural ensemble toward the exon-7
**inclusion-competent** fold. branaplam (LMI070, Novartis) is a second
SMN2 exon-7 splicing-modulator small molecule of the same modality.

- Axis: `RNA-TARGETING-SMALL-MOLECULE` — a sub-axis of `RIBOZYME` declared
  in `AXIS/HIERARCHY.tape` `@D sub_under_ribozyme`. The sub-axis
  specializes the parent's RNA secondary-structure modeling toward
  small-molecule ENSEMBLE SHIFTS (the RNA is the drug target, the small
  molecule is the drug — distinct from RIBOZYME's catalytic-RNA semantics).
- In-axis sim: `_python_bridge/module/rna_targeting_small_molecule_sim.py`
  (deterministic Nussinov ensemble shift; `__RNA_TARGETING_SMALL_MOLECULE__
  PASS`). This runner IMPORTS it (no fork — governance f3).
- Real-limit anchor (g1): RNA secondary-structure thermodynamics.
  Nussinov *et al.* 1978, *SIAM J Appl Math* 35:68-82 (base-pair
  maximization); Turner & Mathews 2010, NNDB, *Nucleic Acids Res*
  38:D280-D282 (nearest-neighbor free-energy / Boltzmann ensemble).
- Drug precedent (g3 / f1, own published modality only): Ratni *et al.*
  2018, *J Med Chem* 61:6501-6517 (risdiplam discovery); Campagne *et al.*
  2019, *Nat Chem Biol* 15:1191-1198 (structural basis at SMN2 exon-7
  5'ss).

### 1.2 nusinersen (Spinraza) → `OLIGONUCLEOTIDE`

nusinersen is an antisense oligonucleotide (ASO) that hybridizes the
ISS-N1 intronic splicing-silencer element in SMN2 intron 7. Masking the
silencer releases exon 7 from suppression, so exon 7 is included. The
mechanism is Watson-Crick duplex formation — NOT an ensemble shift.

- Axis: `OLIGONUCLEOTIDE` — expansion-main axis declared in
  `AXIS/HIERARCHY.tape` `@D axis_oligonucleotide`. nusinersen / Spinraza
  is the named drug precedent for the axis itself.
- In-axis sim: `_python_bridge/module/oligonucleotide_hybridization_sim.py`
  (deterministic SantaLucia 1998 unified NN duplex thermodynamics;
  `__OLIGONUCLEOTIDE_HYBRIDIZATION__ PASS`). This runner IMPORTS it
  (no fork — governance f3).
- Real-limit anchor (g1): nucleic-acid duplex hybridization
  thermodynamics. SantaLucia J Jr 1998, *Proc Natl Acad Sci USA*
  95(4):1460-1465 (the 10 unified nearest-neighbor parameters).
- Drug precedent (g3 / f1, own published modality only): Hua *et al.*
  2008, *Am J Hum Genet* 82:834-848 (ASO masking of ISS-N1); Singh *et al.*
  2006, *Mol Cell Biol* 26:1333-1346 (ISS-N1 intronic silencer in SMN2).

### 1.3 onasemnogene abeparvovec (Zolgensma) → UNPLACED (CBER)

Zolgensma is an AAV9-mediated `SMN1` gene therapy. It is a CBER-regulated
biologic, which puts it OUTSIDE the hexa-bio drug-only/CDER scope
(`AXIS/README.md` criterion #4). The honest call is: **no code axis**.
See §3 for the UNPLACED handling.

## §2 In-silico runs

The runner `sma_portfolio_runner.py` invokes the two existing in-axis
sims on the SMN2 target — the same target the A3 cross uses — and
aggregates the outputs into a single portfolio witness JSON.

### 2.1 What is run

- **risdiplam-like path** — `rna_targeting_small_molecule_sim.simulate()`
  is called with the toy SMN2-exon-7 pre-mRNA construct and the
  exon-inclusion stem window. The small molecule occludes a competing
  5' arm; with that competitor removed the transcript re-folds toward
  the inclusion-competent stem. The reported model signal is the
  structural-ensemble SHIFT (Δ paired-fraction of the exon-inclusion
  stem, baseline → ligand-bound).
- **nusinersen-like path** — `oligonucleotide_hybridization_sim` is
  used: the ASO is designed as the reverse complement of the toy ISS-N1
  element, then `duplex_report()` computes ΔH° / ΔS° / ΔG°(37 °C) / Tm
  via the unified SantaLucia NN sum. The reported model signal is the
  ASO:silencer duplex ΔG°(37 °C) — how stably the ASO would clamp the
  silencer.
- **Zolgensma** — **REPORTED-NOT-RUN**. The portfolio witness emits a
  `not_in_scope_drugs[0]` row with `axis: null`, `in_scope: false`,
  `reported_not_run: true`, and an explicit `reason` string. No sim is
  invoked for this row by design (see §3).

### 2.2 Sequences are toy constructs

The illustrative SMN2 pre-mRNA + ISS-N1 sequences are **toy constructs**,
not genuine SMN2 sequence. They exercise the two mechanism models'
arithmetic; they assert no real splice outcome (g8 / f2). They mirror the
constructs used in the A3 cross so the portfolio touches the same target
without forking sequence data.

### 2.3 Determinism

Both upstream sims are stdlib-only and deterministic. The runner is
likewise stdlib-only. `json.dumps(build_portfolio(), sort_keys=True)`
produces byte-identical output on every run — the deductive-verification
contract used across `_python_bridge/module/`.

## §3 Honest UNPLACED handling — Zolgensma

Zolgensma is the **third FDA-approved SMA drug** and a different modality
from the other two. A naïve portfolio would invent a "GENETIC-MEDICINE
axis" to hold it. That would be **dishonest**: the hexa-bio axis tree is
explicitly drug-only/CDER (criterion #4) and CBER biologics are excluded
by design.

The existing precedent for this pattern lives in `AXIS/HIERARCHY.tape`:

```
@N genetic_medicine_status := "GENETIC-MEDICINE — not placed (CBER scope)"
  text = "GENETIC-MEDICINE (gene therapy / cell therapy / mRNA — own
  precedent: Zolgensma · Casgevy · Comirnaty) is NOT registered as an
  expansion axis and NOT code-implemented: gene/cell therapy and mRNA
  products are CBER-regulated biologics, failing the README drug-only
  (CDER) discipline criterion #4. Status: scope-disqualified — left
  UNPLACED (honest; implementing a CBER-scope code axis would breach
  g8 + criterion #4)."
```

This case study applies **the same pattern** to Zolgensma:

- the witness records Zolgensma in `not_in_scope_drugs[]` with
  `axis: null`, `in_scope: false`, `fda_center: "CBER"`,
  `reported_not_run: true`, and an explicit `reason` string;
- the schema separates `in_scope_drugs` from `not_in_scope_drugs` as
  distinct top-level fields, so the UNPLACED handling is *structurally
  required*, not a comment;
- the row points back to `@N genetic_medicine_status` via
  `unplaced_precedent_in_repo` so a reader can follow the trail to the
  governing axis-layer policy;
- THERANOSTIC (CDER+CDRH boundary) and ADC (antibody = CBER) are the two
  parallel UNPLACED notes already on record; Zolgensma here joins that
  same honesty cohort.

### 3.1 Why the UNPLACED handling is a feature, not a gap

A portfolio that acknowledges what it does **not** cover is more honest
than one that pretends to. The honest UNPLACED handling does three
things that a forced placement would not:

1. **Preserves the CDER scope discipline.** Implementing a GENETIC-
   MEDICINE axis to hold Zolgensma would force the repo to model a
   modality whose mechanism (AAV9 capsid tropism, episomal SMN1 cDNA
   expression, neutralizing-antibody pre-screen) is not bounded by the
   thermodynamic real limits the rest of the axis tree uses — there is
   no SantaLucia-equivalent canonical-NN bound on AAV9 transduction.
   Any sim invented for that axis would be a model without an anchor.
2. **Keeps in-silico claims in-silico.** g8 limits PASS scope to
   simulator-consistency. A CBER axis carries an implicit immunogenicity
   / vector-tropism / dosing-window claim load that g8 forbids.
3. **Acknowledges the third drug exists.** The witness contains the
   Zolgensma row — sponsor, FDA year, modality, FDA center, drug-
   precedent citations — so a reader of the portfolio is NOT left with
   the impression that SMA has only two FDA-approved drugs.

### 3.2 Drug precedent for Zolgensma (own modality only — g3 / f1)

- Mendell JR *et al.* 2017, *N Engl J Med* 377:1713-1722 — AVXS-101
  phase-1 study in SMA type 1.
- FDA STN BL 125694 — onasemnogene abeparvovec-xioi (Zolgensma) approval,
  2019-05-24, CBER.

## §4 Cross-axis touch-point with A3

This case study touches the existing `AXIS/HIERARCHY.tape` §2.5 A3 cross:

```
A3 = "RNA-TARGETING-SMALL-MOLECULE vs OLIGONUCLEOTIDE — SMN2 modality
      comparison — _python_bridge/module/rna_modality_comparison_smn2_cross.py
      (__RNA_MODALITY_COMPARISON_SMN2_CROSS__ PASS 6/6) ...
      schema consts comparison_is_ranking=false /
      signals_commensurable=false — a comparison, NOT an efficacy
      ranking (both FDA-approved)."
```

The witness emits a `cross_axis_touch_point` block pointing at A3 by
`bridge_id`, source `module`, and the A3 schema_version. The relationship
is **strict extension**:

- A3 stays the canonical SMN2 cross-axis bridge (two-modality comparison,
  wired into selftest).
- This case study adds: (i) explicit portfolio framing (the writeup), (ii)
  the third FDA-approved drug (Zolgensma) as honestly UNPLACED, (iii) a
  case-study-scoped witness schema that *requires* the UNPLACED field.

A3's honesty fences (`comparison_is_ranking=false`,
`signals_commensurable=false`) carry forward: the two in-scope rows in
this portfolio are reported side-by-side, NOT ranked, and the signals
remain non-commensurable (Δ paired-fraction vs ΔG° kcal/mol on different
real limits).

## §5 Governance

The case study sits inside the standard hexa-bio governance stack:

- **g1 real-limits-first.** Each in-scope row carries its parent sim's
  real-limit anchor forward into the witness:
  - risdiplam → RNA secondary-structure thermodynamics (Nussinov 1978;
    Turner-Mathews NNDB 2010);
  - nusinersen → SantaLucia 1998 unified NN duplex thermodynamics.
- **g3 honesty-external / f1 lattice-fit-on-external-entity.** The three
  drugs are described **only** via their own published precedent
  (risdiplam/Evrysdi FDA 2020; nusinersen/Spinraza FDA 2016; onasemnogene
  abeparvovec/Zolgensma FDA 2019). Nothing here is lattice-derived
  (`f_lattice_fit`). No "n=6 → 3 drugs" or similar derivation.
- **g8 in-silico-only / f2 wet-lab-clinical-claim-from-in-silico.** Every
  PASS certifies in-silico simulator+metadata internal consistency only.
  This case study makes **no** therapeutic, clinical, splicing-correction,
  efficacy, immunogenic, regulatory, or **portfolio-recommendation** claim.
- **f3 shadow-implementation-of-sister-repo.** The runner IMPORTS the
  two axis sims (`rna_targeting_small_molecule_sim` +
  `oligonucleotide_hybridization_sim`); it does not re-implement either
  the Nussinov solver or the SantaLucia NN model.
- **g11 (analogue) vendored-snapshots-readonly.** No shared files are
  edited by this case study (`AXIS/*`, `selftest/run_all.sh`,
  `AGENTS.tape`, `HEXA-*.tape`, root `README.md` are untouched). The case
  study lives entirely under `case_studies/sma_portfolio/`.
- **scope discipline (criterion #4 drug-only/CDER).** Honored — Zolgensma
  is left UNPLACED per the same pattern that already governs
  GENETIC-MEDICINE / ADC / THERANOSTIC in `AXIS/HIERARCHY.tape`.

### 5.1 What this case study is NOT

- NOT a portfolio recommendation, ranking, or investment thesis.
- NOT a claim that any one of the three modalities is superior. All three
  drugs are FDA-approved.
- NOT a clinical, regulatory, immunogenicity, dosing, or efficacy claim.
- NOT a derivation of the modality count from the n=6 lattice.
- NOT the deferred 200-disease portfolio re-mapping; this is the one-
  disease SMA pilot only.

## §6 Files

- `README.md` — this writeup.
- `sma_portfolio_runner.py` — deterministic stdlib-only runner; imports
  the two in-axis sims; emits the portfolio witness JSON; prints the
  `__SMA_PORTFOLIO__ PASS` sentinel on success.
- `portfolio_v1.schema.json` — draft-07 JSON Schema for the witness;
  separates `in_scope_drugs` (2 entries, `fda_center=CDER`,
  `in_scope=true`) from `not_in_scope_drugs` (≥1 entry,
  `fda_center=CBER|CDRH`, `in_scope=false`, `axis=null`,
  `reported_not_run=true`).

Run the runner directly:

```bash
python3 case_studies/sma_portfolio/sma_portfolio_runner.py
```

Expected: exit 0, last line `__SMA_PORTFOLIO__ PASS`. The witness JSON
is emitted on stdout (`sort_keys=True`, `indent=2`) and is byte-identical
on every run.
