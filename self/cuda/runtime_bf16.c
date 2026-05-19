/* runtime_bf16.c — forge RFC 049 Stage 2: BF16 mixed-precision substrate.
 *
 *   Status: Stage 2 SCAFFOLD (storage class + kernel-entry signatures).
 *           Stage 2 kernel-body fire-validation = follow-up cost-bearing
 *           cycle. Stage 1 (the BF16 fused FFN kernel itself) is ALREADY
 *           MEASURED PASS — see self/cuda/experiments/r049_bf16_fused_ffn.cu
 *           (9.67x FP64 cuBLAS Dgemm chain on A100, Llama-7B FFN scale,
 *           state/forge_phaseR_r049_bf16_2026_05_17). This file is the
 *           wiring that turns that proven kernel into a forge substrate
 *           storage class — it adds no new measured claim.
 *
 * ─── Relationship to runtime_cuda.c (RFC 040 FP64 substrate) ──────────
 *
 *   runtime_cuda.c hosts the FP64 substrate: the `_CudaFarrSlot` device
 *   mirror table (FP64 `double* d_buf`) + cuBLAS Dgemm dispatch. This
 *   file is its SIBLING for the BF16 tier: a parallel `farr_bf16` storage
 *   class (2-byte `__nv_bfloat16` elements) + `*_bf16_gpu` kernel entry
 *   points. runtime_cuda.c `#include`s this file at the end of its
 *   translation unit so both substrates share one `nvcc -x cu` build.
 *
 *   This file is written so that on a NO-CUDA host (a Mac without the
 *   CUDA toolkit) it `cc -fsyntax-only`s clean as plain C: every line
 *   that needs a CUDA header or the cuBLAS handle is inside
 *   `#ifdef HEXA_CUDA`. With HEXA_CUDA undefined, only portable C
 *   (struct decls, plain helpers, honest-stub bodies) remains — the same
 *   pattern runtime_cuda.c uses for its Phase B elementwise block.
 *
 * ─── Cross-precision determinism contract (RFC 049 §"Cross-precision
 *     determinism contract", item 4 — encoded here as the function-
 *     signature surface; PROOF is the Stage 2 fire's job, NOT this
 *     scaffold's) ────────────────────────────────────────────────────
 *
 *   C1. WITHIN-PRECISION WITHIN-RUN bit-equal.
 *       Two invocations of the SAME `*_bf16_gpu` entry point with the
 *       SAME farr inputs, SAME batch size, on the SAME single GPU in
 *       the SAME single process MUST produce byte-identical BF16
 *       output. This is the FP64 D' anchor (within-run determinism
 *       FREE) generalised to BF16. Mechanism: cuBLAS GemmEx pinned to
 *       CUBLAS_GEMM_DEFAULT_TENSOR_OP (deterministic algo), no
 *       atomic-add to HBM, single-stream ordering. RFC 049 Stage 1
 *       MEASURED this PASS 3/3 shapes (within-run biteq) — Stage 2
 *       carries the same anchor.
 *
 *   C2. CROSS-PRECISION is NOT bit-equal — honest caveat.
 *       FP64 vs BF16 outputs of the same logical op are numerically
 *       close (RFC 049 Stage 1 measured 1.20-1.51% relative divergence;
 *       LayerCast paper anchor <= 3.4%) but they are NOT byte-equal and
 *       MUST NOT be compared with memcmp. forge's BF16 oracle compares
 *       against a BF16 CPU reference (RNE rounding), never against the
 *       FP64 path.
 *
 *   C3. CROSS-BATCH-SIZE is NOT bit-equal on the BF16 substrate.
 *       A different batch size changes the reduction tree; BF16's
 *       7-bit mantissa makes that reordering observable (LayerCast
 *       paper §3). The FP64 substrate D' has no such limitation — the
 *       BF16 D' boundary is strictly narrower (same-process +
 *       same-batch + same-GPU). Callers requiring batch-stable output
 *       MUST hold batch size fixed.
 *
 *   C4. PEDANTIC has no BF16 equivalent.
 *       FP64 PEDANTIC mode (cross-mode bit-equal) cannot be offered for
 *       BF16: GemmEx Tensor Core algos reduce in algo-dependent order.
 *       forge_tier_v1.c already returns FORGE_PRECISION_UNSUPPORTED for
 *       PEDANTIC + non-FP64 (RFC 049 §3.3) — this scaffold keeps that
 *       contract; no PEDANTIC entry point is declared here.
 *
 * ─── 3-layer cast pyramid (RFC 049 §"Architecture") ───────────────────
 *
 *   L1 master weights  : FP64 packed-double farr (runtime_cuda.c slot
 *                        table). AdamW state lives here. Untouched by
 *                        this file.
 *   L2 compute weights : BF16 `farr_bf16` storage class (THIS FILE) —
 *                        half-width arena, 2 bytes/elem.
 *   L3 compute         : BF16 Tensor Core, FP32 accumulator
 *                        (CUBLAS_COMPUTE_32F). Output cast FP32->BF16
 *                        at the epilogue.
 *
 * ─── RFC 052 compatibility note ───────────────────────────────────────
 *
 *   The `*_bf16_gpu` entry points declared here are the sm_80+
 *   single-block path (RFC 049). RFC 052 (Hopper sm_90+ BF16 WMMA + DSM
 *   cluster combined kernel) is a SUPERSEDING upper tier reachable
 *   through the SAME entry points: a Stage 2 dispatcher selects the
 *   RFC 052 cluster kernel when cc.major >= 9 and falls back to the
 *   RFC 049 body here on sm_80. The signatures below therefore carry
 *   NO sm_90-only argument — the cluster decision is internal to the
 *   kernel body, exactly as RFC 052 §6.5 fallback chain specifies. A
 *   future RFC 052 Stage 2 may add `hexa_farr_ffn_bf16_dsm_gpu` as a
 *   sibling; this scaffold does not pre-empt that name.
 *
 * ─── Governance ───────────────────────────────────────────────────────
 *
 *   g5 (hexa-native-only): forge's C/CUDA layer is the sanctioned
 *     substrate exception — the `.cu` body is a portable artifact built
 *     via nvcc, NOT an LLVM/C-transpile architecture backend.
 *   g3 (real-limits-first): every perf number referenced here traces to
 *     RFC 049 Stage 1's MEASURED fire or the LayerCast / NVIDIA datasheet
 *     literature anchors in the RFC. This file adds no new claim.
 *   No n=6 lattice numerology — BF16 = 2 bytes, FP64 = 8 bytes are IEEE
 *     754 / __nv_bfloat16 facts (f1/f2 deny clear).
 */

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ════════════════════════════════════════════════════════════════════
 * BF16 storage class — `farr_bf16`
 *
 * The FP64 substrate (runtime_cuda.c) keys its device mirror by farr_id
 * into the host `_hx_farr_table` (HexaFarrEntry, FP64 `double* buf`).
 * The BF16 tier needs its own descriptor because a BF16 element is
 * 2 bytes, not 8 — it cannot share the FP64 HexaFarrEntry. `HexaFarrBf16`
 * is the half-width sibling: an opaque handle the forge dispatcher
 * allocates, fills (H2D from an FP64 master via RNE cast, or directly),
 * hands to a `*_bf16_gpu` kernel, then reads back (D2H).
 *
 * Lifetime: caller-managed, mirroring forge_tier_v1.h ForgeArgs — no
 * hidden alloc, no hidden free (RFC 035/040 arena-ownership invariant).
 * ════════════════════════════════════════════════════════════════════ */

