# QFORGE MOLSCF — molecular SCF front-end (round-1 design)

**slug**: qforge-molscf · **handoff**: b143b899 (qfs-r8 → hexa-lang, molecular-SCF front-end gap) · adjacency f6611b1e, chem #3138
**status**: round-1 — lit + design + brick 1 (s-type 1-electron integrals) SHIPPED & g5-PASS

## Why (the cross-cutting wall, d2)

QFORGE's only SCF is **periodic plane-wave** (`stdlib/qforge/scf_pw.hexa`): basis = Bloch `|k+G⟩`,
kinetic = diagonal `½|k+G|²` (`kinetic.hexa`), potential on a `G`-grid. That basis is **wrong for a finite
molecule** — no Bloch `k`, the wavefunction decays to 0, and the natural basis is **atom-centered
Gaussian/STO orbitals**. So `atoms`, `chem`, and `system` all share ONE blocker: there is no molecular
(non-periodic) ab-initio path. A from-scratch atom-centered Roothaan RHF SCF opens all three at once.

## Lit grounding (round-1, d18)

- **Roothaan 1951** (Rev. Mod. Phys. 23, 69) — the RHF SCF matrix equation `F C = S C ε` (generalized
  eigenproblem in a non-orthogonal AO basis). The whole front-end targets this fixed point.
- **Szabo & Ostlund, _Modern Quantum Chemistry_** — Appendix A closed forms for s-type Gaussian integrals
  (A.4 product theorem, A.9 overlap, A.11 kinetic, A.32/A.33 nuclear + 2-electron via Boys `F₀`). The g5
  anchors (STO-3G H₂ `S_AB@1.4bohr = 0.6593182001`) come from here.
- **Boys 1950 / McMurchie-Davidson 1978** — Gaussian product theorem + Hermite-Gaussian recursion;
  nuclear-attraction and `(ab|cd)` reduce to the Boys function `F₀(t) = ½√(π/t)·erf(√t)` — **reuses
  `stdlib/core/special.erf_fn` directly** (no new special fn).
- **Hehre, Stewart & Pople 1969** (STO-3G, J. Chem. Phys. 51, 2657) — the 3-Gaussian contraction fit of a
  Slater 1s; supplies the brick-1 H 1s primitive set.
- **NOVEL probe — end-to-end differentiable HF** (arxiv 1711.08127 Tamayo-Mendoza 2018; 2203.04441 2022):
  autodiff *through* the SCF fixed point gives analytic energy gradients (forces) without coding them by
  hand. QFORGE already ships **`stdlib/autograd`** → a hexa-native MOLSCF can be **differentiable from day
  one**: molecular forces = `∇_R E` by autograd through `gint_*` + the SCF solve. This is the QFORGE
  differentiator vs a classic Fortran HF (PySCF/Psi4 bolt AD on afterward). Pursue in round-3.

## Common-core reuse map (d19 — mint no new primitive)

| MOLSCF need | reuse | location |
|---|---|---|
| generalized eigenproblem `FC=SCε` | `eigh` / `eigvalsh` (Jacobi) | `stdlib/alloc/math/eigen.hexa` |
| Boys `F₀` (nuclear V, 2-e `(ab\|cd)`) | `erf_fn` | `stdlib/core/special.hexa` |
| molecular force `∇_R E`, gradients | autograd through `gint_*` | `stdlib/autograd` |
| `−½∇²` kinetic physics | same operator, atom-centered re-expression | mirrors `stdlib/qforge/kinetic.hexa` |
| SCF driver loop / mixing | pattern from PW SCF | `stdlib/qforge/scf.hexa`, `mixing.hexa` |
| `exp`/`sqrt`/`pow` | language builtins (float) | — |

## Roadmap (integrals → RHF SCF → forces → 3-scale wiring)

```
brick 1  s-type S, T              ✅ SHIPPED  gaussian_integrals.hexa (g5 PASS)
brick 2  nuclear attraction V_ab  ◻ round-2   Boys F₀ via erf_fn (Szabo A.33)
brick 3  two-electron (ab|cd)     ◻ round-2   Boys F₀, 4-index (Szabo A.41)
brick 4  H_core = T + V, Fock     ◻ round-2   F = H_core + G[P] (G from (ab|cd) + density P)
brick 5  RHF SCF  F C = S C ε     ◻ round-3   eigh(S^-½ F S^-½) loop → SCF energy (g5: H₂ E≈−1.117 Ha)
brick 6  molecular force ∇_R E    ◻ round-3   autograd through brick 1-5 (NOVEL lane)
brick 7  p/d angular momentum     ◻ round-4   Hermite recursion (beyond s-only) for real chemistry
```

g5 anchors per brick: V via Szabo A.33 closed form · `(ab|cd)` via the [00|00] Boys value ·
RHF H₂/STO-3G total energy `E ≈ −1.1167 Ha` @ 1.4 bohr (Szabo Table 3.5).

## Three-scale unblock (what this opens)

- **atoms** — single-atom Hartree-Fock (He, Be) as the smallest closed RHF test; atomic reference states.
- **chem** — molecular RHF energies/geometries (H₂, H₂O at STO-3G), reaction-energy deltas; the chem #3138
  path that needs a *molecular* (not periodic) engine.
- **system** — finite-cluster / molecular-fragment SCF feeding larger system models without a periodic
  supercell artifact (the f6611b1e adjacency).

All three consume the SAME `gint_*` + RHF brick — one generic atom-centered path (d4), instance = the
basis-set + geometry manifest only, no per-molecule dispatcher.

## round-2 next (immediate)

1. **brick 2 — nuclear attraction `V_ab`** (Boys `F₀` via `erf_fn`, Szabo A.33). g5: `[00|00]`-style
   closed form + same-center limit.
2. **brick 3 — two-electron `(ab|cd)`** (Boys `F₀`, 4-index s-only). g5: the analytic `(ss|ss)` value.
3. **brick 4 — Fock build** `F = H_core + G[P]` once V and `(ab|cd)` exist.
