# MACROCYCLE — sub-axis note (`:> WEAVE`, core)

**Status:** specialization SUB-AXIS hanging off the core **WEAVE** axis.
This is **not** a 6th core axis — the hexa-bio core stays 5 (QUANTUM · WEAVE ·
NANOBOT · RIBOZYME · VIROCAPSID per `AXIS/AXIS.tape`). Recorded under the
expansion-layer pattern of `AXIS/HIERARCHY.tape` `@D sub_under_weave`. The
core-5 SSOT is UNCHANGED.

## What MACROCYCLE is — and how it differs from its parent

The parent **WEAVE** axis models *structural quasi-equivalence*: the
Caspar-Klug / Zlotnick assembly of many repeating capsomer units into a closed
icosahedral shell — a many-body lattice-assembly thermodynamics.

A **macrocyclic drug** is a single molecule whose pharmacophore is closed into
a ring. This sub-axis models the **macrocyclization entropic effect**: closing
a flexible acyclic chain into a ring covalently constrains its rotatable bonds,
so the molecule samples far fewer conformers in solution — it is
*pre-organized* toward the bound conformer. On binding, it therefore pays a
much smaller conformational-entropy penalty `−T·ΔS_conf` than its acyclic
analog would. The sub-axis also carries the "beyond rule of 5" (bRo5) property
space that macrocyclic drugs systematically occupy.

## Honest WEAVE-overlap note (HIERARCHY.tape criterion #2)

MACROCYCLE is registered as a **sub-axis** of WEAVE (`AXIS/HIERARCHY.tape`
`@D sub_under_weave`: "strong precedent, WEAVE-adjacent"). The overlap is
stated plainly:

- **Shared** — both WEAVE and MACROCYCLE reason about the *geometry of a
  closed cyclic structure* and the thermodynamics of forming it.
- **Distinct** — WEAVE is *structural quasi-equivalence* (a closed many-body
  icosahedral capsomer lattice). MACROCYCLE specializes away from it toward
  **single-molecule ring-closure conformational thermodynamics**: how one
  ring constrains one molecule's rotatable bonds and pre-organizes it for
  binding.

That overlap is enough to make MACROCYCLE a *specialization* of WEAVE, not
enough independence to be a 6th core axis. Hence: sub-axis. Core-5
(`AXIS/AXIS.tape`) is UNCHANGED.

## Modality and its own drug precedent

The macrocyclic drug is a real, independent modality with a long clinical
track record — described here **only** by that precedent, never derived from
the n=6 lattice (governance g3/f1/f_lattice_fit):

- **cyclosporine** — a cyclic undecapeptide immunosuppressant (MW ≈ 1203,
  squarely beyond the rule of 5); the canonical macrocyclic drug. The
  **macrolide class** (erythromycin, azithromycin, rapamycin / sirolimus,
  tacrolimus) is the broader natural-product macrocycle precedent.
- **lorlatinib** — a synthetic **macrocyclic** ALK/ROS1 tyrosine-kinase
  inhibitor (FDA-approved 2018); the ring was designed to pre-organize the
  pharmacophore and improve CNS penetration. The canonical *synthetic*
  macrocyclic-drug precedent.

## Real limit anchored (governance g1 — real-limits-first)

The sub-axis simulator (`_python_bridge/module/macrocycle_sim.py`) anchors to
published real limits:

- **Macrocyclization pre-organization entropy.** Conformational restriction by
  ring closure reduces the entropic cost of binding by limiting the number of
  accessible conformers — Mallinson & Collins (2012), *Future Med. Chem.*
  4:1409–1438; Villar et al. (2014), *Nat. Chem. Biol.* 10:723–731; Driggers,
  Hale, Lee & Terrett (2008), *Nat. Rev. Drug Discov.* 7:608–624.
- **Boltzmann's relation** `S = R·ln W` — conformational entropy as the
  logarithm of the accessible conformational microstate count `W_conf`. This
  is the statistical-mechanics foundation that bounds every entropy here:
  `S_conf ≥ 0`, and `S_conf = 0` iff `W_conf = 1` (a fully rigid,
  single-conformer ligand pays no conformational binding penalty).
- **The "beyond rule of 5" property space** for macrocycles — Doak, Over,
  Giordanetto & Kihlberg (2014), *Chem. Biol.* 21:1115–1142; the parent
  rule of 5 — Lipinski et al. (1997), *Adv. Drug Deliv. Rev.* 23:3–25.
- **Hard ceiling.** A ring constraint can only *remove* conformers, never add
  them: `W_conf(macrocycle) ≤ W_conf(acyclic analog)`, so the
  pre-organization free-energy difference `ΔΔG_preorg ≤ 0` always. The
  simulator gates on this (acceptance C3/C4).

No count, entropy, or parameter is derived from the n=6 lattice
(g2 / `f_lattice_fit`) — `W_conf` is a product of per-bond rotamer
multiplicities, `S_conf` is Boltzmann's `R·ln W`.

## In-silico scope (governance g8 / f2)

Every PASS in this sub-axis verifies **in-silico simulator-consistency only**:
that the conformational microstate counts, the Boltzmann entropies
`S_conf = R·ln W`, the pre-organization free-energy gain `ΔΔG_preorg`, and the
bRo5 classification are computed self-consistently and reproduce textbook
identities byte-identically. It is **not** a wet-lab, binding-affinity,
potency, permeability, therapeutic, clinical, or regulatory claim about any
compound. The rotamer multiplicities, ring-constraint factor, and molecular
properties are literature-informed illustrative surrogates for ligand
*classes*, not fits to a specific compound. Crossing the wet-lab boundary is
out of repo scope (`AGENTS.tape` g8 · f2 · `CLOSURE_RESIDUAL_BACKLOG.md` §0).

## Files

| file | role |
|---|---|
| `_python_bridge/module/macrocycle_sim.py` | deterministic stdlib-only simulator + `__MACROCYCLE__ PASS` sentinel |
| `_python_bridge/spec/macrocycle_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/macrocycle_subaxis.md` | this note |

Run: `python3 _python_bridge/module/macrocycle_sim.py`
