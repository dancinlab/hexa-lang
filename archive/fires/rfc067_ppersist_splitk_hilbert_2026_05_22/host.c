/* RFC 067 PPSH -- Persistent CTA + Split-K + Hilbert visitation (2026-05-22)
 *
 * Goal: combine N149 PHILB Hilbert visitation (best @ cliff, ratio 0.847 @ M=8192)
 *       with persistent CTAs (P=48, one per SM on RTX 5070) and split-K (G=4 groups,
 *       atomic-add reduction over K). Hypothesis: at large M the L2-locality + parallel
 *       K dimension wins over GPU scheduler + Hilbert-only.
 *
 * Grid: (P*G, 1, 1) = (192, 1, 1) -- 48 SMs * 4 K-splits.
 *   ctaid.x / P -> k_group  in [0, G)
 *   ctaid.x % P -> cta_in_g in [0, P)  -- walks Hilbert range [d_start, d_end).
 *
 * Sweep:
 *   M = 4096  (N149 PHILB ratio 0.821)
 *   M = 6144  (N149 PHILB ratio 0.834)
 *   M = 8192  (N149 PHILB ratio 0.847)
 *
 * Falsifier F-RFC067-HEXA-PERSIST-SPLITK-HILBERT:
 *   - Numeric: per-element maxabs vs cuBLAS HGEMM. Split-K atomic-add reorders
 *     accumulation; NOT bit-exact. Tolerance: max_abs <= 4 ULP relative to cuBLAS
 *     value scale.  Recorded as `split_k_ulp_relative_max`.
 *   - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync.
 *   - Headline: per-shape ratio vs cuBLAS HGEMM; vs N149 PHILB Hilbert.
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 * Run:
 *   ./host sgemm_ppsh_4096x4096_grid.ptx \
 *          sgemm_ppsh_6144x6144_grid.ptx \
 *          sgemm_ppsh_8192x8192_grid.ptx
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

#define NUM_K_SPLITS    4
#define NUM_PERSISTENT  48

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

static int run_hexa_ppsh(CUfunction f_hexa,
                         int M, int N, int K,
                         CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                         int warmup, int reps,
                         double *out_times_ms)
{
    /* k_tiles_per_group = (K / 16) / G */
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    const int K_TILES_PER_GROUP = K_TILES_TOTAL / NUM_K_SPLITS;
    unsigned long long k_arg = (unsigned long long)K_TILES_PER_GROUP;

    void *kargs[4] = { &da, &db, &dc, &k_arg };
    const size_t CSZ_BYTES = (size_t)M * (size_t)N * sizeof(float);

    /* Grid: (P*G, 1, 1) */
    unsigned int grid_x = (unsigned int)(NUM_PERSISTENT * NUM_K_SPLITS);

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    /* Warmup: each iter must memset C=0 (atomic accumulation) */
    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuMemsetD8(dc, 0, CSZ_BYTES));
        CHECK_CU(cuLaunchKernel(f_hexa,
            grid_x, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    /* Measurement: time covers cuMemsetD8 + launch (this is the honest end-to-end cost
       for a split-K kernel; cuBLAS HGEMM does NOT need an external memset since it
       writes-not-adds). We report both `with_memset` and `kernel_only` timings. */
    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuMemsetD8(dc, 0, CSZ_BYTES));
        CHECK_CU(cuLaunchKernel(f_hexa,
            grid_x, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
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

static int run_hexa_ppsh_kernelonly(CUfunction f_hexa,
                                    int M, int N, int K,
                                    CUdeviceptr da, CUdeviceptr db, CUdeviceptr dc,
                                    int warmup, int reps,
                                    double *out_times_ms)
{
    /* Like run_hexa_ppsh but EXCLUDES the cuMemsetD8 from the timed region.
       The memset still happens (between launches we still need C=0) but is
       NOT counted against the kernel TFLOPS. Useful to isolate atomic-add cost. */
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    const int K_TILES_PER_GROUP = K_TILES_TOTAL / NUM_K_SPLITS;
    unsigned long long k_arg = (unsigned long long)K_TILES_PER_GROUP;
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    const size_t CSZ_BYTES = (size_t)M * (size_t)N * sizeof(float);
    unsigned int grid_x = (unsigned int)(NUM_PERSISTENT * NUM_K_SPLITS);

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuMemsetD8(dc, 0, CSZ_BYTES));
        CHECK_CU(cuLaunchKernel(f_hexa,
            grid_x, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_CU(cuMemsetD8(dc, 0, CSZ_BYTES));
        CHECK_CU(cuCtxSynchronize());
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa,
            grid_x, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
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
                        float *out_maxabs, float *out_maxrel,
                        double *out_ulp_relative)
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

    /* Hexa side */
    CHECK_CU(cuMemsetD8(dc, 0, csz_bytes));
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    const int K_TILES_PER_GROUP = K_TILES_TOTAL / NUM_K_SPLITS;
    unsigned long long k_arg = (unsigned long long)K_TILES_PER_GROUP;
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    unsigned int grid_x = (unsigned int)(NUM_PERSISTENT * NUM_K_SPLITS);
    CHECK_CU(cuLaunchKernel(f_hexa, grid_x, 1, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    float *hexa_c = (float *)malloc(snap_n * sizeof(float));
    CHECK_CU(cuMemcpyDtoH(hexa_c, dc, snap_n * sizeof(float)));

    float maxabs = 0.0f;
    float maxrel = 0.0f;
    double max_ulp_rel = 0.0;
    for (size_t i = 0; i < snap_n; ++i) {
        float d = fabsf(cublas_c[i] - hexa_c[i]);
        if (d > maxabs) maxabs = d;
        float scale = fabsf(cublas_c[i]);
        if (scale > 1e-3f) {
            float r = d / scale;
            if (r > maxrel) maxrel = r;
            /* ULP at this scale: nextafterf(scale, +inf) - scale ~= scale * 2^-23 */
            float ulp = ldexpf(scale, -23);
            double ulp_rel = (double)d / (double)ulp;
            if (ulp_rel > max_ulp_rel) max_ulp_rel = ulp_rel;
        }
    }
    free(cublas_c); free(hexa_c);
    *out_maxabs = maxabs;
    *out_maxrel = maxrel;
    *out_ulp_relative = max_ulp_rel;
    return 1;
}

#define N_SHAPES 3

int main(int argc, char **argv) {
    int shapes[N_SHAPES] = { 4096, 6144, 8192 };

    if (argc < 1 + N_SHAPES) {
        fprintf(stderr,
            "usage: %s sgemm_ppsh_4096x4096_grid.ptx sgemm_ppsh_6144x6144_grid.ptx sgemm_ppsh_8192x8192_grid.ptx\n",
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
    int num_sms = 0;
    CHECK_CU(cuDeviceGetAttribute(&num_sms, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, dev));
    printf("Device: %s sm_%d%d (num_SMs=%d)\n", dev_name, sm_major, sm_minor, num_sms);
    printf("CUDA driver=%d runtime=%d\n", driver_ver, runtime_ver);
    printf("Persistent slots (kernel-baked) = %d, K splits = %d, grid_x = %d\n",
           NUM_PERSISTENT, NUM_K_SPLITS, NUM_PERSISTENT * NUM_K_SPLITS);
    if (num_sms != NUM_PERSISTENT) {
        printf("WARNING: device num_SMs=%d != kernel-baked NUM_PERSISTENT=%d. "
               "Persistent slot count is a kernel constant; tiles_per_cta may be off.\n",
               num_sms, NUM_PERSISTENT);
    }

    CUmodule   mods[N_SHAPES];
    CUfunction fns[N_SHAPES];
    int        load_ok[N_SHAPES];
    char       load_err[N_SHAPES][200];
    char       load_info[N_SHAPES][8192];
    FILE *fp_info = fopen("ptxas_info.log", "w");
    for (int si = 0; si < N_SHAPES; ++si) {
        char entry[64];
        snprintf(entry, sizeof(entry), "sgemm_ppsh_%dx%d_grid", shapes[si], shapes[si]);
        if (load_ptx_kernel(argv[1 + si], entry, &mods[si], &fns[si],
                            load_info[si], sizeof(load_info[si])) == 0) {
            load_ok[si] = 1; load_err[si][0] = 0;
            printf("loaded hexa-PPSH PTX shape %d (%s)\n", shapes[si], entry);
            if (fp_info) {
                fprintf(fp_info, "=== shape %d (%s) ===\n%s\n\n",
                        shapes[si], entry, load_info[si]);
            }
        } else {
            load_ok[si] = 0;
            snprintf(load_err[si], sizeof(load_err[si]),
                "PTX load/lookup failed for %s", argv[1 + si]);
            printf("FAILED hexa-PPSH PTX shape %d -- skipping\n", shapes[si]);
        }

        if (load_ok[si]) {
            int reg_per_thd = 0, shmem_bytes = 0, max_thd = 0;
            cuFuncGetAttribute(&reg_per_thd, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            cuFuncGetAttribute(&shmem_bytes, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[si]);
            cuFuncGetAttribute(&max_thd, CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK, fns[si]);
            printf("  shape %d: regs/thd=%d, shmem=%d B, max_thd=%d\n",
                   shapes[si], reg_per_thd, shmem_bytes, max_thd);
            if (fp_info) {
                fprintf(fp_info, "shape %d cuFuncGetAttribute: regs/thd=%d, shmem=%d B, max_thd=%d\n\n",
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
        double hexa_ulp_relative;
        stat_t hexa;            /* with memset (end-to-end) */
        double hexa_tflops;     /* with memset */
        stat_t hexa_kernel_only;
        double hexa_tflops_kernel_only;
        double ratio;           /* vs cuBLAS, with-memset (honest end-to-end) */
        double ratio_kernel_only;
        int    grid_x;
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
        res[si].grid_x = NUM_PERSISTENT * NUM_K_SPLITS;
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
            fprintf(stderr, "cuMemAlloc OOM at M=%d (e_a=%d e_b=%d e_c=%d)\n",
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

        printf("[M=%4d] cuBLAS HGEMM             median=%.6f ms  std=%.6f  TFLOPS=%8.4f\n",
               M, res[si].cublas.median, res[si].cublas.std, res[si].cublas_tflops);

        if (load_ok[si]) {
            float maxabs = 0.0f, maxrel = 0.0f;
            double ulp_rel = 0.0;
            sanity_check(handle, fns[si], M, N, K, da, db, dc, &maxabs, &maxrel, &ulp_rel);
            res[si].hexa_maxabs = maxabs;
            res[si].hexa_maxrel = maxrel;
            res[si].hexa_ulp_relative = ulp_rel;

            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            if (run_hexa_ppsh(fns[si], M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
                fprintf(stderr, "hexa-PPSH (with memset) run failed at shape %d\n", M);
                res[si].hexa_valid = 0;
                snprintf(res[si].note, sizeof(res[si].note),
                    "hexa with-memset launch failure at M=%d", M);
            } else {
                res[si].hexa_valid = 1;
                res[si].hexa = stats_compute(times, REPS);
                res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
                res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
                printf("[M=%4d] hexa-PPSH (with memset)  median=%.6f ms  std=%.6f  TFLOPS=%8.4f  ratio=%.4f  maxabs=%.4f  maxrel=%.4f  ulp_rel=%.2f  grid_x=%d  regs=%d\n",
                       M, res[si].hexa.median, res[si].hexa.std,
                       res[si].hexa_tflops, res[si].ratio,
                       res[si].hexa_maxabs, res[si].hexa_maxrel, res[si].hexa_ulp_relative,
                       res[si].grid_x, res[si].regs_per_thd);

                /* kernel-only timing (memset excluded -- isolates atomic-add cost) */
                if (run_hexa_ppsh_kernelonly(fns[si], M, N, K, da, db, dc, WARMUP, REPS, times) == 0) {
                    res[si].hexa_kernel_only = stats_compute(times, REPS);
                    res[si].hexa_tflops_kernel_only = flops / (res[si].hexa_kernel_only.median / 1000.0) / 1e12;
                    res[si].ratio_kernel_only = res[si].hexa_tflops_kernel_only / res[si].cublas_tflops;
                    printf("[M=%4d] hexa-PPSH (kernel-only)  median=%.6f ms  std=%.6f  TFLOPS=%8.4f  ratio_kernel_only=%.4f\n",
                           M, res[si].hexa_kernel_only.median, res[si].hexa_kernel_only.std,
                           res[si].hexa_tflops_kernel_only, res[si].ratio_kernel_only);
                }
            }
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note), "%s", load_err[si]);
            printf("[M=%4d] hexa-PPSH SKIPPED -- %s\n", M, res[si].note);
        }

        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    /* N149 PHILB (Hilbert-only) baselines.
       shapes: 4096, 6144, 8192  (5120 omitted in this fire because 12GB VRAM tight). */
    double n149_hexa_tflops[N_SHAPES]   = { 56.991156, 58.486211, 59.477660 };
    double n149_cublas_tflops[N_SHAPES] = { 69.394548, 70.131669, 70.196552 };
    double n149_ratio[N_SHAPES]         = {  0.821263,  0.833949,  0.847302 };

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PPSH-hexa-hgemm-persistent-splitk-hilbert\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
    fprintf(rj, "  \"host\": \"%s\",\n", getenv("PY_HOST") ? getenv("PY_HOST") : "ubu-1");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"num_SMs\": %d,\n", num_sms);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter); with-memset and kernel-only variants\",\n");
    fprintf(rj, "  \"variant\": \"PPSH -- Persistent CTA (P=%d, one per SM) + Split-K (G=%d, atom.global.add.f32 reduce) + Hilbert visitation (contiguous Hilbert range per persistent CTA). 4-warp 64x64 body byte-identical to N149 PHILB. K-split: each k_group operates on K/G slice; atom-add to global C (C=0 memset between launches).\",\n", NUM_PERSISTENT, NUM_K_SPLITS);
    fprintf(rj, "  \"hexa_kernel_family\": \"sgemm_ppsh_SxS_grid\",\n");
    fprintf(rj, "  \"cublas_math_mode\": \"CUBLAS_TENSOR_OP_MATH (HGEMM via cublasGemmEx)\",\n");
    fprintf(rj, "  \"persistent_slots\": %d,\n", NUM_PERSISTENT);
    fprintf(rj, "  \"split_k_groups\": %d,\n", NUM_K_SPLITS);
    fprintf(rj, "  \"grid_x_total\": %d,\n", NUM_PERSISTENT * NUM_K_SPLITS);
    fprintf(rj, "  \"l2_size_mb\": 32,\n");
    fprintf(rj, "  \"split_k_tolerance\": \"atomic-add re-orders accumulation across G partial sums; not bit-exact. Recorded as hexa_ulp_relative (= |Delta| / ULP(cublas_value)). Accept ulp_rel <= 256 (i.e., relative error ~3e-5).\",\n");
    fprintf(rj, "  \"stack_inputs\": {\n");
    fprintf(rj, "    \"N149_PHILB\": \"rfc067_philb_hexa_sgemm_hilbert_swizzle_2026_05_22 Hilbert-only: M=4096 0.821, M=6144 0.834, M=8192 0.847 (best @ cliff)\",\n");
    fprintf(rj, "    \"N94_PV\":    \"rfc067_pV_hexa_sgemm_persistent_2026_05_21 persistent-only (N77 body): -0.39%% on square shapes, scheduler already efficient at small M\"\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"hypothesis\": \"At large M (4096+) L2 working set spans 32 MB; Hilbert visitation + persistent CTA (1 CTA/SM walking contiguous Hilbert range) gives BOTH amortised dispatch AND tight L2 reuse. Split-K (G=4) provides parallel work over K for atomic reduction. Useful negative if atomic cost or losing 8 CTAs/SM exceeds these gains.\",\n");
    fprintf(rj, "  \"launch_config\": {\n");
    fprintf(rj, "    \"threads_per_block\": 128,\n");
    fprintf(rj, "    \"warps_per_block\": 4,\n");
    fprintf(rj, "    \"output_tile_M\": 64,\n");
    fprintf(rj, "    \"output_tile_N\": 64,\n");
    fprintf(rj, "    \"per_warp_M\": 32,\n");
    fprintf(rj, "    \"per_warp_N\": 32,\n");
    fprintf(rj, "    \"mma_per_warp_per_kstep\": 8,\n");
    fprintf(rj, "    \"acc_f32_per_lane\": 32,\n");
    fprintf(rj, "    \"shmem_bytes_per_cta\": 8192,\n");
    fprintf(rj, "    \"persistent_slots_P\": %d,\n", NUM_PERSISTENT);
    fprintf(rj, "    \"split_k_groups_G\": %d,\n", NUM_K_SPLITS);
    fprintf(rj, "    \"grid_total\": %d,\n", NUM_PERSISTENT * NUM_K_SPLITS);
    fprintf(rj, "    \"atomic_adds_per_cta_per_tile\": 32\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
        double pct_over_n149 = (res[si].hexa_valid)
            ? 100.0 * (res[si].hexa_tflops - n149_hexa_tflops[si]) / n149_hexa_tflops[si]
            : 0.0;
        double ratio_delta_n149 = (res[si].hexa_valid)
            ? (res[si].ratio - n149_ratio[si])
            : 0.0;
        int beats_n149 = (res[si].hexa_valid && res[si].hexa_tflops > n149_hexa_tflops[si]);
        double overhead_pct = 0.0;
        if (res[si].hexa_valid && res[si].hexa_tflops_kernel_only > 0.0) {
            /* memset overhead = (with - kernel_only) / kernel_only * 100 (in ms domain) */
            overhead_pct = 100.0 * (res[si].hexa.median - res[si].hexa_kernel_only.median)
                                / res[si].hexa_kernel_only.median;
        }

        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"vram_bytes_allocated\":   %zu,\n", res[si].bytes_allocated);
        fprintf(rj, "      \"grid_x_launched\":        %d,\n", res[si].grid_x);
        fprintf(rj, "      \"tiles_per_cta_approx\":   %d,\n",
                ((res[si].M / 64) * (res[si].M / 64) + NUM_PERSISTENT - 1) / NUM_PERSISTENT);
        fprintf(rj, "      \"k_tiles_per_group\":      %d,\n", (res[si].K / 16) / NUM_K_SPLITS);
        fprintf(rj, "      \"cublas_hgemm_tflops\":     %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_hgemm_median_ms\":  %.6f,\n", res[si].cublas.median);
        fprintf(rj, "      \"cublas_hgemm_std_ms\":     %.6f,\n", res[si].cublas.std);
        fprintf(rj, "      \"cublas_hgemm_min_ms\":     %.6f,\n", res[si].cublas.min);
        fprintf(rj, "      \"cublas_hgemm_max_ms\":     %.6f,\n", res[si].cublas.max);
        fprintf(rj, "      \"n149_philb_cublas_tflops\": %.6f,\n", n149_cublas_tflops[si]);
        fprintf(rj, "      \"n149_philb_hexa_tflops\":   %.6f,\n", n149_hexa_tflops[si]);
        fprintf(rj, "      \"n149_philb_ratio\":         %.6f,\n", n149_ratio[si]);
        fprintf(rj, "      \"ppsh_regs_per_thd\":       %d,\n", res[si].regs_per_thd);
        if (res[si].hexa_valid) {
            fprintf(rj, "      \"hexa_ppsh_tflops\":               %.6f,\n", res[si].hexa_tflops);
            fprintf(rj, "      \"hexa_ppsh_median_ms\":            %.6f,\n", res[si].hexa.median);
            fprintf(rj, "      \"hexa_ppsh_std_ms\":               %.6f,\n", res[si].hexa.std);
            fprintf(rj, "      \"hexa_ppsh_min_ms\":               %.6f,\n", res[si].hexa.min);
            fprintf(rj, "      \"hexa_ppsh_max_ms\":               %.6f,\n", res[si].hexa.max);
            fprintf(rj, "      \"hexa_ppsh_kernel_only_tflops\":   %.6f,\n", res[si].hexa_tflops_kernel_only);
            fprintf(rj, "      \"hexa_ppsh_kernel_only_median_ms\":%.6f,\n", res[si].hexa_kernel_only.median);
            fprintf(rj, "      \"hexa_memset_overhead_pct\":       %.4f,\n", overhead_pct);
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":          %.6f,\n", res[si].hexa_maxabs);
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":          %.6e,\n", res[si].hexa_maxrel);
            fprintf(rj, "      \"hexa_vs_cublas_ulp_relative\":    %.4f,\n", res[si].hexa_ulp_relative);
            fprintf(rj, "      \"ratio_vs_cublas\":                %.6f,\n", res[si].ratio);
            fprintf(rj, "      \"ratio_vs_cublas_kernel_only\":    %.6f,\n", res[si].ratio_kernel_only);
            fprintf(rj, "      \"pct_over_n149_philb\":            %.4f,\n", pct_over_n149);
            fprintf(rj, "      \"ratio_delta_vs_n149\":            %.6f,\n", ratio_delta_n149);
            fprintf(rj, "      \"beats_n149_hilbert\":             %s,\n", beats_n149 ? "true" : "false");
            fprintf(rj, "      \"note\":                          null\n");
        } else {
            fprintf(rj, "      \"hexa_ppsh_tflops\":               null,\n");
            fprintf(rj, "      \"hexa_ppsh_median_ms\":            null,\n");
            fprintf(rj, "      \"hexa_ppsh_std_ms\":               null,\n");
            fprintf(rj, "      \"hexa_ppsh_min_ms\":               null,\n");
            fprintf(rj, "      \"hexa_ppsh_max_ms\":               null,\n");
            fprintf(rj, "      \"hexa_ppsh_kernel_only_tflops\":   null,\n");
            fprintf(rj, "      \"hexa_ppsh_kernel_only_median_ms\":null,\n");
            fprintf(rj, "      \"hexa_memset_overhead_pct\":       null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":          null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":          null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_ulp_relative\":    null,\n");
            fprintf(rj, "      \"ratio_vs_cublas\":                null,\n");
            fprintf(rj, "      \"ratio_vs_cublas_kernel_only\":    null,\n");
            fprintf(rj, "      \"pct_over_n149_philb\":            null,\n");
            fprintf(rj, "      \"ratio_delta_vs_n149\":            null,\n");
            fprintf(rj, "      \"beats_n149_hilbert\":             null,\n");
            fprintf(rj, "      \"note\":                          \"%s\"\n", res[si].note);
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
