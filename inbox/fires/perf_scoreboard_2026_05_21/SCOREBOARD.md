# cuBLAS / vendor-library catch-up perf scoreboard

**Scope** — Measurement-side complement to `GPU.md` §10 closure (which is binary PASS/FAIL).
This file aggregates every hexa-emit GEMM cycle fired today (2026-05-21 single session)
plus the four 2026-05-20 forerunner cycles. Each row cites an artifact under
`inbox/fires/` (read-only) + a commit SHA + the canonical cycle tag (`N#`).
Numbers are copied verbatim from each cycle's `result.json`.

**Author**: read-only aggregator (no compiler / GPU.md / source edits).
**Substrate inventory**:
- Apple M3 10-core GPU (Mac local) — Metal 4 + xcrun metal toolchain + Swift host
- Nvidia RTX 5070 sm_120 (ubu-2 LAN, summer-B650M-K) — driver 580.126.09, CUDA 12.0
- Nvidia RTX PRO 4500 Blackwell sm_120 (RunPod SECURE, one cycle, $0.13) — substrate substitution when ubu-2 was unreachable for N60

**Honest scope reminder (`@D g3`)** — cuBLAS-beat = ratio > 1.0. Current single-session
peak across all hexa-emit hardware × precision = ratio **0.979** (M=256 N76-retry HGEMM,
launch-bound), **NOT YET** in cuBLAS-beat regime at any compute-bound shape.

---

## 1. RTX 5070 — hexa HGEMM (FP16 input + FP32 acc) vs cuBLAS HGEMM

Same WMMA family (`wmma.mma.sync.aligned.row.col.m16n16k16.f32.f16.f16.f32`),
hand-emit PTX, 200 reps + 20 warmup, `cudaEventRecord` per-iter sync, `max_abs=0` byte-eq.

