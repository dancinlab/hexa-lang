/* RFC 067 PT64x128 -- 64x128 output tile, 16 warps (512 thd) + Hilbert CTA-swizzle (N149 PHILB) -- large-M sweep (2026-05-22)
 *
 * Middle-occupancy tile between N107 (64x64, 4-warp, 128 thd, ~8 CTAs/SM) and N151 (128x128,
 * 32-warp, 1024 thd, 1 CTA/SM occupancy collapse). N151's recommendation after the 128x128
 * collapse: "64x128/128x64 16-warp at ~32 regs/512 thd restores occupancy while giving more
 * output per CTA than 64x64." This fire tests whether the middle-occupancy tile (512 thd ->
 * ~3-4 CTAs/SM) beats N149's 64x64+Hilbert (M=8192 ratio 0.847) at large M.
 *
 * Launch grid: p x p where p = next_pow2(max(gx, gy)), gx = N/128 (N tiles), gy = N/64 (M tiles).
 *   The grid is ASYMMETRIC (64-tall x 128-wide CTA tile). Kernel computes (sw_x,sw_y)=d2xy(p,d)
 *   from linear CTA id d = ctaid.y*p + ctaid.x, then EARLY-RETURNS padding CTAs
 *   (sw_x>=gx || sw_y>=gy). Bijective over the real gx x gy grid -> bit-exact.
 *     4096 -> gx=32 gy=64  -> p=64  (4096 launched, 2048 real, 2048 padding-return)
 *     5120 -> gx=40 gy=80  -> p=128 (16384 launched, 3200 real, 13184 padding-return)
 *     6144 -> gx=48 gy=96  -> p=128 (16384 launched, 4608 real, 11776 padding-return)
 *     8192 -> gx=64 gy=128 -> p=128 (16384 launched, 8192 real, 8192 padding-return)
 *
 * Sweep (same shapes as N149 / N151 for direct comparison):
 *   - M = 4096  (N149 64x64+Hilbert 56.99 / ratio 0.821)
 *   - M = 5120  (N149 64x64+Hilbert 57.69 / ratio 0.827)
 *   - M = 6144  (N149 64x64+Hilbert 58.49 / ratio 0.834)
 *   - M = 8192  (N149 64x64+Hilbert 59.48 / ratio 0.847 -- headline: does 64x128 beat it?)
 *
 * Falsifier F-RFC067-HEXA-SGEMM-TILE64x128-HILBERT:
 *   - Numeric: per-element maxabs vs cuBLAS HGEMM (must be 0.0 -- bit-exact)
 *   - Per-shape median TFLOPS over 200 reps (20 warmup), cuEvent sync each iter
 *   - regs/thd from cuFuncGetAttribute; CTAs/SM from min(2048/512, 65536/(regs*512), 100KB/shmem)
 *
 * Build:  nvcc -O2 -arch=sm_90 -o host host.c -lcuda -lcublas -lm
 * Run:    ./host sgemm_tile64x128_hilbert_4096x4096_grid.ptx \
 *                sgemm_tile64x128_hilbert_5120x5120_grid.ptx \
 *                sgemm_tile64x128_hilbert_6144x6144_grid.ptx \
 *                sgemm_tile64x128_hilbert_8192x8192_grid.ptx
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

#define THREADS_PER_BLOCK 512
#define WARPS_PER_BLOCK   16
#define SHMEM_PER_CTA     12288   /* A 4096 + B 8192 (double-buffered) */

/* Hilbert launch grid is p x p where p = next_pow2(max(gx, gy)). */
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

    /* PT64x128: launch p x p where p=next_pow2(max(gx,gy)), gx=N/128, gy=N/64 (asymmetric). */
    unsigned int gx = (unsigned int)(N / 128);
    unsigned int gy = (unsigned int)(M / 64);
    unsigned int p = next_pow2_u(gx > gy ? gx : gy);

    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa,
            p, p, 1, THREADS_PER_BLOCK, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    for (int i = 0; i < reps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(f_hexa,
            p, p, 1, THREADS_PER_BLOCK, 1, 1, 0, NULL, kargs, NULL));
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
    /* PT64x128: launch p x p (next_pow2 of max(gx,gy)); kernel d2xy + padding return. */
    unsigned int gx = (unsigned int)(N / 128);
    unsigned int gy = (unsigned int)(M / 64);
    unsigned int p = next_pow2_u(gx > gy ? gx : gy);
    CHECK_CU(cuLaunchKernel(f_hexa, p, p, 1, THREADS_PER_BLOCK, 1, 1, 0, NULL, kargs, NULL));
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

