# BCL-2 portfolio — in-silico case study (one-disease pilot)

**Status**: case-study artefact. ONE-DISEASE PILOT, NOT the deferred
200-disease re-mapping. Reading this document does NOT change the
hexa-bio core-5 axes or expansion-layer registrations.

## §0 Honest scope

This is a per-disease in-silico composition of one existing sub-axis
sim (PPI :> QUANTUM) against the two clinical BH3-mimetic
protein-protein-interaction inhibitors targeting the BCL-2 family in
hematologic malignancies. One is FDA-approved (in-scope) and one is
late-stage clinical only (in-scope as the canonical second BH3-mimetic
the parent PPI sim already names). It is:

- a HONEST one-disease pilot, NOT the deferred 200-disease re-mapping
  (which `AXIS/HIERARCHY.tape` Log keeps explicitly out of scope);
- an in-silico simulator-consistency composition only — NOT a clinical,
  therapeutic, oncology, efficacy, regulatory, immunogenic, or
  portfolio-recommendation claim (governance g8 / f2);
- a real-drug demonstration that the cross-axis machinery covers the
  flat-hotspot-driven PPI interface that defines the BH3-mimetic
  modality (Bogan & Thorn 1998).

The BCL-2 / BH3 interface is the landmark approved-PPI-inhibitor case
in modern pharmacology (Souers *et al.* 2013; Wells & McClendon 2007).

## §1 BH3-mimetic drugs that map cleanly onto the PPI axis

| Drug | Status | Sponsor | FDA year | FDA center | Modality | Axis mapping |
|---|---|---|---|---|---|---|
| **venetoclax** (Venclexta) | FDA-approved | AbbVie / Genentech | 2016 | CDER | BH3-mimetic small-molecule PPI inhibitor — disrupts BCL-2 / pro-apoptotic-BH3 interaction | `PPI` `:> QUANTUM` (sub-axis) |
| **navitoclax** (ABT-263) | Clinical-stage (not FDA-approved) | AbbVie | — | (CDER if filed) | BH3-mimetic small-molecule, dual BCL-2 / BCL-xL PPI inhibitor | `PPI` `:> QUANTUM` (sub-axis) |

