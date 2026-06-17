# QFORGE UNIFIED dense off-diag V_scr(G_a−G_b) el-ph vertex assembler — VERDICT

**date**: 2026-06-12 · **cost**: $0 (0-pod, mini local-CPU; summer GPU BUSY @89% fep → mini fallback)
**branch**: `qforge-offdiag-assembler` (worktree `/private/tmp/wt-offdiag`)
**modules**: `stdlib/qforge/elph_offdiag_integrated.hexa` (+ selftest) · fixture
  `stdlib/qforge/fixtures/cah6_realcell_offdiag_integrated_xval.hexa`

## THE 大작업 (migration-gate ARCHITECTURAL residual)
Three prior rounds each built a piece of the off-diagonal el-ph vertex on a DIFFERENT route,
and the routes DISAGREED by ~10 orders on the SAME Γ-only CaH6 cell:
  • COMPOSE route (compose_cah6 → qforge_realcell_g_offdiag): g_mn = Σ_G ψ_m(G)·(ΔV_scr·ψ_n)(G)
    → **λ=1.1545** (rel-ε 0.736). PHYSICAL ORDER.
  • CUBE route (elph_vscr_realspace): g_mn = ∫ψ*_m(r)·∂V_scr(r)·ψ_n(r) dr → λ=9.26e-10,
    ~9.5 orders BELOW compose.
The gate's architectural residual = "no single consistent dense off-diag V_scr(G_a−G_b) path."

## DIAGNOSIS (task item 1 — why compose=1.15 but direct off-diag not-sufficient)
The ~10-order gap is **NOT physics — it is a NORMALIZATION+PHASE convention mismatch**:
  1. **PW-norm**: ψ(r)=ifft3(ψ(G)) carries a 1/Ntot, so the raw cube overlap is too small by
     (√Ω/Ntot)² per pair (~22 orders on Σ|g|²). The normalization round hand-patched ×Ntot/√Ω.
  2. **Bra conjugation** (the residual the prior round MISSED): the canonical element is
     g_mn = ⟨ψ_m|ΔV|ψ_n⟩ = (1/N)Σ_j ψ_m*(r_j)·ΔV(r_j)·ψ_n(r_j) — the BRA ψ_m*(r)=Σ_G c_m(G)e^{−iG r}
     carries the −iG phase. The cube route took Re(ifft) for ALL THREE factors, dropping the bra
     conjugate, which for OFF-DIAGONAL Γ elements is NOT zero. THAT (on top of PW-norm) is the
     true cube deficit. The compose route avoids both because it works in G-space (Σ|ψ(G)|²=1,
     no Ω/Ntot, no real-space phase loss).

## THE UNIFICATION (THEOREM, not a fit — d6)
`elph_offdiag_integrated.hexa` exposes ONE canonical operator g_mn = Σ_{G_a,G_b} ψ*_m(G_a)·
ΔV_scr(G_a−G_b)·ψ_n(G_b) with THREE equivalent evaluations:
  (A) DENSE  — explicit Σ_{G_a,G_b} double sum over the ΔV(ΔG) convolution matrix (the DEFINITION).
  (B) APPLY  — g_mn = Σ_G ψ_m(G)·w_n(G), w_n=ΔV·ψ_n the applied column (= the COMPOSE route).
  (C) CUBE   — g_mn = (1/N)Σ_j ψ_m*(r_j)·ΔV(r_j)·ψ_n(r_j) with the FULL complex ψ_m* (−iG bra)
               + PW normalization. By Parseval C = A = B.

## g5 GATE (synthetic exact PW system — A==B==C to machine precision)
`qforge_elph_offdiag_integrated_selftest` — **PASS (all checks)** VERBATIM:
  (A) const ΔV: g00_dense==V̄ (0.7) · g01_dense==0 (orthonormal off-diag) · dense==diag on diagonal
  (B) route A (dense) == route B (apply=compose)         got −0.082 (machine-eq)
  (C) route A == route C (cube, FULL complex ψ_m*)        got −0.082 (eq to 1e-12)
  (C) route C imaginary part ≈ 0 (real at Γ)              got 5.55e-17
  (D) off-diag lifts Σ|g|² (lift = 1.23803 > 1)
  (E) Hermitian vertex (herm_residual = 0.0)
  (F) dense λ finite + positive + monotone (3955.64 → 5176.62 on ×2 off-diag)
  (G) route-B columns path == dense-matrix path END-TO-END  λ_cols==λ_dense=3955.64 (≤1e-9)
      + diagonal floor (3616.37) ≤ full (3955.64)

