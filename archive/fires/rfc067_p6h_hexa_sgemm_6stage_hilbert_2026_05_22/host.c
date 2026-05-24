/* RFC 067 P6H -- 4-WARP 64x64 + 6-STAGE cp.async PIPELINE + HILBERT CTA-SWIZZLE (2026-05-22)
 *
 * COMBINE the two regime winners into one kernel:
 *   N121 (PZ):    6-stage cp.async pipeline -- small-shape WIN (M=256 ratio 1.1611,
 *                 cuBLAS-BEAT). But large M hurts (M=1536 -2.32% vs N107 2-stage; shmem
 *                 24576 B cuts occupancy 8->4 CTAs/SM).
 *   N149 (PHILB): Hilbert-curve d2xy CTA-swizzle -- large-shape WIN (M=8192 ratio 0.847,
 *                 M>=6144 L2-thrash cliff flattened). 2-stage pipeline (8192 B shmem).
 *   P6H (this):   N121 6-stage pipeline body + N149 Hilbert CTA visitation. Win BOTH?
 *
 * Launch grid (N149 PHILB): p x p where p = next_pow2(N/64). Kernel computes
 *   (sw_x,sw_y)=d2xy(p,d) from d = ctaid.y*p + ctaid.x, then EARLY-RETURNS padding CTAs
 *   (sw_x>=gx || sw_y>=gy). Bijective over the real gx x gy grid -> bit-exact.
 *     256  -> grid 4x4    -> p=4   (no padding)
 *     384  -> grid 6x6    -> p=8   (64 launched, 36 real, 28 padding-return)
 *     512  -> grid 8x8    -> p=8   (no padding)
 *     4096 -> grid 64x64  -> p=64  (no padding)
 *     6144 -> grid 96x96  -> p=128 (16384 launched, 9216 real, 7168 padding-return)
 *     8192 -> grid 128x128-> p=128 (no padding)
 *
 * Sweep BOTH regimes:
 *   SMALL (N121 6-stage wins): M=256 (PZ 5.825 / 1.1611), M=384 (15.799 / 0.9799),
 *                              M=512 (21.760 / 0.8768)
 *   LARGE (N149 Hilbert wins): M=4096, M=6144, M=8192 (PHILB 8192 ratio 0.847)
 *
 * Falsifier F-RFC067-HEXA-SGEMM-6STAGE-HILBERT:
 *   - Numeric: per-element maxabs vs cuBLAS HGEMM (must be 0.0 -- bit-exact)
 *   - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync each iter
 *   - Headline: combined kernel = best small (M=256 >= 1.16) AND best large (M=8192 >= 0.847)?
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
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

/* Hilbert launch grid is p x p where p = next_pow2(side). */
static unsigned int next_pow2_u(unsigned int n) {
    unsigned int p = 1;
    while (p < n) p <<= 1;
    return p;
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
                    CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                    int warmup, int reps,
                    double *out_times_ms)
{
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };

    /* Hilbert: launch p x p where p = next_pow2(side). Kernel d2xy + padding return. */
    unsigned int side = (unsigned int)(N / 64);
    unsigned int p = next_pow2_u(side);
    unsigned int gx = p;
    unsigned int gy = p;

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa,
            gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa,
            gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
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
                           CUfunction *out_fn,
                           char *out_info,
                           size_t out_info_n)
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
    char log_info[8192]; log_info[0] = 0;
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
    if (out_info && out_info_n > 0) {
        strncpy(out_info, log_info, out_info_n - 1);
        out_info[out_info_n - 1] = 0;
    }
    free(ptx);
    return 0;
}

