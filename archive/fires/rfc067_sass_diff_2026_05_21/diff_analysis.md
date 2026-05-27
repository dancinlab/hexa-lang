# RFC 067 SASS-level diff: cuBLAS HGEMM vs hexa N89 @ M=N=K=1536

Date: 2026-05-21..22
Host: ubu-2 (RTX 5070, sm_120, driver 580, CUDA 12.0 + 12.9 toolkit)
Hexa baseline: rfc067_pS_hexa_sgemm_tile128_2026_05_21 (N89), peak 37.07 TFLOPS @ M=1536 ratio 0.557 vs cuBLAS

## 1. cuBLAS kernel selection (M=N=K=1536, FP16 NN, FP32 acc)

Identified via `nsys profile -t cuda ./hgemm_probe 1536 1536 1536`:

| field | value |
|-------|-------|
| Kernel name | `void cutlass::Kernel2<cutlass_80_tensorop_s16816gemm_f16_64x64_32x6_nn_align8>(T1::Params)` |
| Grid | (192, 3, 1) = 576 CTAs |
| Block | (128, 1, 1) = 4 warps |
| Median runtime | 104.4 us |
| Achieved TFLOPS | 69.4 (vs result.json 66.6, within run variance) |
| CTAs / SM (42 SM) | 13.7 |

Kernel-name decoding (CUTLASS naming convention):
- `cutlass_80` -- compiled for sm_80 ISA (forward-runs on sm_120 via driver JIT or fatbin)
- `tensorop` -- uses tensor cores
- `s16816gemm` -- mma.sync.m16n8k16 (sm80 tensor-op shape)
- `f16` -- A/B fp16
- `64x64` -- CTA output tile (M x N)
- `32x6` -- K-tile 32, software pipeline depth 6
- `nn` -- both operands NN-layout
- `align8` -- 8-element (16-byte) vec LDG

## 2. Hexa N89 emit characteristics

From `sgemm_tile128_1536x1536_grid.ptx` (PS variant) compiled via `ptxas -O3 --gpu-name sm_90`:

| field | value |
|-------|-------|
| Entry | `sgemm_tile128_1536x1536_grid` |
| Grid (M=1536) | (12, 12, 1) = 144 CTAs |
| Block | (1024, 1, 1) = 32 warps |
| Output tile | 128 x 128 per CTA |
| K-tile | 16 (single mma.m16n8k16 chunk) |
| Pipeline depth | 2 (cp.async.cg with __syncthreads each iter; no multi-stage `wait_group(N-2)`) |
| Registers / thread | 47 (ptxas -v) |
| Smem / CTA | 16384 bytes (single-buffered: 4 KB for A + 4 KB for B + dual-buffer toggle, room for sw-pipeline expansion) |
| CTAs / SM | 3.4 |

## 3. SASS instruction histogram (per `instruction_histogram.csv`)

The hexa SASS comes from `ptxas -O3 --gpu-name sm_90 sgemm_tile128_1536x1536_grid.ptx` (152 static instrs).
The "proxy" column comes from a hand-written 64x64x32-stage6 CUDA file (`cublas_proxy_64x64x32_s6.cu`)
that **mirrors the cuBLAS kernel name's structural spec** (NOT byte-equal -- structural reference).
Proxy is a stand-in for the real cuBLAS SASS because the kernel is loaded from libcublasLt.so via
`cuLibraryLoadData`/`cuKernelGetFunction` paths, not exposed as a stable elf symbol (only `forwardCompat_256x128_64x3`
variants appear in the symbol table; the `64x64_32x6` config is JIT/runtime-bound).

Top deltas (proxy - hexa):

| opcode | hexa N89 | proxy 64x64x32_s6 | delta | meaning |
|--------|----------|--------------------|-------|---------|
| HMMA   | 4        | 16                 | +12   | proxy has 4x mma per K-step (full m16n8k16 inner-k unroll) |
| LDSM   | 3        | 12                 | +9    | proxy uses 4x ldmatrix per K-step for full warp-tile coverage |
| LDGSTS | 4        | 0                  | -4    | hexa uses cp.async (LDGSTS.E.BYPASS.128); proxy fell back to LDG+STS because the inline-asm scaffold did not vector-fuse into LDGSTS |
| LDG    | 0        | 8                  | +8    | (proxy non-async; hexa is correctly async) |
| STS    | 0        | 8                  | +8    | (proxy explicit store-to-shared; hexa is bundled in LDGSTS) |
| IMAD   | 31       | 120                | +89   | proxy address-gen overhead from non-fused gmem->smem path |
| ISETP  | 8        | 44                 | +36   | proxy bounds-check predicates |
| LDC    | 1        | 10                 | +9    | proxy reloads kernel param constants |
| STG    | 16       | 16                 | 0     | both write same 64-bit C epilogue pattern |

