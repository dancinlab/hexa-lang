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

## 2026-06-13 — round-3: electrostatic embedding (MM charges → QM V_ext → density polarizes)

### QM external-potential hook audit (d6 · @L5)

- AUDITED `stdlib/qforge/assembler::qforge_assemble_h` — it DOES fold a local V_ext(G−G') =
  V_loc(|ΔG|)·S(ΔG) (+ V_NL + caller screening) into the dense plane-wave Kohn-Sham H that
  `qforge_scf` (stdlib/qforge/scf) diagonalizes self-consistently. A real V_ext SCF injection site
  exists — an MM point-charge field is, in principle, just another local G-space diagonal term.
- BUT driving it to a self-consistent POLARIZED DENSITY needs the full PW stack (gvecs · UPF
  channels · screening ρ-callbacks). Round-2 already set the honest convention that the toy QM
  region is its `qforge_ewald` electrostatic total, not a converged PW SCF on a molecule. Forcing a
  full PW SCF on the toy would fabricate convergence we have not run (d6) → HONEST minimal path =
  exact O(E²) linear response (static polarizability α·E) for the polarization sign + order.

### round-3 brick

- [x] `stdlib/qforge/system/embed_electrostatic.hexa` — electrostatic embedding. d4-generic: V_ext /
      field are CALLBACKS over the MM charge array; `embed_electrostatic_total` takes plain floats.
      Provides: `embed_ee_vext_at` (V_ext(r)=Σ q_MM/|r−R_MM|), `embed_ee_field_at` (E=−∇V_ext),
      `embed_ee_induced_dipole` (μ=αE), `embed_ee_polarization_energy` (E_pol=−½α|E|²),
      `embed_electrostatic_total`, `embed_ee_minus_me`, `embed_electrostatic_from_regions`.
- [x] `stdlib/qforge/system/embed_electrostatic_selftest.hexa` (@ci_gate) — 18 checks, analytic/toy.
- [x] g5 VERBATIM (HEXA_MAC_BUILD_OK=1 hexa build … && run):
      ```
      PASS (a) field_x analytic (single +q, −x side) (got 0.125)
      PASS (a) field_y == 0 (|got|=0.0)
      PASS (a) field_z == 0 (|got|=0.0)
      PASS (a) induced dipole μ_x = α·E_x (along field) (got 0.5625)
      PASS (a) μ·field projection > 0 (dipole ALONG field) (got 0.0703125 > 0)
      PASS (a) V_ext(+q) > 0 at QM point (got 0.5 > 0)
      E_ME=2537.78  E_EE=2537.78  EE−ME=-2.97092e-05  e_pol_ref=-2.97092e-05
      PASS (b) EE − ME == e_pol = −½α|E|² (order exact) (got -2.97092e-05)
      PASS (b) polarization term is NEGATIVE (stabilizing) (got -2.97092e-05 < 0)
      PASS (b) helper e_pol == EE − ME (got -2.97092e-05)
      PASS (c) |field| → 0 at separation (|got|=7.74382e-37)
      PASS (c) EE == ME when field → 0 (got 2537.78)
      PASS (d) field_x reverses (== −original) (got -0.125)
      PASS (d) induced dipole μ_x reverses (== −original) (got -0.5625)
      PASS (d) μ_rev · field_rev > 0 (tracks reversed field) (got 0.0703125 > 0)
      PASS (d) e_pol INVARIANT under charge-sign flip (quadratic) (got -0.0351563)
      PASS (d) e_pol still stabilizing (< 0) after flip (got -0.0351563 < 0)
      PASS (d) V_ext sign-flips with the charge (got -0.5)
      embed_electrostatic_selftest PASS
      ```
- FINDING: the MM external potential polarizes the QM region; the induced dipole μ=αE points ALONG
  the field (sign exact), and EE − ME = E_pol = −½α|E|² < 0 — the polarization STABILIZATION absent
  in mechanical embedding (round-2). Field→0 ⇒ EE==ME; a charge-sign flip REVERSES the dipole
  (vector negation) while leaving E_pol invariant (quadratic in the field — the stabilization is
  sign-independent). All four mandated checks closed to round-off.

### honesty (d6 · @L5)

The polarization is proven via EXACT second-order linear response (static polarizability α·E), the
universal O(E²) response of any stable ground state (α>0) — its sign + order are not a model choice.
The MM field is the REAL Coulomb sum (the same 1/|r−R| the SCF hook would inject); only the DENSITY
response is taken to its exact leading order rather than from a converged PW SCF we did not run. Full
self-consistent SCF polarization (via `qforge_assemble_h` V_ext) + hyperpolarizability (β,γ) are the
round-3+ refinement — flagged, not fabricated. No invented convergence, no forced numbers.

### round-4 (next)

Covalent boundary / link atom: H-cap a cut bond across the QM/MM boundary + host-charge
redistribution (charge-shift / RESP-style). g5 = link-atom force projection conserves total force
(Newton's 3rd law across the boundary); the capped-bond energy reduces to the uncut reference when
QM≡MM on the boundary atom. Reuses round-1 partition + round-3 V_ext (the link-atom host charge is
an MM point charge the QM now sees electrostatically).
