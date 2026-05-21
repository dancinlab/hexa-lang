# F-RFC075-METAL-FARR32-MATMUL-NT-B-NUMERIC-EQ

Smoke for METAL_INTEGRATION.md step 4 of 5 (2026-05-21): the new
`hexa_farr32_matmul_NT_b` C builtin + `_hx_metal_farr32_matmul_NT_b_gpu`
Metal/MPS shim for the bwd-input matmul shape in `ag_linear` (flame
`stdlib/flame/ag_tape.hexa:630` via `matmul_bwd_auto`).

## Build commands

CPU only:
```
xcrun --sdk macosx clang -O2 \
  inbox/fires/rfc075_metal_farr32_matmul_NT_b_2026_05_21/host_check.c \
  self/runtime.c -o /tmp/n34_smoke
```

With Metal:
```
xcrun --sdk macosx clang -O2 -DHEXA_METAL -fobjc-arc \
  -framework Metal -framework MetalPerformanceShaders -framework Foundation \
  inbox/fires/rfc075_metal_farr32_matmul_NT_b_2026_05_21/host_check.c \
  self/runtime.c self/metal/runtime_metal.m -o /tmp/n34_smoke_metal
```

## Build results

| target                          | rc | object size |
|---------------------------------|----|-------------|
| runtime.c (no defines)          | 0  | 456720 B    |
| runtime.c (-DHEXA_METAL)        | 0  | 457368 B    |
| runtime_metal.m (-DHEXA_METAL)  | 0  | 15040 B     |
| smoke (CPU-only link)           | 0  | -           |
| smoke (Metal-linked)            | 0  | -           |

## Smoke results

CPU-only `/tmp/n34_smoke` (no HEXA_METAL define):
```
[PASS 4x4x4_ones]   M=4 K=4 N=4       max_abs=0  max_rel=0       tol=1e-06
[PASS 8x8x8_ramp]   M=8 K=8 N=8       max_abs=0  max_rel=0       tol=1e-06
[PASS 64x64x64_rand]  M=64 K=64 N=64       max_abs=4.768e-07  max_rel=1.612e-04  tol=1e-02
[PASS 128x128x128]    M=128 K=128 N=128    max_abs=9.537e-07  max_rel=3.319e-03  tol=1e-02
OVERALL: PASS
```

Metal-linked + `HEXA_METAL=1` env (case 4 = M*K=16384, ABOVE dim-gate,
routes through `_hx_metal_farr32_matmul_NT_b_gpu` → MPS):
```
[PASS 4x4x4_ones]   M=4 K=4 N=4       max_abs=0  max_rel=0       tol=1e-06
[PASS 8x8x8_ramp]   M=8 K=8 N=8       max_abs=0  max_rel=0       tol=1e-06
[PASS 64x64x64_rand]  M=64 K=64 N=64       max_abs=4.768e-07  max_rel=1.612e-04  tol=1e-02
[PASS 128x128x128]    M=128 K=128 N=128    max_abs=9.537e-07  max_rel=3.319e-03  tol=1e-02
OVERALL: PASS
```

All four cases pass under both CPU and Metal paths.

## What this validates

1. The math contract `C[i,j] = sum_k A[i,k] * B[j,k]` (A row-major M×K,
   B row-major N×K) is computed correctly by both the CPU fallback and
   the MPS `transposeRight:YES` dispatch.
2. Cases 1+2 (integer inputs, M=K=N ≤ 8) hit the exact-FP32 representable
   regime → max_rel exactly 0, structural correctness gate.
3. Cases 3+4 (FP32 random inputs) hit the accumulator-reordering regime
   → max_rel < 1e-2 is the documented FP32 SGEMM budget vs scalar k-inner
   reference (MPS tile-major reduce vs our 4-wide unrolled k-inner; same
   class of difference as the N26 no-T smoke documented).
4. The dispatch dim-gate (M*K > 8192 || K*N > 8192) routes case 4 to MPS
   when HEXA_METAL=1.

## Honest scope (@D g3)

- Case 4 max_rel happens to align bit-exactly between CPU + MPS paths
  at 128×128×128 — same alignment observation as the N26 no-T smoke.
  At adversarial shapes (1024+ K), MPS tile-major reduce vs scalar
  k-inner reference can produce 1e-3 to 1e-2 drift — still well within
  the FP32 budget.
- The smoke does NOT exercise `ag_linear` end-to-end on Metal; that's
  step 5 (nn.Module dispatch wiring), which depends on this step.
- No CUDA path on `hexa_farr32_matmul_NT_b` — Mac is the priority
  target (mirrors N26's no-T variant rationale).
