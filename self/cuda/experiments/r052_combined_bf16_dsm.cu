/* r052_combined_bf16_dsm.cu — forge RFC 052 Stage 2 (Hopper BF16 WMMA + DSM combined FFN)
 *
 * Pre-registered (RFC 052 §"Falsifier battery", 7 falsifiers):
 *   F-FORGE-RFC052-COMBINED-PERF      — combined fused FFN ≤ 0.667× the RFC 049
 *                                       cuBLAS GemmEx BF16 chain on the SAME GPU
 *                                       (≥ 1.5× speedup over the BF16-only path)
 *   F-FORGE-RFC052-BITEQ-VS-RFC049    — combined output max rel|Δ| ≤ 1e-3 vs the
 *                                       cuBLAS GemmEx BF16 chain
 *   F-FORGE-RFC052-LAYERCAST-DET      — within-run bit-equal (two runs, byte-equal)
 *   F-FORGE-RFC052-DSM-INTERMEDIATE-FIT — per-block H_half SMEM fits Hopper optin cap
 *   F-FORGE-RFC052-HOPPER-ONLY        — cluster launch SUCCESS on sm_90+
 *   (F-FORGE-RFC052-FALLBACK / Tier-5 build = structural, not fired here)
 *
 * --- Kernel design (RFC 052 §6.1, combined Hopper kernel) ---
 *
 *   X  [M , D ]  input activations (BF16, row-major)
 *   W1 [D , FD]  up-projection      (BF16, row-major)
 *   W2 [FD, D ]  down-projection    (BF16, row-major)
 *   H  = X @ W1        [M, FD]   BF16 WMMA, FP32 acc → BF16 SMEM
 *   H' = SiLU(H)       [M, FD]   FP32 compute, BF16 SMEM
 *   Y  = H' @ W2       [M, D]    BF16 WMMA, FP32 acc → atomicAdd FP32 staging
 *
 * Cluster of 2 blocks (__cluster_dims__(1,2,1)). FD axis bisected:
 *   block_rank=0 owns FD cols [0, FD/2), block_rank=1 owns [FD/2, FD).
 * Each block keeps its H_half[M_TILE × FD/2] in dynamic SMEM (BF16) — the
 * intermediate H NEVER touches HBM (the DSM-fusion point). The two blocks'
 * partial Y contributions are merged by FP32 atomicAdd into a Y staging
 * buffer. cluster.sync() barriers the two halves (RFC 052 §6.1 step 3).
 *
 * Honest scope (g3 / instrument-first pre-fire prediction):
 *   This is a HAND WMMA kernel. The C Phase 3 forge measurement showed hand
 *   WMMA reaches ~41-43% of TC peak vs cuBLAS GemmEx ~77-87%. The combined
 *   kernel must replace 2 cuBLAS GemmEx calls with in-kernel WMMA — so at
 *   compute-bound training shapes (M=64-128) the prediction is that the
 *   combined kernel is SLOWER than the cuBLAS BF16 chain (the §3.9a roofline
 *   HARD_WALL: hand WMMA < cuBLAS, already FP64-confirmed by RFC 060-C).
 *   The DSM intermediate-elimination saves only ~1.5% HBM traffic at LARGE.
 *   The genuine open window is the launch-bound regime (small M) where no
 *   one's GEMM is TC-efficient. Falsifier verdicts are reported as measured —
 *   a KILL is recorded as a KILL.
 *
 * Reference: RFC 052 §6 (combined kernel architecture), RFC 049 Stage 1
 *   (state/forge_phaseR_r049_bf16_2026_05_17 — cuBLAS GemmEx BF16 9.67×),
 *   b_dsm_fused_ffn_v2.cu (B Stage 2 — proven 2-block cluster DSM FFN).
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_bf16.h>
#include <mma.h>
#include <cooperative_groups.h>

namespace cg = cooperative_groups;
namespace wmma = nvcuda::wmma;

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { fprintf(stderr, "[R052] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } } while (0)
#define CB(call) do { cublasStatus_t _s = (call); if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[R052] cuBLAS %s:%d %d\n", __FILE__, __LINE__, (int)_s); exit(1); } } while (0)

#define WMMA_M 16
#define WMMA_N 16
#define WMMA_K 16
#define BLOCK_THREADS 256
#define WARPS_PER_BLOCK (BLOCK_THREADS / 32)

static double now_sec(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}
static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}
static int dbl_cmp(const void* a, const void* b) {
    double aa = *(const double*)a, bb = *(const double*)b;
    return (aa > bb) - (aa < bb);
}
static double median(double* a, int n) {
    qsort(a, n, sizeof(double), dbl_cmp);
    return a[n / 2];
}

/* ============================================================================
 * BF16 conversion helpers (FP64 host data → BF16 device, RNE)
 * ============================================================================ */
