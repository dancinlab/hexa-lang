// util_loop: run ONE GEMM impl (cublas-TF32 | wmma2) in a sustained loop for N
// seconds so an external nvidia-smi sampler can read util MEAN per impl.
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <mma.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static cublasHandle_t H;
#include "gemm_kernels_extracted.cuh"
int main(int argc, char** argv){
    const char* mode = argc>1?argv[1]:"wmma2";
    double secs = argc>2?atof(argv[2]):15.0;
    long long M=2048,N=2048,K=2048;
    cublasCreate(&H); cublasSetMathMode(H, CUBLAS_TF32_TENSOR_OP_MATH);
    float *dA,*dB,*dC;
    cudaMalloc(&dA,M*K*sizeof(float)); cudaMalloc(&dB,K*N*sizeof(float)); cudaMalloc(&dC,M*N*sizeof(float));
    cudaMemset(dA,1,M*K*sizeof(float)); cudaMemset(dB,1,K*N*sizeof(float));
    float alpha=1.f,beta=0.f;
    dim3 w2blk(256), w2grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N+HXG_BN-1)/HXG_BN));
    struct timespec t0,t1; clock_gettime(CLOCK_MONOTONIC,&t0);
    long iters=0;
    for(;;){
        if(!strcmp(mode,"cublas"))
            cublasSgemm(H,CUBLAS_OP_N,CUBLAS_OP_N,(int)N,(int)M,(int)K,&alpha,dB,(int)N,dA,(int)K,&beta,dC,(int)N);
        else
            _hx_k_sgemm_cm_wmma2<<<w2grd,w2blk>>>(0,0,M,N,K,alpha,dA,M,dB,K,beta,dC,M);
        if(((++iters)&31)==0){ cudaDeviceSynchronize(); clock_gettime(CLOCK_MONOTONIC,&t1);
            double el=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9; if(el>=secs) break; }
    }
    cudaDeviceSynchronize(); printf("%s: %ld iters\n",mode,iters); return 0;
}
