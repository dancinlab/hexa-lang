/* RFC 067 PC -- HGEMM scale-up matrix re-fire (2026-05-21)
 *
 * Re-measures the scale-up matrix lost in the macOS crash. The original
 * stash 0 numbers (M=256 ratio 0.500 ... M=1024 ratio 0.280) must be
 * RE-MEASURED -- @D g3 honest report only what we observe today.
 *
 * Coverage:
 *   - cuBLAS GemmEx (f16 inputs / f32 compute / f32 output) at
 *     M=N=K = 256, 384, 512, 768, 1024
 *   - hexa-emit `wmma_256x256_grid.ptx` (PR #214) at 256 only
 *     (kernel hardcodes 256x256x256 -- larger shapes require new codegen).
 *
 * Measurement protocol:
 *   - 20 warmup launches per (kernel, shape) pair
 *   - 200 timed launches, each individually timed via cudaEventRecord
 *   - Reports median / std / min / max per-launch milliseconds
 *   - TFLOPS = 2*M*N*K / median_seconds / 1e12
 *
 * Output: result.json with structured array (5 entries, one per shape)
 *   each entry: M, N, K, cublas_tflops, cublas_median_ms, cublas_std_ms,
 *               cublas_min_ms, cublas_max_ms, measurement_count,
 *               hexa_tflops, hexa_median_ms, ratio,
 *               note (when hexa is null)
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 * Run:
 *   ./host /home/summer/r067_perf/wmma_256x256_grid.ptx
 */

#include <cuda.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <library_types.h>
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

static uint16_t f32_to_f16(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    uint32_t sign  = (x >> 16) & 0x8000;
    int32_t  exp   = ((x >> 23) & 0xff) - 127 + 15;
    uint32_t mant  =  x & 0x7fffff;
    if (exp <= 0)        return (uint16_t)sign;
    if (exp >= 31)       return (uint16_t)(sign | 0x7c00);
    return (uint16_t)(sign | (exp << 10) | (mant >> 13));
}

/* qsort comparator for double ascending */
static int cmp_double(const void *a, const void *b) {
    double da = *(const double *)a, dbb = *(const double *)b;
    if (da < dbb) return -1;
    if (da > dbb) return  1;
    return 0;
}

/* compute median (sorted-in-place) / std / min / max from an array of doubles */
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

/* Run cuBLAS GemmEx at given shape, return per-launch times in ms.
 * Layout: A row-major (M,K), B col-major (K,N), C row-major (M,N).
 * We use the same col/row dual identity from r067_perf_hgemm_host.c:
 *   cublasGemmEx(OP_N, OP_N, n=N, m=M, k=K, A=B_buf lda=K, B=A_buf ldb=K,
 *                C=C_buf ldc=N) -- col-major view of row-major bytes.
 */
