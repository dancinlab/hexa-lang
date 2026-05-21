# RNA-TARGETING-SMALL-MOLECULE — sub-axis note

**Sub-axis** `RNA-TARGETING-SMALL-MOLECULE` `:>` **RIBOZYME** (core-5 axis).
This is a *specialization* sub-axis. It does **not** mutate the committed
core-5 hexa-bio axes (QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID);
the core-5 RIBOZYME axis is **UNCHANGED**. See `AXIS/HIERARCHY.tape` for
the expansion-layer convention used to record sub-axes.

## What it is — and how it differs from the parent

- **RIBOZYME (parent, core)** = *catalytic RNA* — the RNA molecule **is**
  the enzyme (group I/II introns, RNase P, hammerhead, the ribosomal PTC).
  Modality: RNA catalysis.
- **RNA-TARGETING-SMALL-MOLECULE (this sub)** = *small molecules that bind
  an RNA structural motif and shift the RNA secondary-structure ensemble.*
  Here the RNA is the **drug target**, and the small molecule is the
  **drug** — the opposite role assignment from the parent.

The two share one substrate: **RNA-secondary-structure modeling**. The
parent axis already models RNA structure (`ribozyme_mfe_nussinov.py`,
Nussinov base-pair maximization). This sub-axis **specializes** that
modeling to the small-molecule-binding case: it folds a baseline
ensemble, then re-folds under a ligand binding constraint, and reports
the structural shift in an exon-inclusion-relevant stem. The sub-axis
simulator **imports** the parent's Nussinov solver — it does not fork it.

## Modality + own drug precedent (governance g3 / f1 / f_lattice_fit)

The modality is described **only** via its own published drug precedent —
never derived from the n=6 lattice:

- **risdiplam / Evrysdi** — a small-molecule, orally-bioavailable
  SMN2 pre-mRNA **exon-7 splicing modulator** (CDER drug, FDA-approved
  2020; Roche / PTC Therapeutics / SMA Foundation). It binds the SMN2
  exon-7 5'-splice-site region and shifts splicing toward exon-7
  *inclusion*. Ratni H et al., *J Med Chem* 2018;61:6501-6517;
  Campagne S et al., *Nat Chem Biol* 2019;15:1191-1198 (structural basis).
- **branaplam (LMI070)** — a second small-molecule SMN2 exon-7
  splicing-modulator of the same modality (Novartis).

No count, position, shift, or ensemble fraction in this sub-axis is
derived from any lattice scalar (σ=12 · τ=4 · φ=2 · J₂=24). Any numerical
coincidence with a lattice value is **observation only**, never a
derivation (AGENTS.tape g2 / f1; HIERARCHY.tape f_lattice_fit).

## Real limit anchored (governance g1 — real-limits-first)

**RNA secondary-structure thermodynamics.** An RNA's accessible
structural ensemble is governed by base-pair free energy, not by any
lattice invariant:

- Nussinov RC, Pieczenik G, Griggs JR, Kleitman DJ. "Algorithms for loop
  matchings." *SIAM J Appl Math* 1978;35:68-82 — base-pair maximization
  dynamic program (the parent axis's `ribozyme_mfe_nussinov.py` solver).
- Turner DH, Mathews DH. "NNDB: the nearest-neighbor parameter database
  for predicting RNA secondary structure." *Nucleic Acids Res*
  2010;38:D280-D282 — nearest-neighbor free-energy model; the structural
  ensemble is a Boltzmann distribution over ΔG.

A small molecule binding an RNA motif acts as a constraint on this
thermodynamic ensemble, shifting the population among competing folds.
That is the physical limit this sub-axis models.

## In-silico scope (governance g8 / f2)

Every PASS sentinel (`__RNA_TARGETING_SMALL_MOLECULE__ PASS`, emitted by
`_python_bridge/module/rna_targeting_small_molecule_sim.py`) certifies
**in-silico simulator + metadata internal consistency ONLY**. It is
**never** a therapeutic, clinical, splicing-correction, efficacy,
immunogenic, or regulatory claim. risdiplam / branaplam are cited for
their published modality only — this note neither re-derives nor
endorses their clinical results. Wet-lab validation of any predicted
structural shift is out of repo scope (CLOSURE_RESIDUAL_BACKLOG.md §0).

## Files

- `_python_bridge/module/rna_targeting_small_molecule_sim.py` —
  deterministic, stdlib-only simulator (imports the parent Nussinov
  solver; byte-identical re-run = the §11 deductive-verification
  contract → `hexa verify` 🟢 SUPPORTED-NUMERICAL discipline).
- `ribozyme/spec/rna_targeting_small_molecule_v1.schema.json` —
  JSON Schema draft-07 contract for the output rows.
- `ribozyme/spec/rna_targeting_small_molecule_subaxis.md` — this note.
