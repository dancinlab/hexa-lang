/* RFC 067 N201 -- TMA SWIZZLE_128B + mma.sync + Hilbert SGEMM sweep host driver.
 *
 * Closes gap #2 from N200-full honest readout: bank conflicts on ldmatrix from
 * non-swizzled smem tile.
 *
 * KEY DIFFERENCES from N200-full host:
 *   1. cuTensorMapEncodeTiled: SWIZZLE_NONE -> SWIZZLE_128B
 *   2. TMA box: [K_TILE=16, 64 rows] -> [K_TILE_INNER=64, 64 rows]
 *      (innermost = 128 B required by SWIZZLE_128B at runtime)
 *   3. K_TILES_OUTER kernel arg: K/16 -> K/64
 *   4. dynamic shared mem: 4112 B -> 16400 B (8192 A + 8192 B + 16 mbar)
 *
 * Build (on ubu-1 with CUDA 12.9):
 *   /usr/local/cuda-12.9/bin/nvcc -O2 -arch=sm_120a -o host host.c -lcuda -lcublas -lm
 *
 * Falsifier F-RFC067-HEXA-TMA-SWIZZLE128:
 *   - max|hexa - cuBLAS| < 1e-2 * |cuBLAS|_max
 *   - per-shape median TFLOPS + ratio vs N200-full SWIZZLE_NONE baseline
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
    if (exp >= 31) out = (sign << 15) | (0x1f << 10) | (mant ? (mant >> 13) : 0);
    else if (exp <= 0) {
        if (exp < -10) out = (sign << 15);
        else { mant |= 0x800000; int shift = 14 - exp; out = (sign << 15) | (mant >> shift); }
    } else out = (sign << 15) | (exp << 10) | (mant >> 13);
    return out;
}

#define N_SHAPES 9

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
    unsigned int hilbert_p;
    unsigned int ctas_launched;
    unsigned int ctas_real;
    int    regs_per_thd;
    int    shmem_bytes_static;
    size_t bytes_allocated;
    char   note[256];
} shape_result_t;

static int build_tma_desc(CUtensorMap *out,
                          CUdeviceptr base,
                          unsigned int inner_dim,
                          unsigned int outer_dim,
                          unsigned int box_inner,
                          unsigned int box_outer,
                          CUtensorMapSwizzle swizzle)
{
    cuuint64_t globalDim[2]    = { (cuuint64_t)inner_dim, (cuuint64_t)outer_dim };
    cuuint64_t globalStride[1] = { (cuuint64_t)inner_dim * 2 };
    cuuint32_t boxDim[2]       = { (cuuint32_t)box_inner, (cuuint32_t)box_outer };
    cuuint32_t elemStride[2]   = { 1, 1 };
    CHECK_CU(cuTensorMapEncodeTiled(
        out, CU_TENSOR_MAP_DATA_TYPE_FLOAT16, 2, (void *)base,
        globalDim, globalStride, boxDim, elemStride,
        CU_TENSOR_MAP_INTERLEAVE_NONE, swizzle,
        CU_TENSOR_MAP_L2_PROMOTION_NONE, CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE));
    return 0;
}

static int load_ptx_kernel(const char *ptx_path,
                           const char *entry,
                           CUmodule *out_mod,
                           CUfunction *out_fn,
                           char *out_info, size_t out_info_n,
                           char *out_err,  size_t out_err_n)
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
        if (out_err && out_err_n > 0)
            snprintf(out_err, out_err_n, "load failed: %s; err=%s", s ? s : "?", log_err);
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

int main(int argc, char **argv) {
    int shapes[N_SHAPES] = { 256, 384, 448, 512, 1024, 2048, 4096, 6144, 8192 };

    if (argc < 1 + N_SHAPES) {
        fprintf(stderr, "usage: %s <ptx_256> <ptx_384> <ptx_448> <ptx_512> <ptx_1024> <ptx_2048> <ptx_4096> <ptx_6144> <ptx_8192>\n", argv[0]);
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
    char       load_err[N_SHAPES][512];
    char       load_info[N_SHAPES][8192];
    FILE *fp_info = fopen("ptxas_info.log", "w");
    for (int si = 0; si < N_SHAPES; ++si) {
        char entry[64];
        snprintf(entry, sizeof(entry), "sgemm_tma_sw128_%dx%d_grid", shapes[si], shapes[si]);
        load_err[si][0] = 0;
        if (load_ptx_kernel(argv[1 + si], entry, &mods[si], &fns[si],
                            load_info[si], sizeof(load_info[si]),
                            load_err[si], sizeof(load_err[si])) == 0) {
            load_ok[si] = 1;
            printf("loaded N201 PTX shape %d (%s)\n", shapes[si], entry);
            if (fp_info)
                fprintf(fp_info, "=== shape %d (%s) ===\n%s\n\n", shapes[si], entry, load_info[si]);
        } else {
            load_ok[si] = 0;
            printf("FAILED N201 PTX shape %d -- %s\n", shapes[si], load_err[si]);
        }
        if (load_ok[si]) {
            int reg_per_thd = 0, shmem_bytes = 0, max_thd = 0;
            cuFuncGetAttribute(&reg_per_thd, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            cuFuncGetAttribute(&shmem_bytes, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[si]);
            cuFuncGetAttribute(&max_thd, CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK, fns[si]);
            printf("  shape %d: regs/thd=%d, shmem=%d B, max_thd_per_block=%d\n",
                   shapes[si], reg_per_thd, shmem_bytes, max_thd);
            if (fp_info)
                fprintf(fp_info, "shape %d cuFuncGetAttribute: regs/thd=%d, shmem=%d B, max_thd_per_block=%d\n\n",
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

    shape_result_t res[N_SHAPES];
    memset(res, 0, sizeof(res));

    double *times = (double *)malloc(REPS * sizeof(double));

    for (int si = 0; si < N_SHAPES; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        res[si].M = M; res[si].N = N; res[si].K = K;
        unsigned int side = (unsigned int)(M / 64);
        unsigned int p = next_pow2_u(side);
        res[si].hilbert_p = p;
        res[si].ctas_launched = p * p;
        res[si].ctas_real = side * side;

        if (load_ok[si]) {
            int rpt = 0, shb = 0;
            cuFuncGetAttribute(&rpt, CU_FUNC_ATTRIBUTE_NUM_REGS, fns[si]);
            cuFuncGetAttribute(&shb, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fns[si]);
            res[si].regs_per_thd = rpt;
            res[si].shmem_bytes_static = shb;
        }

        const size_t ASZ = (size_t)M * (size_t)K;
        const size_t BSZ = (size_t)K * (size_t)N;
        const size_t CSZ = (size_t)M * (size_t)N;

        size_t bytes_needed = ASZ * 2 + BSZ * 2 + CSZ * 4 + CSZ * 4;
        res[si].bytes_allocated = bytes_needed;
        printf("[M=%4d] allocating %.2f MB device memory\n",
               M, (double)bytes_needed / 1048576.0);

        unsigned short *ha = (unsigned short *)malloc(ASZ * sizeof(unsigned short));
        unsigned short *hb = (unsigned short *)malloc(BSZ * sizeof(unsigned short));
        if (!ha || !hb) {
            fprintf(stderr, "host malloc failed at shape M=%d\n", M);
            snprintf(res[si].note, sizeof(res[si].note), "host malloc failed at M=%d", M);
            if (ha) free(ha);
            if (hb) free(hb);
            continue;
        }
        /* Non-trivial all-positive fill so cuBLAS C is non-zero.
           Use a row-dependent component to break the all-cells-equal pattern that
           triggered cuBLAS HGEMM split-K reduction artifacts at K=6144 in v1
           (where every C[m,n] should be 396 but cuBLAS returned a 3-way mix of
           264/396/528 -- a cuBLAS-side artifact since CPU-naive and hexa both
           agree on 396). Adding row offset to A and col offset to B breaks
           periodicity. */
        for (size_t i = 0; i < ASZ; ++i) {
            size_t row = i / (size_t)K;
            size_t col = i % (size_t)K;
            ha[i] = f32_to_f16(0.25f + 0.0625f * (float)((col + (row & 3)) % 4));
        }
        for (size_t i = 0; i < BSZ; ++i) {
            size_t row = i / (size_t)K;  /* row in storage = N-index in B */
            size_t col = i % (size_t)K;
            hb[i] = f32_to_f16(0.125f + 0.0625f * (float)((col + (row % 3)) % 3));
        }

        CUdeviceptr da = 0, db = 0, dc = 0;
        CUresult e_a = cuMemAlloc(&da, ASZ * sizeof(unsigned short));
        CUresult e_b = cuMemAlloc(&db, BSZ * sizeof(unsigned short));
        CUresult e_c = cuMemAlloc(&dc, CSZ * sizeof(float));
        if (e_a != CUDA_SUCCESS || e_b != CUDA_SUCCESS || e_c != CUDA_SUCCESS) {
            fprintf(stderr, "cuMemAlloc failed at shape M=%d\n", M);
            snprintf(res[si].note, sizeof(res[si].note), "cuMemAlloc OOM at M=%d", M);
            if (da) cuMemFree(da);
            if (db) cuMemFree(db);
            if (dc) cuMemFree(dc);
            free(ha); free(hb);
            continue;
        }
        CHECK_CU(cuMemcpyHtoD(da, ha, ASZ * sizeof(unsigned short)));
        CHECK_CU(cuMemcpyHtoD(db, hb, BSZ * sizeof(unsigned short)));
        CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));

        /* SWIZZLE_128B box [K_TILE_INNER=64 fp16=128B, 64 rows] */
        CUtensorMap tmap_a, tmap_b;
        if (build_tma_desc(&tmap_a, da, (unsigned)K, (unsigned)M, 64, 64,
                           CU_TENSOR_MAP_SWIZZLE_128B) != 0) return 1;
        if (build_tma_desc(&tmap_b, db, (unsigned)K, (unsigned)N, 64, 64,
                           CU_TENSOR_MAP_SWIZZLE_128B) != 0) return 1;

        /* cuBLAS HGEMM reference */
        float alpha = 1.0f, beta = 0.0f;
        cudaEvent_t ev_a, ev_b;
        CHECK_RT(cudaEventCreate(&ev_a));
        CHECK_RT(cudaEventCreate(&ev_b));

        for (int i = 0; i < WARMUP; ++i) {
            CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                &alpha, (const void *)(uintptr_t)db, CUDA_R_16F, N,
                (const void *)(uintptr_t)da, CUDA_R_16F, K,
                &beta, (void *)(uintptr_t)dc, CUDA_R_32F, N,
                CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        }
        CHECK_CU(cuCtxSynchronize());

        for (int i = 0; i < REPS; ++i) {
            CHECK_RT(cudaEventRecord(ev_a, 0));
            CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                &alpha, (const void *)(uintptr_t)db, CUDA_R_16F, N,
                (const void *)(uintptr_t)da, CUDA_R_16F, K,
                &beta, (void *)(uintptr_t)dc, CUDA_R_32F, N,
                CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
            CHECK_RT(cudaEventRecord(ev_b, 0));
            CHECK_RT(cudaEventSynchronize(ev_b));
            float ms = 0.0f;
            CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
            times[i] = (double)ms;
        }
        res[si].cublas = stats_compute(times, REPS);
        double flops = 2.0 * (double)M * (double)N * (double)K;
        res[si].cublas_tflops = flops / (res[si].cublas.median / 1000.0) / 1e12;
        printf("[M=%4d] cuBLAS HGEMM             median=%.6f ms  TFLOPS=%8.4f\n",
               M, res[si].cublas.median, res[si].cublas_tflops);

        float *cublas_c = NULL;
        if (load_ok[si]) {
            cublas_c = (float *)malloc(CSZ * sizeof(float));
            CHECK_CU(cuMemcpyDtoH(cublas_c, dc, CSZ * sizeof(float)));
        }

        if (load_ok[si]) {
            /* Need K_TILES_OUTER = K / 64 (each TMA loads 64 K-cols) */
            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            int K_TILES_OUTER = K / 64;
            unsigned long long k_arg = (unsigned long long)K_TILES_OUTER;
            void *kargs[4] = { &tmap_a, &tmap_b, &dc, &k_arg };

            unsigned int gx = p, gy = p;
            CUresult le = cuLaunchKernel(fns[si], gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL);
            if (le != CUDA_SUCCESS) {
                const char *s = NULL; cuGetErrorString(le, &s);
                fprintf(stderr, "[M=%4d] hexa sanity launch FAILED: %s\n", M, s ? s : "?");
                snprintf(res[si].note, sizeof(res[si].note), "launch fail: %s", s ? s : "?");
                cuMemFree(da); cuMemFree(db); cuMemFree(dc);
                free(ha); free(hb); if (cublas_c) free(cublas_c);
                continue;
            }
            CUresult se = cuCtxSynchronize();
            if (se != CUDA_SUCCESS) {
                const char *s = NULL; cuGetErrorString(se, &s);
                fprintf(stderr, "[M=%4d] hexa sanity sync FAILED: %s\n", M, s ? s : "?");
                snprintf(res[si].note, sizeof(res[si].note), "sync fail: %s", s ? s : "?");
                cuMemFree(da); cuMemFree(db); cuMemFree(dc);
                free(ha); free(hb); if (cublas_c) free(cublas_c);
                continue;
            }
            float *hexa_c = (float *)malloc(CSZ * sizeof(float));
            CHECK_CU(cuMemcpyDtoH(hexa_c, dc, CSZ * sizeof(float)));

            float maxabs = 0.0f, maxrel = 0.0f, max_cublas_abs = 0.0f;
            for (size_t i = 0; i < CSZ; ++i) {
                float d = fabsf(cublas_c[i] - hexa_c[i]);
                if (d > maxabs) maxabs = d;
                float scale = fabsf(cublas_c[i]);
                if (scale > max_cublas_abs) max_cublas_abs = scale;
                if (scale > 1e-3f) {
                    float r = d / scale;
                    if (r > maxrel) maxrel = r;
                }
            }
            res[si].hexa_maxabs = maxabs;
            res[si].hexa_maxrel = maxrel;
            free(hexa_c);
            printf("[M=%4d] sanity max|hexa-cuBLAS|=%.4f maxrel=%.6f (cuBLAS max|C|=%.4f)\n",
                   M, maxabs, maxrel, max_cublas_abs);

            /* Decide whether to time. Skip timing if max_rel > 5% -- numeric failure. */
            int numeric_ok = (maxrel < 0.05f) && (max_cublas_abs > 1.0f);
            if (!numeric_ok) {
                snprintf(res[si].note, sizeof(res[si].note),
                         "NUMERIC FAIL: maxabs=%.4f maxrel=%.6f max_cublas=%.4f",
                         maxabs, maxrel, max_cublas_abs);
                printf("[M=%4d] N201 NUMERIC FAIL -- skipping timing\n", M);
                res[si].hexa_valid = 0;
                cudaEventDestroy(ev_a);
                cudaEventDestroy(ev_b);
                if (cublas_c) free(cublas_c);
                cuMemFree(da); cuMemFree(db); cuMemFree(dc);
                free(ha); free(hb);
                continue;
            }

            /* Timed run */
            CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));
            for (int i = 0; i < WARMUP; ++i) {
                CHECK_CU(cuLaunchKernel(fns[si], gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
            }
            CHECK_CU(cuCtxSynchronize());
            for (int i = 0; i < REPS; ++i) {
                CHECK_RT(cudaEventRecord(ev_a, 0));
                CHECK_CU(cuLaunchKernel(fns[si], gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
                CHECK_RT(cudaEventRecord(ev_b, 0));
                CHECK_RT(cudaEventSynchronize(ev_b));
                float ms = 0.0f;
                CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
                times[i] = (double)ms;
            }
            res[si].hexa = stats_compute(times, REPS);
            res[si].hexa_tflops = flops / (res[si].hexa.median / 1000.0) / 1e12;
            res[si].ratio = res[si].hexa_tflops / res[si].cublas_tflops;
            res[si].hexa_valid = 1;
            printf("[M=%4d] N201 TMA-SWIZZLE128 median=%.6f ms TFLOPS=%8.4f ratio=%.4f maxabs=%.4f CTAs=%u regs=%d shmem=%d\n",
                   M, res[si].hexa.median, res[si].hexa_tflops, res[si].ratio,
                   res[si].hexa_maxabs, res[si].ctas_launched, res[si].regs_per_thd, res[si].shmem_bytes_static);
        } else {
            res[si].hexa_valid = 0;
            snprintf(res[si].note, sizeof(res[si].note), "%s", load_err[si]);
            printf("[M=%4d] N201 SKIPPED -- %s\n", M, res[si].note);
        }

        cudaEventDestroy(ev_a);
        cudaEventDestroy(ev_b);
        if (cublas_c) free(cublas_c);
        cuMemFree(da); cuMemFree(db); cuMemFree(dc);
        free(ha); free(hb);
    }
    free(times);

    /* N200-full SWIZZLE_NONE baseline (from result.json on origin/main e9d2da2c) */
    double n200_hexa_tflops[N_SHAPES] = { 15.169, 39.395, 51.902, 55.980, 56.455, 57.984 };
    double n200_ratio[N_SHAPES]       = { 0.6546, 0.7385, 0.7773, 0.7995, 0.7976, 0.8190 };

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-N201-tma-swizzle128-mma-hilbert\",\n");
    fprintf(rj, "  \"date_utc\": \"2026-05-22\",\n");
    fprintf(rj, "  \"host\": \"%s\",\n", getenv("PY_HOST") ? getenv("PY_HOST") : "ubu-1");
    fprintf(rj, "  \"device\": \"%s\",\n", dev_name);
    fprintf(rj, "  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    fprintf(rj, "  \"driver_version\": %d,\n", driver_ver);
    fprintf(rj, "  \"runtime_version\": %d,\n", runtime_ver);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"measurement_count\": %d,\n", REPS);
    fprintf(rj, "  \"variant\": \"N201: TMA SWIZZLE_128B (box [K_TILE_INNER=64, 64 rows] = 8192 B/tile) + named mbarrier (parity, expect_tx 16384/K-outer) + 8 mma.sync.m16n8k16 per warp per K-step + 4 K-steps per outer iter + Hilbert d2xy. sm_120a + .version 8.7 + ASCII-only PTX. ldmatrix lane addr = full_row * 128 + (atom_k XOR (row & 7)) * 16.\",\n");
    fprintf(rj, "  \"hexa_kernel_family\": \"sgemm_tma_sw128_SxS_grid\",\n");
    fprintf(rj, "  \"cublas_math_mode\": \"CUBLAS_TENSOR_OP_MATH (HGEMM via cublasGemmEx CUBLAS_COMPUTE_32F)\",\n");
    fprintf(rj, "  \"layout\": {\n");
    fprintf(rj, "    \"A_global\": \"row-major [M, K] fp16\",\n");
    fprintf(rj, "    \"B_global\": \"col-major [K, N] fp16 (stored as [N, K] row-major)\",\n");
    fprintf(rj, "    \"C_global\": \"row-major [M, N] fp32\",\n");
    fprintf(rj, "    \"tma_box_dim\": \"[K_TILE_INNER=64 fp16=128B, 64 rows]\",\n");
    fprintf(rj, "    \"tma_swizzle\": \"CU_TENSOR_MAP_SWIZZLE_128B\",\n");
    fprintf(rj, "    \"smem_a_bytes\": 8192,\n");
    fprintf(rj, "    \"smem_b_bytes\": 8192,\n");
    fprintf(rj, "    \"smem_mbar_bytes\": 16,\n");
    fprintf(rj, "    \"smem_total_per_cta\": 16400,\n");
    fprintf(rj, "    \"per_cta_output\": \"64x64\",\n");
    fprintf(rj, "    \"warps_per_cta\": 4,\n");
    fprintf(rj, "    \"mma_per_warp_per_kstep\": 8,\n");
    fprintf(rj, "    \"kstep_per_outer_iter\": 4,\n");
    fprintf(rj, "    \"acc_f32_per_lane\": 32\n");
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"shapes\": [\n");
    for (int si = 0; si < N_SHAPES; ++si) {
        double pct_over_n200 = 0.0;
        double ratio_delta_n200 = 0.0;
        int beats_n200 = 0;
        if (res[si].hexa_valid) {
            pct_over_n200 = 100.0 * (res[si].hexa_tflops - n200_hexa_tflops[si]) / n200_hexa_tflops[si];
            ratio_delta_n200 = res[si].ratio - n200_ratio[si];
            beats_n200 = (res[si].hexa_tflops > n200_hexa_tflops[si]);
        }
        fprintf(rj, "    {\n");
        fprintf(rj, "      \"M\": %d, \"N\": %d, \"K\": %d,\n", res[si].M, res[si].N, res[si].K);
        fprintf(rj, "      \"vram_bytes_allocated\":     %zu,\n", res[si].bytes_allocated);
        fprintf(rj, "      \"hilbert_p\":                %u,\n", res[si].hilbert_p);
        fprintf(rj, "      \"ctas_launched\":            %u,\n", res[si].ctas_launched);
        fprintf(rj, "      \"ctas_real\":                %u,\n", res[si].ctas_real);
        fprintf(rj, "      \"regs_per_thd\":             %d,\n", res[si].regs_per_thd);
        fprintf(rj, "      \"shmem_bytes_static\":       %d,\n", res[si].shmem_bytes_static);
        fprintf(rj, "      \"cublas_hgemm_tflops\":      %.6f,\n", res[si].cublas_tflops);
        fprintf(rj, "      \"cublas_hgemm_median_ms\":   %.6f,\n", res[si].cublas.median);
        fprintf(rj, "      \"n200_swiznone_tflops\":     %.6f,\n", n200_hexa_tflops[si]);
        fprintf(rj, "      \"n200_swiznone_ratio\":      %.6f,\n", n200_ratio[si]);
        if (res[si].hexa_valid) {
            fprintf(rj, "      \"hexa_n201_tflops\":         %.6f,\n", res[si].hexa_tflops);
            fprintf(rj, "      \"hexa_n201_median_ms\":      %.6f,\n", res[si].hexa.median);
            fprintf(rj, "      \"hexa_n201_std_ms\":         %.6f,\n", res[si].hexa.std);
            fprintf(rj, "      \"hexa_n201_min_ms\":         %.6f,\n", res[si].hexa.min);
            fprintf(rj, "      \"hexa_n201_max_ms\":         %.6f,\n", res[si].hexa.max);
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":    %.6f,\n", res[si].hexa_maxabs);
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":    %.6f,\n", res[si].hexa_maxrel);
            fprintf(rj, "      \"ratio_vs_cublas\":          %.6f,\n", res[si].ratio);
            fprintf(rj, "      \"pct_over_n200_swiznone\":   %.6f,\n", pct_over_n200);
            fprintf(rj, "      \"ratio_delta_vs_n200\":      %.6f,\n", ratio_delta_n200);
            fprintf(rj, "      \"beats_n200\":               %s,\n", beats_n200 ? "true" : "false");
            fprintf(rj, "      \"note\":                     null\n");
        } else {
            fprintf(rj, "      \"hexa_n201_tflops\":         null,\n");
            fprintf(rj, "      \"hexa_n201_median_ms\":      null,\n");
            fprintf(rj, "      \"hexa_n201_std_ms\":         null,\n");
            fprintf(rj, "      \"hexa_n201_min_ms\":         null,\n");
            fprintf(rj, "      \"hexa_n201_max_ms\":         null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxabs\":    null,\n");
            fprintf(rj, "      \"hexa_vs_cublas_maxrel\":    null,\n");
            fprintf(rj, "      \"ratio_vs_cublas\":          null,\n");
            fprintf(rj, "      \"pct_over_n200_swiznone\":   null,\n");
            fprintf(rj, "      \"ratio_delta_vs_n200\":      null,\n");
            fprintf(rj, "      \"beats_n200\":               null,\n");
            fprintf(rj, "      \"note\":                     \"%s\"\n", res[si].note);
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
