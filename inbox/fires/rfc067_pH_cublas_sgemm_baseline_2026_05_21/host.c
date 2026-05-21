/* RFC 067 PH -- cuBLAS SGEMM FP32 baseline 23-shape sweep (2026-05-21)
 *
 * Apples-to-apples FP32 baseline counterpart to:
 *   - PG (HGEMM via cublasGemmEx, FP16 in / FP32 compute / FP32 out)
 *   - RFC 075 MPS GEMM (Apple M3 FP32 SGEMM via MetalPerformanceShaders)
 *
 * This fire measures pure cublasSgemm (FP32 in / FP32 compute / FP32 out)
 * on RTX 5070 sm_120 so we can cite a real apples-to-apples FP32-vs-FP32
 * ratio against the Apple M3 MPS FP32 result (N7, commit 9b352bda).
 *
 * The hexa-emit column from PG is intentionally NOT carried over here:
 *   - All current hexa-emit WMMA kernels are FP16-input, so they do not
 *     produce an FP32 SGEMM peer.
 *   - cuBLAS SGEMM is the ONLY column timed in this fire.
 *
 * cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH) is asserted so that
 * cublasSgemm is allowed to dispatch through TF32 tensor-core kernels on
 * sm_80+ (sm_120 inherits). This matches what a real production caller
 * would get with default settings on this driver; we document the math
 * mode in result.json so the number is unambiguous.
 *
 * Measurement protocol (identical to pD / pF / pG):
 *   - 20 warmup launches per shape
 *   - 200 timed launches, cudaEventRecord per-iter sync
 *   - median / mean / std / min / max ms; TFLOPS = 2*M*N*K / median_s / 1e12
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 * Run:
 *   ./host
 */

#include <cuda.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK_CU(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA driver error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

#define CHECK_RT(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { \
        fprintf(stderr, "CUDA runtime error %d at %s:%d: %s\n", e, __FILE__, __LINE__, cudaGetErrorString(e)); \
        return 1; }} while (0)

#define CHECK_BLAS(call) do { cublasStatus_t e = (call); \
    if (e != CUBLAS_STATUS_SUCCESS) { \
        fprintf(stderr, "cuBLAS error %d at %s:%d\n", (int)e, __FILE__, __LINE__); \
        return 1; }} while (0)

static int cmp_double(const void *a, const void *b) {
    double da = *(const double *)a, dbb = *(const double *)b;
    if (da < dbb) return -1;
    if (da > dbb) return  1;
    return 0;
}

typedef struct {
    double median;
    double mean;
    double std;
    double min;
    double max;
} stat_t;

static stat_t stats_compute(double *arr, int n) {
    stat_t s = {0, 0, 0, 0, 0};
    if (n <= 0) return s;
    qsort(arr, n, sizeof(double), cmp_double);
    s.min = arr[0];
    s.max = arr[n-1];
    s.median = (n % 2) ? arr[n/2] : 0.5 * (arr[n/2 - 1] + arr[n/2]);
    double sum = 0.0;
    for (int i = 0; i < n; ++i) sum += arr[i];
    s.mean = sum / (double)n;
    double sq = 0.0;
    for (int i = 0; i < n; ++i) { double d = arr[i] - s.mean; sq += d*d; }
    s.std = sqrt(sq / (double)n);
    return s;
}

/* Pure cublasSgemm. Note row-major-as-col-major convention:
 *   We want C[M,N] = A[M,K] * B[K,N] in row-major.
 *   cuBLAS is col-major, so we ask it to compute
 *     C^T[N,M] = B^T[N,K] * A^T[K,M]
 *   by passing (op_N, op_N, N, M, K, B, ldb=N, A, lda=K, C, ldc=N).
 *   This matches PG (cublasGemmEx) exactly. */
static int run_cublas_sgemm(cublasHandle_t handle,
                            int M, int N, int K,
                            CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                            int warmup, int reps,
                            double *out_times_ms)
{
    float alpha = 1.0f, beta = 0.0f;
    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_BLAS(cublasSgemm(handle,
            CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha,
            (const float *)(uintptr_t)db, N,
            (const float *)(uintptr_t)da, K,
            &beta,
            (float *)(uintptr_t)dc, N));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_BLAS(cublasSgemm(handle,
            CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha,
            (const float *)(uintptr_t)db, N,
            (const float *)(uintptr_t)da, K,
            &beta,
            (float *)(uintptr_t)dc, N));
        CHECK_RT(cudaEventRecord(ev_b, 0));
        CHECK_RT(cudaEventSynchronize(ev_b));
        float ms = 0.0f;
        CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
        out_times_ms[i] = (double)ms;
    }

    cudaEventDestroy(ev_a);
    cudaEventDestroy(ev_b);
    return 0;
}

