// HEXA-TRAIN-FLOOR M7 — fp64 vs fp32 GEMM throughput on RTX 5070.
// Tests the M4 roofline claim: trainer is fp64 COMPUTE-bound; the fp32 lever
// (M6) lifts the step-rate ceiling. M4 predicted 5070 fp64 floor = 6.58 s/step
// (0.15 step/s) and that fp32 lifts it ~44×. We measure the device fp64 and
// fp32 GEMM rates directly (the dominant per-step cost) → the achievable
// ceiling ratio. cuBLAS SGEMM/DGEMM, square N.
#include <cstdio>
#include <cstdint>
#include <vector>
#include <cuda_runtime.h>
#include <cublas_v2.h>
static double now_ms(){struct timespec ts;clock_gettime(CLOCK_MONOTONIC,&ts);return ts.tv_sec*1e3+ts.tv_nsec*1e-6;}
int main(){
  cudaSetDevice(0);
  cublasHandle_t h; cublasCreate(&h);
  int Ns[]={1024,2048,4096}; int nN=3; int reps=30,warm=5;
  printf("# HEXA-TRAIN-FLOOR M7 GEMM roofline — RTX 5070\n");
  printf("# square GEMM N×N×N, FLOPs=2N^3.  reps=%d\n",reps);
  printf("# N | dgemm_TFLOPs(fp64) | sgemm_TFLOPs(fp32) | fp32/fp64_speedup\n");
  for(int i=0;i<nN;i++){
    int N=Ns[i]; size_t e=(size_t)N*N;
    std::vector<double> A(e,0.5),B(e,0.5),C(e,0.0);
    std::vector<float> Af(e,0.5f),Bf(e,0.5f),Cf(e,0.0f);
    double *dA,*dB,*dC; float *fA,*fB,*fC;
    cudaMalloc(&dA,e*8);cudaMalloc(&dB,e*8);cudaMalloc(&dC,e*8);
    cudaMalloc(&fA,e*4);cudaMalloc(&fB,e*4);cudaMalloc(&fC,e*4);
    cudaMemcpy(dA,A.data(),e*8,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,B.data(),e*8,cudaMemcpyHostToDevice);
    cudaMemcpy(fA,Af.data(),e*4,cudaMemcpyHostToDevice);
    cudaMemcpy(fB,Bf.data(),e*4,cudaMemcpyHostToDevice);
    const double a=1.0,b=0.0; const float af=1.0f,bf=0.0f;
    for(int w=0;w<warm;w++){
      cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,N,N,&a,dA,N,dB,N,&b,dC,N);
      cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,N,N,&af,fA,N,fB,N,&bf,fC,N);
    }
    cudaDeviceSynchronize();
    double t0=now_ms();
    for(int r=0;r<reps;r++) cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,N,N,&a,dA,N,dB,N,&b,dC,N);
    cudaDeviceSynchronize();
    double dms=(now_ms()-t0)/reps;
    t0=now_ms();
    for(int r=0;r<reps;r++) cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,N,N,&af,fA,N,fB,N,&bf,fC,N);
    cudaDeviceSynchronize();
    double sms=(now_ms()-t0)/reps;
    double flop=2.0*N*N*(double)N;
    double dtf=flop/(dms*1e-3)/1e12, stf=flop/(sms*1e-3)/1e12;
    printf("%5d | %18.3f | %18.3f | %.2f\n",N,dtf,stf,dtf>0?stf/dtf:0);
    cudaFree(dA);cudaFree(dB);cudaFree(dC);cudaFree(fA);cudaFree(fB);cudaFree(fC);
  }
  cublasDestroy(h); return 0;
}
