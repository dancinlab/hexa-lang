/* F-FUSION-ATTN-WMMA-WALL -- cuBLAS Tensor-Core baseline (the stack to beat).
 *
 * The canonical non-fused attention path a cuBLAS-using stack runs, with the
 * inner GEMMs on TENSOR CORES (the fair round-3 baseline -- round 1 used FP32
 * SGEMM; the WMMA fused kernel must beat the cuBLAS TC path):
 *   L1  cublasGemmEx (CUBLAS_GEMM_DEFAULT_TENSOR_OP, f16 in / f32 acc)
 *         S = Q K^T * scale          -> S (N x N) written to HBM
 *   L2  standalone row-softmax kernel S = softmax_row(S)   -> reads + writes S
 *   L3  cublasGemmEx (TENSOR_OP)      O = softmax(S) . V    -> reads S
 * 3 launches + O(N^2) S materialization to HBM -- exactly what the fused WMMA
 * kernel structurally avoids while ALSO running its inner GEMMs on TCs.
 * Times the WHOLE 3-launch sequence with cudaEvent: 20 warmup + 200 timed.
 *
 * Build:  nvcc -O2 -x cu -o fa_cublas_tc_baseline fa_cublas_tc_baseline.c -lcublas -lcudart
 * Run:    ./fa_cublas_tc_baseline [N]   (d fixed = 64)
 *
 * THIS BASELINE IS READY FOR ROUND 3 -- run serially against fa_wmma_host to
 * compute the wall ratio. Do NOT run timed in the codegen round.
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA err %s at %s:%d\n", cudaGetErrorString(e), __FILE__, __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS err %d at %s:%d\n", (int)s, __FILE__, __LINE__); return 1; }} while (0)

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}
static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void) {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    return ((float)(lcg_state >> 8) / (float)(1u << 24)) - 0.5f;
}

/* Row-softmax over an N x N f16 score matrix S (in place), one row per block. */
__global__ void softmax_rows(__half *S, int N) {
    int row = blockIdx.x;
    if (row >= N) return;
    extern __shared__ float buf[];
    int t = threadIdx.x, nt = blockDim.x;
    float m = -1e30f;
    for (int j = t; j < N; j += nt) { float v = __half2float(S[(size_t)row*N+j]); if (v > m) m = v; }
    buf[t] = m; __syncthreads();
    for (int s = nt/2; s > 0; s >>= 1) { if (t < s && buf[t+s] > buf[t]) buf[t] = buf[t+s]; __syncthreads(); }
    float rmax = buf[0]; __syncthreads();
    float sum = 0.0f;
    for (int j = t; j < N; j += nt) { float e = expf(__half2float(S[(size_t)row*N+j]) - rmax); S[(size_t)row*N+j] = __float2half(e); sum += e; }
    buf[t] = sum; __syncthreads();
    for (int s = nt/2; s > 0; s >>= 1) { if (t < s) buf[t] += buf[t+s]; __syncthreads(); }
    float rsum = buf[0]; float inv = 1.0f / rsum; __syncthreads();
    for (int j = t; j < N; j += nt) S[(size_t)row*N+j] = __float2half(__half2float(S[(size_t)row*N+j]) * inv);
}

int main(int argc, char **argv) {
    int N = (argc > 1) ? atoi(argv[1]) : 2048;
    int d = 64;
    cublasHandle_t h; CB(cublasCreate(&h));
    CB(cublasSetMathMode(h, CUBLAS_TENSOR_OP_MATH));

    size_t elems = (size_t)N * d;
    __half *hq = (__half*)malloc(elems*sizeof(__half));
    __half *hk = (__half*)malloc(elems*sizeof(__half));
    __half *hv = (__half*)malloc(elems*sizeof(__half));
    for (size_t i=0;i<elems;++i) hq[i]=__float2half(lcg_f32()*4.0f);
    for (size_t i=0;i<elems;++i) hk[i]=__float2half(lcg_f32()*4.0f);
    for (size_t i=0;i<elems;++i) hv[i]=__float2half(lcg_f32());
    float scale = 1.0f/sqrtf((float)d);

    __half *dq,*dk,*dv,*dS,*dO;
    CK(cudaMalloc(&dq, elems*sizeof(__half)));
    CK(cudaMalloc(&dk, elems*sizeof(__half)));
    CK(cudaMalloc(&dv, elems*sizeof(__half)));
    CK(cudaMalloc(&dS, (size_t)N*N*sizeof(__half)));
    CK(cudaMalloc(&dO, elems*sizeof(__half)));
    CK(cudaMemcpy(dq, hq, elems*sizeof(__half), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dk, hk, elems*sizeof(__half), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dv, hv, elems*sizeof(__half), cudaMemcpyHostToDevice));

    float alpha = scale, beta = 0.0f, one = 1.0f;
    int smblk = 256; size_t smbytes = smblk*sizeof(float);

    /* one 3-launch attention sequence (column-major cuBLAS conventions):
       S = Q K^T : treat as S^T = K Q^T so cublas col-major lands row-major S.
       Use cublasGemmEx with op handling; details validated at round 3 fire. */
    #define SEQ() do { \
        CB(cublasGemmEx(h, CUBLAS_OP_T, CUBLAS_OP_N, N, N, d, &alpha, \
            dk, CUDA_R_16F, d, dq, CUDA_R_16F, d, &beta, \
            dS, CUDA_R_16F, N, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP)); \
        softmax_rows<<<N, smblk, smbytes>>>(dS, N); \
        CB(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, d, N, N, &one, \
            dv, CUDA_R_16F, d, dS, CUDA_R_16F, N, &beta, \
            dO, CUDA_R_16F, d, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP)); \
    } while (0)

    for (int w=0; w<20; ++w) SEQ();
    CK(cudaDeviceSynchronize());

    cudaEvent_t st,en; CK(cudaEventCreate(&st)); CK(cudaEventCreate(&en));
    int reps=200; double *ms=(double*)malloc(reps*sizeof(double));
    for (int r=0;r<reps;++r){
        CK(cudaEventRecord(st,0));
        SEQ();
        CK(cudaEventRecord(en,0));
        CK(cudaEventSynchronize(en));
        float t; CK(cudaEventElapsedTime(&t,st,en)); ms[r]=(double)t;
    }
    qsort(ms,reps,sizeof(double),cmp_double);
    printf("cublas_tc_3launch median_ms=%.6f  (N=%d d=%d, 20 warmup + %d timed)\n", ms[reps/2], N, d, reps);
    cublasDestroy(h);
    return 0;
}
