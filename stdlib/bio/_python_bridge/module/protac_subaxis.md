# PROTAC — sub-axis note

`:> BIFUNCTIONAL` (expansion-main, see `AXIS/HIERARCHY.tape`
`@D sub_under_bifunctional`). This is a **sub-axis**, NOT a hexa-bio core-5
axis — the core remains QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per
`AXIS.tape` (unchanged).

## Modality

A **PROTAC** (PROteolysis-TArgeting Chimera) is a bifunctional small molecule:
one warhead binds the target protein of interest (POI), the other binds an E3
ubiquitin ligase (CRBN, VHL, …), and a linker joins them. Unlike a classical
occupancy-driven inhibitor, a PROTAC works *catalytically* — it recruits the E3
to ubiquitinate the POI, which is then degraded by the 26S proteasome, and the
PROTAC is released to act again.

It **specializes** the parent BIFUNCTIONAL axis (bifunctional / ternary-complex
degraders) toward the **proteasomal** degradation pathway: the productive event
is a cooperative ternary complex POI·PROTAC·E3 that presents the POI surface
lysines to the E2~ubiquitin conjugate for ubiquitin transfer.

## Own drug precedent (g3 / f1 / f_lattice_fit — described by precedent, never lattice-derived)

- **ARV-471 (vepdegestrant)** — an estrogen-receptor (ER) PROTAC in clinical
  development (Arvinas / Pfizer programme).
- **ARV-110 (bavdegalutamide)** — an androgen-receptor (AR) PROTAC,
  clinical-stage (Arvinas).
- PROTAC chemistry traces to Sakamoto, Kim, Kumagai-Cresse, et al.,
  *PNAS* 98:8554 (2001) — the first peptidic PROTAC.

The modality is described **only** by this precedent — never derived from the
n=6 lattice. No count, K_d, cooperativity factor, or fraction here is a lattice
scalar.

## Real limit anchored (g1 — real-limits-first)

**The law of mass action / chemical-equilibrium thermodynamics.** Every binary
and ternary occupancy is a closed-form mass-action equilibrium — fractional
occupancy `θ = [L]/(K_d + [L])`, with `θ = 1/2` exactly at `[L] = K_d`. The
three-body ternary-complex equilibrium with a cooperativity factor `α`
(apparent `K_d,ternary = K_d(E3)/α`) and the resulting **hook effect**
(non-monotone ternary fraction in `[PROTAC]`) follow the published
three-body-binding model:

- Douglass, Miller, Sparer, Shapiro & Spiegel, "A comprehensive mathematical
  model for three-body binding equilibria", *J. Am. Chem. Soc.* 135:6092 (2013).
- Gadd, Testa, Lucas, et al., "Structural basis of PROTAC cooperative
  recognition for selective protein degradation", *Nat. Chem. Biol.* 13:514
  (2017) — cooperativity `α` measured for a VHL–BRD4 ternary complex.
- Hughes & Ciulli, "Molecular recognition of ternary complexes: a new
  dimension in the structure-guided design of chemical degraders",
  *Essays Biochem.* 61:505 (2017) — the hook effect.

Mass-action equilibrium is the hard real limit: no modelled occupancy may
exceed 1, and `θ = 1/2` must hold exactly at `[L] = K_d` (acceptance criteria
C2 / C3). No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## In-silico scope (g8 / f2)

The `__PROTAC__ PASS` sentinel certifies **in-silico simulator+metadata
internal consistency ONLY**: that the mass-action binary/ternary equilibria,
the cooperativity factor, the hook-effect peak and the degradation-drive
product are computed self-consistently and reproduce byte-identically. It is
NOT a binding-affinity measurement, NOT a degradation-potency (DC50/Dmax)
claim, NOT a therapeutic-efficacy claim. `K_d` / `α` / transfer-efficiency
values are literature-informed illustrative surrogates, not fits to a specific
compound. Crossing the wet-lab boundary is out of repo scope (`AGENTS.tape`
g8/f2 · `CLOSURE_RESIDUAL_BACKLOG.md` §0).

## Files

| file | role |
|---|---|
| `_python_bridge/module/protac_sim.py` | deterministic stdlib-only simulator + `__PROTAC__ PASS` sentinel |
| `_python_bridge/spec/protac_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/protac_subaxis.md` | this note |

Run: `python3 _python_bridge/module/protac_sim.py`