/* Element-tag for the BF16 tier. Kept as a plain enum so the struct is
 * portable C even on a no-CUDA host. */
enum {
    FARR_BF16_LOC_HOST   = 0,   /* host buffer authoritative              */
    FARR_BF16_LOC_DEVICE = 1,   /* device buffer authoritative            */
    FARR_BF16_LOC_MIRROR = 2    /* host + device in sync                  */
};

/* BF16 storage descriptor. `h_buf` / `d_buf` are void* so this header
 * stays parseable as plain C without <cuda_bf16.h>; the CUDA-side code
 * casts them to `__nv_bfloat16*`. Each BF16 element is 2 bytes — the
 * half-width arena RFC 049 §"Components" item 1 calls for (75% storage
 * reduction vs the FP64 packed-double farr). */
typedef struct HexaFarrBf16 {
    void*    h_buf;     /* host-side __nv_bfloat16 buffer, or NULL         */
    void*    d_buf;     /* device-side __nv_bfloat16 buffer, or NULL       */
    int64_t  len;       /* element count                                  */
    int      loc;       /* one of FARR_BF16_LOC_*                          */
    int      owns;      /* 1 = this descriptor owns its buffers (free OK)  */
} HexaFarrBf16;

/* Bytes-per-element for the BF16 tier. IEEE 754 bfloat16 / NVIDIA
 * __nv_bfloat16 is a 16-bit type. Not a lattice constant — a hardware
 * fact (f1/f2 deny clear). */
#define HEXA_FARR_BF16_ELEM_BYTES 2

/* ─── storage-class lifecycle (host side, portable) ───────────────────
 *
 * These four are declared unconditionally — the HOST-side bookkeeping
 * (descriptor alloc, host buffer malloc/free) is portable C and useful
 * even on a no-CUDA build for the BF16 CPU reference oracle. The
 * device-touching bodies live in the HEXA_CUDA block below. */

/* Allocate a BF16 storage descriptor + host buffer of `len` elements.
 * Returns NULL on OOM. Zero-fills the host buffer. */
