/* gpu_tc_peak - cuBLAS HGEMM (tensor-core) achieved peak at large square shape.
 * Anchors the FP16-tensor roofline denominator. ASCII only.
 * Build: nvcc -O2 -arch=sm_90 -o gpu_tc_peak gpu_tc_peak.cu -lcublas -lcudart
 */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#define CK(c) do{cudaError_t e=(c); if(e!=cudaSuccess){fprintf(stderr,"cuda %s\n",cudaGetErrorString(e));return 1;}}while(0)
#define CB(c) do{cublasStatus_t s=(c); if(s!=CUBLAS_STATUS_SUCCESS){fprintf(stderr,"cublas %d\n",(int)s);return 1;}}while(0)
static int cmp(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}
int main(void){
    cublasHandle_t h; CB(cublasCreate(&h));
    CB(cublasSetMathMode(h, CUBLAS_TENSOR_OP_MATH));
    cudaEvent_t e0,e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));
    int Ms[]={1024,2048,4096}; int nM=3;
    __half alpha=__float2half(1.0f), beta=__float2half(0.0f);
    printf("# cuBLAS HGEMM (tensor-core) square N=K=M, achieved TFLOPS\n");
    for(int mi=0;mi<nM;++mi){
        int M=Ms[mi], N=M, K=M;
        size_t sz=(size_t)M*N*sizeof(__half);
        __half *dA,*dB,*dC; CK(cudaMalloc((void**)&dA,sz));CK(cudaMalloc((void**)&dB,sz));CK(cudaMalloc((void**)&dC,sz));
        CK(cudaMemset(dA,1,sz));CK(cudaMemset(dB,1,sz));
        for(int i=0;i<20;++i) CB(cublasHgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&alpha,dB,N,dA,K,&beta,dC,N));
        CK(cudaDeviceSynchronize());
        const int IT=100; double s[100];
        for(int i=0;i<IT;++i){CK(cudaEventRecord(e0,0));
            CB(cublasHgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&alpha,dB,N,dA,K,&beta,dC,N));
            CK(cudaEventRecord(e1,0));CK(cudaEventSynchronize(e1));
            float ms;CK(cudaEventElapsedTime(&ms,e0,e1));s[i]=ms;}
        qsort(s,IT,sizeof(double),cmp); double med=s[IT/2];
        double flops=2.0*M*N*K; double tf=flops/(med*1e-3)/1e12;
        printf("M=%-5d  median %.4f ms  %.2f TFLOPS\n",M,med,tf);
        cudaFree(dA);cudaFree(dB);cudaFree(dC);
    }
    cublasDestroy(h); return 0;
}
