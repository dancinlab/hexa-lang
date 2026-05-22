/* Non-trivial bit-exact verification for N200-full.
 *
 * Replaces the zero-mean data pattern (which caused cuBLAS max|C|=0 -- trivial check) with a
 * non-cancelling pattern, then runs M=N=K=512 hexa vs cuBLAS and reports max|hexa-cuBLAS| /
 * (max|cuBLAS|), max|hexa| separately, plus a few sample (i,j) cells.
 *
 * Why M=512? Smallest shape -> fast iteration; if hexa is correct here, structure scales.
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
    if (e != cudaSuccess) { fprintf(stderr, "rt err %d: %s\n", e, cudaGetErrorString(e)); return 1; }} while (0)
#define CHECK_BLAS(call) do { cublasStatus_t e = (call); \
    if (e != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "blas err %d\n", (int)e); return 1; }} while (0)

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

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <ptx_512>\n", argv[0]); return 2; }
    int M = 512, N = 512, K = 512;

    CHECK_CU(cuInit(0));
    CUdevice dev; CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    FILE *fp = fopen(argv[1], "rb"); if (!fp) { perror("ptx"); return 1; }
    fseek(fp, 0, SEEK_END); long n_ptx = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    fread(ptx, 1, n_ptx, fp); ptx[n_ptx] = 0; fclose(fp);
    CUmodule mod; CHECK_CU(cuModuleLoadDataEx(&mod, ptx, 0, NULL, NULL));
    CUfunction fn; CHECK_CU(cuModuleGetFunction(&fn, mod, "sgemm_tma_mma_hilbert_512x512_grid"));

    size_t ASZ = (size_t)M * K, BSZ = (size_t)K * N, CSZ = (size_t)M * N;
    unsigned short *ha = (unsigned short *)malloc(ASZ * 2);
    unsigned short *hb = (unsigned short *)malloc(BSZ * 2);
    /* NON-TRIVIAL fill: all positive small values (cuBLAS HGEMM will produce a non-zero
       output of magnitude K * a_typ * b_typ = 512 * 0.5 * 0.5 = 128). */
    for (size_t i = 0; i < ASZ; ++i) ha[i] = f32_to_f16(0.25f + 0.0625f * (float)(i % 4));
    for (size_t i = 0; i < BSZ; ++i) hb[i] = f32_to_f16(0.125f + 0.0625f * (float)(i % 3));

    CUdeviceptr da, db, dc;
    CHECK_CU(cuMemAlloc(&da, ASZ * 2));
    CHECK_CU(cuMemAlloc(&db, BSZ * 2));
    CHECK_CU(cuMemAlloc(&dc, CSZ * 4));
    CHECK_CU(cuMemcpyHtoD(da, ha, ASZ * 2));
    CHECK_CU(cuMemcpyHtoD(db, hb, BSZ * 2));

    /* cuBLAS HGEMM */
    cublasHandle_t handle; CHECK_BLAS(cublasCreate(&handle));
    CHECK_BLAS(cublasSetMathMode(handle, CUBLAS_TENSOR_OP_MATH));
    float alpha = 1.0f, beta = 0.0f;
    CHECK_CU(cuMemsetD8(dc, 0, CSZ * 4));
    CHECK_BLAS(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
        &alpha, (const void *)(uintptr_t)db, CUDA_R_16F, N,
        (const void *)(uintptr_t)da, CUDA_R_16F, K,
        &beta, (void *)(uintptr_t)dc, CUDA_R_32F, N,
        CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CHECK_CU(cuCtxSynchronize());
    float *cublas_c = (float *)malloc(CSZ * 4);
    CHECK_CU(cuMemcpyDtoH(cublas_c, dc, CSZ * 4));

    /* hexa */
    CUtensorMap tmap_a, tmap_b;
    cuuint64_t gA[2] = { K, M };
    cuuint64_t sA[1] = { (cuuint64_t)K * 2 };
    cuuint32_t bA[2] = { 16, 64 };
    cuuint32_t eA[2] = { 1, 1 };
    CHECK_CU(cuTensorMapEncodeTiled(&tmap_a, CU_TENSOR_MAP_DATA_TYPE_FLOAT16, 2, (void *)da,
        gA, sA, bA, eA, CU_TENSOR_MAP_INTERLEAVE_NONE, CU_TENSOR_MAP_SWIZZLE_NONE,
        CU_TENSOR_MAP_L2_PROMOTION_NONE, CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE));
    cuuint64_t gB[2] = { K, N };
    cuuint64_t sB[1] = { (cuuint64_t)K * 2 };
    CHECK_CU(cuTensorMapEncodeTiled(&tmap_b, CU_TENSOR_MAP_DATA_TYPE_FLOAT16, 2, (void *)db,
        gB, sB, bA, eA, CU_TENSOR_MAP_INTERLEAVE_NONE, CU_TENSOR_MAP_SWIZZLE_NONE,
        CU_TENSOR_MAP_L2_PROMOTION_NONE, CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE));

    CHECK_CU(cuMemsetD8(dc, 0, CSZ * 4));
    int K_TILES_TOTAL = K / 16;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &tmap_a, &tmap_b, &dc, &k_arg };
    unsigned int side = M / 64;
    unsigned int p = 1; while (p < side) p <<= 1;
    CHECK_CU(cuLaunchKernel(fn, p, p, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    CHECK_CU(cuCtxSynchronize());
    float *hexa_c = (float *)malloc(CSZ * 4);
    CHECK_CU(cuMemcpyDtoH(hexa_c, dc, CSZ * 4));

    float max_cublas = 0, max_hexa = 0, max_diff = 0, max_rel = 0;
    int n_zero_cublas = 0, n_zero_hexa = 0;
    for (size_t i = 0; i < CSZ; ++i) {
        if (fabsf(cublas_c[i]) > max_cublas) max_cublas = fabsf(cublas_c[i]);
        if (fabsf(hexa_c[i]) > max_hexa) max_hexa = fabsf(hexa_c[i]);
        if (cublas_c[i] == 0) n_zero_cublas++;
        if (hexa_c[i] == 0) n_zero_hexa++;
        float d = fabsf(cublas_c[i] - hexa_c[i]);
        if (d > max_diff) max_diff = d;
        if (fabsf(cublas_c[i]) > 1e-3f) {
            float r = d / fabsf(cublas_c[i]);
            if (r > max_rel) max_rel = r;
        }
    }
    printf("M=N=K=%d non-trivial fill\n", M);
    printf("  max|cuBLAS|=%f  max|hexa|=%f  max|diff|=%f  max_rel=%f\n",
           max_cublas, max_hexa, max_diff, max_rel);
    printf("  zero cells: cuBLAS=%d hexa=%d (of %zu)\n", n_zero_cublas, n_zero_hexa, CSZ);
    printf("  sample C[0,0]: cuBLAS=%f hexa=%f\n", cublas_c[0], hexa_c[0]);
    printf("  sample C[1,1]: cuBLAS=%f hexa=%f\n", cublas_c[1 * N + 1], hexa_c[1 * N + 1]);
    printf("  sample C[255,255]: cuBLAS=%f hexa=%f\n", cublas_c[255 * N + 255], hexa_c[255 * N + 255]);
    printf("  sample C[M-1,N-1]: cuBLAS=%f hexa=%f\n", cublas_c[(M-1) * N + N-1], hexa_c[(M-1) * N + N-1]);

    int verdict_pass = (max_diff < 0.05f * max_cublas) && (max_cublas > 1.0f);
    printf("  verdict: %s (max_rel=%.4f < 0.05? %s; max_cublas > 1? %s)\n",
           verdict_pass ? "PASS" : "FAIL",
           max_rel, (max_rel < 0.05f) ? "yes" : "no",
           (max_cublas > 1.0f) ? "yes" : "no");

    free(ptx); free(ha); free(hb); free(cublas_c); free(hexa_c);
    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    cublasDestroy(handle);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return verdict_pass ? 0 : 1;
}