HexaFarrBf16* hexa_farr_bf16_alloc(int64_t len);

/* Free a BF16 descriptor and any buffers it owns (host + device).
 * Safe on NULL. */
void hexa_farr_bf16_free(HexaFarrBf16* f);

/* RNE cast helpers — FP64 master <-> BF16 storage. Round-to-nearest-even
 * is the IEEE 754 default; the device path uses __float2bfloat16 (RNE),
 * the host reference path here mirrors that contract. `n` elements.
 * Returns 0 ok / -1 on bad args. Host-side, portable (the BF16 CPU
 * reference oracle, RFC 049 §Authority g_blue_closed_mandate). */
int hexa_farr_bf16_from_f64(const double* src, HexaFarrBf16* dst, int64_t n);
int hexa_farr_bf16_to_f64(const HexaFarrBf16* src, double* dst, int64_t n);

/* ─── H2D / D2H (device side — only meaningful with CUDA) ──────────────
 *
 * Declared unconditionally so callers compiled on any host see a stable
 * ABI; the no-CUDA body is an honest stub returning -1. */

/* Upload host BF16 buffer -> device (cudaMalloc on demand). 0 ok / -1. */
int hexa_farr_bf16_to_device(HexaFarrBf16* f);

/* Download device BF16 buffer -> host. 0 ok / -1. */
int hexa_farr_bf16_to_host(HexaFarrBf16* f);

/* ════════════════════════════════════════════════════════════════════
 * `*_bf16_gpu` kernel entry points (RFC 049 §"Components" item 2)
 *
 * These are the substrate-level surface the forge dispatcher
 * (forge_tier_v1.c, FORGE_PREC_LAYERCAST_BF16_FP32 / FORGE_PREC_PURE_BF16)
 * routes BF16 work to. Each is the BF16 sibling of an existing FP64
 * `_hx_cuda_farr_*_gpu` entry in runtime_cuda.c.
 *
 * Determinism contract C1 (within-precision within-run bit-equal)
 * applies to ALL of these; C2/C3/C4 caveats apply (see file header).
 *
 * Stage 2 status: SIGNATURES landed. Bodies delegate to the MEASURED
 * Stage 1 kernel pattern (r049_bf16_fused_ffn.cu cuBLAS GemmEx BF16
 * path) OR are honest fire-validation-pending stubs — the production
 * kernel fire is the follow-up cost-bearing cycle, NOT this scaffold.
 * ════════════════════════════════════════════════════════════════════ */

/* BF16 matmul: row-major C[M,N] = A[M,K] @ B[K,N], all `farr_bf16`.
 * cuBLAS GemmEx, CUDA_R_16BF input, CUBLAS_COMPUTE_32F (FP32 accumulator),
 * CUDA_R_16BF output, CUBLAS_GEMM_DEFAULT_TENSOR_OP (BF16 Tensor Core on
 * sm_80+, deterministic algo → contract C1). Sibling of
 * runtime_cuda.c::_hx_cuda_farr_matmul_gpu. 0 ok / -1 err. */
int hexa_farr_matmul_bf16_gpu(HexaFarrBf16* A, int64_t M, int64_t K,
                              HexaFarrBf16* B, int64_t N,
                              HexaFarrBf16* C);

/* BF16 fused FFN: Y = SiLU(X @ W1) @ W2. The exact chain RFC 049 Stage 1
 * MEASURED at 9.67x FP64 cuBLAS Dgemm (Llama-7B FFN, A100 — see
 * r049_bf16_fused_ffn.cu). Activation in FP32 (LayerCast storage/compute
 * split), GemmEx BF16 for both matmuls. X[M,D], W1[D,FD], W2[FD,D],
 * Y[M,D]. 0 ok / -1 err. */
int hexa_farr_ffn_bf16_gpu(HexaFarrBf16* X, int64_t M, int64_t D, int64_t FD,
                           HexaFarrBf16* W1, HexaFarrBf16* W2,
                           HexaFarrBf16* Y);

/* LayerCast linear: Y[M,N] = X[M,K] @ W[K,N], W in BF16 storage, X and
 * Y in FP32, FP32 compute (just-in-time upcast per linear — LayerCast
 * paradigm, arxiv 2506.09501). The MEASURED pattern from
 * r049_layercast_linear.cu. X / Y are plain FP32 device-or-host arrays;
 * only the weight uses the BF16 storage class. 0 ok / -1 err. */
int hexa_farr_layercast_linear_bf16_gpu(const float* X, int64_t M, int64_t K,
                                        HexaFarrBf16* W, int64_t N,
                                        float* Y);

/* ════════════════════════════════════════════════════════════════════
 * Host-side portable bodies (no CUDA needed — compile on every host).
 * ════════════════════════════════════════════════════════════════════ */

