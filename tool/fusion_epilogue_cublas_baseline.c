/* F-FUSION-EPILOGUE-GEMM-BIAS-GELU -- cuBLAS-using BASELINE host program.
 *
 * The cuBLAS-using stack that the fused hexa kernel undercuts. Computes the
 * SAME transformer-FFN epilogue:
 *
 *     C[m][n] = GeLU( (A @ B)[m][n] + bias[n] )
 *
 * but the way a cuBLAS-using NN stack is FORCED to: cuBLAS GEMM cannot fuse a
 * bias-add or an activation into its epilogue (cublasLt has limited
 * GELU_BIAS epilogue support but plain cublasSgemm / cublasGemmEx -- the
 * canonical NN-stack GEMM call -- does not), so the result round-trips HBM:
 *
 *   launch 1: cublasSgemm           -- writes the M x N GEMM result C to HBM
 *   launch 2: bias_add_kernel       -- reads C + bias from HBM, writes C to HBM
 *   launch 3: gelu_kernel           -- reads C from HBM, writes C to HBM
 *
 * = 3 kernel launches + 3x the M x N HBM write traffic.
 *
 * This file is the BASELINE the structural oracle counts against. The timed
 * silicon fire (wall-time vs the fused kernel) is DEFERRED to a serial
 * follow-up on ubu-2 (shared host -- parallel timed fires contend and poison
 * wall numbers). What this file establishes by construction is the launch
 * count (3) and the HBM write traffic (3 x M x N x 4 bytes).
 *
 * Build:  nvcc -O2 -o fusion_baseline fusion_epilogue_cublas_baseline.c -lcublas -lcudart
 * Run:    ./fusion_baseline M N K        (default 256 256 256)
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA error %s at %s:%d\n", \
        cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS error %d at %s:%d\n", \
        (int)s, __FILE__, __LINE__); return 1; }} while (0)

/* launch 2: separate bias-add kernel -- reads C[m][n], adds bias[n], writes C. */
__global__ void bias_add_kernel(float *C, const float *bias, int M, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = M * N;
    if (idx < total) {
        int n = idx % N;
        C[idx] = C[idx] + bias[n];   /* HBM read + HBM write */
    }
}

/* launch 3: separate GeLU kernel -- reads C, applies tanh-approx GeLU, writes C. */
__global__ void gelu_kernel(float *C, int M, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = M * N;
    if (idx < total) {
        float x = C[idx];            /* HBM read */
        float x3 = x * x * x;
        float t = 0.7978845608028654f * (x + 0.044715f * x3);
        float th = tanhf(t);
        C[idx] = 0.5f * x * (1.0f + th);  /* HBM write */
    }
}

int main(int argc, char **argv) {
    int M = (argc > 1) ? atoi(argv[1]) : 256;
    int N = (argc > 2) ? atoi(argv[2]) : 256;
    int K = (argc > 3) ? atoi(argv[3]) : 256;

    size_t szA = (size_t)M * K * sizeof(float);
    size_t szB = (size_t)K * N * sizeof(float);
    size_t szC = (size_t)M * N * sizeof(float);
    size_t szBias = (size_t)N * sizeof(float);

    float *hA = (float *)malloc(szA);
    float *hB = (float *)malloc(szB);
    float *hBias = (float *)malloc(szBias);
    float *hC = (float *)malloc(szC);
    for (int i = 0; i < M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
    for (int i = 0; i < K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;
    for (int i = 0; i < N; ++i)     hBias[i] = (float)((i % 3) - 1) * 0.5f;

    float *dA, *dB, *dBias, *dC;
    CK(cudaMalloc(&dA, szA));
    CK(cudaMalloc(&dB, szB));
    CK(cudaMalloc(&dBias, szBias));
    CK(cudaMalloc(&dC, szC));
    CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dBias, hBias, szBias, cudaMemcpyHostToDevice));

    cublasHandle_t h;
    CB(cublasCreate(&h));

    /* C (row-major M x N) = A (row-major M x K) @ B (row-major K x N).
       cuBLAS is column-major; compute C^T = B^T @ A^T by swapping operands:
       cublasSgemm(N,N, N, M, K, &alpha, dB(N x K col-maj = B row-maj), N,
       dA(K x M col-maj = A row-maj), K, &beta, dC(N x M col-maj = C row-maj), N). */
    const float alpha = 1.0f, beta = 0.0f;

    /* ===== launch 1: cuBLAS GEMM -- writes M x N result C to HBM ===== */
    CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                   &alpha, dB, N, dA, K, &beta, dC, N));

    /* ===== launch 2: bias-add kernel -- reads+writes C in HBM ===== */
    int total = M * N;
    int threads = 256;
    int blocks = (total + threads - 1) / threads;
    bias_add_kernel<<<blocks, threads>>>(dC, dBias, M, N);

    /* ===== launch 3: GeLU kernel -- reads+writes C in HBM ===== */
    gelu_kernel<<<blocks, threads>>>(dC, M, N);

    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hC, dC, szC, cudaMemcpyDeviceToHost));

    /* f64 CPU reference. */
    double max_rel = 0.0, max_abs = 0.0;
    int checked = 0;
    int step = (total > 4096) ? (total / 4096) : 1;  /* sample to keep CPU ref cheap */
    for (int idx = 0; idx < total; idx += step) {
        int m = idx / N, n = idx % N;
        double acc = 0.0;
        for (int k = 0; k < K; ++k)
            acc += (double)hA[m * K + k] * (double)hB[k * N + n];
        double x = acc + (double)hBias[n];
        double t = 0.7978845608028654 * (x + 0.044715 * x * x * x);
        double g = 0.5 * x * (1.0 + tanh(t));
        double d = fabs((double)hC[idx] - g);
        double rel = d / (fabs(g) + 1e-6);
        if (d > max_abs) max_abs = d;
        if (rel > max_rel) max_rel = rel;
        ++checked;
    }

    const char *verd = (max_rel <= 1e-2) ? "PASS" : "FAIL";
    printf("F-FUSION-EPILOGUE-GEMM-BIAS-GELU baseline %s -- shape M=%d N=%d K=%d "
           "launches=3 hbm_C_writes=3 max_rel=%g max_abs=%g checked=%d/%d\n",
           verd, M, N, K, max_rel, max_abs, checked, total);

    cublasDestroy(h);
    cudaFree(dA); cudaFree(dB); cudaFree(dBias); cudaFree(dC);
    free(hA); free(hB); free(hBias); free(hC);
    return (max_rel <= 1e-2) ? 0 : 1;
}
