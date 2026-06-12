@title: 🌉⚛ QFORGE-SYSTEM — multi-scale bridge (QM/MM·CG 스케일 결합 드라이버)

@goal: Join the scales QFORGE verifies in isolation — QM (`stdlib/qforge/` SCF·DFPT·el-ph) and MM
(`stdlib/chem/md/` lennard_jones·bonded·ewald·pme) — into ONE multi-scale energy + force driver,
each scale-bridge verified by lower-scale consistency (a QM/MM partition of a purely-MM system
reproduces the bare MM energy; embedding adds only the polarization it should). d4-generic: QM/MM
engines are callbacks (energies = plain floats), never hardcoded into the partition layer.

## method

The bridge is built bottom-up, one verified brick per scale-junction, reusing the QM and MM cores
hexa already ships (d19) — never rebuilding a sibling's verified primitive. The partition algebra
(this round-1 brick) is the foundation every later embedding rests on: additive QM/MM and ONIOM
subtractive schemes must give the SAME total on shared inputs (they do — algebraically), and a
QM/MM partition of a purely-MM system must reproduce the bare MM energy. Each round then adds one
physical coupling (mechanical → electrostatic → covalent boundary → CG tier), each gated by a
`hexa build … selftest && run` g5 numerical-identity check (no LLM judge).

## milestones

- [x] round-1 — QM/MM energy-partition algebra (additive ↔ ONIOM consistency identity + toy limits).
      `stdlib/qforge/system/qmmm.hexa` + `qmmm_selftest.hexa`. g5 10/10 PASS — additive==ONIOM
      residual = 0 (machine zero) over 3 arbitrary input sets; MM-only limit → E_low(real);
      partition-boundary invariance; mechanical-coupling sanity. d4-generic (energies = callbacks).
- [ ] round-2 — mechanical embedding, real cores: E_QM = qforge `scf_etot`, E_MM = chem/md
      `total_energy`, coupling = classical LJ+Coulomb (`ewald`/`pme`) between regions. g5 = 2-fragment
      toy where the QM frag is also MM-parameterized matches a hand additive sum.
- [x] round-3 — electrostatic embedding: MM point charges fold into the QM 1-electron Hamiltonian
      as V_ext(r)=Σ q_MM/|r−R_MM| → QM density polarizes. `stdlib/qforge/system/embed_electrostatic.hexa`
      + selftest. g5 18/18 PASS — (a) induced dipole μ=αE ALONG the field (sign exact); (b) EE−ME =
      e_pol = −½α|E|² < 0 (negative + order exact, Δ<1e-12); (c) field→0 ⇒ EE==ME; (d) charge-sign
      flip ⇒ dipole reverses (vector), e_pol invariant (quadratic). d4-generic (V_ext = MM-charge
      callback). HONEST (d6·@L5): real `qforge_assemble_h` V_ext SCF hook exists; full PW SCF on the
      toy not run (round-2 convention) — sign+order via exact O(E²) linear response (static α·E),
      MM field = real Coulomb sum. Full SCF polarization + hyperpolarizability = round-3+ refinement.
- [x] round-4 — covalent boundary / link atom: H-cap a cut bond + host-charge redistribution.
      `stdlib/qforge/system/link_atom.hexa` + selftest. g5 28/28 PASS — (a) force projection
      conserves total force (net added == F_L exactly, Newton 3rd across the cut; share split
      (1−g):g = the linear-slave Jacobian); (b) capped→uncut: E_capped == E_uncut when QM≡MM (ONIOM
      cap cancels), QM≠MM residual = E_QM(cap)−E_MM(cap) = −1.2 reported honestly (not forced 0, d6);
      (c) charge-shift conserves Σq (|ΣΔq|=0, host zeroed, q_H/n spread to n MM neighbours); (d) H-cap
      on the Q→H axis (cross-product=0 colinear, |R_L−R_Q|=g·|R_H−R_Q|=d_QL). d4-generic (g, host
      charge, neighbour set = data). REUSE (d19): shifted charges feed straight into round-3 V_ext
      (`embed_ee_vext_at`) — verified identical in-gate.
- [ ] round-5 — CG tier (MARTINI-style ~4:1 mapping): QM/MM/CG additive coupling reusing the same
      partition algebra. g5 = MM→CG coarse-graining preserves the slow-DOF free energy in a toy.

## core reuse (d19)

| bridge term           | hexa core reused (not rebuilt)                          |
|-----------------------|---------------------------------------------------------|
| E_QM(inner)           | `stdlib/qforge/scf` · `scf_etot`                        |
| E_MM(outer)           | `stdlib/chem/md/lennard_jones` · `bonded`               |
| E_QM-MM electrostatic | `stdlib/chem/md/ewald` · `pme`                          |
| V_ext (QM 1-e hook)   | `stdlib/qforge/assembler` `qforge_assemble_h` (SCF hook) |
| polarization (EE−ME)  | **`stdlib/qforge/system/embed_electrostatic`** (round-3) |
| link atom (H-cap)     | **`stdlib/qforge/system/link_atom`** (round-4)           |
| forces (all scales)   | `stdlib/chem/md/forces_autograd` · qforge HF forces     |
| partition algebra     | **`stdlib/qforge/system/qmmm`** (round-1 brick)         |

NEXUS edge: `QFORGE/system reuses qforge/{scf,scf_etot} + chem/md/{lennard_jones,bonded,ewald,pme}`.

## scope / honesty (d6 · @L5)

Round-1 = lit grounding + bridge design + the FIRST g5-verifiable brick (the partition-consistency
identity). The full multi-scale coupling (real SCF↔MM electrostatic embedding, link atoms, CG) is a
large multi-round build — rounds 2-5 are OPEN, not done. The partition algebra is engine-agnostic
(toy energies stand in for any callback), so the identity is proven for ALL inputs; what is NOT yet
wired is the real qforge-SCF/chem-md coupling (round-2+). No fabricated coupling results.
