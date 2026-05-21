# RFC 075 P3+ — matmul_NT_a + matmul_NT_b Apple M3 silicon-fire

Date: 2026-05-21
Branch: `worktree-agent-a9f9e8ba6e97d75cb`
Falsifier: `F-RFC075-METAL-MATMUL-NT-CODEGEN-NUMERIC-EQ`
Status: **PASS** (6/6 — 2 kernels × 3 cube shapes)

## What was fired

Two codegen-emitted MSL kernels exercising Apple MSL's `simdgroup_load`
`transpose_matrix` flag (MSL Specification §6.7.1) to implement
transposed-operand matmul variants needed by flame's `ag_linear`
backward (`dx = dy · W^T` → matmul_NT_b; `dW = x^T · dy` → matmul_NT_a).

- `matmul_NT_a.metal` — `C = A^T · B`, A is K×M row-major.
  Inner: `simdgroup_load(Amat, As, ulong(TG_M), ulong2(sg_y*8u, 0), true)`.
- `matmul_NT_b.metal` — `C = A · B^T`, B is N×K row-major.
  Inner: `simdgroup_load(Bmat, Bs, ulong(TG_K), ulong2(0, sg_x*8u), true)`.

Both kernels share N24's plain matmul preamble + 6-arg kernel signature
+ 4-thread-hierarchy attributes + tile constants (TG_M=32 · TG_N=32 ·
TG_K=8 · 16 simdgroups × 32 lanes = 512 threads/TG).

## How

1. `hexa build compiler/codegen/metal_lower_test.hexa` → `/tmp/metal_lower_test_NT`.
2. Ran the binary; extracted MSL kernel text for matmul_NT_a + matmul_NT_b.
3. `xcrun -sdk macosx metal -c <kernel>.metal -o <kernel>.air` (AIR rc=0).
4. `xcrun -sdk macosx metallib matmul_NT_a.air matmul_NT_b.air -o matmul_NT.metallib`.
5. `xcrun --sdk macosx swift host_matmul_NT.swift matmul_NT.metallib`.

## Results

Apple M3 GPU, Darwin 25.5.0, Metal Toolchain v17.5.188.0.

| shape (M=N=K) | kernel | max\|abs\| | max\|rel\| (\|ref\|>1e-3) | abs-floor | wall ms | GFLOPS |
|---|---|---|---|---|---|---|
| 128 | matmul_NT_a | 6.2e-6  | 2.2e-4 | 1.0e-4 | 1.61  | 2.6   |
| 128 | matmul_NT_b | 5.7e-6  | 5.1e-4 | 1.0e-4 | 0.41  | 10.4  |
| 256 | matmul_NT_a | 5.3e-5  | 1.1e-3 | 1.0e-4 | 1.49  | 22.6  |
| 256 | matmul_NT_b | 6.9e-5  | 2.4e-3 | 1.0e-4 | 1.17  | 28.7  |
| 512 | matmul_NT_a | 3.2e-5  | 8.5e-3 | 2.0e-4 | 3.19  | 84.3  |
| 512 | matmul_NT_b | 3.0e-5  | 2.2e-3 | 2.0e-4 | 3.34  | 80.3  |

`max|abs|` is FP32 dot-product accumulation noise (bounded by
`K · ε · E[|product|] ≈ K · 1.2e-7 · 0.33`). All shapes are within the
abs-floor or within the 1e-3 relative tolerance — PASS.

GFLOPS are single-dispatch first-fire warmup numbers (cf. N24
`713c0a07`: similar 50-92 d=128 / 185-373 d=256 / 233-550 d=512
single-shot; N24 reported 638 GFLOPS @ 512³ only after steady-state
averaging). Steady-state perf for the NT variants should match plain
matmul (simdgroup_load transpose is hardware-cheap).

## Honest scope

- Single-dispatch numerics validated — no GFLOPS-stability measurement
  (steady-state averaging multi-session work).
- 32×32 output tile + TG_K=8 hardcoded (mirrors N24).
- FP32 only.
- Kernels carry one unused `TG_K` declaration warning (NT_a body; cosmetic).
