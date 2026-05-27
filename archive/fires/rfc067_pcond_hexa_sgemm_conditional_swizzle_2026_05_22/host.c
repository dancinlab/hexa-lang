/* RFC 067 PCOND -- 4-WARP 64x64 + CONDITIONAL CTA-swizzle full-range sweep (2026-05-22)
 *
 * Goal: single "best everywhere" SGEMM kernel. At kernel entry the kernel branches on the
 *       launch grid CTA count (gridDim.x * gridDim.y) -- a uniform grid-constant, no warp
 *       divergence -- and selects:
 *         grid_ctas <= THRESHOLD (4096)  -> IDENTITY map  (sw=ctaid; NO Hilbert prologue)
 *         grid_ctas >  THRESHOLD          -> HILBERT d2xy  (L2-locality recovery)
 *       N168 found swizzle+pipeline regime-orthogonal: Hilbert prologue HURTS small M
 *       (unamortised over short K-loop) but helps large M (L2 thrash). Conditional gating
 *       gets the best of both.
 *
 * Launch grid (host picks the grid matching the in-kernel decision):
 *   IDENTITY regime (M<=4096): launch gx x gy = (M/64) x (N/64). No padding CTAs; kernel
 *       reads gridDim = gx*gy <= 4096 -> takes identity path. sw = ctaid directly.
 *   HILBERT regime (M>=5120): launch p x p, p = next_pow2(M/64) = 128 here. Kernel reads
 *       gridDim = 16384 > 4096 -> takes Hilbert path. d2xy + padding early-return.
 *
 * Sweep: M = 256/384/512/1024/2048/4096 (identity) + 6144/8192 (Hilbert).
 *
 * Per-shape comparison baselines (both measured on ubu-2 RTX 5070 sm_120, same config):
 *   N107 PZbig identity: M256 1.0606, M384 0.8683, M512 0.9111, M1024 0.7375,
 *                        M2048 0.8180, M4096 0.8185
 *   N149 PHILB  Hilbert: M4096 0.8213, M6144 0.8339, M8192 0.8473
 *
 * Falsifier F-RFC067-HEXA-SGEMM-CONDITIONAL-SWIZZLE:
 *   - Numeric: per-element maxabs vs cuBLAS HGEMM (must be 0.0 -- bit-exact, all shapes)
 *   - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync each iter
 *   - small-M (256-512) should match N107 identity (no Hilbert prologue penalty)
 *   - large-M (6144-8192) should match N149 Hilbert (cliff recovered)
 *
 * Build:  nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 */

#include <cuda.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define THRESHOLD_CTAS 4096

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

static unsigned int next_pow2_u(unsigned int n) {
    unsigned int p = 1;
    while (p < n) p <<= 1;
    return p;
}

/* Decide the launch grid for a given side (=M/64), matching the in-kernel branch.
 * Identity regime: grid = side x side (gx*gy <= THRESHOLD).
 * Hilbert regime:  grid = p x p, p = next_pow2(side) (p*p > THRESHOLD). */
static void launch_grid_for(unsigned int side, unsigned int *gx, unsigned int *gy,
                            int *is_hilbert) {
    if (side * side <= (unsigned int)THRESHOLD_CTAS) {
        *gx = side; *gy = side; *is_hilbert = 0;
    } else {
        unsigned int p = next_pow2_u(side);
        *gx = p; *gy = p; *is_hilbert = 1;
    }
}

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

static int run_cublas_hgemm(cublasHandle_t handle, int M, int N, int K,
                            CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                            int warmup, int reps, double *out_times_ms) {
    float alpha = 1.0f, beta = 0.0f;
    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));
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
        float ms = 0.0f;
        CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
        out_times_ms[i] = (double)ms;
    }
    cudaEventDestroy(ev_a);
    cudaEventDestroy(ev_b);
    return 0;
}

static int run_hexa(CUfunction f_hexa, int M, int N, int K,
                    CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                    int warmup, int reps, double *out_times_ms) {
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };

    unsigned int side = (unsigned int)(N / 64);
    unsigned int gx, gy; int is_hilbert;
    launch_grid_for(side, &gx, &gy, &is_hilbert);

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));
    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());
    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
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

