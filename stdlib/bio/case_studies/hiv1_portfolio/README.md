# HIV-1 portfolio — in-silico case study (one-disease pilot)

**Status**: case-study artefact. ONE-DISEASE PILOT, NOT the deferred
200-disease re-mapping. Reading this document does NOT change the
hexa-bio core-5 axes or expansion-layer registrations.

## §0 Honest scope

This is a per-disease in-silico composition of two existing axis sims
against two real FDA-approved HIV-1 drugs that map cleanly onto the
new axes. It is:

- a HONEST one-disease pilot, NOT the deferred 200-disease re-mapping
  (which AXIS/HIERARCHY.tape Log keeps explicitly out of scope until
  the core ever expands);
- an in-silico simulator-consistency composition only — NOT a clinical,
  therapeutic, efficacy, regulatory, immunogenic, or
  portfolio-recommendation claim (governance g8 / f2);
- a real-drug demonstration that the cross-axis machinery covers two
  distinct mechanisms (capsid assembly modulation + allosteric
  inhibition) against the SAME disease.

## §1 Two FDA-approved drugs that map cleanly onto axes

| Drug | FDA year | FDA center | Modality | Axis mapping |
|---|---|---|---|---|
| **lenacapavir** (Sunlenca, Gilead) | 2022 | CDER | capsid-assembly modulator (small molecule) | `CAPSID-ASSEMBLY-MODULATOR` `:> VIROCAPSID` (core) |
| **maraviroc** (Selzentry, ViiV/Pfizer) | 2007 | CDER | CCR5 allosteric inhibitor | `ALLOSTERIC` `:> QUANTUM` (core) |

Both are FDA-approved small-molecule (CDER) drugs in current clinical
use; both map onto sub-axes already implemented in this repo. The
case study runs the corresponding in-silico sims against them and
reports the model signatures side by side.

### Drug-precedent references (own precedent only — g3 / f1)
- **lenacapavir**: Link *et al.*, *Nature* 584:614 (2020); Bester
  *et al.*, *Science* 370:360 (2020); FDA NDA 215973 (2022-12-22).
- **maraviroc**: Dorr *et al.*, *Antimicrob Agents Chemother* 49:4721
  (2005); FDA NDA 022128 (2007-08-06).

## §2 In-silico runs (deterministic, stdlib-only)

The portfolio runner (`hiv1_portfolio_runner.py`) imports two axis
sims (f3 — no fork), runs each, and emits a single aggregated
portfolio witness:

- **lenacapavir-style** → `_python_bridge/module/capsid_assembly_modulator_sim.py`
  — the strong-over-stabilizer scenario (lenacapavir over-stabilizes
  the capsid hexamer interface, disrupting both assembly and uncoating).
  Caspar-Klug 1962 + Zlotnick 1994/2003 real-limit anchors.
- **maraviroc-style** → `_python_bridge/module/allosteric_sim.py` — an
  MWC two-state allosteric profile with an R-state stabilizer.
  Monod-Wyman-Changeux 1965 real-limit anchor.

Each in-scope row carries forward its parent sim's real-limit citation
(g1). Output rows validate against `portfolio_v1.schema.json`.

## §3 Honest negatives (research-stage modalities for HIV-1)

This portfolio explicitly does NOT pretend the new axes cover every
HIV-1 modality. The following are research-stage at the time of writing
and are honestly excluded:

- **Anti-HIV antisense oligonucleotides** — research-stage; no
  FDA-approved anti-HIV ASO exists. (fomivirsen was the first
  FDA-approved ASO but it targets CMV; it was withdrawn 2002).
  → The OLIGONUCLEOTIDE expansion-main axis EXISTS in the repo, but
    NO FDA-approved HIV drug maps onto it yet.
- **HIV-targeting PROTACs** — research-stage; no FDA-approved
  HIV-targeting bifunctional degrader exists.
  → The BIFUNCTIONAL expansion-main axis EXISTS, but no clinical
    HIV drug maps onto it yet.
- **Gene-editing curative approaches (e.g. EBT-101, CRISPR-Cas9)** —
  clinical-trial-stage; CBER-regulated; out of repo CDER scope per
  criterion #4. → honest UNPLACED, same precedent as Zolgensma in the
  SMA case study (see `case_studies/sma_portfolio/`).

The honest negative is the point: a portfolio that lists what it does
NOT cover is more honest than one that pretends to be comprehensive.

## §4 Cross-axis touch-points already covered

The repo already crosses HIV-1-relevant axes:

- **A4 — CAPSID-ASSEMBLY-MODULATOR × VIROCAPSID PDB corpus**
  (`_python_bridge/module/capsid_modulator_pdb_anchor_cross.py`):
  scans 527 capsids; the 12 Retroviridae entries (including HIV-1)
  are HONESTLY classified `T-number N/A — non-icosahedral fullerene
  cone`. The native HIV-1 capsid is a variable-curvature cone, not a
  closed icosahedral shell — the cross refuses to force a fabricated
  T-number. That honesty result is the foundation this case study
  rests on.
- **G2 — ALLOSTERIC × CRYPTIC-POCKET**
  (`_python_bridge/module/allosteric_cryptic_pocket_cross.py`): proves
  the MWC two-state model and the cryptic-pocket open/closed
  population coincide identically under R↔open mapping. maraviroc's
  CCR5 binding pocket has been argued in the literature to be a
  cryptic-style site; the cross's MWC≡cryptic identity is the
  general framework this case study draws on.

This case study composes the existing sims; it does NOT introduce
new chemistry.

## §5 Governance

- **g1 real-limits-first**: each in-scope row's PASS is anchored to a
  cited real limit (Caspar-Klug + Zlotnick for the CAM side; MWC
  two-state for the allosteric side); each anchor inherited from the
  parent sim's citation.
- **g3 / f1 / f_lattice_fit**: drugs described by own precedent only
  (lenacapavir Sunlenca; maraviroc Selzentry). Nothing here is
  derived from the n=6 lattice.
- **g8 / f2 in-silico-only**: every PASS verifies in-silico
  simulator+metadata consistency ONLY — NEVER a clinical,
  therapeutic, regulatory, efficacy, or portfolio-recommendation
  claim. Wet-lab / clinical boundary out of scope
  (`CLOSURE_RESIDUAL_BACKLOG.md` §0).
- **f3 no-fork**: both parent sims are IMPORTED, never re-implemented.
- **criterion #4 drug-only / CDER**: both in-scope drugs are
  CDER-regulated small molecules. The honest UNPLACED CBER modalities
  (gene-editing curatives) are listed in §3 with no fabricated coverage.

## §6 Files

- `README.md` — this document.
- `hiv1_portfolio_runner.py` — deterministic stdlib-only runner;
  imports the two parent sims; emits the portfolio witness; sentinel
  `__HIV1_PORTFOLIO__ PASS`.
- `portfolio_v1.schema.json` — draft-07 schema. Separates
  `in_scope_drugs` from `research_stage_negatives` so the structural
  shape encodes the honest scope (the same pattern as
  `case_studies/sma_portfolio/portfolio_v1.schema.json`).

## §7 Log

- 2026-05-16 — HIV-1 portfolio case study created. Two FDA-approved
  drugs mapped onto sub-axes (lenacapavir → CAPSID-ASSEMBLY-MODULATOR;
  maraviroc → ALLOSTERIC). Research-stage / CBER negatives documented
  honestly (anti-HIV ASOs, HIV-PROTACs, gene-editing curatives).
  Cross-axis touch-points A4 and G2 cited. Core-5 axes UNCHANGED.
  Sentinel `__HIV1_PORTFOLIO__ PASS`.
