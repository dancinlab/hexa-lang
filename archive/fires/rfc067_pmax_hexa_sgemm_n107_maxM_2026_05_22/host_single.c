/* RFC 067 Pmax -- single-shape host for thermal isolation.
 *
 * Runs ONE shape at a time so we can sleep-cooldown between shapes.
 * Writes result_single_M<S>.json.
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host_single host_single.c -lcuda -lcublas -lm
 * Run:
 *   ./host_single sgemm_4warp_swizzle_SxS_grid.ptx S
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
    stat_t s = {0,0,0,0,0};
    if (n <= 0) return s;
    qsort(arr, n, sizeof(double), cmp_double);
    s.min = arr[0]; s.max = arr[n-1];
    s.median = (n % 2) ? arr[n/2] : 0.5*(arr[n/2-1] + arr[n/2]);
    double sum = 0.0;
    for (int i = 0; i < n; ++i) sum += arr[i];
    s.mean = sum / (double)n;
    double sq = 0.0;
    for (int i = 0; i < n; ++i) { double d = arr[i]-s.mean; sq += d*d; }
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
        if (exp < -10) { out = (sign << 15); }
        else {
            mant |= 0x800000;
            int shift = 14 - exp;
            out = (sign << 15) | (mant >> shift);
        }
    } else {
        out = (sign << 15) | (exp << 10) | (mant >> 13);
    }
    return out;
}

static int load_ptx_kernel(const char *ptx_path, const char *entry,
                           CUmodule *out_mod, CUfunction *out_fn)
{
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { fprintf(stderr, "ptx open %s: ", ptx_path); perror(""); return 1; }
    fseek(fp, 0, SEEK_END);
    long n_ptx = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) { return 1; }
    ptx[n_ptx] = 0;
    fclose(fp);

    char log_err[4096]; log_err[0] = 0;
    CUjit_option jit_opts[3] = {
        CU_JIT_TARGET_FROM_CUCONTEXT,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
    };
    void *jit_vals[3] = {
        (void *)0,
        (void *)log_err,
        (void *)(uintptr_t)sizeof(log_err),
    };
    CUresult e = cuModuleLoadDataEx(out_mod, ptx, 3, jit_opts, jit_vals);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleLoadDataEx: %s\nlog_err: %s\n", s ? s : "?", log_err);
        free(ptx); return 1;
    }
    e = cuModuleGetFunction(out_fn, *out_mod, entry);
    if (e != CUDA_SUCCESS) { free(ptx); return 1; }
    free(ptx);
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s <ptx> <S> [reps] [warmup] [throttle_check_ms]\n", argv[0]);
        return 2;
    }
    const char *ptx_path = argv[1];
    int S = atoi(argv[2]);
    int REPS   = (argc > 3) ? atoi(argv[3]) : 50;
    int WARMUP = (argc > 4) ? atoi(argv[4]) : 5;

    int M = S, N = S, K = S;

    CHECK_CU(cuInit(0));
    CUdevice  dev; CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    char dev_name[256];
    CHECK_CU(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    int driver_ver = 0, runtime_ver = 0;
    CHECK_CU(cuDriverGetVersion(&driver_ver));
    cudaRuntimeGetVersion(&runtime_ver);
    fprintf(stderr, "Device: %s sm_%d%d  driver=%d runtime=%d\n",
            dev_name, sm_major, sm_minor, driver_ver, runtime_ver);

    char entry[64];
    snprintf(entry, sizeof(entry), "sgemm_4warp_swizzle_%dx%d_grid", S, S);
    CUmodule mod;
    CUfunction fn;
    if (load_ptx_kernel(ptx_path, entry, &mod, &fn) != 0) {
        fprintf(stderr, "PTX load failed\n"); return 1;
    }
    int reg_per_thd = 0;
    cuFuncGetAttribute(&reg_per_thd, CU_FUNC_ATTRIBUTE_NUM_REGS, fn);
    fprintf(stderr, "regs/thd=%d\n", reg_per_thd);

    const size_t ASZ = (size_t)M * (size_t)K;
    const size_t BSZ = (size_t)K * (size_t)N;
    const size_t CSZ = (size_t)M * (size_t)N;
    size_t bytes_needed = ASZ*2 + BSZ*2 + CSZ*4;
    fprintf(stderr, "[M=%d] alloc %.2f MB\n", M, (double)bytes_needed/1048576.0);

    unsigned short *ha = (unsigned short *)malloc(ASZ*2);
    unsigned short *hb = (unsigned short *)malloc(BSZ*2);
    for (size_t i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
    for (size_t i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

    CUdeviceptr da, db, dc;
    CHECK_CU(cuMemAlloc(&da, ASZ*2));
    CHECK_CU(cuMemAlloc(&db, BSZ*2));
    CHECK_CU(cuMemAlloc(&dc, CSZ*4));
    CHECK_CU(cuMemcpyHtoD(da, ha, ASZ*2));
    CHECK_CU(cuMemcpyHtoD(db, hb, BSZ*2));
    CHECK_CU(cuMemsetD8(dc, 0, CSZ*4));

    cublasHandle_t handle;
    CHECK_BLAS(cublasCreate(&handle));
    CHECK_BLAS(cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH));

    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };
    unsigned int gx = (unsigned int)(N / 64);
    unsigned int gy = (unsigned int)(M / 64);

    cudaEvent_t ev_a, ev_b;
    cudaEventCreate(&ev_a); cudaEventCreate(&ev_b);
    double *times = (double *)malloc(REPS * sizeof(double));

    /* cuBLAS bit-exact reference snapshot for sanity check */
    float alpha = 1.0f, beta = 0.0f;
    CHECK_CU(cuMemsetD8(dc, 0, CSZ*4));
    CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
        &alpha, (const void *)(uintptr_t)db, CUDA_R_16F, N,
        (const void *)(uintptr_t)da, CUDA_R_16F, K,
        &beta, (void *)(uintptr_t)dc, CUDA_R_32F, N,
        CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CHECK_CU(cuCtxSynchronize());
    float *cublas_c = (float *)malloc(CSZ*4);
    CHECK_CU(cuMemcpyDtoH(cublas_c, dc, CSZ*4));

    CHECK_CU(cuMemsetD8(dc, 0, CSZ*4));
    CHECK_CU(cuLaunchKernel(fn, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    float *hexa_c = (float *)malloc(CSZ*4);
    CHECK_CU(cuMemcpyDtoH(hexa_c, dc, CSZ*4));
    float maxabs = 0.0f, maxrel = 0.0f;
    for (size_t i = 0; i < CSZ; ++i) {
        float d = fabsf(cublas_c[i] - hexa_c[i]);
        if (d > maxabs) maxabs = d;
        float scale = fabsf(cublas_c[i]);
        if (scale > 1e-3f) { float r = d/scale; if (r > maxrel) maxrel = r; }
    }
    free(cublas_c); free(hexa_c);
    fprintf(stderr, "[M=%d] sanity vs cuBLAS: maxabs=%.6f maxrel=%.6f\n", M, maxabs, maxrel);

    /* WARMUP */
    for (int i = 0; i < WARMUP; ++i) {
        CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha, (const void *)(uintptr_t)db, CUDA_R_16F, N,
            (const void *)(uintptr_t)da, CUDA_R_16F, K,
            &beta, (void *)(uintptr_t)dc, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    }
    CHECK_CU(cuCtxSynchronize());

    /* MEASURE cuBLAS */
    for (int i = 0; i < REPS; ++i) {
        cudaEventRecord(ev_a, 0);
        CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha, (const void *)(uintptr_t)db, CUDA_R_16F, N,
            (const void *)(uintptr_t)da, CUDA_R_16F, K,
            &beta, (void *)(uintptr_t)dc, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        cudaEventRecord(ev_b, 0);
        cudaEventSynchronize(ev_b);
        float ms = 0.0f;
        cudaEventElapsedTime(&ms, ev_a, ev_b);
        times[i] = (double)ms;
    }
    stat_t cs = stats_compute(times, REPS);
    double flops = 2.0 * (double)M * (double)N * (double)K;
    double cublas_tflops = flops / (cs.median/1000.0) / 1e12;
    fprintf(stderr, "[M=%d] cuBLAS  med=%.4f ms std=%.4f min=%.4f max=%.4f  TFLOPS=%.4f\n",
            M, cs.median, cs.std, cs.min, cs.max, cublas_tflops);

    /* COOL between cuBLAS and hexa: ctx sync + brief sleep */
    CHECK_CU(cuCtxSynchronize());

    /* WARMUP hexa */
    for (int i = 0; i < WARMUP; ++i) {
        CHECK_CU(cuLaunchKernel(fn, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    /* MEASURE hexa */
    for (int i = 0; i < REPS; ++i) {
        cudaEventRecord(ev_a, 0);
        CHECK_CU(cuLaunchKernel(fn, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
        cudaEventRecord(ev_b, 0);
        cudaEventSynchronize(ev_b);
        float ms = 0.0f;
        cudaEventElapsedTime(&ms, ev_a, ev_b);
        times[i] = (double)ms;
    }
    stat_t hs = stats_compute(times, REPS);
    double hexa_tflops = flops / (hs.median/1000.0) / 1e12;
    double ratio = hexa_tflops / cublas_tflops;
    fprintf(stderr, "[M=%d] hexa    med=%.4f ms std=%.4f min=%.4f max=%.4f  TFLOPS=%.4f  ratio=%.4f\n",
            M, hs.median, hs.std, hs.min, hs.max, hexa_tflops, ratio);

    /* Emit JSON to stdout. */
    printf("{\n");
    printf("  \"M\": %d, \"N\": %d, \"K\": %d,\n", M, N, K);
    printf("  \"device\": \"%s\",\n", dev_name);
    printf("  \"sm\": \"sm_%d%d\",\n", sm_major, sm_minor);
    printf("  \"reps\": %d, \"warmup\": %d,\n", REPS, WARMUP);
    printf("  \"vram_bytes_allocated\": %zu,\n", bytes_needed);
    printf("  \"regs_per_thd\": %d,\n", reg_per_thd);
    printf("  \"num_ctas\": %d,\n", (M/64)*(N/64));
    printf("  \"hexa_vs_cublas_maxabs\": %.6f,\n", maxabs);
    printf("  \"hexa_vs_cublas_maxrel\": %.6f,\n", maxrel);
    printf("  \"cublas_hgemm\": { \"tflops\": %.6f, \"median_ms\": %.6f, \"mean_ms\": %.6f, \"std_ms\": %.6f, \"min_ms\": %.6f, \"max_ms\": %.6f },\n",
           cublas_tflops, cs.median, cs.mean, cs.std, cs.min, cs.max);
    printf("  \"hexa_py\":      { \"tflops\": %.6f, \"median_ms\": %.6f, \"mean_ms\": %.6f, \"std_ms\": %.6f, \"min_ms\": %.6f, \"max_ms\": %.6f },\n",
           hexa_tflops, hs.median, hs.mean, hs.std, hs.min, hs.max);
    printf("  \"ratio_vs_cublas\": %.6f\n", ratio);
    printf("}\n");

    free(times);
    cudaEventDestroy(ev_a); cudaEventDestroy(ev_b);
    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    free(ha); free(hb);
    cublasDestroy(handle);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return 0;
}
