/* r049_layercast_linear.cu — forge RFC 049 Phase R' Stage 1 (LayerCast pattern)
 *
 * Pre-registered (RFC 049 §"Falsifier battery"):
 *   F-FORGE-RFC049-LAYERCAST-DIVERGE — BF16 weight + FP32 compute path
 *     vs FP32 reference: relative error ≤ 5% (LayerCast paper anchor ≤ 3.4%).
 *
 * --- Design (LayerCast linear fwd) ---
 *
 *   Storage:  W_bf16  [K, N]  bfloat16
 *   Compute:  X_f32   [M, K]  float32
 *             W_f32   [K, N]  float32 (just-in-time upcast from W_bf16, via FP32 compute)
 *             Y_f32   [M, N]  float32
 *
 *   Pattern: load BF16 weight → upcast to FP32 inside the matmul kernel
 *   (BF16 storage, FP32 compute). This is the LayerCast paradigm:
 *   memory-side savings (4× weight footprint reduction) without losing
 *   FP32 numerical fidelity.
 *
 *   Implementation: use cublasGemmEx with mixed type:
 *     A (X)        : CUDA_R_32F
 *     B (W_bf16)   : CUDA_R_16BF
 *     compute      : CUBLAS_COMPUTE_32F
 *     C (Y)        : CUDA_R_32F
 *
 *   Comparison:
 *     - FP32 reference:  cublasSgemm with W cast up to FP32 once on host
 *     - LayerCast:       cublasGemmEx with W_bf16 directly (FP32 compute)
 *     - Numerical Δ:     relative error vs FP32 reference
 *
 *   NOTE: cuBLAS GemmEx requires both A/B same type historically; modern
 *   cuBLAS 12.x supports mixed-precision A=FP32 B=BF16. If unsupported,
 *   fallback path = explicit on-device upcast W_bf16 → W_f32 followed by
 *   cublasSgemm. We try the direct mixed path first; on failure, fallback.
 *
 * Honest scope:
 *   - This tests the LayerCast PATTERN (storage/compute precision split),
 *     not a custom kernel implementation. The LayerCast paper anchor is
 *     functional/numerical, not performance-against-a-WMMA-kernel.
 *   - Memory measurement: explicit anchor (BF16 weight 2 B/elem vs FP32
 *     4 B/elem = 0.5× weight footprint). The 34% reduction in the
 *     LayerCast paper is at activation-cache layer; here we anchor just
 *     the weight layer.
 *   - We are NOT measuring training convergence (Tier 4 of RFC 049, that's
 *     Stage 2+ with flame trainer integration).
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

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { fprintf(stderr, "[R049LC] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } } while (0)
#define CB(call) do { cublasStatus_t _s = (call); if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[R049LC] cuBLAS %s:%d %d\n", __FILE__, __LINE__, (int)_s); exit(1); } } while (0)

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

__global__ void f32_to_bf16_k(const float* in, __nv_bfloat16* out, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = __float2bfloat16(in[i]);
}

__global__ void bf16_to_f32_k(const __nv_bfloat16* in, float* out, size_t n) {
    size_t i = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = __bfloat162float(in[i]);
}

/* ============================================================================
 * Two paths:
 *   1) reference_fp32: cublasSgemm with FP32 W (explicit FP32 storage)
 *   2) layercast: cublasGemmEx with BF16 storage of W + FP32 compute output
 *
 * Both produce Y = X @ W with X [M,K] @ W [K,N] = Y [M,N], row-major.
 * cuBLAS column-major trick: gemm(opN, opN, N, M, K, W, N, X, K, Y, N).
 * ============================================================================ */

/* Pure FP32 reference: X is FP32, W is FP32 (no BF16) */
static void reference_fp32(cublasHandle_t h, int M, int K, int N,
                           const float* dX, const float* dW_f32, float* dY) {
    const float alpha = 1.0f, beta = 0.0f;
    CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dW_f32, N, dX, K, &beta, dY, N));
}

