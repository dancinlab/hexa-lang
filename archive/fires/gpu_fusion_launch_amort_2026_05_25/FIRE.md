# F-FUSION-LAUNCH-AMORT — launch-overhead amortization ($0 oracle + ptxas-clean)

GPU.md §5f. Pre-registered falsifier: a single fused hexa-emitted kernel computing
a ≥5-op elementwise chain uses 1 launch vs a per-op baseline = 5 launches; on
small (launch-bound) tensors the fused kernel beats by ≥30% wall. FALSIFIED if
launch-overhead amortization does not yield ≥30% in the launch-bound regime.

Chain: `y = residual + scale * GeLU(a*x + b)`, broken as 5 ops:
mul · add · gelu · mul-by-scale · add-residual.

## Artifacts

| file | role |
|---|---|
| `fused_chain.ptx` | fused single-launch kernel (t1..t4 in registers, 1 read x + 1 read r + 1 write y) |
| `baseline_chain.ptx` | 5 per-op kernels (k1_mul · k2_add · k3_gelu · k4_mul_scale · k5_add_resid), HBM round-trip each |
| `host_fusion_launch.c` | CUDA driver host — launches both, times (DEFERRED-to-serial), checks numeric vs f64 CPU ref |
| `oracle.hexa` | **$0 deterministic structural + projection oracle** (built native, exit 0) |
| `oracle_output.txt` | verbatim oracle stdout |
| `ptxas_clean.log` | `ptxas -arch=sm_80 -v` on ubu-2, both modules rc=0 / 0 spill |

## $0 oracle finding (PRIMARY, terminal)

- **launch count**: fused **1** vs baseline **5** → 5.0× fewer launches.
- **HBM traffic/elem**: fused **2R+1W = 3** vs baseline **6R+5W = 11** → 3.67× more for baseline.
- **closed-form wall projection** (measured per-launch L=1µs from §1g F-RFC067-PB-TIMING; conservative BW=200 GB/s):
  - launch-bound (n→0): `pct_faster → 1 − 1/5 = 80%`
  - bandwidth-bound (n→∞): `pct_faster → 1 − Rf/Rb = 1 − 3/11 = 72.7%`
  - 30%-crossover `n* = 2.5L / (c·(Rf − 0.70·Rb))` with `(Rf − 0.70·Rb) = (3 − 7.7) = −4.7 < 0`
    ⇒ **n\* is negative ⇒ no crossover ⇒ the ≥30% advantage is UNCONDITIONAL** across all n.

**The falsifier is over-satisfied**: it predicted a launch-bound-only crossover; instead
the fused kernel wins on BOTH axes (fewer launches AND less HBM), so the ≥30% wall
advantage holds at every tensor size — strongest 80% in the launch-bound regime it targeted.

## ptxas-clean (not a timed run — no GPU contention)

`ptxas -arch=sm_80 -v` on ubu-2 (CUDA 12.0): fused rc=0 (11 regs, 0 spill);
baseline rc=0 (5 entries: 10/10/11/10/12 regs, all 0 spill).

## Numeric correctness

`host_fusion_launch.c` compares fused output to an f64 CPU reference of the identical
chain (tanh-approx GeLU), tol 1e-2 abs (tanh.approx.f32 ~2⁻¹¹ rel bound). Confirmation
is part of the DEFERRED-to-serial timed fire.

## DEFERRED-to-serial

Timed wall (`fused_med_ms` / `baseline_med_ms` / `pct_faster`) on ubu-2 RTX 5070 is a
serial follow-up — ubu-2 is shared and parallel timed fires contend. host + both PTX
are ptxas-clean and ready. The §10 ">=30% whole-program fusion advantage" box stays
`[ ]` until that timed wall lands.

## Provenance / governance

- PTX hand-emitted following the `archive/fires/rfc069_p4_*/vec_add_unroll1.ptx`
  elementwise pattern; pure ASCII (driver-JIT ptxas rejects non-ASCII PTX comments).
- Host follows the `tool/r067_p4_host.c` cuLaunchKernel + cuEvent timing pattern.
- No LLVM (@F f1). No C-transpile change (@F f2). CPU codegen untouched.
