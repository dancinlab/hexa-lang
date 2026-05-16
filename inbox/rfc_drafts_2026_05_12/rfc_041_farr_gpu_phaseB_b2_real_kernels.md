# RFC 041 — real CUDA kernels for the RFC 040 Phase B / B2 `farr` ops

- **Status**: design-draft (2026-05-16) — DESIGN ONLY, no implementation
- **Date**: 2026-05-16
- **Severity**: MEDIUM-HIGH (the Phase B/B2 ops are the only farr-GPU
  ops still CPU-fallback-only; without real kernels every backward
  weight-grad / elementwise / row-reduction op runs on the CPU even on
  a GPU box — the campaign worked around this for *matmul-reshapeable*
  ops but not for the genuinely-elementwise / reduction ones)
- **Priority**: P2 (follows RFC 040 Phase A — `farr_matmul_gpu` cuBLAS
  Dgemm — which is the ONE real kernel that exists today; RFC 041
  completes the Phase B/B2 op family)
- **Source convergence**: anima RFC 040 Phase D/E/E2 GPU campaign
  (2026-05-16). The Phase E2 backward+fat-host fire surfaced this as a
  *measured* hexa-lang upstream need, not a speculative one.
- **Source evidence (g3 — every claim below traces to a real capture)**:
  - anima `docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md`
    §2.1 + §5 C3-3, and `state/hexad_gpu_fire_phaseE2_2026_05_16/
    result.json` `backward_refactor.b2_op_finding` —
    *"hexa-lang `017b988f` B2 ops (`farr_matmul_t_gpu` /
    `farr_outer_gpu` / …) have `TODO[cuda] return -1` HEXA_CUDA stubs
    (NO CUDA kernel — verified reading `self/runtime.c` §11145-11176).
    Routed backward through the ONE real CUDA kernel
    (`farr_matmul_gpu` / cuBLAS Dgemm) via exact GEMM reshapes
    instead — strictly stronger than -1-hard-fail stubs."*
  - anima `docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md` §2.2 —
    the measured cuBLAS Dgemm `TOL_MATMUL ≈ 2e-9` calibration (the fp
    non-associativity caveat this RFC must carry forward).
  - hexa-lang `self/runtime.c` (read directly, `017b988f`): the Phase
    B stubs at §10778-10852 (`farr_softmax_rows_gpu`,
    `farr_rmsnorm_rows_gpu`, `farr_add_gpu`, `farr_scale_gpu`) and the
    Phase B2 stubs at §10859-11176+ (`farr_matmul_t_gpu`,
    `farr_outer_gpu`, `farr_mul_gpu`, `farr_silu_gpu`,
    `farr_silu_grad_gpu`, `farr_rmsnorm_bwd_rows_gpu`,
    `farr_adamw_step_gpu`) — each a `#ifdef HEXA_CUDA → TODO[cuda]
    return -1` body, confirming the campaign finding.

## Scope of this RFC — DESIGN DRAFT, honest framing

This is a **design document only**. It specifies the real CUDA kernels
for the RFC 040 Phase B + Phase B2 `farr` op family; it lands **zero
CUDA code**, does not modify `self/runtime.c` or
`self/cuda/runtime_cuda.c`, and builds nothing. Implementation is a
separate CUDA-box cycle gated on this design's acceptance.

It is the natural Phase B/B2 follow-on to RFC 040 (which scoped
`farr_matmul_gpu` as Phase A and named the rest as Phase B). RFC 041
exists because the anima GPU campaign **measured exactly which ops do
and do not have a real kernel today** — a fact that should drive the
implementation, not an assumption.

## Problem — the honest op-availability finding

RFC 040 §"Hot-path op survey" enumerated the `farr` GPU op family and
phased it: Phase A = `farr_matmul`, Phase B = the rest. The anima
campaign implemented + dispatched the GPU path on real hardware (H100
Phase D, H200 Phase E, A100-SXM4 fat-host Phase E2) and, in the course
of routing the *backward* pass, **read `self/runtime.c` directly** to
check op availability. The finding (g3, verified — not a guess):

