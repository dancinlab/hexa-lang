/* r049_bf16_fused_ffn.cu — forge RFC 049 Phase R' Stage 1 (BF16 substrate first fire)
 *
 * Pre-registered (RFC 049 §"Falsifier battery"):
 *   F-FORGE-RFC049-BF16-TC-PERF  — BF16 fused FFN ≥ 5 × cuBLAS Dgemm FP64 chain (Llama-7B scale)
 *   F-FORGE-RFC049-LAYERCAST-DET — same-precision same-batch single-GPU bit-equal (D' generalization)
 *   F-FORGE-RFC049-LAYERCAST-MEM — BF16 footprint ≤ 0.3× FP64 (computed from sizeof anchor)
 *
 * --- Design (BF16 fused FFN, single-block per output tile) ---
 *
 *   X  [M , D ]  input activations (BF16, row-major)
 *   W1 [D , FD]  up-projection      (BF16, row-major)
 *   W2 [FD, D ]  down-projection    (BF16, row-major)
 *
 *   H  = X @ W1        [M, FD]  BF16 input, FP32 acc, BF16 out (via FP32→BF16 cast)
 *   H' = SiLU(H)       [M, FD]  FP32 compute path, BF16 out
 *   Y  = H' @ W2       [M, D]   BF16 input, FP32 acc, BF16 out
 *
 * For the BF16 path we use cuBLASLt-equivalent path via cublasGemmEx with
 *   CUDA_R_16BF input, CUDA_R_32F compute (CUBLAS_COMPUTE_32F), output BF16.
 *   Tensor Core (BF16 TC) automatic on sm_80+. This is the standard
 *   "library-grade" BF16 path — competitive with hand WMMA only after
 *   weeks of CUTLASS-grade tuning (C Phase 3 wall FAIL anchor for FP64
 *   shows this). We honest-anchor against cuBLAS BF16 GemmEx, not hand
 *   WMMA, because the goal is "BF16 substrate wins vs FP64 substrate"
 *   not "hand kernel beats cuBLAS".
 *
 *   Comparison baseline:
 *     - cuBLAS Dgemm FP64 chain (same M/D/FD shape) — RFC 044 B Stage 1
 *       anchor (Llama-7B M=128 D=4096 FD=11008 H200 = 0.4461 ms).
 *     - cuBLAS GemmEx BF16 chain (same shape) — this is the contender.
 *
 * Honest scope:
 *   - We are NOT writing a hand-WMMA BF16 kernel that beats cuBLAS BF16
 *     GemmEx. That's the C Phase 3 lesson (41-43% peak vs 77-87% peak).
 *   - We ARE measuring whether the BF16-TC substrate path (via cuBLAS
 *     GemmEx) clears the ≥ 5× FP64 cuBLAS Dgemm bar.
 *   - Numerical anchor: BF16 vs FP64 max|Δ| ~ 1e-2 to 1e-3 relative
 *     (literature LayerCast); we report measured.
 *
 * Reference: RFC 049 §"Architecture (3-layer cast pyramid)" — Layer 2
 *   BF16 storage / Layer 3 BF16 TC compute with FP32 accumulator. This
 *   fire validates the substrate (Stage 1), not the LayerCast policy
 *   surface (Stage 2 follow-up RFC 050+).
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

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { fprintf(stderr, "[R049] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } } while (0)
#define CB(call) do { cublasStatus_t _s = (call); if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[R049] cuBLAS %s:%d %d\n", __FILE__, __LINE__, (int)_s); exit(1); } } while (0)

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
 * BF16 conversion helpers
 *
 * BF16 = bfloat16: 8-bit exponent (FP32 dynamic range), 7-bit mantissa.
 * Stored as __nv_bfloat16 (16-bit unsigned with raw bit pattern).
 *
 * Conversions: round-to-nearest-even is the IEEE 754 default; the
 * NVIDIA __float2bfloat16() intrinsic uses RNE.
 * ============================================================================ */
__global__ void f32_to_bf16(const float* in, __nv_bfloat16* out, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = __float2bfloat16(in[i]);
}

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

