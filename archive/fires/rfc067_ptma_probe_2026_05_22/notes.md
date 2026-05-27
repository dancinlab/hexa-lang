# RFC 067 PTMA probe -- 2026-05-22

## Question
Does `cp.async.bulk.tensor` (Hopper Tensor Memory Accelerator, TMA) survive on
Blackwell **consumer** SKU (RTX 5070, sm_120), or did NVIDIA carve it out for
datacenter Blackwell only?

This is the gating question for warp-specialized GEMM follow-on. N127 (warp
specialization at mma.sync level) was falsified because full-CTA `bar.sync`
serialized producer/consumer. cuBLAS uses named barriers + TMA to avoid that;
without TMA on consumer Blackwell, warp specialization stays blocked at the
mma.sync layer.

## Verdict
**`TMA_AVAILABLE_BIT_EXACT` on RTX 5070 sm_120.**

* `cuTensorMapEncodeTiled` succeeds on sm_120 (driver 580.159.04).
* `ptxas` (CUDA 12.9, V12.9.86) accepts `cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes` at `.target sm_120a` (PTX `.version 8.7`).
* Driver-JIT (`cuModuleLoadDataEx`) accepts the same PTX on sm_120.
* Kernel runs to completion, `cudaSync` returns success.
* 64x64 fp16 tile read back from `out` is **byte-identical** to the source tile in global memory (mismatch=0/4096 halves, byte_mismatch=0).

## ptxas accept matrix

| `.target` | PTX `.version` | `--gpu-name=sm_90a` | `--gpu-name=sm_120a` |
|-----------|---------------|---------------------|----------------------|
| sm_90a    | 8.4           | OK                  | rejected ("cannot be compiled to future architecture") |
| sm_120a   | 8.7           | --                  | OK |

Forward-compat from a sm_90a-targeted PTX to a sm_120 device through the
driver JIT is NOT permitted ("Program with .target 'sm_90a' cannot be compiled
to future architecture"). PTX must be authored at `.target sm_120a` for this
device. Hexa codegen for TMA-bearing kernels must therefore emit `.target sm_120a`
(or whichever device-matching target) and bump `.version` to 8.7.

## Descriptor encoding notes (CUtensorMap)

The Driver API call that succeeded:
```c
cuTensorMapEncodeTiled(
    &tmap,
    CU_TENSOR_MAP_DATA_TYPE_FLOAT16,
    /*rank=*/ 2,
    (void *)dsrc,
    /*globalDim   = */ { W=128, H=128 },     // innermost first
    /*globalStride[1..] (bytes) = */ { W*2 = 256 },
    /*boxDim       = */ { TILE_W=64, TILE_H=64 },
    /*elemStride   = */ { 1, 1 },
    CU_TENSOR_MAP_INTERLEAVE_NONE,
    CU_TENSOR_MAP_SWIZZLE_NONE,
    CU_TENSOR_MAP_L2_PROMOTION_NONE,
    CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
```
Descriptor is passed to the kernel as a 128-byte `__grid_constant__` value
parameter (PTX: `.param .align 64 .b8 tmap_param[128]`). Inside the kernel,
load via `mov.b64 + cvta.param.u64` to obtain a generic-space address.

## PTX kernel pieces that mattered

Three pitfalls I hit during the bring-up; recording so the codegen and any
future hand-written probe doesn't repeat:

1. **Param-space address conversion**.  `mov.u64 %addr, tmap_param;` returns a
   param-space label, but `cp.async.bulk.tensor` needs a **generic** address.
   Required sequence:
   ```
   mov.b64 %pp, tmap_param;
   cvta.param.u64 %tmap_addr, %pp;
   ```
   Without `cvta.param.u64`, kernel triggers `CUDA_ERROR_ILLEGAL_ADDRESS (700)`
   at the cp.async.bulk.tensor.

2. **`shared::cluster` qualifier (not `shared::cta`)** on the dst-space of
   `cp.async.bulk.tensor`, even on non-cluster launches:
   ```
   cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes
     [%smem_dst], [%tmap, {%x, %y}], [%mbar];
   ```
   Cross-checked against nvcc's emit for `cuda::ptx::cp_async_bulk_tensor`.

3. **Combined `mbarrier.arrive.expect_tx`** is the canonical pattern, not
   separate `expect_tx` + `arrive`. It returns a state token (we drop it for
   the parity-wait variant):
   ```
   mbarrier.init.shared.b64 [%mbar], 1;
   fence.proxy.async.shared::cta;
   cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes
     [%smem_dst], [%tmap, {%x, %y}], [%mbar];
   mbarrier.arrive.expect_tx.release.cta.shared::cta.b64
     %tok, [%mbar], 8192;
   ```

4. **Wait with `try_wait.parity`** (no state token needed):
   ```
   L_try:
     mbarrier.try_wait.parity.shared::cta.b64 %pdone, [%mbar], 0;
     @%pdone bra L_done;
     bra L_try;
   L_done:
   ```
   Parity bit = 0 (waiting for the first / 0-th phase to complete).

## Implication for warp-spec follow-on

TMA + mbarrier-with-tx-tracking are available on RTX 5070 sm_120. This unblocks
the N127 retry path:

* **Producer warp** issues `cp.async.bulk.tensor` for the next K-tile of A/B
  into double-buffered shared memory.
* **Consumer warp(s)** wait on the *tile-local* mbarrier (not full-CTA bar.sync),
  then run mma.sync on the current tile.
* Producer arrives on the *next* mbarrier while consumers are still mma-ing on
  the current.

The full-CTA `bar.sync` serialization that falsified N127 is replaceable with
per-tile mbarriers because TMA's `mbarrier::complete_tx::bytes` mode lets the
DMA engine drive the mbarrier completion directly -- no thread-side sync needed
to declare the load done.

## Honest scope (`@D g3`)

* Single-descriptor smoke only. We did not test:
  - Multiple descriptors / multiple tiles in flight (double-buffer).
  - Box-dim larger than 64x64 (TMA box-dim ceiling differs by dtype/swizzle).
  - Swizzled descriptors (`CU_TENSOR_MAP_SWIZZLE_128B` etc.).
  - Cluster-scope completion (we used cta scope inside `arrive.expect_tx`).
  - Performance comparison vs cp.async (the load is single-shot and serial; no
    perf claim here).
* Driver version 13000 (CUDA 13 era) with toolkit 12.9 ptxas. The "PTX 8.7 +
  .target sm_120a" combo is what worked; CUDA 12.0 ptxas alone would not
  emit cubin for sm_120 since the arch is post-12.0.
* The PTX `.target sm_120a` is mandatory. A `.target sm_90a` PTX targeted at
  a sm_120 device through the driver JIT is **rejected** ("cannot be compiled
  to future architecture"). Future hexa codegen for TMA on consumer Blackwell
  must bump `.target` and `.version` accordingly. The codegen change is a
  follow-up; this probe does not touch compiler source.

## Files
* `tma_probe.ptx`     -- hand-authored PTX kernel (final working version).
* `host.c`            -- driver-API host: tmap encode, JIT load, launch, verify.
* `fire.sh`           -- on-host runner (ptxas accept-checks + nvcc build + fire).
* `fire.log`          -- captured stdout/stderr of the fire.
* `result.json`       -- structured verdict + provenance.
* `notes.md`          -- this file.
