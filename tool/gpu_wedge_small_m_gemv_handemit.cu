/* gpu_wedge_small_m_gemv_handemit — F-WEDGE-SMALL-M-GEMV-WALL fire.
 *
 * Pre-registered falsifier (GPU.log.md 2026-05-27 ranked-wedge #1):
 *   hexa-native hand-emit GEMV vs cuBLAS SGEMM at M in {1, 8, 32}, K=N=4096.
 *
 * Context: cuBLAS at M=1 sustains only 0.30 TFLOPS = 0.95% of sm_120 FP32 peak
 * (31.2 TFLOPS). vLLM/llama.cpp ship custom GEMV CUDA kernels because cuBLAS
 * SGEMM is tile-shape-bound when M is too small. This fire asks: can a plain
 * hand-emit GEMV warp-reduce + broadcast kernel beat cuBLAS at small M?
 *
 * Strategy (v3, float4-vectorised B loads):
 *   - Each CTA owns CTA_N_COLS = 16 output columns.
 *   - CTA has 4 warps = 128 threads. Each warp processes 4 columns.
 *   - Within a warp, lanes stripe across K in groups of WARP_SIZE.
 *   - B is loaded via float4 (128-bit) — each lane reads B[k, n4_base + 0..3]
 *     at once, giving 4 partial sums per lane (one per warp-owned column).
 *   - A[m, k] is broadcast through shared mem (loaded once per K-chunk).
 *
 * For M > 1 the kernel loops over M reusing the same B reads. The total B
 * read volume stays at K*N*4 = 67 MB regardless of M, so the kernel
 * smoothly transitions from BW-bound (M=1) to compute-bound (M>1).
 *
 * Verdict rubric (g5):
 *   GREEN (SUPPORTED-NUMERICAL) if handemit >= 1.5x cuBLAS at M=1.
 *   RED   (FALSIFIED)           if handemit <  1.05x cuBLAS at M=1.
 *
 * Build: nvcc -O3 -arch=compute_90 -code=compute_90 \
 *               gpu_wedge_small_m_gemv_handemit.cu -lcublas \
 *               -o gpu_wedge_small_m_gemv_handemit
 *
 * The compute_90 PTX is driver-JIT'd to sm_120 on RTX 5070 host
 * (reference_gpu_fire_infra.md). Pure-ASCII source.
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA error %s at %s:%d\n", \
        cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS err %d at %s:%d\n", \
        (int)s, __FILE__, __LINE__); return 1; }} while (0)

static const double PEAK_FP32_TFLOPS = 31.2;

#define WARP_SIZE 32
#define CTA_WARPS 4
#define CTA_THREADS (WARP_SIZE * CTA_WARPS)
#define COLS_PER_WARP 4               /* via float4 vectorised B loads */
#define CTA_N_COLS (CTA_WARPS * COLS_PER_WARP)  /* 16 output cols per CTA */
#define K_CHUNK 128                   /* shared-mem A-tile size */

/* Hand-emit GEMV/GEMM-skinny kernel with float4 B loads.
 *   C[m,n] = sum_k A[m,k] * B[k,n]
 *   A is M*K row-major, B is K*N row-major, C is M*N row-major.
 *
 * Grid: dim3(N / CTA_N_COLS, 1, 1)
 * Block: dim3(WARP_SIZE, CTA_WARPS, 1)
 *
 * Warp w in CTA cx owns output cols [cx*CTA_N_COLS + w*COLS_PER_WARP,
 *                                    cx*CTA_N_COLS + (w+1)*COLS_PER_WARP).
 * Lane L in warp w accumulates 4 partial sums (one per warp-owned column);
 * within a K-chunk lanes stride by WARP_SIZE reading float4 from B.
 */
