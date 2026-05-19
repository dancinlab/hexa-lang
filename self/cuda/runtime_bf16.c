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

/* ─── *_bf16_gpu kernel entry points — Stage 2 bodies ─────────────────
 *
 * RFC 049 Stage 2 — kernel bodies pending fire-validation. The MEASURED
 * Stage 1 reference (self/cuda/experiments/r049_bf16_fused_ffn.cu, cuBLAS
 * GemmEx BF16 path, 9.67x FP64 cuBLAS) is the kernel these will wrap. The
 * production wiring (cuBLAS handle sharing with runtime_cuda.c::g_cublas,
 * stream coordination, the device-mirror residence contract) is the
 * follow-up cost-bearing cycle's deliverable. Each stub returns -1 and
 * names itself on stderr — honest, no fake CUDA result (the runtime_cuda.c
 * error-path convention). */

int hexa_farr_matmul_bf16_gpu(HexaFarrBf16* A, int64_t M, int64_t K,
                              HexaFarrBf16* B, int64_t N,
                              HexaFarrBf16* C) {
    (void)A; (void)M; (void)K; (void)B; (void)N; (void)C;
    /* RFC 049 Stage 2 — kernel body pending fire-validation.
     * Will wrap cublasGemmEx(CUDA_R_16BF, CUBLAS_COMPUTE_32F,
     * CUBLAS_GEMM_DEFAULT_TENSOR_OP) — the r049_bf16_fused_ffn.cu
     * gemm_ex_bf16 helper, already MEASURED Stage 1. */
    fprintf(stderr, "[bf16] hexa_farr_matmul_bf16_gpu: "
                    "RFC 049 Stage 2 kernel body pending fire-validation\n");
    return -1;
}

int hexa_farr_ffn_bf16_gpu(HexaFarrBf16* X, int64_t M, int64_t D, int64_t FD,
                           HexaFarrBf16* W1, HexaFarrBf16* W2,
                           HexaFarrBf16* Y) {
    (void)X; (void)M; (void)D; (void)FD; (void)W1; (void)W2; (void)Y;
    /* RFC 049 Stage 2 — kernel body pending fire-validation.
     * Will wrap cublas_ffn_chain_bf16 from r049_bf16_fused_ffn.cu
     * (GemmEx BF16 -> silu_bf16 FP32-compute -> GemmEx BF16),
     * already MEASURED Stage 1 at 9.67x FP64 cuBLAS @ Llama-7B FFN.
     * RFC 052 supersedes this body with the Hopper sm_90+ DSM-cluster
     * combined kernel via an internal cc.major>=9 branch — same entry
     * point, no signature change. */
    fprintf(stderr, "[bf16] hexa_farr_ffn_bf16_gpu: "
                    "RFC 049 Stage 2 kernel body pending fire-validation\n");
    return -1;
}

int hexa_farr_layercast_linear_bf16_gpu(const float* X, int64_t M, int64_t K,
                                        HexaFarrBf16* W, int64_t N,
                                        float* Y) {
    (void)X; (void)M; (void)K; (void)W; (void)N; (void)Y;
    /* RFC 049 Stage 2 — kernel body pending fire-validation.
     * Will wrap the LayerCast path from r049_layercast_linear.cu
     * (cublasGemmEx FP32 X + BF16 W -> FP32 compute -> FP32 Y, with the
     * on-device upcast fallback for cuBLAS versions lacking the mixed
     * type). MEASURED Stage 1: divergence 1.20-1.51% vs FP32. */
    fprintf(stderr, "[bf16] hexa_farr_layercast_linear_bf16_gpu: "
                    "RFC 049 Stage 2 kernel body pending fire-validation\n");
    return -1;
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
