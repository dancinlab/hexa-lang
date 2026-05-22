# PEPTIDE — sub-axis note (`:> WEAVE`, core)

**Status:** specialization SUB-AXIS hanging off the core **WEAVE** axis.
This is **not** a 6th core axis — the hexa-bio core stays 5 (QUANTUM · WEAVE ·
NANOBOT · RIBOZYME · VIROCAPSID per `AXIS/AXIS.tape`). Recorded under the
expansion-layer pattern of `AXIS/HIERARCHY.tape` `@D sub_under_weave`. The
core-5 SSOT is UNCHANGED.

## What PEPTIDE is — and how it differs from its parent

The parent **WEAVE** axis models *structural quasi-equivalence*: the
Caspar-Klug / Zlotnick assembly of many repeating capsomer units into a closed
icosahedral shell — a many-body lattice-assembly thermodynamics.

A **therapeutic peptide** is a single LINEAR residue chain whose biological
behaviour is governed by its *conformational ensemble*, not by a closed
quasi-equivalent lattice. This sub-axis models the **helix-coil equilibrium**
of that chain — the fractional helicity `θ_H`, the cooperative one-dimensional
helix-coil transition, and a helicity/permeability property tradeoff. `θ_H` is
a thermodynamic equilibrium fraction, not an assembled stoichiometry.

## Honest WEAVE-overlap note (HIERARCHY.tape criterion #2 — demotion boundary)

PEPTIDE is registered as a **sub-axis**, not a core axis, *precisely because*
it sits on the ~30% WEAVE-overlap demotion boundary (`AXIS/HIERARCHY.tape`
`@D sub_under_weave`; `AXIS/README.md` promotion criterion #2). The overlap is
real and is stated plainly:

- **Shared ~30%** — the "secondary structure of a biopolymer" concern. Both
  WEAVE and PEPTIDE reason about how local structural elements assemble.
- **Distinct ~70%** — WEAVE is *structural quasi-equivalence* (a closed
  many-capsomer icosahedral lattice). PEPTIDE specializes away from it toward
  **linear-chain conformational thermodynamics**: a one-dimensional helix-coil
  partition function for a single peptide, plus the peptide-drug property
  tradeoff (helicity ↔ membrane permeability).

That ~30% overlap is the demotion criterion — enough shared machinery to make
PEPTIDE a *specialization* of WEAVE, not enough independence to be a 6th core
axis. Hence: sub-axis. Core-5 (`AXIS/AXIS.tape`) is UNCHANGED.

## Modality and its own drug precedent

The therapeutic peptide is a real, independent modality with a blockbuster
clinical track record — described here **only** by that precedent, never
derived from the n=6 lattice (governance g3/f1/f_lattice_fit):

- **semaglutide** — a GLP-1 receptor-agonist analog peptide (Ozempic / Wegovy /
  Rybelsus); the GLP-1 backbone is α-helical in its receptor-bound state. A
  blockbuster peptide therapeutic.
- the broader **GLP-1 analog class** (liraglutide, dulaglutide, tirzepatide)
  and engineered **stapled / helical peptides** are the modality track record
  this sub-axis is described by.

## Real limit anchored (governance g1 — real-limits-first)

The sub-axis simulator (`_python_bridge/module/peptide_sim.py`) anchors to
published statistical-mechanics real limits:

- **Zimm-Bragg helix-coil theory** — Zimm & Bragg (1959), *J. Chem. Phys.*
  31:526–535; the equivalent **Lifson-Roig** formulation — Lifson & Roig
  (1961), *J. Chem. Phys.* 34:1963–1974. The cooperative helix-coil transition
  of a one-dimensional chain with a nucleation penalty `σ ≪ 1` has a partition
  function `Z` that is exactly the sum over the `2^N` helix/coil microstates,
  and `θ_H = (1/N)·∂lnZ/∂ln s`.
- **Per-residue helix propensities** — the experimental host-guest scales of
  Pace & Scholtz (1998), *Biophys. J.* 75:422–427, and Chakrabartty, Kortemme
  & Baldwin (1994), *Protein Sci.* 3:843–852 (alanine the strongest
  helix-former; glycine and proline helix-breakers).
- **Hard ceilings.** `0 ≤ θ_H ≤ 1` always — it is a fraction. In the `σ → 1`
  (no nucleation cost) limit the residues become independent two-state systems
  and `θ_H` reduces to the analytically known baseline `(1/N) Σ s_i/(1+s_i)`;
  the simulator cross-checks against this closed form (acceptance C3), and a
  nucleation penalty can only *suppress* helix relative to it.

No count, helicity, or parameter is derived from the n=6 lattice
(g2 / `f_lattice_fit`) — `θ_H` comes from the helix-coil partition sum, the
propensities from experimental host-guest scales.

## In-silico scope (governance g8 / f2)

Every PASS in this sub-axis verifies **in-silico simulator-consistency only**:
that the helix-coil partition sum, `θ_H`, the `σ → 1` independent-residue
cross-check, and the permeability-proxy tradeoff are computed self-consistently
and reproduce textbook identities byte-identically. It is **not** a wet-lab,
structural, binding-affinity, permeability, therapeutic, clinical, or
regulatory claim about any peptide. Parameters are literature-informed
illustrative magnitudes, not fits to a specific dataset. Crossing the wet-lab
boundary is out of repo scope (`AGENTS.tape` g8 · f2 ·
`CLOSURE_RESIDUAL_BACKLOG.md` §0).

## Files

| file | role |
|---|---|
| `_python_bridge/module/peptide_sim.py` | deterministic stdlib-only simulator + `__PEPTIDE__ PASS` sentinel |
| `_python_bridge/spec/peptide_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/peptide_subaxis.md` | this note |

Run: `python3 _python_bridge/module/peptide_sim.py`