static int sanity_check(cublasHandle_t handle, CUfunction f_hexa,
                        int M, int N, int K,
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
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    unsigned int side = (unsigned int)(N / 64);
    unsigned int p = next_pow2_u(side);
    unsigned int gx = p, gy = p;
    CHECK_CU(cuLaunchKernel(f_hexa, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
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
    int shapes[N_SHAPES] = { 256, 384, 512, 4096, 6144, 8192 };

    if (argc < 1 + N_SHAPES) {
        fprintf(stderr,
            "usage: %s <ptx_256> <ptx_384> <ptx_512> <ptx_4096> <ptx_6144> <ptx_8192>\n",
            argv[0]);
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

    CUmodule   mods[N_SHAPES];
    CUfunction fns[N_SHAPES];
    int        load_ok[N_SHAPES];
    char       load_err[N_SHAPES][200];
    char       load_info[N_SHAPES][8192];
    FILE *fp_info = fopen("ptxas_info.log", "w");
    for (int si = 0; si < N_SHAPES; ++si) {
        char entry[80];
        snprintf(entry, sizeof(entry), "sgemm_4warp_6stage_hilbert_%dx%d_grid", shapes[si], shapes[si]);
        if (load_ptx_kernel(argv[1 + si], entry, &mods[si], &fns[si],
                            load_info[si], sizeof(load_info[si])) == 0) {
            load_ok[si] = 1; load_err[si][0] = 0;
            printf("loaded hexa-P6H PTX shape %d (%s)\n", shapes[si], entry);
            if (fp_info) {
                fprintf(fp_info, "=== shape %d (%s) ===\n%s\n\n",
                        shapes[si], entry, load_info[si]);
            }
        } else {
            load_ok[si] = 0;
            snprintf(load_err[si], sizeof(load_err[si]),
                "PTX load/lookup failed for %s", argv[1 + si]);
            printf("FAILED hexa-P6H PTX shape %d -- skipping\n", shapes[si]);
        }

        if (load_ok[si]) {
            int reg_per_thd = 0, shmem_bytes = 0, max_thd = 0;
            cuFuncGetAttribute(&reg_per_thd, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            cuFuncGetAttribute(&shmem_bytes, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[si]);
            cuFuncGetAttribute(&max_thd, CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK, fns[si]);
            printf("  shape %d: regs/thd=%d, shmem=%d B, max_thd_per_block=%d\n",
                   shapes[si], reg_per_thd, shmem_bytes, max_thd);
            if (fp_info) {
                fprintf(fp_info, "shape %d cuFuncGetAttribute: regs/thd=%d, shmem=%d B, max_thd_per_block=%d\n\n",
                        shapes[si], reg_per_thd, shmem_bytes, max_thd);
            }
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
        float  hexa_maxabs;
        float  hexa_maxrel;
        stat_t hexa;
        double hexa_tflops;
        double ratio;
        int    num_ctas;
        int    regs_per_thd;
        int    shmem_bytes;
        size_t bytes_allocated;
        char   note[256];
    } shape_result_t;

    shape_result_t res[N_SHAPES];
    memset(res, 0, sizeof(res));

    double *times = (double *)malloc(REPS * sizeof(double));

    for (int si = 0; si < N_SHAPES; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        res[si].M = M; res[si].N = N; res[si].K = K;
        res[si].num_ctas = (M / 64) * (N / 64);
        if (load_ok[si]) {
            int rpt = 0, shb = 0;
            cuFuncGetAttribute(&rpt, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            cuFuncGetAttribute(&shb, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[si]);
            res[si].regs_per_thd = rpt;
            res[si].shmem_bytes  = shb;
        }

        const size_t ASZ = (size_t)M * (size_t)K;
        const size_t BSZ = (size_t)K * (size_t)N;
        const size_t CSZ = (size_t)M * (size_t)N;

        size_t bytes_needed = ASZ * 2 + BSZ * 2 + CSZ * 4;
        res[si].bytes_allocated = bytes_needed;
        printf("[M=%4d] allocating %.2f MB device memory (A=%zu KB + B=%zu KB + C=%zu KB)\n",
               M, (double)bytes_needed / 1048576.0,
               ASZ * 2 / 1024, BSZ * 2 / 1024, CSZ * 4 / 1024);

        unsigned short *ha = (unsigned short *)malloc(ASZ * sizeof(unsigned short));
        unsigned short *hb = (unsigned short *)malloc(BSZ * sizeof(unsigned short));
        if (!ha || !hb) {
            fprintf(stderr, "host malloc failed at shape M=%d\n", M);
            snprintf(res[si].note, sizeof(res[si].note), "host malloc failed at M=%d", M);
            if (ha) free(ha);
            if (hb) free(hb);
            continue;
        }
        for (size_t i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
        for (size_t i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

        CUdeviceptr da = 0, db = 0, dc = 0;
        CUresult e_a = cuMemAlloc(&da, ASZ * sizeof(unsigned short));
        CUresult e_b = cuMemAlloc(&db, BSZ * sizeof(unsigned short));
        CUresult e_c = cuMemAlloc(&dc, CSZ * sizeof(float));
        if (e_a != CUDA_SUCCESS || e_b != CUDA_SUCCESS || e_c != CUDA_SUCCESS) {
            fprintf(stderr, "cuMemAlloc failed at shape M=%d (e_a=%d e_b=%d e_c=%d) -- treating as OOM\n",
                    M, (int)e_a, (int)e_b, (int)e_c);
            snprintf(res[si].note, sizeof(res[si].note),
                     "cuMemAlloc OOM at M=%d (needed %.2f MB)", M, (double)bytes_needed / 1048576.0);
            if (da) cuMemFree(da);
            if (db) cuMemFree(db);
            if (dc) cuMemFree(dc);
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

        printf("[M=%4d] cuBLAS HGEMM             median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f\n",
               M, res[si].cublas.median, res[si].cublas.std, res[si].cublas.min, res[si].cublas.max,
               res[si].cublas_tflops);

        if (load_ok[si]) {
            float maxabs = 0.0f, maxrel = 0.0f;
            sanity_check(handle, fns[si], M, N, K, da, db, dc, &maxabs, &maxrel);
            res[si].hexa_maxabs = maxabs;
            res[si].hexa_maxrel = maxrel;

            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            if (run_hexa(fns[si], M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
                fprintf(stderr, "hexa-P6H run failed at shape %d\n", M);
                res[si].hexa_valid = 0;
                snprintf(res[si].note, sizeof(res[si].note),
                    "hexa launch failure at M=%d", M);
            } else {
                res[si].hexa_valid = 1;
                res[si].hexa = stats_compute(times, REPS);
                res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
                res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
                printf("[M=%4d] hexa-P6H 6stage+Hilbert median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f  ratio=%.4f  maxabs=%.4f  maxrel=%.4f  CTAs=%d  regs=%d  shmem=%d\n",
                       M, res[si].hexa.median, res[si].hexa.std, res[si].hexa.min, res[si].hexa.max,
                       res[si].hexa_tflops, res[si].ratio, res[si].hexa_maxabs, res[si].hexa_maxrel,
                       res[si].num_ctas, res[si].regs_per_thd, res[si].shmem_bytes);
            }
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note), "%s", load_err[si]);
            printf("[M=%4d] hexa-P6H 6stage+Hilbert SKIPPED -- %s\n", M, res[si].note);
        }

        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    /* ===== Baselines for the combined-kernel comparison ===== *
     * Order matches shapes[] = {256, 384, 512, 4096, 6144, 8192}.
     * SMALL regime baselines = N121 PZ 6-stage (measured 256/384/512 in N121).
     * LARGE regime baselines = N149 PHILB Hilbert (measured 4096/6144/8192 in N149)
     *                          + N134 super-block (Pattern A) for the cliff.
     * "-1" means that shape was not measured in that prior fire. */
    double n121_6stage_tflops[N_SHAPES] = { 5.825422, 15.798857, 21.760332, -1.0, -1.0, -1.0 };
    double n121_6stage_ratio[N_SHAPES]  = { 1.161111,  0.979911,  0.876783, -1.0, -1.0, -1.0 };
    /* N149 PHILB Hilbert (2-stage) large-shape baselines (from N149 result.json). */
    double n149_hilbert_tflops[N_SHAPES] = { -1.0, -1.0, -1.0, 56.991156, 58.486211, 59.477660 };
    double n149_hilbert_ratio[N_SHAPES]  = { -1.0, -1.0, -1.0,  0.821263,  0.833949,  0.847302 };

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-P6H-hexa-hgemm-6stage-plus-hilbert-COMBINE\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
    fprintf(rj, "  \"host\": \"%s\",\n", getenv("PY_HOST") ? getenv("PY_HOST") : "ubu-1");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"variant\": \"P6H -- COMBINE N121 PZ (4-warp 64x64, 6-stage cp.async pipeline, 5 in-flight, wait_group(4), 24576 B shmem) + N149 PHILB (Hilbert-curve d2xy CTA-swizzle). Launch grid p x p, p=next_pow2(side); d=ctaid.y*p+ctaid.x; (sw_x,sw_y)=hilbert_d2xy(p,d) unrolled log2(p) rounds; early-return padding CTAs. Pipeline body byte-identical to N121; only ctaid->tile mapping changes.\",\n");
    fprintf(rj, "  \"hexa_kernel_family\": \"sgemm_4warp_6stage_hilbert_SxS_grid\",\n");
    fprintf(rj, "  \"cublas_math_mode\": \"CUBLAS_TENSOR_OP_MATH (HGEMM via cublasGemmEx)\",\n");
    fprintf(rj, "  \"hypothesis\": \"N121 6-stage wins small shapes (M=256 ratio 1.1611) but hurts large M (occupancy 8->4 CTAs/SM). N149 Hilbert wins large shapes (M=8192 ratio 0.847, cliff flat). Combined kernel = best small (M=256 >= 1.16) AND best large (M=8192 >= 0.847)? Or do 24576 B shmem + Hilbert prologue compound occupancy+register cost (useful negative)?\",\n");
    fprintf(rj, "  \"stack_inputs\": {\n");
    fprintf(rj, "    \"N121_PZ\":    \"rfc067_pZ_hexa_sgemm_4warp_6stage_2026_05_21: 6-stage pipeline. M=256 5.825/1.1611, M=384 15.799/0.9799, M=512 21.760/0.8768, M=1536 50.455/0.7596 (-2.32%% vs N107)\",\n");
    fprintf(rj, "    \"N149_PHILB\": \"rfc067_philb_hexa_sgemm_hilbert_swizzle_2026_05_22: Hilbert d2xy CTA-swizzle (2-stage). M=8192 ratio 0.847 (cliff flattened). 8192 B shmem.\",\n");
    fprintf(rj, "    \"N107_2stage\": \"rfc067_pY: 4-warp 64x64 2-stage. M=1536 ratio 0.777.\"\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"launch_config\": {\n");
    fprintf(rj, "    \"threads_per_block\": 128,\n");
    fprintf(rj, "    \"warps_per_block\": 4,\n");
    fprintf(rj, "    \"output_tile_M\": 64,\n");
    fprintf(rj, "    \"output_tile_N\": 64,\n");
    fprintf(rj, "    \"per_warp_M\": 32,\n");
    fprintf(rj, "    \"per_warp_N\": 32,\n");
    fprintf(rj, "    \"mma_per_warp_per_kstep\": 8,\n");
    fprintf(rj, "    \"acc_f32_per_lane\": 32,\n");
    fprintf(rj, "    \"pipeline_stages\": 6,\n");
    fprintf(rj, "    \"pipeline_in_flight\": 5,\n");
    fprintf(rj, "    \"slab_bytes\": 2048,\n");
    fprintf(rj, "    \"shmem_bytes_per_cta\": 24576,\n");
    fprintf(rj, "    \"cta_swizzle\": \"Hilbert space-filling curve d2xy (N149 PHILB)\"\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"l2_size_mb\": 32,\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
        unsigned int side = (unsigned int)(res[si].M / 64);
        unsigned int p = next_pow2_u(side);
        int is_small = (res[si].M <= 512);
        double base_tflops = is_small ? n121_6stage_tflops[si] : n149_hilbert_tflops[si];
        double base_ratio  = is_small ? n121_6stage_ratio[si]  : n149_hilbert_ratio[si];
        double pct_over_base = (res[si].hexa_valid && base_tflops > 0.0)
            ? 100.0 * (res[si].hexa_tflops - base_tflops) / base_tflops : 0.0;
        double ratio_delta_base = (res[si].hexa_valid && base_ratio > 0.0)
            ? (res[si].ratio - base_ratio) : 0.0;
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"regime\": \"%s\",\n", is_small ? "small_N121_6stage_regime" : "large_N149_hilbert_regime");
        fprintf(rj, "      \"vram_bytes_allocated\":   %zu,\n", res[si].bytes_allocated);
        fprintf(rj, "      \"hilbert_p\":              %u,\n", p);
        fprintf(rj, "      \"grid_side\":              %u,\n", side);
        fprintf(rj, "      \"ctas_launched\":          %u,\n", p * p);
        fprintf(rj, "      \"ctas_real\":              %u,\n", side * side);
        fprintf(rj, "      \"ctas_padding_return\":    %u,\n", p * p - side * side);
        fprintf(rj, "      \"cublas_hgemm_tflops\":     %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_hgemm_median_ms\":  %.6f,\n", res[si].cublas.median);
        fprintf(rj, "      \"cublas_hgemm_std_ms\":     %.6f,\n", res[si].cublas.std);
        fprintf(rj, "      \"cublas_hgemm_min_ms\":     %.6f,\n", res[si].cublas.min);
        fprintf(rj, "      \"cublas_hgemm_max_ms\":     %.6f,\n", res[si].cublas.max);
        if (base_tflops > 0.0) {
            fprintf(rj, "      \"baseline_tflops\":         %.6f,\n", base_tflops);
            fprintf(rj, "      \"baseline_ratio\":          %.6f,\n", base_ratio);
        } else {
            fprintf(rj, "      \"baseline_tflops\":         null,\n");
            fprintf(rj, "      \"baseline_ratio\":          null,\n");
        }
        fprintf(rj, "      \"baseline_source\":         \"%s\",\n", is_small ? "N121_PZ_6stage" : "N149_PHILB_hilbert");
        fprintf(rj, "      \"p6h_regs_per_thd\":        %d,\n", res[si].regs_per_thd);
        fprintf(rj, "      \"p6h_shmem_bytes\":         %d,\n", res[si].shmem_bytes);
        if (res[si].hexa_valid) {
            fprintf(rj, "      \"hexa_p6h_tflops\":         %.6f,\n", res[si].hexa_tflops);
            fprintf(rj, "      \"hexa_p6h_median_ms\":      %.6f,\n", res[si].hexa.median);
            fprintf(rj, "      \"hexa_p6h_std_ms\":         %.6f,\n", res[si].hexa.std);
            fprintf(rj, "      \"hexa_p6h_min_ms\":         %.6f,\n", res[si].hexa.min);
            fprintf(rj, "      \"hexa_p6h_max_ms\":         %.6f,\n", res[si].hexa.max);
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":   %.6f,\n", res[si].hexa_maxabs);
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":   %.6f,\n", res[si].hexa_maxrel);
            fprintf(rj, "      \"ratio_vs_cublas\":         %.6f,\n", res[si].ratio);
            fprintf(rj, "      \"bit_exact\":               %s,\n", (res[si].hexa_maxabs == 0.0f) ? "true" : "false");
            fprintf(rj, "      \"pct_over_baseline\":       %.4f,\n", pct_over_base);
            fprintf(rj, "      \"ratio_delta_vs_baseline\": %.6f,\n", ratio_delta_base);
            fprintf(rj, "      \"note\":                    null\n");
        } else {
            fprintf(rj, "      \"hexa_p6h_tflops\":         null,\n");
            fprintf(rj, "      \"hexa_p6h_median_ms\":      null,\n");
            fprintf(rj, "      \"hexa_p6h_std_ms\":         null,\n");
            fprintf(rj, "      \"hexa_p6h_min_ms\":         null,\n");
            fprintf(rj, "      \"hexa_p6h_max_ms\":         null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":   null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":   null,\n");
            fprintf(rj, "      \"ratio_vs_cublas\":         null,\n");
            fprintf(rj, "      \"bit_exact\":               null,\n");
            fprintf(rj, "      \"pct_over_baseline\":       null,\n");
            fprintf(rj, "      \"ratio_delta_vs_baseline\": null,\n");
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
