# QFORGE-SYSTEM — log (append-only)

## 2026-06-13 — round-1: lit grounding + bridge design + first g5 brick (partition consistency)

### lit grounding (d18 — arxiv + web)

- Warshel & Levitt 1976 (J.Mol.Biol. 103 227) — first QM/MM (lysozyme carbonium ion); QM active
  site embedded in classical/electrostatic environment, structurally + electrostatically coupled.
- Senn & Thiel 2009 (Angew.Chem.Int.Ed. 48 1198) — canonical review. ADDITIVE
  `E=E_QM(inner)+E_MM(outer)+E_QM-MM` vs SUBTRACTIVE/ONIOM `E=E_high(model)+E_low(real)−E_low(model)`
  (Svensson 1996; Chung et al. 2015 Chem.Rev. 115 5678). Embedding = mechanical / electrostatic /
  polarized. Covalent boundary = link atom (H-cap) + charge-shift.
- MARTINI (Marrink; Martini 3, Nat.Methods 2021) — CG ~4-heavy-atom:1-bead, families P/N/C/Q. The
  scale below MM; QM/CG-MM (arXiv:1709.09771) shares the additive coupling structure.
- NOVEL probe (multiscale 2024-25 — ML/MM arXiv:2408.03273; QM/MM-Ewald vs -Multipole energy
  conservation): additive & ONIOM totals are the SAME partition at mechanical embedding, not rivals.
  → became the round-1 consistency lever.

### first g5 brick

- [x] `stdlib/qforge/system/qmmm.hexa` — energy-partition algebra. d4-generic: every fn takes
      energies as plain floats (results of QM/MM callbacks), no engine hardcoded. Provides:
      `qmmm_additive_total`, `qmmm_mechanical_coupling`, `qmmm_oniom2_total`,
      `qmmm_additive_from_levels`, `qmmm_scheme_residual`.
- [x] `stdlib/qforge/system/qmmm_selftest.hexa` (@ci_gate) — 10 checks, all analytic/closed-form.
- [x] g5 VERBATIM (HEXA_MAC_BUILD_OK=1 hexa build … && run):
      ```
      PASS identity set A residual (|got|=0.0)
      PASS identity set B residual (|got|=0.0)
      PASS identity set C residual (|got|=8.88178e-16)
      PASS identity set A additive==ONIOM total (got -40.8)
      PASS MM-only ONIOM == E_low(real) (got -88.0)
      PASS MM-only additive == E_low(real) (got -88.0)
      PASS partition P==Q (boundary invariance) (got -57.0)
      PASS partition P additive==ONIOM (got -57.0)
      PASS mechanical coupling hand value (got -7.0)
      PASS non-interacting coupling == 0 (|got|=0.0)
      qmmm_selftest PASS
      ```
- FINDING: additive QM/MM ≡ ONIOM 2-layer at mechanical embedding with
  `E_QM-MM := E_low(real)−E_low(inner)−E_low(outer)`. Residual = 0 (machine zero) for arbitrary
  inputs; MM-only limit → E_low(real); partition-boundary invariant. The bridge's foundation is
  internally consistent.

### honesty (d6 · @L5)

Round-1 = lit + design + ONE brick (partition-consistency identity). Rounds 2-5 (real qforge-SCF ↔
chem/md mechanical/electrostatic coupling, link atoms, CG tier) are OPEN. The identity is proven for
ALL inputs (algebraic; toy energies stand in for any callback) — what is NOT yet wired is the real
QM/MM engine coupling. No fabricated coupling numbers.

### round-2 (next)

Mechanical embedding with real cores: E_QM=qforge `scf_etot`, E_MM=chem/md `total_energy`, coupling
= classical LJ+Coulomb via `ewald`/`pme`. g5 = 2-fragment toy where the QM frag is also
MM-parameterized matches a hand additive sum. Design draft: `drafts/qforge-system-round1-design.md`.