__global__ void f64_to_bf16_via_f32(const double* in, __nv_bfloat16* out, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = __float2bfloat16((float)in[i]);
}
__global__ void bf16_to_f64(const __nv_bfloat16* in, double* out, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = (double)__bfloat162float(in[i]);
}
__global__ void f32_to_f64(const float* in, double* out, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = (double)in[i];
}
__global__ void silu_bf16(__nv_bfloat16* h, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        float v = __bfloat162float(h[i]);
        h[i] = __float2bfloat16(v / (1.0f + expf(-v)));
    }
}
__global__ void silu_f64(double* y, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) { double v = x[i]; y[i] = v / (1.0 + exp(-v)); }
}

/* ============================================================================
 * RFC 052 combined kernel — Hopper BF16 WMMA + DSM cluster fused FFN
 *
 * Grid:    gridDim = (M / M_TILE, 2, 1)   — y-dim is the cluster's 2 blocks
 * Cluster: __cluster_dims__(1, 2, 1)
 * Block:   BLOCK_THREADS threads = WARPS_PER_BLOCK warps; one warp per
 *          16×16 WMMA output tile, grid-stride over the tile set.
 *
 * Dynamic SMEM layout (per block):
 *   [0 .. M_TILE*FD_HALF)            __nv_bfloat16  H_half  (the DSM intermediate)
 *   [aligned ..)                     float          scratch[WARPS_PER_BLOCK][256]
 *
 * Constraints (checked host-side): M % M_TILE == 0, M_TILE % 16 == 0,
 *   D % 16 == 0, FD_HALF % 16 == 0.
 * ============================================================================ */
template<int M_TILE, int FD_HALF>
__global__ void __cluster_dims__(1, 2, 1)
combined_ffn_bf16_dsm(int M, int D, int FD,
                      const __nv_bfloat16* __restrict__ X,    /* [M, D]  row-major */
                      const __nv_bfloat16* __restrict__ W1,   /* [D, FD] row-major */
                      const __nv_bfloat16* __restrict__ W2,   /* [FD, D] row-major */
                      float* __restrict__ Y_stage)            /* [M, D]  FP32, pre-zeroed */
{
    cg::cluster_group cluster = cg::this_cluster();
    int block_rank = cluster.block_rank();          /* 0 or 1 */
    int row_base   = blockIdx.x * M_TILE;
    int fd_offset  = block_rank * FD_HALF;

    extern __shared__ char smem_raw[];
    __nv_bfloat16* H_half = (__nv_bfloat16*)smem_raw;                       /* M_TILE × FD_HALF */
    float* scratch = (float*)(smem_raw + (size_t)M_TILE * FD_HALF * sizeof(__nv_bfloat16));

    int warp = threadIdx.x >> 5;
    int lane = threadIdx.x & 31;
    float* my_scratch = scratch + (size_t)warp * 256;

    const int mt_tiles = M_TILE / WMMA_M;   /* row tiles within this cluster's M slice */
    const int fd_tiles = FD_HALF / WMMA_N;  /* col tiles within this block's FD half   */
    const int d_tiles  = D / WMMA_N;        /* col tiles of the final Y                */

    /* ---- matmul1: H_half = X[row_base:+M_TILE, :] @ W1[:, fd_offset:+FD_HALF] ----
     * Each warp owns a 16×16 H_half output tile; accumulate over D in K=16 steps. */
    for (int t = warp; t < mt_tiles * fd_tiles; t += WARPS_PER_BLOCK) {
        int mr = (t / fd_tiles) * WMMA_M;   /* row offset within M_TILE   */
        int fc = (t % fd_tiles) * WMMA_N;   /* col offset within FD_HALF  */
        wmma::fragment<wmma::accumulator, WMMA_M, WMMA_N, WMMA_K, float> acc;
        wmma::fill_fragment(acc, 0.0f);
        for (int k = 0; k < D; k += WMMA_K) {
            wmma::fragment<wmma::matrix_a, WMMA_M, WMMA_N, WMMA_K, __nv_bfloat16, wmma::row_major> a;
            wmma::fragment<wmma::matrix_b, WMMA_M, WMMA_N, WMMA_K, __nv_bfloat16, wmma::row_major> b;
            wmma::load_matrix_sync(a, X  + (size_t)(row_base + mr) * D + k,           D);
            wmma::load_matrix_sync(b, W1 + (size_t)k * FD + (fd_offset + fc),         FD);
            wmma::mma_sync(acc, a, b, acc);
        }
        /* FP32 acc → scratch → SiLU(FP32) → BF16 store into H_half */
        wmma::store_matrix_sync(my_scratch, acc, WMMA_N, wmma::mem_row_major);
        __syncwarp();
        for (int e = lane; e < WMMA_M * WMMA_N; e += 32) {
            float v = my_scratch[e];
            float sv = v / (1.0f + expf(-v));   /* SiLU */
            int er = e / WMMA_N, ec = e % WMMA_N;
            H_half[(size_t)(mr + er) * FD_HALF + (fc + ec)] = __float2bfloat16(sv);
        }
    }
    __syncthreads();
    /* RFC 052 §6.1 step 3 — cluster barrier across the two FD halves. */
    cluster.sync();

    /* ---- matmul2: Y_partial = H_half @ W2[fd_offset:+FD_HALF, :] ----
     * Each block owns a disjoint FD slice; FP32 atomicAdd merges the two
     * partials into Y_stage (deterministic: only two operands per (m,d)). */
    for (int t = warp; t < mt_tiles * d_tiles; t += WARPS_PER_BLOCK) {
        int mr = (t / d_tiles) * WMMA_M;
        int dc = (t % d_tiles) * WMMA_N;
        wmma::fragment<wmma::accumulator, WMMA_M, WMMA_N, WMMA_K, float> acc;
        wmma::fill_fragment(acc, 0.0f);
        for (int j = 0; j < FD_HALF; j += WMMA_K) {
            wmma::fragment<wmma::matrix_a, WMMA_M, WMMA_N, WMMA_K, __nv_bfloat16, wmma::row_major> a;
            wmma::fragment<wmma::matrix_b, WMMA_M, WMMA_N, WMMA_K, __nv_bfloat16, wmma::row_major> b;
            wmma::load_matrix_sync(a, H_half + (size_t)mr * FD_HALF + j,              FD_HALF);
            wmma::load_matrix_sync(b, W2 + (size_t)(fd_offset + j) * D + dc,          D);
            wmma::mma_sync(acc, a, b, acc);
        }
        wmma::store_matrix_sync(my_scratch, acc, WMMA_N, wmma::mem_row_major);
        __syncwarp();
        for (int e = lane; e < WMMA_M * WMMA_N; e += 32) {
            int er = e / WMMA_N, ec = e % WMMA_N;
            int abs_m = row_base + mr + er;
            if (abs_m < M)
                atomicAdd(&Y_stage[(size_t)abs_m * D + (dc + ec)], my_scratch[e]);
        }
    }
}

