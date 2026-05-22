# TMA runtime-builtin requirements (RFC 067 N202+)

**Status**: SCAFFOLD — host-side runtime work, NOT in this cycle.
**Provenance**: N196 (`450ad0cc`) finding + N200 SMOKE (`c5840f19`).
**Precondition for**: hexa source-level matmul that needs TMA on consumer
Blackwell (RTX 5070 sm_120a).
**Companion codegen scaffold**: `compiler/codegen/nvptx_tma_ops.hexa`
(N202 — landed alongside this note).

---

## Why a runtime builtin is required

TMA (Tensor Memory Accelerator) is a producer-consumer DMA path between
GPU global and shared memory introduced on Hopper (sm_90a) and extended
to consumer Blackwell (sm_120a). The kernel-side use is well-described
in the N200 SMOKE artifact
(`inbox/fires/rfc067_ptma_named_bar_hilbert_2026_05_22/sgemm_tma_smoke.ptx`)
and now enumerated in `compiler/codegen/nvptx_tma_ops.hexa`:

    cp.async.bulk.tensor.2d.shared::cluster.global.tile.mbarrier::...
    mbarrier.init.shared.b64
    mbarrier.arrive.expect_tx.release.cta.shared::cta.b64
    mbarrier.try_wait.parity.shared::cta.b64
    fence.proxy.async.shared::cta
    cvta.param.u64

What the kernel CANNOT do is build its own TMA descriptor. The
`CUtensorMap` (128 byte, 64 byte alignment) is opaque to the kernel; the
HOST must call `cuTensorMapEncodeTiled` (CUDA Driver API) to populate it,
then pass the 128 bytes by value via a `.param .align 64 .b8` value-param.

Until the hexa runtime exposes the encoder, no compiled hexa source-level
matmul can take the TMA path — even if codegen emits all the correct
kernel-side opcodes.

---

## Required builtin (host-side, in hexa runtime layer)

### Signature

```hexa
// Returns 128 bytes of descriptor data (CUtensorMap) ready to memcpy
// into a kernel-launch param slot. Returns empty byte array on
// driver error; caller MUST check before launching.
@runtime_builtin
pub fn gpu_tma_encode_tiled_2d(
    global_addr: u64,         // device pointer to global tensor base
    elem_bytes: i64,          // sizeof(elem) — 2 for fp16/bf16, 4 for fp32
    dim0: i64,                // outer dim (rows for row-major 2-D)
    dim1: i64,                // inner dim (cols)
    stride0_bytes: i64,       // byte stride between rows (= dim1 * elem_bytes
                              //   for contiguous row-major)
    box_dim0: i64,            // tile shape outer (smem tile rows)
    box_dim1: i64,            // tile shape inner (smem tile cols)
    swizzle_mode: i64         // 0=none, 1=32B, 2=64B, 3=128B (sm_120a)
) -> [i8]
```

Returned value is exactly `NVPTX_TMA_DESC_BYTES = 128` bytes. The kernel
launch path memcpy's it into a 128-byte aligned param slot.

### CUDA Driver API mapping

The implementation in the runtime layer calls:

```c
CUtensorMap tmap;
CUresult rc = cuTensorMapEncodeTiled(
    &tmap,
    CU_TENSOR_MAP_DATA_TYPE_<elem>,   // derived from elem_bytes
    /*tensorRank=*/2,
    (void*)global_addr,
    (cuuint64_t[]){dim1, dim0},        // CUDA wants inner-first
    (cuuint64_t[]){stride0_bytes},     // strides for non-innermost dims only
    (cuuint32_t[]){box_dim1, box_dim0},
    (cuuint32_t[]){1, 1},              // elementStrides — always 1 for tile
    CU_TENSOR_MAP_INTERLEAVE_NONE,
    swizzle_enum_for(swizzle_mode),
    CU_TENSOR_MAP_L2_PROMOTION_NONE,
    CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE
);
if (rc != CUDA_SUCCESS) return empty_byte_array();
return bytes_from_struct(&tmap, 128);
```

### Variants

For matmul we need at minimum:

- `gpu_tma_encode_tiled_2d` — A and B operands of GEMM (this RFC).
- `gpu_tma_encode_tiled_3d` — convolution NHWC, batch-matmul stacked.
- `gpu_tma_encode_tiled_5d` — full conv input (NDHWC / convolution
  unfold). Listed for symmetry; not in N202 scope.

---

## Descriptor lifetime

The CUDA Driver API caches the encoded descriptor across kernel launches
when the underlying tensor + tile shape do not change. For the hexa
matmul lane, the recommended lifecycle is:

1. **At module load** — for each `@gpu_kernel matmul_*` the linker
   discovered, allocate a small per-shape descriptor cache (host RAM
   only, no device alloc — the descriptor is value-passed by param).
2. **Per call** — first lookup in the cache keyed by
   `(global_addr, dim0, dim1, tile0, tile1, swizzle)`. On miss, call
   `gpu_tma_encode_tiled_2d`, insert. On hit, reuse the 128 B blob.
3. **At module unload** — free the cache. No CUDA-side resource
   release needed (the descriptor is plain memory).

CUDA does NOT require `cuTensorMapDestroy` (there isn't one — the
descriptor is a value type, not a handle). The cache is purely a hexa-
side optimisation.

---

## Param-packing into kernel launch

The kernel signature is:

```ptx
.visible .entry matmul_tma(
    .param .align 64 .b8 tmap_a_param[128],
    .param .align 64 .b8 tmap_b_param[128],
    .param .u64 c_ptr_param
)
```

The launch must:

1. Allocate a 64 byte aligned kernel-arg buffer of size 128+128+8 = 264 B.
2. memcpy the 128-byte A descriptor into offset 0.
3. memcpy the 128-byte B descriptor into offset 128.
4. Store the C global pointer at offset 256.
5. Call `cuLaunchKernel` with a single arg pointer to this buffer.

The 64 byte alignment is mandatory — `cuTensorMapEncodeTiled` requires
the in-kernel `.param` slot be aligned to 64 B per the PTX ISA
`.param .align 64 .b8` directive. Misalignment is silent UB.

---

## Integration point with N128 WMMA matmul lane

The current N128 matmul lane (`compiler/codegen/nvptx_target.hexa`
`_nvptx_emit_matmul_module` + helpers) emits `ld.global` + `cp.async.cg`
for the A and B tile loads. The TMA replacement is a per-K-iter swap:

| **N128 (current, sm_90)**                | **N202+ (future, sm_120a)**                          |
| ---                                       | ---                                                  |
| `ld.global.f16` into reg, `st.shared.f16` | `cp.async.bulk.tensor.2d ... [mbar]`                 |
| OR `cp.async.cg.shared.global`            | (single opcode, hw-coalesced, async)                 |
| `cp.async.commit_group` + `wait_group`    | `mbarrier.arrive.expect_tx` + `try_wait.parity`     |
| (no proxy fence needed)                   | `fence.proxy.async.shared::cta` before consumer mma |
| param: 3x `.param .u64` (A/B/C ptrs)      | param: 2x `.param .align 64 .b8 [128]` + 1x `.u64`  |

The codegen wiring point is `_nvptx_emit_matmul_module`:

- Today it dispatches `matmul` / `matmul_NT_a` / `matmul_NT_b` to the
  WMMA emitter unconditionally.
- N203+ adds a third dispatch axis: if `target_sm == "sm_120a"` AND
  `nvptx_tma_codegen_enabled() == true`, route to a new
  `_nvptx_emit_matmul_tma_module` that uses the
  `cp.async.bulk.tensor` chain instead of `ld.global` + `cp.async.cg`.

The runtime-side decision (which descriptor to encode per call) lives in
the launch path, NOT codegen — codegen only needs to emit the kernel
that expects two 128-byte param slots.

---

## Per-shape TMA descriptor generation — compile-time vs runtime

Two viable approaches:

**A. Runtime (recommended for N202+)**: every kernel call computes the
descriptor at launch time via the runtime builtin. Cost = one `Encode`
call per shape, cached. Pro = no compile-time shape knowledge needed,
works for dynamic shapes (variable `M`/`N`/`K`). Con = small per-call
overhead (~microseconds on first call).

**B. Compile-time MIR baked**: if the MIR shape info is known at compile
time (constant `M`/`N`/`K` in the GPU kernel attribute), the descriptor
can be encoded once at module init. Pro = zero per-call cost. Con =
requires shape constants on the MIR, breaks dynamic-shape kernels.

Recommended: **A first** (covers all cases), B as a later optimisation
gated on a `@gpu_static_shape(M=64, N=64, K=64)` attribute.

---

## Falsifier summary

This note + the N202 scaffold satisfy a **scaffold-only** contract:

- `F-RFC067-NVPTX-TMA-CODEGEN-SCAFFOLD` — `nvptx_tma_ops.hexa` parses
  clean; `nvptx_emit_module_header_for_tma("sm_120a")` returns a
  byte-identical match for the N200 SMOKE header; the existing
  nvptx_target.hexa emit path is byte-identically untouched (no MIR
  routes to TMA opcodes; `nvptx_tma_codegen_enabled()` returns false).

The full integration falsifier (`F-RFC067-NVPTX-TMA-SOURCE-TO-SILICON`)
needs:

1. N200-full kernel (real mma.sync chain + TMA) proven on silicon — a
   sibling lane that's currently launching.
2. The runtime builtin in this doc, implemented in the hexa runtime
   layer (host-side C or hexa shim into `cuTensorMapEncodeTiled`).
3. The N203+ codegen wiring (`_nvptx_emit_matmul_tma_module` +
   feature-flag dispatch in `_nvptx_emit_matmul_module`).

None of those are in N202 — the cycle scope is opcodes enumerated,
header emit scaffolded, integration point documented.

---

## References

- N196 finding: `450ad0cc` on origin/main (TMA on sm_120 requires sm_120a + 8.7)
- N200 SMOKE artifact: `inbox/fires/rfc067_ptma_named_bar_hilbert_2026_05_22/`
- N128 WMMA matmul: `compiler/codegen/nvptx_target.hexa::_nvptx_emit_matmul_module`
- N202 codegen scaffold: `compiler/codegen/nvptx_tma_ops.hexa`
- PTX ISA 8.7: https://docs.nvidia.com/cuda/parallel-thread-execution/
  - §9.7.8.24 (cp.async.bulk.tensor)
  - §9.7.12.15 (mbarrier)
  - §8.5 (proxy fence)
  - §9.7.9.6 (cvta)
  - §7.1.7 (param state space)
- CUDA Driver API: `cuTensorMapEncodeTiled`
  https://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__TENSOR__MEMORY.html