/* RNE round of an FP32 value to a bfloat16 bit pattern (returned as the
 * raw 16-bit value). Round-to-nearest-even, matching __float2bfloat16.
 * This is the host CPU reference contract for the BF16 oracle; the
 * device path uses the hardware intrinsic. Pure integer arithmetic on
 * the FP32 bit pattern — no <cuda_bf16.h> needed. */
static uint16_t _hx_f32_to_bf16_rne(float v) {
    uint32_t bits;
    memcpy(&bits, &v, sizeof(bits));
    /* NaN: keep it quiet, preserve a payload bit. */
    if (((bits >> 23) & 0xFF) == 0xFF && (bits & 0x7FFFFF) != 0) {
        return (uint16_t)((bits >> 16) | 0x0040);
    }
    /* Round-to-nearest-even: add the rounding bias then truncate. The
     * bias is 0x7FFF + the LSB of the surviving mantissa. */
    uint32_t lsb        = (bits >> 16) & 1u;
    uint32_t round_bias = 0x7FFFu + lsb;
    return (uint16_t)((bits + round_bias) >> 16);
}

/* Widen a bfloat16 bit pattern back to FP32 (exact — bf16 ⊂ fp32). */
static float _hx_bf16_to_f32(uint16_t bf) {
    uint32_t bits = (uint32_t)bf << 16;
    float v;
    memcpy(&v, &bits, sizeof(v));
    return v;
}

#ifdef HEXA_CUDA
/* Forward decl — defined in the HEXA_CUDA block below; needed here so
 * hexa_farr_bf16_free (portable section) can reference it. */
static void _hx_farr_bf16_device_free(HexaFarrBf16* f);
#endif

HexaFarrBf16* hexa_farr_bf16_alloc(int64_t len) {
    if (len < 0) return NULL;
    HexaFarrBf16* f = (HexaFarrBf16*)calloc(1, sizeof(HexaFarrBf16));
    if (!f) return NULL;
    size_t bytes = (size_t)len * HEXA_FARR_BF16_ELEM_BYTES;
    f->h_buf = (len > 0) ? calloc((size_t)len, HEXA_FARR_BF16_ELEM_BYTES)
                         : NULL;
    if (len > 0 && !f->h_buf) { free(f); return NULL; }
    f->d_buf = NULL;
    f->len   = len;
    f->loc   = FARR_BF16_LOC_HOST;
    f->owns  = 1;
    (void)bytes;
    return f;
}

void hexa_farr_bf16_free(HexaFarrBf16* f) {
    if (!f) return;
    if (f->owns && f->h_buf) free(f->h_buf);
#ifdef HEXA_CUDA
    /* device buffer is cudaFree'd in the CUDA block's helper below */
    if (f->owns && f->d_buf) _hx_farr_bf16_device_free(f);
#endif
    f->h_buf = NULL;
    f->d_buf = NULL;
    free(f);
}

int hexa_farr_bf16_from_f64(const double* src, HexaFarrBf16* dst, int64_t n) {
    if (!src || !dst || !dst->h_buf || n < 0 || n > dst->len) return -1;
    uint16_t* hb = (uint16_t*)dst->h_buf;
    for (int64_t i = 0; i < n; i++) {
        hb[i] = _hx_f32_to_bf16_rne((float)src[i]);
    }
    dst->loc = FARR_BF16_LOC_HOST;
    return 0;
}

int hexa_farr_bf16_to_f64(const HexaFarrBf16* src, double* dst, int64_t n) {
    if (!src || !src->h_buf || !dst || n < 0 || n > src->len) return -1;
    const uint16_t* hb = (const uint16_t*)src->h_buf;
    for (int64_t i = 0; i < n; i++) {
        dst[i] = (double)_hx_bf16_to_f32(hb[i]);
    }
    return 0;
}

/* ════════════════════════════════════════════════════════════════════
 * CUDA-side bodies — only compiled when HEXA_CUDA is defined (the
 * nvcc -x cu build). On a no-CUDA host this whole block is skipped and
 * the device entry points below take their honest-stub form instead.
 * ════════════════════════════════════════════════════════════════════ */
#ifdef HEXA_CUDA

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_bf16.h>

/* cudaFree the device buffer of a BF16 descriptor. Internal helper used
 * by hexa_farr_bf16_free. */
static void _hx_farr_bf16_device_free(HexaFarrBf16* f) {
    if (f && f->d_buf) {
        cudaFree(f->d_buf);
        f->d_buf = NULL;
    }
}

