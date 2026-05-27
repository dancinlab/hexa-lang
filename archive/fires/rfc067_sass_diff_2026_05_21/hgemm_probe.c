/* Minimal cuBLAS HGEMM probe at M=N=K=1536, FP16 in, FP32 acc, TENSOR_OP.
 * Goal: trigger the same kernel cuBLAS selects for the hexa N89 comparator.
 * Build: nvcc -O2 -o hgemm_probe hgemm_probe.c -lcuda -lcudart -lcublas
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

static unsigned short f32_to_f16(float f){
    unsigned int x; memcpy(&x,&f,4);
    unsigned int sign=(x>>31)&1; int exp=(int)((x>>23)&0xff)-127+15;
    unsigned int mant=x&0x7fffff; unsigned short out;
    if (exp>=31)      out=(sign<<15)|(0x1f<<10)|(mant?(mant>>13):0);
    else if (exp<=0){ if(exp<-10) out=(sign<<15); else {mant|=0x800000; int s=14-exp; out=(sign<<15)|(mant>>s);} }
    else out=(sign<<15)|(exp<<10)|(mant>>13);
    return out;
}

int main(int argc, char **argv){
    int M=1536,N=1536,K=1536;
    if (argc>=4){M=atoi(argv[1]); N=atoi(argv[2]); K=atoi(argv[3]);}
    int iters = (argc>=5)?atoi(argv[4]):50;
    cublasHandle_t h; cublasCreate(&h);
    cublasSetMathMode(h, CUBLAS_TENSOR_OP_MATH);
    size_t bytes_a=(size_t)M*K*2, bytes_b=(size_t)K*N*2, bytes_c=(size_t)M*N*4;
    unsigned short *hA=(unsigned short*)malloc(bytes_a), *hB=(unsigned short*)malloc(bytes_b);
    for(int i=0;i<M*K;++i) hA[i]=f32_to_f16(0.001f*(float)(i%97));
    for(int i=0;i<K*N;++i) hB[i]=f32_to_f16(0.001f*(float)(i%89));
    void *dA,*dB,*dC; cudaMalloc(&dA,bytes_a); cudaMalloc(&dB,bytes_b); cudaMalloc(&dC,bytes_c);
    cudaMemcpy(dA,hA,bytes_a,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,hB,bytes_b,cudaMemcpyHostToDevice);
    float alpha=1.0f, beta=0.0f;
    /* warmup */
    for (int w=0;w<5;++w){
        cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, M,N,K,
                     &alpha, dA, CUDA_R_16F, M, dB, CUDA_R_16F, K,
                     &beta,  dC, CUDA_R_32F, M,
                     CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    }
    cudaDeviceSynchronize();
    for (int it=0; it<iters; ++it){
        cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, M,N,K,
                     &alpha, dA, CUDA_R_16F, M, dB, CUDA_R_16F, K,
                     &beta,  dC, CUDA_R_32F, M,
                     CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    }
    cudaDeviceSynchronize();
    printf("HGEMM probe done M=%d N=%d K=%d iters=%d\n", M,N,K,iters);
    cudaFree(dA); cudaFree(dB); cudaFree(dC);
    free(hA); free(hB);
    cublasDestroy(h);
    return 0;
}