/* ============================================================================
 * cuBLAS GemmEx BF16 chain — the RFC 049 baseline (the wall-path contender)
 * ============================================================================ */
static cublasStatus_t gemm_ex_bf16(cublasHandle_t h,
                                    cublasOperation_t opA, cublasOperation_t opB,
                                    int m, int n, int k,
                                    const __nv_bfloat16* A, int lda,
                                    const __nv_bfloat16* B, int ldb,
                                    __nv_bfloat16* C, int ldc) {
    const float alpha = 1.0f, beta = 0.0f;
    return cublasGemmEx(h, opA, opB, m, n, k, &alpha,
                        A, CUDA_R_16BF, lda, B, CUDA_R_16BF, ldb,
                        &beta, C, CUDA_R_16BF, ldc,
                        CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}
static void cublas_ffn_chain_bf16(cublasHandle_t h, cudaStream_t st,
                                   int M, int D, int FD,
                                   const __nv_bfloat16* dX, const __nv_bfloat16* dW1,
                                   __nv_bfloat16* dH,
                                   const __nv_bfloat16* dW2, __nv_bfloat16* dY) {
    CB(gemm_ex_bf16(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D, dW1, FD, dX, D, dH, FD));
    int n_act = M * FD, threads = 256, blocks = (n_act + threads - 1) / threads;
    if (blocks > 65535) blocks = 65535;
    silu_bf16<<<blocks, threads, 0, st>>>(dH, (size_t)n_act);
    CB(gemm_ex_bf16(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD, dW2, D, dH, FD, dY, D));
}

/* cuBLAS Dgemm FP64 chain — numerical ground truth */
static void cublas_ffn_chain_f64(cublasHandle_t h, cudaStream_t st,
                                  int M, int D, int FD,
                                  const double* dX, const double* dW1,
                                  double* dH, double* dH_act,
                                  const double* dW2, double* dY) {
    const double alpha = 1.0, beta = 0.0;
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D, &alpha, dW1, FD, dX, D, &beta, dH, FD);
    int n_act = M * FD, threads = 256, blocks = (n_act + threads - 1) / threads;
    if (blocks > 65535) blocks = 65535;
    silu_f64<<<blocks, threads, 0, st>>>(dH_act, dH, n_act);
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD, &alpha, dW2, D, dH_act, FD, &beta, dY, D);
}

/* ============================================================================
 * Combined-kernel cluster launch wrapper
 * ============================================================================ */
