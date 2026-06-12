# QFORGE/system — multi-scale bridge · round-1 design

`system` = the scale that JOINS the scales QFORGE already verifies in isolation.
QFORGE has QM (`stdlib/qforge/` SCF · DFPT · el-ph) and MM (`stdlib/chem/md/`
lennard_jones · bonded · ewald · pme). `system` is the bridge driver: one
multi-scale energy + force, verified by **lower-scale consistency** (a QM/MM
partition of a purely-MM system must reproduce the bare MM energy, etc.).

## Lit grounding (round-1)

- **Warshel & Levitt 1976** (J.Mol.Biol. 103 227) — first QM/MM: lysozyme
  carbonium-ion, QM active site embedded in a classical/electrostatic
  environment, structurally + electrostatically coupled. (2013 Nobel.)
- **Senn & Thiel 2009** (Angew.Chem.Int.Ed. 48 1198) — canonical review.
  - **Additive**: `E = E_QM(inner) + E_MM(outer) + E_QM-MM(coupling)`. Inner
    by QM, rest by MM, explicit inner↔outer coupling term.
  - **Subtractive / ONIOM** (Svensson 1996; Chung et al. 2015 Chem.Rev. 115
    5678): `E = E_high(model) + E_low(real) − E_low(model)`. Whole system at
    cheap level, model region corrected up to high level; coupling implicit.
  - **Embedding**: *mechanical* (MM sees QM region as fixed MM atoms — coupling
    is classical), *electrostatic* (MM point charges enter the QM Hamiltonian
    as a 1-electron operator — QM polarizes to the environment), *polarized*
    (mutual). EE is the workhorse for chemistry-in-environment.
  - **Boundary**: covalent QM/MM cut → *link atom* (cap the dangling bond with
    H), or frozen LMO / boundary-atom schemes. Charge-shift to avoid
    over-polarization near the cut.
- **MARTINI** (Marrink et al.; Martini 3, Nat.Methods 2021) — CG: ~4-heavy-atom
  → 1 bead, bead families P/N/C/Q. The third scale below MM; QM/CG-MM
  (arXiv:1709.09771) shares the additive coupling structure of QM/MM.
- **NOVEL probe** (multiscale 2024-25 · ML/MM, arXiv 2408.03273; energy-
  conservation in QM/MM-Ewald vs -Multipole): the additive and ONIOM totals
  are the **same partition** at mechanical embedding — not rival schemes. This
  is the consistency lever the bridge is built on (and what round-1 verifies).

## Bridge roadmap (build order)

1. **[round-1 ✅] Energy-partition algebra** — additive ↔ ONIOM consistency
   identity + toy limits. `stdlib/qforge/system/qmmm.hexa`. d4-generic: QM/MM
   energies are callback *results* (plain floats), no engine hardcoded. g5 ✅.
2. **[round-2] Mechanical embedding, real cores** — wire E_QM = qforge SCF
   total (`scf_etot`/`scf`), E_MM = chem/md `total_energy` (LJ+bonded), coupling
   = mechanical (classical LJ+Coulomb between regions via `ewald`/`pme`). g5 =
   energy of a 2-fragment toy where the QM frag is also MM-parameterized →
   matches a hand additive sum.
3. **[round-3] Electrostatic embedding** — fold MM point charges into the QM
   one-electron Hamiltonian (`scf` external-potential hook). g5 = QM dipole
   shifts toward the embedding field; EE energy ≠ ME energy by the
   polarization term, sign + order-of-magnitude pinned.
4. **[round-4] Covalent boundary / link atom** — H-cap a cut bond, redistribute
   the host charge. g5 = link-atom force projection conserves total force
   (Newton's 3rd across the boundary); energy invariant to cap bond length in
   the redundant-coordinate limit.
5. **[round-5] CG tier (MARTINI-style)** — third scale; QM/MM/CG additive
   coupling reusing the same partition algebra. g5 = MM→CG coarse-graining
   preserves the slow-DOF free energy in a toy.

## Core reuse map (d19)

| bridge term            | hexa core (reused, not rebuilt)                          |
|------------------------|----------------------------------------------------------|
| E_QM(inner)            | `stdlib/qforge/scf` · `scf_etot` (SCF total energy)      |
| E_MM(outer)            | `stdlib/chem/md/lennard_jones` total_energy · `bonded`   |
| E_QM-MM electrostatic  | `stdlib/chem/md/ewald` · `pme` (long-range Coulomb)      |
| forces (all scales)    | `stdlib/chem/md/forces_autograd` (autograd) · qforge HF  |
| partition algebra      | **`stdlib/qforge/system/qmmm`** (this brick)             |

The partition layer NEVER branches on engine identity (d4) — swapping QM=qforge
for a toy, or MM=chem/md for CG, is "pass a different number". NEXUS.tape edge:
`QFORGE/system reuses qforge/scf_etot + chem/md/{lennard_jones,ewald}`.

## Round-1 finding (g5-verified)

The additive QM/MM and ONIOM 2-layer schemes are **algebraically identical** at
mechanical embedding, with `E_QM-MM := E_low(real) − E_low(inner) − E_low(outer)`:
```
E_high(inner) + E_low(outer) + [E_low(real)−E_low(inner)−E_low(outer)]
  = E_high(model) + E_low(real) − E_low(model)   (model ≡ inner)   ∎
```
Verified residual = 0 (machine zero) over 3 arbitrary input sets, + MM-only
limit, + partition-boundary invariance, + coupling sanity. 10/10 g5 checks PASS.
