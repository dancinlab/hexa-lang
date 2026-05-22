# CRYPTIC-POCKET — sub-axis note

`:> QUANTUM (core)` — see `AXIS/HIERARCHY.tape` `@D sub_under_quantum`.
This is a **sub-axis**, NOT a hexa-bio core-5 axis. The core remains
QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per `AXIS.tape` (unchanged).
The sub hangs off the core QUANTUM axis as a tag — the *opened* cryptic pocket
is a VQE-applicable active-space target — and does **not** mutate the core axis.

## Modality

A *cryptic* pocket is a transient binding site that is **absent (closed) in the
apo crystal structure** and opens only under protein dynamics. It specializes
the QUANTUM axis toward targets whose druggable pocket is not visible at rest.
The site lives on a conformational equilibrium between a closed (pocket-absent)
and an open (pocket-formed, druggable) state.

## Real limit anchored (g1)

**Conformational free-energy / Boltzmann population statistics.** The open-state
population of the apo protein is fixed by

```
P_open = exp(-ΔG_open/RT) / (1 + exp(-ΔG_open/RT))      bounded in (0,1)
```

For a genuine cryptic pocket `ΔG_open > 0` and `P_open ≪ 1` — rarely sampled,
hence invisible in the apo crystal. The **conformational-selection
thermodynamic cycle** (Hammes, Chang & Oas, *PNAS* 106:13737, 2009) fixes the
ledger: a binder that selects the open state must pay the opening cost out of
its intrinsic affinity,

```
ΔG_bind_obs = ΔG_bind_open + ΔG_open
```

This conservation of the conformational free-energy ledger is the hard real
limit — a binder cannot escape paying `ΔG_open` (acceptance criteria C2/C4).
Cryptic-pocket conformational equilibria follow the simulation/Markov-state
literature: Bowman & Geissler, *PNAS* 109:11681 (2012); Vajda et al.,
*Curr. Opin. Chem. Biol.* 44:1 (2018).

## Own drug precedent (g3 / f1 — described by precedent, never lattice-derived)

- the **KRAS-G12C switch-II pocket** — a cryptic pocket absent in early apo
  KRAS structures, revealed under dynamics and exploited by sotorasib
  (Ostrem et al., *Nature* 503:548, 2013; Canon et al., *Nature* 575:217,
  2019; sotorasib FDA-approved 2021).
- the **TEM-1 β-lactamase cryptic allosteric site** — a transient pocket
  distal to the active site, detected by tethering / MD (Horn & Shoichet,
  *J. Mol. Biol.* 336:1283, 2004; Bowman & Geissler, *PNAS* 109:11681, 2012).

## In-silico scope (g8 / f2)

The `__CRYPTIC_POCKET__ PASS` sentinel certifies **in-silico simulator+metadata
internal consistency ONLY**: that the Boltzmann open-state populations, the
conformational free-energy ledger `ΔG_bind_obs = ΔG_bind_open + ΔG_open` and the
cryptic-site viability gate are computed self-consistently and reproduce
byte-identically. It is NOT a binding-affinity, potency, selectivity, or
therapeutic-efficacy claim, and NOT a prediction that any specific pocket is
real or druggable. The `ΔG` values are literature-informed surrogates for
pocket *classes*, not fits to a specific protein.

No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## Files

| file | role |
|---|---|
| `_python_bridge/module/cryptic_pocket_sim.py` | deterministic stdlib-only simulator + `__CRYPTIC_POCKET__ PASS` sentinel |
| `_python_bridge/spec/cryptic_pocket_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/cryptic_pocket_subaxis.md` | this note |

Run: `python3 _python_bridge/module/cryptic_pocket_sim.py`
