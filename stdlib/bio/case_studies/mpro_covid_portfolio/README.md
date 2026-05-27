# Mpro / COVID-19 portfolio — in-silico case study (one-disease pilot)

**Status**: case-study artefact. ONE-DISEASE PILOT, NOT the deferred
200-disease re-mapping. Reading this document does NOT change the
hexa-bio core-5 axes or expansion-layer registrations.

## §0 Honest scope

This is a per-disease in-silico composition of one existing sub-axis
sim (REVERSIBLE-COVALENT :> COVALENT) against one FDA-approved Mpro
inhibitor that maps cleanly onto the expansion-layer. It is:

- a HONEST one-disease pilot, NOT the deferred 200-disease re-mapping
  (which `AXIS/HIERARCHY.tape` Log keeps explicitly out of scope);
- an in-silico simulator-consistency composition only — NOT a clinical,
  therapeutic, antiviral, efficacy, regulatory, immunogenic, or
  portfolio-recommendation claim (governance g8 / f2);
- a real-drug demonstration that the cross-axis machinery
  (REVERSIBLE-COVALENT × Mpro warhead VQE — Project A5) covers the one
  FDA-approved oral Mpro inhibitor in current US clinical use.

## §1 FDA-approved drug that maps cleanly onto an axis

| Drug | FDA year | FDA center | Modality | Axis mapping |
|---|---|---|---|---|
| **nirmatrelvir** (Paxlovid, Pfizer) | 2022 (EUA) / 2023 (full approval) | CDER | reversible covalent nitrile warhead, SARS-CoV-2 Mpro Cys145 | `REVERSIBLE-COVALENT` `:> COVALENT` (expansion-main) |

nirmatrelvir is the nitrile-warhead component of Paxlovid (nirmatrelvir
+ ritonavir); it is a reversible covalent inhibitor of the SARS-CoV-2
main protease (Mpro / 3CLpro / nsp5). The nitrile carbon forms a
thioimidate adduct with the Cys145 thiolate of the Mpro catalytic dyad
(Cys145 / His41) — a reversible covalent linkage with a measurable
koff and a finite residence time, distinct from the irreversible
acrylamide-warhead modality of e.g. ibrutinib / sotorasib.

### Drug-precedent references (own precedent only — g3 / f1)
- **nirmatrelvir**: Owen *et al.*, *Science* 374:1586 (2021) — discovery
  and characterization of PF-07321332; FDA EUA 091 (2022-12-22, granted
  2021-12-22 amended for adults 2022); FDA NDA 217188 — Paxlovid full
  approval 2023-05-25.
- The nitrile→thioimidate covalent linkage at Cys145 is documented in
  Boras *et al.*, *Nat. Commun.* 12:6055 (2021).

## §2 In-silico run (deterministic, stdlib-only)

The portfolio runner (`mpro_covid_portfolio_runner.py`) imports the
REVERSIBLE-COVALENT sub-axis sim (f3 — no fork) and pulls the
nitrile-warhead row from its deterministic panel:

- **nirmatrelvir-style** → `_python_bridge/module/reversible_covalent_sim.py`
  — the nitrile_nirmatrelvir entry of the warhead panel. Eyring
  transition-state-theory covalent equilibrium: ΔG‡_on / ΔG_rxn → kon,
  koff, K_eq = kon/koff, τ_res = 1/koff, reversibility class. The
  nitrile→thioimidate adduct is near-thermoneutral (small |ΔG_rxn|),
  giving a climbable reverse barrier, a measurable koff, and a
  finite residence time — the reversible-covalent signature.

The in-scope row carries forward the parent sim's real-limit
citation (g1): Eyring transition-state theory (Eyring, *J. Chem. Phys.*
3:107, 1935) — the universal frequency prefactor kB·T/h ≈ 6.46e12 /s
at T = 310 K is the hard ceiling on any modelled unimolecular rate.

Output validates against `portfolio_v1.schema.json`.

## §3 Honest negatives (research-stage / non-US-FDA modalities for Mpro)

This portfolio explicitly does NOT pretend the axes cover every Mpro
modality. The following are out-of-scope at the time of writing and
are honestly excluded:

- **ensitrelvir** (Xocova, Shionogi) — a non-covalent Mpro inhibitor
  approved by Japan PMDA only (emergency approval 2022-11; conditional
  full approval 2024). It is NOT US-FDA-approved at the time of
  writing. The Mpro-inhibitor axis exists (REVERSIBLE-COVALENT
  describes the covalent class; a non-covalent Mpro inhibitor is the
  GENERAL covalent-axis NEGATIVE-control), but criterion #4 keeps
  US-FDA discipline in this case study; ensitrelvir is RECORDED, not
  modeled.
