# Phase 4-D-5-1 — runtime.c GPU substrate wiring notes (2026-05-17)

> Scaffold-only sub-phase of Phase 4-D-5 cuBLAS wire-up (see
> `PHASE4D5_CUBLAS_WIRE_DESIGN.md`). Wires the runtime.c `#ifdef HEXA_CUDA`
> call sites that have a corresponding `_hx_cuda_*` body in
> `self/cuda/runtime_cuda.c`. Honestly leaves Phase B/B2 GPU paths as
> `return -1` until their `__global__` kernel bodies land in a CUDA TU.

## Audit summary (commit a3033da8, pre-wire)

Initial TODO[cuda] survey of `self/runtime.c` (12 sites) cross-referenced
against `self/cuda/runtime_cuda.c` (6 implemented `_hx_cuda_*` bodies):

| runtime.c site | line | _hx_cuda_ body exists? | wire status |
|---|---|---|---|
| `hexa_farr_free` cudaFree | 8309 | **YES** (`_hx_cuda_farr_device_free`) | **WIRED THIS CYCLE** |
| Phase A doc-line wording | 8186 | n/a (comment) | **UPDATED THIS CYCLE** |
| `hexa_cuda_available` | 10753 | YES | already wired (pre-cycle) |
| `hexa_cuda_device_count` | 10763 | YES | already wired (pre-cycle) |
| `hexa_farr_to_device` | 10781 | YES | already wired (pre-cycle) |
| `hexa_farr_to_host` | 10798 | YES | already wired (pre-cycle) |
| `hexa_farr_device_free` | 10823 | YES | already wired (pre-cycle) |
| `hexa_farr_matmul_gpu` | 10861 | YES (flagship Dgemm) | already wired (pre-cycle) |
| Phase A doc-block wording | 10716-10722 | n/a (comment) | **UPDATED THIS CYCLE** |
| matmul_gpu body comment | 10833-10838 | n/a (comment) | **UPDATED THIS CYCLE** |
| `hexa_farr_softmax_rows_gpu` | 11062 | NO | stays -1 (no body) |
| `hexa_farr_rmsnorm_rows_gpu` | 11082 | NO | stays -1 (no body) |
| `hexa_farr_add_gpu` | 11098 | NO | stays -1 (no body) |
| `hexa_farr_scale_gpu` | 11113 | NO | stays -1 (no body) |
| `hexa_farr_matmul_t_gpu` | 11429 | NO | stays -1 (no body) |
| `hexa_farr_outer_gpu` | 11446 | NO | stays -1 (no body) |
| `hexa_farr_mul_gpu` | 11460 | NO | stays -1 (no body) |
| `hexa_farr_silu_gpu` | 11473 | NO | stays -1 (no body) |
| `hexa_farr_silu_grad_gpu` | 11486 | NO | stays -1 (no body) |
| `hexa_farr_rmsnorm_bwd_rows_gpu` | 11502 | NO | stays -1 (no body) |
| `hexa_farr_adamw_step_gpu` | 11531 | NO | stays -1 (no body) |

**Key finding**: Phase A (matmul + residence management) is FULLY landed
in `self/cuda/runtime_cuda.c` (251 LOC of real cuBLAS Dgemm + mirror-table
H2D/D2H). Phase B (4 ops) + Phase B2 (7 ops) are pending — extern
forward-decls exist in `runtime.c` lines 10926-11181 but no `_hx_cuda_*`
bodies are defined anywhere. Wiring them would yield link-failure on a
CUDA build (undefined symbol).

## What was wired this cycle

### Wire 1 — `hexa_farr_free` cudaFree path (line 8307-8320)

The on-free cudaFree call was previously a comment-only stub:

```c
#ifdef HEXA_CUDA
    if (e->d_buf) {
        /* TODO[cuda] Phase A impl: cudaFree(e->d_buf); */
        e->d_buf = NULL;
    }
#else
    e->d_buf = NULL;
#endif
```

Now wired to the existing Phase A device-free body:

```c
#ifdef HEXA_CUDA
    extern int _hx_cuda_farr_device_free(int64_t farr_id);
    if (e->d_buf) {
        (void)_hx_cuda_farr_device_free(id);  /* cudaFree + slot zero */
        e->d_buf = NULL;
    }
#else
    e->d_buf = NULL;
#endif
```

This closes a Phase A device-buffer leak: prior to this wire, freeing a
host farr while it had a mirror-resident device buffer would null the
runtime.c `e->d_buf` field without releasing the `cudaMalloc`'d region in
`self/cuda/runtime_cuda.c`'s `g_slots[id].d_buf`. The mirror slot would
accumulate orphaned device pointers across the run.

### Wire 2 — comment hygiene (3 doc-blocks)

Three doc-blocks were updated to reflect actual Phase A LANDED state
(replacing stale "scaffolding cycle returns -1" wording with the
substrate-truth from `self/cuda/runtime_cuda.c`):

- runtime.c line 8181-8187 (struct doc): "cuBLAS Dgemm + cudaMalloc are
  TODO[cuda] stubs" → "wired (Phase 4-D-5-1, 2026-05-17) to the cuBLAS
  Dgemm + cudaMalloc/cudaMemcpy bodies in self/cuda/runtime_cuda.c"
- runtime.c line 10716-10732 (Phase A dispatcher header): expanded into
  a per-symbol wire-status table + honest Phase B/B2 carveout