/* SiLU(x) = x * sigmoid(x), applied in-place on a BF16 buffer via FP32.
 * This matches the "LayerCast" pattern: storage BF16, compute FP32.
 */
__global__ void silu_bf16(__nv_bfloat16* h, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        float v = __bfloat162float(h[i]);
        float sig = 1.0f / (1.0f + expf(-v));
        h[i] = __float2bfloat16(v * sig);
    }
}

/* FP64 SiLU (for cuBLAS Dgemm reference chain). */
__global__ void silu_f64(double* y, const double* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        double v = x[i];
        double sig = 1.0 / (1.0 + exp(-v));
        y[i] = v * sig;
    }
}

/* ============================================================================
 * cuBLAS Dgemm FP64 reference chain (baseline)
 *
 * H = X · W1   (M×D · D×FD)
 * H' = SiLU(H)
 * Y = H' · W2  (M×FD · FD×D)
 *
 * cuBLAS is column-major; row-major emulation via swapped op trick.
 * ============================================================================ */
static void cublas_ffn_chain_f64(cublasHandle_t h, cudaStream_t st,
                                  int M, int D, int FD,
                                  const double* dX, const double* dW1,
                                  double* dH, double* dH_act,
                                  const double* dW2, double* dY) {
    const double alpha = 1.0, beta = 0.0;
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D, &alpha, dW1, FD, dX, D, &beta, dH, FD);
    int n_act = M * FD;
    int threads = 256, blocks = (n_act + threads - 1) / threads;
    if (blocks > 65535) blocks = 65535;
    silu_f64<<<blocks, threads, 0, st>>>(dH_act, dH, n_act);
    cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD, &alpha, dW2, D, dH_act, FD, &beta, dY, D);
}

/* ============================================================================
 * cuBLAS GemmEx BF16 chain (forge BF16 substrate path)
 *
 * Same shape, but:
 *   - inputs CUDA_R_16BF (BF16)
 *   - compute CUBLAS_COMPUTE_32F (FP32 accumulator)
 *   - output CUDA_R_16BF (BF16)
 *   - algo CUBLAS_GEMM_DEFAULT_TENSOR_OP (BF16 Tensor Core on sm_80+)
 *
 * Cast SiLU operates in FP32 path via silu_bf16 kernel above.
 * ============================================================================ */
