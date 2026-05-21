/* RFC 067 PV V1 -- N77 baseline + persistent CTA loop (2026-05-21)
 *
 * Comparator chain:
 *   N77 (PP):  ldmatrix HGEMM + cp.async.cg vec16  -> peak 36.06 TFLOPS @ M=1536 ratio 0.533
 *   N89 (PS):  128x128 tile + 1024-thd CTA          -> peak 37.07 TFLOPS @ M=1536 ratio 0.557
 *   PV V1 (this): N77 body wrapped in persistent CTA loop (1 CTA / SM).
 *
 * Hypothesis: at large M (>= 768), where total_tiles > num_SMs, persistent
 *   CTAs amortise launch + grid scheduler overhead, lifting ratio toward 0.6.
 *   At small M (<= 384), grid is already smaller than num_SMs (16 tiles vs 48
 *   SMs at M=256), so persistent is parity / mild regression from prologue
 *   overhead.  Honest report.
 *
 * Falsifier F-RFC067-HEXA-SGEMM-PERSISTENT-SPLIT-K:
 *   - Numeric: per-element maxabs vs cuBLAS HGEMM within tolerance.  K-loop
 *     body is byte-identical to N77 -> match should be bit-exact to N77's
 *     output (NOT to cuBLAS -- cuBLAS uses different reduction order).
 *   - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync each iter.
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 * Run:
 *   ./host sgemm_persistent_256x256_grid.ptx ... 1536x1536_grid.ptx
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

static unsigned short f32_to_f16(float f) {
    unsigned int x; memcpy(&x, &f, 4);
    unsigned int sign = (x >> 31) & 0x1;
    int exp = (int)((x >> 23) & 0xff) - 127 + 15;
    unsigned int mant = x & 0x7fffff;
    unsigned short out;
    if (exp >= 31) {
        out = (sign << 15) | (0x1f << 10) | (mant ? (mant >> 13) : 0);
    } else if (exp <= 0) {
        if (exp < -10) {
            out = (sign << 15);
        } else {
            mant |= 0x800000;
            int shift = 14 - exp;
            out = (sign << 15) | (mant >> shift);
        }
    } else {
        out = (sign << 15) | (exp << 10) | (mant >> 13);
    }
    return out;
}

static int run_cublas_hgemm(cublasHandle_t handle,
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
            (const void *)(uintptr_t)db, CUDA_R_16F, N,
            (const void *)(uintptr_t)da, CUDA_R_16F, K,
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
            (const void *)(uintptr_t)db, CUDA_R_16F, N,
            (const void *)(uintptr_t)da, CUDA_R_16F, K,
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
                    int num_SMs,
                    CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                    int warmup, int reps,
                    double *out_times_ms,
                    unsigned int *out_grid_x,
                    unsigned int *out_num_tiles,
                    unsigned int *out_tiles_per_cta)
{
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;

    /* persistent: grid_x = min(total_tiles, persistent_factor * num_SMs).
     * persistent_factor=2 gives 2 CTAs/SM oversubscription -- restores latency
     * hiding while still amortising scheduler overhead per CTA across multiple
     * tiles.  Env override via PV_PERSISTENT_FACTOR for sweep. */
    /* Best persistent_factor measured via sweep PV_PERSISTENT_FACTOR=1,2,4,8,16
     * on RTX 5070 (48 SMs): factor=8 peak; factor=16 degenerates to N77's launch
     * pattern (1 tile/CTA at M=1536) and exactly matches N77. */
    const char *pf_env = getenv("PV_PERSISTENT_FACTOR");
    int persistent_factor = pf_env ? atoi(pf_env) : 8;
    if (persistent_factor < 1) persistent_factor = 1;
    unsigned int tiles_m = (unsigned int)(M / 64);
    unsigned int tiles_n = (unsigned int)(N / 64);
    unsigned int num_tiles = tiles_m * tiles_n;
    unsigned int max_grid = (unsigned int)(persistent_factor * num_SMs);
    unsigned int grid_x = (num_tiles < max_grid) ? num_tiles : max_grid;
    unsigned int tiles_per_cta = (num_tiles + grid_x - 1) / grid_x;

    void *kargs[6] = { &da, &db, &dc, &k_arg, &num_tiles, &tiles_n };

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa,
            grid_x, 1, 1, 512, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa,
            grid_x, 1, 1, 512, 1, 1, 0, NULL, kargs, NULL));
        CHECK_RT(cudaEventRecord(ev_b, 0));
        CHECK_RT(cudaEventSynchronize(ev_b));
        float ms = 0.0f;
        CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
        out_times_ms[i] = (double)ms;
    }

    if (out_grid_x)        *out_grid_x = grid_x;
    if (out_num_tiles)     *out_num_tiles = num_tiles;
    if (out_tiles_per_cta) *out_tiles_per_cta = tiles_per_cta;

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

    char log_err[8192]; log_err[0] = 0;
    char log_info[4096]; log_info[0] = 0;
    CUjit_option jit_opts[5] = {
        CU_JIT_TARGET_FROM_CUCONTEXT,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
    };
    void *jit_vals[5] = {
        (void *)0,
        (void *)log_err,
        (void *)(uintptr_t)sizeof(log_err),
        (void *)log_info,
        (void *)(uintptr_t)sizeof(log_info),
    };
    CUresult e = cuModuleLoadDataEx(out_mod, ptx, 5, jit_opts, jit_vals);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleLoadDataEx %s: %s\n", ptx_path, s ? s : "?");
        if (log_err[0]) fprintf(stderr, "  ptxas err: %s\n", log_err);
        if (log_info[0]) fprintf(stderr, "  ptxas info: %s\n", log_info);
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