template<int M_TILE, int FD_HALF>
static cudaError_t launch_combined(int M, int D, int FD,
                                    const __nv_bfloat16* dX, const __nv_bfloat16* dW1,
                                    const __nv_bfloat16* dW2, float* dY_stage,
                                    cudaStream_t stream, int smem_bytes) {
    int n_tiles = M / M_TILE;
    cudaLaunchConfig_t config; memset(&config, 0, sizeof(config));
    config.gridDim = dim3(n_tiles, 2, 1);
    config.blockDim = dim3(BLOCK_THREADS, 1, 1);
    config.dynamicSmemBytes = smem_bytes;
    config.stream = stream;
    cudaLaunchAttribute attrs[1]; memset(attrs, 0, sizeof(attrs));
    attrs[0].id = cudaLaunchAttributeClusterDimension;
    attrs[0].val.clusterDim.x = 1;
    attrs[0].val.clusterDim.y = 2;
    attrs[0].val.clusterDim.z = 1;
    config.attrs = attrs;
    config.numAttrs = 1;
    cudaFuncSetAttribute((void*)combined_ffn_bf16_dsm<M_TILE, FD_HALF>,
                         cudaFuncAttributeMaxDynamicSharedMemorySize, smem_bytes);
    return cudaLaunchKernelEx(&config, combined_ffn_bf16_dsm<M_TILE, FD_HALF>,
                              M, D, FD, dX, dW1, dW2, dY_stage);
}

static int dispatch_combined(int M, int D, int FD, int FD_HALF, int smem_bytes,
                             const __nv_bfloat16* dX, const __nv_bfloat16* dW1,
                             const __nv_bfloat16* dW2, float* dY_stage,
                             cudaStream_t stream) {
    cudaMemsetAsync(dY_stage, 0, (size_t)M * D * sizeof(float), stream);
    cudaError_t err;
    if      (FD_HALF == 1536) err = launch_combined<16, 1536>(M, D, FD, dX, dW1, dW2, dY_stage, stream, smem_bytes);
    else if (FD_HALF == 5504) err = launch_combined<16, 5504>(M, D, FD, dX, dW1, dW2, dY_stage, stream, smem_bytes);
    else { fprintf(stderr, "[R052] unsupported FD_HALF=%d — add template instantiation\n", FD_HALF); return -1; }
    if (err != cudaSuccess) { fprintf(stderr, "[R052] launch err: %s\n", cudaGetErrorString(err)); return -2; }
    return 0;
}

/* ============================================================================
 * Per-shape harness
 * ============================================================================ */
struct shape_result {
    int M, D, FD, M_TILE, FD_HALF, smem_bytes;
    int kernel_launched;
    double t_bf16_chain_ms;     /* RFC 049 cuBLAS GemmEx BF16 chain */
    double t_combined_ms;       /* RFC 052 combined kernel          */
    double t_f64_chain_ms;      /* cuBLAS Dgemm FP64 (numerical ref) */
    double perf_ratio;          /* t_combined / t_bf16_chain → ≤ 0.667 = PASS */
    double speedup_vs_f64;      /* t_f64_chain / t_combined         */
    double max_abs_delta_vs_bf16, max_rel_delta_vs_bf16;
    double max_abs_delta_vs_f64, max_rel_delta_vs_f64;
    int within_run_biteq;
    int falsifier_perf_pass;    /* ≤ 0.667× */
    int falsifier_biteq_pass;   /* rel|Δ| ≤ 1e-3 vs BF16 chain */
    int falsifier_det_pass;     /* within-run bit-equal */
    int falsifier_smem_pass;    /* SMEM ≤ 227 KB */
    char status[160];
};

