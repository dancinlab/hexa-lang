/* RFC 067 PBEAT -- cuBLAS-BEAT envelope sweep: N121 (6-stage) + N107 (swizzle) (2026-05-22)
 *
 * Maps the exact M where the small-tile hexa SGEMM STOPS beating cuBLAS HGEMM.
 * N121 prior: M=256 ratio 1.1611 BEAT, M=384 0.980, M=512 0.877.
 * N107 prior: M=256 ratio 1.053 BEAT, M=384 0.868, M=512 0.911.
 * This fire sweeps M = 192/256/320/384/448/512 (64-aligned), running BOTH
 * variants per shape against the same cuBLAS HGEMM reference.
 *
 * cuBLAS-BEAT is a small-shape LAUNCH-OVERHEAD-bound regime (under-subscribed grid),
 * NOT a compute-bound signal. cuBLAS launch-bound timing is noisy at small M, so the
 * fire is run 3x (run-tags r1/r2/r3) to capture variance.
 *
 * Falsifier F-RFC067-CUBLAS-BEAT-ENVELOPE:
 *   - Numeric: per-element maxabs vs cuBLAS HGEMM == 0.0 (bit-exact) for ALL shapes,
 *     BOTH variants (mma identical -> bit-exact).
 *   - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync each iter.
 *   - Report ratio_n121, ratio_n107 vs cuBLAS at every shape.
 *   - BEAT boundary = largest M with max(ratio_n121, ratio_n107) > 1.0.
 *
 * Launch config (both variants identical):
 *   block = (128, 1, 1)              -- 4 warps
 *   grid  = (N/64, M/64, 1)
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 * Run:
 *   ./host <run_tag> \
 *     sgemm_4warp_6stage_192x192_grid.ptx ... 512x512_grid.ptx \
 *     sgemm_4warp_swizzle_192x192_grid.ptx ... 512x512_grid.ptx
 *   (run_tag is a free string written into result_<tag>.json, e.g. r1/r2/r3)
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

typedef struct { double median, mean, std, min, max; } stat_t;

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
        if (exp < -10) out = (sign << 15);
        else { mant |= 0x800000; int shift = 14 - exp; out = (sign << 15) | (mant >> shift); }
    } else {
        out = (sign << 15) | (exp << 10) | (mant >> 13);
    }
    return out;
}

static int run_cublas_hgemm(cublasHandle_t handle, int M, int N, int K,
                            CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                            int warmup, int reps, double *out_times_ms) {
    float alpha = 1.0f, beta = 0.0f;
    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a)); CHECK_RT(cudaEventCreate(&ev_b));
    for (int i = 0; i < warmup; ++i) {
        CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            (const void *)(uintptr_t)db, CUDA_R_16F, N,
            (const void *)(uintptr_t)da, CUDA_R_16F, K, &beta,
            (void *)(uintptr_t)dc, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    }
    CHECK_CU(cuCtxSynchronize());
    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            (const void *)(uintptr_t)db, CUDA_R_16F, N,
            (const void *)(uintptr_t)da, CUDA_R_16F, K, &beta,
            (void *)(uintptr_t)dc, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CHECK_RT(cudaEventRecord(ev_b, 0));
        CHECK_RT(cudaEventSynchronize(ev_b));
        float ms = 0.0f; CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
        out_times_ms[i] = (double)ms;
    }
    cudaEventDestroy(ev_a); cudaEventDestroy(ev_b);
    return 0;
}

static int run_hexa(CUfunction f_hexa, int M, int N, int K,
                    CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                    int warmup, int reps, double *out_times_ms) {
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    unsigned int gx = (unsigned int)(N / 64);
    unsigned int gy = (unsigned int)(M / 64);
    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a)); CHECK_RT(cudaEventCreate(&ev_b));
    for (int i = 0; i < warmup; ++i)
        CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
        CHECK_RT(cudaEventRecord(ev_b, 0));
        CHECK_RT(cudaEventSynchronize(ev_b));
        float ms = 0.0f; CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
        out_times_ms[i] = (double)ms;
    }
    cudaEventDestroy(ev_a); cudaEventDestroy(ev_b);
    return 0;
}

static int load_ptx_kernel(const char *ptx_path, const char *entry,
                           CUmodule *out_mod, CUfunction *out_fn,
                           char *out_info, size_t out_info_n) {
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { fprintf(stderr, "ptx open %s: ", ptx_path); perror(""); return 1; }
    fseek(fp, 0, SEEK_END); long n_ptx = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) { fprintf(stderr, "ptx short read %s\n", ptx_path); return 1; }
    ptx[n_ptx] = 0; fclose(fp);
    char log_err[8192]; log_err[0] = 0;
    char log_info[8192]; log_info[0] = 0;
    CUjit_option jit_opts[5] = {
        CU_JIT_TARGET_FROM_CUCONTEXT, CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_INFO_LOG_BUFFER, CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
    };
    void *jit_vals[5] = {
        (void *)0, (void *)log_err, (void *)(uintptr_t)sizeof(log_err),
        (void *)log_info, (void *)(uintptr_t)sizeof(log_info),
    };
    CUresult e = cuModuleLoadDataEx(out_mod, ptx, 5, jit_opts, jit_vals);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleLoadDataEx %s: %s\n", ptx_path, s ? s : "?");
        if (log_err[0]) fprintf(stderr, "  ptxas err: %s\n", log_err);
        free(ptx); return 1;
    }
    e = cuModuleGetFunction(out_fn, *out_mod, entry);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleGetFunction %s %s: %s\n", ptx_path, entry, s ? s : "?");
        free(ptx); return 1;
    }
    if (out_info && out_info_n > 0) { strncpy(out_info, log_info, out_info_n - 1); out_info[out_info_n - 1] = 0; }
    free(ptx);
    return 0;
}

static int sanity_check(cublasHandle_t handle, CUfunction f_hexa, int M, int N, int K,
                        CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                        float *out_maxabs, float *out_maxrel) {
    float alpha = 1.0f, beta = 0.0f;
    size_t csz_bytes = (size_t)M * (size_t)N * sizeof(float);
    CHECK_CU(cuMemsetD8(dc, 0, csz_bytes));
    CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
        (const void *)(uintptr_t)db, CUDA_R_16F, N,
        (const void *)(uintptr_t)da, CUDA_R_16F, K, &beta,
        (void *)(uintptr_t)dc, CUDA_R_32F, N,
        CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CHECK_CU(cuCtxSynchronize());
    size_t snap_n = (size_t)M * (size_t)N;
    float *cublas_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(cublas_c, dc, snap_n * sizeof(float)));
    CHECK_CU(cuMemsetD8(dc, 0, csz_bytes));
    const int K_PER_TILE = 16, K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    unsigned int gx = (unsigned int)(N / 64), gy = (unsigned int)(M / 64);
    CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    float *hexa_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(hexa_c, dc, snap_n * sizeof(float)));
    float maxabs = 0.0f, maxrel = 0.0f;
    for (size_t i = 0; i < snap_n; ++i) {
        float d = fabsf(cublas_c[i] - hexa_c[i]);
        if (d > maxabs) maxabs = d;
        float scale = fabsf(cublas_c[i]);
        if (scale > 1e-3f) { float r = d / scale; if (r > maxrel) maxrel = r; }
    }
    free(cublas_c); free(hexa_c);
    *out_maxabs = maxabs; *out_maxrel = maxrel;
    return 1;
}

#define N_SHAPES 6
#define N_VAR    2   /* 0 = N121 6-stage, 1 = N107 swizzle */

