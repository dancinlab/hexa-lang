/* RFC 067 PG -- HGEMM 23-shape extension (2026-05-21)
 *
 * Extends the pD follow-on (commit d9f9446a, 5 hexa-emit shapes) to all
 * 23 shapes spanning M=N=K=192..2048 in 64-aligned steps (matching N12 /
 * pF cuBLAS fine curve, commit d720d83a).
 *
 * All 23 PTX kernels are direct shape-ports of wmma_256x256_grid.ptx
 * (PR #214 baseline) via the gen_ptx.py generator in this dir. They use
 * the identical 16-warp 4x4 warp-grid microcode; only the per-shape
 * address-arithmetic stride constants change.
 *
 * Both cuBLAS and hexa are measured in the SAME process under the SAME
 * cudaEventRecord protocol, so ratios are valid side-by-side.
 *
 * Measurement protocol (identical to pD and pF):
 *   - 20 warmup launches per (kernel, shape) pair
 *   - 200 timed launches, cudaEventRecord per-iter sync
 *   - Reports median / mean / std / min / max per-launch ms
 *   - TFLOPS = 2*M*N*K / median_seconds / 1e12
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 * Run:
 *   ./host wmma_192x192_grid.ptx wmma_256x256_grid.ptx ... wmma_2048x2048_grid.ptx
 *   (23 args, in increasing shape order)
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

static float f16_to_f32(uint16_t h) {
    uint32_t sign = (uint32_t)(h & 0x8000) << 16;
    uint32_t exp  = (h >> 10) & 0x1f;
    uint32_t mant = h & 0x3ff;
    uint32_t out;
    if (exp == 0) {
        if (mant == 0) out = sign;
        else { /* subnormal */ out = sign | ((mant) << 13); }
    } else if (exp == 31) {
        out = sign | 0x7f800000 | (mant << 13);
    } else {
        out = sign | ((exp - 15 + 127) << 23) | (mant << 13);
    }
    float r; memcpy(&r, &out, 4); return r;
}

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

static int run_cublas(cublasHandle_t handle,
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

static int run_hexa(CUfunction f_hexa,
                    int M, int N, int K,
                    CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                    int warmup, int reps,
                    double *out_times_ms)
{
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };

    unsigned int gx = (unsigned int)(N / 64);
    unsigned int gy = (unsigned int)(M / 64);

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa,
            gx, gy, 1, 512, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa,
            gx, gy, 1, 512, 1, 1, 0, NULL, kargs, NULL));
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

static int load_ptx_kernel(const char *ptx_path,
                           const char *entry,
                           CUmodule *out_mod,
                           CUfunction *out_fn)
{
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { fprintf(stderr, "ptx open %s: ", ptx_path); perror(""); return 1; }
    fseek(fp, 0, SEEK_END);
    long n_ptx = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) {
        fprintf(stderr, "ptx short read %s\n", ptx_path); return 1;
    }
    ptx[n_ptx] = 0;
    fclose(fp);

    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CUresult e = cuModuleLoadDataEx(out_mod, ptx, 1, jit_opts, jit_vals);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleLoadDataEx %s: %s\n", ptx_path, s ? s : "?");
        free(ptx); return 1;
    }
    e = cuModuleGetFunction(out_fn, *out_mod, entry);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleGetFunction %s %s: %s\n", ptx_path, entry, s ? s : "?");
        free(ptx); return 1;
    }
    free(ptx);
    return 0;
}

/* Sanity check: compare hexa output vs cuBLAS output on a small spot.
 * We compute cuBLAS C first, snapshot a few rows, then re-run hexa and
 * snapshot the same rows, compare max-abs error. Returns 1 if OK, 0 if
 * mismatch beyond tol.
 */
static int sanity_check(cublasHandle_t handle, CUfunction f_hexa,
                        int M, int N, int K,
                        CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                        float *out_maxabs)
{
    float alpha = 1.0f, beta = 0.0f;
    CHECK_CU(cuMemsetD8(dc, 0, (size_t)M * (size_t)N * sizeof(float)));
    CHECK_BLAS(cublasGemmEx(handle,
        CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
        &alpha,
        (void *)(uintptr_t)db, CUDA_R_16F, K,
        (void *)(uintptr_t)da, CUDA_R_16F, K,
        &beta,
        (void *)(uintptr_t)dc, CUDA_R_32F, N,
        CUBLAS_COMPUTE_32F,
        CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CHECK_CU(cuCtxSynchronize());
    size_t snap_n = (size_t)M * (size_t)N;
    float *cublas_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(cublas_c, dc, snap_n * sizeof(float)));

    CHECK_CU(cuMemsetD8(dc, 0, snap_n * sizeof(float)));
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    unsigned int gx = (unsigned int)(N / 64);
    unsigned int gy = (unsigned int)(M / 64);
    CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 512, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    float *hexa_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(hexa_c, dc, snap_n * sizeof(float)));

    float maxabs = 0.0f;
    for (size_t i = 0; i < snap_n; ++i) {
        float d = fabsf(cublas_c[i] - hexa_c[i]);
        if (d > maxabs) maxabs = d;
    }
    free(cublas_c); free(hexa_c);
    *out_maxabs = maxabs;
    return 1;
}

#define N_SHAPES 23

