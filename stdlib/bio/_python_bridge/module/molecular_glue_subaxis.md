# MOLECULAR-GLUE — sub-axis note

`:> BIFUNCTIONAL` (expansion-main, see `AXIS/HIERARCHY.tape`
`@D sub_under_bifunctional`). This is a **sub-axis**, NOT a hexa-bio core-5
axis — the core remains QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per
`AXIS.tape` (unchanged).

## Modality

A **MOLECULAR GLUE** is a **monovalent** small molecule — it has *no bivalent
linker*, unlike a PROTAC. It binds one partner (typically the target
neosubstrate) with appreciable affinity, has only marginal intrinsic affinity
for the other partner (the E3 ligase), and works by remodelling the bound
surface so that a **new protein-protein interface** is created. The ternary
complex `Target·Glue·E3` is held together **cooperatively** — by the glue's
grip on one partner *plus* the glue-induced target↔E3 contact. It specializes
the parent BIFUNCTIONAL axis as its monovalent, neo-interface-nucleating
limiting case: it achieves induced proximity without two real warheads.

The defining signature, modelled here as the central acceptance gate: **neither
binary affinity alone is sufficient** — both the glue→target binary occupancy
and the bare target↔E3 binary occupancy are low, yet the cooperative ternary
occupancy is high because the cooperativity factor `α ≫ 1` amplifies the second
binding event.

## Own precedent (g3 / f1 — described by precedent, never lattice-derived)

- **MOLECULAR-GLUE:** lenalidomide and thalidomide — monovalent CRBN glues
  recruiting the neosubstrates IKZF1/IKZF3 to the CRL4-CRBN E3 ligase
  (Krönke et al., *Science* 343:301, 2014; Lu et al., *Science* 343:305,
  2014), both **FDA-approved**; indisulam — an aryl-sulfonamide glue recruiting
  the splicing factor RBM39 to the E3 substrate-receptor DCAF15
  (Han et al., *Science* 356:eaal3755, 2017; Uehara et al., *Nat. Chem. Biol.*
  13:675, 2017).

## Real limit anchored (g1)

**Cooperative ternary-complex equilibrium** — mass-action with a cooperativity
factor. The ternary-complex thermodynamics of induced-proximity modalities
follow the cooperativity formalism of Douglass et al., *J. Am. Chem. Soc.*
135:6092 (2013), refined for glues/PROTACs by Han, *Drug Discov. Today* 25:1832
(2020): the ternary equilibrium is governed by the binary dissociation
constants and a cooperativity factor `α`, and every occupancy is a mass-action
solution (Guldberg & Waage law of mass action, 1864). No modelled occupancy may
exceed `1.0` (acceptance criterion C2). The model further enforces **detailed
balance**: the two equivalent assembly paths (glue-first vs PPI-first) must
reach the same ternary occupancy — the thermodynamic-cycle consistency any
cooperative-equilibrium model must satisfy (acceptance criterion C3).

## In-silico scope (g8 / f2)

The `__MOLECULAR_GLUE__ PASS` sentinel certifies **in-silico simulator+metadata
internal consistency ONLY**: that the cooperative-ternary mass-action
occupancies, the thermodynamic-cycle (detailed-balance) consistency, and the
"neither binary sufficient" glue signature are computed self-consistently and
reproduce byte-identically. It is NOT an affinity measurement, NOT a degradation
(DC50/Dmax) claim, NOT a therapeutic-efficacy claim. `K_glue` / `K_PPI` / `α`
values are literature-informed surrogates for the modality, not fits to a
specific compound. (Note: although lenalidomide/thalidomide are FDA-approved
drugs, this module makes no clinical claim — it verifies only equilibrium-model
self-consistency.)

No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## Files

| file | role |
|---|---|
| `_python_bridge/module/molecular_glue_sim.py` | deterministic stdlib-only simulator + `__MOLECULAR_GLUE__ PASS` sentinel |
| `_python_bridge/spec/molecular_glue_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/molecular_glue_subaxis.md` | this note |

Run: `python3 _python_bridge/module/molecular_glue_sim.py`
