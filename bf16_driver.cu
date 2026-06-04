// bf16_driver.cu — HEXA-FUSION C1 standalone A/B for the BF16 own-GEMM.
// Compares, on the SAME GPU, for a square M=N=K GEMM (col-major, no-transpose):
//   • cuBLAS-BF16  : cublasGemmEx(CUDA_R_16BF inputs, CUDA_R_32F compute) — the
//                    BF16 oracle (faithful bf16 Tensor-Core path).
//   • BF16-own     : _hx_k_sgemm_cm_bf16  (this PR — bf16 frag, fp32 accum).
//   • FP32-WMMA2   : _hx_k_sgemm_cm_wmma2 (ref TF32 own-GEMM, the FP32 path).
//   • FP64-cuBLAS  : cublasDgemm (the FP64 baseline the README's 9.67× cites).
//
// CORRECTNESS: BF16-own vs the cuBLAS-BF16 oracle, rel-RMS. BF16 tol = 1e-2
//   (BF16 ~8-bit mantissa; this is the LOOSER bar — NOT the 3e-3 TF32 bar).
//   FP32-WMMA2 is also checked vs an fp64 reference (TF32 tol 3e-3) for context.
// PERF: CUDA-event timing, 50 iters, single GEMM. Reports ms/iter + the
//   dtype-axis throughput (TFLOP/s) so the BF16-vs-FP32-vs-FP64 axis is visible.
//
// The kernels are #included verbatim from the shipped .cu (gemm_kernels_extracted.cuh)
// so the measured code IS the shipped code (no copy drift).
//
// Build:  nvcc -O3 -arch=sm_90 -lcublas bf16_driver.cu -o bf16_driver
// Run:    ./bf16_driver [M N K iters]

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cuda_bf16.h>
#include <mma.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "gemm_kernels_extracted.cuh"

// --- helpers ---
static double rel_rms(const float* ref, const float* got, long long n) {
    double se = 0.0, sr = 0.0;
    for (long long i = 0; i < n; i++) {
        double d = (double)got[i] - (double)ref[i];
        se += d*d; sr += (double)ref[i]*(double)ref[i];
    }
    return sqrt(se / (sr > 0 ? sr : 1.0));
}

