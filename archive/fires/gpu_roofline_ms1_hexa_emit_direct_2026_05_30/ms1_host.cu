// MS#1 hexa-emit DIRECT achieved/peak roofline harness.
// ubu-2 RTX 5070 sm_120. cuBLAS-INDEPENDENT numerator: loads the
// COMPILER-EMITTED hexa WMMA PTX (PR #214, wmma_256x256_grid, 256-locked),
// times it (median of 200, 20 warmup, cudaEventRecord per-launch), byte-eq
// vs CPU FP64 ref, and reports its TFLOPS as a DIRECT % of the device
// achieved tensor-core peak (re-measured here via cuBLAS HGEMM M=4096 = the
// §peak denominator, 126.52 TF on 2026-05-30) AND the shape-local cuBLAS
// achievable at the SAME 256 shape. Pure-ASCII. /tmp only.
#include <cuda.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static int cmp_d(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}

// Measure achieved tensor-core peak: cuBLAS HGEMM (f16 in, f32 acc) at a
// large shape where the tensor cores saturate (M=N=K=4096 per §peak).
static double measure_tc_peak(cublasHandle_t cub,int S,int REP,int WARM){
  size_t n=(size_t)S*S;
  __half* hA=(__half*)malloc(n*2); __half* hB=(__half*)malloc(n*2);
  for(size_t i=0;i<n;i++){ hA[i]=__float2half((float)((i%7)-3)); hB[i]=__float2half((float)((i%5)-2)); }
  __half *dA,*dB; cudaMalloc(&dA,n*2); cudaMalloc(&dB,n*2);
  cudaMemcpy(dA,hA,n*2,cudaMemcpyHostToDevice);
  cudaMemcpy(dB,hB,n*2,cudaMemcpyHostToDevice);
  float *dC; cudaMalloc(&dC,n*4);
  float alphaf=1.f, betaf=0.f;
  cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
  for(int w=0;w<WARM;w++){
    cublasGemmEx(cub,CUBLAS_OP_T,CUBLAS_OP_N,S,S,S,&alphaf,
      dB,CUDA_R_16F,S, dA,CUDA_R_16F,S,&betaf, dC,CUDA_R_32F,S,
      CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
  }
  cudaDeviceSynchronize();
  double* t=(double*)malloc(REP*sizeof(double));
  for(int it=0;it<REP;it++){ cudaEventRecord(e0);
    cublasGemmEx(cub,CUBLAS_OP_T,CUBLAS_OP_N,S,S,S,&alphaf,
      dB,CUDA_R_16F,S, dA,CUDA_R_16F,S,&betaf, dC,CUDA_R_32F,S,
      CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    cudaEventRecord(e1); cudaEventSynchronize(e1); float ms; cudaEventElapsedTime(&ms,e0,e1); t[it]=ms; }
  qsort(t,REP,sizeof(double),cmp_d); double med=t[REP/2];
  double tf=(2.0*S*S*S)/(med*1e-3)/1e12;
  free(t);free(hA);free(hB);cudaFree(dA);cudaFree(dB);cudaFree(dC);
  return tf;
}

int main(int argc,char**argv){
  cuInit(0);
  CUdevice dev; cuDeviceGet(&dev,0);
  CUcontext ctx; cuCtxCreate(&ctx,0,dev);
  char name[256]; cuDeviceGetName(name,256,dev);
  int drv,rt; cuDriverGetVersion(&drv); cudaRuntimeGetVersion(&rt);
  printf("Device: %s\nCUDA driver=%d runtime=%d\n",name,drv,rt);

  const char* ptx = argc>1 ? argv[1] : "wmma_256x256_grid.ptx";
  const char* entry = argc>2 ? argv[2] : "wmma_256x256_grid";
  const int WARM=20, REP=200;
  cublasHandle_t cub; cublasCreate(&cub);

  // --- DENOMINATOR: achieved tensor-core peak (cuBLAS HGEMM M=4096) ---
  double tc_peak = measure_tc_peak(cub,4096,100,10);
  printf("achieved-peak (cuBLAS HGEMM M=4096, tensor-core): %.4f TFLOPS\n", tc_peak);

  // --- NUMERATOR: COMPILER-EMITTED hexa WMMA kernel at S=256 ---
  int S=256; size_t n=(size_t)S*S;
  __half* hA=(__half*)malloc(n*2); __half* hB=(__half*)malloc(n*2);
  for(size_t i=0;i<n;i++){ hA[i]=__float2half((float)((i%7)-3)); hB[i]=__float2half((float)((i%5)-2)); }
  __half *dA,*dB; cudaMalloc(&dA,n*2); cudaMalloc(&dB,n*2);
  cudaMemcpy(dA,hA,n*2,cudaMemcpyHostToDevice);
  cudaMemcpy(dB,hB,n*2,cudaMemcpyHostToDevice);
  float *dC_hexa; cudaMalloc(&dC_hexa,n*4);

  CUmodule mod; CUresult r=cuModuleLoad(&mod,ptx);
  if(r!=CUDA_SUCCESS){const char*es;cuGetErrorString(r,&es);printf("PTX load FAIL: %s\n",es);return 1;}
  CUfunction fn; cuModuleGetFunction(&fn,mod,entry);
  long long k_tiles=S/16;
  void* a_=dA; void* b_=dB; void* c_=dC_hexa; long long kt=k_tiles;
  void* args[]={&a_,&b_,&c_,&kt};
  int grid=S/64; dim3 g(grid,grid,1); dim3 blk(512,1,1);

  cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
  for(int w=0;w<WARM;w++){ cuLaunchKernel(fn,g.x,g.y,1,blk.x,1,1,0,0,args,0); }
  cudaDeviceSynchronize();
  double* th=(double*)malloc(REP*sizeof(double));
  for(int it=0;it<REP;it++){ cudaEventRecord(e0); cuLaunchKernel(fn,g.x,g.y,1,blk.x,1,1,0,0,args,0); cudaEventRecord(e1); cudaEventSynchronize(e1); float ms; cudaEventElapsedTime(&ms,e0,e1); th[it]=ms; }
  qsort(th,REP,sizeof(double),cmp_d); double hmed=th[REP/2];
  double htf=(2.0*S*S*S)/(hmed*1e-3)/1e12;

  // shape-local cuBLAS at same 256 shape (for the relative anchor)
  double cub256 = measure_tc_peak(cub,256,REP,WARM);

  // byte-eq vs CPU FP64 ref (full 256x256)
  float* hHexa=(float*)malloc(n*4); cudaMemcpy(hHexa,dC_hexa,n*4,cudaMemcpyDeviceToHost);
  double maxabs=0.0;
  for(int i=0;i<S;i++) for(int j=0;j<S;j++){
    double acc=0;
    for(int k=0;k<S;k++){ acc += (double)__half2float(hA[(size_t)i*S+k]) * (double)__half2float(hB[(size_t)j*S+k]); }
    double got=hHexa[(size_t)i*S+j]; double d=fabs(got-acc); if(d>maxabs)maxabs=d;
  }

  printf("hexa-emit (COMPILER-emitted %s, S=256): median=%.6f ms  TFLOPS=%.4f\n", entry, hmed, htf);
  printf("byte-eq hexa-vs-CPUref(FP64) max|d|=%.6g (full 256x256)\n", maxabs);
  printf("DIRECT hexa-emit achieved/peak = %.4f / %.4f = %.4f%%  (cuBLAS-INDEPENDENT numerator)\n",
    htf, tc_peak, 100.0*htf/tc_peak);
  printf("shape-local cuBLAS HGEMM S=256 = %.4f TFLOPS = %.4f%% of achieved-peak\n",
    cub256, 100.0*cub256/tc_peak);
  printf("hexa-emit / cuBLAS(S=256) = %.4f%%\n", 100.0*htf/cub256);
  return 0;
}