int hexa_farr_bf16_to_device(HexaFarrBf16* f) {
    if (!f || f->len < 0) return -1;
    size_t bytes = (size_t)f->len * sizeof(__nv_bfloat16);
    if (!f->d_buf && f->len > 0) {
        cudaError_t e = cudaMalloc(&f->d_buf, bytes);
        if (e != cudaSuccess) {
            fprintf(stderr, "[bf16] cudaMalloc %zu B failed: %s\n",
                    bytes, cudaGetErrorString(e));
            f->d_buf = NULL;
            return -1;
        }
    }
    if (f->len > 0 && f->h_buf) {
        cudaError_t e = cudaMemcpy(f->d_buf, f->h_buf, bytes,
                                   cudaMemcpyHostToDevice);
        if (e != cudaSuccess) {
            fprintf(stderr, "[bf16] H2D %zu B failed: %s\n",
                    bytes, cudaGetErrorString(e));
            return -1;
        }
    }
    f->loc = FARR_BF16_LOC_MIRROR;
    return 0;
}

int hexa_farr_bf16_to_host(HexaFarrBf16* f) {
    if (!f || f->len < 0) return -1;
    if (!f->d_buf || !f->h_buf) return -1;
    size_t bytes = (size_t)f->len * sizeof(__nv_bfloat16);
    cudaError_t e = cudaMemcpy(f->h_buf, f->d_buf, bytes,
                               cudaMemcpyDeviceToHost);
    if (e != cudaSuccess) {
        fprintf(stderr, "[bf16] D2H %zu B failed: %s\n",
                bytes, cudaGetErrorString(e));
        return -1;
    }
    f->loc = FARR_BF16_LOC_MIRROR;
    return 0;
}

/* ─── *_bf16_gpu kernel entry points — Stage 2 PRODUCTION BODIES ───────
 *
 * RFC 049 Stage 2 — production wiring of the MEASURED Stage 1 kernels
 * (self/cuda/experiments/r049_bf16_fused_ffn.cu, cuBLAS GemmEx BF16 path,
 * 9.67x FP64 cuBLAS Dgemm chain on A100). The kernel ALGORITHM is unchanged
 * from Stage 1 — these bodies only do the substrate wiring: they reuse the
 * shared `g_cublas` handle from runtime_cuda.c (this file is `#include`d
 * into the same CUDA translation unit, so the static handle + the
 * `_ensure_cublas()` lazy-init helper are both visible here), then drive
 * the proven cublasGemmEx call shape. No new measured claim — the fire
 * (running these on a GPU + confirming 9.67x + within-run bit-equal) is a
 * separate cost-bearing step.
 *
 * `g_cublas` / `_ensure_cublas()` provenance: runtime_cuda.c defines them
 * `static` before its `#include "runtime_bf16.c"` line, so they are
 * file-scope-visible to this TU section. We do NOT create a second cuBLAS
 * handle — one handle per process keeps the determinism contract C1
 * (within-run bit-equal) intact and avoids redundant context init.
 *
 * Determinism contract (file header C1): cublasGemmEx with a fixed algo
 * (CUBLAS_GEMM_DEFAULT_TENSOR_OP for the pure-BF16 path) reduces in a
 * fixed order on a single GPU + single stream + single process — so two
 * invocations with identical inputs produce byte-identical BF16 output.
 * No atomic-add to HBM. C2/C3/C4 caveats unchanged (see file header).
 *
 * On any cuBLAS / device error each body returns -1 and names itself on
 * stderr — the runtime_cuda.c error-path convention; no fake result. */

/* SiLU(x) = x * sigmoid(x) on a BF16 device buffer, computed in FP32
 * (LayerCast storage/compute split). Byte-identical to the MEASURED
 * Stage 1 `silu_bf16` kernel in r049_bf16_fused_ffn.cu — same FP32
 * sigmoid, same __float2bfloat16 RNE epilogue, same grid-stride loop. */
static __global__ void _hx_silu_bf16_k(__nv_bfloat16* h, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        float v = __bfloat162float(h[i]);
        float sig = 1.0f / (1.0f + expf(-v));
        h[i] = __float2bfloat16(v * sig);
    }
}

/* On-device upcast BF16 -> FP32 — the LayerCast fallback path's weight
 * widening (r049_layercast_linear.cu `bf16_to_f32_k`). Used only when the
 * running cuBLAS lacks the mixed FP32xBF16 GemmEx type combination. */
static __global__ void _hx_bf16_to_f32_k(const __nv_bfloat16* in,
                                         float* out, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = __bfloat162float(in[i]);
}

/* The pure-BF16 GemmEx call shape, lifted verbatim from the MEASURED
 * Stage 1 `gemm_ex_bf16` helper: CUDA_R_16BF input, CUBLAS_COMPUTE_32F
 * (FP32 accumulator), CUDA_R_16BF output, CUBLAS_GEMM_DEFAULT_TENSOR_OP
 * (BF16 Tensor Core on sm_80+, deterministic algo -> contract C1). */