/* LayerCast path: X is FP32, W is BF16 storage; compute FP32 accumulator;
 * output FP32. The actual cuBLAS call uses cublasGemmEx with mixed input
 * types (FP32 + BF16). If the cuBLAS version does not support this exact
 * mix, we fall back to an on-device upcast of W_bf16 → W_f32 and call
 * cublasSgemm (slightly different memory pressure but same numerical path).
 */
static int layercast_path_supports_mixed = -1;  /* -1 unknown; 0 no; 1 yes */

static cublasStatus_t try_layercast_mixed(cublasHandle_t h, int M, int K, int N,
                                          const float* dX, const __nv_bfloat16* dW_bf16,
                                          float* dY) {
    const float alpha = 1.0f, beta = 0.0f;
    return cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                        &alpha,
                        dW_bf16, CUDA_R_16BF, N,
                        dX, CUDA_R_32F, K,
                        &beta,
                        dY, CUDA_R_32F, N,
                        CUBLAS_COMPUTE_32F,
                        CUBLAS_GEMM_DEFAULT);
}

static void layercast_fallback_upcast(cublasHandle_t h, cudaStream_t st,
                                      int M, int K, int N,
                                      const float* dX,
                                      const __nv_bfloat16* dW_bf16,
                                      float* dW_f32_scratch,
                                      float* dY) {
    /* Explicit on-device upcast then Sgemm — slightly more memory traffic but
     * numerically the same (BF16 mantissa truncation applied in cast). */
    int threads = 256;
    size_t n_w = (size_t)K * N;
    int blocks = (int)((n_w + threads - 1) / threads);
    if (blocks > 65535) blocks = 65535;
    bf16_to_f32_k<<<blocks, threads, 0, st>>>(dW_bf16, dW_f32_scratch, n_w);
    const float alpha = 1.0f, beta = 0.0f;
    CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, dW_f32_scratch, N, dX, K, &beta, dY, N));
}

/* ============================================================================
 * Per-shape harness
 * ============================================================================ */
struct shape_result {
    int M, K, N;
    double t_fp32_ms;
    double t_layercast_ms;
    double t_layercast_fallback_ms;
    int mixed_supported;
    /* Numerical comparison: layercast Y vs FP32 reference Y */
    double max_abs_delta_y;
    double max_rel_delta_y;
    double mean_rel_delta_y;
    double mean_abs_y_ref;
    /* Memory anchor: BF16 weight bytes / FP32 weight bytes */
    double weight_mem_ratio_bf16_over_fp32;
    /* Falsifier */
    int falsifier_diverge_pass;     /* mean_rel ≤ 5% (LayerCast paper anchor ≤ 3.4%) */
    char status[128];
};