__global__ void gemv_warpreduce_kernel(
    const float * __restrict__ A,
    const float * __restrict__ B,
    float * __restrict__ C,
    int M, int K, int N)
{
    __shared__ float sA[K_CHUNK];

    const int warp_id = threadIdx.y;
    const int lane    = threadIdx.x;
    const int tid     = warp_id * WARP_SIZE + lane;
    const int n_base  = blockIdx.x * CTA_N_COLS + warp_id * COLS_PER_WARP;

    if (n_base >= N) return;

    for (int m = 0; m < M; ++m) {
        float acc0 = 0.0f, acc1 = 0.0f, acc2 = 0.0f, acc3 = 0.0f;
        for (int k0 = 0; k0 < K; k0 += K_CHUNK) {
            /* cooperatively load A[m, k0:k0+K_CHUNK] into sA. */
            for (int j = tid; j < K_CHUNK; j += CTA_THREADS) {
                sA[j] = A[m * K + k0 + j];
            }
            __syncthreads();
            /* lanes stripe through K_CHUNK; each loads a float4 of B. */
            for (int k = lane; k < K_CHUNK; k += WARP_SIZE) {
                float a = sA[k];
                /* B row pointer for this K-slice. n_base is float4-aligned by
                 * construction (CTA_N_COLS=16, COLS_PER_WARP=4 -> n_base %4 ==0). */
                const float *brow = B + (k0 + k) * N + n_base;
                float4 b4 = *reinterpret_cast<const float4 *>(brow);
                acc0 += a * b4.x;
                acc1 += a * b4.y;
                acc2 += a * b4.z;
                acc3 += a * b4.w;
            }
            __syncthreads();
        }
        /* warp-reduce 4 lanes-worth of partials in parallel. */
        for (int offset = WARP_SIZE / 2; offset > 0; offset >>= 1) {
            acc0 += __shfl_xor_sync(0xffffffff, acc0, offset);
            acc1 += __shfl_xor_sync(0xffffffff, acc1, offset);
            acc2 += __shfl_xor_sync(0xffffffff, acc2, offset);
            acc3 += __shfl_xor_sync(0xffffffff, acc3, offset);
        }
        if (lane == 0) {
            float *crow = C + m * N + n_base;
            /* float4 store (n_base aligned by construction). */
            float4 out = {acc0, acc1, acc2, acc3};
            *reinterpret_cast<float4 *>(crow) = out;
        }
    }
}

