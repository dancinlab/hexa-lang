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

## 2026-06-13 — round-4: covalent boundary / link atom (H-cap + charge-shift)

### R1 partition + R3 V_ext audit (d3 · d19)

- AUDITED `stdlib/qforge/system/qmmm` (R1) — additive/ONIOM partition algebra; the link-atom capped
  energy is the R1 ONIOM subtractive total specialised to the capped model region (reused, d3).
- AUDITED `stdlib/qforge/system/embed_electrostatic` (R3) — `embed_ee_vext_at(rq, q_mm, pos_mm)` is
  the V_ext the MM point charges inject into the QM. CONFIRMED: the link-atom host charge IS an MM
  point charge the R3 V_ext sees → the charge-SHIFTED MM charge array feeds straight into R3 V_ext
  (verified identical in-gate: `link_vext_after_shift` == `embed_ee_vext_at`). No new V_ext code.
- FRONTIER (QM) = atom Q at R_Q; HOST (MM) = atom H at R_H bonded across the boundary. The cut bond
  Q—H is capped by a monovalent link atom L (H-cap), a LINEAR SLAVE of Q,H (no new DOF).

### round-4 brick

- [x] `stdlib/qforge/system/link_atom.hexa` — covalent boundary / link atom. d4-generic: placement
      ratio g, host charge, neighbour set are DATA (plain float/int arrays = engine callback
      results). Provides: `link_cap_position` (R_L=(1−g)R_Q+g·R_H), `link_cap_ratio`,
      `link_qh_distance`, `link_force_share_q`/`_h` ((1−g):g linear-slave Jacobian shares),
      `link_project_force`, `link_force_net_added`, `link_charge_shift` (zero q_H → spread q_H/n onto
      n MM neighbours, Σq conserved), `link_total_charge`, `link_charge_residual`,
      `link_capped_energy` (R1 ONIOM specialised), `link_capped_minus_uncut`, `link_vext_after_shift`
      (R3 V_ext over the shifted charges).
- [x] `stdlib/qforge/system/link_atom_selftest.hexa` (@ci_gate) — 28 checks, analytic closed-form.
- [x] g5 VERBATIM (HEXA_MAC_BUILD_OK=1 hexa build … && run):
      ```
      PASS (setup) live Q—H distance = 1.5 (got 1.5)
      PASS (setup) cap ratio g = d_QL/d_QH = 1.09/1.5 (got 0.726667)
      PASS (d) cap x = R_Qx + g·ΔX (= 1 + 1.09) (got 2.09)
      PASS (d) cap y on axis (== R_Qy) (got 1.0)
      PASS (d) cap z on axis (== R_Qz) (got 1.0)
      PASS (d) colinear: cross_x == 0 (|got|=0.0)
      PASS (d) colinear: cross_y == 0 (|got|=0.0)
      PASS (d) colinear: cross_z == 0 (|got|=0.0)
      PASS (d) |R_L−R_Q| = g·|R_H−R_Q| = d_QL (got 1.09)
      PASS (a) net added force_x == F_Lx (no net force created) (got 0.7)
      PASS (a) net added force_y == F_Ly (got -1.3)
      PASS (a) net added force_z == F_Lz (got 2.4)
      PASS (a) Δ(F_Q+F_H)_x == F_Lx (conserved) (got 0.7)
      PASS (a) Δ(F_Q+F_H)_y == F_Ly (got -1.3)
      PASS (a) Δ(F_Q+F_H)_z == F_Lz (got 2.4)
      PASS (a) Q share_x == (1−g)·F_Lx (got 0.191333)
      PASS (a) H share_x == g·F_Lx (got 0.508667)
      Σq_before=0.68  Σq_after=0.68  |ΣΔq|=0.0
      PASS (c) |Σ Δq| < 1e-12 (charge conserved) (|got|=0.0)
      PASS (c) host charge zeroed after shift (|got|=0.0)
      PASS (c) nbr1 += q_H/3 (−0.1 + 0.2) (got 0.1)
      PASS (c) nbr2 += q_H/3 (−0.2 + 0.2) (got -2.77556e-17)
      PASS (c) nbr3 += q_H/3 (0.05 + 0.2) (got 0.25)
      PASS (c) non-neighbour untouched (got 0.33)
      PASS (c) V_ext(shifted charges) == round-3 embed_ee_vext_at (got 0.175)
      PASS (b) E_capped == E_uncut when QM≡MM (cap cancels) (got -42.7)
      PASS (b) |E_capped − E_uncut| < tol (QM≡MM limit) (|got|=0.0)
      (b) QM≠MM cap correction (E_QM-cap − E_MM-cap) = -1.2 (REAL, not forced to 0)
      PASS (b) QM≠MM residual = E_QM(cap)−E_MM(cap) = −1.2 (honest) (got -1.2)
      link_atom_selftest PASS
      ```
- FINDING: a covalent QM/MM boundary closes consistently. (a) The link atom is a linear slave
  R_L=(1−g)R_Q+g·R_H, so its force projects onto Q,H via the constant Jacobian (1−g):g and the NET
  added force == F_L EXACTLY — Newton's 3rd law survives the bond cut (no ghost force). (d) the H-cap
  sits ON the Q→H axis (cross-product=0) at |R_L−R_Q|=g·|R_H−R_Q|=d_QL. (c) charge-shift zeroes the
  host charge and spreads q_H/n onto its n MM neighbours with Σq invariant (|ΣΔq|=0), and those
  shifted charges feed straight into the round-3 V_ext (verified identical). (b) in the QM≡MM limit
  the ONIOM cap correction cancels and E_capped reproduces the uncut MM reference.

### honesty (d6 · @L5)