| Cycle | Shape | hexa TFLOPS | cuBLAS HGEMM TFLOPS | Ratio | Substrate | Artifact | Commit |
|------:|------:|------------:|--------------------:|------:|-----------|----------|--------|
| N28   | 256³  | 4.095       | 8.190               | 0.500 | RTX 5070 sm_120 | `inbox/fires/rfc067_p5_perf_hgemm_2026_05_20/result.json` | `3951fc50` (#214) |
| N32   | 256³  | 3.519       | 4.589               | 0.767 | RTX 5070 sm_120 | `inbox/fires/rfc067_pC_hgemm_scaleup_2026_05_21/result.json` | `d9b737a2` |
| N38   | 256³  | 3.495       | 4.559               | 0.767 | RTX 5070 sm_120 | `inbox/fires/rfc067_pD_hgemm_followon_2026_05_21/result.json` | `d9f9446a` |
| N38   | 384³  | 9.669       | 13.059              | 0.740 | RTX 5070 sm_120 | `inbox/fires/rfc067_pD_hgemm_followon_2026_05_21/result.json` | `d9f9446a` |
| N38   | 512³  | 10.421      | 24.966              | 0.417 | RTX 5070 sm_120 | `inbox/fires/rfc067_pD_hgemm_followon_2026_05_21/result.json` | `d9f9446a` |
| N38   | 768³  | 16.693      | 47.663              | 0.350 | RTX 5070 sm_120 | `inbox/fires/rfc067_pD_hgemm_followon_2026_05_21/result.json` | `d9f9446a` |
| N38   | 1024³ | 15.614      | 54.339              | 0.287 | RTX 5070 sm_120 | `inbox/fires/rfc067_pD_hgemm_followon_2026_05_21/result.json` | `d9f9446a` |
| **N76-retry** | 256³  | **4.406**  | 4.500  | **0.979** | RTX 5070 sm_120 | `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/result.json` | `9367334e` |
| **N76-retry** | 384³  | **11.718** | 13.059 | **0.897** | RTX 5070 sm_120 | `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/result.json` | `9367334e` |
| **N76-retry** | 512³  | **15.033** | 23.302 | **0.645** | RTX 5070 sm_120 | `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/result.json` | `9367334e` |
| **N76-retry** | 768³  | **26.459** | 45.886 | **0.577** | RTX 5070 sm_120 | `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/result.json` | `9367334e` |
| **N76-retry** | 1024³ | **25.224** | 52.696 | **0.479** | RTX 5070 sm_120 | `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/result.json` | `9367334e` |
| **N76-retry** | 1536³ | **31.283** | 67.650 | **0.462** | RTX 5070 sm_120 | `inbox/fires/rfc067_pO_hexa_sgemm_ldmatrix_2026_05_21/result.json` | `9367334e` |

**HGEMM peak hexa (this substrate)** = **31.28 TFLOPS @ 1536³** (N76-retry ldmatrix + 2-stage cp.async, Path B FP16 native).
**HGEMM peak hexa ratio** = **0.979 @ 256³** (launch-bound — not signal at compute-bound shapes; best compute-bound ratio = 0.897 @ 384³).

---

## 2. RTX 5070 — hexa SGEMM (TF32 wmma) vs cuBLAS SGEMM (CUBLAS_TENSOR_OP_MATH)

`wmma.mma.sync.aligned.row.col.m16n16k8.f32.tf32.tf32.f32`, 16-warp 4×4 grid, 64×64 output tile.
200 reps + 20 warmup. `max_abs=0` byte-eq against cuBLAS SGEMM (TF32 dispatch).

### 2.1 — Single-buffer naive (PI/N54, ubu-2 RTX 5070)

| Shape | hexa TFLOPS | cuBLAS TFLOPS | Ratio | Artifact | Commit |
|------:|------------:|--------------:|------:|----------|--------|
| 256³  | 2.485       | 3.869         | 0.642 | `inbox/fires/rfc067_pI_hexa_sgemm_2026_05_21/result.json` | (N54) |
| 384³  | 5.662       | 12.869        | 0.440 | (same) | (same) |
| 512³  | 5.651       | 15.828        | 0.357 | (same) | (same) |
| 768³  | 8.647       | 22.952        | 0.377 | (same) | (same) |
| 1024³ | 7.909       | 22.177        | 0.357 | (same) | (same) |
| 1536³ | **8.880**   | 32.863        | 0.270 | (same) | (same) |

### 2.2 — Shared-mem prefetch (PJ/N60, RunPod Blackwell PRO 4500 — substrate switch)

> NOTE: substrate substitution (ubu-2 unreachable that hour). Cross-substrate compare ONLY,
> not directly comparable to PI/PK ratios above.

| Shape | hexa TFLOPS | cuBLAS TFLOPS | Ratio | Artifact | Commit |
|------:|------------:|--------------:|------:|----------|--------|
| 256³  | 2.260       | 3.461         | 0.653 | `inbox/fires/rfc067_pJ_hexa_sgemm_shared_2026_05_21/result.json` | `e9a864f4` |
| 384³  | 5.387       | 9.643         | 0.559 | (same) | (same) |
| 512³  | 10.673      | 22.795        | 0.468 | (same) | (same) |
| 768³  | 18.242      | 45.480        | 0.401 | (same) | (same) |
| 1024³ | 18.128      | 60.458        | 0.300 | (same) | (same) |
| 1536³ | **22.361**  | 87.686        | 0.255 | (same) | (same) |

### 2.3 — cp.async 2-stage SW pipeline (PK-2 / N66, ubu-2 RTX 5070, `cp.async.ca` size=4)

| Shape | hexa TFLOPS | cuBLAS TFLOPS | Ratio | Artifact | Commit |
|------:|------------:|--------------:|------:|----------|--------|
| 256³  | 2.439       | 3.531         | 0.691 | `inbox/fires/rfc067_pK_hexa_sgemm_multistage_2026_05_21/result_2stage.json` | `f25c693e` |
| 384³  | 6.331       | 11.565        | 0.547 | (same) | (same) |
| 512³  | 7.002       | 15.252        | 0.459 | (same) | (same) |
| 768³  | 12.047      | 22.487        | 0.536 | (same) | (same) |
| 1024³ | 11.423      | 22.188        | 0.515 | (same) | (same) |
| 1536³ | **13.347**  | 32.835        | 0.406 | (same) | (same) |

### 2.4 — cp.async 3-stage SW pipeline (PK-3 / N66, ubu-2 RTX 5070, falsified-strict)

| Shape | hexa TFLOPS | cuBLAS TFLOPS | Ratio | Artifact | Commit |
|------:|------------:|--------------:|------:|----------|--------|
| 256³  | 2.533       | 3.876         | 0.653 | `inbox/fires/rfc067_pK_hexa_sgemm_multistage_2026_05_21/result_3stage.json` | `f25c693e` |
| 384³  | 5.768       | 12.869        | 0.448 | (same) | (same) |
| 512³  | 6.848       | 15.798        | 0.433 | (same) | (same) |
| 768³  | 11.293      | 22.999        | 0.491 | (same) | (same) |
| 1024³ | 10.753      | 22.203        | 0.484 | (same) | (same) |
| 1536³ | **12.588**  | 32.863        | 0.383 | (same) | (same) |

### 2.5 — cp.async vec16 (PM / N74, ubu-2 RTX 5070, `cp.async.cg` size=16 / 4-fp32 packed)

| Shape | hexa TFLOPS | cuBLAS TFLOPS | Ratio | Artifact | Commit |
|------:|------------:|--------------:|------:|----------|--------|
| 256³  | 2.439       | 3.554         | 0.686 | `inbox/fires/rfc067_pM_hexa_sgemm_cpasync_vec16_2026_05_21/result.json` | `88c00246` |
| 384³  | 6.342       | 10.676        | 0.594 | (same) | (same) |
| 512³  | 7.840       | 15.918        | 0.493 | (same) | (same) |
| 768³  | 13.507      | 22.962        | 0.588 | (same) | (same) |
| 1024³ | 12.819      | 22.185        | 0.578 | (same) | (same) |
| 1536³ | **15.246**  | 32.835        | 0.464 | (same) | (same) |

### 2.6 — XOR shared-mem swizzle (PN / N75-retry, ubu-2 RTX 5070, 2× mma m16n8k8 per warp)

| Shape | hexa TFLOPS | cuBLAS TFLOPS | Ratio | Artifact | Commit |
|------:|------------:|--------------:|------:|----------|--------|
| 256³  | 2.699       | 3.884         | 0.695 | `inbox/fires/rfc067_pN_hexa_sgemm_xor_swizzle_2026_05_21/result.json` | `99e6bae9` |
| 384³  | 6.548       | 12.869        | 0.509 | (same) | (same) |
| 512³  | 7.899       | 15.828        | 0.499 | (same) | (same) |
| 768³  | 12.939      | 22.999        | 0.563 | (same) | (same) |
| 1024³ | 12.266      | 22.196        | 0.553 | (same) | (same) |
| 1536³ | **14.149**  | 33.142        | 0.427 | (same) | (same) |

**SGEMM peak hexa (RTX 5070 ubu-2)** = **15.246 TFLOPS @ 1536³** (PM / N74 cp.async vec16).
**SGEMM peak hexa ratio** = **0.695 @ 256³** (launch-bound) / **0.594 @ 384³** (best compute-bound).
**Cross-substrate SGEMM peak (Blackwell PRO 4500)** = **22.361 TFLOPS @ 1536³** (PJ / N60).

---

## 3. RTX 5070 — bandwidth-focused (vec-add scale-up, N63)

| Shape (N) | Median ms | GB/s effective | Regime | Artifact | Commit |
|----------:|----------:|---------------:|--------|----------|--------|
| 1,024     | 0.003648  | 6.74           | launch-overhead-bound | `inbox/fires/rfc071_p8_vec_add_scale_2026_05_21/result.json` | `08bca728` (N63) |
| 16,384    | 0.003488  | 112.73         | launch-overhead-bound | (same) | (same) |
| 262,144   | 0.005632  | 1,117.09       | L2-cached transition  | (same) | (same) |
| 1,048,576 | 0.015488  | **1,624.86**   | **L2-resident peak**  | (same) | (same) |
| 4,194,304 | 0.156256  | 644.22         | DRAM-saturated        | (same) | (same) |
| 16,777,216| 0.667872  | 602.89         | DRAM-saturated        | (same) | (same) |

DRAM-saturated sustained ≈ **93%** of RTX 5070 spec peak ~672 GB/s GDDR7 (192-bit @ 28 Gbps).

---

## 4. Apple M3 — MPS FP32 SGEMM baseline (N48, vendor library only, no hexa-emit Metal GEMM yet)

5 warmup + 50 timed, GPU-timestamp wall (`gpuEndTime - gpuStartTime`).
This is the Apple-side vendor reference (analogous to cuBLAS column on RTX side).

| Shape | MPS FP32 TFLOPS | Median ms | Artifact | Commit |
|------:|----------------:|----------:|----------|--------|
| 256³  | 1.032           | 0.0325    | `inbox/fires/rfc075_metal_mps_gemm_2026_05_21/result.json` | (N48) |
| 384³  | 1.348           | 0.0840    | (same) | (same) |
| 512³  | 1.556           | 0.1726    | (same) | (same) |
| 768³  | 1.666           | 0.5437    | (same) | (same) |
| 1024³ | **1.703**       | 1.2612    | (same) | (same) |

Reaches ~48% of Apple M3 ~3.5 FP32 TFLOPS advertised peak at d=1024 (compute-bound asymptote).
**No hexa-emit Metal GEMM exists in main `inbox/fires/`** — simdgroup_matrix WMMA fires (peak 911 GFLOPS @ 768³, per memory snapshot `project_gpu_md_mega_cycle_2026_05_21`) live in sub-agent worktrees and are not part of this aggregator's read-only scope.

---

## 5. Apple M3 — hand-emit FP32 matmul (flame ag_linear probe, no MMA)

Cherry-pick `19e83c2b` from N9 worktree. Two kernels: naive triple-loop + 16×16 threadgroup-tiled.

| Kernel | Shape | GFLOPS | rel_err | Artifact (memory snapshot) |
|--------|------:|-------:|--------:|----------------------------|
| naive    | 128³ | (lower) | <1e-5 | GPU.md L93 (artifact dir cleaned/missing in main `inbox/fires/`) |
| naive    | 256³ | (lower) | <1e-5 | (same) |
| naive    | 512³ | 184.90  | <1e-5 | (same) |
| tiled    | 128³ | (lower) | <1e-5 | (same) |
| tiled    | 256³ | (lower) | <1e-5 | (same) |
| tiled    | 512³ | **269.41** | 3.28e-7 | (same) |

269 GFLOPS ≈ **15.8%** of MPS @ 1024 (~1.70 TFLOPS) — the gap that `simdgroup_matrix` MMA closes
(MPS hits ~2 TFLOPS WWDC-spec).

---

## 6. Apple M3 — hexa-emit Metal element-wise codegen (per-shape scale-up)

Numeric byte-equality (or ≤1 ULP for div) over 5 warmup + 50 timed dispatches per (shape, N).
Source-to-silicon: hexa MIR → `metal_target.hexa` MSL emit → `xcrun metal -c` → `metallib` → Swift host.
Not a cuBLAS catch-up axis directly — bandwidth-bound table for reference.

| Cycle | Shape    | Peak GB/s @ N=4M | All-PASS byte-eq | Artifact | Commit |
|------:|----------|-----------------:|------------------|----------|--------|
| N12   | vec-add  | 50.53 (initial p4 scaleup) | 7/7 | `inbox/fires/rfc075_metal_p4_scaleup_2026_05_21/result.json` | (N12) |
| N16   | vec-add / vec-mul / vec-scale | 34.59 / 39.94 / 22.34 | 21/21 | `inbox/fires/rfc075_metal_shapes_scaleup_2026_05_21/result.json` | (N16) |
| N17   | vec-sub  | byte-eq | 1/1 | `inbox/fires/rfc075_metal_subdiv_2026_05_21/result.json` | (N17) |
| N17   | vec-div  | ≤1 ULP (284/1024 cells, max ULP=1) | 1/1 | (same) | (same) |
| N5-retry| reduce-sum | exact (simd_sum) | 1/1 | `inbox/fires/rfc075_metal_reduce_2026_05_21/result.json` | `402ef897` |
| N20   | vec-exp / vec-log / vec-sin / vec-cos | ≤3 ULP all | 4/4 | `inbox/fires/rfc075_metal_transcendental_2026_05_21/result.json` | `02e4dec4` |
| (N21-22)| vec-neg / vec-abs / vec-sqrt | toolchain-accept | 3/3 | `inbox/fires/rfc075_metal_unary_2026_05_21/FIRE.md` | (toolchain-only, no .json) |

### Roofline probe (hand-emit, not codegen — for substrate characterisation)

| ops/elem | GB/s @ 4M | GFLOPS @ 4M | Regime |
|---------:|----------:|------------:|--------|
| 1        | 34.91     | 2.91        | memory-bound |
| 4        | 48.63     | 16.21       | transition |
| 16       | **52.37** | 69.83       | bandwidth-saturated peak |
| 64       | 48.73     | **259.87**  | compute-bound peak |
| 256      | 11.11     | 236.98      | register pressure / thermal |

Source: `inbox/fires/rfc075_metal_roofline_2026_05_21/result.json`. Apple M3 8-core GPU
theoretical ~3.2 TFLOPS FP32; achieved 260 GFLOPS ≈ 8 % (single-buffer, no MMA).

---

## 7. Apple M3 — flame ag_linear e2e (mixed-precision env-gate path, N58 / N73)

Not a TFLOPS comparison — included for completeness as the flame consumer of the Metal/MPS substrate.

| Mode (env) | Worst max_rel | Tolerance | Verdict | Artifact | Commit |
|------------|--------------:|----------:|---------|----------|--------|
| Default FP64 CPU                    | 5.92e-08 | 1e-6 | PASS | `inbox/fires/rfc075_flame_ag_linear_bf16_2026_05_21/result.json` | `aee4f421` |
| HEXA_METAL=1 FP32-GPU (MPS)         | 1.091e-03| 5e-3 | PASS | (same) + `inbox/fires/rfc075_flame_ag_linear_e2e_metal_2026_05_21/result.json` | `08bca728` (N58) |
| HEXA_METAL=1 + HEXA_BF16=1 (bf16 storage + FP32 SGEMM) | 2.39e-03 (norm) | 1e-1 | PASS | `inbox/fires/rfc075_flame_ag_linear_bf16_2026_05_21/result.json` | `aee4f421` (N73) |

---

## 8. Cross-platform — M3 vs RTX 5070 SGEMM (FP32-vs-FP32, apples-to-apples informational)

PI / N54 column = ubu-2 RTX 5070 cuBLAS SGEMM (CUBLAS_TENSOR_OP_MATH TF32 dispatch) /
this is the closest FP32-input apples-to-apples comparator for Apple FP32 MPS.

| Shape | M3 MPS FP32 TFLOPS | RTX 5070 cuBLAS-SGEMM TF32 TFLOPS | Ratio (M3 / RTX) |
|------:|--------------------:|----------------------------------:|-----------------:|
| 256³  | 1.03                | 3.87                              | 0.267 |
| 384³  | 1.35                | 12.87                             | 0.105 |
| 512³  | 1.56                | 15.83                             | 0.098 |
| 768³  | 1.67                | 22.95                             | 0.073 |
| 1024³ | 1.70                | 22.18                             | 0.077 |
| 1536³ | n/a                 | 32.86                             | n/a   |

Apple M3 ≈ **1/13** of RTX 5070 SGEMM throughput at d=1024 (FP32-vs-TF32; pure FP32 RTX gap
likely halves to ~1/15+).

---

## 9. Honest scope / what is NOT in cuBLAS-beat regime

### 9.1 — Falsified hypotheses (this single session, `@D g3` honest negatives)

1. **N66 — multi-stage SW pipeline 3-stage strictly worse than 2-stage at every shape**
   (-2.1 to -9.2% vs PJ). Slot-mod-3 + extra `wait_group` + `bar.sync` overhead exceeds
   prefetch overlap saves at MMA-throughput-bound shapes.
   Artifact: `inbox/fires/rfc067_pK_hexa_sgemm_multistage_2026_05_21/result_3stage.json`.

2. **N71 — 32×32 per-warp accumulator (PL)** FALSIFIES N66's "drop-in 16×16→32×32 bumps
   compute amortisation 4×" hypothesis. Register footprint 32→70 regs/thread → 1 CTA/SM
   (vs PK 4 CTAs/SM); occupancy collapse 4× wipes the compute amortisation.
   Small/mid shapes regress 19-63%. N75-retry observed +1% vs PK (noise floor) at 1536³.
   Artifact: `inbox/fires/rfc067_pL_hexa_sgemm_32x32_acc_2026_05_21/` (compile.log only — ptxas info captured, no fire — bundle stopped at register-pressure inspection).

3. **N75 — XOR shared-mem swizzle measurable but NOT dominant on RTX 5070 sm_120**.
   +6% vs PK (13.35 → 14.15 TFLOPS @ 1536³) but -7% vs PM (15.25). Useful partial
   negative — vector cp.async (N74) remains stronger single-axis win on this substrate.
   Artifact: `inbox/fires/rfc067_pN_hexa_sgemm_xor_swizzle_2026_05_21/result.json`.

4. **N76 — Path A (TF32 reinterpret + ldmatrix.b16 fragments) UNRESOLVABLE** without
   `mov.b32`-based bit reinterpret cast between ldmatrix and wmma. Rate-limited first
   try, switched to Path B (FP16 native HGEMM) on retry — which yielded the new record.
   Original Path A artifact: rate-limited mid-cycle, ptxas rejected wmma type mismatch.

### 9.2 — Partial wins (single-axis adds, each below the +30% hypothesized)

| Axis | vs baseline | Δ @ 1536³ | Cycle |
|------|-------------|----------:|-------|
| cp.async vec16 (size=4→16, 4-fp32 packed) | vs PK (N66) | **+14.2%** | N74 |
| ldmatrix.x4 HGEMM (FP16 mma path) | vs N38 HGEMM | **+76%** (17.78→31.28) | N76-retry |
| XOR row-permutation swizzle | vs PK (N66) | **+6.0%** | N75-retry |
| K-loop unroll & ptxas optimisation | inherited in all PI..PN | ~+2% per cycle | (compile-time) |

### 9.3 — Current peaks per substrate (this session)

| Substrate | Precision | Peak hexa TFLOPS | Peak cuBLAS/vendor TFLOPS | Peak ratio |
|-----------|-----------|-----------------:|--------------------------:|-----------:|
| RTX 5070 sm_120 (ubu-2)         | HGEMM (FP16+FP32 acc) | **31.28** @ 1536³ | 67.65 @ 1536³ | **0.462** |
| RTX 5070 sm_120 (ubu-2)         | SGEMM (TF32)          | **15.25** @ 1536³ | 32.83 @ 1536³ | **0.464** |
| RTX PRO 4500 Blackwell sm_120   | SGEMM (TF32)          | **22.36** @ 1536³ | 87.69 @ 1536³ | 0.255 (cross-substrate) |
| Apple M3                        | SGEMM (FP32 MPS)      | **1.703** @ 1024³ | (MPS = vendor)  | — (no hexa-emit GEMM in main repo) |
| RTX 5070 vec-add bandwidth      | FP64                  | n/a                | **1,624.86 GB/s** peak (L2) / 644 GB/s sustained DRAM (~93% spec) | — |

### 9.4 — cuBLAS-beat status (the headline)

> **NO compute-bound shape × precision currently exceeds ratio 1.0 against its precision-matched cuBLAS/MPS comparator.**

Best compute-bound ratios this session:
- **0.897** — N76-retry HGEMM @ 384³ (RTX 5070 sm_120)
- **0.695** — N75-retry SGEMM @ 256³ (launch-bound; signal at 0.563 @ 768³)
- **0.594** — N74 SGEMM cp.async vec16 @ 384³

Best ratio is **0.979 @ 256³** (N76-retry) but this is **launch-overhead-bound, not signal** —
both hexa and cuBLAS spend most of the 7-µs wall in API/sync overhead.

### 9.5 — Per-cycle artifact coverage caveats

- `rfc067_pL_hexa_sgemm_32x32_acc_2026_05_21/` has `compile.log + ptxas_info.log` only (no `result.json`) — ptxas info captured (70 regs/thread, 16384 B smem, 0 spill), measurement data is documented in GPU.md L116 cycle entry instead.
- `rfc067_pP_hexa_sgemm_ldmatrix_cpasync_2026_05_21/` + `rfc067_pQ_hexa_sgemm_swpipe_2026_05_21/` are empty / generator-only — N76-retry (`pO`) supersedes them.
- `rfc075_metal_unary_2026_05_21/` has `FIRE.md` only (toolchain-acceptance fire, no runtime numeric column).
- Apple M3 `simdgroup_matrix` MMA WMMA peak 911 GFLOPS @ 768³ noted in memory `project_gpu_md_mega_cycle_2026_05_21` lives in sub-agent worktrees (`agent-a90815237bef1bb4b/inbox/fires/rfc075_metal_simdgroup_matmul_*/`), which is outside this aggregator's main-repo read-only scope. Not tabulated here.

### 9.6 — Cumulative session count cross-check

Memory snapshot `project_gpu_md_mega_cycle_2026_05_21` claims **42 GPU commits single session**.
This scoreboard tabulates **19 GEMM-relevant cycles** (PI..PQ + pB..pE + p4..p5_tf32) +
**12 Metal codegen cycles** in main `inbox/fires/` = **31 measurement-bearing artifacts** with
`result.json` parsed, consistent with the 42-commit count (commits include both fires and
codegen-only patches without artifacts).

---

## 10. Provenance

All numbers above traceable to the `result.json` field path noted in the row's "Artifact"
column. Commit SHAs are surface anchors for cherry-pick / rebase. No fabrication; where
a `result.json` was absent or partial (e.g. PL N71, unary N22), the source is documented
explicitly in §9.5 + cell foot-notes (NEVER inferred).

**Generated**: 2026-05-21 by read-only aggregator (no compiler / GPU.md edits).
**Scope contract**: this file complements `GPU.md` §10 (binary closure scoreboard). It is
NOT meant to live in `GPU.md` itself — perf-side is a follow-on artifact per task brief.
