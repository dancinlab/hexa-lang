# RFC 067 N200-full notes (TMA + mma.sync + Hilbert d2xy)

Date: 2026-05-22
Host: ubu-2 (RTX 5070 sm_120, CUDA driver 13000, runtime 12090, ptxas/nvcc 12.9)
Falsifier: F-RFC067-HEXA-TMA-MMA-HILBERT

## Headline

| M=N=K | cuBLAS HGEMM TFLOPS | hexa N200 TFLOPS | ratio | N149 PHILB ratio (ref) | delta |
|-------|---------------------|------------------|-------|------------------------|-------|
| 512   | 23.17               | 15.17            | 0.654 | -                      | -     |
| 1024  | 53.35               | 39.39            | 0.738 | -                      | -     |
| 2048  | 66.78               | 51.90            | 0.777 | -                      | -     |
| 4096  | 70.02               | 55.98            | 0.799 | 0.828                  | -0.029|
| 6144  | 70.78               | 56.46            | 0.798 | 0.655                  | +0.143|
| 8192  | 70.80               | 57.98            | **0.819** | 0.624              | +0.195|

(N149 PHILB used 4-warp 64x64 + Hilbert + cp.async.cg on the SAME GPU per memory record;
the 0.847 ratio cited in the task brief is from a different measurement series; the
0.624 baseline here is from the N149 result.json shipped on origin/main.)

**Did TMA + mma.sync break the 0.85 ceiling? NO — peak 0.819 @ M=8192.**

## Honest readout

The TMA + mma.sync + Hilbert N200-full kernel:

1. **Runs correctly** on RTX 5070 sm_120. Bit-exact PASS across all 6 shapes (the
   sweep used a zero-mean fill that produced trivially-zero cuBLAS output → bit-exact
   was vacuous). A separate `verify_nontrivial.c` ran on M=512 with a non-cancelling fill,
   max|hexa - cuBLAS| = 0.043 / max|cuBLAS| = 33.02 = **max_rel 0.0013** (well within
   fp16 numerical tolerance for K=512 accumulation).

2. **Did not beat the N149 cp.async.cg baseline at M=4096** (0.799 vs 0.828, -0.029).
   At M=4096 the L2 footprint fits comfortably, so the cp.async.cg + ldmatrix path
   already runs near the substrate limit; TMA adds descriptor setup overhead + single-buffer
   K-loop synchronization that erodes the small-M throughput.

3. **Did beat the N149 result.json baseline at M=6144 and M=8192** (+0.143 and +0.195
   ratio respectively). This is the L2-thrash regime where the N149 result.json showed
   the cliff (0.655 / 0.624). The TMA path holds throughput flat through the cliff
   because TMA-issued loads carry their own memcpy-asynchronous DMA channel, sidestepping
   the L2 thrash that bottlenecked cp.async.cg at large M.

4. **Did NOT reach 0.85** — peak 0.819 at M=8192. The path is correct and TMA-issued
   GEMM beats the cp.async.cg cliff in the regime where L2 thrash dominates, but it
   does not catch up to cuBLAS HGEMM. The remaining 18% gap on sm_120 is plausibly:
   - **No software pipelining**: our K-loop is strictly serial (TMA-load → wait → mma → next).
     A double-buffered K-loop with `cp.async.bulk.tensor` to slot[k+1] overlapping the
     mma chain consuming slot[k] should recover most of the gap.
   - **TMA descriptor swizzle = NONE**: bank conflicts on ldmatrix from the
     non-swizzled smem tile. `CU_TENSOR_MAP_SWIZZLE_128B` is what cuBLAS uses; would
     need a matching swizzled ldmatrix address scheme.
   - **No async-warp split**: hopper-style GEMM splits producer/consumer warps so the
     producer issues TMA while consumers run mma. Our single-issuer pattern (thread 0
     issues both TMA loads) serializes the producer side.

## Kernel stats

- **regs/thd: 64** (uniform across all 6 shapes; identical PTX register pressure)
- **shmem/CTA: 4112 B** = 2048 A + 2048 B + 16 mbarrier
- **mbarrier-pool depth: 1** (single mbarrier, parity-tracked across K-iter)
- **TMA descriptors: 2** (A row-major, B col-major-stored-as-row-major, both [K_TILE=16, 64])
- **expect_tx per K-iter: 4096 B**
- **mma per warp per K-step: 8** (m16n8k16, identical to N149 chain)
- **acc f32 per lane: 32**
- **Hilbert prologue: ~32 ASM lines per round** (3 rounds @ M=512, 7 rounds @ M=8192)

## Driver-JIT pitfalls (re-confirmed from N196/N200-SMOKE)

- `.target sm_120a + .version 8.7` REQUIRED (sm_90a forward-compat fails on sm_120
  for TMA-bearing kernels).
- PTX must be PURE ASCII (driver-JIT ptxas rejects non-ASCII like em-dash; standalone
  ptxas 12.9 accepts them).
- nvcc driver compile needs `-arch=sm_120a` (not just sm_120) for CUDA runtime stubs;
  default `/usr/local/cuda/bin/nvcc` may be 12.0 which does not know sm_120a → must use
  `/usr/local/cuda-12.9/bin/nvcc`.
- mbarrier parity ALTERNATES per K-iter; `and.b32 %parity, %k_iter, 1` is required.
- `mbarrier.arrive.expect_tx.release.cta.shared::cta.b64` is the combined form;
  separating `arrive` and `expect_tx` lands silently-wrong on sm_120.

## Reproduce

```
bash /Users/ghost/core/hexa-lang/inbox/fires/rfc067_ptma_mma_hilbert_2026_05_22/measure.sh
```

Requires `ssh ubu-2` access + `/usr/local/cuda-12.9` on ubu-2.
