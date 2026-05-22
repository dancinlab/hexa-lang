# RIBOTAC — sub-axis note

`:> BIFUNCTIONAL` (expansion-main, see `AXIS/HIERARCHY.tape`
`@D sub_under_bifunctional`). This is a **sub-axis**, NOT a hexa-bio core-5
axis — the core remains QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per
`AXIS.tape` (unchanged).

## Modality

A **RIBOTAC** (RIBOnuclease-TArgeting Chimera) is a bifunctional small molecule
with two warheads joined by a linker: one binds a *structured RNA* target, the
other recruits the endogenous latent ribonuclease **RNase-L**. The molecule
nucleates a ternary complex `Target·R·RNase-L`; the recruited nuclease then
catalytically cleaves the bound RNA. Because the RIBOTAC is released after
cleavage, it acts as an **event-driven catalyst** — it neutralizes *many* RNA
copies per molecule, in contrast to a stoichiometric RNA binder (one target per
molecule). It specializes the parent BIFUNCTIONAL axis: like PROTAC/LYTAC, it
is a heterobifunctional recruiter, but its "effector" is a nuclease and its
substrate is RNA.

## Cross-axis soft dependence (`?> RIBOZYME` core)

RIBOTAC and the hexa-bio core **RIBOZYME** axis both effect **multiple-turnover
catalytic cleavage of RNA** — a ribozyme is an intrinsically catalytic RNA, a
RIBOTAC recruits a protein nuclease to a structured RNA. The shared physics is
catalytic phosphodiester cleavage with turnover. This module therefore reuses
the parent RIBOZYME axis's RNA secondary-structure machinery — it **imports**
`ribozyme_mfe_nussinov.nussinov` to score the target RNA's structuredness and
**does not fork it** (forbidden-pattern f3).

## Own precedent (g3 / f1 — described by precedent, never lattice-derived)

- **RIBOTAC:** the Disney-lab RIBOnuclease-TArgeting Chimeras that recruit
  RNase-L to disease RNAs — Costales et al., *J. Am. Chem. Soc.* 140:6741
  (2018), the first RNase-L-recruiting heterobifunctional; Costales et al.,
  *PNAS* 117:2406 (2020), a RIBOTAC against pre-miR-21.
- RIBOTAC is a **research-stage** modality: no RIBOTAC is an approved drug.

## Real limits anchored (g1)

1. **Mass-action law** (Guldberg & Waage, 1864). Every equilibrium occupancy —
   binary `Target·R` and ternary `Target·R·RNase` fractions — is the closed-form
   mass-action solution of the coupled dissociation equilibria. No modelled
   bound fraction may exceed `1.0` (acceptance criterion C2).
2. **Catalytic multiple-turnover limit**. A stoichiometric (single-turnover)
   ligand has turnover number `= 1` by definition; a genuine catalyst has
   turnover number `> 1` (Cornish-Bowden, *Fundamentals of Enzyme Kinetics*,
   4th ed., 2012). The modelled RIBOTAC turnover `N = k_cat·t_exposure` must
   exceed `1` for the catalytic-advantage claim to hold (acceptance C4).

## In-silico scope (g8 / f2)

The `__RIBOTAC__ PASS` sentinel certifies **in-silico simulator+metadata
internal consistency ONLY**: that the mass-action ternary fractions, the
turnover number `N = k_cat·t_exposure`, and the catalytic advantage are
computed self-consistently and reproduce byte-identically. It is NOT an
affinity measurement, NOT a cellular-knockdown claim, NOT a therapeutic-efficacy
claim. RIBOTAC is research-stage — nothing here is a clinical claim. `K_d` /
`k_cat` / `α` values are literature-informed surrogates for the modality, not
fits to a specific compound.

No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## Files

| file | role |
|---|---|
| `_python_bridge/module/ribotac_sim.py` | deterministic stdlib-only simulator + `__RIBOTAC__ PASS` sentinel |
| `_python_bridge/spec/ribotac_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/ribotac_subaxis.md` | this note |

Run: `python3 _python_bridge/module/ribotac_sim.py`