static int run_cublas(cublasHandle_t handle,
                      int M, int N, int K,
                      CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                      int warmup, int reps,
                      double *out_times_ms /* size reps */)
{
    float alpha = 1.0f, beta = 0.0f;
    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_BLAS(cublasGemmEx(handle,
            CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha,
            (void *)(uintptr_t)db, CUDA_R_16F, K,
            (void *)(uintptr_t)da, CUDA_R_16F, K,
            &beta,
            (void *)(uintptr_t)dc, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F,
            CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_BLAS(cublasGemmEx(handle,
            CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha,
            (void *)(uintptr_t)db, CUDA_R_16F, K,
            (void *)(uintptr_t)da, CUDA_R_16F, K,
            &beta,
            (void *)(uintptr_t)dc, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F,
            CUBLAS_GEMM_DEFAULT_TENSOR_OP));
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

/* Run hexa-emit wmma_256x256_grid kernel at 256x256x256, return per-launch ms. */
static int run_hexa(CUfunction f_hexa,
                    CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                    int warmup, int reps,
                    double *out_times_ms /* size reps */)
{
    const int M = 256, N = 256;
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = 256 / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa,
            N / 64, M / 64, 1, 512, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa,
            N / 64, M / 64, 1, 512, 1, 1, 0, NULL, kargs, NULL));
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

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s wmma_256x256_grid.ptx\n", argv[0]);
        return 2;
    }
    const char *ptx_path = argv[1];

    /* ---- CUDA init ---- */
    CHECK_CU(cuInit(0));
    CUdevice  dev;     CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx;     CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    /* Report GPU + driver + toolkit so artifact is self-describing. */
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

    /* ---- Load hexa-emit PTX (single kernel, shape-locked 256). ---- */
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("ptx open"); return 1; }
    fseek(fp, 0, SEEK_END);
    long n_ptx = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) { fprintf(stderr, "ptx short read\n"); return 1; }
    ptx[n_ptx] = 0;
    fclose(fp);

    CUmodule mod;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK_CU(cuModuleLoadDataEx(&mod, ptx, 1, jit_opts, jit_vals));
    CUfunction f_hexa;
    CHECK_CU(cuModuleGetFunction(&f_hexa, mod, "wmma_256x256_grid"));

    /* ---- cuBLAS handle ---- */
    cublasHandle_t handle;
    CHECK_BLAS(cublasCreate(&handle));
    CHECK_BLAS(cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH));

    /* ---- Shape sweep ---- */
    int shapes[] = { 256, 384, 512, 768, 1024 };
    int n_shapes = sizeof(shapes) / sizeof(shapes[0]);
    const int WARMUP = 20;
    const int REPS   = 200;

    /* Per-shape stats so we can emit JSON at the end. */
    typedef struct {
        int M, N, K;
        stat_t cublas;
        double cublas_tflops;
        int    hexa_valid;          /* 1 only at M=256 */
        stat_t hexa;
        double hexa_tflops;
        double ratio;
        char   note[160];
    } shape_result_t;

    shape_result_t res[16];
    memset(res, 0, sizeof(res));

    double *times = (double *)malloc(REPS * sizeof(double));

    for (int si = 0; si < n_shapes; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        res[si].M = M; res[si].N = N; res[si].K = K;

        const size_t ASZ = (size_t)M * (size_t)K;
        const size_t BSZ = (size_t)K * (size_t)N;
        const size_t CSZ = (size_t)M * (size_t)N;

        /* Host buffers (deterministic small f16 values). */
        uint16_t *ha = (uint16_t *)malloc(ASZ * sizeof(uint16_t));
        uint16_t *hb = (uint16_t *)malloc(BSZ * sizeof(uint16_t));
        for (size_t i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
        for (size_t i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

        CUdeviceptr da, db, dc;
        CHECK_CU(cuMemAlloc(&da, ASZ * sizeof(uint16_t)));
        CHECK_CU(cuMemAlloc(&db, BSZ * sizeof(uint16_t)));
        CHECK_CU(cuMemAlloc(&dc, CSZ * sizeof(float)));
        CHECK_CU(cuMemcpyHtoD(da, ha, ASZ * sizeof(uint16_t)));
        CHECK_CU(cuMemcpyHtoD(db, hb, BSZ * sizeof(uint16_t)));
        CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));

        /* ---- cuBLAS timing (all shapes) ---- */
        if (run_cublas(handle, M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
            fprintf(stderr, "cuBLAS run failed at shape %d\n", M);
            return 1;
        }
        res[si].cublas = stats_compute(times, REPS);
        double flops = 2.0 * (double)M * (double)N * (double)K;
        res[si].cublas_tflops = flops / (res[si].cublas.median / 1000.0) / 1e12;

        printf("[shape M=N=K=%d] cuBLAS  median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%.4f\n",
               M, res[si].cublas.median, res[si].cublas.std, res[si].cublas.min, res[si].cublas.max,
               res[si].cublas_tflops);

        /* ---- hexa-emit timing (only at 256; shape-locked kernel) ---- */
        if (M == 256) {
            if (run_hexa(f_hexa, da, db, dc, WARMUP, REPS, times) != 0) {
                fprintf(stderr, "hexa-emit run failed at shape %d\n", M);
                return 1;
            }
            res[si].hexa_valid = 1;
            res[si].hexa = stats_compute(times, REPS);
            res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
            res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
            printf("[shape M=N=K=%d] hexa    median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%.4f  ratio=%.4f\n",
                   M, res[si].hexa.median, res[si].hexa.std, res[si].hexa.min, res[si].hexa.max,
                   res[si].hexa_tflops, res[si].ratio);
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note),
                "hexa-emit wmma_256x256_grid is shape-locked at 256x256x256 (PR #214); larger M requires new codegen invocation");
            printf("[shape M=N=K=%d] hexa    SKIPPED -- %s\n", M, res[si].note);
        }

        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    /* ---- Emit result.json ---- */
    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PC-hgemm-scaleup-refire\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-21\",\n");
    fprintf(rj, "  \"host\": \"ubu-2\",\n");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"hexa_kernel\": \"wmma_256x256_grid (PR #214, shape-locked 256x256x256)\",\n");
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < n_shapes; ++si) {
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"cublas_tflops\":     %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_median_ms\":  %.6f,\n", res[si].cublas.median);
        fprintf(rj, "      \"cublas_mean_ms\":    %.6f,\n", res[si].cublas.mean);
        fprintf(rj, "      \"cublas_std_ms\":     %.6f,\n", res[si].cublas.std);
        fprintf(rj, "      \"cublas_min_ms\":     %.6f,\n", res[si].cublas.min);
        fprintf(rj, "      \"cublas_max_ms\":     %.6f,\n", res[si].cublas.max);
        if (res[si].hexa_valid) {
            fprintf(rj, "      \"hexa_tflops\":       %.6f,\n", res[si].hexa_tflops);
            fprintf(rj, "      \"hexa_median_ms\":    %.6f,\n", res[si].hexa.median);
            fprintf(rj, "      \"hexa_mean_ms\":      %.6f,\n", res[si].hexa.mean);
            fprintf(rj, "      \"hexa_std_ms\":       %.6f,\n", res[si].hexa.std);
            fprintf(rj, "      \"hexa_min_ms\":       %.6f,\n", res[si].hexa.min);
            fprintf(rj, "      \"hexa_max_ms\":       %.6f,\n", res[si].hexa.max);
            fprintf(rj, "      \"ratio\":             %.6f,\n", res[si].ratio);
            fprintf(rj, "      \"note\":              null\n");
        } else {
            fprintf(rj, "      \"hexa_tflops\":       null,\n");
            fprintf(rj, "      \"hexa_median_ms\":    null,\n");
            fprintf(rj, "      \"hexa_mean_ms\":      null,\n");
            fprintf(rj, "      \"hexa_std_ms\":       null,\n");
            fprintf(rj, "      \"hexa_min_ms\":       null,\n");
            fprintf(rj, "      \"hexa_max_ms\":       null,\n");
            fprintf(rj, "      \"ratio\":             null,\n");
            fprintf(rj, "      \"note\":              \"%s\"\n", res[si].note);
        }
        fprintf(rj, "    }%s\n", (si == n_shapes - 1) ? "" : ",");
    }
    fprintf(rj, "  ]\n");
    fprintf(rj, "}\n");
    fclose(rj);

    cublasDestroy(handle);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return 0;
}