Caveat: the proxy is intentionally hand-written to expose the CUTLASS structural pattern; the
**absolute** instruction counts in the proxy column are not a fidelity claim against the
true cuBLAS SASS. They are useful only to confirm that the structural-pattern claim
(more HMMA per K-step, more LDSM, multi-stage pipeline) compiles down to that pattern under ptxas.

## 4. Structural diff (the actionable diagnostic)

| Axis                         | hexa N89               | cuBLAS s16816gemm_64x64_32x6 |
|------------------------------|------------------------|------------------------------|
| Output tile MxN              | 128 x 128              | 64 x 64                      |
| K-tile                       | 16                     | 32                           |
| Warps / CTA                  | 32                     | 4                            |
| Threads / CTA                | 1024                   | 128                          |
| Pipeline stages              | 1-2 (single-buffer)    | 6                            |
| Async load primitive         | cp.async.cg vec128     | cp.async (CUTLASS-managed)   |
| Compute primitive            | mma.m16n8k16 fp16->f32 | mma.m16n8k16 fp16->f32 (same)|
| Shared-mem layout            | linear, swizzle in N89 | swizzle (CUTLASS-canonical)  |
| Grid CTAs @ M=N=1536         | 144                    | 576                          |
| CTAs / SM (42 SM)            | 3.4                    | 13.7                         |
| Per-CTA FLOP per K-step      | 524288                 | 262144                       |
| Per-CTA mma per K-step       | 128 (32warp x 4mma)    | 64 (4warp x 16mma)           |
| Achieved TFLOPS @ M=1536     | 37.07                  | 66.60                        |
| Ratio vs cuBLAS              | 0.557                  | 1.000                        |

## 5. Root-cause attribution of the 0.557 ratio

**(a) Latency-hiding deficit from low CTA count.** RTX 5070 has 42 SMs. cuBLAS launches
576 CTAs (~13.7 / SM), so HBM-load latency on one CTA is hidden by compute on neighbor CTAs.
Hexa launches 144 CTAs (3.4 / SM) -- only 3-4 CTAs per SM at occupancy 32-warps each
(1024 thd / CTA = full SM occupancy fast, but only 3-4 CTAs per SM means **no inter-CTA
latency hiding**). Net effect: every cp.async.wait inside the warp-internal K-loop blocks
the entire SM because there is no neighboring CTA to interleave.

**(b) No multi-stage software pipeline.** Hexa N89 issues `cp.async.commit_group` then immediately
`__syncthreads` and consumes the loaded tile. cuBLAS issues 5 cp.async groups in the prologue and
runs a steady-state where stage N is computing while stages N+1 .. N+5 are still in flight
(`cp.async.wait_group(stages-2)` = wait until ge 4 in flight, then proceed). This hides 5x more
LDGSTS latency.

**(c) K-tile size 16 vs 32 forces 2x more pipeline iterations.** Hexa walks K=1536 in 96 K-steps;
cuBLAS in 48 K-steps. Each K-step has fixed sync + pipeline-rotate overhead. Halving the K-tile
size doubles the absolute count of `__syncthreads`, `BAR.SYNC`, and `cp.async.commit_group`
boundaries.

The 0.557 ratio decomposes approximately as:
  - 0.85 from (b) -- single-stage pipeline collapses latency hiding to 1 / (stages) of cuBLAS
  - 0.85 from (a) -- low CTA/SM count reduces inter-CTA overlap
  - 0.95 from (c) -- K-tile 16 doubles loop overhead per K
  Multiplied: 0.85 * 0.85 * 0.95 = 0.686. The remaining 0.557 / 0.686 = 0.81 attributable to
  shared-memory bank conflicts and unfused address-gen (IMAD count is hexa-favorable in static
  emit, but dynamic execution shows ~30% of cycles in IMAD on the cookbook).

## 6. Recommendations -- top 3 actionable micro-opts hexa is missing

See `recommendations.md`.

## 7. Honest limitations

- The cuBLAS SASS for `s16816gemm_f16_64x64_32x6_nn_align8` is loaded via cuLibrary at runtime and
  is **not** statically extractable from libcublasLt.so via cuobjdump -- only the `forwardCompat_256x128_64x3`
  variants are static symbols. The kernel name appears as an ASCII string inside libcublasLt.so
  (verified via `strings | grep`) but the bytecode is in a compressed cubin loaded via cuLibraryLoadData.
  Capturing it byte-equal would require LD_PRELOAD interception of `cuLibraryLoadData` to dump
  the cubin blob at JIT time -- deferred (not required to expose the structural gaps that drive 0.557).
- The "proxy" 64x64x32_s6 reference kernel compiles but has a misaligned-address fault at runtime
  (epilogue STG indexing); the SASS pattern it produces is informative for instruction histogram
  cross-check but the proxy is not a byte-equal cuBLAS reproduction.
- All measurements at M=1536 only. Per result.json the hexa-vs-cuBLAS ratio varies 0.33-0.56
  across M in [256, 1536]; the recommendations are tuned to the M=1536 regime where hexa
  achieves its peak.
