# Migraine portfolio — in-silico case study (one-disease pilot)

**Status**: case-study artefact. ONE-DISEASE PILOT, NOT the deferred
200-disease re-mapping. Reading this document does NOT change the
hexa-bio core-5 axes or expansion-layer registrations.

## §0 Honest scope

This is a per-disease in-silico composition of one existing sub-axis
sim (PPI :> QUANTUM) against the four FDA-approved CDER
small-molecule CGRP-receptor antagonists (the **gepant** class) used
for migraine. All four disrupt the CGRP / CGRP-receptor
protein-protein interaction. It is:

- a HONEST one-disease pilot, NOT the deferred 200-disease re-mapping
  (which `AXIS/HIERARCHY.tape` Log keeps explicitly out of scope);
- an in-silico simulator-consistency composition only — NOT a clinical,
  therapeutic, neurologic, efficacy, regulatory, immunogenic, or
  portfolio-recommendation claim (governance g8 / f2);
- a real-drug demonstration that the cross-axis machinery covers the
  peptide-receptor PPI modality that defines the gepant class
  (Bogan & Thorn 1998; Wells & McClendon 2007).

The CGRP / CGRP-receptor pathway has produced **eight** FDA-approved
migraine drugs since 2018 (four small molecules + four monoclonal
antibodies). This case study covers all eight; four map cleanly onto
the PPI sub-axis (in-scope) and four are honestly UNPLACED CBER
biologics (criterion #4 drug-only/CDER scope boundary — same handling
as Zolgensma in `case_studies/sma_portfolio/`).

## §1 Four FDA-approved CDER small-molecule gepants (in-scope)

| Drug | Brand | Sponsor | FDA year | FDA center | Modality | Axis mapping |
|---|---|---|---|---|---|---|
| **rimegepant** | Nurtec ODT | Pfizer / Biohaven | 2020 | CDER | oral acute & preventive CGRP-receptor antagonist (small molecule) | `PPI` `:> QUANTUM` (sub-axis) |
| **ubrogepant** | Ubrelvy | AbbVie / Allergan | 2019 | CDER | oral acute CGRP-receptor antagonist (small molecule) | `PPI` `:> QUANTUM` (sub-axis) |
| **atogepant** | Qulipta | AbbVie | 2021 | CDER | oral preventive CGRP-receptor antagonist (small molecule) | `PPI` `:> QUANTUM` (sub-axis) |
| **zavegepant** | Zavzpret | Pfizer | 2023 | CDER | intranasal acute CGRP-receptor antagonist (small molecule) | `PPI` `:> QUANTUM` (sub-axis) |

All four are FDA-approved CDER small molecules that disrupt the same
CGRP / CGRP-receptor protein-protein interaction by occupying the
orthosteric peptide-binding site on the CLR + RAMP1 receptor complex.
This is one PPI-disruption modality class with four approved drugs —
NOT four distinct mechanisms.

### Drug-precedent references (own precedent only — g3 / f1)
- **rimegepant**: Croop R *et al.*, *Lancet* 394:737 (2019) acute
  phase III; Croop R *et al.*, *Lancet* 397:51 (2021) preventive;
  FDA NDA 212728 (Nurtec ODT, 2020-02-27).
- **ubrogepant**: Dodick DW *et al.*, *N. Engl. J. Med.* 381:2230
  (2019) ACHIEVE I; Lipton RB *et al.*, *JAMA* 322:1887 (2019)
  ACHIEVE II; FDA NDA 211765 (Ubrelvy, 2019-12-23).
- **atogepant**: Ailani J *et al.*, *N. Engl. J. Med.* 385:695
  (2021) ADVANCE; Goadsby PJ *et al.*, *Lancet Neurol.* 19:727
  (2020) dose-finding; FDA NDA 215206 (Qulipta, 2021-09-28).
- **zavegepant**: Lipton RB *et al.*, *Lancet Neurol.* 22:209
  (2023) intranasal phase III; Croop R *et al.*, *Headache* 62:1153
  (2022) phase II/III; FDA NDA 216386 (Zavzpret, 2023-03-09).

