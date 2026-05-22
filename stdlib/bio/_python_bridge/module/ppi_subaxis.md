# PPI — sub-axis note

`:> QUANTUM (core)` — see `AXIS/HIERARCHY.tape` `@D sub_under_quantum`.
This is a **sub-axis**, NOT a hexa-bio core-5 axis. The core remains
QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per `AXIS.tape` (unchanged).
The sub hangs off the core QUANTUM axis as a tag and does **not** mutate it.

## Placement honesty (g3 — tension flagged, not hidden)

Per `AXIS/HIERARCHY.tape` `@D sub_under_quantum`, PPI **scores main-eligible**
(4.8/5/5) — by score it could be an expansion-MAIN axis. It is recorded as a
**borderline sub** of QUANTUM because of a QUANTUM-VQE-applicability tension
(README criterion #2): a large flat PPI interface is hotspot-energetics-driven,
not obviously an electronic-structure / active-space VQE problem. User direction
places ambiguous cases as sub. This note states the tension openly rather than
hiding it.

## Modality

A *PPI inhibitor* disrupts a **large, flat, hotspot-driven interface** with a
small molecule. The interface buries a wide surface, yet its binding free
energy is concentrated, not uniform — a few hotspot residues dominate. A small
molecule cannot bury the whole surface; it must **mimic the dominant hotspot
cluster**.

## Real limit anchored (g1)

The **Bogan-Thorn binding-hotspot theory** (Bogan & Thorn, "Anatomy of hot
spots in protein interfaces", *J. Mol. Biol.* 280:1, 1998): interface binding
free energy is concentrated in a small set of hotspot residues — operationally
those with alanine-scanning `ΔΔG ≥ 2 kcal/mol` — not spread uniformly over the
buried surface (alanine-scanning origin: Clackson & Wells, *Science* 267:383,
1995). The model sums the per-residue ΔΔG ledger:

```
ΔG_interface ≈ -Σ ΔΔG_i      hotspot_fraction = Σ_hotspot ΔΔG / Σ_all ΔΔG
```

The hard real limit: the total recoverable interface energy is **bounded by the
alanine-scanning ΔΔG ledger** — a small-molecule mimic cannot recover more
hotspot energy than the interface actually carries (acceptance criteria
C2/C4). Druggability of flat hotspot-driven PPIs follows Wells & McClendon,
*Nature* 450:1001 (2007).

## Own drug precedent (g3 / f1 — described by precedent, never lattice-derived)

- **venetoclax** — a BH3-mimetic small molecule disrupting the BCL-2 /
  pro-apoptotic BH3 protein-protein interaction (Souers et al., *Nat. Med.*
  19:202, 2013; **FDA-approved 2016** — the landmark approved PPI inhibitor).
- **navitoclax** (ABT-263) — dual BCL-2/BCL-xL BH3-mimetic PPI inhibitor
  (Tse et al., *Cancer Res.* 68:3421, 2008).

## In-silico scope (g8 / f2)

The `__PPI__ PASS` sentinel certifies **in-silico simulator+metadata internal
consistency ONLY**: that the alanine-scanning ΔΔG ledger, the hotspot fraction,
the interface `ΔG_bind` and the hotspot-mimicry gate are computed
self-consistently and reproduce byte-identically. It is NOT a binding-affinity,
potency, selectivity, or therapeutic-efficacy claim. The `ΔΔG` values are
literature-informed surrogates for interface *classes*, not fits to a specific
complex.

No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## Files

| file | role |
|---|---|
| `_python_bridge/module/ppi_sim.py` | deterministic stdlib-only simulator + `__PPI__ PASS` sentinel |
| `_python_bridge/spec/ppi_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/ppi_subaxis.md` | this note |

Run: `python3 _python_bridge/module/ppi_sim.py`
