# ALLOSTERIC — sub-axis note

`:> QUANTUM (core)` — see `AXIS/HIERARCHY.tape` `@D sub_under_quantum`.
This is a **sub-axis**, NOT a hexa-bio core-5 axis. The core remains
QUANTUM · WEAVE · NANOBOT · RIBOZYME · VIROCAPSID per `AXIS.tape` (unchanged).
The sub hangs off the core QUANTUM axis as a tag — the cryptic allosteric
pocket is a VQE-applicable active-site target — and does **not** mutate the
core axis.

## Modality

An *allosteric* modulator binds a site **distinct from the orthosteric site**
and from there shifts the orthosteric affinity/activity of the target. It
specializes the QUANTUM axis toward modulators of pocket conformational
equilibria. The pharmacological signature that separates allostery from simple
orthosteric competition is **saturability**: an orthosteric competitor shifts
EC50 without bound (linear in competitor concentration), whereas an allosteric
modulator's effect reaches a **ceiling** once every allosteric site is occupied.

## Real limit anchored (g1)

The **Monod-Wyman-Changeux concerted allosteric model** (Monod, Wyman &
Changeux, *J. Mol. Biol.* 12:88, 1965) and the Allosteric Two-State /
ternary-complex formalism (Hall, *Mol. Pharmacol.* 58:1412, 2000;
Christopoulos & Kenakin, *Pharmacol. Rev.* 54:323, 2002). The model collapses
the ternary equilibrium to the cooperativity factor `α`:

```
EC50_obs / EC50_orth = (1 + [B]/K_B) / (1 + α·[B]/K_B)
```

The hard real limit is that the modulation is **saturable** — as `[B] → ∞` the
affinity shift converges to the ceiling `1/α` and cannot pass it (acceptance
criterion C2/C6). Detailed balance of the ternary cycle fixes the equilibrium
relations self-consistently. `α > 1` → PAM, `α < 1` → NAM, `α ≈ 1` → neutral.

## Own drug precedent (g3 / f1 — described by precedent, never lattice-derived)

- **maraviroc** — allosteric CCR5 antagonist, binding a transmembrane-cavity
  site distinct from the chemokine orthosteric site (Dorr et al.,
  *Antimicrob. Agents Chemother.* 49:4721, 2005).
- **trametinib** — allosteric MEK1/2 inhibitor binding adjacent to the ATP
  pocket (Gilmartin et al., *Clin. Cancer Res.* 17:989, 2011).
- **asciminib** — allosteric BCR-ABL1 inhibitor at the **myristoyl pocket**, a
  site distinct from the ATP (orthosteric) site (Wylie et al., *Nature*
  543:733, 2017; FDA-approved 2021).

## In-silico scope (g8 / f2)

The `__ALLOSTERIC__ PASS` sentinel certifies **in-silico simulator+metadata
internal consistency ONLY**: that the MWC/ternary-complex equilibria, the
cooperativity factor `α`, the EC50 affinity-shift sweep and the saturable
ceiling `1/α` are computed self-consistently and reproduce byte-identically.
It is NOT a binding-affinity, potency, selectivity, or therapeutic-efficacy
claim. The `α` / `K_B` values are literature-informed surrogates for modulator
*classes*, not fits to a specific compound.

No quantity here is derived from the n=6 lattice (g2 / `f_lattice_fit`).

## Files

| file | role |
|---|---|
| `_python_bridge/module/allosteric_sim.py` | deterministic stdlib-only simulator + `__ALLOSTERIC__ PASS` sentinel |
| `_python_bridge/spec/allosteric_v1.schema.json` | JSON Schema (draft-07) for the output rows |
| `_python_bridge/module/allosteric_subaxis.md` | this note |

Run: `python3 _python_bridge/module/allosteric_sim.py`