static int cmp_d(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

static int run_one_M(cublasHandle_t h, int M, int K, int N,
                     double *out_cublas_ms, double *out_handemit_ms,
                     double *out_max_abs_err)
{
    size_t szA = (size_t)M * K * sizeof(float);
    size_t szB = (size_t)K * N * sizeof(float);
    size_t szC = (size_t)M * N * sizeof(float);

    float *hA = (float *)malloc(szA);
    float *hB = (float *)malloc(szB);
    float *hC_ref = (float *)malloc(szC);
    float *hC_he  = (float *)malloc(szC);

    for (long i = 0; i < (long)M * K; ++i) hA[i] = (float)((i % 7) - 3) * 0.1f;
    for (long i = 0; i < (long)K * N; ++i) hB[i] = (float)((i % 5) - 2) * 0.1f;

    float *dA, *dB, *dC_ref, *dC_he;
    CK(cudaMalloc((void **)&dA, szA));
    CK(cudaMalloc((void **)&dB, szB));
    CK(cudaMalloc((void **)&dC_ref, szC));
    CK(cudaMalloc((void **)&dC_he,  szC));
    CK(cudaMemcpy(dA, hA, szA, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, szB, cudaMemcpyHostToDevice));

    float alpha = 1.0f, beta = 0.0f;
    const int WARMUP = 20, ITERS = 200;
    double *samples = (double *)malloc(ITERS * sizeof(double));

    /* cuBLAS baseline. */
    for (int i = 0; i < WARMUP; ++i) {
        CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                       &alpha, dB, N, dA, K, &beta, dC_ref, N));
    }
    CK(cudaDeviceSynchronize());

    cudaEvent_t e0, e1;
    CK(cudaEventCreate(&e0));
    CK(cudaEventCreate(&e1));
    for (int i = 0; i < ITERS; ++i) {
        CK(cudaEventRecord(e0, 0));
        CB(cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
                       &alpha, dB, N, dA, K, &beta, dC_ref, N));
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms;
        CK(cudaEventElapsedTime(&ms, e0, e1));
        samples[i] = (double)ms;
    }
    qsort(samples, ITERS, sizeof(double), cmp_d);
    *out_cublas_ms = samples[ITERS / 2];

    /* hand-emit kernel. */
    dim3 grid((N + CTA_N_COLS - 1) / CTA_N_COLS, 1, 1);
    dim3 block(WARP_SIZE, CTA_WARPS, 1);

    for (int i = 0; i < WARMUP; ++i) {
        gemv_warpreduce_kernel<<<grid, block>>>(dA, dB, dC_he, M, K, N);
    }
    CK(cudaDeviceSynchronize());
    CK(cudaGetLastError());

    for (int i = 0; i < ITERS; ++i) {
        CK(cudaEventRecord(e0, 0));
        gemv_warpreduce_kernel<<<grid, block>>>(dA, dB, dC_he, M, K, N);
        CK(cudaEventRecord(e1, 0));
        CK(cudaEventSynchronize(e1));
        float ms;
        CK(cudaEventElapsedTime(&ms, e0, e1));
        samples[i] = (double)ms;
    }
    qsort(samples, ITERS, sizeof(double), cmp_d);
    *out_handemit_ms = samples[ITERS / 2];

    /* numerical check. */
    CK(cudaMemcpy(hC_ref, dC_ref, szC, cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hC_he,  dC_he,  szC, cudaMemcpyDeviceToHost));
    double max_abs = 0.0;
    for (long i = 0; i < (long)M * N; ++i) {
        double d = (double)hC_he[i] - (double)hC_ref[i];
        if (d < 0) d = -d;
        if (d > max_abs) max_abs = d;
    }
    *out_max_abs_err = max_abs;

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    free(samples);
    cudaFree(dA); cudaFree(dB); cudaFree(dC_ref); cudaFree(dC_he);
    free(hA); free(hB); free(hC_ref); free(hC_he);
    return 0;
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    const int M_vals[] = {1, 8, 32};
    const int n_M = sizeof(M_vals) / sizeof(M_vals[0]);
    const int K = 4096, N = 4096;

    printf("# F-WEDGE-SMALL-M-GEMV-WALL -- hand-emit GEMV vs cuBLAS (RTX 5070 sm_120)\n");
    printf("# Peak FP32 = %.2f TFLOPS, K=%d N=%d, cuEvent 20 warmup + 200 timed median\n",
           PEAK_FP32_TFLOPS, K, N);
    printf("# CTA: %d warps x %d threads, %d cols/CTA, K_CHUNK=%d, float4 B loads\n",
           CTA_WARPS, WARP_SIZE, CTA_N_COLS, K_CHUNK);
    printf("# M  cuBLAS_ms  handemit_ms  handemit_TFLOPS  speedup_x  sub_roofline_pct  max_abs_err\n");

    cublasHandle_t h;
    CB(cublasCreate(&h));

    for (int i = 0; i < n_M; ++i) {
        int M = M_vals[i];
        double cublas_ms = 0.0, he_ms = 0.0, err = 0.0;
        if (run_one_M(h, M, K, N, &cublas_ms, &he_ms, &err) != 0) {
            fprintf(stderr, "run failed at M=%d\n", M);
            return 2;
        }
        double flops = 2.0 * (double)M * (double)N * (double)K;
        double he_tflops = flops / (he_ms * 1e-3) * 1e-12;
        double speedup   = cublas_ms / he_ms;
        double sub_rl    = 100.0 * (1.0 - he_tflops / PEAK_FP32_TFLOPS);
        printf("%-5d %.6f  %.6f  %8.3f         %7.3fx  %6.2f%%  %.3e\n",
               M, cublas_ms, he_ms, he_tflops, speedup, sub_rl, err);
    }

    cublasDestroy(h);
    return 0;
}