- runtime.c line 10833-10838 (matmul_gpu body comment): "scaffolding
  cycle the body is the TODO[cuda] stub" → "LANDED — Phase 4-D-5-1
  wire-up; fp64 strict Dgemm, no Tensor Core flip"

No semantic change in these comment edits (g_inbox_dual_track is
inapplicable here — no builtin / operator / runtime intrinsic was added
or modified; comment hygiene only).

## What was NOT wired (and why)

11 Phase B/B2 GPU sites still return `-1` under `-DHEXA_CUDA`. Reason:
the matching `_hx_cuda_*_gpu` symbols are forward-declared in `runtime.c`
but **not defined** anywhere in the tree. Wiring them with no body would
break the next-sub-phase CUDA-host link with "undefined reference"
errors. The honest no-fake-PASS pattern (return -1) preserves the
RFC 040 §"Honest caveats" contract.

The next-cycle deliverable (Phase 4-D-5-2 or a new RFC 041 sub-phase) is
the matching `__global__` kernel bodies in `self/cuda/runtime_cuda.c`
(or a new `.cu` TU). Pre-existing forward-decl signatures are stable —
the bodies just need to land.

## Verification (this cycle)

### F-RFC040-MAC-BUILD-PRESERVED ✅
- `clang -O2 -I . -c self/runtime.c` → 0 errors, 0 warnings (no-CUDA)
- `clang -O2 -I . -DHEXA_CUDA -c self/runtime.c` → 0 errors, 0 warnings
  (syntactic — link would need cuda toolkit, scope = 4-D-5-3)
- `bash tool/flame_phase4b3_verify_all.sh`:
  - 5/5 leaf fwd byte-eq PASS (rmsnorm, residual, swiglu, rope, attention)
  - 3/3 mechanism probes within expected ranges
  - State IDENTICAL to pre-edit baseline

### F-RFC040-CUDA-BUILD-COMPILES (scoped OUT, next sub-phase)
This sub-phase verified Mac-side compile-only. The link-step verification
on a CUDA host (-lcudart -lcublas + runtime_cuda.c co-compile) is sub-
phase 4-D-5-3 (zero-budget remote build verify, no fire).

### F-RFC047-A2-PATHB-FULL-BYTE-EQ (regression gate)
24/24 PRESERVED on the leaf battery layer. IPCP / A2 wrapper builds were
pre-existingly broken (flame transpiler emission bug emits undeclared
identifiers in `_db_grad_accum_farr` / `_db_*_fwd` lowered C — orthogonal
to runtime.c wiring; reproduces on the un-edited baseline).

## Next sub-phases (honest scope)

| sub-phase | what | effort | cost | depends-on |
|---|---|---|---|---|
| 4-D-5-2 | Phase B/B2 GPU `_hx_cuda_*` bodies in `self/cuda/runtime_cuda.c` (or new .cu TU). 11 kernels: 4 Phase B + 7 Phase B2. | 2-3 cycles | $0 (local, CUDA host scoped) | runtime_cuda.c extern decls (LANDED) |
| 4-D-5-3 | CUDA host build verify: `clang/nvcc -DHEXA_CUDA -lcudart -lcublas` co-compile + link of `runtime.c + runtime_cuda.c`. F-RFC040-CUDA-BUILD-COMPILES gate. | 1 cycle | $0 (build only, no run) | 4-D-5-2 OR landed Phase A subset only |
| 4-D-5-4 | **Phase 4-D-4-second fire** — CUDA-enabled binary on A100, F-RFC046-EAGER-PYTORCH-MATCH wall ≤437.9s | 1 cycle | **$5-20** | 4-D-5-3 PASS |
| 4-D-5-5 | RFC 046 ship + RFC 040 close-out | 1 cycle | $0 | 4-D-5-4 PASS |

**Alternative path** (if Phase B/B2 bodies are deferred): 4-D-5-3 can
proceed with Phase A only (matmul + residence). Flame's A2 primitives
emit single-threaded naive C matmul today; routing them to cuBLAS Dgemm
alone (matmul_gpu) is the dominant-FLOP win — Phase B (softmax / rmsnorm
/ add / scale) and Phase B2 (matmul_t / outer / mul / silu / silu_grad /
rmsnorm_bwd / adamw) are memory-bound or sub-dominant compared to the
matmul layer at d=768·12L scale. Per Phase 4-D-4 FAIL RCA, the matmul is
the bottleneck (~10¹¹ flops/step); a matmul-only cuBLAS route may already
clear the F-RFC046 wall gate.

## Cross-link

- Phase 4-D-5 design (sub-phase parent): `stdlib/flame/PHASE4D5_CUBLAS_WIRE_DESIGN.md`
- Phase 4-D-4 FAIL RCA: `state/flame_phase4d_20260517_102511/RESULTS.md`
- RFC 040 substrate landed: `self/cuda/runtime_cuda.c`
- RFC 041 (future .cu kernels): `docs/rfc/rfc_drafts_2026_05_12/rfc_041_*.md`
- RFC 050 forge↔flame integration: `docs/rfc/rfc_drafts_2026_05_12/rfc_050_flame_forge_integration.md`
- AGENTS.tape §0 nn_stack (flame:forge :: torch:ATen)
- Verify_all script: `tool/flame_phase4b3_verify_all.sh` (24 artifact battery)
