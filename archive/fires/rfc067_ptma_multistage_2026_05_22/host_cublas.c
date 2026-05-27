/* cuBLAS HGEMM reference for cliff-regime shapes.
 * Uses cublasGemmEx so it builds as plain C (no __half type).
 * Args: ./host_cublas M K N [reps]
 * cuBLAS is column-major. We pass A as fp16 (CUDA_R_16F), B fp16, accumulate
 * f32, output fp16. alpha=1, beta=0.
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

static uint16_t f32_to_f16(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    uint32_t sign  = (x >> 16) & 0x8000;
    int32_t  exp   = ((x >> 23) & 0xff) - 127 + 15;
    uint32_t mant  =  x & 0x7fffff;
    if (exp <= 0)        return (uint16_t)sign;
    if (exp >= 31)       return (uint16_t)(sign | 0x7c00);
    return (uint16_t)(sign | (exp << 10) | (mant >> 13));
}

#define CHK_RT(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "rt err: %s\n", cudaGetErrorString(e)); return 1; }} while (0)

#define CHK_BL(call) do { cublasStatus_t e = (call); \
    if (e != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "blas err %d\n", (int)e); return 1; }} while (0)

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s M K N [REPS]\n", argv[0]); return 2; }
    int M = atoi(argv[1]);
    int K = atoi(argv[2]);
    int N = atoi(argv[3]);
    int reps = (argc >= 5) ? atoi(argv[4]) : 32;

    size_t a_bytes = (size_t)M * K * 2;
    size_t b_bytes = (size_t)K * N * 2;
    size_t c_bytes = (size_t)M * N * 2;

    uint16_t *ha = (uint16_t*)malloc(a_bytes);
    uint16_t *hb = (uint16_t*)malloc(b_bytes);
    for (size_t i = 0; i < (size_t)M*K; ++i) ha[i] = f32_to_f16((float)(i%13)/16.0f);
    for (size_t i = 0; i < (size_t)K*N; ++i) hb[i] = f32_to_f16((float)((i*7)%17)/16.0f);

    void *da, *db, *dc;
    CHK_RT(cudaMalloc(&da, a_bytes));
    CHK_RT(cudaMalloc(&db, b_bytes));
    CHK_RT(cudaMalloc(&dc, c_bytes));
    CHK_RT(cudaMemcpy(da, ha, a_bytes, cudaMemcpyHostToDevice));
    CHK_RT(cudaMemcpy(db, hb, b_bytes, cudaMemcpyHostToDevice));
    CHK_RT(cudaMemset(dc, 0, c_bytes));

    cublasHandle_t h; CHK_BL(cublasCreate(&h));

    /* Use f32 alpha/beta with cublasGemmEx to avoid needing __half on host. */
    float alpha = 1.0f, beta = 0.0f;

    /* warmup */
    for (int w = 0; w < 3; ++w) {
        CHK_BL(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N,
                            M, N, K,
                            &alpha,
                            da, CUDA_R_16F, M,
                            db, CUDA_R_16F, K,
                            &beta,
                            dc, CUDA_R_16F, M,
                            CUBLAS_COMPUTE_32F,
                            CUBLAS_GEMM_DEFAULT));
    }
    CHK_RT(cudaDeviceSynchronize());

    cudaEvent_t s, e;
    cudaEventCreate(&s); cudaEventCreate(&e);
    cudaEventRecord(s, 0);
    for (int r = 0; r < reps; ++r) {
        CHK_BL(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N,
                            M, N, K,
                            &alpha,
                            da, CUDA_R_16F, M,
                            db, CUDA_R_16F, K,
                            &beta,
                            dc, CUDA_R_16F, M,
                            CUBLAS_COMPUTE_32F,
                            CUBLAS_GEMM_DEFAULT));
    }
    cudaEventRecord(e, 0);
    cudaEventSynchronize(e);
    float ms_total = 0;
    cudaEventElapsedTime(&ms_total, s, e);
    float ms = ms_total / (float)reps;
    double flops = 2.0 * (double)M * (double)N * (double)K;
    double tflops = (flops / (ms * 1e-3)) / 1.0e12;

    printf("{\n");
    printf("  \"backend\": \"cublasGemmEx_R16F_C32F\",\n");
    printf("  \"M\": %d, \"K\": %d, \"N\": %d, \"reps\": %d,\n", M, K, N, reps);
    printf("  \"ms_per_launch\": %f,\n", ms);
    printf("  \"tflops\": %f\n", tflops);
    printf("}\n");

    cublasDestroy(h);
    cudaFree(da); cudaFree(db); cudaFree(dc);
    free(ha); free(hb);
    return 0;
}