static int load_ptx_kernel(const char *ptx_path, const char *entry,
                           CUmodule *out_mod, CUfunction *out_fn,
                           char *out_info, size_t out_info_n) {
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
    char log_info[8192]; log_info[0] = 0;
    CUjit_option jit_opts[5] = {
        CU_JIT_TARGET_FROM_CUCONTEXT,
        CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_INFO_LOG_BUFFER, CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
    };
    void *jit_vals[5] = {
        (void *)0,
        (void *)log_err, (void *)(uintptr_t)sizeof(log_err),
        (void *)log_info, (void *)(uintptr_t)sizeof(log_info),
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
    if (out_info && out_info_n > 0) {
        strncpy(out_info, log_info, out_info_n - 1);
        out_info[out_info_n - 1] = 0;
    }
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
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    unsigned int side = (unsigned int)(N / 64);
    unsigned int gx, gy; int is_hilbert;
    launch_grid_for(side, &gx, &gy, &is_hilbert);
    CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    float *hexa_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(hexa_c, dc, snap_n * sizeof(float)));

    float maxabs = 0.0f, maxrel = 0.0f;
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

#define N_SHAPES 8

int main(int argc, char **argv) {
    int shapes[N_SHAPES] = { 256, 384, 512, 1024, 2048, 4096, 6144, 8192 };

    /* N107 PZbig identity baselines (ubu-2 RTX 5070, same launch config). -1 => not measured. */
    double n107_ratio[N_SHAPES]  = { 1.060606, 0.868313, 0.911051, 0.737470, 0.817996, 0.818492, -1.0, -1.0 };
    double n107_tflops[N_SHAPES] = { 5.295839, 14.563555, 22.610803, 40.041089, 54.771570, 57.329673, -1.0, -1.0 };
    /* N149 PHILB Hilbert baselines (ubu-1 RTX 5070; cliff regime). -1 => not measured. */
    double n149_ratio[N_SHAPES]  = { -1.0, -1.0, -1.0, -1.0, -1.0, 0.821263, 0.833949, 0.847302 };
    double n149_tflops[N_SHAPES] = { -1.0, -1.0, -1.0, -1.0, -1.0, 56.991156, 58.486211, 59.477660 };

    if (argc < 1 + N_SHAPES) {
        fprintf(stderr, "usage: %s <8 ptx files in order 256 384 512 1024 2048 4096 6144 8192>\n", argv[0]);
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
    printf("THRESHOLD_CTAS=%d (M<=4096 identity, M>=5120 Hilbert)\n", THRESHOLD_CTAS);

    CUmodule   mods[N_SHAPES];
    CUfunction fns[N_SHAPES];
    int        load_ok[N_SHAPES];
    char       load_err[N_SHAPES][200];
    char       load_info[N_SHAPES][8192];
    FILE *fp_info = fopen("ptxas_info.log", "w");
    for (int si = 0; si < N_SHAPES; ++si) {
        char entry[64];
        snprintf(entry, sizeof(entry), "sgemm_4warp_cond_%dx%d_grid", shapes[si], shapes[si]);
        if (load_ptx_kernel(argv[1 + si], entry, &mods[si], &fns[si],
                            load_info[si], sizeof(load_info[si])) == 0) {
            load_ok[si] = 1; load_err[si][0] = 0;
            printf("loaded hexa-PCOND PTX shape %d (%s)\n", shapes[si], entry);
            if (fp_info) fprintf(fp_info, "=== shape %d (%s) ===\n%s\n\n", shapes[si], entry, load_info[si]);
        } else {
            load_ok[si] = 0;
            snprintf(load_err[si], sizeof(load_err[si]), "PTX load/lookup failed for %s", argv[1 + si]);
            printf("FAILED hexa-PCOND PTX shape %d -- skipping\n", shapes[si]);
        }
        if (load_ok[si]) {
            int reg_per_thd = 0, shmem_bytes = 0, max_thd = 0;
            cuFuncGetAttribute(&reg_per_thd, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            cuFuncGetAttribute(&shmem_bytes, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[si]);
            cuFuncGetAttribute(&max_thd, CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK, fns[si]);
            printf("  shape %d: regs/thd=%d, shmem=%d B, max_thd_per_block=%d\n",
                   shapes[si], reg_per_thd, shmem_bytes, max_thd);
            if (fp_info) fprintf(fp_info, "shape %d cuFuncGetAttribute: regs/thd=%d, shmem=%d B, max_thd_per_block=%d\n\n",
                                 shapes[si], reg_per_thd, shmem_bytes, max_thd);
        }
    }
    if (fp_info) fclose(fp_info);

    size_t free_b = 0, total_b = 0;
    cuMemGetInfo(&free_b, &total_b);
    printf("Device VRAM free=%.2f MB total=%.2f MB\n",
           (double)free_b / 1048576.0, (double)total_b / 1048576.0);

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
        float  hexa_maxabs, hexa_maxrel;
        stat_t hexa;
        double hexa_tflops, ratio;
        unsigned int grid_x, grid_y, ctas_launched, ctas_real;
        int    is_hilbert;
        int    regs_per_thd;
        size_t bytes_allocated;
        char   note[256];
    } shape_result_t;

    shape_result_t res[N_SHAPES];
    memset(res, 0, sizeof(res));
    double *times = (double *)malloc(REPS * sizeof(double));

    for (int si = 0; si < N_SHAPES; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        res[si].M = M; res[si].N = N; res[si].K = K;
        unsigned int side = (unsigned int)(M / 64);
        unsigned int gx, gy; int is_hilbert;
        launch_grid_for(side, &gx, &gy, &is_hilbert);
        res[si].grid_x = gx; res[si].grid_y = gy;
        res[si].ctas_launched = gx * gy;
        res[si].ctas_real = side * side;
        res[si].is_hilbert = is_hilbert;
        if (load_ok[si]) {
            int rpt = 0;
            cuFuncGetAttribute(&rpt, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            res[si].regs_per_thd = rpt;
        }

        const size_t ASZ = (size_t)M * (size_t)K;
        const size_t BSZ = (size_t)K * (size_t)N;
        const size_t CSZ = (size_t)M * (size_t)N;
        size_t bytes_needed = ASZ * 2 + BSZ * 2 + CSZ * 4;
        res[si].bytes_allocated = bytes_needed;
        printf("[M=%4d] %-8s launch %ux%u (%u CTAs, %u real) -- alloc %.2f MB\n",
               M, is_hilbert ? "HILBERT" : "IDENTITY", gx, gy, gx*gy, side*side,
               (double)bytes_needed / 1048576.0);

        unsigned short *ha = (unsigned short *)malloc(ASZ * sizeof(unsigned short));
        unsigned short *hb = (unsigned short *)malloc(BSZ * sizeof(unsigned short));
        if (!ha || !hb) {
            snprintf(res[si].note, sizeof(res[si].note), "host malloc failed at M=%d", M);
            if (ha) free(ha); if (hb) free(hb);
            continue;
        }
        for (size_t i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
        for (size_t i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

        CUdeviceptr da = 0, db = 0, dc = 0;
        CUresult e_a = cuMemAlloc(&da, ASZ * sizeof(unsigned short));
        CUresult e_b = cuMemAlloc(&db, BSZ * sizeof(unsigned short));
        CUresult e_c = cuMemAlloc(&dc, CSZ * sizeof(float));
        if (e_a != CUDA_SUCCESS || e_b != CUDA_SUCCESS || e_c != CUDA_SUCCESS) {
            snprintf(res[si].note, sizeof(res[si].note),
                     "cuMemAlloc OOM at M=%d (needed %.2f MB)", M, (double)bytes_needed / 1048576.0);
            if (da) cuMemFree(da); if (db) cuMemFree(db); if (dc) cuMemFree(dc);
            free(ha); free(hb);
            continue;
        }
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
        printf("[M=%4d] cuBLAS HGEMM             median=%.6f ms  TFLOPS=%8.4f\n",
               M, res[si].cublas.median, res[si].cublas_tflops);

        if (load_ok[si]) {
            float maxabs = 0.0f, maxrel = 0.0f;
            sanity_check(handle, fns[si], M, N, K, da, db, dc, &maxabs, &maxrel);
            res[si].hexa_maxabs = maxabs;
            res[si].hexa_maxrel = maxrel;

            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            if (run_hexa(fns[si], M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
                res[si].hexa_valid = 0;
                snprintf(res[si].note, sizeof(res[si].note), "hexa launch failure at M=%d", M);
            } else {
                res[si].hexa_valid = 1;
                res[si].hexa = stats_compute(times, REPS);
                res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
                res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
                printf("[M=%4d] hexa-PCOND %-8s     median=%.6f ms  TFLOPS=%8.4f  ratio=%.4f  maxabs=%.4f  CTAs=%u  regs=%d\n",
                       M, res[si].is_hilbert ? "HILBERT" : "IDENTITY", res[si].hexa.median,
                       res[si].hexa_tflops, res[si].ratio, res[si].hexa_maxabs,
                       res[si].ctas_launched, res[si].regs_per_thd);
            }
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note), "%s", load_err[si]);
            printf("[M=%4d] hexa-PCOND SKIPPED -- %s\n", M, res[si].note);
        }
        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PCOND-hexa-hgemm-conditional-swizzle\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
    fprintf(rj, "  \"host\": \"%s\",\n", getenv("PY_HOST") ? getenv("PY_HOST") : "ubu-2");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"threshold_ctas\": %d,\n", THRESHOLD_CTAS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"variant\": \"PCOND -- single 'best everywhere' kernel. At kernel entry, branch on grid CTA count (gridDim.x*gridDim.y), a uniform grid-constant -> NO warp divergence, predicated once: grid_ctas<=THRESHOLD(4096) -> IDENTITY (sw=ctaid, no Hilbert prologue, byte-identical N107 PY K-loop); else -> HILBERT d2xy (byte-identical N149 PHILB) + padding early-return. Host picks launch grid: identity = side x side, Hilbert = p x p (p=next_pow2(side)). N168 found swizzle+pipeline regime-orthogonal (Hilbert prologue hurts small M, helps large M); conditional gating gets best of both.\",\n");
    fprintf(rj, "  \"hexa_kernel_family\": \"sgemm_4warp_cond_SxS_grid\",\n");
    fprintf(rj, "  \"cublas_math_mode\": \"CUBLAS_TENSOR_OP_MATH (HGEMM via cublasGemmEx)\",\n");
    fprintf(rj, "  \"stack_inputs\": {\n");
    fprintf(rj, "    \"N107_PZbig\": \"rfc067_pZbig_hexa_sgemm_n107_bigshape (identity): M256 1.061, M384 0.868, M512 0.911, M1024 0.737, M2048 0.818, M4096 0.818\",\n");
    fprintf(rj, "    \"N149_PHILB\": \"rfc067_philb_hexa_sgemm_hilbert_swizzle (Hilbert): M4096 0.821, M5120 0.827, M6144 0.834, M8192 0.847\",\n");
    fprintf(rj, "    \"N168\": \"swizzle+pipeline regime-orthogonal; Hilbert prologue hurts small M (M=384 0.98->0.64) -> conditional gating needed\"\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"hypothesis\": \"A single kernel that branches at entry on grid CTA count (identity at small M, Hilbert d2xy at large M) matches N107 identity at small M (no Hilbert prologue penalty) AND matches N149 Hilbert at large M (cliff recovered) -> best across the full range with one kernel.\",\n");
    fprintf(rj, "  \"branch_cost\": \"~5 instructions at entry (mov.nctaid.x, mov.nctaid.y, mul.lo, setp.le, predicated bra). Uniform across all CTAs (grid-size constant) -> no warp divergence, predicated once. Negligible vs K-loop.\",\n");
    fprintf(rj, "  \"launch_config\": {\n");
    fprintf(rj, "    \"threads_per_block\": 128, \"warps_per_block\": 4,\n");
    fprintf(rj, "    \"output_tile_M\": 64, \"output_tile_N\": 64,\n");
    fprintf(rj, "    \"mma_per_warp_per_kstep\": 8, \"acc_f32_per_lane\": 32, \"shmem_bytes_per_cta\": 8192\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
        int has_n107 = (n107_ratio[si] >= 0.0);
        int has_n149 = (n149_ratio[si] >= 0.0);
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"regime\":                 \"%s\",\n", res[si].is_hilbert ? "hilbert" : "identity");
        fprintf(rj, "      \"grid_x\": %u, \"grid_y\": %u,\n", res[si].grid_x, res[si].grid_y);
        fprintf(rj, "      \"ctas_launched\":          %u,\n", res[si].ctas_launched);
        fprintf(rj, "      \"ctas_real\":              %u,\n", res[si].ctas_real);
        fprintf(rj, "      \"ctas_padding_return\":    %u,\n", res[si].ctas_launched - res[si].ctas_real);
        fprintf(rj, "      \"vram_bytes_allocated\":   %zu,\n", res[si].bytes_allocated);
        fprintf(rj, "      \"pcond_regs_per_thd\":     %d,\n", res[si].regs_per_thd);
        fprintf(rj, "      \"cublas_hgemm_tflops\":    %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_hgemm_median_ms\": %.6f,\n", res[si].cublas.median);
        if (has_n107) {
            fprintf(rj, "      \"n107_identity_ratio\":    %.6f,\n", n107_ratio[si]);
            fprintf(rj, "      \"n107_identity_tflops\":   %.6f,\n", n107_tflops[si]);
        } else {
            fprintf(rj, "      \"n107_identity_ratio\":    null,\n");
            fprintf(rj, "      \"n107_identity_tflops\":   null,\n");
        }
        if (has_n149) {
            fprintf(rj, "      \"n149_hilbert_ratio\":     %.6f,\n", n149_ratio[si]);
            fprintf(rj, "      \"n149_hilbert_tflops\":    %.6f,\n", n149_tflops[si]);
        } else {
            fprintf(rj, "      \"n149_hilbert_ratio\":     null,\n");
            fprintf(rj, "      \"n149_hilbert_tflops\":    null,\n");
        }
        if (res[si].hexa_valid) {
            double match_ref = res[si].is_hilbert ? (has_n149 ? n149_ratio[si] : -1.0)
                                                  : (has_n107 ? n107_ratio[si] : -1.0);
            double ratio_delta_ref = (match_ref >= 0.0) ? (res[si].ratio - match_ref) : 0.0;
            fprintf(rj, "      \"hexa_pcond_tflops\":      %.6f,\n", res[si].hexa_tflops);
            fprintf(rj, "      \"hexa_pcond_median_ms\":   %.6f,\n", res[si].hexa.median);
            fprintf(rj, "      \"hexa_pcond_std_ms\":      %.6f,\n", res[si].hexa.std);
            fprintf(rj, "      \"hexa_pcond_min_ms\":      %.6f,\n", res[si].hexa.min);
            fprintf(rj, "      \"hexa_pcond_max_ms\":      %.6f,\n", res[si].hexa.max);
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":  %.6f,\n", res[si].hexa_maxabs);
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":  %.6f,\n", res[si].hexa_maxrel);
            fprintf(rj, "      \"ratio_vs_cublas\":        %.6f,\n", res[si].ratio);
            if (match_ref >= 0.0)
                fprintf(rj, "      \"ratio_delta_vs_regime_ref\": %.6f,\n", ratio_delta_ref);
            else
                fprintf(rj, "      \"ratio_delta_vs_regime_ref\": null,\n");
            fprintf(rj, "      \"bit_exact_pass\":         %s,\n", (res[si].hexa_maxabs == 0.0f) ? "true" : "false");
            fprintf(rj, "      \"note\":                   null\n");
        } else {
            fprintf(rj, "      \"hexa_pcond_tflops\":      null,\n");
            fprintf(rj, "      \"hexa_pcond_median_ms\":   null,\n");
            fprintf(rj, "      \"hexa_pcond_std_ms\":      null,\n");
            fprintf(rj, "      \"hexa_pcond_min_ms\":      null,\n");
            fprintf(rj, "      \"hexa_pcond_max_ms\":      null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":  null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":  null,\n");
            fprintf(rj, "      \"ratio_vs_cublas\":        null,\n");
            fprintf(rj, "      \"ratio_delta_vs_regime_ref\": null,\n");
            fprintf(rj, "      \"bit_exact_pass\":         null,\n");
            fprintf(rj, "      \"note\":                   \"%s\"\n", res[si].note);
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
