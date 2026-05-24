/* RFC 067 P5 perf HGEMM hexa-emit vs cuBLAS -- single-shape benchmark.
 *
 * GPU.md sec 5m measured-claim. Times hexa-emit WMMA GEMM against
 * cuBLAS GemmEx (f16 inputs, f32 compute, f32 output) on the same
 * shape, same buffers, same warmup, same rep count, same RTX 5070.
 *
 * Shape: M = N = K = 256 (fixed). Kernel: wmma_256x256_grid.ptx
 * (grid 4x4 blocks * 16 warps/block * 16x16 WMMA tile = 256x256 out).
 *
 * Measures via cuEventRecord (begin/end before/after the rep loop;
 * synchronize on end_event; mean_ms = total_ms / reps). Reports
 * TFLOPS = (2 * M * N * K * reps) / total_s / 1e12.
 *
 * Honest report -- @D g3 verification-anchor-real-limit:
 *   - if hexa is 10x slower than cuBLAS, REPORT THAT.
 *   - the goal is the data point, not the win.
 *
 * Build: nvcc -O2 -arch=sm_90 -o host r067_perf_hgemm_host.c \
 *        -lcuda -lcublas
 * Run:   ./host wmma_256x256_grid.ptx
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
    uint32_t sign  = (h & 0x8000) << 16;
    uint32_t exp   = (h & 0x7c00) >> 10;
    uint32_t mant  =  h & 0x3ff;
    uint32_t f;
    if (exp == 0)        { f = sign; }
    else if (exp == 31)  { f = sign | 0x7f800000 | (mant << 13); }
    else                 { f = sign | ((exp - 15 + 127) << 23) | (mant << 13); }
    float out; memcpy(&out, &f, 4);
    return out;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s wmma_256x256_grid.ptx\n", argv[0]); return 2; }
    const char *ptx_path = argv[1];

    /* Load PTX text. */
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("ptx open"); return 1; }
    fseek(fp, 0, SEEK_END);
    long n_ptx = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) { fprintf(stderr, "ptx short read\n"); return 1; }
    ptx[n_ptx] = 0;
    fclose(fp);

    CHECK_CU(cuInit(0));
    CUdevice  dev;     CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx;     CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    /* JIT-load hexa-emit PTX (driver picks target from current ctx). */
    CUmodule mod;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK_CU(cuModuleLoadDataEx(&mod, ptx, 1, jit_opts, jit_vals));
    CUfunction f_hexa;
    CHECK_CU(cuModuleGetFunction(&f_hexa, mod, "wmma_256x256_grid"));

    /* Shape. */
    const int M = 256, N = 256, K = 256;
    const int K_PER_TILE = 16;
    const int K_TILES_TOTAL = K / K_PER_TILE;  /* 16 */
    const int ASZ = M * K;                     /* 65536 f16 */
    const int BSZ = K * N;                     /* 65536 f16 */
    const int CSZ = M * N;                     /* 65536 f32 */

    /* Host buffers.
     *
     * Hexa-emit kernel expects:
     *   A row-major     a[m][k] = ha[m*K + k]   (f16)
     *   B col-major     b[k][n] = hb[n*K + k]   (f16)
     *   C row-major     c[m][n] = hc[m*N + n]   (f32)
     *
     * cuBLAS expects column-major. We will reuse the same A/B buffers
     * with this trick:
     *
     *   Our A row-major M*K     == A^T col-major K*M
     *   Our B col-major K*N     == B   col-major K*N
     *
     * Mathematically, to get C = A*B (row-major M*N) we compute the
     * column-major view via:
     *   C^T (col-major N*M)  = B^T * A^T = (B^T) * (A^T)
     *
     * But more naturally, cuBLAS sees A^T col-major (K*M) -- we ask for
     * op_A = T (transpose) -> A col-major M*K logically. And B col-major
     * K*N with op_B = N. The product is C col-major M*N -> when we view
     * this same memory row-major it is C^T row-major N*M. NOT what we want.
     *
     * Cleanest -- use the col/row dual identity:
     *
     *   C_row_major(M,N) = A_row_major(M,K) * B_view(K,N)
     *
     * View the same bytes column-major:
     *   C^T_col_major(N,M) = B^T_col_major(N,K) * A^T_col_major(K,M)
     *
     *   - B is stored col-major K*N -> the same bytes viewed col-major
     *     as N*K is exactly B^T. ldb = K.
     *   - A is stored row-major M*K -> the same bytes viewed col-major
     *     as K*M is exactly A^T. lda = K.
     *   - C output, viewed col-major N*M -> the same bytes viewed
     *     row-major M*N is the desired C. ldc = N.
     *
     * So call cublasGemmEx(handle, OP_N, OP_N, n=N, m=M, k=K,
     *                      A=B_buf, lda=K, B=A_buf, ldb=K,
     *                      C=C_buf, ldc=N).
     *
     * The two A/B buffers are identical bytes for both kernels; only
     * the cuBLAS opcode treats them differently.
     */
    uint16_t *ha = (uint16_t *)malloc(ASZ * sizeof(uint16_t));
    uint16_t *hb = (uint16_t *)malloc(BSZ * sizeof(uint16_t));
    float    *hc_hexa  = (float *)malloc(CSZ * sizeof(float));
    float    *hc_blas  = (float *)malloc(CSZ * sizeof(float));
    float    *cref     = (float *)malloc(CSZ * sizeof(float));

    /* Small inputs in safe f16 range (avoid mantissa loss in long chains). */
    for (int i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
    for (int i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

    /* CPU reference (single shot, for numeric gate). */
    for (int m = 0; m < M; ++m) {
        for (int n = 0; n < N; ++n) {
            float acc = 0.0f;
            for (int k = 0; k < K; ++k) {
                float av = f16_to_f32(ha[m * K + k]);
                float bv = f16_to_f32(hb[n * K + k]);
                acc += av * bv;
            }
            cref[m * N + n] = acc;
        }
    }

    /* Device buffers. */
    CUdeviceptr da, db, dc_hexa, dc_blas;
    CHECK_CU(cuMemAlloc(&da, ASZ * sizeof(uint16_t)));
    CHECK_CU(cuMemAlloc(&db, BSZ * sizeof(uint16_t)));
    CHECK_CU(cuMemAlloc(&dc_hexa, CSZ * sizeof(float)));
    CHECK_CU(cuMemAlloc(&dc_blas, CSZ * sizeof(float)));
    CHECK_CU(cuMemcpyHtoD(da, ha, ASZ * sizeof(uint16_t)));
    CHECK_CU(cuMemcpyHtoD(db, hb, BSZ * sizeof(uint16_t)));
    CHECK_CU(cuMemsetD8(dc_hexa, 0, CSZ * sizeof(float)));
    CHECK_CU(cuMemsetD8(dc_blas, 0, CSZ * sizeof(float)));

    /* cuBLAS handle + Tensor-Core compute mode (matches WMMA semantics). */
    cublasHandle_t handle;
    CHECK_BLAS(cublasCreate(&handle));
    /* Allow tensor cores (mirrors hexa-emit wmma.mma path). */
    CHECK_BLAS(cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH));

    /* ---- Numeric gate -- single fire of each, compare vs CPU ref ---- */
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc_hexa, &k_arg };
    CHECK_CU(cuLaunchKernel(f_hexa,
        /*gridX=*/ N / 64, /*gridY=*/ M / 64, /*gridZ=*/ 1,
        /*blockX=*/ 512, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    CHECK_CU(cuMemcpyDtoH(hc_hexa, dc_hexa, CSZ * sizeof(float)));

    float alpha = 1.0f, beta = 0.0f;
    /* C^T = B^T * A^T in col-major. See note above on layout trick. */
    CHECK_BLAS(cublasGemmEx(handle,
        CUBLAS_OP_N, CUBLAS_OP_N,
        N, M, K,
        &alpha,
        (void *)(uintptr_t)db, CUDA_R_16F, K,
        (void *)(uintptr_t)da, CUDA_R_16F, K,
        &beta,
        (void *)(uintptr_t)dc_blas, CUDA_R_32F, N,
        CUBLAS_COMPUTE_32F,
        CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CHECK_CU(cuCtxSynchronize());
    CHECK_CU(cuMemcpyDtoH(hc_blas, dc_blas, CSZ * sizeof(float)));

    /* Numeric verdict for hexa. */
    float max_abs_cref = 0.0f;
    for (int i = 0; i < CSZ; ++i) if (fabsf(cref[i]) > max_abs_cref) max_abs_cref = fabsf(cref[i]);
    float tol_abs = (max_abs_cref > 0.0f) ? max_abs_cref * 1e-2f : 1e-3f;

    float max_d_hexa = 0.0f, max_d_blas = 0.0f;
    int mism_hexa = 0, mism_blas = 0;
    for (int i = 0; i < CSZ; ++i) {
        float dh = fabsf(hc_hexa[i] - cref[i]);
        float db_= fabsf(hc_blas[i] - cref[i]);
        if (dh > max_d_hexa) max_d_hexa = dh;
        if (db_> max_d_blas) max_d_blas = db_;
        if (dh > tol_abs) ++mism_hexa;
        if (db_> tol_abs) ++mism_blas;
    }
    const char *verd_hexa = (mism_hexa == 0) ? "PASS" : "FAIL";
    const char *verd_blas = (mism_blas == 0) ? "PASS" : "FAIL";
    printf("Numeric gate: hexa=%s (max|d|=%g mism=%d/%d) cublas=%s (max|d|=%g mism=%d/%d) tol=%g max_ref=%g\n",
        verd_hexa, max_d_hexa, mism_hexa, CSZ,
        verd_blas, max_d_blas, mism_blas, CSZ,
        tol_abs, max_abs_cref);

    /* ---- Timing ---- */
    const int WARMUP = 10;
    const int REPS   = 1000;
    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    /* Hexa-emit warmup + timed. */
    for (int i = 0; i < WARMUP; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa,
            N / 64, M / 64, 1, 512, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());
    CHECK_RT(cudaEventRecord(ev_a, 0));
    for (int i = 0; i < REPS; ++i) {
        CHECK_CU(cuLaunchKernel(f_hexa,
            N / 64, M / 64, 1, 512, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_RT(cudaEventRecord(ev_b, 0));
    CHECK_RT(cudaEventSynchronize(ev_b));
    float ms_hexa_total = 0.0f;
    CHECK_RT(cudaEventElapsedTime(&ms_hexa_total, ev_a, ev_b));

    /* cuBLAS warmup + timed. */
    for (int i = 0; i < WARMUP; ++i) {
        CHECK_BLAS(cublasGemmEx(handle,
            CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha,
            (void *)(uintptr_t)db, CUDA_R_16F, K,
            (void *)(uintptr_t)da, CUDA_R_16F, K,
            &beta,
            (void *)(uintptr_t)dc_blas, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F,
            CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    }
    CHECK_CU(cuCtxSynchronize());
    CHECK_RT(cudaEventRecord(ev_a, 0));
    for (int i = 0; i < REPS; ++i) {
        CHECK_BLAS(cublasGemmEx(handle,
            CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha,
            (void *)(uintptr_t)db, CUDA_R_16F, K,
            (void *)(uintptr_t)da, CUDA_R_16F, K,
            &beta,
            (void *)(uintptr_t)dc_blas, CUDA_R_32F, N,
            CUBLAS_COMPUTE_32F,
            CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    }
    CHECK_RT(cudaEventRecord(ev_b, 0));
    CHECK_RT(cudaEventSynchronize(ev_b));
    float ms_blas_total = 0.0f;
    CHECK_RT(cudaEventElapsedTime(&ms_blas_total, ev_a, ev_b));

    double flops_per_call = 2.0 * (double)M * (double)N * (double)K;
    double total_flops    = flops_per_call * (double)REPS;
    double mean_ms_hexa   = ms_hexa_total / (double)REPS;
    double mean_ms_blas   = ms_blas_total / (double)REPS;
    double tflops_hexa    = total_flops / (ms_hexa_total / 1000.0) / 1e12;
    double tflops_blas    = total_flops / (ms_blas_total / 1000.0) / 1e12;
    double ratio          = tflops_hexa / tflops_blas;

    printf("Shape M=%d N=%d K=%d, reps=%d, warmup=%d\n", M, N, K, REPS, WARMUP);
    printf("hexa-emit WMMA   mean=%.4f ms  TFLOPS=%.4f\n", mean_ms_hexa, tflops_hexa);
    printf("cuBLAS GemmEx    mean=%.4f ms  TFLOPS=%.4f\n", mean_ms_blas, tflops_blas);
    printf("ratio hexa/cublas = %.4f  (cublas/hexa = %.4f)\n", ratio, 1.0/ratio);

    FILE *rj = fopen("result.json", "w");
    fprintf(rj, "{\n");
    fprintf(rj, "  \"rfc\": \"067-P5-perf-hgemm-vs-cublas\",\n");
    fprintf(rj, "  \"kernel\": \"wmma_256x256_grid\",\n");
    fprintf(rj, "  \"falsifier\": \"F-RFC067-PERF-HGEMM\",\n");
    fprintf(rj, "  \"shape\": {\"M\":%d,\"N\":%d,\"K\":%d},\n", M, N, K);
    fprintf(rj, "  \"reps\": %d,\n", REPS);
    fprintf(rj, "  \"warmup\": %d,\n", WARMUP);
    fprintf(rj, "  \"numeric\": {\n");
    fprintf(rj, "    \"hexa_verdict\": \"%s\",\n", verd_hexa);
    fprintf(rj, "    \"cublas_verdict\": \"%s\",\n", verd_blas);
    fprintf(rj, "    \"hexa_max_delta\": %g,\n", max_d_hexa);
    fprintf(rj, "    \"cublas_max_delta\": %g,\n", max_d_blas);
    fprintf(rj, "    \"tolerance\": %g,\n", tol_abs);
    fprintf(rj, "    \"max_abs_ref\": %g\n", max_abs_cref);
    fprintf(rj, "  },\n");
    fprintf(rj, "  \"timing\": {\n");
    fprintf(rj, "    \"hexa_total_ms\": %.6f,\n", ms_hexa_total);
    fprintf(rj, "    \"hexa_mean_ms\": %.6f,\n", mean_ms_hexa);
    fprintf(rj, "    \"hexa_tflops\": %.6f,\n", tflops_hexa);
    fprintf(rj, "    \"cublas_total_ms\": %.6f,\n", ms_blas_total);
    fprintf(rj, "    \"cublas_mean_ms\": %.6f,\n", mean_ms_blas);
    fprintf(rj, "    \"cublas_tflops\": %.6f,\n", tflops_blas);
    fprintf(rj, "    \"ratio_hexa_over_cublas\": %.6f,\n", ratio);
    fprintf(rj, "    \"ratio_cublas_over_hexa\": %.6f\n", 1.0/ratio);
    fprintf(rj, "  }\n");
    fprintf(rj, "}\n");
    fclose(rj);

    cudaEventDestroy(ev_a);
    cudaEventDestroy(ev_b);
    cublasDestroy(handle);
    cuMemFree(da); cuMemFree(db); cuMemFree(dc_hexa); cuMemFree(dc_blas);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);

    /* g3 honesty: exit 0 iff hexa numeric passed. cuBLAS verdict is informational
       (its 1e-2 vs CPU ref will of course PASS). */
    return (mism_hexa == 0) ? 0 : 1;
}
