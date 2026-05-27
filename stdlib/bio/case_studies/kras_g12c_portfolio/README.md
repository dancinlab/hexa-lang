# KRAS-G12C portfolio — in-silico case study (one-disease pilot)

**Status**: case-study artefact. ONE-DISEASE PILOT, NOT the deferred
200-disease re-mapping. Reading this document does NOT change the
hexa-bio core-5 axes or expansion-layer registrations.

## §0 Honest scope

This is a per-disease in-silico composition of two existing axis sims
against two FDA-approved KRAS-G12C inhibitors that map cleanly onto the
same expansion-main axis (COVALENT) AND onto a sub-axis (CRYPTIC-POCKET
:> QUANTUM). It is:

- a HONEST one-disease pilot, NOT the deferred 200-disease re-mapping
  (which `AXIS/HIERARCHY.tape` Log keeps explicitly out of scope);
- an in-silico simulator-consistency composition only — NOT a clinical,
  therapeutic, oncology, efficacy, regulatory, immunogenic, or
  portfolio-recommendation claim (governance g8 / f2);
- a real-drug demonstration that the cross-axis machinery covers BOTH
  the irreversible-covalent warhead modality (COVALENT axis) AND the
  switch-II cryptic-pocket conformational selection (CRYPTIC-POCKET
  sub-axis) for the SAME disease.

The KRAS-G12C switch-II pocket is the canonical cryptic site exploited
by the FDA-approved drugs — it is absent in early apo KRAS crystal
structures and is revealed only under protein dynamics (Ostrem *et al.*
2013; Canon *et al.* 2019).

## §1 FDA-approved drugs that map cleanly onto axes

| Drug | FDA year | FDA center | Modality | Axis mapping |
|---|---|---|---|---|
| **sotorasib** (Lumakras, Amgen) | 2021 | CDER | irreversible covalent acrylamide warhead, KRAS-G12C switch-II Cys12 | `COVALENT` (expansion-main); cryptic site touches `CRYPTIC-POCKET` `:> QUANTUM` |
| **adagrasib** (Krazati, Mirati / Bristol-Myers Squibb) | 2022 | CDER | irreversible covalent acrylamide warhead, KRAS-G12C switch-II Cys12 | `COVALENT` (expansion-main); cryptic site touches `CRYPTIC-POCKET` `:> QUANTUM` |

Both are FDA-approved small-molecule (CDER) drugs in current clinical
use against G12C-mutant non-small-cell lung cancer; both share the
acrylamide-warhead, Cys12-targeting modality and exploit the same
switch-II cryptic pocket. The case study runs the corresponding
in-silico sims and reports the model signatures.

### Drug-precedent references (own precedent only — g3 / f1)
- **sotorasib**: Canon *et al.*, *Nature* 575:217 (2019) — discovery and
  characterization of AMG 510; Hong *et al.*, *N. Engl. J. Med.*
  383:1207 (2020) — phase I/II CodeBreaK 100; FDA NDA 214665 — Lumakras
  accelerated approval 2021-05-28 (full approval 2025).
- **adagrasib**: Jänne *et al.*, *N. Engl. J. Med.* 387:120 (2022) —
  KRYSTAL-1 phase I/II; FDA NDA 216340 — Krazati accelerated approval
  2022-12-12.
- Switch-II cryptic pocket as drug target: Ostrem *et al.*, *Nature*
  503:548 (2013) — original chemical-biology demonstration of the
  cryptic switch-II pocket and the G12C-targeting covalent strategy.

## §2 In-silico runs (deterministic, stdlib-only)

The portfolio runner (`kras_g12c_portfolio_runner.py`) imports two axis
sims (f3 — no fork), runs each, and emits a single aggregated
portfolio witness:

- **sotorasib-style + adagrasib-style covalent step** →
  `_python_bridge/module/covalent_inhibition_sim.py` — the
  `sotorasib_KRAS_Cys12` and `adagrasib_KRAS_Cys12` entries of the
  COVALENT panel. Two-step kinetics: E + I ⇌(Ki) E·I → kinact → E–I;
  kinact/Ki is the field-standard efficiency metric (Strelow 2017).
  Eyring transition-state theory anchors the covalent-step rate
  ceiling. Both rows belong to the `acrylamide_thio_michael`
  warhead-class, the canonical irreversible-covalent class.
- **switch-II cryptic-pocket conformational selection** →
  `_python_bridge/module/cryptic_pocket_sim.py` — the
  `kras_g12c_switch_II` entry of the cryptic-pocket panel. Boltzmann
  open-state population in the apo protein; conformational-selection
  free-energy ledger ΔG_bind_obs = ΔG_bind_open + ΔG_open (Hammes,
  Chang & Oas 2009 thermodynamic cycle). The same pocket the FDA-
  approved drugs exploit.

Each in-scope row carries forward its parent sim's real-limit citation
(g1). Output rows validate against `portfolio_v1.schema.json`.

## §3 Honest UNPLACED / research-stage negatives for KRAS-G12C

This portfolio explicitly does NOT pretend the axes cover every
KRAS-targeting modality. The following are research-stage at the time
of writing and are honestly excluded:

- **pan-KRAS PROTAC degraders** — research-stage; no FDA-approved
  KRAS-targeting bifunctional degrader exists. (Several preclinical
  CRBN- and VHL-recruiting KRAS-G12C-selective PROTACs have been
  reported in the literature — e.g. LC-2 — but none are FDA-approved.)
  → The BIFUNCTIONAL expansion-main axis EXISTS in the repo, but NO
    FDA-approved KRAS-targeting bifunctional degrader maps onto it yet.
- **antisense oligonucleotides against KRAS** — research-stage; no
  FDA-approved anti-KRAS ASO exists.
  → The OLIGONUCLEOTIDE expansion-main axis EXISTS, but no clinical
    anti-KRAS oligonucleotide drug maps onto it yet.
- **Pan-KRAS active-state inhibitors / non-G12C KRAS mutant
  inhibitors** — research-stage (e.g. RMC-6236 pan-RAS, divarasib).
  Some are in late clinical trials but none are FDA-approved at the
  time of writing.

The honest negative is the point: a portfolio that lists what it does
NOT cover is more honest than one that pretends to be comprehensive.

## §4 Cross-axis touch-points already covered

The repo already crosses KRAS-G12C-relevant axes:

- **G2 — ALLOSTERIC × CRYPTIC-POCKET**
  (`_python_bridge/module/allosteric_cryptic_pocket_cross.py`): proves
  the MWC two-state and the cryptic-pocket open/closed populations
  coincide identically under R↔open mapping (rel-err < 1e-12). The
  switch-II pocket of KRAS-G12C is the named cryptic-side precedent of
  that cross (sotorasib/KRAS-G12C cited there) — the model-level
  unification this case study draws on.
- **A5 — REVERSIBLE-COVALENT × Mpro warhead VQE**
  (`_python_bridge/module/reversible_covalent_mpro_vqe_cross.py`):
  although that bridge models the Mpro target, its acrylamide
  contrast row (`acrylamide_sotorasib`) carries the SAME irreversible-
  covalent warhead modality as the two KRAS-G12C drugs here. The
  covalent-warhead pattern (acrylamide → Cys thio-Michael adduct,
  large |ΔG_rxn|, koff → 0, irreversible) is the same pattern the
  KRAS-G12C drugs follow; the cross's `acrylamide_sotorasib` row is
  the link.

This case study composes the existing sims; it does NOT introduce new
chemistry.

## §5 Governance

- **g1 real-limits-first**: each in-scope row's PASS is anchored to a
  cited real limit (Strelow 2017 kinact/Ki framework + Eyring TST for
  the covalent side; Hammes-Chang-Oas 2009 thermodynamic cycle +
  Boltzmann population statistics for the cryptic-pocket side); each
  anchor inherited from the parent sim's citation.
- **g3 / f1 / f_lattice_fit**: drugs described by own precedent only
  (sotorasib Lumakras; adagrasib Krazati; switch-II cryptic-pocket
  Ostrem 2013 / Canon 2019). Nothing here is derived from the n=6
  lattice.
- **g8 / f2 in-silico-only**: every PASS verifies in-silico
  simulator+metadata consistency ONLY — NEVER a clinical, therapeutic,
  oncology, regulatory, efficacy, or portfolio-recommendation claim.
  Wet-lab / clinical boundary out of scope
  (`CLOSURE_RESIDUAL_BACKLOG.md` §0).
- **f3 no-fork**: both parent sims are IMPORTED, never re-implemented.
- **criterion #4 drug-only / CDER**: both in-scope drugs are
  CDER-regulated small molecules. The research-stage modalities
  (pan-KRAS PROTACs, anti-KRAS ASOs, pan-RAS inhibitors) are listed in
  §3 with no fabricated coverage.
- **one-disease pilot**: this is KRAS-G12C-mutant cancer only — NOT
  the deferred 200-disease re-mapping.

## §6 Files

- `README.md` — this document.
- `kras_g12c_portfolio_runner.py` — deterministic stdlib-only runner;
  imports the two parent sims; emits the portfolio witness; sentinel
  `__KRAS_G12C_PORTFOLIO__ PASS`.
- `portfolio_v1.schema.json` — draft-07 schema. Separates
  `in_scope_drugs` from `research_stage_negatives` so the structural
  shape encodes the honest scope (the same pattern as
  `case_studies/sma_portfolio/portfolio_v1.schema.json`).

## §7 Log

- 2026-05-16 — KRAS-G12C portfolio case study created. Two FDA-approved
  drugs mapped onto COVALENT expansion-main + CRYPTIC-POCKET sub-axis
  (sotorasib FDA 2021; adagrasib FDA 2022; both acrylamide / Cys12 /
  switch-II cryptic site). Research-stage negatives documented
  honestly (pan-KRAS PROTACs, anti-KRAS ASOs, pan-RAS inhibitors).
  Cross-axis touch-points G2 and A5 cited. Core-5 axes UNCHANGED.
  Sentinel `__KRAS_G12C_PORTFOLIO__ PASS`.