> Of the RFC 040 farr-GPU op family, **only `farr_matmul_gpu` has a
> real cuBLAS Dgemm kernel** (`self/cuda/runtime_cuda.c`
> `_hx_cuda_farr_matmul_gpu`, the Phase D/E forward path: 51 TFLOPS
> FP64, max|Δ|=4.44e-15 vs CPU). **Every Phase B and Phase B2 op is a
> `#ifdef HEXA_CUDA → TODO[cuda] return -1` stub** (CPU fallback
> only; hard-fail under `-DHEXA_CUDA`).

The Phase B/B2 ops with no real kernel today (verified in
`self/runtime.c` `017b988f`):

| op | runtime.c stub | math contract (CPU oracle exists) |
|---|---|---|
| `farr_matmul_t_gpu` | §11145 `TODO[cuda]` ret -1 | `Mᵀ·u` (c3_matvec_t — dX / dr / dzT vjp) |
| `farr_outer_gpu` | §11162 `TODO[cuda]` ret -1 | `u⊗v` (c3_outer — dW / dWg / dWh grad) |
| `farr_mul_gpu` | §11178 `TODO[cuda]` ret -1 | `A⊙B` elementwise |
| `farr_silu_gpu` | §10859+ `TODO[cuda]` ret -1 | `silu(x)=x·σ(x)` |
| `farr_silu_grad_gpu` | §10859+ `TODO[cuda]` ret -1 | `σ(x)·(1+x·(1−σ(x)))` |
| `farr_softmax_rows_gpu` | §10781 `TODO[cuda]` ret -1 | row-wise numerically-stable softmax |
| `farr_rmsnorm_rows_gpu` | §10799 `TODO[cuda]` ret -1 | row RMSNorm `mean(x²)+eps` |
| `farr_rmsnorm_bwd_rows_gpu` | §10859+ `TODO[cuda]` ret -1 | exact RMSNorm vjp dy→dx |
| `farr_add_gpu` | §10817 `TODO[cuda]` ret -1 | `C = A + B` elementwise |
| `farr_scale_gpu` | §10832 `TODO[cuda]` ret -1 | `Y = α·X` elementwise |
| `farr_adamw_step_gpu` | §10875+ `TODO[cuda]` ret -1 | decoupled-wd AdamW in-place |

How the campaign worked around this (context, not a substitute for
RFC 041): for the *GEMM-reshapeable* backward ops the campaign proved
two exact reshape equivalences and routed them through the ONE real
kernel (`farr_matmul_gpu`) instead of the -1-hard-fail stubs —

| boxed op | proven GEMM reshape | reduction order |
|---|---|---|
| `c3_outer(u,v,R,C)` = u⊗v | `farr_matmul_gpu(u, R, 1, v, C)` → [R·C] | single term `u[r]·v[c]` — BIT-identical |
| `c3_matvec_t(M,u,R,C)` = Mᵀ·u | `farr_matmul_gpu(u, 1, R, M, C)` → [1·C] | `Σ_{k=0..R-1} u[k]·M[k·C+c]` — SAME order as the CPU helper |

(Evidence: Phase E2 doc §2.1 table; `result.json`
`backward_refactor.helpers_added`. The d=384·6L GRAD-EXACT PASS on the
real A100 — `analytic=-0.00311269 fd=-0.000706787 |Δ|=0.0024059` — is
the on-hardware proof these reshapes are numerically exact.)

That reshape trick is strictly stronger than the -1 stubs **but only
covers the matmul-shaped ops** (`farr_matmul_t_gpu`, `farr_outer_gpu`).
The genuinely-elementwise / row-reduction ops (`farr_mul_gpu`,
`farr_silu_gpu`, `farr_silu_grad_gpu`, `farr_softmax_rows_gpu`,
`farr_rmsnorm_rows_gpu`, `farr_rmsnorm_bwd_rows_gpu`, `farr_add_gpu`,
`farr_scale_gpu`, `farr_adamw_step_gpu`) have **no GEMM reshape** and
remain CPU-only — and the Phase E2 honest C3-2 / C3-4 named these
exact elementwise cores as the part that stays boxed. RFC 041 closes
that gap with real kernels.

## Proposal

Implement the Phase B + B2 op kernels in `self/cuda/runtime_cuda.c`
(the same CUDA TU that already holds `_hx_cuda_farr_matmul_gpu`),
filling the existing `extern int _hx_cuda_farr_*` forward decls already
present in `self/runtime.c` (§10647-10657, §10887-10901). No new
surface — the builtins, ABI, and `-1`-on-no-CUDA fallback already exist
(RFC 040 scaffolding); RFC 041 only supplies the missing kernel bodies.