- **Non-covalent Mpro inhibitors (research-stage chemotypes)** — the
  Pfizer PF-00835231 piperidinone and various non-covalent
  high-throughput-screen leads from the early COVID-19 response remain
  research-stage; no FDA-approved non-covalent Mpro inhibitor exists.
- **Anti-SARS-CoV-2 monoclonal antibodies (e.g. tixagevimab/cilgavimab,
  bebtelovimab)** — CBER-regulated biologics; out of repo CDER scope
  per criterion #4, and all currently authorised mAbs were withdrawn /
  de-authorised against contemporary variants. Honest UNPLACED, same
  precedent as Zolgensma in the SMA case study.

The honest negative is the point: a portfolio that lists what it does
NOT cover is more honest than one that pretends to be comprehensive.

## §4 Cross-axis touch-points already covered

The repo already crosses Mpro-relevant axes:

- **A5 — REVERSIBLE-COVALENT × Mpro warhead VQE**
  (`_python_bridge/module/reversible_covalent_mpro_vqe_cross.py`):
  takes per-warhead ΔE_rxn (covalent-bond formation energy) from the
  QUANTUM-axis Mpro warhead VQE library, feeds it into the
  REVERSIBLE-COVALENT Eyring kinetics model, and shows the qualitative
  reactivity ordering: nitrile / aldehyde / ketone-class adducts are
  near-thermoneutral (reversible); the acrylamide thio-Michael adduct
  is strongly exothermic (irreversible). The 5 panel rows are
  illustrative-only (qualitative input, barrier-proxy is a modelling
  choice). This case study takes the nitrile_nirmatrelvir row and
  recasts it as the nirmatrelvir/Paxlovid drug-precedent line.

This case study composes the existing sim; it does NOT introduce new
chemistry.

## §5 Governance

- **g1 real-limits-first**: the in-scope row's PASS is anchored to a
  cited real limit (Eyring transition-state theory; the universal
  prefactor kB·T/h ≈ 6.46e12 /s at 310 K is the hard unimolecular
  ceiling), inherited from the parent sim's citation.
- **g3 / f1 / f_lattice_fit**: nirmatrelvir is described by own
  precedent only (Owen *et al.* 2021; FDA NDA 217188). Nothing here is
  derived from the n=6 lattice.
- **g8 / f2 in-silico-only**: every PASS verifies in-silico
  simulator+metadata consistency ONLY — NEVER a clinical, therapeutic,
  antiviral, regulatory, efficacy, or portfolio-recommendation claim.
  Wet-lab / clinical boundary out of scope
  (`CLOSURE_RESIDUAL_BACKLOG.md` §0).
- **f3 no-fork**: the parent sim is IMPORTED, never re-implemented.
- **criterion #4 drug-only / CDER**: the in-scope drug is a
  CDER-regulated small molecule. ensitrelvir (PMDA-only) and the
  withdrawn anti-SARS-CoV-2 mAbs (CBER) are listed in §3 with no
  fabricated coverage.
- **one-disease pilot**: this is COVID-19 only — NOT the deferred
  200-disease re-mapping.

## §6 Files

- `README.md` — this document.
- `mpro_covid_portfolio_runner.py` — deterministic stdlib-only runner;
  imports the parent sim; emits the portfolio witness; sentinel
  `__MPRO_COVID_PORTFOLIO__ PASS`.
- `portfolio_v1.schema.json` — draft-07 schema. Separates
  `in_scope_drugs` from `research_stage_negatives` so the structural
  shape encodes the honest scope (the same pattern as
  `case_studies/sma_portfolio/portfolio_v1.schema.json`).

## §7 Log

- 2026-05-16 — Mpro / COVID-19 portfolio case study created. One
  FDA-approved drug mapped onto a sub-axis (nirmatrelvir →
  REVERSIBLE-COVALENT :> COVALENT). Non-US-FDA (ensitrelvir / PMDA),
  research-stage (non-covalent Mpro chemotypes), and CBER (anti-
  SARS-CoV-2 mAbs) negatives documented honestly. Cross-axis touch-
  point A5 cited. Core-5 axes UNCHANGED. Sentinel
  `__MPRO_COVID_PORTFOLIO__ PASS`.