int main(int argc, char** argv) {
    long long M = 2048, N = 2048, K = 2048; int iters = 50;
    if (argc >= 4) { M = atoll(argv[1]); N = atoll(argv[2]); K = atoll(argv[3]); }
    if (argc >= 5) iters = atoi(argv[4]);

    cublasHandle_t h; cublasCreate(&h);

    // Col-major, no transpose: C(MxN) = A(MxK) * B(KxN). lda=M, ldb=K, ldc=M.
    long long szA = M*K, szB = K*N, szC = M*N;
    float *hA = (float*)malloc(szA*4), *hB = (float*)malloc(szB*4);
    float *hRef = (float*)malloc(szC*4), *hGot = (float*)malloc(szC*4);
    srand(1234);
    for (long long i=0;i<szA;i++) hA[i] = (float)(rand()%2001-1000)/1000.0f;
    for (long long i=0;i<szB;i++) hB[i] = (float)(rand()%2001-1000)/1000.0f;

    // fp32 device buffers (the own kernels read fp32, round to bf16 internally).
    float *dA,*dB,*dC; cudaMalloc(&dA,szA*4); cudaMalloc(&dB,szB*4); cudaMalloc(&dC,szC*4);
    cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice);

    // bf16 device buffers for the cuBLAS-BF16 oracle (rounded from the SAME fp32).
    __nv_bfloat16 *hAb=(__nv_bfloat16*)malloc(szA*2), *hBb=(__nv_bfloat16*)malloc(szB*2);
    for (long long i=0;i<szA;i++) hAb[i] = __float2bfloat16(hA[i]);
    for (long long i=0;i<szB;i++) hBb[i] = __float2bfloat16(hB[i]);
    __nv_bfloat16 *dAb,*dBb; cudaMalloc(&dAb,szA*2); cudaMalloc(&dBb,szB*2);
    cudaMemcpy(dAb,hAb,szA*2,cudaMemcpyHostToDevice);
    cudaMemcpy(dBb,hBb,szB*2,cudaMemcpyHostToDevice);

    // fp64 buffers for the FP64-cuBLAS baseline + an fp64 reference.
    double *hAd=(double*)malloc(szA*8), *hBd=(double*)malloc(szB*8);
    for (long long i=0;i<szA;i++) hAd[i]=(double)hA[i];
    for (long long i=0;i<szB;i++) hBd[i]=(double)hB[i];
    double *dAd,*dBd,*dCd; cudaMalloc(&dAd,szA*8); cudaMalloc(&dBd,szB*8); cudaMalloc(&dCd,szC*8);
    cudaMemcpy(dAd,hAd,szA*8,cudaMemcpyHostToDevice);
    cudaMemcpy(dBd,hBd,szB*8,cudaMemcpyHostToDevice);

    float alpha=1.0f, beta=0.0f; double alphad=1.0, betad=0.0;
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    auto timed = [&](auto launch)->float{
        launch(); cudaDeviceSynchronize();
        cudaEventRecord(e0);
        for (int it=0; it<iters; it++) launch();
        cudaEventRecord(e1); cudaEventSynchronize(e1);
        float ms=0; cudaEventElapsedTime(&ms,e0,e1);
        return ms/iters;
    };
    double flops = 2.0*(double)M*(double)N*(double)K;   // 2MNK
    auto tflops = [&](float ms){ return flops / (ms*1e-3) / 1e12; };

    // --- 1) cuBLAS-BF16 oracle (bf16 inputs, fp32 compute) ---
    float t_cublas_bf = timed([&]{
        cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, (int)M,(int)N,(int)K,
                     &alpha, dAb, CUDA_R_16BF, (int)M, dBb, CUDA_R_16BF, (int)K,
                     &beta,  dC,  CUDA_R_32F,  (int)M,
                     CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    });
    cudaMemcpy(hRef,dC,szC*4,cudaMemcpyDeviceToHost);   // bf16 oracle result

    // --- fp64 reference (for FP32 context) ---
    double t_cublas_fp64 = timed([&]{
        cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, (int)M,(int)N,(int)K,
                    &alphad, dAd,(int)M, dBd,(int)K, &betad, dCd,(int)M);
    });
    double *hRefd=(double*)malloc(szC*8); cudaMemcpy(hRefd,dCd,szC*8,cudaMemcpyDeviceToHost);
    float *hRef64f=(float*)malloc(szC*4);
    for (long long i=0;i<szC;i++) hRef64f[i]=(float)hRefd[i];

    // --- 2) BF16-own (_hx_k_sgemm_cm_bf16) ---
    cudaMemset(dC,0,szC*4);
    dim3 bfblk(256), bfgrd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N+HXG_BN-1)/HXG_BN));
    float t_bf_own = timed([&]{
        _hx_k_sgemm_cm_bf16<<<bfgrd,bfblk>>>(0,0,M,N,K, alpha, dA,M, dB,K, beta, dC,M);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_bf_vs_cublasbf = rel_rms(hRef,hGot,szC);   // vs bf16 oracle (BF16 tol 1e-2)
    double rms_bf_vs_fp64     = rel_rms(hRef64f,hGot,szC); // vs fp64 (context)

    // --- 3) FP32-WMMA2 (ref TF32 own-GEMM) ---
    cudaMemset(dC,0,szC*4);
    dim3 w2blk(256), w2grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N+HXG_BN-1)/HXG_BN));
    float t_wmma2 = timed([&]{
        _hx_k_sgemm_cm_wmma2<<<w2grd,w2blk>>>(0,0,M,N,K, alpha, dA,M, dB,K, beta, dC,M);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_wmma2_vs_fp64 = rel_rms(hRef64f,hGot,szC);  // vs fp64 (TF32 tol 3e-3)

    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("shape: M=%lld N=%lld K=%lld  iters=%d  (col-major, no-transpose, alpha=1 beta=0)\n",M,N,K,iters);

    printf("\nperf ms/iter (single GEMM, CUDA-event) + dtype-axis throughput:\n");
    printf("  cuBLAS-BF16   : %.5f ms/iter  %8.1f TFLOP/s  (1.00x)\n", t_cublas_bf, tflops(t_cublas_bf));
    printf("  BF16-own      : %.5f ms/iter  %8.1f TFLOP/s  (%.2fx vs cuBLAS-BF16)\n", t_bf_own, tflops(t_bf_own), t_bf_own/t_cublas_bf);
    printf("  FP32-WMMA2(ref): %.5f ms/iter  %8.1f TFLOP/s  (%.2fx vs cuBLAS-BF16)\n", t_wmma2, tflops(t_wmma2), t_wmma2/t_cublas_bf);
    printf("  FP64-cuBLAS   : %.5f ms/iter  %8.1f TFLOP/s  (%.2fx vs cuBLAS-BF16)\n", (float)t_cublas_fp64, tflops((float)t_cublas_fp64), t_cublas_fp64/t_cublas_bf);

    printf("\ndtype-axis throughput speedup (the README's 9.67x axis):\n");
    printf("  BF16-own   vs FP64-cuBLAS : %.2fx\n", t_cublas_fp64/t_bf_own);
    printf("  cuBLAS-BF16 vs FP64-cuBLAS: %.2fx\n", t_cublas_fp64/t_cublas_bf);
    printf("  BF16-own   vs FP32-WMMA2  : %.2fx\n", t_wmma2/t_bf_own);

    printf("\ncorrectness (rel-RMS):\n");
    printf("  BF16-own  vs cuBLAS-BF16 oracle = %.3e   %s   (BF16 tol 1e-2)\n",
           rms_bf_vs_cublasbf, rms_bf_vs_cublasbf<=1e-2?"PASS":"FAIL");
    printf("  BF16-own  vs fp64 ref           = %.3e   (context: bf16 precision floor)\n", rms_bf_vs_fp64);
    printf("  FP32-WMMA2 vs fp64 ref          = %.3e   %s   (TF32 tol 3e-3, context)\n",
           rms_wmma2_vs_fp64, rms_wmma2_vs_fp64<=3e-3?"PASS":"FAIL");
    return 0;
}