- capped==uncut holds ONLY in the QM≡MM boundary limit (E_QM(model+cap)==E_MM(model+cap)). For a
  GENERAL QM≠MM boundary the cap energy is a REAL physical correction, NOT zero — the gate pins the
  genuine residual E_QM(cap)−E_MM(cap)=−1.2 explicitly rather than forcing it to 0 (d6). The
  capped→uncut cancellation is the exact R1 ONIOM identity, not an approximation, in that limit.
- check (c) nbr2 prints −2.77556e-17 (float round-off of −0.2+0.2), within the 1e-12 tolerance — the
  real run output, not a cleaned number. No fabricated convergence; the link-atom geometry/force/
  charge algebra is exact, the cap-energy cancellation is exact in its stated limit.

### round-5 (next)

CG tier (MARTINI 3 ~4-heavy-atom:1-bead, families P/N/C/Q): a QM/MM/CG additive coupling reusing the
round-1 partition algebra (a third scale joins the additive sum). g5 = MM→CG coarse-graining
preserves the slow-DOF free energy / first two moments of the mapped coordinate in a toy (the CG bead
position = mass-weighted centroid of its 4 mapped atoms; the mapping operator is linear → reuse the
same linear-slave Jacobian pattern as the link atom for CG force back-mapping). Reuses R1 partition +
R4 linear-slave projection (CG mapping is the same constant-Jacobian back-mapping as the H-cap).

## 2026-06-13 — COMPLETION: real ab-initio QM/MM end-to-end (genuine RHF QM + electrostatic embedding)

The named system-scale completion. The QM region is now a GENUINE ab-initio molecule, not a model
energy: QFORGE-ATOMS/MOLSCF landed real closed-shell RHF (`qf_pd_*` build the McMurchie-Davidson
overlap/kinetic/nuclear/ERI integrals from atom positions + a contracted-Gaussian basis, and
`molscf/rhf::rhf_scf` drives the SCF fixed-point loop). `stdlib/qforge/system/qmmm_real.hexa` wires
that real RHF into the existing round-1 partition + round-3 electrostatic bridge.

System run (honest, d6): QM = a water molecule (STO-3G, 7 cart AOs, 5 doubly-occupied MOs) by the
real RHF; MM = point charge(s). The clean minimal end-to-end case.

g5 (VERBATIM run output):
- (b) REAL QM region — E_QM(real RHF) = −74.9618 Ha == the standalone MOLSCF anchor −74.961754. The
  QM subsystem is genuine ab-initio quantum mechanics, not a model energy.
- (a) ADDITIVITY IDENTITY — with the REAL RHF as E_high(inner), the additive ONIOM scheme reduces
  correctly to full-QM: |additive − ONIOM| = 0.0 (machine zero) on the round-1 partition algebra
  (reused verbatim). When MM≡QM on the region the partition collapses to the full energy.
- (c) ELECTROSTATIC EMBEDDING WITH REAL DENSITY RESPONSE (the key physics) — the MM point charge is
  appended to the QM hcore as an extra electron-attraction center (`qf_pd_hcore` sums
  Σ_c z_c·∫φ(−1/|r−R_c|)φ over every center; an MM charge q is a center with z=q, no new AO since the
  basis stays on the QM atoms), and the FULL SCF re-converges the density IN the MM field — a GENUINE
  polarized density, NOT the round-3 linear-response surrogate. Cation +1 @4bohr → shift −2.556 Ha
  (stabilizing, electrons drawn toward the +charge); anion −1 → +2.548 Ha (destabilizing); closer
  cation +1 @2bohr → −5.274 Ha (1/distance growth); cation/anion magnitude asymmetry = 0.0082 Ha,
  which is the nonlinear SCF density response (a linear-response E_pol=−½α|E|² would be EXACTLY
  symmetric — the asymmetry proves the density genuinely re-converged, not a model response).
- (d) ΣF = 0 — the real analytic RHF forces (Hellmann-Feynman + Pulay) on the QM region satisfy
  Newton's 3rd: ‖Σ_A F_A‖∞ = 3.9968e-15 (machine zero, translational invariance).
- regression — system r1-r8 selftests (qmmm · embed_mechanical · embed_electrostatic · embed_real_scf
  · link_atom · cg_martini{,_bonded,_ff}) 8/8 PASS unchanged.

WALL CLOSED (d6): round-8 (embed_real_scf) flagged `molecular_scf_frontend_available()==0` — QFORGE's
periodic plane-wave SCF could not treat an isolated MOLECULE. QFORGE-ATOMS/MOLSCF supplies the
molecular front-end, so this COMPLETION closes that cross-cutting wall for the system scale: the QM
region is a real water molecule by genuine RHF, with a real-density-response electrostatic embedding
(the round-3 next-step, now made real). d4-generic: qf_pd_* engine + qmmm.hexa algebra reused
verbatim; the MM charge set is data (longer array = more charges, no edit).

REUSE (d19 · NEXUS): E_QM ← stdlib/qforge/atoms/rhf_force_pd::qf_pd_{energy,run,force,enuc};
SCF loop ← stdlib/qforge/molscf/rhf::rhf_scf; ΣF ← qf_pd_transl_residual; ONIOM/additive ←
stdlib/qforge/system/qmmm. Vendored atoms/MOLSCF files (rhf_force_pd · molscf/rhf · molscf/md_integrals
· atoms/shell_grads) are read-only copies from origin/qforge-atoms-r29 (atoms is the canonical home).

### next
electrostatic embedding with a self-consistently RESPONDING MM region (mutual polarization /
polarizable MM, e.g. Drude/AMOEBA) — here the MM charges are FIXED external centers; the QM density
responds but the MM does not respond back. Mutual QM↔MM polarization is the next refinement.