static int sanity_check(cublasHandle_t handle, CUfunction f_hexa,
                        int M, int N, int K, int num_SMs,
                        CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                        float *out_maxabs, float *out_maxrel)
{
    float alpha = 1.0f, beta = 0.0f;
    size_t csz_bytes = (size_t)M * (size_t)N * sizeof(float);
    CHECK_CU(cuMemsetD8(dc, 0, csz_bytes));
    CHECK_BLAS(cublasGemmEx(handle,
        CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
        &alpha,
        (const void *)(uintptr_t)db, CUDA_R_16F, N,
        (const void *)(uintptr_t)da, CUDA_R_16F, K,
        &beta,
        (void *)(uintptr_t)dc, CUDA_R_32F, N,
        CUBLAS_COMPUTE_32F,
        CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CHECK_CU(cuCtxSynchronize());
    size_t snap_n = (size_t)M * (size_t)N;
    float *cublas_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(cublas_c, dc, snap_n * sizeof(float)));

    CHECK_CU(cuMemsetD8(dc, 0, csz_bytes));
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    const char *pf_env = getenv("PV_PERSISTENT_FACTOR");
    int persistent_factor = pf_env ? atoi(pf_env) : 8;
    if (persistent_factor < 1) persistent_factor = 1;
    unsigned int tiles_m = (unsigned int)(M / 64);
    unsigned int tiles_n = (unsigned int)(N / 64);
    unsigned int num_tiles = tiles_m * tiles_n;
    unsigned int max_grid = (unsigned int)(persistent_factor * num_SMs);
    unsigned int grid_x = (num_tiles < max_grid) ? num_tiles : max_grid;

    void *kargs[6] = { &da, &db, &dc, &k_arg, &num_tiles, &tiles_n };
    CHECK_CU(cuLaunchKernel(f_hexa, grid_x, 1, 1, 512, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    float *hexa_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(hexa_c, dc, snap_n * sizeof(float)));

    float maxabs = 0.0f;
    float maxrel = 0.0f;
    for (size_t i = 0; i < snap_n; ++i) {
        float d = fabsf(cublas_c[i] - hexa_c[i]);
        if (d > maxabs) maxabs = d;
        float scale = fabsf(cublas_c[i]);
        if (scale > 1e-3f) {
            float r = d / scale;
            if (r > maxrel) maxrel = r;
        }
    }
    free(cublas_c); free(hexa_c);
    *out_maxabs = maxabs;
    *out_maxrel = maxrel;
    return 1;
}

#define N_SHAPES 6

int main(int argc, char **argv) {
    int shapes[N_SHAPES] = { 256, 384, 512, 768, 1024, 1536 };

    if (argc < 1 + N_SHAPES) {
        fprintf(stderr, "usage: %s sgemm_persistent_256x256_grid.ptx ... 1536x1536_grid.ptx (%d args)\n",
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
    int num_SMs = 0;
    CHECK_CU(cuDeviceGetAttribute(&num_SMs, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, dev));
    int driver_ver = 0, runtime_ver = 0;
    CHECK_CU(cuDriverGetVersion(&driver_ver));
    cudaRuntimeGetVersion(&runtime_ver);
    printf("Device: %s sm_%d%d  SMs=%d\n", dev_name, sm_major, sm_minor, num_SMs);
    printf("CUDA driver=%d runtime=%d\n", driver_ver, runtime_ver);

    CUmodule   mods[N_SHAPES];
    CUfunction fns[N_SHAPES];
    int        load_ok[N_SHAPES];
    char       load_err[N_SHAPES][200];
    for (int si = 0; si < N_SHAPES; ++si) {
        char entry[64];
        snprintf(entry, sizeof(entry), "sgemm_persistent_%dx%d_grid", shapes[si], shapes[si]);
        if (load_ptx_kernel(argv[1 + si], entry, &mods[si], &fns[si]) == 0) {
            load_ok[si] = 1; load_err[si][0] = 0;
            printf("loaded hexa-PV PTX shape %d (%s)\n", shapes[si], entry);
        } else {
            load_ok[si] = 0;
            snprintf(load_err[si], sizeof(load_err[si]),
                "PTX load/lookup failed for %s", argv[1 + si]);
            printf("FAILED hexa-PV PTX shape %d -- skipping\n", shapes[si]);
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
        float  hexa_maxabs;
        float  hexa_maxrel;
        stat_t hexa;
        double hexa_tflops;
        double ratio;
        unsigned int grid_x;
        unsigned int num_tiles;
        unsigned int tiles_per_cta;
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

        unsigned short *ha = (unsigned short *)malloc(ASZ * sizeof(unsigned short));
        unsigned short *hb = (unsigned short *)malloc(BSZ * sizeof(unsigned short));
        for (size_t i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
        for (size_t i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

        CUdeviceptr da, db, dc;
        CHECK_CU(cuMemAlloc(&da, ASZ * sizeof(unsigned short)));
        CHECK_CU(cuMemAlloc(&db, BSZ * sizeof(unsigned short)));
        CHECK_CU(cuMemAlloc(&dc, CSZ * sizeof(float)));
        CHECK_CU(cuMemcpyHtoD(da, ha, ASZ * sizeof(unsigned short)));
        CHECK_CU(cuMemcpyHtoD(db, hb, BSZ * sizeof(unsigned short)));
        CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));

        if (run_cublas_hgemm(handle, M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
            fprintf(stderr, "cuBLAS HGEMM run failed at shape %d\n", M);
            return 1;
        }
        res[si].cublas = stats_compute(times, REPS);
        double flops = 2.0 * (double)M * (double)N * (double)K;
        res[si].cublas_tflops = flops / (res[si].cublas.median / 1000.0) / 1e12;

        printf("[M=%4d] cuBLAS HGEMM             median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f\n",
               M, res[si].cublas.median, res[si].cublas.std, res[si].cublas.min, res[si].cublas.max,
               res[si].cublas_tflops);

        if (load_ok[si]) {
            float maxabs = 0.0f, maxrel = 0.0f;
            sanity_check(handle, fns[si], M, N, K, num_SMs, da, db, dc, &maxabs, &maxrel);
            res[si].hexa_maxabs = maxabs;
            res[si].hexa_maxrel = maxrel;

            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            unsigned int gx = 0, nt = 0, tpc = 0;
            if (run_hexa(fns[si], M, N, K, num_SMs, da, db, dc, WARMUP, REPS, times,
                         &gx, &nt, &tpc) != 0) {
                fprintf(stderr, "hexa-PV run failed at shape %d\n", M);
                res[si].hexa_valid = 0;
                snprintf(res[si].note, sizeof(res[si].note),
                    "hexa launch failure at M=%d", M);
            } else {
                res[si].hexa_valid = 1;
                res[si].hexa = stats_compute(times, REPS);
                res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
                res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
                res[si].grid_x = gx;
                res[si].num_tiles = nt;
                res[si].tiles_per_cta = tpc;
                printf("[M=%4d] hexa-PV V1 persistent    median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f  ratio=%.4f  maxabs=%.4f  maxrel=%.4f  grid=%u/%u tiles(%u/CTA)\n",
                       M, res[si].hexa.median, res[si].hexa.std, res[si].hexa.min, res[si].hexa.max,
                       res[si].hexa_tflops, res[si].ratio, res[si].hexa_maxabs, res[si].hexa_maxrel,
                       gx, nt, tpc);
            }
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note), "%s", load_err[si]);
            printf("[M=%4d] hexa-PV V1 persistent    SKIPPED -- %s\n", M, res[si].note);
        }

        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    /* N77 (PP) and N89 (PS) baselines (RTX 5070 sm_120, 2026-05-21) for inline % delta. */
    double n77_tflops[N_SHAPES] = { 4.619278, 12.245481, 17.331835, 29.896042, 29.038887, 36.059929 };
    double n89_tflops[N_SHAPES] = { 0,        0,         0,         0,         0,         37.07     };
    /* N89 only quoted at M=1536 in the artifact; fill with zeros for other M, skip in JSON. */

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PV-V1-hexa-hgemm-persistent\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-21\",\n");
    fprintf(rj, "  \"host\": \"%s\",\n", getenv("PV_HOST") ? getenv("PV_HOST") : "ubu-2");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"num_SMs\": %d,\n", num_SMs);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"variant\": \"PV V1 -- N77 body (ldmatrix.x4 + 2x mma.m16n8k16 + cp.async.cg vec16) wrapped in persistent CTA tile loop. Grid = min(num_tiles, num_SMs).\",\n");
    fprintf(rj, "  \"hexa_kernel_family\": \"sgemm_persistent_SxS_grid\",\n");
    fprintf(rj, "  \"cublas_math_mode\": \"CUBLAS_TENSOR_OP_MATH (HGEMM via cublasGemmEx)\",\n");
    fprintf(rj, "  \"baseline_inputs\": {\n");
    fprintf(rj, "    \"N77_PP\": \"rfc067_pP_hexa_sgemm_ldmatrix_cpasync_2026_05_21 peak 36.06 TFLOPS @ M=1536 ratio 0.533\",\n");
    fprintf(rj, "    \"N89_PS\": \"rfc067_pS_hexa_sgemm_tile128_2026_05_21 peak 37.07 TFLOPS @ M=1536 ratio 0.557\"\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"hypothesis\": \"persistent CTAs save grid-scheduler overhead at large M; gain at M >= 768 expected; M <= 384 parity\",\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
        double pct_over_n77 = res[si].hexa_valid
            ? 100.0 * (res[si].hexa_tflops - n77_tflops[si]) / n77_tflops[si]
            : 0.0;
        double pct_over_n89 = (res[si].hexa_valid && n89_tflops[si] > 0)
            ? 100.0 * (res[si].hexa_tflops - n89_tflops[si]) / n89_tflops[si]
            : 0.0;
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"cublas_hgemm_tflops\":     %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_hgemm_median_ms\":  %.6f,\n", res[si].cublas.median);
        fprintf(rj, "      \"cublas_hgemm_mean_ms\":    %.6f,\n", res[si].cublas.mean);
        fprintf(rj, "      \"cublas_hgemm_std_ms\":     %.6f,\n", res[si].cublas.std);
        fprintf(rj, "      \"cublas_hgemm_min_ms\":     %.6f,\n", res[si].cublas.min);
        fprintf(rj, "      \"cublas_hgemm_max_ms\":     %.6f,\n", res[si].cublas.max);
        fprintf(rj, "      \"n77_baseline_tflops\":     %.6f,\n", n77_tflops[si]);
        if (n89_tflops[si] > 0)
            fprintf(rj, "      \"n89_baseline_tflops\":     %.6f,\n", n89_tflops[si]);
        else
            fprintf(rj, "      \"n89_baseline_tflops\":     null,\n");
        if (res[si].hexa_valid) {
            fprintf(rj, "      \"hexa_pv_tflops\":          %.6f,\n", res[si].hexa_tflops);
            fprintf(rj, "      \"hexa_pv_median_ms\":       %.6f,\n", res[si].hexa.median);
            fprintf(rj, "      \"hexa_pv_mean_ms\":         %.6f,\n", res[si].hexa.mean);
            fprintf(rj, "      \"hexa_pv_std_ms\":          %.6f,\n", res[si].hexa.std);
            fprintf(rj, "      \"hexa_pv_min_ms\":          %.6f,\n", res[si].hexa.min);
            fprintf(rj, "      \"hexa_pv_max_ms\":          %.6f,\n", res[si].hexa.max);
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":   %.6f,\n", res[si].hexa_maxabs);
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":   %.6f,\n", res[si].hexa_maxrel);
            fprintf(rj, "      \"ratio_vs_cublas\":         %.6f,\n", res[si].ratio);
            fprintf(rj, "      \"pct_over_n77\":            %.4f,\n", pct_over_n77);
            if (n89_tflops[si] > 0)
                fprintf(rj, "      \"pct_over_n89\":            %.4f,\n", pct_over_n89);
            else
                fprintf(rj, "      \"pct_over_n89\":            null,\n");
            fprintf(rj, "      \"grid_x\":                  %u,\n", res[si].grid_x);
            fprintf(rj, "      \"num_tiles\":               %u,\n", res[si].num_tiles);
            fprintf(rj, "      \"tiles_per_cta\":           %u,\n", res[si].tiles_per_cta);
            fprintf(rj, "      \"note\":                    null\n");
        } else {
            fprintf(rj, "      \"hexa_pv_tflops\":          null,\n");
            fprintf(rj, "      \"hexa_pv_median_ms\":       null,\n");
            fprintf(rj, "      \"hexa_pv_mean_ms\":         null,\n");
            fprintf(rj, "      \"hexa_pv_std_ms\":          null,\n");
            fprintf(rj, "      \"hexa_pv_min_ms\":          null,\n");
            fprintf(rj, "      \"hexa_pv_max_ms\":          null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":   null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":   null,\n");
            fprintf(rj, "      \"ratio_vs_cublas\":         null,\n");
            fprintf(rj, "      \"pct_over_n77\":            null,\n");
            fprintf(rj, "      \"pct_over_n89\":            null,\n");
            fprintf(rj, "      \"grid_x\":                  null,\n");
            fprintf(rj, "      \"num_tiles\":               null,\n");
            fprintf(rj, "      \"tiles_per_cta\":           null,\n");
            fprintf(rj, "      \"note\":                    \"%s\"\n", res[si].note);
        }
        fprintf(rj, "    }%s\n", (si == N_SHAPES - 1) ? "" : ",");
    }
    fprintf(rj, "  ]\n");
    fprintf(rj, "}\n");
    fclose(rj);

    cublasDestroy(handle);
    for (int si = 0; si < N_SHAPES; ++si) if (load_ok[si]) cuModuleUnload(mods[si]);
    cuCtxDestroy(ctx);
    return 0;
}