int main(int argc, char **argv) {
    int shapes[N_SHAPES] = { 192, 256, 320, 384, 448, 512 };
    const char *var_entry_prefix[N_VAR] = { "sgemm_4warp_6stage", "sgemm_4warp_swizzle" };
    const char *var_label[N_VAR]        = { "N121-6stage", "N107-swizzle" };

    /* argv[1] = run_tag; argv[2..2+6) = 6stage ptx; argv[8..8+6) = swizzle ptx */
    if (argc < 1 + 1 + N_VAR * N_SHAPES) {
        fprintf(stderr, "usage: %s <run_tag> <6 x 6stage.ptx> <6 x swizzle.ptx>  (%d args)\n",
                argv[0], 1 + N_VAR * N_SHAPES);
        return 2;
    }
    const char *run_tag = argv[1];

    CHECK_CU(cuInit(0));
    CUdevice  dev; CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK_CU(cuCtxCreate(&ctx, 0, dev));
    char dev_name[256]; CHECK_CU(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    int driver_ver = 0, runtime_ver = 0;
    CHECK_CU(cuDriverGetVersion(&driver_ver)); cudaRuntimeGetVersion(&runtime_ver);
    printf("=== run_tag=%s ===\n", run_tag);
    printf("Device: %s sm_%d%d  driver=%d runtime=%d\n", dev_name, sm_major, sm_minor, driver_ver, runtime_ver);

    CUmodule   mods[N_VAR][N_SHAPES];
    CUfunction fns[N_VAR][N_SHAPES];
    int        load_ok[N_VAR][N_SHAPES];
    int        regs[N_VAR][N_SHAPES];
    int        shmem[N_VAR][N_SHAPES];
    char       info[8192];

    char info_path[64]; snprintf(info_path, sizeof(info_path), "ptxas_info_%s.log", run_tag);
    FILE *fp_info = fopen(info_path, "w");
    for (int v = 0; v < N_VAR; ++v) {
        for (int si = 0; si < N_SHAPES; ++si) {
            int arg_idx = 2 + v * N_SHAPES + si;
            char entry[80];
            snprintf(entry, sizeof(entry), "%s_%dx%d_grid", var_entry_prefix[v], shapes[si], shapes[si]);
            if (load_ptx_kernel(argv[arg_idx], entry, &mods[v][si], &fns[v][si], info, sizeof(info)) == 0) {
                load_ok[v][si] = 1;
                int rpt = 0, smb = 0;
                cuFuncGetAttribute(&rpt, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[v][si]);
                cuFuncGetAttribute(&smb, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[v][si]);
                regs[v][si] = rpt; shmem[v][si] = smb;
                printf("loaded %s M=%d (regs=%d shmem=%d)\n", var_label[v], shapes[si], rpt, smb);
                if (fp_info) fprintf(fp_info, "%s M=%d regs=%d shmem=%d\n%s\n\n", var_label[v], shapes[si], rpt, smb, info);
            } else {
                load_ok[v][si] = 0;
                printf("FAILED %s M=%d -- skipping\n", var_label[v], shapes[si]);
            }
        }
    }
    if (fp_info) fclose(fp_info);

    cublasHandle_t handle;
    CHECK_BLAS(cublasCreate(&handle));
    CHECK_BLAS(cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH));

    const int WARMUP = 20, REPS = 200;

    typedef struct {
        double cublas_tflops; stat_t cublas;
        int    valid[N_VAR];
        float  maxabs[N_VAR], maxrel[N_VAR];
        double tflops[N_VAR]; stat_t st[N_VAR];
        double ratio[N_VAR];
    } shape_result_t;

    shape_result_t res[N_SHAPES];
    memset(res, 0, sizeof(res));
    double *times = (double *)malloc(REPS * sizeof(double));

    for (int si = 0; si < N_SHAPES; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        const size_t ASZ = (size_t)M * (size_t)K, BSZ = (size_t)K * (size_t)N, CSZ = (size_t)M * (size_t)N;
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
            fprintf(stderr, "cuBLAS HGEMM run failed at shape %d\n", M); return 1;
        }
        res[si].cublas = stats_compute(times, REPS);
        double flops = 2.0 * (double)M * (double)N * (double)K;
        res[si].cublas_tflops = flops / (res[si].cublas.median / 1000.0) / 1e12;
        printf("[M=%4d] cuBLAS HGEMM   median=%.6f ms  TFLOPS=%8.4f  CTAs=%d\n",
               M, res[si].cublas.median, res[si].cublas_tflops, (M/64)*(N/64));

        for (int v = 0; v < N_VAR; ++v) {
            if (!load_ok[v][si]) { res[si].valid[v] = 0; printf("[M=%4d] %-12s SKIPPED (load fail)\n", M, var_label[v]); continue; }
            float maxabs = 0.0f, maxrel = 0.0f;
            sanity_check(handle, fns[v][si], M, N, K, da, db, dc, &maxabs, &maxrel);
            res[si].maxabs[v] = maxabs; res[si].maxrel[v] = maxrel;
            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            if (run_hexa(fns[v][si], M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
                res[si].valid[v] = 0; printf("[M=%4d] %-12s RUN FAIL\n", M, var_label[v]); continue;
            }
            res[si].valid[v] = 1;
            res[si].st[v] = stats_compute(times, REPS);
            res[si].tflops[v] = flops / (res[si].st[v].median / 1000.0) / 1e12;
            res[si].ratio[v] = res[si].tflops[v] / res[si].cublas_tflops;
            printf("[M=%4d] %-12s median=%.6f ms  TFLOPS=%8.4f  ratio=%.4f  maxabs=%.4f%s\n",
                   M, var_label[v], res[si].st[v].median, res[si].tflops[v], res[si].ratio[v],
                   res[si].maxabs[v], res[si].ratio[v] > 1.0 ? "  [BEAT]" : "");
        }
        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    /* Determine BEAT boundary: largest M where max(ratio_n121, ratio_n107) > 1.0. */
    int beat_boundary_M = 0;
    for (int si = 0; si < N_SHAPES; ++si) {
        double best = -1.0;
        for (int v = 0; v < N_VAR; ++v) if (res[si].valid[v] && res[si].ratio[v] > best) best = res[si].ratio[v];
        if (best > 1.0 && shapes[si] > beat_boundary_M) beat_boundary_M = shapes[si];
    }

    char rj_path[64]; snprintf(rj_path, sizeof(rj_path), "result_%s.json", run_tag);
    FILE *rj = fopen(rj_path, "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PBEAT-cublas-beat-envelope\",\n");
    fprintf(rj, "  \"run_tag\": \"%s\",\n", run_tag);
    fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
    fprintf(rj, "  \"host\": \"ubu-2\",\n");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"variants\": [\"N121-6stage (4-warp 64x64 + 6-stage cp.async)\", \"N107-swizzle (4-warp 64x64 + 2-slot swizzle)\"],\n");
    fprintf(rj, "  \"cublas_math_mode\": \"CUBLAS_TENSOR_OP_MATH (HGEMM via cublasGemmEx)\",\n");
    fprintf(rj, "  \"note\": \"cuBLAS-BEAT regime is small-shape LAUNCH-OVERHEAD-bound (under-subscribed grid), NOT compute-bound. Run 3x (r1/r2/r3) for variance.\",\n");
    fprintf(rj, "  \"beat_boundary_M\": %d,\n", beat_boundary_M);
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
        int M = shapes[si];
        double best_ratio = -1.0; const char *best_var = "none";
        for (int v = 0; v < N_VAR; ++v) if (res[si].valid[v] && res[si].ratio[v] > best_ratio) { best_ratio = res[si].ratio[v]; best_var = var_label[v]; }
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d, \"num_ctas\": %d,\n", M, M, M, (M/64)*(M/64));
        fprintf(rj, "      \"cublas_hgemm_tflops\": %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_hgemm_median_ms\": %.6f,\n", res[si].cublas.median);
        fprintf(rj, "      \"cublas_hgemm_std_ms\": %.6f,\n", res[si].cublas.std);
        fprintf(rj, "      \"cublas_hgemm_min_ms\": %.6f,\n", res[si].cublas.min);
        if (res[si].valid[0]) {
            fprintf(rj, "      \"n121_6stage_tflops\": %.6f,\n", res[si].tflops[0]);
            fprintf(rj, "      \"n121_6stage_median_ms\": %.6f,\n", res[si].st[0].median);
            fprintf(rj, "      \"n121_6stage_std_ms\": %.6f,\n", res[si].st[0].std);
            fprintf(rj, "      \"n121_maxabs\": %.6f,\n", res[si].maxabs[0]);
            fprintf(rj, "      \"ratio_n121\": %.6f,\n", res[si].ratio[0]);
        } else {
            fprintf(rj, "      \"n121_6stage_tflops\": null, \"ratio_n121\": null,\n");
        }
        if (res[si].valid[1]) {
            fprintf(rj, "      \"n107_swizzle_tflops\": %.6f,\n", res[si].tflops[1]);
            fprintf(rj, "      \"n107_swizzle_median_ms\": %.6f,\n", res[si].st[1].median);
            fprintf(rj, "      \"n107_swizzle_std_ms\": %.6f,\n", res[si].st[1].std);
            fprintf(rj, "      \"n107_maxabs\": %.6f,\n", res[si].maxabs[1]);
            fprintf(rj, "      \"ratio_n107\": %.6f,\n", res[si].ratio[1]);
        } else {
            fprintf(rj, "      \"n107_swizzle_tflops\": null, \"ratio_n107\": null,\n");
        }
        fprintf(rj, "      \"best_ratio\": %.6f,\n", best_ratio);
        fprintf(rj, "      \"best_variant\": \"%s\",\n", best_var);
        fprintf(rj, "      \"beat\": %s\n", best_ratio > 1.0 ? "true" : "false");
        fprintf(rj, "    }%s\n", (si == N_SHAPES - 1) ? "" : ",");
    }
    fprintf(rj, "  ]\n}\n");
    fclose(rj);
    printf("=== run_tag=%s BEAT boundary M = %d ===\n", run_tag, beat_boundary_M);

    cublasDestroy(handle);
    for (int v = 0; v < N_VAR; ++v) for (int si = 0; si < N_SHAPES; ++si) if (load_ok[v][si]) cuModuleUnload(mods[v][si]);
    cuCtxDestroy(ctx);
    return 0;
}