static cublasStatus_t _hx_gemm_ex_bf16(cublasOperation_t opA,
                                       cublasOperation_t opB,
                                       int m, int n, int k,
                                       const __nv_bfloat16* A, int lda,
                                       const __nv_bfloat16* B, int ldb,
                                       __nv_bfloat16* C, int ldc) {
    const float alpha = 1.0f, beta = 0.0f;
    return cublasGemmEx(g_cublas, opA, opB, m, n, k,
                        &alpha,
                        A, CUDA_R_16BF, lda,
                        B, CUDA_R_16BF, ldb,
                        &beta,
                        C, CUDA_R_16BF, ldc,
                        CUBLAS_COMPUTE_32F,
                        CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}

/* Grid-block count for an elementwise kernel of `n` elements (256-thread
 * blocks, capped at 65535 — the Stage 1 kernels' launch-config helper). */
static int _hx_bf16_blocks(size_t n) {
    size_t b = (n + 255) / 256;
    return (b > 65535) ? 65535 : (int)b;
}

int hexa_farr_matmul_bf16_gpu(HexaFarrBf16* A, int64_t M, int64_t K,
                              HexaFarrBf16* B, int64_t N,
                              HexaFarrBf16* C) {
    /* Production body: a single BF16 GemmEx — the MEASURED Stage 1
     * gemm_ex_bf16 pattern (r049_bf16_fused_ffn.cu). */
    if (!A || !B || !C || M <= 0 || K <= 0 || N <= 0) {
        fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: bad args\n");
        return -1;
    }
    if (M > INT32_MAX || K > INT32_MAX || N > INT32_MAX) {
        fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: "
                        "dim exceeds cuBLAS int range\n");
        return -1;
    }
    if (_ensure_cublas() != 0) {
        fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: no cuBLAS handle\n");
        return -1;
    }
    /* Ensure all three farr are device-resident (H2D on demand). */
    if (hexa_farr_bf16_to_device(A) != 0 ||
        hexa_farr_bf16_to_device(B) != 0 ||
        hexa_farr_bf16_to_device(C) != 0) {
        fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: H2D failed\n");
        return -1;
    }
    const __nv_bfloat16* dA = (const __nv_bfloat16*)A->d_buf;
    const __nv_bfloat16* dB = (const __nv_bfloat16*)B->d_buf;
    __nv_bfloat16*       dC = (__nv_bfloat16*)C->d_buf;
    if (!dA || !dB || !dC) {
        fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: null device buf\n");
        return -1;
    }
    /* Row-major C[M,N] = A[M,K] @ B[K,N]. cuBLAS is column-major; the
     * standard swap trick computes the transpose: gemm(opN,opN, N, M, K,
     * B, N, A, K, C, N) — identical to the Stage 1 helper's call sites. */
    cublasStatus_t st = _hx_gemm_ex_bf16(CUBLAS_OP_N, CUBLAS_OP_N,
                                         (int)N, (int)M, (int)K,
                                         dB, (int)N,
                                         dA, (int)K,
                                         dC, (int)N);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: "
                        "cublasGemmEx failed: %d\n", (int)st);
        return -1;
    }
    cudaError_t ce = cudaDeviceSynchronize();
    if (ce != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: sync failed: %s\n",
                cudaGetErrorString(ce));
        return -1;
    }
    /* C's device buffer is now authoritative. */
    C->loc = FARR_BF16_LOC_DEVICE;
    return 0;
}