static shape_result run_shape(cublasHandle_t h, cudaStream_t stream,
                              int M, int K, int N, int n_warm, int n_iter) {
    shape_result r;
    memset(&r, 0, sizeof(r));
    r.M = M; r.K = K; r.N = N;
    fprintf(stderr, "[R049LC] === M=%d K=%d N=%d ===\n", M, K, N);

    size_t szX = (size_t)M * K * sizeof(float);
    size_t szW_f32 = (size_t)K * N * sizeof(float);
    size_t szW_bf16 = (size_t)K * N * sizeof(__nv_bfloat16);
    size_t szY = (size_t)M * N * sizeof(float);

    /* Host */
    float* hX = (float*)malloc(szX);
    float* hW_f32 = (float*)malloc(szW_f32);
    float* hY_fp32_ref = (float*)malloc(szY);
    float* hY_layercast = (float*)malloc(szY);

    uint64_t st = 0x1abcdcab7ULL ^ (uint64_t)(M * 1000003 + K * 1009 + N * 31);
    for (size_t i = 0; i < (size_t)M * K; i++) hX[i] = (float)((lcg_next(&st) - 0.5) * 0.1);
    for (size_t i = 0; i < (size_t)K * N; i++) hW_f32[i] = (float)((lcg_next(&st) - 0.5) * 0.05);

    /* Device buffers */
    float *dX, *dW_f32, *dY_fp32_ref, *dY_layercast, *dW_f32_scratch;
    __nv_bfloat16 *dW_bf16;
    CK(cudaMalloc(&dX, szX));
    CK(cudaMalloc(&dW_f32, szW_f32));
    CK(cudaMalloc(&dW_f32_scratch, szW_f32));
    CK(cudaMalloc(&dW_bf16, szW_bf16));
    CK(cudaMalloc(&dY_fp32_ref, szY));
    CK(cudaMalloc(&dY_layercast, szY));
    CK(cudaMemcpy(dX, hX, szX, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW_f32, hW_f32, szW_f32, cudaMemcpyHostToDevice));

    /* Cast W FP32 → BF16 once (LayerCast storage layer) */
    int threads = 256;
    size_t n_w = (size_t)K * N;
    int blocks = (int)((n_w + threads - 1) / threads);
    if (blocks > 65535) blocks = 65535;
    f32_to_bf16_k<<<blocks, threads, 0, stream>>>(dW_f32, dW_bf16, n_w);
    CK(cudaStreamSynchronize(stream));

    /* ---- FP32 reference path ---- */
    for (int w = 0; w < n_warm; w++) reference_fp32(h, M, K, N, dX, dW_f32, dY_fp32_ref);
    CK(cudaStreamSynchronize(stream));
    double* s32 = (double*)malloc((size_t)n_iter * sizeof(double));
    for (int it = 0; it < n_iter; it++) {
        double t0 = now_sec();
        reference_fp32(h, M, K, N, dX, dW_f32, dY_fp32_ref);
        CK(cudaStreamSynchronize(stream));
        s32[it] = (now_sec() - t0) * 1000.0;
    }
    r.t_fp32_ms = median(s32, n_iter);
    free(s32);
    CK(cudaMemcpy(hY_fp32_ref, dY_fp32_ref, szY, cudaMemcpyDeviceToHost));

    /* ---- LayerCast path: try mixed first ---- */
    if (layercast_path_supports_mixed == -1) {
        cublasStatus_t tst = try_layercast_mixed(h, M, K, N, dX, dW_bf16, dY_layercast);
        if (tst == CUBLAS_STATUS_SUCCESS) {
            layercast_path_supports_mixed = 1;
            fprintf(stderr, "[R049LC]   mixed-type cublasGemmEx (FP32+BF16) SUPPORTED\n");
        } else {
            layercast_path_supports_mixed = 0;
            fprintf(stderr, "[R049LC]   mixed-type cublasGemmEx UNSUPPORTED (status %d) — using fallback upcast path\n", (int)tst);
        }
    }
    r.mixed_supported = layercast_path_supports_mixed;

    if (layercast_path_supports_mixed == 1) {
        for (int w = 0; w < n_warm; w++) CB(try_layercast_mixed(h, M, K, N, dX, dW_bf16, dY_layercast));
        CK(cudaStreamSynchronize(stream));
        double* slc = (double*)malloc((size_t)n_iter * sizeof(double));
        for (int it = 0; it < n_iter; it++) {
            double t0 = now_sec();
            CB(try_layercast_mixed(h, M, K, N, dX, dW_bf16, dY_layercast));
            CK(cudaStreamSynchronize(stream));
            slc[it] = (now_sec() - t0) * 1000.0;
        }
        r.t_layercast_ms = median(slc, n_iter);
        r.t_layercast_fallback_ms = 0.0;
        free(slc);
    } else {
        for (int w = 0; w < n_warm; w++)
            layercast_fallback_upcast(h, stream, M, K, N, dX, dW_bf16, dW_f32_scratch, dY_layercast);
        CK(cudaStreamSynchronize(stream));
        double* slc = (double*)malloc((size_t)n_iter * sizeof(double));
        for (int it = 0; it < n_iter; it++) {
            double t0 = now_sec();
            layercast_fallback_upcast(h, stream, M, K, N, dX, dW_bf16, dW_f32_scratch, dY_layercast);
            CK(cudaStreamSynchronize(stream));
            slc[it] = (now_sec() - t0) * 1000.0;
        }
        r.t_layercast_fallback_ms = median(slc, n_iter);
        r.t_layercast_ms = 0.0;
        free(slc);
    }
    CK(cudaMemcpy(hY_layercast, dY_layercast, szY, cudaMemcpyDeviceToHost));

    /* Numerical comparison */
    double max_abs = 0, max_rel = 0, sum_rel = 0, sum_abs_y = 0;
    size_t n_y = (size_t)M * N;
    int count_rel = 0;
    for (size_t i = 0; i < n_y; i++) {
        double d = fabs((double)hY_fp32_ref[i] - (double)hY_layercast[i]);
        if (d > max_abs) max_abs = d;
        double ref = fabs((double)hY_fp32_ref[i]);
        sum_abs_y += ref;
        if (ref > 1e-7) {
            double rel = d / ref;
            sum_rel += rel; count_rel++;
            if (rel > max_rel) max_rel = rel;
        }
    }
    r.max_abs_delta_y = max_abs;
    r.max_rel_delta_y = max_rel;
    r.mean_rel_delta_y = (count_rel > 0) ? (sum_rel / count_rel) : 0;
    r.mean_abs_y_ref = sum_abs_y / (double)n_y;

    r.weight_mem_ratio_bf16_over_fp32 = (double)szW_bf16 / (double)szW_f32;

    /* Falsifier: mean relative divergence ≤ 5% */
    r.falsifier_diverge_pass = (r.mean_rel_delta_y <= 0.05) ? 1 : 0;

    snprintf(r.status, sizeof(r.status), "ok");
    fprintf(stderr, "[R049LC]   FP32_ref=%.4f ms · LayerCast(%s)=%.4f ms\n",
            r.t_fp32_ms,
            (layercast_path_supports_mixed == 1) ? "mixed" : "fallback",
            (layercast_path_supports_mixed == 1) ? r.t_layercast_ms : r.t_layercast_fallback_ms);
    fprintf(stderr, "[R049LC]   max|Δ|=%.3e · max_rel=%.3e · mean_rel=%.3e · weight_mem_ratio=%.4f\n",
            r.max_abs_delta_y, r.max_rel_delta_y, r.mean_rel_delta_y, r.weight_mem_ratio_bf16_over_fp32);
    fprintf(stderr, "[R049LC]   DIVERGE≤5%%=%s\n",
            r.falsifier_diverge_pass ? "PASS" : "FAIL");

    CK(cudaFree(dX)); CK(cudaFree(dW_f32)); CK(cudaFree(dW_f32_scratch));
    CK(cudaFree(dW_bf16)); CK(cudaFree(dY_fp32_ref)); CK(cudaFree(dY_layercast));
    free(hX); free(hW_f32); free(hY_fp32_ref); free(hY_layercast);
    return r;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    int n_dev = 0; cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[R049LC] FATAL: no CUDA device\n"); return 1; }
    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    cudaDeviceProp prop; cudaGetDeviceProperties(&prop, 0);
    fprintf(stderr, "[R049LC] device 0: name=%s cc=%d.%d\n", prop.name, cc_major, cc_minor);

    if (cc_major < 8) {
        fprintf(stderr, "[R049LC] FATAL: BF16 requires sm_80+, got %d.%d\n", cc_major, cc_minor);
        FILE* jf = fopen("result_layercast.json", "w");
        fprintf(jf, "{\"error\":\"non-bf16 device cc=%d.%d\"}\n", cc_major, cc_minor);
        fclose(jf);
        return 2;
    }

    cublasHandle_t h; CB(cublasCreate(&h));
    cudaStream_t stream; CK(cudaStreamCreate(&stream));
    CB(cublasSetStream(h, stream));
    int cb_maj = 0, cb_min = 0, cb_pat = 0;
    cublasGetProperty(MAJOR_VERSION, &cb_maj);
    cublasGetProperty(MINOR_VERSION, &cb_min);
    cublasGetProperty(PATCH_LEVEL, &cb_pat);

    /* Linear layer shapes spanning small to Llama-7B FFN-half scale */
    struct { int M, K, N, warm, iter; } shapes[] = {
        {  64,  768,  3072,  5, 31 },
        { 128, 4096, 11008,  3, 21 },
        { 128, 4096,  4096,  3, 21 },
        { 128, 11008, 4096,  3, 21 },
    };
    int n_shapes = (int)(sizeof(shapes) / sizeof(shapes[0]));

    shape_result results[8];
    for (int i = 0; i < n_shapes; i++)
        results[i] = run_shape(h, stream, shapes[i].M, shapes[i].K, shapes[i].N,
                                shapes[i].warm, shapes[i].iter);

    FILE* jf = fopen("result_layercast.json", "w");
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_rfc049_layercast_linear_stage1\",\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_name\": \"%s\",\n", prop.name);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cb_maj, cb_min, cb_pat);
    fprintf(jf, "  \"layercast_mixed_supported\": %d,\n",
            layercast_path_supports_mixed);
    fprintf(jf, "  \"shapes\": [\n");
    for (int i = 0; i < n_shapes; i++) {
        shape_result* r = &results[i];
        if (i > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"M\":%d, \"K\":%d, \"N\":%d, "
            "\"t_fp32_ms\":%.5f, \"t_layercast_ms\":%.5f, \"t_layercast_fallback_ms\":%.5f, "
            "\"mixed_supported\":%d, "
            "\"max_abs_delta_y\":%.3e, \"max_rel_delta_y\":%.3e, \"mean_rel_delta_y\":%.3e, "
            "\"mean_abs_y_ref\":%.3e, "
            "\"weight_mem_ratio_bf16_over_fp32\":%.5f, "
            "\"falsifier_diverge_pass\":%d, "
            "\"status\":\"%s\" }",
            r->M, r->K, r->N,
            r->t_fp32_ms, r->t_layercast_ms, r->t_layercast_fallback_ms,
            r->mixed_supported,
            r->max_abs_delta_y, r->max_rel_delta_y, r->mean_rel_delta_y, r->mean_abs_y_ref,
            r->weight_mem_ratio_bf16_over_fp32, r->falsifier_diverge_pass, r->status);
    }
    fprintf(jf, "\n  ],\n");

    int all_div = 1; double worst_rel = 0;
    for (int i = 0; i < n_shapes; i++) {
        if (!results[i].falsifier_diverge_pass) all_div = 0;
        if (results[i].mean_rel_delta_y > worst_rel) worst_rel = results[i].mean_rel_delta_y;
    }
    fprintf(jf, "  \"falsifier_verdicts\": {\n");
    fprintf(jf, "    \"F-FORGE-RFC049-LAYERCAST-DIVERGE\": { \"threshold\":\"mean_rel≤0.05\", \"worst_mean_rel\":%.4e, \"verdict\":\"%s\" }\n",
            worst_rel, all_div ? "PASS" : "FAIL");
    fprintf(jf, "  },\n");
    fprintf(jf, "  \"notes\": [\n");
    fprintf(jf, "    \"LayerCast pattern: BF16 weight storage + FP32 compute (cublasGemmEx mixed).\",\n");
    fprintf(jf, "    \"Reference: FP32 weight + FP32 compute (cublasSgemm).\",\n");
    fprintf(jf, "    \"If mixed-type path unsupported, fallback = on-device upcast + Sgemm.\",\n");
    fprintf(jf, "    \"weight_mem_ratio_bf16_over_fp32 expected 0.5 (BF16=2B vs FP32=4B).\"\n");
    fprintf(jf, "  ]\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "\n[R049LC] === SUMMARY ===\n");
    for (int i = 0; i < n_shapes; i++) {
        shape_result* r = &results[i];
        double t_lc = (r->mixed_supported == 1) ? r->t_layercast_ms : r->t_layercast_fallback_ms;
        fprintf(stderr, "  M=%d K=%d N=%d: fp32=%.4f lc=%.4f max|Δ|=%.3e mean_rel=%.3e diverge=%s\n",
                r->M, r->K, r->N, r->t_fp32_ms, t_lc,
                r->max_abs_delta_y, r->mean_rel_delta_y,
                r->falsifier_diverge_pass ? "PASS" : "FAIL");
    }

    cudaStreamDestroy(stream);
    cublasDestroy(h);
    return 0;
}
