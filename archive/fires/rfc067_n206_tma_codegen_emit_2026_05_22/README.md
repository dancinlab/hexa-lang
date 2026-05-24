# RFC 067 N206 — TMA matmul codegen-emit source-to-silicon fire

**Status**: PASS on ubu-1 RTX 5070 sm_120, 0 mismatches across 256 cells.
**Date**: 2026-05-22
**Falsifier**: F-RFC067-NVPTX-TMA-SOURCE-TO-SILICON (codegen-emit half).

## What this proves

The hexa NVPTX codegen now emits a **TMA + mbarrier** PTX module
(cp.async.bulk.tensor.2d + mbarrier.init/arrive/try_wait + fence.proxy.async)
for the sm_120a target, gated behind the `HEXA_NVPTX_TMA=1` env flag.
The emitted PTX runs **byte-for-byte equivalent** to the hand-written N200
SMOKE artifact and verifies TMA-loaded shared memory matches the host-
side input data after `cp.async.bulk.tensor` completes.

This closes the **codegen half** of source-to-silicon TMA on consumer
Blackwell.

## Pipeline

```
            HEXA_NVPTX_TMA=1
                    ↓
codegen_emit_ptx_for_sm(module, "sm_120a")
                    ↓
_nvptx_emit_matmul_module(...)             # nvptx_target.hexa:4830
                    ↓  target == sm_120a + flag on
_nvptx_emit_matmul_tma_module(name, ...)   # nvptx_target.hexa:4870
                    ↓
sgemm_tma_codegen.ptx (104 lines)
                    ↓
cuModuleLoadDataEx (driver JIT, sm_120a)
                    ↓
cuLaunchKernel on RTX 5070
                    ↓
TMA_SMOKE_PASS (0 mismatches / 256 cells)
```

## Files

- `sgemm_tma_codegen.ptx` — the codegen-emitted PTX (104 lines).
- `fire_ubu1_PASS.log` — silicon-fire stdout (TMA_SMOKE_PASS).
- `../rfc067_ptma_named_bar_hilbert_2026_05_22/host.c` — reused N200
  SMOKE host driver (cuTensorMapEncodeTiled + kernel launch). Same
  kernel name `sgemm_tma_smoke` so this driver fires the codegen-
  emitted PTX without modification.
- `emit_tma_ptx.hexa` — the hexa source that calls
  `_nvptx_emit_matmul_tma_module` and writes PTX to stdout.

## Reproduction

```sh
# Mac local — codegen the PTX
export HEXA_MODULE_LOADER=$HOME/core/hexa-lang/build/hexa_module_loader
export HEXA_LANG=$HOME/.hx/bin/hexa.real
export HEXA_MAC_BUILD_OK=1
~/.hx/bin/hexa build inbox/fires/rfc067_n206_tma_codegen_emit_2026_05_22/emit_tma_ptx.hexa -o /tmp/emit_tma
/tmp/emit_tma > sgemm_tma_codegen.ptx

# ubu-1 (RTX 5070) — fire it
scp sgemm_tma_codegen.ptx ubu-1:/tmp/rfc067_n206_tma_codegen/
ssh ubu-1 'cd /tmp/rfc067_n206_tma_codegen && ./host_n206 sgemm_tma_codegen.ptx'
# => TMA_SMOKE_PASS (0 mismatches / 256 cells)
```

## Honest scope (@D g3)

- **What works (this cycle)**: codegen-emit of the SMOKE-level TMA matmul
  kernel (TMA load A, TMA load B, mbarrier sync, smem→C write-back as
  fp32). Demonstrates TMA reaches shared memory and the host-issued
  CUtensorMap descriptors are consumed correctly by the kernel.
- **What is NOT yet codegen-emitted**: the full mma.sync.m16n8k16
  HGEMM chain (8 mma per warp × 4 K-iters) + Hilbert d2xy CTA swizzle
  from the N200-full artifact. The kernel here emits the load + sync +
  write-back, not the mma compute.
- **Runtime-builtin gap**: `gpu_tma_encode_tiled_2d` (host-side
  `cuTensorMapEncodeTiled` wrapper) is NOT yet implemented in the hexa
  runtime layer. Today the host driver (C) calls
  `cuTensorMapEncodeTiled` directly. See
  `inbox/notes/2026-05-22-tma-runtime-builtin-requirements.md`.
- **Natural-loop matcher dependency**: this cycle uses the explicit
  codegen entry point `_nvptx_emit_matmul_tma_module(name, target, ver)`
  rather than driving through the natural-loop matcher (N143
  `_hir_is_nested_matmul_body`), which is currently wiped from
  compiler/lower/hir_to_mir.hexa on this worktree. Re-restoring the
  N143 matcher is a follow-on cycle (path-limited cherry-pick from
  c440d002 + 34e5dc10).

## Verifier contract

- `_nvptx_emit_matmul_tma_module("sgemm_tma_smoke", NVPTX_TARGET_SM120A, NVPTX_PTX_VERSION_SM120A)`
  produces 104 lines of PTX containing:
  * `.version 8.7` + `.target sm_120a` + `.address_size 64`
  * `.visible .entry sgemm_tma_smoke(.param .align 64 .b8 tmap_a_param[128], ..., .param .u64 c_ptr_param)`
  * `cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::complete_tx::bytes` (×2 — A and B loads)
  * `mbarrier.init.shared.b64` + `mbarrier.arrive.expect_tx.release.cta.shared::cta.b64` + `mbarrier.try_wait.parity.shared::cta.b64`
  * `fence.proxy.async.shared::cta` (proxy fence between TMA async and generic proxy)
  * `cvta.param.u64` (×2 — A and B descriptor param→generic addr conversion)
- Default behavior (no env): WMMA path. Default behavior (`HEXA_NVPTX_TMA=1`): TMA path.
- `codegen_emit_ptx_for_sm(matmul_module, "sm_120a")` with flag off must NOT contain
  `cp.async.bulk.tensor` or `mbarrier.*` (regression guard for the byte-identical contract).

## Provenance

- N196 (`450ad0cc`): TMA available on RTX 5070 sm_120 at `.target sm_120a + .version 8.7`.
- N200 SMOKE (`c5840f19`): first hexa-shaped TMA+SGEMM kernel bit-exact on sm_120.
- N202 (`d9c08721`): TMA codegen scaffold (this cycle's predecessor).
- N206 (this artifact): TMA codegen E2E — feature flag + dispatch + source-to-silicon.
