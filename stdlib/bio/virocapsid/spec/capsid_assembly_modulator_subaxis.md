# CAPSID-ASSEMBLY-MODULATOR — sub-axis note (`:> VIROCAPSID`, core)

**Status:** specialization SUB-AXIS hanging off the core **VIROCAPSID** axis.
This is **not** a 6th core axis — the hexa-bio core stays 5 (QUANTUM · WEAVE ·
NANOBOT · RIBOZYME · VIROCAPSID per `AXIS.tape`). Recorded under the
expansion-layer pattern of `AXIS/HIERARCHY.tape`. The core-5 SSOT is UNCHANGED.

## What CAPSID-ASSEMBLY-MODULATOR is — and how it differs from its parent

The parent **VIROCAPSID** axis models viral capsid *self-assembly*: Caspar-Klug
quasi-equivalence geometry and the Zlotnick nucleation-elongation pathway by
which free capsomers assemble into a complete shell (cf.
`virocapsid/module/zlotnick_ode.py`).

A **capsid-assembly modulator (CAM)** is a small molecule that *perturbs* that
assembly. The sub-axis **specializes** the parent's machinery: it reuses the
parent's Caspar-Klug T-number geometry and Zlotnick assembly thermodynamics,
and redirects them from modeling *productive assembly* toward modeling
*inhibition* — a CAM shifts the per-contact inter-subunit free energy
`g_contact`, and the sub-axis computes how that shift moves the assembly
equilibrium. Per Zlotnick, **over-stabilization** (contacts made too strong)
kinetically *traps* assembly in incomplete / aberrant intermediates — the
system can no longer anneal out defects. That is the mechanistic core of the
CAM modality.

## Modality and its own drug precedent

The CAM is a real, independent therapeutic modality with its own clinical
track record — described here **only** by that precedent, never derived from
the n=6 lattice (governance g3 / f1 / f_lattice_fit):

- **lenacapavir (Sunlenca)** — a first-in-class HIV-1 **capsid inhibitor**,
  a SMALL-MOLECULE (CDER) drug, FDA-approved 2022 for multidrug-resistant
  HIV-1. It binds the capsid hexamer interface and over-stabilizes the
  lattice, disrupting both capsid assembly and uncoating.
- **HBV capsid-assembly modulators** — vebicorvir, JNJ-56136379 (bersacapavir),
  GLS4 (morphothiadine): clinical-stage small molecules that misdirect HBV
  core-protein assembly toward empty or aberrant capsids.

## Real limits anchored (governance g1 — real-limits-first)

The sub-axis simulator (`_python_bridge/module/capsid_assembly_modulator_sim.py`)
anchors to published real limits:

- **Caspar-Klug quasi-equivalence T-number geometry** — Caspar & Klug (1962),
  *Cold Spring Harb Symp Quant Biol* 27:1-24. An icosahedral capsid of
  triangulation number T has exactly `60·T` protein subunits = 12 pentamers +
  `10·(T-1)` hexamers; the capsomer polyhedron satisfies Euler `V - E + F = 2`.
  This is an **exact** integer / closed-form geometry — no fitting.
- **Zlotnick assembly thermodynamics** — Zlotnick (1994), *Biochemistry*
  33:1233-1237; Zlotnick (2003), *J Mol Recognit* 16:294-298. Capsids are held
  by many individually-**weak** inter-subunit contacts (≈ −2 to −4 kcal/mol
  each); over-stabilization beyond that band kinetically **traps** assembly.

No subunit count, free energy, or concentration is derived from the n=6
lattice (g2 / f_lattice_fit). "12 pentamers" is Caspar-Klug capsid geometry —
an observation from structural virology, never a lattice derivation.

## In-silico scope (governance g8 / f2)

Every PASS in this sub-axis verifies **in-silico simulator-consistency only**:
that the Caspar-Klug geometry is exact and the Zlotnick mean-field equilibrium
is internally self-consistent (dG↔K round-trip, monotone cooperative
assembled-fraction, mass-action critical concentration). It is **not** a
wet-lab, structural, binding-affinity, therapeutic, clinical, or regulatory
claim about any CAM. Parameters are literature-informed illustrative
magnitudes, not fits to a specific dataset. Crossing the wet-lab boundary is
out of repo scope (`AGENTS.tape` g8_in_silico_only · f2 ·
`CLOSURE_RESIDUAL_BACKLOG.md` §0).
