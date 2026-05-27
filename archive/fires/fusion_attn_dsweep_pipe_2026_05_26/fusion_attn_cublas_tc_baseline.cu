/* R11 cuBLAS-TC FP16 baseline -- the STRONGEST cuBLAS attention stack, matching
 * the math precision of the FP16 Tensor-Core fused kernel (fair apples-to-apples
 * comparison; this is the "cuBLAS-stack" the R8/R10 verdicts compared against).
 *
 * 3-launch non-fused attention path on Tensor Cores:
 *   L1  cublasGemmStridedBatchedEx  S = scale * Q K^T  (FP16 in, FP16 out, TC)
 *   L2  OPTIMIZED block-per-row softmax kernel (parallel reduction, coalesced)
 *   L3  cublasGemmStridedBatchedEx  O = softmax(S) . V  (FP16 in, FP16 out, TC)
 * 3 kernel launches + O(N^2) FP16 S materialization to HBM. Exactly the stack
 * the fused flash-attention kernel structurally avoids.
 *
 * The softmax is a FAIR optimized kernel: one BLOCK (256 threads) per row, each
 * thread strides over the row, block-wide max + sum via shared-mem reduction,
 * coalesced loads/stores. (A naive one-thread-per-row softmax is a 13x-slower
 * strawman that would falsely inflate any "fused beats cuBLAS" claim -- rejected.)
 *
 * FP16 inputs/outputs (CUDA_R_16F), COMPUTE_32F accumulate, GEMM_DEFAULT_TENSOR_OP
 * -> uses Tensor Cores. Same LCG inputs + same f64 CPU reference + per-row-scaled
 * rel-err as the fused host. cudaEvent: 20 warmup + 200 timed median.
 *
 * Build:  nvcc -O2 -x cu -arch=sm_90a -o fa_cublas_tc fusion_attn_cublas_tc_baseline.cu -lcublas -lcudart
 * Run:    ./fa_cublas_tc [N] [d]
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>

#define CK(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { fprintf(stderr, "CUDA err %s at %d\n", cudaGetErrorString(e), __LINE__); return 1; }} while (0)
#define CB(call) do { cublasStatus_t s = (call); \
    if (s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "cuBLAS err %d at %d\n", (int)s, __LINE__); return 1; }} while (0)

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}
static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void) {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    return ((float)(lcg_state >> 8) / (float)(1u << 24)) - 0.5f;
}

/* FAIR optimized softmax: one block (BLK threads) per row, parallel reduction. */
#define SBLK 256
__global__ void softmax_rows_h(__half *S, int N, int rowlen) {
    int row = blockIdx.x;
    if (row >= N) return;
    __half *r = S + (size_t)row * rowlen;
    int t = threadIdx.x;
    __shared__ float red[SBLK];

    /* pass 1: block-wide max (coalesced strided loads) */
    float m = -3.4e38f;
    for (int j = t; j < rowlen; j += SBLK) { float x = __half2float(r[j]); if (x > m) m = x; }
    red[t] = m; __syncthreads();
    for (int s = SBLK/2; s > 0; s >>= 1) { if (t < s) red[t] = fmaxf(red[t], red[t+s]); __syncthreads(); }
    float rmax = red[0]; __syncthreads();

    /* pass 2: exp + block-wide sum */
    float l = 0.0f;
    for (int j = t; j < rowlen; j += SBLK) { float e = __expf(__half2float(r[j]) - rmax); r[j] = __float2half(e); l += e; }
    red[t] = l; __syncthreads();
    for (int s = SBLK/2; s > 0; s >>= 1) { if (t < s) red[t] += red[t+s]; __syncthreads(); }
    float inv = 1.0f / red[0]; __syncthreads();

    /* pass 3: normalize */
    for (int j = t; j < rowlen; j += SBLK) r[j] = __float2half(__half2float(r[j]) * inv);
}