int hexa_farr_ffn_bf16_gpu(HexaFarrBf16* X, int64_t M, int64_t D, int64_t FD,
                           HexaFarrBf16* W1, HexaFarrBf16* W2,
                           HexaFarrBf16* Y) {
    /* Production body: the fused FFN chain Y = SiLU(X @ W1) @ W2 — the
     * MEASURED Stage 1 cublas_ffn_chain_bf16 pattern
     * (r049_bf16_fused_ffn.cu, 9.67x FP64 cuBLAS @ Llama-7B FFN).
     *
     * RFC 052 will supersede this body with the Hopper sm_90+ DSM-cluster
     * combined kernel via an internal cc.major>=9 branch — same entry
     * point, no signature change (RFC 052 §6.5 fallback chain). This
     * Stage 2 body is the sm_80 RFC 049 path. */
    if (!X || !W1 || !W2 || !Y || M <= 0 || D <= 0 || FD <= 0) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: bad args\n");
        return -1;
    }
    if (M > INT32_MAX || D > INT32_MAX || FD > INT32_MAX) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: "
                        "dim exceeds cuBLAS int range\n");
        return -1;
    }
    if (_ensure_cublas() != 0) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: no cuBLAS handle\n");
        return -1;
    }
    if (hexa_farr_bf16_to_device(X)  != 0 ||
        hexa_farr_bf16_to_device(W1) != 0 ||
        hexa_farr_bf16_to_device(W2) != 0 ||
        hexa_farr_bf16_to_device(Y)  != 0) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: H2D failed\n");
        return -1;
    }
    const __nv_bfloat16* dX  = (const __nv_bfloat16*)X->d_buf;
    const __nv_bfloat16* dW1 = (const __nv_bfloat16*)W1->d_buf;
    const __nv_bfloat16* dW2 = (const __nv_bfloat16*)W2->d_buf;
    __nv_bfloat16*       dY  = (__nv_bfloat16*)Y->d_buf;
    if (!dX || !dW1 || !dW2 || !dY) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: null device buf\n");
        return -1;
    }
    /* The hidden activation H[M,FD] needs its own device scratch — the
     * caller's farr set does not include it. Owned + freed locally. */
    __nv_bfloat16* dH = NULL;
    size_t szH = (size_t)M * (size_t)FD * sizeof(__nv_bfloat16);
    cudaError_t ce = cudaMalloc((void**)&dH, szH);
    if (ce != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: "
                        "scratch cudaMalloc %zu B failed: %s\n",
                szH, cudaGetErrorString(ce));
        return -1;
    }
    /* H = X @ W1 — row-major (M,D)·(D,FD) -> (M,FD); column-major swap. */
    cublasStatus_t st = _hx_gemm_ex_bf16(CUBLAS_OP_N, CUBLAS_OP_N,
                                         (int)FD, (int)M, (int)D,
                                         dW1, (int)FD,
                                         dX,  (int)D,
                                         dH,  (int)FD);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: "
                        "gemm1 failed: %d\n", (int)st);
        cudaFree(dH);
        return -1;
    }
    /* In-place SiLU on H (BF16 storage, FP32 compute). */
    size_t n_act = (size_t)M * (size_t)FD;
    _hx_silu_bf16_k<<<_hx_bf16_blocks(n_act), 256>>>(dH, n_act);
    ce = cudaGetLastError();
    if (ce != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: "
                        "silu launch failed: %s\n", cudaGetErrorString(ce));
        cudaFree(dH);
        return -1;
    }
    /* Y = H @ W2 — row-major (M,FD)·(FD,D) -> (M,D); column-major swap. */
    st = _hx_gemm_ex_bf16(CUBLAS_OP_N, CUBLAS_OP_N,
                          (int)D, (int)M, (int)FD,
                          dW2, (int)D,
                          dH,  (int)FD,
                          dY,  (int)D);
    if (st != CUBLAS_STATUS_SUCCESS) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: "
                        "gemm2 failed: %d\n", (int)st);
        cudaFree(dH);
        return -1;
    }
    ce = cudaDeviceSynchronize();
    cudaFree(dH);
    if (ce != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: sync failed: %s\n",
                cudaGetErrorString(ce));
        return -1;
    }
    Y->loc = FARR_BF16_LOC_DEVICE;
    return 0;
}

