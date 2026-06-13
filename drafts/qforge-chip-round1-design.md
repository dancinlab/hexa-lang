# QFORGE — CHIP scale front-end · round-1 design

scope: QFORGE universal-engine **chip (device)** scale. milestone QFORGE.md §122 / line 141:
"밴드·수송·열 front-end (SCF 전자구조 재사용)". verify-adapter = 측정 / TCAD ref.
date: 2026-06-13 · 0-pod (analytic) round-1.

This is the device-physics extension of the same plane-wave-DFT + linear-response +
eigen core that DONE the materials scale (NEXUS c7, el-ph GATE CLOSED). The chip front-end
does NOT need a new solver — it needs (1) a Bloch-Hamiltonian band front-end that reuses
the SCF electronic structure, (2) a quantum-transport layer (Landauer → NEGF), and
(3) a phonon/electron thermal layer (Landauer/BTE). Each closes against a measurement or
TCAD reference.

## lit grounding (round-1, d18)

### band structure
- **Empirical / Slater-Koster tight-binding · LCAO**: bands from a small Bloch
  Hamiltonian H(k) (atomic-orbital basis). 1D nearest-neighbour: ε(k)=ε₀−2t·cos(ka),
  band ∈ [ε₀−2t, ε₀+2t], **bandwidth = 4t**; group velocity v_g=(1/ħ)dε/dk vanishes at
  band edges (van-Hove DOS divergence, effective mass m*=ħ²/(d²ε/dk²)). Multi-orbital /
  diatomic chains open a **gap** = the semiconductor vs metal distinction.
  (Narozniak TB notes; Shen 8.231 lec5; TU-Delft Open Solid State.)
- **Empirical pseudopotential method (EPM)** + plane-wave H(k): the SCF-fed route — the
  SAME plane-wave Hamiltonian QFORGE materials already builds (`scf_pw`, `projector`,
  `kinetic`, `vloc`) diagonalised on a k-mesh gives the band manifold. Empirical form
  factors or the converged SCF potential feed H(k).

### quantum transport — Landauer-Büttiker
- two-terminal conductance **G = (2e²/h)·Σₙ Tₙ**, G₀ = 2e²/h the conductance quantum.
  N perfectly-transmitting channels (Tₙ=1) ⇒ **G = N·G₀** — the quantized QPC staircase
  (van Wees). From a tight-binding device, Tₙ via the **Fisher-Lee relation** + lead
  Green's functions; coherent regime ⇒ NEGF: G = (2e²/h) Tr[ΓL G^r ΓR G^a].
  (Datta; arXiv:cond-mat/0103219 TB-transport; arXiv:0806.2739 block-tridiag.)

### thermal transport — phonon/electron Landauer + BTE
- ballistic heat current I_Q = (1/2π)∫dω ħω·T(ω)·[n_L−n_R]; linearised conductance
  κ = ∫(dω/2π) ħω·T(ω)·∂n/∂T. universal **thermal conductance quantum
  g₀ = π²k_B²T/(3h)** (≈ 9.46×10⁻¹³ W/K at 1 K, T-linear, carrier-statistics-independent)
  — the heat analogue of G₀ (Pendry bound; Schwab et al., Nature 404, 974 (2000)).
  Diffusive regime ⇒ phonon **BTE** / Landauer-with-mfp. (arXiv:0802.2761 Wang et al.;
  Nat. Commun. 2018 ballistic 1D waveguide.)

### NOVEL probe (round-1)
The **band↔transport bridge**: the number of Landauer conductance plateaus equals the
number of sub-bands the Fermi level cuts — so the SAME band kernel DRIVES the transport
channel count. round-1 encodes this as a verifiable identity (perfect-channel count = N
sub-bands ⇒ G=N·G₀); future rounds make it a live coupling (band machine → channel
enumerator → G(E_F) staircase). The thermal quantum g₀ seeds the '열' leg with its exact
closed-form reference even before the BTE solver lands.

## roadmap — 밴드 → 수송 → 열 (SCF-core reuse map)

| leg | front-end | core reuse (d19) | verify-adapter |
|-----|-----------|------------------|----------------|
| **밴드** | H(k) Bloch / EPM band manifold on a k-mesh | `scf_pw` · `projector` · `kinetic` · `vloc` (SCF potential) → `davidson`/`eigen.eigh` diag · `mpgrid`/`kmesh_elph` k-mesh | band gaps / effective mass vs experiment · TCAD band ref |
| **수송** | Landauer G=G₀ΣTₙ → Fisher-Lee → NEGF G^r=(E−H−Σ)⁻¹ | band H(k) above · `eigen` (lead modes) · `signal/fft3` (if k-space leads) | conductance plateaus / I-V vs measured QPC · TCAD |
| **열** | phonon Landauer / BTE; g₀=π²k_B²T/3h floor | DFPT phonon ω(q) (`dfpt`·`realcell_phonon`) reused as phonon transmission input · `eigen` | κ vs measured ballistic/diffusive · TCAD thermal |

ordering rationale: bands are the prerequisite for both transport (H feeds G^r) and
thermal-electronic (band v_g, DOS). 수송 before 열 because the Landauer machinery is shared
(electron G first, then the phonon-Landauer twin reuses the same transmission integrator).

## round-1 deliverable (this brick)
`stdlib/qforge/chip/band_transport.hexa` + selftest — the analytic SPINE:
TB band (bandwidth/v_g), diatomic gap (generic eigh), Landauer G₀ quantization,
thermal quantum g₀. **g5 PASS 22/22**, all exact closed forms (d6). This is the anchor
a later SCF-fed / NEGF band-transport machine must reproduce in its analytic limit.

## round-2 (next)
1. **k-mesh band sweep brick** — fold the 1D TB into a generic H(k) eval over a Monkhorst-
   Pack mesh (reuse `mpgrid`), emit ε_n(k) band manifold; anchor = analytic TB on a path
   Γ→X, DOS van-Hove peaks. (band leg, still 0-pod.)
2. **2-terminal NEGF transmission brick** — T(E)=Tr[ΓL G^r ΓR G^a] for a 1D TB chain with
   semi-infinite leads (analytic lead self-energy Σ(E)); anchor = G(E) quantized to N·G₀
   on the perfect chain, and the Fisher-Lee ↔ mode-count identity (the NOVEL bridge made
   live). (수송 leg, 0-pod.)
3. **SCF-fed band hook** — wire the band front-end to the converged `scf_pw` potential so
   H(k) comes from QFORGE's own electronic structure (the milestone's '재사용'); xval vs a
   small real cell. (may need 1 small pool/pod SCF — size first, d11.)
4. **phonon-Landauer κ brick** — reuse DFPT ω(q) as the phonon transmission; anchor =
   ballistic κ → N·g₀ floor at low T. (열 leg.)
5. file the round-2 results + flip QFORGE.md line-141 sub-progress; **upstream**: chase the
   gen3 arena-return bug (handoff aededed6) so the scalar-materialization workaround can be
   dropped.

## honest scope (d6 / @L5)
round-1 = lit grounding + design + ONE g5-verifiable analytic brick (band correctness +
transport quantization + thermal quantum). Full TCAD device simulation (self-consistent
Poisson-Schrödinger, drift-diffusion, real NEGF with scattering, 3D thermal FEM) is a
LARGE multi-round build — NOT claimed here. The brick's values are exact analytic
references, not a device-scale simulation result.