int main(int argc, char **argv) {
    int N = (argc > 1) ? atoi(argv[1]) : 2048;
    int d = (argc > 2) ? atoi(argv[2]) : 64;

    size_t szT = (size_t)N * d * sizeof(__half);
    size_t szS = (size_t)N * N * sizeof(__half);
    __half *hq = (__half *)malloc(szT), *hk = (__half *)malloc(szT);
    __half *hv = (__half *)malloc(szT), *ho = (__half *)malloc(szT);
    float *qf = (float *)malloc((size_t)N*d*4), *kf = (float *)malloc((size_t)N*d*4), *vf = (float *)malloc((size_t)N*d*4);
    double *ref = (double *)malloc((size_t)N * d * sizeof(double));

    for (int i = 0; i < N * d; ++i) { hq[i] = __float2half(lcg_f32()*4.0f); qf[i] = __half2float(hq[i]); }
    for (int i = 0; i < N * d; ++i) { hk[i] = __float2half(lcg_f32()*4.0f); kf[i] = __half2float(hk[i]); }
    for (int i = 0; i < N * d; ++i) { hv[i] = __float2half(lcg_f32());      vf[i] = __half2float(hv[i]); }
    float scale = 1.0f / sqrtf((float)d);

    double *sr = (double *)malloc((size_t)N * 8);
    for (int i = 0; i < N; ++i) {
        double m = -1e300;
        for (int j = 0; j < N; ++j) { double s=0; for (int l=0;l<d;++l) s += (double)qf[(size_t)i*d+l]*(double)kf[(size_t)j*d+l];
            s *= (double)scale; sr[j]=s; if (s>m) m=s; }
        double sum=0; for (int j=0;j<N;++j){ sr[j]=exp(sr[j]-m); sum+=sr[j]; } double inv=1.0/sum;
        for (int x=0;x<d;++x){ double a=0; for(int j=0;j<N;++j) a+=sr[j]*(double)vf[(size_t)j*d+x]; ref[(size_t)i*d+x]=a*inv; }
    } free(sr);

    __half *dq,*dk,*dv,*dop,*dS;
    CK(cudaMalloc(&dq, szT)); CK(cudaMalloc(&dk, szT)); CK(cudaMalloc(&dv, szT));
    CK(cudaMalloc(&dop, szT)); CK(cudaMalloc(&dS, szS));
    CK(cudaMemcpy(dq, hq, szT, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dk, hk, szT, cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dv, hv, szT, cudaMemcpyHostToDevice));

    cublasHandle_t h; CB(cublasCreate(&h));
    CB(cublasSetMathMode(h, CUBLAS_TENSOR_OP_MATH));
    const float one = 1.0f, zero = 0.0f;
    long long s0 = 0;
    cudaEvent_t e0, e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));

    {
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_T, CUBLAS_OP_N, N, N, d,
            &scale, dk, CUDA_R_16F, d, s0, dq, CUDA_R_16F, d, s0,
            &zero, dS, CUDA_R_16F, N, s0, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        softmax_rows_h<<<N, SBLK>>>(dS, N, N);
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_N, CUBLAS_OP_N, d, N, N,
            &one, dv, CUDA_R_16F, d, s0, dS, CUDA_R_16F, N, s0,
            &zero, dop, CUDA_R_16F, d, s0, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(ho, dop, szT, cudaMemcpyDeviceToHost));
    }
    double *rmx = (double *)malloc((size_t)N * 8);
    for (int i=0;i<N;++i){ double mx=0; for(int x=0;x<d;++x){ double w=fabs(ref[(size_t)i*d+x]); if(w>mx)mx=w; } rmx[i]=mx; }
    double maxa=0, relrs=0; long nanc=0;
    for (size_t i=0;i<(size_t)N*d;++i){ double g=(double)__half2float(ho[i]), w=ref[i];
        if (isnan(g)||isinf(g)) nanc++;
        double a=fabs(g-w); if(a>maxa)maxa=a; int r=(int)(i/d); double rr=a/(rmx[r]+1e-9); if(rr>relrs)relrs=rr; }
    int numeric_pass = (relrs <= 1e-2) && (nanc==0);

    const int WARMUP=20, TIMED=200;
    for (int i=0;i<WARMUP;++i){
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_T, CUBLAS_OP_N, N, N, d,
            &scale, dk, CUDA_R_16F, d, s0, dq, CUDA_R_16F, d, s0,
            &zero, dS, CUDA_R_16F, N, s0, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        softmax_rows_h<<<N, SBLK>>>(dS, N, N);
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_N, CUBLAS_OP_N, d, N, N,
            &one, dv, CUDA_R_16F, d, s0, dS, CUDA_R_16F, N, s0,
            &zero, dop, CUDA_R_16F, d, s0, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    }
    CK(cudaDeviceSynchronize());
    double *times = (double *)malloc(TIMED * 8);
    for (int i=0;i<TIMED;++i){
        CK(cudaEventRecord(e0,0));
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_T, CUBLAS_OP_N, N, N, d,
            &scale, dk, CUDA_R_16F, d, s0, dq, CUDA_R_16F, d, s0,
            &zero, dS, CUDA_R_16F, N, s0, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        softmax_rows_h<<<N, SBLK>>>(dS, N, N);
        CB(cublasGemmStridedBatchedEx(h, CUBLAS_OP_N, CUBLAS_OP_N, d, N, N,
            &one, dv, CUDA_R_16F, d, s0, dS, CUDA_R_16F, N, s0,
            &zero, dop, CUDA_R_16F, d, s0, 1, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CK(cudaEventRecord(e1,0)); CK(cudaEventSynchronize(e1));
        float ms=0; CK(cudaEventElapsedTime(&ms, e0, e1)); times[i]=(double)ms;
    }
    qsort(times, TIMED, 8, cmp_double);
    double median = times[TIMED/2];
    double mean=0; for(int i=0;i<TIMED;++i) mean+=times[i]; mean/=TIMED;
    double var=0; for(int i=0;i<TIMED;++i){ double dd=times[i]-mean; var+=dd*dd; } double sd=sqrt(var/TIMED);

    printf("BASELINE-CUBLAS-TC %s -- N=%d d=%d rel_rowscale=%g naninf=%ld\n",
           numeric_pass?"PASS":"FAIL", N, d, relrs, nanc);
    printf("BASELINE-TC-WALL N=%d d=%d launches=3 median_ms=%.6f mean_ms=%.6f std_ms=%.6f std_pct=%.4f\n",
           N, d, median, mean, sd, (mean>0?100.0*sd/mean:0.0));
    cudaFree(dq); cudaFree(dk); cudaFree(dv); cudaFree(dop); cudaFree(dS);
    cublasDestroy(h);
    return numeric_pass ? 0 : 1;
}