int hexa_farr_layercast_linear_bf16_gpu(const float* X, int64_t M, int64_t K,
                                        HexaFarrBf16* W, int64_t N,
                                        float* Y) {
    /* Production body: the LayerCast linear Y[M,N] = X[M,K] @ W[K,N] with
     * W in BF16 storage, X and Y in FP32, FP32 compute — the MEASURED
     * Stage 1 r049_layercast_linear.cu pattern (divergence 1.20-1.51% vs
     * FP32). Tries the direct mixed FP32xBF16 cublasGemmEx first; on an
     * unsupported-type status falls back to an on-device BF16->FP32 upcast
     * of the weight followed by cublasSgemm — exactly the Stage 1
     * try-mixed-then-fallback structure.
     *
     * X / Y are plain FP32 HOST arrays (the LayerCast surface uses FP32
     * activations); this body owns the device staging for X, W and Y. */
    if (!X || !W || !Y || M <= 0 || K <= 0 || N <= 0) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "bad args\n");
        return -1;
    }
    if (M > INT32_MAX || K > INT32_MAX || N > INT32_MAX) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "dim exceeds cuBLAS int range\n");
        return -1;
    }
    if (W->len < (int64_t)K * N) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "weight farr too small\n");
        return -1;
    }
    if (_ensure_cublas() != 0) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "no cuBLAS handle\n");
        return -1;
    }
    if (hexa_farr_bf16_to_device(W) != 0) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "weight H2D failed\n");
        return -1;
    }
    const __nv_bfloat16* dW = (const __nv_bfloat16*)W->d_buf;
    if (!dW) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "null weight device buf\n");
        return -1;
    }
    /* Device staging for the FP32 activations. */
    size_t szX = (size_t)M * (size_t)K * sizeof(float);
    size_t szY = (size_t)M * (size_t)N * sizeof(float);
    float* dX = NULL;
    float* dY = NULL;
    cudaError_t ce;
    if ((ce = cudaMalloc((void**)&dX, szX)) != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "dX cudaMalloc failed: %s\n", cudaGetErrorString(ce));
        return -1;
    }
    if ((ce = cudaMalloc((void**)&dY, szY)) != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "dY cudaMalloc failed: %s\n", cudaGetErrorString(ce));
        cudaFree(dX);
        return -1;
    }
    if ((ce = cudaMemcpy(dX, X, szX, cudaMemcpyHostToDevice)) != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "X H2D failed: %s\n", cudaGetErrorString(ce));
        cudaFree(dX); cudaFree(dY);
        return -1;
    }
    /* Row-major Y[M,N] = X[M,K] @ W[K,N]; column-major swap trick:
     * gemm(opN,opN, N, M, K, W, N, X, K, Y, N). Try the mixed FP32xBF16
     * GemmEx first (modern cuBLAS 12.x); FP32 accumulator. */
    const float alpha = 1.0f, beta = 0.0f;
    cublasStatus_t st = cublasGemmEx(g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                                     (int)N, (int)M, (int)K,
                                     &alpha,
                                     dW, CUDA_R_16BF, (int)N,
                                     dX, CUDA_R_32F,  (int)K,
                                     &beta,
                                     dY, CUDA_R_32F,  (int)N,
                                     CUBLAS_COMPUTE_32F,
                                     CUBLAS_GEMM_DEFAULT);
    if (st != CUBLAS_STATUS_SUCCESS) {
        /* Fallback: on-device upcast BF16 weight -> FP32, then Sgemm. */
        float* dW_f32 = NULL;
        size_t n_w = (size_t)K * (size_t)N;
        if ((ce = cudaMalloc((void**)&dW_f32,
                             n_w * sizeof(float))) != cudaSuccess) {
            fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                            "fallback scratch failed: %s\n",
                    cudaGetErrorString(ce));
            cudaFree(dX); cudaFree(dY);
            return -1;
        }
        _hx_bf16_to_f32_k<<<_hx_bf16_blocks(n_w), 256>>>(dW, dW_f32, n_w);
        ce = cudaGetLastError();
        if (ce != cudaSuccess) {
            fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                            "upcast launch failed: %s\n",
                    cudaGetErrorString(ce));
            cudaFree(dX); cudaFree(dY); cudaFree(dW_f32);
            return -1;
        }
        st = cublasSgemm(g_cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                         (int)N, (int)M, (int)K,
                         &alpha, dW_f32, (int)N, dX, (int)K,
                         &beta, dY, (int)N);
        cudaFree(dW_f32);
        if (st != CUBLAS_STATUS_SUCCESS) {
            fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                            "fallback Sgemm failed: %d\n", (int)st);
            cudaFree(dX); cudaFree(dY);
            return -1;
        }
    }
    ce = cudaMemcpy(Y, dY, szY, cudaMemcpyDeviceToHost);
    cudaFree(dX);
    cudaFree(dY);
    if (ce != cudaSuccess) {
        fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                        "Y D2H failed: %s\n", cudaGetErrorString(ce));
        return -1;
    }
    return 0;
}

#else  /* !HEXA_CUDA — no-CUDA host: honest stubs, ABI stays stable */

int hexa_farr_bf16_to_device(HexaFarrBf16* f) {
    (void)f;
    /* No CUDA toolkit on this host — the BF16 device tier is unavailable.
     * Host-side farr_bf16 storage + RNE casts still work for the CPU
     * reference oracle. */
    return -1;
}

int hexa_farr_bf16_to_host(HexaFarrBf16* f) {
    (void)f;
    return -1;
}

int hexa_farr_matmul_bf16_gpu(HexaFarrBf16* A, int64_t M, int64_t K,
                              HexaFarrBf16* B, int64_t N,
                              HexaFarrBf16* C) {
    (void)A; (void)M; (void)K; (void)B; (void)N; (void)C;
    return -1;  /* no-CUDA host: BF16 GPU substrate unavailable */
}

int hexa_farr_ffn_bf16_gpu(HexaFarrBf16* X, int64_t M, int64_t D, int64_t FD,
                           HexaFarrBf16* W1, HexaFarrBf16* W2,
                           HexaFarrBf16* Y) {
    (void)X; (void)M; (void)D; (void)FD; (void)W1; (void)W2; (void)Y;
    return -1;  /* no-CUDA host: BF16 GPU substrate unavailable */
}

int hexa_farr_layercast_linear_bf16_gpu(const float* X, int64_t M, int64_t K,
                                        HexaFarrBf16* W, int64_t N,
                                        float* Y) {
    (void)X; (void)M; (void)K; (void)W; (void)N; (void)Y;
    return -1;  /* no-CUDA host: BF16 GPU substrate unavailable */
}

#endif /* HEXA_CUDA */

#ifdef __cplusplus
}  /* extern "C" */
#endif