## §2 In-silico runs (deterministic, stdlib-only)

The portfolio runner (`migraine_portfolio_runner.py`) imports the PPI
sub-axis sim via `importlib` (f3 — no fork), pulls a single
class-surrogate row from its deterministic panel, and emits one
aggregated portfolio witness covering all eight drugs:

- **gepant-style** → `_python_bridge/module/ppi_sim.py` `mdm2_p53_cleft`
  row (interface class `alpha_helix_peptide_cleft`). The parent
  ppi_sim's panel does NOT include a CGRP-specific row; per the
  parent sim's OWN honesty note ("ΔΔG values are literature-informed
  surrogates for interface CLASSES, NOT fits to specific complexes")
  we use the alpha-helix-peptide-cleft row as the panel-class
  surrogate. CGRP is a 37-residue peptide that binds the CLR+RAMP1
  receptor groove via an alpha-helical N-terminal anchor — the
  peptide-binds-cleft interface CLASS is the closest panel surrogate.
  All four gepants share the same `sim_run` block by design: this is
  ONE PPI-disruption class with four approved drugs.

Each in-scope row carries forward the parent sim's real-limit
citation (g1): Bogan & Thorn 1998 binding-hotspot theory + Wells &
McClendon 2007 flat-PPI druggability. Output rows validate against
`portfolio_v1.schema.json`.

## §3 Honest UNPLACED — four FDA-approved CBER monoclonal antibodies

The CGRP pathway is unique in modern migraine pharmacology because
FOUR FDA-approved anti-CGRP or anti-CGRP-receptor monoclonal
antibodies exist in parallel with the four small-molecule gepants.
These mAbs are FDA-approved BUT they are CBER-regulated biologics
and therefore fall OUTSIDE the hexa-bio criterion #4 drug-only/CDER
scope boundary. They are honestly UNPLACED with `axis=null`,
`in_scope=false`, `reported_not_run=true` — same pattern as Zolgensma
in `case_studies/sma_portfolio/`.

| Drug | Brand | Sponsor | FDA year | FDA center | Modality |
|---|---|---|---|---|---|
| **erenumab** | Aimovig | Amgen / Novartis | 2018 | CBER | anti-CGRP-RECEPTOR fully human IgG2 mAb (SC) |
| **fremanezumab** | Ajovy | Teva | 2018 | CBER | anti-CGRP humanized IgG2 mAb (SC) |
| **galcanezumab** | Emgality | Eli Lilly | 2018 | CBER | anti-CGRP humanized IgG4 mAb (SC) |
| **eptinezumab** | Vyepti | Lundbeck | 2020 | CBER | anti-CGRP humanized IgG1 mAb (IV) |

### Honest UNPLACED — drug precedents (CBER, NOT modeled)
- **erenumab**: Goadsby PJ *et al.*, *N. Engl. J. Med.* 377:2123
  (2017) STRIVE; FDA BLA 761077 (Aimovig, 2018-05-17, CBER).
- **fremanezumab**: Silberstein SD *et al.*, *N. Engl. J. Med.*
  377:2113 (2017) HALO-CM/HALO-EM; FDA BLA 761089 (Ajovy,
  2018-09-14, CBER).
- **galcanezumab**: Stauffer VL *et al.*, *JAMA Neurol.* 75:1080
  (2018) EVOLVE-1; Skljarevski V *et al.*, *Cephalalgia* 38:1442
  (2018) EVOLVE-2; FDA BLA 761063 (Emgality, 2018-09-27, CBER).
- **eptinezumab**: Ashina M *et al.*, *Cephalalgia* 40:241 (2020)
  PROMISE-1; Lipton RB *et al.*, *Neurology* 94:e1365 (2020)
  PROMISE-2; FDA BLA 761119 (Vyepti, 2020-02-21, CBER).