/* Theoretical CTAs/SM on RTX 5070 (sm_120): 48 KB+ shared / SM (use 100 KB cap), 2048 thd / SM,
 * 65536 regs / SM. The binding constraint among threads / regs / shmem. */
static int ctas_per_sm(int regs_per_thd, int shmem_bytes) {
    int by_thd = 2048 / THREADS_PER_BLOCK;                 /* 2048/512 = 4 */
    int by_reg = (regs_per_thd > 0)
                 ? 65536 / (regs_per_thd * THREADS_PER_BLOCK)
                 : by_thd;
    int by_shm = (shmem_bytes > 0) ? (102400 / shmem_bytes) : by_thd; /* 100 KB usable */
    int m = by_thd;
    if (by_reg < m) m = by_reg;
    if (by_shm < m) m = by_shm;
    if (m < 0) m = 0;
    return m;
}

#define N_SHAPES 4

int main(int argc, char **argv) {
    int shapes[N_SHAPES] = { 4096, 5120, 6144, 8192 };

    if (argc < 1 + N_SHAPES) {
        fprintf(stderr,
            "usage: %s sgemm_tile64x128_hilbert_4096x4096_grid.ptx ... 8192x8192_grid.ptx\n",
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
    int n_sm = 0;
    CHECK_CU(cuDeviceGetAttribute(&n_sm, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, dev));
    int driver_ver = 0, runtime_ver = 0;
    CHECK_CU(cuDriverGetVersion(&driver_ver));
    cudaRuntimeGetVersion(&runtime_ver);
    printf("Device: %s sm_%d%d (%d SMs)\n", dev_name, sm_major, sm_minor, n_sm);
    printf("CUDA driver=%d runtime=%d\n", driver_ver, runtime_ver);

    CUmodule   mods[N_SHAPES];
    CUfunction fns[N_SHAPES];
    int        load_ok[N_SHAPES];
    char       load_err[N_SHAPES][200];
    char       load_info[N_SHAPES][8192];
    int        reg_per_thd_arr[N_SHAPES];
    int        shmem_arr[N_SHAPES];
    int        occ_arr[N_SHAPES];
    memset(reg_per_thd_arr, 0, sizeof(reg_per_thd_arr));
    memset(shmem_arr, 0, sizeof(shmem_arr));
    memset(occ_arr, 0, sizeof(occ_arr));
    FILE *fp_info = fopen("ptxas_info.log", "w");
    for (int si = 0; si < N_SHAPES; ++si) {
        char entry[64];
        snprintf(entry, sizeof(entry), "sgemm_tile64x128_hilbert_%dx%d_grid", shapes[si], shapes[si]);
        if (load_ptx_kernel(argv[1 + si], entry, &mods[si], &fns[si],
                            load_info[si], sizeof(load_info[si])) == 0) {
            load_ok[si] = 1; load_err[si][0] = 0;
            printf("loaded hexa-PT64x128 PTX shape %d (%s)\n", shapes[si], entry);
            if (fp_info) {
                fprintf(fp_info, "=== shape %d (%s) ===\n%s\n\n",
                        shapes[si], entry, load_info[si]);
            }
        } else {
            load_ok[si] = 0;
            snprintf(load_err[si], sizeof(load_err[si]),
                "PTX load/lookup failed for %s", argv[1 + si]);
            printf("FAILED hexa-PT64x128 PTX shape %d -- skipping\n", shapes[si]);
        }

        if (load_ok[si]) {
            int reg_per_thd = 0, shmem_bytes = 0, max_thd = 0;
            cuFuncGetAttribute(&reg_per_thd, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            cuFuncGetAttribute(&shmem_bytes, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[si]);
            cuFuncGetAttribute(&max_thd, CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK, fns[si]);
            reg_per_thd_arr[si] = reg_per_thd;
            shmem_arr[si] = shmem_bytes;
            occ_arr[si] = ctas_per_sm(reg_per_thd, shmem_bytes);
            printf("  shape %d: regs/thd=%d, shmem=%d B, max_thd_per_block=%d, est_CTAs/SM=%d\n",
                   shapes[si], reg_per_thd, shmem_bytes, max_thd, occ_arr[si]);
            if (fp_info) {
                fprintf(fp_info, "shape %d cuFuncGetAttribute: regs/thd=%d, shmem=%d B, max_thd_per_block=%d, est_CTAs_per_SM=%d (min over thd %d, reg %d, shmem %d)\n\n",
                        shapes[si], reg_per_thd, shmem_bytes, max_thd, occ_arr[si],
                        2048 / THREADS_PER_BLOCK,
                        reg_per_thd > 0 ? 65536 / (reg_per_thd * THREADS_PER_BLOCK) : -1,
                        shmem_bytes > 0 ? 102400 / shmem_bytes : -1);
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
        int    ctas_per_sm;
        size_t bytes_allocated;
        char   note[256];
    } shape_result_t;

    shape_result_t res[N_SHAPES];
    memset(res, 0, sizeof(res));

    double *times = (double *)malloc(REPS * sizeof(double));

    for (int si = 0; si < N_SHAPES; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        res[si].M = M; res[si].N = N; res[si].K = K;
        res[si].num_ctas = (M / 64) * (N / 128);  /* 64x128-tile real CTA count */
        res[si].regs_per_thd = reg_per_thd_arr[si];
        res[si].shmem_bytes  = shmem_arr[si];
        res[si].ctas_per_sm  = occ_arr[si];

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

        printf("[M=%4d] cuBLAS HGEMM                    median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f\n",
               M, res[si].cublas.median, res[si].cublas.std, res[si].cublas.min, res[si].cublas.max,
               res[si].cublas_tflops);

        if (load_ok[si]) {
            float maxabs = 0.0f, maxrel = 0.0f;
            sanity_check(handle, fns[si], M, N, K, da, db, dc, &maxabs, &maxrel);
            res[si].hexa_maxabs = maxabs;
            res[si].hexa_maxrel = maxrel;

            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            if (run_hexa(fns[si], M, N, K, da, db, dc, WARMUP, REPS, times) != 0) {
                fprintf(stderr, "hexa-PT64x128 run failed at shape %d\n", M);
                res[si].hexa_valid = 0;
                snprintf(res[si].note, sizeof(res[si].note),
                    "hexa launch failure at M=%d", M);
            } else {
                res[si].hexa_valid = 1;
                res[si].hexa = stats_compute(times, REPS);
                res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
                res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
                printf("[M=%4d] hexa-PT64x128 64x128+Hilbert median=%.6f ms  std=%.6f  min=%.6f  max=%.6f  TFLOPS=%8.4f  ratio=%.4f  maxabs=%.4f  maxrel=%.4f  CTAs=%d  regs=%d  CTAs/SM=%d\n",
                       M, res[si].hexa.median, res[si].hexa.std, res[si].hexa.min, res[si].hexa.max,
                       res[si].hexa_tflops, res[si].ratio, res[si].hexa_maxabs, res[si].hexa_maxrel,
                       res[si].num_ctas, res[si].regs_per_thd, res[si].ctas_per_sm);
            }
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note), "%s", load_err[si]);
            printf("[M=%4d] hexa-PT64x128 SKIPPED -- %s\n", M, res[si].note);
        }

        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    /* N149 PHILB baselines: 4-warp 64x64 + Hilbert CTA-swizzle (Pattern B).
       Headline comparison: does 64x128 (middle occupancy) beat 64x64 + Hilbert?
       Per-shape order matches shapes[] = {4096, 5120, 6144, 8192}. From
       rfc067_philb_hexa_sgemm_hilbert_swizzle_2026_05_22/result.json. */
    double n149_hexa_tflops[N_SHAPES]   = { 56.991156, 57.687564, 58.486211, 59.477660 };
    double n149_cublas_tflops[N_SHAPES] = { 69.394548, 69.720889, 70.131669, 70.196552 };
    double n149_ratio[N_SHAPES]         = {  0.821263,  0.827407,  0.833949,  0.847302 };
    /* N151 PT128H 128x128 + Hilbert (occupancy-dead): per-shape from its result.json.
       M=8192 ratio 0.538 (occupancy collapse, -36% vs N149). */
    double n151_hexa_tflops[N_SHAPES]   = { 0.0, 0.0, 0.0, 0.0 };  /* filled by analysis.md from N151 result.json */

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-PT64x128-hexa-hgemm-tile64x128-hilbert\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
    fprintf(rj, "  \"host\": \"%s\",\n", getenv("PY_HOST") ? getenv("PY_HOST") : "ubu-1");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"sm_count\": %d,\n", n_sm);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"timing_method\": \"cudaEventRecord per-launch (sync each iter)\",\n");
    fprintf(rj, "  \"variant\": \"PT64x128 -- 64x128 output tile, 16 warps (512 thd/CTA, 16 f32 acc/lane, 4 mma.m16n8k16/warp/K-step). Warp grid 4x4 (m_tile=warp>>2 in [0,4), n_tile=warp&3 in [0,4)). MMA body byte-identical to N151 PT128H / N89 PS. + N149 PHILB Hilbert d2xy CTA-swizzle on an ASYMMETRIC grid gx=N/128 (N tiles) x gy=N/64 (M tiles). Launch p x p, p=next_pow2(max(gx,gy)); d=ctaid.y*p+ctaid.x; (sw_x,sw_y)=hilbert_d2xy(p,d) unrolled log2(p) rounds (no runtime loop); early-return padding CTAs (sw_x>=gx||sw_y>=gy). Shared-mem per slot: A=64x16 fp16 (2048 B), B=128x16 fp16 (4096 B), double-buffered = 12288 B/CTA.\",\n");
    fprintf(rj, "  \"hexa_kernel_family\": \"sgemm_tile64x128_hilbert_SxS_grid\",\n");
    fprintf(rj, "  \"cublas_math_mode\": \"CUBLAS_TENSOR_OP_MATH (HGEMM via cublasGemmEx)\",\n");
    fprintf(rj, "  \"swizzle_pattern\": \"Hilbert space-filling curve d2xy on an asymmetric grid (gx=N/128 N-tiles, gy=N/64 M-tiles). Launch p x p (p=next_pow2(max(gx,gy))), d2xy(p, ctaid.y*p+ctaid.x), drop padding tiles outside gx x gy. Bijective over real grid -> bit-exact. d2xy unrolled at gen time.\",\n");
    fprintf(rj, "  \"l2_size_mb\": 32,\n");
    fprintf(rj, "  \"stack_inputs\": {\n");
    fprintf(rj, "    \"N107_PY\":  \"4-warp 64x64 canonical: 51.65 TFLOPS @ M=1536 ratio 0.777, ~8 CTAs/SM (128 thd).\",\n");
    fprintf(rj, "    \"N149_PHILB\": \"rfc067_philb 64x64 + Hilbert: M=4096 0.821, M=5120 0.827, M=6144 0.834, M=8192 0.847 (best large-M ratio in RFC 067 SGEMM line). 64 regs, 128 thd.\",\n");
    fprintf(rj, "    \"N151_PT128H\": \"rfc067_pt128h 128x128 + Hilbert: 1 CTA/SM occupancy collapse, -33-36%% vs N149 (M=8192 ratio ~0.538). Recommendation: 64x128 16-warp ~32 regs/512 thd.\"\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"hypothesis\": \"N151's 128x128 tile collapsed to 1 CTA/SM (32 warps, 1024 thd). Its explicit recommendation: 64x128 16-warp 512 thd restores occupancy (~3-4 CTAs/SM, between N107's 8 and N151's 1) while giving 2x the output/CTA of 64x64. Two-sided: if 64x128 beats 64x64+Hilbert at large M, the occupancy-vs-output-per-CTA sweet spot is 512 thd and tile size beyond 64x64 helps at the right occupancy; if 64x128 matches 64x64, tile size beyond 64x64 doesn't help on RTX 5070 even at the right occupancy -- 64x64 4-warp is structurally optimal (strong structural finding).\",\n");
    fprintf(rj, "  \"launch_config\": {\n");
    fprintf(rj, "    \"threads_per_block\": 512,\n");
    fprintf(rj, "    \"warps_per_block\": 16,\n");
    fprintf(rj, "    \"output_tile_M\": 64,\n");
    fprintf(rj, "    \"output_tile_N\": 128,\n");
    fprintf(rj, "    \"per_warp_M\": 16,\n");
    fprintf(rj, "    \"per_warp_N\": 32,\n");
    fprintf(rj, "    \"mma_per_warp_per_kstep\": 4,\n");
    fprintf(rj, "    \"acc_f32_per_lane\": 16,\n");
    fprintf(rj, "    \"shmem_bytes_per_cta\": 12288\n");
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
        unsigned int gx = (unsigned int)(res[si].N / 128);
        unsigned int gy = (unsigned int)(res[si].M / 64);
        unsigned int p = next_pow2_u(gx > gy ? gx : gy);
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"vram_bytes_allocated\":   %zu,\n", res[si].bytes_allocated);
        fprintf(rj, "      \"hilbert_p\":              %u,\n", p);
        fprintf(rj, "      \"grid_gx_n_tiles\":        %u,\n", gx);
        fprintf(rj, "      \"grid_gy_m_tiles\":        %u,\n", gy);
        fprintf(rj, "      \"ctas_launched\":          %u,\n", p * p);
        fprintf(rj, "      \"ctas_real\":              %u,\n", gx * gy);
        fprintf(rj, "      \"ctas_padding_return\":    %u,\n", p * p - gx * gy);
        fprintf(rj, "      \"cublas_hgemm_tflops\":     %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_hgemm_median_ms\":  %.6f,\n", res[si].cublas.median);
        fprintf(rj, "      \"cublas_hgemm_std_ms\":     %.6f,\n", res[si].cublas.std);
        fprintf(rj, "      \"cublas_hgemm_min_ms\":     %.6f,\n", res[si].cublas.min);
        fprintf(rj, "      \"cublas_hgemm_max_ms\":     %.6f,\n", res[si].cublas.max);
        fprintf(rj, "      \"n149_hilbert64_cublas_tflops\": %.6f,\n", n149_cublas_tflops[si]);
        fprintf(rj, "      \"n149_hilbert64_hexa_tflops\":   %.6f,\n", n149_hexa_tflops[si]);
        fprintf(rj, "      \"n149_hilbert64_ratio\":         %.6f,\n", n149_ratio[si]);
        fprintf(rj, "      \"pt64x128_regs_per_thd\":    %d,\n", res[si].regs_per_thd);
        fprintf(rj, "      \"pt64x128_shmem_bytes\":     %d,\n", res[si].shmem_bytes);
        fprintf(rj, "      \"pt64x128_ctas_per_sm\":     %d,\n", res[si].ctas_per_sm);
        if (res[si].hexa_valid) {
            fprintf(rj, "      \"hexa_pt64x128_tflops\":     %.6f,\n", res[si].hexa_tflops);
            fprintf(rj, "      \"hexa_pt64x128_median_ms\":  %.6f,\n", res[si].hexa.median);
            fprintf(rj, "      \"hexa_pt64x128_mean_ms\":    %.6f,\n", res[si].hexa.mean);
            fprintf(rj, "      \"hexa_pt64x128_std_ms\":     %.6f,\n", res[si].hexa.std);
            fprintf(rj, "      \"hexa_pt64x128_min_ms\":     %.6f,\n", res[si].hexa.min);
            fprintf(rj, "      \"hexa_pt64x128_max_ms\":     %.6f,\n", res[si].hexa.max);
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":   %.6f,\n", res[si].hexa_maxabs);
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":   %.6f,\n", res[si].hexa_maxrel);
            fprintf(rj, "      \"ratio_vs_cublas\":         %.6f,\n", res[si].ratio);
            fprintf(rj, "      \"pct_over_n149_hilbert64\": %.4f,\n", pct_over_n149);
            fprintf(rj, "      \"ratio_delta_vs_n149\":     %.6f,\n", ratio_delta_n149);
            fprintf(rj, "      \"tile64x128_hilbert_beats_hilbert64\": %s,\n", beats_n149 ? "true" : "false");
            fprintf(rj, "      \"note\":                    null\n");
        } else {
            fprintf(rj, "      \"hexa_pt64x128_tflops\":     null,\n");
            fprintf(rj, "      \"hexa_pt64x128_median_ms\":  null,\n");
            fprintf(rj, "      \"hexa_pt64x128_mean_ms\":    null,\n");
            fprintf(rj, "      \"hexa_pt64x128_std_ms\":     null,\n");
            fprintf(rj, "      \"hexa_pt64x128_min_ms\":     null,\n");
            fprintf(rj, "      \"hexa_pt64x128_max_ms\":     null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":   null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":   null,\n");
            fprintf(rj, "      \"ratio_vs_cublas\":         null,\n");
            fprintf(rj, "      \"pct_over_n149_hilbert64\": null,\n");
            fprintf(rj, "      \"ratio_delta_vs_n149\":     null,\n");
            fprintf(rj, "      \"tile64x128_hilbert_beats_hilbert64\": null,\n");
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