## CaH6 REAL-CELL MEASUREMENT (VERBATIM — d6, NOT tuned, mini CPU 0-pod)
`cah6_realcell_offdiag_integrated_xval.hexa` — NPW=64 converged SCF (21 iters, etot=2.74425),
Anderson-screened ΔV_scr converged (max_res 9.4e-9), real 24-mode ω band (ω_log=1156 K),
real N(E_F)=19.95, nactive=10 (n_pairs=100):

| quantity                                          | VERBATIM value |
|---------------------------------------------------|----------------|
| **λ_unified** (qforge_lambda_dense, route-B cols) | **1.1545**     |
| **λ_compose** (established compose vertex)        | **1.1545**     |
| **route A=B residual** \|λ_uni−λ_comp\|/λ_comp    | **3.30e-7**    |
| λ_diag-floor (OLD diagonal-only assembler)        | 1.08916        |
| Σ\|g\|²_dense/Σ\|g\|²_diag lift                   | 1.67608        |
| Hermiticity residual Σ\|g_mn−g_nm\|               | 1.39e-15       |
| diagonal→dense λ lift (real CaH6)                 | 1.08916 → 1.1545 (off-diag RAISES) |
| **rel-ε vs QE 4.376**                             | **0.736175**   |

## VERDICT — outcome (2)+(3): ARCHITECTURE CLOSED, MAGNITUDE RESIDUAL (d6 / @L5 HONEST)
- **Architectural residual CLOSED.** The A==B==C unification is a normalization+phase THEOREM
  (g5 machine-precision). On the REAL CaH6 cell λ_unified == λ_compose to **3.3e-7** — the
  off-diag assembler IS the compose vertex. There is now ONE consistent dense off-diag
  V_scr(G_a−G_b) path; the ~10-order route disagreement is explained (PW-norm + bra-conjugate)
  and eliminated.
- **Magnitude residual PERSISTS (NOT the assembler).** Unifying the architecture did NOT move λ
  to 4.376 — it stays at **1.1545** (rel-ε 0.736). The diagonal→dense lift is only ×1.06
  (Σ|g|² ×1.68), i.e. the off-diagonal vertex STRUCTURE is small; the 3.8× gap to QE is the
  **vertex MAGNITUDE / Γ-only FS BZ residual**, NOT the architecture. This is consistent with
  the prior from-scratch screened-vertex WALL (f_xc-in-χ ALDA = FINAL DFT lever, CLOSED-NEGATIVE)
  and the hybrid (rel-ε 1.65e-7) being the QE-grade production path. **gate HELD** (hybrid =
  production), dispatch qforge NOT flipped from this work.
- **NO 4.376 forced** (d6). λ reported verbatim. Cost = $0.

## summer GPU (task item 3)
summer RTX 5070 BUSY @89% util (python / fep campaign live — memory `summer-free-gpu-fep`).
Per the 0-pod spec, fell back to mini local-CPU. The GPU step is moot for THIS finding: the
unified path closed the architectural residual at nactive=10 on mini CPU, and route A=B is
EXACT (3.3e-7) independent of mesh — n=645 k×q GPU convergence would only probe the *magnitude*
residual, which the measurement already proves is NOT the assembler. No paid pod (d17 n/a here).

## NEXT (the remaining magnitude gap — already named, d2)
The 3.8× QE gap is the vertex-magnitude / Γ-only FS BZ axis, GPU-gated n=645 k×q convergence
(NON-MONOTONIC in basis/mesh per `.verdicts/qforge-converged-kxq-gpu/`). Production path =
hybrid (QE el-ph + QFORGE post-gate accel), per the standing migration-gate decision.