static shape_result run_shape(cublasHandle_t h, int M, int D, int FD, int n_warm, int n_iter) {
    shape_result r; memset(&r, 0, sizeof(r));
    r.M = M; r.D = D; r.FD = FD; r.M_TILE = 16; r.FD_HALF = FD / 2;
    int FD_HALF = FD / 2;
    /* SMEM: H_half (BF16) + per-warp FP32 scratch */
    r.smem_bytes = r.M_TILE * FD_HALF * (int)sizeof(__nv_bfloat16)
                 + WARPS_PER_BLOCK * 256 * (int)sizeof(float);
    r.falsifier_smem_pass = (r.smem_bytes <= 227 * 1024) ? 1 : 0;

    fprintf(stderr, "[R052] === M=%d D=%d FD=%d (M_TILE=16 FD_HALF=%d smem=%d B) ===\n",
            M, D, FD, FD_HALF, r.smem_bytes);

    if ((M % r.M_TILE) || (D % 16) || (FD_HALF % 16)) {
        snprintf(r.status, sizeof(r.status), "SHAPE_UNALIGNED M%%16 D%%16 FD_HALF%%16");
        fprintf(stderr, "[R052]   FAIL: %s\n", r.status);
        return r;
    }
    if (!r.falsifier_smem_pass) {
        snprintf(r.status, sizeof(r.status), "SMEM_EXHAUST %d B > 227 KB", r.smem_bytes);
        fprintf(stderr, "[R052]   FAIL: %s\n", r.status);
        return r;
    }

    size_t nX = (size_t)M * D, nW1 = (size_t)D * FD, nW2 = (size_t)FD * D, nY = (size_t)M * D;
    size_t nH = (size_t)M * FD;

    /* host FP64 inputs */
    double* hX  = (double*)malloc(nX * sizeof(double));
    double* hW1 = (double*)malloc(nW1 * sizeof(double));
    double* hW2 = (double*)malloc(nW2 * sizeof(double));
    double* hY_f64      = (double*)malloc(nY * sizeof(double));
    double* hY_bf16chain = (double*)malloc(nY * sizeof(double));
    double* hY_combined  = (double*)malloc(nY * sizeof(double));
    float*  hY_run1 = (float*)malloc(nY * sizeof(float));
    float*  hY_run2 = (float*)malloc(nY * sizeof(float));

    uint64_t st = 0x052c0117ULL ^ (uint64_t)(M * 1000003 + D * 1009 + FD * 31);
    for (size_t i = 0; i < nX;  i++) hX[i]  = (lcg_next(&st) - 0.5) * 0.1;
    for (size_t i = 0; i < nW1; i++) hW1[i] = (lcg_next(&st) - 0.5) * 0.05;
    for (size_t i = 0; i < nW2; i++) hW2[i] = (lcg_next(&st) - 0.5) * 0.05;

    /* FP64 device buffers */
    double *dX, *dW1, *dW2, *dH, *dH_act, *dY_f64;
    CK(cudaMalloc(&dX, nX*sizeof(double)));   CK(cudaMalloc(&dW1, nW1*sizeof(double)));
    CK(cudaMalloc(&dW2, nW2*sizeof(double))); CK(cudaMalloc(&dH, nH*sizeof(double)));
    CK(cudaMalloc(&dH_act, nH*sizeof(double))); CK(cudaMalloc(&dY_f64, nY*sizeof(double)));
    CK(cudaMemcpy(dX, hX, nX*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW1, hW1, nW1*sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW2, hW2, nW2*sizeof(double), cudaMemcpyHostToDevice));

    /* BF16 device buffers */
    __nv_bfloat16 *dX_b, *dW1_b, *dW2_b, *dH_b, *dY_b;
    CK(cudaMalloc(&dX_b, nX*sizeof(__nv_bfloat16)));   CK(cudaMalloc(&dW1_b, nW1*sizeof(__nv_bfloat16)));
    CK(cudaMalloc(&dW2_b, nW2*sizeof(__nv_bfloat16))); CK(cudaMalloc(&dH_b, nH*sizeof(__nv_bfloat16)));
    CK(cudaMalloc(&dY_b, nY*sizeof(__nv_bfloat16)));
    float* dY_stage; CK(cudaMalloc(&dY_stage, nY*sizeof(float)));

    cudaStream_t stream; CK(cudaStreamCreate(&stream)); CB(cublasSetStream(h, stream));
    auto cblk = [](size_t n) -> int { int b = (int)((n + 255) / 256); return b > 65535 ? 65535 : b; };
    f64_to_bf16_via_f32<<<cblk(nX), 256, 0, stream>>>(dX, dX_b, nX);
    f64_to_bf16_via_f32<<<cblk(nW1),256, 0, stream>>>(dW1, dW1_b, nW1);
    f64_to_bf16_via_f32<<<cblk(nW2),256, 0, stream>>>(dW2, dW2_b, nW2);
    CK(cudaStreamSynchronize(stream));

    /* ---- FP64 reference ---- */
    cublas_ffn_chain_f64(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_f64);
    CK(cudaStreamSynchronize(stream));
    CK(cudaMemcpy(hY_f64, dY_f64, nY*sizeof(double), cudaMemcpyDeviceToHost));
    {
        double* sf = (double*)malloc(n_iter*sizeof(double));
        for (int w = 0; w < n_warm; w++) cublas_ffn_chain_f64(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_f64);
        CK(cudaStreamSynchronize(stream));
        for (int it = 0; it < n_iter; it++) {
            double t0 = now_sec();
            cublas_ffn_chain_f64(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_f64);
            CK(cudaStreamSynchronize(stream));
            sf[it] = (now_sec() - t0) * 1000.0;
        }
        r.t_f64_chain_ms = median(sf, n_iter); free(sf);
    }

    /* ---- RFC 049 cuBLAS GemmEx BF16 chain ---- */
    for (int w = 0; w < n_warm; w++) cublas_ffn_chain_bf16(h, stream, M, D, FD, dX_b, dW1_b, dH_b, dW2_b, dY_b);
    CK(cudaStreamSynchronize(stream));
    {
        double* sb = (double*)malloc(n_iter*sizeof(double));
        for (int it = 0; it < n_iter; it++) {
            double t0 = now_sec();
            cublas_ffn_chain_bf16(h, stream, M, D, FD, dX_b, dW1_b, dH_b, dW2_b, dY_b);
            CK(cudaStreamSynchronize(stream));
            sb[it] = (now_sec() - t0) * 1000.0;
        }
        r.t_bf16_chain_ms = median(sb, n_iter); free(sb);
    }
    {
        double* dY_b_as_f64; CK(cudaMalloc(&dY_b_as_f64, nY*sizeof(double)));
        bf16_to_f64<<<cblk(nY), 256, 0, stream>>>(dY_b, dY_b_as_f64, nY);
        CK(cudaStreamSynchronize(stream));
        CK(cudaMemcpy(hY_bf16chain, dY_b_as_f64, nY*sizeof(double), cudaMemcpyDeviceToHost));
        CK(cudaFree(dY_b_as_f64));
    }

    /* ---- RFC 052 combined kernel ---- */
    int rc = dispatch_combined(M, D, FD, FD_HALF, r.smem_bytes, dX_b, dW1_b, dW2_b, dY_stage, stream);
    cudaError_t serr = cudaStreamSynchronize(stream);
    if (rc != 0 || serr != cudaSuccess) {
        snprintf(r.status, sizeof(r.status), "LAUNCH/SYNC_ERR rc=%d %s", rc,
                 serr != cudaSuccess ? cudaGetErrorString(serr) : "dispatch");
        fprintf(stderr, "[R052]   FAIL: %s\n", r.status);
        cudaStreamDestroy(stream);
        cudaFree(dX); cudaFree(dW1); cudaFree(dW2); cudaFree(dH); cudaFree(dH_act); cudaFree(dY_f64);
        cudaFree(dX_b); cudaFree(dW1_b); cudaFree(dW2_b); cudaFree(dH_b); cudaFree(dY_b); cudaFree(dY_stage);
        free(hX); free(hW1); free(hW2); free(hY_f64); free(hY_bf16chain); free(hY_combined);
        free(hY_run1); free(hY_run2);
        return r;
    }
    r.kernel_launched = 1;
    CK(cudaMemcpy(hY_run1, dY_stage, nY*sizeof(float), cudaMemcpyDeviceToHost));
    /* within-run determinism: recompute, byte-compare */
    dispatch_combined(M, D, FD, FD_HALF, r.smem_bytes, dX_b, dW1_b, dW2_b, dY_stage, stream);
    CK(cudaStreamSynchronize(stream));
    CK(cudaMemcpy(hY_run2, dY_stage, nY*sizeof(float), cudaMemcpyDeviceToHost));
    r.within_run_biteq = (memcmp(hY_run1, hY_run2, nY*sizeof(float)) == 0) ? 1 : 0;

    for (int w = 0; w < n_warm; w++)
        dispatch_combined(M, D, FD, FD_HALF, r.smem_bytes, dX_b, dW1_b, dW2_b, dY_stage, stream);
    CK(cudaStreamSynchronize(stream));
    {
        double* sc = (double*)malloc(n_iter*sizeof(double));
        for (int it = 0; it < n_iter; it++) {
            double t0 = now_sec();
            dispatch_combined(M, D, FD, FD_HALF, r.smem_bytes, dX_b, dW1_b, dW2_b, dY_stage, stream);
            CK(cudaStreamSynchronize(stream));
            sc[it] = (now_sec() - t0) * 1000.0;
        }
        r.t_combined_ms = median(sc, n_iter); free(sc);
    }
    {
        double* dY_stage_as_f64; CK(cudaMalloc(&dY_stage_as_f64, nY*sizeof(double)));
        f32_to_f64<<<cblk(nY), 256, 0, stream>>>(dY_stage, dY_stage_as_f64, nY);
        CK(cudaStreamSynchronize(stream));
        CK(cudaMemcpy(hY_combined, dY_stage_as_f64, nY*sizeof(double), cudaMemcpyDeviceToHost));
        CK(cudaFree(dY_stage_as_f64));
    }

    /* ---- numerics ---- */
    double ma_b = 0, mr_b = 0, ma_f = 0, mr_f = 0;
    for (size_t i = 0; i < nY; i++) {
        double db = fabs(hY_combined[i] - hY_bf16chain[i]);
        double df = fabs(hY_combined[i] - hY_f64[i]);
        if (db > ma_b) ma_b = db;
        if (df > ma_f) ma_f = df;
        double nb = fabs(hY_bf16chain[i]), nf = fabs(hY_f64[i]);
        if (nb > 1e-12 && db / nb > mr_b) mr_b = db / nb;
        if (nf > 1e-12 && df / nf > mr_f) mr_f = df / nf;
    }
    r.max_abs_delta_vs_bf16 = ma_b; r.max_rel_delta_vs_bf16 = mr_b;
    r.max_abs_delta_vs_f64  = ma_f; r.max_rel_delta_vs_f64  = mr_f;
    r.perf_ratio    = r.t_combined_ms / r.t_bf16_chain_ms;
    r.speedup_vs_f64 = r.t_f64_chain_ms / r.t_combined_ms;

    r.falsifier_perf_pass  = (r.perf_ratio <= 0.667) ? 1 : 0;
    r.falsifier_biteq_pass = (r.max_rel_delta_vs_bf16 <= 1e-3) ? 1 : 0;
    r.falsifier_det_pass   = r.within_run_biteq;
    snprintf(r.status, sizeof(r.status), "ok");

    fprintf(stderr, "[R052]   bf16_chain=%.4f ms · combined=%.4f ms · f64_chain=%.4f ms\n",
            r.t_bf16_chain_ms, r.t_combined_ms, r.t_f64_chain_ms);
    fprintf(stderr, "[R052]   perf_ratio(comb/bf16)=%.4f · speedup_vs_f64=%.3f× · rel|Δ|vs_bf16=%.3e · rel|Δ|vs_f64=%.3e · biteq=%d\n",
            r.perf_ratio, r.speedup_vs_f64, r.max_rel_delta_vs_bf16, r.max_rel_delta_vs_f64, r.within_run_biteq);
    fprintf(stderr, "[R052]   PERF≤0.667×=%s · BITEQ≤1e-3=%s · DET=%s · SMEM=%s\n",
            r.falsifier_perf_pass?"PASS":"FAIL", r.falsifier_biteq_pass?"PASS":"FAIL",
            r.falsifier_det_pass?"PASS":"FAIL", r.falsifier_smem_pass?"PASS":"FAIL");

    cudaStreamDestroy(stream);
    cudaFree(dX); cudaFree(dW1); cudaFree(dW2); cudaFree(dH); cudaFree(dH_act); cudaFree(dY_f64);
    cudaFree(dX_b); cudaFree(dW1_b); cudaFree(dW2_b); cudaFree(dH_b); cudaFree(dY_b); cudaFree(dY_stage);
    free(hX); free(hW1); free(hW2); free(hY_f64); free(hY_bf16chain); free(hY_combined);
    free(hY_run1); free(hY_run2);
    return r;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0; cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[R052] FATAL: no CUDA device\n"); return 1; }
    int ccM = 0, ccm = 0;
    cudaDeviceGetAttribute(&ccM, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&ccm, cudaDevAttrComputeCapabilityMinor, 0);
    cudaDeviceProp prop; cudaGetDeviceProperties(&prop, 0);
    fprintf(stderr, "[R052] device 0: name=%s cc=%d.%d sm=%d smem_optin=%zu KB\n",
            prop.name, ccM, ccm, prop.multiProcessorCount, prop.sharedMemPerBlockOptin / 1024);

    if (ccM < 9) {
        /* F-FORGE-RFC052-HOPPER-ONLY — cluster API needs sm_90+ */
        fprintf(stderr, "[R052] non-Hopper cc=%d.%d — combined kernel needs sm_90+ cluster API\n", ccM, ccm);
        FILE* jf = fopen("result.json", "w");
        fprintf(jf, "{\"error\":\"non-hopper device cc=%d.%d\",\"falsifier_hopper_only\":\"FALLBACK (would route to RFC 049 BF16 path)\"}\n", ccM, ccm);
        fclose(jf);
        return 2;
    }

    cublasHandle_t h; CB(cublasCreate(&h));
    int cbM = 0, cbm = 0, cbp = 0;
    cublasGetProperty(MAJOR_VERSION, &cbM); cublasGetProperty(MINOR_VERSION, &cbm); cublasGetProperty(PATCH_LEVEL, &cbp);
    fprintf(stderr, "[R052] cuBLAS %d.%d.%d\n", cbM, cbm, cbp);

    /* Pre-registered shapes. INFER probes the launch-bound regime (the genuine
     * open window per the instrument-first prediction). */
    struct { int M, D, FD, warm, iter; const char* tier; } shapes[] = {
        {  16, 4096, 11008, 5, 31, "INFER"  },   /* launch-bound probe */
        {  64,  768,  3072, 5, 31, "SMALL"  },
        { 128,  768,  3072, 5, 31, "MEDIUM" },
        { 128, 4096, 11008, 3, 21, "LARGE"  },   /* Llama-7B FFN */
    };
    int n_shapes = (int)(sizeof(shapes)/sizeof(shapes[0]));
    shape_result results[8];
    for (int i = 0; i < n_shapes; i++)
        results[i] = run_shape(h, shapes[i].M, shapes[i].D, shapes[i].FD, shapes[i].warm, shapes[i].iter);

    FILE* jf = fopen("result.json", "w");
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_rfc052_combined_bf16_dsm_stage2\",\n");
    fprintf(jf, "  \"date\": \"2026-05-19\",\n");
    fprintf(jf, "  \"device_name\": \"%s\",\n", prop.name);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", ccM, ccm);
    fprintf(jf, "  \"sm_count\": %d,\n", prop.multiProcessorCount);
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cbM, cbm, cbp);
    fprintf(jf, "  \"baseline\": \"cublasGemmEx BF16 chain (RFC 049 wall-path)\",\n");
    fprintf(jf, "  \"contender\": \"RFC 052 combined Hopper BF16 WMMA + DSM cluster kernel\",\n");
    fprintf(jf, "  \"shapes\": [\n");
    for (int i = 0; i < n_shapes; i++) {
        shape_result* r = &results[i];
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"tier\":\"%s\", \"M\":%d, \"D\":%d, \"FD\":%d, \"smem_bytes\":%d, "
            "\"kernel_launched\":%d, \"status\":\"%s\", "
            "\"t_bf16_chain_ms\":%.5f, \"t_combined_ms\":%.5f, \"t_f64_chain_ms\":%.5f, "
            "\"perf_ratio_comb_over_bf16\":%.5f, \"speedup_vs_f64\":%.4f, "
            "\"max_rel_delta_vs_bf16\":%.3e, \"max_rel_delta_vs_f64\":%.3e, "
            "\"within_run_biteq\":%d, "
            "\"falsifier_perf_pass\":%d, \"falsifier_biteq_pass\":%d, "
            "\"falsifier_det_pass\":%d, \"falsifier_smem_pass\":%d }",
            shapes[i].tier, r->M, r->D, r->FD, r->smem_bytes,
            r->kernel_launched, r->status,
            r->t_bf16_chain_ms, r->t_combined_ms, r->t_f64_chain_ms,
            r->perf_ratio, r->speedup_vs_f64,
            r->max_rel_delta_vs_bf16, r->max_rel_delta_vs_f64,
            r->within_run_biteq,
            r->falsifier_perf_pass, r->falsifier_biteq_pass,
            r->falsifier_det_pass, r->falsifier_smem_pass);
    }
    fprintf(jf, "\n  ],\n");

    int li = -1;
    for (int i = 0; i < n_shapes; i++) if (strcmp(shapes[i].tier, "LARGE") == 0) li = i;
    int all_biteq = 1, all_det = 1, all_smem = 1;
    for (int i = 0; i < n_shapes; i++) {
        if (results[i].kernel_launched) {
            if (!results[i].falsifier_biteq_pass) all_biteq = 0;
            if (!results[i].falsifier_det_pass)   all_det = 0;
        } else { all_biteq = all_det = 0; }
        if (!results[i].falsifier_smem_pass) all_smem = 0;
    }
    fprintf(jf, "  \"falsifier_verdicts\": {\n");
    if (li >= 0)
        fprintf(jf, "    \"F-FORGE-RFC052-COMBINED-PERF\": { \"threshold\":\"≤0.667× cuBLAS BF16 chain\", \"ratio\":%.4f, \"shape\":\"LARGE\", \"verdict\":\"%s\" },\n",
                results[li].perf_ratio, results[li].falsifier_perf_pass ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC052-BITEQ-VS-RFC049\": { \"threshold\":\"rel|Δ|≤1e-3 (all shapes)\", \"verdict\":\"%s\" },\n",
            all_biteq ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC052-LAYERCAST-DET\": { \"threshold\":\"within-run bit-equal (all shapes)\", \"verdict\":\"%s\" },\n",
            all_det ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC052-DSM-INTERMEDIATE-FIT\": { \"threshold\":\"≤227 KB/block\", \"verdict\":\"%s\" },\n",
            all_smem ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC052-HOPPER-ONLY\": { \"threshold\":\"cluster launch on sm_90+\", \"verdict\":\"%s\" }\n",
            results[0].kernel_launched ? "PASS" : "FAIL");
    fprintf(jf, "  },\n");
    fprintf(jf, "  \"notes\": [\n");
    fprintf(jf, "    \"Baseline = cublasGemmEx BF16 chain (RFC 049 wall-path, 3 ops).\",\n");
    fprintf(jf, "    \"Contender = RFC 052 hand WMMA + 2-block cluster DSM combined kernel.\",\n");
    fprintf(jf, "    \"Pre-fire prediction (instrument-first): hand WMMA ~41-43%% peak vs cuBLAS ~77-87%% — combined kernel expected SLOWER at compute-bound shapes (LARGE/MEDIUM); INFER probes the launch-bound window.\",\n");
    fprintf(jf, "    \"perf_ratio = t_combined / t_bf16_chain; ≤0.667 = PASS (the RFC 052 1.5x-over-RFC-049 claim).\"\n");
    fprintf(jf, "  ]\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "\n[R052] === SUMMARY ===\n");
    for (int i = 0; i < n_shapes; i++) {
        shape_result* r = &results[i];
        fprintf(stderr, "  %-7s M=%d D=%d FD=%d: bf16_chain=%.4f combined=%.4f ratio=%.4f biteq=%d %s\n",
                shapes[i].tier, r->M, r->D, r->FD, r->t_bf16_chain_ms, r->t_combined_ms,
                r->perf_ratio, r->within_run_biteq, r->status);
    }
    cublasDestroy(h);
    return 0;
}