static cublasStatus_t gemm_ex_bf16(cublasHandle_t h,
                                    cublasOperation_t opA, cublasOperation_t opB,
                                    int m, int n, int k,
                                    const __nv_bfloat16* A, int lda,
                                    const __nv_bfloat16* B, int ldb,
                                    __nv_bfloat16* C, int ldc)
{
    const float alpha = 1.0f, beta = 0.0f;
    return cublasGemmEx(h, opA, opB, m, n, k,
                        &alpha,
                        A, CUDA_R_16BF, lda,
                        B, CUDA_R_16BF, ldb,
                        &beta,
                        C, CUDA_R_16BF, ldc,
                        CUBLAS_COMPUTE_32F,
                        CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}

static void cublas_ffn_chain_bf16(cublasHandle_t h, cudaStream_t st,
                                   int M, int D, int FD,
                                   const __nv_bfloat16* dX, const __nv_bfloat16* dW1,
                                   __nv_bfloat16* dH,
                                   const __nv_bfloat16* dW2, __nv_bfloat16* dY) {
    /* H = X · W1 — row-major (M×D)·(D×FD) → (M×FD)
     * cublas column-major trick: compute swapped → gemm(opN,opN, FD, M, D, W1, FD, X, D, H, FD) */
    CB(gemm_ex_bf16(h, CUBLAS_OP_N, CUBLAS_OP_N, FD, M, D, dW1, FD, dX, D, dH, FD));
    /* In-place SiLU on H (BF16, FP32 compute) */
    int n_act = M * FD;
    int threads = 256, blocks = (n_act + threads - 1) / threads;
    if (blocks > 65535) blocks = 65535;
    silu_bf16<<<blocks, threads, 0, st>>>(dH, (size_t)n_act);
    /* Y = H · W2 — (M×FD)·(FD×D) → (M×D) */
    CB(gemm_ex_bf16(h, CUBLAS_OP_N, CUBLAS_OP_N, D, M, FD, dW2, D, dH, FD, dY, D));
}

/* ============================================================================
 * Per-shape harness
 * ============================================================================ */
struct shape_result {
    int M, D, FD;
    /* Baseline (cuBLAS Dgemm FP64) */
    double t_f64_ms;
    double f64_tflops;
    /* Contender (cuBLAS GemmEx BF16) */
    double t_bf16_ms;
    double bf16_tflops;
    /* Wall ratio: t_f64 / t_bf16 = how many × BF16 is faster */
    double speedup_ratio_f64_over_bf16;
    /* Numerical anchor: max|Δ| of Y in FP64 absolute */
    double max_abs_delta_y;
    double max_rel_delta_y;
    double mean_abs_delta_y;
    /* Memory: BF16 footprint / FP64 footprint */
    double mem_ratio_bf16_over_f64;
    /* Within-run determinism (BF16, single GPU, single process): run twice, byte-compare */
    int bf16_within_run_biteq;
    /* Falsifier verdicts */
    int falsifier_perf_pass;        /* ≥ 5× */
    int falsifier_det_pass;         /* within-run bit-equal */
    int falsifier_mem_pass;         /* ≤ 0.3× */
    char status[128];
};

static shape_result run_shape(cublasHandle_t h, int M, int D, int FD,
                              int n_warm, int n_iter) {
    shape_result r;
    memset(&r, 0, sizeof(r));
    r.M = M; r.D = D; r.FD = FD;
    fprintf(stderr, "[R049] === M=%d D=%d FD=%d (warm=%d iter=%d) ===\n",
            M, D, FD, n_warm, n_iter);

    /* Host buffers (FP64 ground truth) */
    size_t szX_f64 = (size_t)M * D * sizeof(double);
    size_t szW1_f64 = (size_t)D * FD * sizeof(double);
    size_t szW2_f64 = (size_t)FD * D * sizeof(double);
    size_t szH_f64  = (size_t)M * FD * sizeof(double);
    size_t szY_f64  = (size_t)M * D * sizeof(double);

    size_t szX_bf16 = szX_f64 / 4;
    size_t szW1_bf16 = szW1_f64 / 4;
    size_t szW2_bf16 = szW2_f64 / 4;
    size_t szH_bf16  = szH_f64 / 4;
    size_t szY_bf16  = szY_f64 / 4;

    double* hX = (double*)malloc(szX_f64);
    double* hW1 = (double*)malloc(szW1_f64);
    double* hW2 = (double*)malloc(szW2_f64);
    double* hY_f64 = (double*)malloc(szY_f64);
    double* hY_bf16_as_f64 = (double*)malloc(szY_f64);
    __nv_bfloat16* hY_bf16_run1 = (__nv_bfloat16*)malloc(szY_bf16);
    __nv_bfloat16* hY_bf16_run2 = (__nv_bfloat16*)malloc(szY_bf16);

    uint64_t st = 0x049b16feULL ^ (uint64_t)(M * 1000003 + D * 1009 + FD * 31);
    /* Small values keep activations modest so BF16 doesn't saturate */
    for (size_t i = 0; i < (size_t)M * D; i++)  hX[i]  = (lcg_next(&st) - 0.5) * 0.1;
    for (size_t i = 0; i < (size_t)D * FD; i++) hW1[i] = (lcg_next(&st) - 0.5) * 0.05;
    for (size_t i = 0; i < (size_t)FD * D; i++) hW2[i] = (lcg_next(&st) - 0.5) * 0.05;

    /* Device buffers — FP64 path */
    double *dX, *dW1, *dW2, *dH, *dH_act, *dY_f64;
    CK(cudaMalloc(&dX, szX_f64));
    CK(cudaMalloc(&dW1, szW1_f64));
    CK(cudaMalloc(&dW2, szW2_f64));
    CK(cudaMalloc(&dH, szH_f64));
    CK(cudaMalloc(&dH_act, szH_f64));
    CK(cudaMalloc(&dY_f64, szY_f64));
    CK(cudaMemcpy(dX, hX, szX_f64, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW1, hW1, szW1_f64, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW2, hW2, szW2_f64, cudaMemcpyHostToDevice));

    /* Device buffers — BF16 path */
    __nv_bfloat16 *dX_bf16, *dW1_bf16, *dW2_bf16, *dH_bf16, *dY_bf16;
    CK(cudaMalloc(&dX_bf16, szX_bf16));
    CK(cudaMalloc(&dW1_bf16, szW1_bf16));
    CK(cudaMalloc(&dW2_bf16, szW2_bf16));
    CK(cudaMalloc(&dH_bf16, szH_bf16));
    CK(cudaMalloc(&dY_bf16, szY_bf16));

    cudaStream_t stream; CK(cudaStreamCreate(&stream));
    CB(cublasSetStream(h, stream));

    /* Cast FP64 → BF16 once for substrate inputs */
    int casts_n = 256;
    auto cast_blocks = [](size_t n) -> int { int b = (int)((n + 255) / 256); return b > 65535 ? 65535 : b; };
    f64_to_bf16_via_f32<<<cast_blocks((size_t)M * D), casts_n, 0, stream>>>(dX, dX_bf16, (size_t)M * D);
    f64_to_bf16_via_f32<<<cast_blocks((size_t)D * FD), casts_n, 0, stream>>>(dW1, dW1_bf16, (size_t)D * FD);
    f64_to_bf16_via_f32<<<cast_blocks((size_t)FD * D), casts_n, 0, stream>>>(dW2, dW2_bf16, (size_t)FD * D);
    CK(cudaStreamSynchronize(stream));

    /* ---- FP64 path: warmup + measure + collect Y ---- */
    for (int w = 0; w < n_warm; w++) {
        cublas_ffn_chain_f64(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_f64);
    }
    CK(cudaStreamSynchronize(stream));
    double* sf64 = (double*)malloc((size_t)n_iter * sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        cublas_ffn_chain_f64(h, stream, M, D, FD, dX, dW1, dH, dH_act, dW2, dY_f64);
        CK(cudaStreamSynchronize(stream));
        sf64[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_f64_ms = median(sf64, n_iter);
    free(sf64);
    CK(cudaMemcpy(hY_f64, dY_f64, szY_f64, cudaMemcpyDeviceToHost));

    /* ---- BF16 path: warmup + measure + collect Y (run1 + run2 for det check) ---- */
    for (int w = 0; w < n_warm; w++) {
        cublas_ffn_chain_bf16(h, stream, M, D, FD, dX_bf16, dW1_bf16, dH_bf16, dW2_bf16, dY_bf16);
    }
    CK(cudaStreamSynchronize(stream));
    double* sbf = (double*)malloc((size_t)n_iter * sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        cublas_ffn_chain_bf16(h, stream, M, D, FD, dX_bf16, dW1_bf16, dH_bf16, dW2_bf16, dY_bf16);
        CK(cudaStreamSynchronize(stream));
        sbf[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_bf16_ms = median(sbf, n_iter);
    free(sbf);
    /* Run1 capture */
    CK(cudaMemcpy(hY_bf16_run1, dY_bf16, szY_bf16, cudaMemcpyDeviceToHost));
    /* Run2 — recompute, same inputs, same stream, same GPU, same process → bit-equal anchor */
    cublas_ffn_chain_bf16(h, stream, M, D, FD, dX_bf16, dW1_bf16, dH_bf16, dW2_bf16, dY_bf16);
    CK(cudaStreamSynchronize(stream));
    CK(cudaMemcpy(hY_bf16_run2, dY_bf16, szY_bf16, cudaMemcpyDeviceToHost));
    r.bf16_within_run_biteq = (memcmp(hY_bf16_run1, hY_bf16_run2, szY_bf16) == 0) ? 1 : 0;

    /* Cast BF16 Y back to FP64 for numerical comparison with FP64 baseline */
    double* dY_bf16_as_f64;
    CK(cudaMalloc(&dY_bf16_as_f64, szY_f64));
    bf16_to_f64<<<cast_blocks((size_t)M * D), casts_n, 0, stream>>>(dY_bf16, dY_bf16_as_f64, (size_t)M * D);
    CK(cudaStreamSynchronize(stream));
    CK(cudaMemcpy(hY_bf16_as_f64, dY_bf16_as_f64, szY_f64, cudaMemcpyDeviceToHost));
    CK(cudaFree(dY_bf16_as_f64));

    /* Compare numerics — BF16 vs FP64 baseline */
    double max_abs = 0, max_rel = 0, sum_abs = 0;
    size_t n_y = (size_t)M * D;
    for (size_t i = 0; i < n_y; i++) {
        double d = fabs(hY_f64[i] - hY_bf16_as_f64[i]);
        if (d > max_abs) max_abs = d;
        sum_abs += d;
        double denom = fabs(hY_f64[i]);
        if (denom > 1e-12) {
            double rr = d / denom;
            if (rr > max_rel) max_rel = rr;
        }
    }
    r.max_abs_delta_y = max_abs;
    r.max_rel_delta_y = max_rel;
    r.mean_abs_delta_y = sum_abs / (double)n_y;

    /* Memory ratio (BF16 / FP64 across X+W1+W2+H+Y) */
    double mem_bf16 = (double)(szX_bf16 + szW1_bf16 + szW2_bf16 + szH_bf16 + szY_bf16);
    double mem_f64  = (double)(szX_f64 + szW1_f64 + szW2_f64 + szH_f64 + szY_f64);
    r.mem_ratio_bf16_over_f64 = mem_bf16 / mem_f64;

    /* FLOPS: 2× 2MNK per matmul → 2 × (2·M·D·FD + 2·M·FD·D) = 4·M·FD·(D + D) */
    double flops = 4.0 * (double)M * (double)FD * (double)D;
    r.f64_tflops = flops / (r.t_f64_ms * 1e-3) / 1e12;
    r.bf16_tflops = flops / (r.t_bf16_ms * 1e-3) / 1e12;
    r.speedup_ratio_f64_over_bf16 = r.t_f64_ms / r.t_bf16_ms;

    /* Falsifier verdicts */
    r.falsifier_perf_pass = (r.speedup_ratio_f64_over_bf16 >= 5.0) ? 1 : 0;
    r.falsifier_det_pass = r.bf16_within_run_biteq;
    r.falsifier_mem_pass = (r.mem_ratio_bf16_over_f64 <= 0.3) ? 1 : 0;

    snprintf(r.status, sizeof(r.status), "ok");
    fprintf(stderr, "[R049]   FP64=%.4f ms (%.2f TF) · BF16=%.4f ms (%.2f TF) · speedup=%.3f×\n",
            r.t_f64_ms, r.f64_tflops, r.t_bf16_ms, r.bf16_tflops, r.speedup_ratio_f64_over_bf16);
    fprintf(stderr, "[R049]   max|Δ|=%.3e · max_rel|Δ|=%.3e · mean|Δ|=%.3e · within_biteq=%d · mem_ratio=%.4f\n",
            r.max_abs_delta_y, r.max_rel_delta_y, r.mean_abs_delta_y, r.bf16_within_run_biteq, r.mem_ratio_bf16_over_f64);
    fprintf(stderr, "[R049]   PERF≥5×=%s · DET-within=%s · MEM≤0.3×=%s\n",
            r.falsifier_perf_pass ? "PASS" : "FAIL",
            r.falsifier_det_pass  ? "PASS" : "FAIL",
            r.falsifier_mem_pass  ? "PASS" : "FAIL");

    /* Cleanup */
    cudaStreamDestroy(stream);
    CK(cudaFree(dX)); CK(cudaFree(dW1)); CK(cudaFree(dW2));
    CK(cudaFree(dH)); CK(cudaFree(dH_act)); CK(cudaFree(dY_f64));
    CK(cudaFree(dX_bf16)); CK(cudaFree(dW1_bf16)); CK(cudaFree(dW2_bf16));
    CK(cudaFree(dH_bf16)); CK(cudaFree(dY_bf16));
    free(hX); free(hW1); free(hW2); free(hY_f64); free(hY_bf16_as_f64);
    free(hY_bf16_run1); free(hY_bf16_run2);

    return r;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0; cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[R049] FATAL: no CUDA device\n"); return 1; }
    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    cudaDeviceProp prop; cudaGetDeviceProperties(&prop, 0);
    fprintf(stderr, "[R049] device 0: name=%s cc=%d.%d sm=%d\n",
            prop.name, cc_major, cc_minor, prop.multiProcessorCount);

    if (cc_major < 8) {
        fprintf(stderr, "[R049] FATAL: BF16 Tensor Core requires sm_80+, got cc=%d.%d\n",
                cc_major, cc_minor);
        FILE* jf = fopen("result.json", "w");
        fprintf(jf, "{\"error\":\"non-bf16-tc device cc=%d.%d\"}\n", cc_major, cc_minor);
        fclose(jf);
        return 2;
    }

    cublasHandle_t h; CB(cublasCreate(&h));
    int cb_maj = 0, cb_min = 0, cb_pat = 0;
    cublasGetProperty(MAJOR_VERSION, &cb_maj);
    cublasGetProperty(MINOR_VERSION, &cb_min);
    cublasGetProperty(PATCH_LEVEL, &cb_pat);
    fprintf(stderr, "[R049] cuBLAS version %d.%d.%d\n", cb_maj, cb_min, cb_pat);

    /* Pre-registered shapes (RFC 049 §"BF16 fused FFN ≥ 5× cuBLAS Dgemm FP64 chain") */
    struct { int M, D, FD; int warm, iter; const char* tier; } shapes[] = {
        {  64,  768,  3072, 5, 31, "SMALL"  },   /* small */
        { 128,  768,  3072, 5, 31, "MEDIUM" },   /* medium */
        { 128, 4096, 11008, 3, 21, "LARGE"  },   /* Llama-7B FFN */
    };
    int n_shapes = (int)(sizeof(shapes)/sizeof(shapes[0]));

    shape_result results[8];
    for (int i = 0; i < n_shapes; i++) {
        results[i] = run_shape(h, shapes[i].M, shapes[i].D, shapes[i].FD,
                                shapes[i].warm, shapes[i].iter);
    }

    /* ---- Emit result.json ---- */
    FILE* jf = fopen("result.json", "w");
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_rfc049_phaseR_bf16_fused_ffn_stage1\",\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_name\": \"%s\",\n", prop.name);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"sm_count\": %d,\n", prop.multiProcessorCount);
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cb_maj, cb_min, cb_pat);
    fprintf(jf, "  \"baseline_path\": \"cublasDgemm FP64 chain (3 ops: gemm + silu + gemm)\",\n");
    fprintf(jf, "  \"contender_path\": \"cublasGemmEx BF16 (CUDA_R_16BF input, CUBLAS_COMPUTE_32F, BF16 TC) chain\",\n");
    fprintf(jf, "  \"shapes\": [\n");
    for (int i = 0; i < n_shapes; i++) {
        shape_result* r = &results[i];
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"tier\":\"%s\", \"M\":%d, \"D\":%d, \"FD\":%d, "
            "\"t_f64_ms\":%.5f, \"t_bf16_ms\":%.5f, "
            "\"f64_tflops\":%.4f, \"bf16_tflops\":%.4f, "
            "\"speedup_ratio_f64_over_bf16\":%.4f, "
            "\"max_abs_delta_y\":%.3e, \"max_rel_delta_y\":%.3e, \"mean_abs_delta_y\":%.3e, "
            "\"mem_ratio_bf16_over_f64\":%.5f, "
            "\"bf16_within_run_biteq\":%d, "
            "\"falsifier_perf_pass\":%d, \"falsifier_det_pass\":%d, \"falsifier_mem_pass\":%d, "
            "\"status\":\"%s\" }",
            shapes[i].tier, r->M, r->D, r->FD,
            r->t_f64_ms, r->t_bf16_ms, r->f64_tflops, r->bf16_tflops,
            r->speedup_ratio_f64_over_bf16,
            r->max_abs_delta_y, r->max_rel_delta_y, r->mean_abs_delta_y,
            r->mem_ratio_bf16_over_f64,
            r->bf16_within_run_biteq,
            r->falsifier_perf_pass, r->falsifier_det_pass, r->falsifier_mem_pass,
            r->status);
    }
    fprintf(jf, "\n  ],\n");
    /* Aggregate verdicts (per shape × falsifier) */
    int large_idx = -1;
    for (int i = 0; i < n_shapes; i++) if (strcmp(shapes[i].tier, "LARGE") == 0) large_idx = i;
    fprintf(jf, "  \"falsifier_verdicts\": {\n");
    if (large_idx >= 0) {
        shape_result* r = &results[large_idx];
        fprintf(jf, "    \"F-FORGE-RFC049-BF16-TC-PERF\": { \"threshold\":\"≥5×\", \"ratio\":%.4f, \"shape\":\"LARGE Llama-7B\", \"verdict\":\"%s\" },\n",
                r->speedup_ratio_f64_over_bf16, r->falsifier_perf_pass ? "PASS" : "FAIL");
    }
    int all_det = 1, all_mem = 1;
    double worst_mem = 0;
    for (int i = 0; i < n_shapes; i++) {
        if (!results[i].falsifier_det_pass) all_det = 0;
        if (!results[i].falsifier_mem_pass) all_mem = 0;
        if (results[i].mem_ratio_bf16_over_f64 > worst_mem) worst_mem = results[i].mem_ratio_bf16_over_f64;
    }
    fprintf(jf, "    \"F-FORGE-RFC049-LAYERCAST-DET\": { \"threshold\":\"within-run bit-equal (all shapes)\", \"verdict\":\"%s\" },\n",
            all_det ? "PASS" : "FAIL");
    fprintf(jf, "    \"F-FORGE-RFC049-LAYERCAST-MEM\": { \"threshold\":\"≤0.3×\", \"worst_ratio\":%.4f, \"verdict\":\"%s\" }\n",
            worst_mem, all_mem ? "PASS" : "FAIL");
    fprintf(jf, "  },\n");
    fprintf(jf, "  \"notes\": [\n");
    fprintf(jf, "    \"Baseline = cublasDgemm FP64 chain (production reference, RFC 044 B Stage 1 anchor).\",\n");
    fprintf(jf, "    \"Contender = cublasGemmEx BF16 with FP32 accumulator (BF16 TC on sm_80+).\",\n");
    fprintf(jf, "    \"Numerical: max|Δ| vs FP64 expected ~1e-3 relative (LayerCast paper anchor).\",\n");
    fprintf(jf, "    \"Mem ratio: BF16 = 2 B/elem vs FP64 8 B/elem → expected 0.25 across X+W1+W2+H+Y.\",\n");
    fprintf(jf, "    \"Within-run det: same process, same GPU, same stream, twice; byte-compare BF16 outputs.\"\n");
    fprintf(jf, "  ]\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "\n[R049] === SUMMARY ===\n");
    for (int i = 0; i < n_shapes; i++) {
        shape_result* r = &results[i];
        fprintf(stderr, "  %-7s M=%d D=%d FD=%d: f64=%.4f bf16=%.4f speedup=%.3f× max|Δ|=%.3e mem=%.3f biteq=%d\n",
                shapes[i].tier, r->M, r->D, r->FD, r->t_f64_ms, r->t_bf16_ms,
                r->speedup_ratio_f64_over_bf16, r->max_abs_delta_y, r->mem_ratio_bf16_over_f64,
                r->bf16_within_run_biteq);
    }

    cublasDestroy(h);
    return 0;
}
