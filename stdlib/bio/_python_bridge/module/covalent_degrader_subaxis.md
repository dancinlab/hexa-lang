# COVALENT-DEGRADER — sub-axis note

`:> BIFUNCTIONAL` (expansion-main, see `AXIS/HIERARCHY.tape`
`@D sub_under_bifunctional`). This is a **sub-axis**, NOT a hexa-bio core-5
axis — the core remains QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per
`AXIS.tape` (unchanged).

## Modality

A **COVALENT DEGRADER** is a bifunctional degrader — one warhead binds the
target, one recruits an E3 ubiquitin ligase — in which **one of the two
warheads is a covalent warhead**. The covalent engagement forms an irreversible
bond, so that engagement loses its off-rate (`koff → 0`): the covalently-engaged
fraction accumulates over the exposure window toward 1.0 instead of plateauing
at the mass-action equilibrium occupancy that a reversible engagement would
reach. The productive ternary complex `Target·Degrader·E3` is the product of
the covalent-engagement occupancy and the reversible second-site occupancy. It
specializes the parent BIFUNCTIONAL axis along the irreversible-engagement
distinction: it shares the degrader architecture of PROTAC, but one end is
covalent.

## Cross note (→ COVALENT expansion-main)

The covalent-warhead engagement step modelled here is the same irreversible
covalent chemistry treated by the **COVALENT expansion-main axis**
(`reversible_covalent_sim.py`). COVALENT-DEGRADER sits under **BIFUNCTIONAL**
because its architecture is a bifunctional degrader, but its warhead chemistry
is the COVALENT axis's domain — a deliberate cross-axis relationship, not a
fork.

## Own precedent (g3 / f1 — described by precedent, never lattice-derived)

- **COVALENT-DEGRADER:** covalent CRBN- and DCAF16-recruiting bifunctional
  degraders — covalent recruiters of the E3 substrate-receptor DCAF16
  (Zhang et al., *Nat. Chem. Biol.* 15:737, 2019); covalent-handle degraders
  against covalently-engaged targets, e.g. covalent BTK degraders
  (Tinworth et al., *ACS Chem. Biol.* 14:342, 2019).
- COVALENT-DEGRADER is a **research / early-clinical** modality: it is not an
  established approved class.

## Real limits anchored (g1)

1. **Mass-action law** (Guldberg & Waage, 1864). Every reversible engagement
   occupancy and the ternary fraction are closed-form mass-action solutions of
   the dissociation equilibria. No modelled fraction may exceed `1.0`
   (acceptance criterion C2).
2. **Irreversible-inactivation kinetics** — the `kinact/K_i` framework for
   covalent inhibitors (Copeland, *Evaluation of Enzyme Inhibitors in Drug
   Discovery*, 2nd ed., 2013, ch. 8; Strelow, *SLAS Discov.* 22:3, 2017). The
   covalently-engaged fraction is `f_cov(t) = 1 − exp(−k_obs·t)` with
   `k_obs = k_inact·[L]/(K_i+[L])`; it is monotone-increasing, bounded in
   `[0, 1)`, and asymptotes to 1.0 — the off-rate is removed (acceptance
   criteria C3/C5).

## In-silico scope (g8 / f2)

The `__COVALENT_DEGRADER__ PASS` sentinel certifies **in-silico
simulator+metadata internal consistency ONLY**: that the irreversible-engagement
kinetics, the mass-action reversible occupancies, and the ternary coupling are
computed self-consistently and reproduce byte-identically. It is NOT an affinity
measurement, NOT a degradation (DC50/Dmax) claim, NOT a therapeutic-efficacy
claim. COVALENT-DEGRADER is research/early-clinical — nothing here is a clinical
claim. `K_i` / `k_inact` / `K_d` / `α` values are literature-informed surrogates
for the modality, not fits to a specific compound.

No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## Files

| file | role |
|---|---|
| `_python_bridge/module/covalent_degrader_sim.py` | deterministic stdlib-only simulator + `__COVALENT_DEGRADER__ PASS` sentinel |
| `_python_bridge/spec/covalent_degrader_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/covalent_degrader_subaxis.md` | this note |

Run: `python3 _python_bridge/module/covalent_degrader_sim.py`
