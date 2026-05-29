// HEXA-TRAIN-FLOOR A100 headroom — fp64 GEMM floor + bf16 TensorCore lift.
// Same microbench style as tool/train_floor_m7/m7_gemm_roofline.cu (M7) and the
// bf16-lever (B) verdict, re-run on a RENTED A100 to confirm M4's analytic:
//   (1) A100 fp64 GEMM rate (Dgemm) — fp64 floor/peak vs M4 (5070 floor lift).
//   (2) bf16 GemmEx vs fp64 Dgemm speedup — confirm M4's predicted ~32x lift.
// GemmEx shape lifted VERBATIM from self/cuda/runtime_bf16_emit.hexa
//   _hx_gemm_ex_bf16: CUDA_R_16BF in/out, CUBLAS_COMPUTE_32F (fp32 accum),
//   CUBLAS_GEMM_DEFAULT_TENSOR_OP. SGEMM(fp32) included for the M6 fp32 lever.
// Square GEMM C[n,n] = A[n,n]*B[n,n], FLOPs = 2*n^3. Trainer d768.12L dims.
#include <cstdio>
#include <cstdint>
#include <vector>
#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>

static double now_ms(){ struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec*1e3+ts.tv_nsec*1e-6; }

int main(){
  cudaSetDevice(0);
  cudaDeviceProp prop; cudaGetDeviceProperties(&prop,0);
  cublasHandle_t h; cublasCreate(&h);

  // trainer d768.12L relevant GEMM shapes (square)
  int Ns[] = {256,512,768,1024,2048}; int nN = 5;
  int reps = 200, warm = 20;

  printf("# HEXA-TRAIN-FLOOR A100 headroom — %s (CC %d.%d, %zu MB)\n",
         prop.name, prop.major, prop.minor, (size_t)(prop.totalGlobalMem>>20));
  printf("# square GEMM n x n x n, FLOPs=2n^3.  reps=%d warmup=%d\n", reps, warm);
  printf("# GemmEx shape = runtime_bf16_emit.hexa _hx_gemm_ex_bf16 (CUDA_R_16BF, COMPUTE_32F, DEFAULT_TENSOR_OP)\n");
  printf("# n | dgemm_fp64_TFLOPs | sgemm_fp32_TFLOPs | gemmEx_bf16_tc_TFLOPs | bf16/fp64_speedup | fp32/fp64\n");

  for(int i=0;i<nN;i++){
    int n = Ns[i]; size_t e = (size_t)n*n;
    std::vector<double> A(e,0.5), B(e,0.5);
    std::vector<float>  Af(e,0.5f), Bf(e,0.5f);
    std::vector<__nv_bfloat16> Ab(e), Bb(e);
    for(size_t k=0;k<e;k++){ Ab[k]=__float2bfloat16(0.5f); Bb[k]=__float2bfloat16(0.5f); }

    double *dA,*dB,*dC; float *fA,*fB,*fC; __nv_bfloat16 *bA,*bB,*bC;
    cudaMalloc(&dA,e*8); cudaMalloc(&dB,e*8); cudaMalloc(&dC,e*8);
    cudaMalloc(&fA,e*4); cudaMalloc(&fB,e*4); cudaMalloc(&fC,e*4);
    cudaMalloc(&bA,e*2); cudaMalloc(&bB,e*2); cudaMalloc(&bC,e*2);
    cudaMemcpy(dA,A.data(),e*8,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,B.data(),e*8,cudaMemcpyHostToDevice);
    cudaMemcpy(fA,Af.data(),e*4,cudaMemcpyHostToDevice);
    cudaMemcpy(fB,Bf.data(),e*4,cudaMemcpyHostToDevice);
    cudaMemcpy(bA,Ab.data(),e*2,cudaMemcpyHostToDevice);
    cudaMemcpy(bB,Bb.data(),e*2,cudaMemcpyHostToDevice);

    const double a=1.0,b=0.0; const float af=1.0f,bf=0.0f;

    for(int w=0;w<warm;w++){
      cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,n,n,n,&a,dA,n,dB,n,&b,dC,n);
      cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,n,n,n,&af,fA,n,fB,n,&bf,fC,n);
      cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,n,n,n,&af,
                   bA,CUDA_R_16BF,n, bB,CUDA_R_16BF,n,&bf,
                   bC,CUDA_R_16BF,n, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    }
    cudaDeviceSynchronize();

    double t0=now_ms();
    for(int r=0;r<reps;r++) cublasDgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,n,n,n,&a,dA,n,dB,n,&b,dC,n);
    cudaDeviceSynchronize();
    double dms=(now_ms()-t0)/reps;

    t0=now_ms();
    for(int r=0;r<reps;r++) cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,n,n,n,&af,fA,n,fB,n,&bf,fC,n);
    cudaDeviceSynchronize();
    double sms=(now_ms()-t0)/reps;

    t0=now_ms();
    for(int r=0;r<reps;r++) cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,n,n,n,&af,
                   bA,CUDA_R_16BF,n, bB,CUDA_R_16BF,n,&bf,
                   bC,CUDA_R_16BF,n, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    cudaDeviceSynchronize();
    double bms=(now_ms()-t0)/reps;

    double flop = 2.0*n*n*(double)n;
    double dtf = flop/(dms*1e-3)/1e12;
    double stf = flop/(sms*1e-3)/1e12;
    double btf = flop/(bms*1e-3)/1e12;
    printf("%5d | %17.3f | %17.3f | %21.3f | %17.2f | %.2f\n",
           n, dtf, stf, btf, dms/bms, dms/sms);

    cudaFree(dA);cudaFree(dB);cudaFree(dC);
    cudaFree(fA);cudaFree(fB);cudaFree(fC);
    cudaFree(bA);cudaFree(bB);cudaFree(bC);
  }
  cublasDestroy(h);
  return 0;
}
