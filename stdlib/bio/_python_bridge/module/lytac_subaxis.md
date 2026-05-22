# LYTAC — sub-axis note

`:> BIFUNCTIONAL` (expansion-main, see `AXIS/HIERARCHY.tape`
`@D sub_under_bifunctional`). This is a **sub-axis**, NOT a hexa-bio core-5
axis — the core remains QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per
`AXIS.tape` (unchanged).

## Modality

A **LYTAC** (LYsosome-TArgeting Chimera) is a bifunctional conjugate: one end
binds an **extracellular or membrane-bound** target protein, the other end is a
glycan ligand for a lysosome-shuttling cell-surface receptor — the
cation-independent mannose-6-phosphate receptor (**CI-M6PR**, ubiquitous) or
the asialoglycoprotein receptor (**ASGPR**, hepatocyte-restricted). The receptor
internalises the LYTAC·target complex by endocytosis and delivers the target to
the lysosome for degradation, while the receptor recycles.

It **specializes** the parent BIFUNCTIONAL axis toward the **lysosomal**
degradation pathway. Where the sibling PROTAC sub-axis routes *intracellular*
targets to the *proteasome* via an E3-ligase ternary complex, LYTAC routes
*extracellular / membrane* targets to the *lysosome* via a receptor-mediated
endocytosis pathway — the productive event is governed by surface ternary
capture and the endosomal sort-vs-recycle trafficking partition.

## Own precedent (g3 / f1 / f_lattice_fit — described by precedent, never lattice-derived)

- **Banik, Pedram, Wisnovsky, Ahn, Riley & Bertozzi**, "Lysosome-targeting
  chimaeras for degradation of extracellular proteins", *Nature* 584:291 (2020)
  — the founding LYTAC work (Bertozzi lab, Stanford).
- **Ahn, Banik, Miller, Riley, Bertozzi & Wisnovsky**, ASGPR/GalNAc
  hepatocyte-directed LYTACs, *Nat. Chem. Biol.* 17:937 (2021).

**LYTAC is a research-stage modality** — there is no FDA-approved LYTAC drug.
The 2020 *Nature* work and its follow-ups are pre-clinical / discovery-stage.
This is stated honestly per g8/f2; the modality is described **only** by this
research precedent, never derived from the n=6 lattice.

## Real limit anchored (g1 — real-limits-first)

**Receptor-mediated endocytosis trafficking kinetics**, layered on the **law of
mass action**. Surface ternary capture (target bound by LYTAC, then the
shuttling receptor binding the target·LYTAC species) is a closed-form
mass-action equilibrium — `θ = [L]/(K_d + [L])`, `θ = 1/2` exactly at
`[L] = K_d`. The endosomal **sort-vs-recycle partition**
`lysosomal_partition = k_sort/(k_sort + k_recycle)` and the internalisation rate
follow the established first-order compartmental description of receptor
trafficking:

- Wiley, H.S. & Cunningham, D.D., "A steady state model for analyzing the
  cellular binding, internalization and degradation of polypeptide ligands",
  *Cell* 25:433 (1981).
- Lauffenburger, D.A. & Linderman, J.J., *Receptors: Models for Binding,
  Trafficking, and Signaling*, Oxford Univ. Press (1993) — the
  sort / recycle / degrade partition.
- Ghosh, P., Dahms, N.M. & Kornfeld, S., "Mannose 6-phosphate receptors: new
  twists in the tale", *Nat. Rev. Mol. Cell Biol.* 4:202 (2003) — CI-M6PR
  lysosomal targeting.

The trafficking partition is bounded in `[0,1]` and the two partition fractions
must sum to 1 exactly; the mass-action half-occupancy identity must hold exactly
at `[L] = K_d` (acceptance criteria C2 / C3 / C4). No quantity here is derived
from the n=6 lattice (g2 / `f_lattice_fit`).

## In-silico scope (g8 / f2)

The `__LYTAC__ PASS` sentinel certifies **in-silico simulator+metadata internal
consistency ONLY**: that the mass-action surface capture, the trafficking
sort/recycle partition and the degradation-flux product are computed
self-consistently and reproduce byte-identically. It is NOT a binding-affinity
measurement, NOT a degradation-potency claim, NOT a therapeutic-efficacy claim.
LYTAC is research-stage — nothing here is a clinical or regulatory claim.
`K_d` / rate-constant values are literature-informed illustrative surrogates,
not fits to a specific compound. Crossing the wet-lab boundary is out of repo
scope (`AGENTS.tape` g8/f2 · `CLOSURE_RESIDUAL_BACKLOG.md` §0).

## Files

| file | role |
|---|---|
| `_python_bridge/module/lytac_sim.py` | deterministic stdlib-only simulator + `__LYTAC__ PASS` sentinel |
| `_python_bridge/spec/lytac_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/lytac_subaxis.md` | this note |

Run: `python3 _python_bridge/module/lytac_sim.py`