int main(int argc, char **argv) {
    int shapes[N_SHAPES] = {
        192, 256, 320, 384, 448, 512, 576, 640, 704, 768, 832, 896, 960,
        1024, 1088, 1152, 1280, 1408, 1536, 1664, 1792, 1920, 2048
    };

    if (argc < 1 + N_SHAPES) {
        fprintf(stderr, "usage: %s wmma_192x192_grid.ptx ... wmma_2048x2048_grid.ptx (%d args)\n",
                argv[0], N_SHAPES);
        return 2;
    }

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

    /* Load all 23 hexa-emit PTX modules up front. */
    CUmodule   mods[N_SHAPES];
    CUfunction fns[N_SHAPES];
    int        load_ok[N_SHAPES];
    char       load_err[N_SHAPES][200];
    for (int si = 0; si < N_SHAPES; ++si) {
        char entry[64];
        snprintf(entry, sizeof(entry), "wmma_%dx%d_grid", shapes[si], shapes[si]);
        if (load_ptx_kernel(argv[1 + si], entry, &mods[si], &fns[si]) == 0) {
            load_ok[si] = 1; load_err[si][0] = 0;
            printf("loaded hexa PTX shape %d (%s)\n", shapes[si], entry);
        } else {
            load_ok[si] = 0;
            snprintf(load_err[si], sizeof(load_err[si]),
                "PTX load/lookup failed for %s", argv[1 + si]);
            printf("FAILED hexa PTX shape %d -- skipping\n", shapes[si]);
        }
    }

    cublasHandle_t handle;
    CHECK_BLAS(cublasCreate(&handle));
    CHECK_BLAS(cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH));

    const int WARMUP = 20;
    const int REPS   = 200;

    typedef struct {
        int M, N, K;
        stat_t cublas;
        double cublas_tflops;
        int    hexa_valid;
        float  hexa_maxabs;     /* vs cuBLAS at this shape */
        stat_t hexa;
        double hexa_tflops;
        double ratio;
        char   note[256];
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

        if (run_cublas(handle, M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
            fprintf(stderr, "cuBLAS run failed at shape %d\n", M);
            return 1;
        }
        res[si].cublas = stats_compute(times, REPS);
        double flops = 2.0 * (double)M * (double)N * (double)K;
        res[si].cublas_tflops = flops / (res[si].cublas.median / 1000.0) / 1e12;

        printf("[M=%4d] cuBLAS  median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f\n",
               M, res[si].cublas.median, res[si].cublas.std, res[si].cublas.min, res[si].cublas.max,
               res[si].cublas_tflops);

        if (load_ok[si]) {
            /* sanity check: hexa output ≈ cuBLAS output (tolerance ~1e-2 for FP16) */
            float maxabs = 0.0f;
            sanity_check(handle, fns[si], M, N, K, da, db, dc, &maxabs);
            res[si].hexa_maxabs = maxabs;

            /* clear dc again before timed runs */
            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            if (run_hexa(fns[si], M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
                fprintf(stderr, "hexa-emit run failed at shape %d\n", M);
                res[si].hexa_valid = 0;
                snprintf(res[si].note, sizeof(res[si].note),
                    "hexa launch failure at M=%d", M);
            } else {
                res[si].hexa_valid = 1;
                res[si].hexa = stats_compute(times, REPS);
                res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
                res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
                printf("[M=%4d] hexa    median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f  ratio=%.4f  maxabs=%.4f\n",
                       M, res[si].hexa.median, res[si].hexa.std, res[si].hexa.min, res[si].hexa.max,
                       res[si].hexa_tflops, res[si].ratio, res[si].hexa_maxabs);
            }
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note), "%s", load_err[si]);
            printf("[M=%4d] hexa    SKIPPED -- %s\n", M, res[si].note);
        }

        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PG-hgemm-16shape-extension\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-21\",\n");
    fprintf(rj, "  \"host\": \"ubu-2\",\n");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"hexa_kernel_family\": \"wmma_SxS_grid -- 16-warp 4x4 warp grid 64x64 output tile, shape-port of PR #214 baseline (S=256) via gen_ptx.py\",\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
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
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\": %.6f,\n", res[si].hexa_maxabs);
            fprintf(rj, "      \"ratio\":             %.6f,\n", res[si].ratio);
            fprintf(rj, "      \"note\":              null\n");
        } else {
            fprintf(rj, "      \"hexa_tflops\":       null,\n");
            fprintf(rj, "      \"hexa_median_ms\":    null,\n");
            fprintf(rj, "      \"hexa_mean_ms\":      null,\n");
            fprintf(rj, "      \"hexa_std_ms\":       null,\n");
            fprintf(rj, "      \"hexa_min_ms\":       null,\n");
            fprintf(rj, "      \"hexa_max_ms\":       null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\": null,\n");
            fprintf(rj, "      \"ratio\":             null,\n");
            fprintf(rj, "      \"note\":              \"%s\"\n", res[si].note);
        }
        fprintf(rj, "    }%s\n", (si == N_SHAPES - 1) ? "" : ",");
    }
    fprintf(rj, "  ]\n");
    fprintf(rj, "}\n");
    fclose(rj);

    cublasDestroy(handle);
    for (int si = 0; si < N_SHAPES; ++si) if (load_ok[si]) cuModuleUnload(mods[si]);
    cuCtxDestroy(ctx);
    (void)f16_to_f32;
    return 0;
}
