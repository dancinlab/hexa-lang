# AUTAC — sub-axis note

`:> BIFUNCTIONAL` (expansion-main, see `AXIS/HIERARCHY.tape`
`@D sub_under_bifunctional`). This is a **sub-axis**, NOT a hexa-bio core-5
axis — the core remains QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per
`AXIS.tape` (unchanged).

## Modality

An **AUTAC** (AUTophagy-TArgeting Chimera) is a bifunctional molecule: one end
is a target-binding warhead, the other is an **S-guanylation-mimetic autophagy
degradation tag** (a cyclic-GMP derivative). The tag drives K63-linked
polyubiquitination of the target / target-containing cargo; the cargo is then
recognised by an autophagy receptor (p62/SQSTM1), recruited to the nascent
autophagosome via **LC3 (Atg8)**, and degraded on autophagosome–lysosome fusion.

It **specializes** the parent BIFUNCTIONAL axis toward the **autophagy**
degradation pathway. Where the sibling PROTAC sub-axis routes cargo to the
*proteasome* (E3-ligase ternary complex) and LYTAC routes extracellular cargo
to the *lysosome via endocytosis*, AUTAC routes cargo — including large cargo
such as fragmented mitochondria, which the proteasome cannot handle — to the
lysosome via **selective macroautophagy**.

## Own precedent (g3 / f1 / f_lattice_fit — described by precedent, never lattice-derived)

- **Takahashi, Moriya, Hara, Ichimura, Abe, Nishino, Aoki, Mizushima &
  Arimoto**, "AUTACs: Cargo-Specific Degraders Using Selective Autophagy",
  *Mol. Cell* 76:797 (2019) — the founding AUTAC work (Arimoto lab, Tohoku
  University), including mitochondria-targeting mito-AUTACs.
- The S-guanylation autophagy tag traces to 8-nitro-cGMP biology — Sawa,
  Zaki, Okamoto, et al., *Nat. Chem. Biol.* 3:727 (2007).

**AUTAC is a research-stage modality** — there is no FDA-approved AUTAC drug.
The 2019 *Mol. Cell* work and its follow-ups are discovery-stage. This is stated
honestly per g8/f2; the modality is described **only** by this research
precedent, never derived from the n=6 lattice.

## Real limit anchored (g1 — real-limits-first)

**Autophagic flux** — the first-order kinetic balance of autophagosome
*formation* against autophagosome–lysosome *fusion* — layered on the **law of
mass action**. Target tagging is a closed-form mass-action equilibrium
(`θ = [L]/(K_d + [L])`, `θ = 1/2` exactly at `[L] = K_d`). The
flux-completion partition `flux_partition = k_fusion/(k_fusion + k_stall)`, and
the principle that autophagic flux must be measured as a *turnover rate through*
the pathway and not as a static autophagosome count, follow the consensus
autophagy-flux methodology:

- Mizushima, N. & Yoshimori, T., "How to interpret LC3 immunoblotting",
  *Autophagy* 3:542 (2007) — LC3-I/LC3-II and the flux concept.
- Klionsky, D.J. et al., "Guidelines for the use and interpretation of assays
  for monitoring autophagy" — consensus guidelines (e.g. *Autophagy* 17:1,
  2021): autophagic flux is a turnover rate, not a steady-state pool.
- Loos, B., du Toit, A. & Hofmeyr, J.-H.S., "Defining and measuring
  autophagosome flux — concept and reality", *Autophagy* 10:2087 (2014).

The flux partition is bounded in `[0,1]` and the two partition fractions must
sum to 1 exactly; the mass-action half-occupancy identity must hold exactly at
`[L] = K_d` (acceptance criteria C2 / C3 / C4). No quantity here is derived from
the n=6 lattice (g2 / `f_lattice_fit`).

## In-silico scope (g8 / f2)

The `__AUTAC__ PASS` sentinel certifies **in-silico simulator+metadata internal
consistency ONLY**: that the mass-action target tagging, the LC3-recruitment
competence, the autophagic-flux partition and the degradation-flux product are
computed self-consistently and reproduce byte-identically. It is NOT a
binding-affinity measurement, NOT a degradation-potency claim, NOT a
therapeutic-efficacy claim. AUTAC is research-stage — nothing here is a
clinical or regulatory claim. `K_d` / rate-constant / tag-competence values are
literature-informed illustrative surrogates, not fits to a specific compound.
Crossing the wet-lab boundary is out of repo scope (`AGENTS.tape` g8/f2 ·
`CLOSURE_RESIDUAL_BACKLOG.md` §0).

## Files

| file | role |
|---|---|
| `_python_bridge/module/autac_sim.py` | deterministic stdlib-only simulator + `__AUTAC__ PASS` sentinel |
| `_python_bridge/spec/autac_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/autac_subaxis.md` | this note |

Run: `python3 _python_bridge/module/autac_sim.py`
