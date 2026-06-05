// HEXA-FUSION SM90 WARP-TILE RETUNE microbench.
// Measures the own-GEMM (WMMA2 vs WMMA2-RR) against cuBLAS on a square
// 2048^3 col-major Sgemm: GFLOP/s, ratio vs cuBLAS, rel-RMS correctness.
// Links against the hxqwen14b_cuda.cu TU (extern "C" _hx_own_sgemm_cm_launch).
//
// Build (on a native sm_90 H100 pod):
//   nvcc -O3 -DHEXA_CUDA -arch=sm_90 -c self/native/hxqwen14b_cuda.cu -o hxq.o
//   nvcc -O3 -arch=sm_90 self/native/bench/wmma2_rr_bench.cu hxq.o \
//        -lcublas -lcuda -o wmma2_rr_bench
//
// Run:
//   HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_WMMA2_RR=1 ./wmma2_rr_bench 2048
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

extern "C" int _hx_own_sgemm_cm_launch(int tA, int tB, int m, int n, int k,
                                       float alpha, const float* A, int lda,
                                       const float* B, int ldb,
                                       float beta, float* C, int ldc);

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e)); exit(1);} }while(0)

static double now_ms(cudaEvent_t a, cudaEvent_t b){ float ms=0; cudaEventElapsedTime(&ms,a,b); return ms; }

int main(int argc, char** argv){
    int n = (argc>1)? atoi(argv[1]) : 2048;
    int M=n, N=n, K=n;
    long long sz = (long long)M*N;
    long long szA=(long long)M*K, szB=(long long)K*N;
    printf("== WMMA2-RR bench: square %dx%dx%d col-major Sgemm ==\n", M,N,K);

    float *hA=(float*)malloc(szA*4), *hB=(float*)malloc(szB*4);
    srand(1234);
    for(long long i=0;i<szA;i++) hA[i]=(float)((rand()%2001-1000)/1000.0);
    for(long long i=0;i<szB;i++) hB[i]=(float)((rand()%2001-1000)/1000.0);

    float *dA,*dB,*dCref,*dCown;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4));
    CK(cudaMalloc(&dCref,sz*4)); CK(cudaMalloc(&dCown,sz*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    cublasHandle_t h; cublasCreate(&h);
    // TF32 math mode so the cuBLAS oracle uses the SAME precision class as the
    // own TF32 WMMA path (fair throughput + correctness compare).
    cublasSetMathMode(h, CUBLAS_TF32_TENSOR_OP_MATH);
    float alpha=1.0f, beta=0.0f;
    int lda=M, ldb=K, ldc=M;

    double flops = 2.0*(double)M*N*K;
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    int WARM=3, ITER=20;

    // ---- cuBLAS baseline ----
    for(int i=0;i<WARM;i++) cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,M,N,K,&alpha,dA,lda,dB,ldb,&beta,dCref,ldc);
    CK(cudaDeviceSynchronize());
    cudaEventRecord(e0);
    for(int i=0;i<ITER;i++) cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,M,N,K,&alpha,dA,lda,dB,ldb,&beta,dCref,ldc);
    cudaEventRecord(e1); CK(cudaEventSynchronize(e1));
    double cub_ms = now_ms(e0,e1)/ITER;
    double cub_gflops = flops/(cub_ms*1e6);

    // ---- own (env-selected: WMMA2 or WMMA2-RR) ----
    int rc=_hx_own_sgemm_cm_launch(0,0,M,N,K,alpha,dA,lda,dB,ldb,beta,dCown,ldc);
    CK(cudaDeviceSynchronize());
    if(rc!=0){ fprintf(stderr,"own launch rc=%d\n",rc); return 2; }
    for(int i=0;i<WARM;i++) _hx_own_sgemm_cm_launch(0,0,M,N,K,alpha,dA,lda,dB,ldb,beta,dCown,ldc);
    CK(cudaDeviceSynchronize());
    cudaEventRecord(e0);
    for(int i=0;i<ITER;i++) _hx_own_sgemm_cm_launch(0,0,M,N,K,alpha,dA,lda,dB,ldb,beta,dCown,ldc);
    cudaEventRecord(e1); CK(cudaEventSynchronize(e1));
    double own_ms = now_ms(e0,e1)/ITER;
    double own_gflops = flops/(own_ms*1e6);

    // ---- rel-RMS (own vs cuBLAS oracle) ----
    float *hR=(float*)malloc(sz*4), *hO=(float*)malloc(sz*4);
    CK(cudaMemcpy(hR,dCref,sz*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hO,dCown,sz*4,cudaMemcpyDeviceToHost));
    double se=0, sr=0;
    for(long long i=0;i<sz;i++){ double d=(double)hO[i]-(double)hR[i]; se+=d*d; sr+=(double)hR[i]*(double)hR[i]; }
    double relrms = sqrt(se/ (sr>0?sr:1));

    printf("cuBLAS : %.3f ms  %.1f GFLOP/s  (%.2f TFLOP/s)\n", cub_ms, cub_gflops, cub_gflops/1000.0);
    printf("own    : %.3f ms  %.1f GFLOP/s  (%.2f TFLOP/s)\n", own_ms, own_gflops, own_gflops/1000.0);
    printf("ratio  : own/cuBLAS = %.4f   cuBLAS/own = %.2fx\n", own_gflops/cub_gflops, cub_gflops/own_gflops);
    printf("rel-RMS: %.3e   (bar <= 3e-3 : %s)\n", relrms, relrms<=3e-3?"PASS":"FAIL");
    return 0;
}
