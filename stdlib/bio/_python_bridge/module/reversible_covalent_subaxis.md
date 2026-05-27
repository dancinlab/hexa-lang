# REVERSIBLE-COVALENT — sub-axis note

`:> COVALENT` (expansion-main, see `AXIS/HIERARCHY.tape` `@D axis_covalent`).
This is a **sub-axis**, NOT a hexa-bio core-5 axis — the core remains
QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per `AXIS.tape` (unchanged).

## Modality

A *reversible covalent* inhibitor forms a covalent bond to its target that is a
genuine chemical **equilibrium**: the adduct measurably re-opens on the
biological timescale. It specializes the parent COVALENT axis along the
reversible-vs-irreversible distinction. Where an irreversible covalent inhibitor
is governed by its on-rate alone (`koff → 0`), a reversible covalent inhibitor
has a finite `koff`, an equilibrium constant `K_eq = kon/koff`, and a
target-residence time `τ_res = 1/koff`.

## Own drug precedent (g3 / f1 — described by precedent, never lattice-derived)

- **Reversible covalent:** nirmatrelvir (PF-07321332), the nitrile-warhead
  SARS-CoV-2 Mpro inhibitor of Paxlovid — the nitrile→thioimidate adduct with
  the Cys145 thiolate is a reversible covalent linkage (Owen et al.,
  *Science* 374:1586, 2021). Other reversible-covalent precedent: peptidyl
  aldehydes (GC373/GC376), α-ketoamides (Hilgenfeld 13b), trifluoromethyl
  ketones.
- **Irreversible covalent (contrast):** ibrutinib — acrylamide Michael
  acceptor, covalent BTK Cys481 (Honigberg et al., *PNAS* 107:13075, 2010);
  sotorasib — acrylamide, covalent KRAS-G12C Cys12 (Canon et al.,
  *Nature* 575:217, 2019). The acrylamide thio-Michael adduct does not
  measurably hydrolyse on the biological timescale (`koff → 0`).

Reversible-vs-irreversible warhead `koff` regimes follow the covalent-inhibitor
kinetics reviews: Singh et al., *Nat. Rev. Drug Discov.* 10:307 (2011);
Bauer, *Drug Discov. Today* 20:1061 (2015); Boike, Bhattacharya & Cravatt,
*Nat. Rev. Drug Discov.* 21:881 (2022).

This sub-axis does NOT modify `tests/mpro_warhead_library_vqe_v7.py` (the
QUANTUM-axis warhead ΔE_rxn ranking); it adds the orthogonal kinetics layer —
*equilibrium / residence time*, not gas-phase bond-formation energy.

## Real limit anchored (g1)

**Eyring transition-state theory** (Eyring, *J. Chem. Phys.* 3:107, 1935). Both
the forward (covalent-bond formation) and reverse (covalent-bond breaking)
elementary rates are computed as `k = (kB·T/h)·exp(−ΔG‡/R·T)`. The universal
frequency prefactor `kB·T/h ≈ 6.46e12 /s` at T = 310 K is the hard physical
ceiling: no modelled `kon`/`koff` may exceed it (acceptance criterion C2). This
is the same TST real-limit used by the RIBOZYME-axis
`ribozyme_kinetics_simulation.py`.

## In-silico scope (g8 / f2)

The `__REVERSIBLE_COVALENT__ PASS` sentinel certifies **in-silico
simulator+metadata internal consistency ONLY**: that the Eyring rates,
`K_eq = kon/koff`, `τ_res = 1/koff`, and the reversible/irreversible
classification are computed self-consistently and reproduce byte-identically.
It is NOT a binding-affinity, potency, selectivity, or therapeutic-efficacy
claim. The `ΔG‡` values are literature-informed surrogates for warhead
*classes*, not fits to a specific compound.

No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## Files

| file | role |
|---|---|
| `_python_bridge/module/reversible_covalent_sim.py` | deterministic stdlib-only simulator + `__REVERSIBLE_COVALENT__ PASS` sentinel |
| `_python_bridge/spec/reversible_covalent_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/reversible_covalent_subaxis.md` | this note |

Run: `python3 _python_bridge/module/reversible_covalent_sim.py`