venetoclax is the landmark FDA-approved small-molecule PPI inhibitor
and is approved for chronic lymphocytic leukemia (CLL), small
lymphocytic lymphoma (SLL) and acute myeloid leukemia (AML, in
combination with hypomethylating agents). navitoclax is its dual
BCL-2/BCL-xL predecessor — clinical-stage only, not FDA-approved
(thrombocytopenia from BCL-xL inhibition has limited its single-agent
window); it is included as in-scope because it is the canonical second
BH3-mimetic the parent PPI sim's panel already names by drug precedent
(`bclxl_bh3_groove` row, "navitoclax (ABT-263) — dual BCL-2/BCL-xL
BH3-mimetic PPI inhibitor").

### Drug-precedent references (own precedent only — g3 / f1)
- **venetoclax**: Souers *et al.*, *Nat. Med.* 19:202 (2013) —
  discovery and characterization of ABT-199 / GDC-0199; Stilgenbauer
  *et al.*, *Lancet Oncol.* 17:768 (2016) — phase II in del(17p) CLL;
  FDA NDA 208573 — Venclexta first approval 2016-04-11 (CLL with
  17p deletion).
- **navitoclax**: Tse *et al.*, *Cancer Res.* 68:3421 (2008) —
  preclinical characterization of ABT-263; clinical-stage; not
  FDA-approved at the time of writing.
- BH3-mimetic / BCL-2-family PPI modality: Wells & McClendon, *Nature*
  450:1001 (2007) — druggability of flat hotspot-driven PPIs.

## §2 In-silico runs (deterministic, stdlib-only)

The portfolio runner (`bcl2_portfolio_runner.py`) imports the PPI
sub-axis sim (f3 — no fork), pulls the two BCL-2-family BH3-groove
rows from its deterministic panel, and emits a single aggregated
portfolio witness:

- **venetoclax-style** → `_python_bridge/module/ppi_sim.py`
  `bcl2_bh3_groove` row. Alanine-scanning ΔΔG ledger over the BH3-
  helix-groove interface; Bogan-Thorn hotspot residues (ΔΔG ≥ 2
  kcal/mol); hotspot energy fraction; hotspot-mimicry gate (the small
  molecule must recover enough hotspot energy to out-compete one
  partner). The parent sim's panel cites venetoclax directly as the
  FDA-approved-PPI-inhibitor precedent for this row.
- **navitoclax-style** → `_python_bridge/module/ppi_sim.py`
  `bclxl_bh3_groove` row. Same model on the BCL-xL BH3-helix-groove
  interface (the dual BCL-2 / BCL-xL modality navitoclax represents).
  The parent sim's panel cites navitoclax / ABT-263 as the
  drug-precedent for this row.

Each in-scope row carries forward its parent sim's real-limit citation
(g1). Output rows validate against `portfolio_v1.schema.json`.

## §3 Honest UNPLACED / research-stage negatives for BCL-2 / hematologic
## malignancies

This portfolio explicitly does NOT pretend the axes cover every
BCL-2-targeting modality. The following are research-stage at the time
of writing and are honestly excluded:

- **BCL-2-targeting PROTAC degraders** — research-stage; no
  FDA-approved BCL-2-targeting bifunctional degrader exists.
  Preclinical BCL-2 PROTACs (CRBN- and VHL-recruiting) and BCL-xL
  PROTACs (DT2216 and analogues — designed to limit BCL-xL-driven
  thrombocytopenia) are reported, but none are FDA-approved.
  → The BIFUNCTIONAL expansion-main axis EXISTS in the repo, but NO
    FDA-approved BCL-2-targeting bifunctional degrader maps onto it
    yet.
- **macrocyclic BH3-mimetics / stapled BH3-peptide BCL-2 inhibitors**
  — research-stage; no FDA-approved macrocyclic or stapled-peptide
  BCL-2 inhibitor exists. Several BH3-stapled-peptide and
  cyclopeptide leads are in preclinical / early clinical development.
- **anti-apoptotic-CAR-T / cell-therapy approaches to BCL-2-driven
  malignancies** — CBER-regulated biologics; out of repo CDER scope
  per criterion #4. Honest UNPLACED, same precedent as Zolgensma in
  the SMA case study.

The honest negative is the point: a portfolio that lists what it does
NOT cover is more honest than one that pretends to be comprehensive.

## §4 Cross-axis touch-points already covered

The repo already crosses BCL-2-relevant axes:

- **G3 — PPI × MOLECULAR-GLUE**
  (`_python_bridge/module/ppi_molecular_glue_cross.py`): proves the
  PPI-disruption and glue-creation modalities share the energetic
  ledger — Bogan-Thorn hotspot ΔG sets a K_PPI_effective scale, which
  in turn fixes the α-ladder threshold for a molecular-glue signature
  to be visible. Hotspot-rich BH3 grooves (the venetoclax / BCL-2 case)
  clear at α ≈ 10; hotspot-poor KIX shallow grooves fail at α > 5000.
  The α-floor is monotonic with hotspot energy — that monotonicity is
  the discriminating signature of the cross.
  IMPORTANT — venetoclax is NOT a molecular glue; it is a *disruptor*
  of the BCL-2 / BH3 interaction. The G3 cross is cited here for
  COMPLETENESS (it shares the BCL-2 BH3-groove interface as its
  hotspot-rich reference case) — the portfolio does NOT claim a
  molecular-glue modality for the BH3-mimetics. The MOLECULAR-GLUE
  axis is a research-stage modality at the BCL-2 family target and is
  not in scope.

This case study composes the existing sim; it does NOT introduce new
chemistry.

## §5 Governance

- **g1 real-limits-first**: each in-scope row's PASS is anchored to a
  cited real limit (Bogan & Thorn 1998 binding-hotspot theory — the
  alanine-scanning ΔΔG ledger bounds the total recoverable interface
  energy; Wells & McClendon 2007 flat-PPI druggability framing);
  anchors inherited from the parent sim's citations.
- **g3 / f1 / f_lattice_fit**: drugs described by own precedent only
  (venetoclax Venclexta Souers 2013 / FDA NDA 208573; navitoclax
  ABT-263 Tse 2008). Nothing here is derived from the n=6 lattice.
- **g8 / f2 in-silico-only**: every PASS verifies in-silico
  simulator+metadata consistency ONLY — NEVER a clinical, therapeutic,
  oncology, regulatory, efficacy, or portfolio-recommendation claim.
  Wet-lab / clinical boundary out of scope
  (`CLOSURE_RESIDUAL_BACKLOG.md` §0).
- **f3 no-fork**: the parent sim is IMPORTED, never re-implemented.
- **criterion #4 drug-only / CDER**: venetoclax is a CDER-regulated
  small molecule; navitoclax is a clinical-stage small molecule (would
  be CDER if approved). The CBER cell-therapy negatives (CAR-T) are
  listed in §3 with no fabricated coverage.
- **one-disease pilot**: this is BCL-2-family-driven hematologic
  malignancy only — NOT the deferred 200-disease re-mapping.

## §6 Files

- `README.md` — this document.
- `bcl2_portfolio_runner.py` — deterministic stdlib-only runner;
  imports the parent sim; emits the portfolio witness; sentinel
  `__BCL2_PORTFOLIO__ PASS`.
- `portfolio_v1.schema.json` — draft-07 schema. Separates
  `in_scope_drugs` from `research_stage_negatives` so the structural
  shape encodes the honest scope (the same pattern as
  `case_studies/sma_portfolio/portfolio_v1.schema.json`).

## §7 Log

- 2026-05-16 — BCL-2 portfolio case study created. Two BH3-mimetic
  drugs mapped onto the PPI sub-axis (venetoclax / Venclexta FDA 2016;
  navitoclax / ABT-263 clinical-stage). Research-stage negatives
  documented honestly (BCL-2-targeting PROTACs, macrocyclic / stapled
  BH3-peptide mimetics, anti-apoptotic CAR-T cell therapies).
  Cross-axis touch-point G3 cited for completeness — the portfolio
  does NOT claim a molecular-glue modality for the BH3-mimetics.
  Core-5 axes UNCHANGED. Sentinel `__BCL2_PORTFOLIO__ PASS`.