### 1. GEMM-reshape ops via cuBLAS (the proven path, generalized)

`farr_matmul_t_gpu` and `farr_outer_gpu` should reuse the ONE
numerically-verified cuBLAS Dgemm kernel via the exact reshapes the
campaign already proved on real hardware:

- `farr_outer_gpu(u, v, R, C)` ≡ `cublasDgemm` of `u`[R·1] · `v`[1·C]
  → [R·C]. Single product term `u[r]·v[c]` — **no reduction**, hence
  bit-exact (no fp non-associativity).
- `farr_matmul_t_gpu(M, R, C, u)` ≡ `cublasDgemm` of `u`[1·R] ·
  `M`[R·C] → [1·C]. Reduction `Σ_{k} u[k]·M[k·C+c]` — same K-loop the
  CPU `c3_matvec_t` does; fp non-associativity applies (see Honest
  caveats — carry RFC 040 §"Honest caveats" `TOL_MATMUL`).

Documenting these reshape equivalences *in the kernel* (rather than
forcing every caller to reshape, as the campaign did at the call site)
is the design point: the equivalence is proven, so the kernel can
encapsulate it. cuBLAS Dgemm is already the one verified GPU path
(Phase D 51 TFLOPS FP64, max|Δ|=4.44e-15; Phase E2 GPU smoke 5/5 on
A100) — these two ops inherit that verification by construction.

### 2. Custom `__global__` kernels for the elementwise / reduction ops

The remaining ops have no GEMM reshape and need custom kernels (RFC
040 §3 "elementwise / reduction — custom `__global__` kernels" named
this; RFC 041 specifies them concretely):

- **`farr_mul_gpu` / `farr_add_gpu` / `farr_scale_gpu`** — 1-D
  grid-stride elementwise kernels. **No reduction → bit-exact**
  (`TOL_ELEM` essentially 0; the falsifier demands exactness here).
- **`farr_silu_gpu`** = `x·σ(x)`, **`farr_silu_grad_gpu`** =
  `σ(x)·(1+x·(1−σ(x)))` — 1-D grid-stride, per-element transcendental
  (`expf`/`exp` — f64 to match the packed-double farr contract).
  Essentially elementwise; tolerance is the f64 `exp` ULP, not a
  reduction order — `TOL_ELEM`.
- **`farr_softmax_rows_gpu`** — block-per-row, warp-shuffle
  (`__shfl_down_sync`) max-then-sum reduction, numerically stable
  (subtract row max). Reduction order differs from the CPU scalar loop
  → `TOL_ELEM` (small; one row-length reduction, not a deep K).
- **`farr_rmsnorm_rows_gpu`** — block-per-row sum-of-squares reduction
  + `rsqrt`. Same reduction-tolerance framing.
- **`farr_rmsnorm_bwd_rows_gpu`** — the exact RMSNorm vjp dy→dx
  (`self/runtime.c` §10870-10872 documents it as the
  c3_rmsnorm_bwd-equivalent). Two row reductions (Σdy·x̂, Σdy);
  block-per-row. `TOL_ELEM`.
- **`farr_adamw_step_gpu`** — single fused 1-D kernel updating
  `param`, `m`, `v` in place (decoupled weight decay, the
  `dt2_adamw_step` contract). No cross-element reduction → bit-exact
  per element given identical `m`/`v`/`grad` inputs (`TOL_ELEM` ≈ 0;
  only the `sqrt`/`/` ULP).

All reductions use a fixed block size + tree/warp-shuffle (no
order-dependent atomics) so they are run-to-run deterministic — the
RFC 040 F-GPU-040-DETERMINISM contract extends to every RFC 041
kernel.

### 3. Acceptance — equivalence to the existing CPU helpers

Every RFC 041 kernel must be **byte-equal (where the math has no
reduction) or within a measured fp tolerance (where it does)** to its
CPU helper — the same `g_blue_closed_mandate` connection-point contract
RFC 040 §"Verification" established.

The reference oracles already exist and are verified — **do not invent
acceptance numbers**:

- The B2 agent's `tmp_rfc040_phaseB2_smoke.hexa` reportedly ran **9/9
  CPU oracles** for these exact ops (the CPU bodies behind the
  `#ifndef HEXA_CUDA` branch of each builtin). Those CPU helpers are
  the reference; each kernel is checked against its own CPU helper on
  identical packed-double farr inputs.
- The campaign's Mac CPU-equivalence gate
  (`state/hexad_gpu_fire_phaseE2_2026_05_16/cpu_equiv_e2.log`) proves
  the full d_train5 step using these op contracts is bit-equal to the
  boxed baseline (`gn2 7.97116 → 3.73374e-07, acc 0/8 → 8/8`,
  *exactly* equal). That is the end-to-end reference the
  RFC-040-style F-GPU-040-STEP-EQ falsifier should reproduce once
  these kernels are real.

### Falsifier battery (F-RFC041-*) — reuse the RFC 040 harness

Each falsifier runs the **compiled-native** path (matches anima
`HEXAD/build_verify.sh`) and compares the kernel against its RFC 032/
033/034-family CPU helper on the *same* farr inputs:

- **F-RFC041-MATMUL-T-EQ** — `farr_matmul_t_gpu` vs the CPU
  `c3_matvec_t`/`farr_matmul`-reshape oracle: max `|Δ| < TOL_MATMUL`
  (carry RFC 040's measured ≈2e-9; reduction op).
- **F-RFC041-OUTER-EXACT** — `farr_outer_gpu` vs CPU `c3_outer`:
  **max `|Δ| = 0`** (no reduction → bit-exact, the falsifier demands
  exactness).
- **F-RFC041-MUL-EXACT / -ADD-EXACT / -SCALE-EXACT** — elementwise,
  **`|Δ| = 0`** exact.
- **F-RFC041-SILU-EQ / -SILU-GRAD-EQ** — vs CPU helper: max
  `|Δ| < TOL_ELEM` (f64 `exp` ULP).
- **F-RFC041-SOFTMAX-ROWS-EQ / -RMSNORM-ROWS-EQ /
  -RMSNORM-BWD-ROWS-EQ** — vs CPU helper: max `|Δ| < TOL_ELEM`
  (single row-length reduction).
- **F-RFC041-ADAMW-EQ** — one `farr_adamw_step_gpu` vs CPU
  `dt2_adamw_step` on identical `param`/`grad`/`m`/`v`: post-update
  max `|Δ| < TOL_ELEM`.
- **F-RFC041-DETERMINISM** — every kernel run twice: byte-identical
  (`|Δ| = 0`).
- **F-RFC041-NO-CUDA-FALLBACK** — on a no-CUDA build every op still
  returns its CPU result (no regression to the existing
  RFC-040-scaffold `-1` behaviour on no-GPU hosts; the Mac dev box
  must remain byte-identical to today).
- **F-RFC041-STEP-EQ** — one full d_train5 step (fwd+CE+bwd+AdamW)
  with ALL Phase B/B2 ops GPU-routed vs the CPU oracle: reproduce the
  campaign's bit-equal descent (`7.97116 → 3.73374e-07`) within
  `TOL_STEP` (carry RFC 040's measurement-calibrated ≤1e-6; the
  campaign's exact-equal CPU gate is the strict reference).

(≥3 per AGENTS.tape directive; this RFC specifies 14. The `*-EQ` /
`*-EXACT` falsifiers are the `g_blue_closed_mandate` connection-point
checks — mandatory, may not be replaced by a "the kernel ran" check.)

## Honest caveats (AGENTS.tape g3 / f2 — no over-claim)

- **Only `farr_matmul_gpu` has a real kernel today.** This RFC states
  that plainly; it is the verified-by-reading-`runtime.c` finding from
  the anima campaign (Phase E2 §2.1 / C3-3, `result.json`
  `b2_op_finding`), not an assumption. RFC 041 does not claim the
  Phase B/B2 ops are "almost done" — they are `-1` stubs and this RFC
  is their design.
- **fp non-associativity carries forward (RFC 040 §"Honest
  caveats").** The reduction ops (`farr_matmul_t_gpu`,
  `farr_softmax_rows_gpu`, `farr_rmsnorm_rows_gpu`,
  `farr_rmsnorm_bwd_rows_gpu`) are within a *measured* tolerance, not
  bit-equal. The campaign already measured cuBLAS Dgemm at
  `TOL_MATMUL ≈ 2e-9` relative on H100
  (`anima_rfc040_phase_d_h100_cublas_2026_05_16.md` §2.2 — 6/7 shapes
  <1e-9, the 768×768×3072 reduction-heavy shape 1.905e-9). RFC 041
  carries that bound forward and mandates the implementing cycle
  *re-measure and confirm-or-widen, never assert by hope* — exactly
  RFC 040's rule. The non-reduction ops (`farr_outer_gpu`,
  `farr_mul_gpu`, `farr_add_gpu`, `farr_scale_gpu`) **are** bit-exact
  and the falsifiers demand `|Δ| = 0`.
- **Don't invent acceptance numbers.** The acceptance references are
  the *existing verified oracles*: the B2 agent's 9/9 CPU-oracle
  smoke and the campaign's exact-equal Mac CPU-equiv gate
  (`cpu_equiv_e2.log`, `7.97116 → 3.73374e-07`). RFC 041 reuses those;
  it does not fabricate a new target metric.
- **CUDA-box cycle.** Implementation can only be built + falsifier-
  verified on a CUDA host (the Mac dev box has no `nvcc`/cuBLAS). This
  is a real-kernel implementation cycle, not a small patch — the
  RFC-040-scaffold provides the ABI/forward-decls; RFC 041 supplies
  ~11 kernel bodies + the equivalence harness on a GPU box.
- **No lattice-tautology (f2).** The real-limit verification anchor is
  *numerical equivalence to a bit-exact CPU reference computation* +
  the CE Shannon-entropy floor preserved by F-RFC041-STEP-EQ — real
  math, not `σ·φ=24`.

## Non-goals (this RFC)

- No CUDA code, no `runtime.c` / `runtime_cuda.c` edit, no build —
  design draft only.
- No new builtins / surface — the ABI + forward-decls already exist
  from the RFC 040 scaffold; RFC 041 fills the existing `-1` stubs.
- No hand-written competitive GEMM — `farr_matmul_t_gpu` /
  `farr_outer_gpu` reuse the verified cuBLAS Dgemm via the proven
  reshapes.
- No change to any RFC 032/033/034 CPU helper — those stay the
  bit-exact oracles.

## Cross-RFC dependency

- **RFC 040** (`farr` GPU/CUDA backend) — RFC 041 is its Phase B/B2
  op completion. RFC 040 Phase A (`farr_matmul_gpu`) is the ONE real
  kernel RFC 041 builds the GEMM-reshape ops on; RFC 040
  §"Verification" / §"Honest caveats" define the harness + tolerance
  framing RFC 041 reuses verbatim.
- **RFC 032** (`farr_matmul`) — the cuBLAS Dgemm path
  `farr_outer_gpu` / `farr_matmul_t_gpu` reshape onto.
- **RFC 034** (`farr` reverse-mode autograd) — the silu/silu_grad/
  rmsnorm-bwd/AdamW op contracts these kernels must match.
- **RFC 035** (bf16 mixed-precision) — `farr_adamw_step_gpu` is the
  f64 AdamW; a bf16 fused variant is a later option, not RFC 041.

## Cross-link (campaign evidence — g3)

- anima `docs/anima_rfc040_phase_e2_backward_fathost_2026_05_16.md`
  §2.1 + §5 C3-2/C3-3/C3-4 — the op-availability finding + the
  GEMM-reshape proof + the elementwise-stays-boxed honest scope.
- anima `state/hexad_gpu_fire_phaseE2_2026_05_16/result.json`
  `backward_refactor.b2_op_finding` + `cpu_equivalence_gate` — the
  verified `-1`-stub finding + the exact-equal CPU reference.
- anima `docs/anima_rfc040_phase_d_h100_cublas_2026_05_16.md` §2.2 —
  the measured cuBLAS Dgemm `TOL_MATMUL ≈ 2e-9` calibration.
- hexa-lang `self/runtime.c` `017b988f` §10778-10852 (Phase B stubs)
  + §10859-11176+ (Phase B2 stubs) + `self/cuda/runtime_cuda.c`
  `_hx_cuda_farr_matmul_gpu` (the one real kernel) — read directly,
  the design's ground truth.
- anima `AGENTS.tape` §0 `g_blue_closed_mandate` / `g3` / `f2` — the
  connection-point closed-equivalence + real-limit-anchor mandate.
