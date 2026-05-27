# APTAMER — sub-axis note (`:> RIBOZYME`, core)

**Status:** specialization SUB-AXIS hanging off the core **RIBOZYME** axis.
This is **not** a 6th core axis — the hexa-bio core stays 5 (QUANTUM · WEAVE ·
NANOBOT · RIBOZYME · VIROCAPSID per `AXIS.tape`). Recorded under the
expansion-layer pattern of `AXIS/HIERARCHY.tape`. The core-5 SSOT is UNCHANGED.

## What APTAMER is — and how it differs from its parent

The parent **RIBOZYME** axis models *catalytic RNA* (Cech/Altman class): RNA
that performs chemistry, `k_cat > 0`, governed by transition-state theory and
the two-metal-ion mechanism.

An **aptamer** is a *non-catalytic structured oligonucleotide binder*: a folded
RNA (or DNA) whose secondary/tertiary structure forms a binding pocket for a
ligand. `k_cat = 0` — an aptamer binds, it does not catalyze. This is the
defining distinction from the parent axis, and it matches the literature-
anchored negative-control corpus already in-repo
(`ribozyme/module/aptamer_null_corpus.hexa` — binding-only RNAs, all `k_cat=0`).

The sub-axis **specializes** the parent's machinery: it reuses RIBOZYME's
RNA secondary-structure folding (Nussinov 1978 base-pair maximization, cf.
`_python_bridge/module/ribozyme_mfe_nussinov.py`) and redirects it from
catalytic-turnover modeling toward **equilibrium affinity** — the fold defines
the binding-competent pocket; affinity is read out as a dissociation constant.

## Modality and its own drug precedent

The aptamer is a real, independent therapeutic modality with its own clinical
track record — described here **only** by that precedent, never derived from
the n=6 lattice (governance g3/f1/f_lattice_fit):

- **pegaptanib sodium (Macugen)** — a PEGylated anti-VEGF165 RNA aptamer,
  FDA-approved 2004 for neovascular age-related macular degeneration.
- **avacincaptad pegol (Izervay / Zimura)** — an anti-complement-C5 RNA
  aptamer, FDA-approved 2023 for geographic atrophy.

## Real limit anchored (governance g1 — real-limits-first)

The sub-axis simulator (`_python_bridge/module/aptamer_affinity_sim.py`)
anchors to published real limits:

- **Nucleic-acid folding thermodynamics** — the nearest-neighbour free-energy
  model: SantaLucia (1998), *PNAS* 95:1460–1465; RNA Turner parameters via
  Turner & Mathews (2010), *Nucleic Acids Research* 38:D280–D282. Folding free
  energy is a sum of measured stacked nearest-neighbour increments.
- **A published aptamer Kd** — the thrombin-binding DNA aptamer (15-mer
  G-quadruplex "TBA"): Bock, Griffin, Latham, Vermaas & Toole (1992), *Nature*
  355:564–566; low-to-mid nanomolar affinity for human α-thrombin.
- Binding follows the law of mass action: `Kd = koff/kon`; fraction bound
  `θ = [L]/(Kd+[L])`, with `θ = 0.5` exactly at `[L] = Kd`.

No count, energy, or Kd is derived from the n=6 lattice (g2/f_lattice_fit) —
folding ΔG comes from nearest-neighbour thermodynamics, Kd from mass action.

## In-silico scope (governance g8 / f2)

Every PASS in this sub-axis verifies **in-silico simulator-consistency only**:
that the fold and binding models are internally self-consistent and reproduce
textbook identities. It is **not** a wet-lab, structural, binding-affinity,
therapeutic, clinical, or regulatory claim about any aptamer. Parameters are
literature-informed illustrative magnitudes, not fits to a specific dataset.
Crossing the wet-lab boundary is out of repo scope (`AGENTS.tape`
g8_in_silico_only · f2 · `CLOSURE_RESIDUAL_BACKLOG.md` §0).