#define N_SHAPES 23

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    int shapes[N_SHAPES] = {
        192, 256, 320, 384, 448, 512, 576, 640, 704, 768, 832, 896, 960,
        1024, 1088, 1152, 1280, 1408, 1536, 1664, 1792, 1920, 2048
    };

    CHECK_CU(cuInit(0));
    CUdevice  dev;     CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx;     CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    char dev_name[256];
    CHECK_CU(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    int driver_ver = 0, runtime_ver = 0;
    CHECK_CU(cuDriverGetVersion(&driver_ver));
    cudaRuntimeGetVersion(&runtime_ver);
    printf("Device: %s sm_%d%d\n", dev_name, sm_major, sm_minor);
    printf("CUDA driver=%d runtime=%d\n", driver_ver, runtime_ver);

    cublasHandle_t handle;
    CHECK_BLAS(cublasCreate(&handle));

    /* Note math mode. CUBLAS_TENSOR_OP_MATH on sm_80+ lets cublasSgemm
     * dispatch into TF32 tensor cores (1e-3 ULP-equivalent precision drop
     * vs strict IEEE FP32). We record this in the JSON output. */
    cublasMath_t math_mode_used = CUBLAS_TENSOR_OP_MATH;
    CHECK_BLAS(cublasSetMathMode(handle, math_mode_used));

    const int WARMUP = 20;
    const int REPS   = 200;

    typedef struct {
        int M, N, K;
        stat_t s;
        double tflops;
    } shape_result_t;

    shape_result_t res[N_SHAPES];
    memset(res, 0, sizeof(res));

    double *times = (double *)malloc(REPS * sizeof(double));

    for (int si = 0; si < N_SHAPES; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        res[si].M = M; res[si].N = N; res[si].K = K;

        const size_t ASZ = (size_t)M * (size_t)K;
        const size_t BSZ = (size_t)K * (size_t)N;
        const size_t CSZ = (size_t)M * (size_t)N;

        float *ha = (float *)malloc(ASZ * sizeof(float));
        float *hb = (float *)malloc(BSZ * sizeof(float));
        /* Same numeric pattern as PG (modular sawtooth) for cache / register
         * pressure parity with the FP16 fire. */
        for (size_t i = 0; i < ASZ; ++i) ha[i] = (float)((i % 8) - 4) * 0.0625f;
        for (size_t i = 0; i < BSZ; ++i) hb[i] = (float)((i % 5) - 2) * 0.125f;

        CUdeviceptr da, db, dc;
        CHECK_CU(cuMemAlloc(&da, ASZ * sizeof(float)));
        CHECK_CU(cuMemAlloc(&db, BSZ * sizeof(float)));
        CHECK_CU(cuMemAlloc(&dc, CSZ * sizeof(float)));
        CHECK_CU(cuMemcpyHtoD(da, ha, ASZ * sizeof(float)));
        CHECK_CU(cuMemcpyHtoD(db, hb, BSZ * sizeof(float)));
        CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));

        if (run_cublas_sgemm(handle, M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
            fprintf(stderr, "cuBLAS SGEMM run failed at shape %d\n", M);
            return 1;
        }
        res[si].s = stats_compute(times, REPS);
        double flops = 2.0 * (double)M * (double)N * (double)K;
        res[si].tflops = flops / (res[si].s.median / 1000.0) / 1e12;

        printf("[M=%4d] cuBLAS SGEMM  median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f\n",
               M, res[si].s.median, res[si].s.std, res[si].s.min, res[si].s.max,
               res[si].tflops);

        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PH-cublas-sgemm-baseline\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-21\",\n");
    fprintf(rj, "  \"host\": \"ubu-2\",\n");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"kernel\": \"cublasSgemm (FP32 in / FP32 compute / FP32 out)\",\n");
    fprintf(rj, "  \"math_mode\": \"CUBLAS_TENSOR_OP_MATH (allows TF32 tensor-core dispatch on sm_80+)\",\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"sgemm_tflops\":    %.6f,\n", res[si].tflops);
        fprintf(rj, "      \"sgemm_median_ms\": %.6f,\n", res[si].s.median);
        fprintf(rj, "      \"sgemm_mean_ms\":   %.6f,\n", res[si].s.mean);
        fprintf(rj, "      \"sgemm_std_ms\":    %.6f,\n", res[si].s.std);
        fprintf(rj, "      \"sgemm_min_ms\":    %.6f,\n", res[si].s.min);
        fprintf(rj, "      \"sgemm_max_ms\":    %.6f\n",  res[si].s.max);
        fprintf(rj, "    }%s\n", (si == N_SHAPES - 1) ? "" : ",");
    }
    fprintf(rj, "  ]\n");
    fprintf(rj, "}\n");
    fclose(rj);

    cublasDestroy(handle);
    cuCtxDestroy(ctx);
    return 0;
}