The honest UNPLACED is the point: a portfolio that lists what it
does NOT cover (four FDA-approved drugs that would breach criterion
#4 if claimed) is more honest than one that pretends to be
comprehensive.

## §4 Cross-axis touch-points

- **G3 — PPI × MOLECULAR-GLUE**
  (`_python_bridge/module/ppi_molecular_glue_cross.py`): cited for
  COMPLETENESS only. Gepants are PPI **disruptors**, NOT molecular
  glues. No migraine-specific molecular glue exists; this portfolio
  does NOT claim a molecular-glue modality for any gepant. The
  cross-axis touch-point is recorded so the parity table mirrors
  the BCL-2 portfolio's G3 reference, NOT to assert a glue modality.

This case study composes the existing sim; it does NOT introduce new
chemistry.

## §5 Governance

- **g1 real-limits-first**: each in-scope row's PASS is anchored to a
  cited real limit (Bogan & Thorn 1998 binding-hotspot theory — the
  alanine-scanning ΔΔG ledger bounds the total recoverable interface
  energy; Wells & McClendon 2007 flat-PPI druggability framing);
  anchors inherited from the parent `ppi_sim.py` citation.
- **g3 / f1 / f_lattice_fit**: drugs described by own precedent only
  (rimegepant Croop 2019; ubrogepant Dodick 2019; atogepant Ailani
  2021; zavegepant Lipton 2023; plus the FDA approval letters).
  Nothing here is derived from the n=6 lattice.
- **g8 / f2 in-silico-only**: every PASS verifies in-silico
  simulator+metadata consistency ONLY — NEVER a clinical, therapeutic,
  neurologic, regulatory, efficacy, or portfolio-recommendation
  claim. Wet-lab / clinical boundary out of scope
  (`CLOSURE_RESIDUAL_BACKLOG.md` §0).
- **f3 no-fork**: the parent `ppi_sim.py` is IMPORTED via
  `importlib`, never re-implemented.
- **criterion #4 drug-only / CDER**: all four in-scope gepants are
  CDER-regulated small molecules. The four FDA-approved CBER mAbs
  (erenumab, fremanezumab, galcanezumab, eptinezumab) are listed
  honestly as UNPLACED with `axis=null` and `reported_not_run=true`
  — same pattern as Zolgensma in `case_studies/sma_portfolio/`.
- **one-disease pilot**: this is migraine only — NOT the deferred
  200-disease re-mapping.

## §6 Files

- `README.md` — this document.
- `migraine_portfolio_runner.py` — deterministic stdlib-only runner;
  imports the parent PPI sim via `importlib`; emits the portfolio
  witness; sentinel `__MIGRAINE_PORTFOLIO__ PASS`.
- `portfolio_v1.schema.json` — draft-07 schema. Separates
  `in_scope_drugs` (four CDER gepants) from `not_in_scope_drugs`
  (four CBER mAbs with `axis=null`) so the structural shape encodes
  the honest scope (same pattern as `case_studies/sma_portfolio/`).

## §7 Log

- 2026-05-16 — Migraine portfolio case study created. Four CDER
  small-molecule gepants (rimegepant / Nurtec ODT FDA 2020;
  ubrogepant / Ubrelvy FDA 2019; atogepant / Qulipta FDA 2021;
  zavegepant / Zavzpret FDA 2023) mapped onto the PPI sub-axis
  (:> QUANTUM core). Four FDA-approved CBER anti-CGRP / anti-CGRP-
  receptor monoclonal antibodies (erenumab / Aimovig 2018,
  fremanezumab / Ajovy 2018, galcanezumab / Emgality 2018,
  eptinezumab / Vyepti 2020) documented honestly as UNPLACED
  (criterion #4 drug-only/CDER scope boundary; same handling as
  Zolgensma). Cross-axis touch-point G3 cited for completeness —
  the portfolio does NOT claim a molecular-glue modality for any
  gepant. Core-5 axes UNCHANGED. Sentinel
  `__MIGRAINE_PORTFOLIO__ PASS`.
