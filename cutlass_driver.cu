// cutlass_driver.cu — standalone 3-way A/B for the HEXA-FUSION own-GEMM variants.
// Compares cuBLAS (Sgemm, oracle) vs naive-WMMA (_hx_k_sgemm_cm_wmma) vs the
// CUTLASS-grade tiled WMMA (_hx_k_sgemm_cm_wmma2) on the SAME GPU.
//   • Correctness: each own kernel vs cuBLAS oracle, rel-RMS (TF32 tol 3e-3).
//   • Perf: CUDA-event timing, 50 iters, M=N=K=2048 (the R16 fwd+bwd workload
//     is dominated by this square GEMM; we measure the GEMM directly).
// The three kernels are #included verbatim from the .cu under test so the
// measured code IS the shipped code (no copy drift).
//
// Build:
//   nvcc -O3 -arch=sm_90 -lcublas cutlass_driver.cu -o cutlass_driver
// Run:  ./cutlass_driver [M N K iters]

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <mma.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// Pull in ONLY the three GEMM kernels + the CUTLASS-grade helpers from the .cu
// under test. We guard out the rest of that TU (it references hxqwen globals).
// Simplest: copy the three __global__ kernels here is risky (drift). Instead we
// extract them at build time via the surrounding markers. To keep the measured
// code identical to shipped, this driver re-declares the kernels with the SAME
// bodies by #include of an extracted fragment produced by the build script.
#include "gemm_kernels_extracted.cuh"

static cublasHandle_t g_cublas_handle;

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
    cublasCreate(&g_cublas_handle);
    // TF32 allowed on cuBLAS too so the oracle is the same math regime (fair).
    cublasSetMathMode(g_cublas_handle, CUBLAS_TF32_TENSOR_OP_MATH);

    // Col-major, no transpose: C(MxN) = A(MxK) * B(KxN). lda=M, ldb=K, ldc=M.
    long long szA = M*K, szB = K*N, szC = M*N;
    float *hA = (float*)malloc(szA*4), *hB = (float*)malloc(szB*4);
    float *hRef = (float*)malloc(szC*4), *hGot = (float*)malloc(szC*4);
    srand(1234);
    for (long long i=0;i<szA;i++) hA[i] = (float)(rand()%2001-1000)/1000.0f;
    for (long long i=0;i<szB;i++) hB[i] = (float)(rand()%2001-1000)/1000.0f;
    float *dA,*dB,*dC; cudaMalloc(&dA,szA*4); cudaMalloc(&dB,szB*4); cudaMalloc(&dC,szC*4);
    cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice);
    float alpha=1.0f, beta=0.0f;

    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    auto timed = [&](const char* name, auto launch)->float{
        launch(); cudaDeviceSynchronize();              // warmup
        cudaEventRecord(e0);
        for (int it=0; it<iters; it++) launch();
        cudaEventRecord(e1); cudaEventSynchronize(e1);
        float ms=0; cudaEventElapsedTime(&ms,e0,e1);
        return ms/iters;
    };

    // 1) cuBLAS oracle
    float t_cublas = timed("cublas", [&]{
        cublasSgemm(g_cublas_handle, CUBLAS_OP_N, CUBLAS_OP_N,
                    (int)M,(int)N,(int)K, &alpha, dA,(int)M, dB,(int)K, &beta, dC,(int)M);
    });
    cudaMemcpy(hRef,dC,szC*4,cudaMemcpyDeviceToHost);

    // 2) naive WMMA
    cudaMemset(dC,0,szC*4);
    dim3 wblk(32), wgrd((unsigned)((M+15)/16),(unsigned)((N+15)/16));
    float t_naive = timed("naive-wmma", [&]{
        _hx_k_sgemm_cm_wmma<<<wgrd,wblk>>>(0,0,M,N,K, alpha, dA,M, dB,K, beta, dC,M);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_naive = rel_rms(hRef,hGot,szC);

    // 3) CUTLASS-grade tiled WMMA2
    cudaMemset(dC,0,szC*4);
    dim3 w2blk(256), w2grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N+HXG_BN-1)/HXG_BN));
    float t_wmma2 = timed("wmma2", [&]{
        _hx_k_sgemm_cm_wmma2<<<w2grd,w2blk>>>(0,0,M,N,K, alpha, dA,M, dB,K, beta, dC,M);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_wmma2 = rel_rms(hRef,hGot,szC);

    // device name
    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);

    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("shape: M=%lld N=%lld K=%lld  iters=%d  (col-major, no-transpose, alpha=1 beta=0)\n",M,N,K,iters);
    printf("\n3-way ms/iter (single GEMM, CUDA-event):\n");
    printf("  cuBLAS (TF32)      : %.5f ms/iter   (1.00x)\n", t_cublas);
    printf("  naive-WMMA         : %.5f ms/iter   (%.2fx vs cuBLAS)\n", t_naive, t_naive/t_cublas);
    printf("  tiled-WMMA2(CUTLASS): %.5f ms/iter   (%.2fx vs cuBLAS)\n", t_wmma2, t_wmma2/t_cublas);
    printf("\nspeedup naive->tiled-WMMA2 : %.2fx\n", t_naive/t_wmma2);
    printf("remaining gap tiled-WMMA2 -> cuBLAS : %.2fx\n", t_wmma2/t_cublas);
    printf("\ncorrectness (own vs cuBLAS oracle, rel-RMS, TF32 tol 3e-3):\n");
    printf("  naive-WMMA  rel-RMS = %.3e  %s\n", rms_naive, rms_naive<=3e-3?"PASS":"FAIL");
    printf("  tiled-WMMA2 rel-RMS = %.3e  %s\n", rms_wmma2, rms_wmma2<=3e-3?"PASS":"FAIL");

    // GFLOP/s = 2*M*N*K / (ms*1e-3) / 1e9. Required by the SM90-VERIFY verdict.
    double flop = 2.0*(double)M*(double)N*(double)K;
    double g_cublas = flop / (t_cublas*1e-3) / 1e9;
    double g_naive  = flop / (t_naive *1e-3) / 1e9;
    double g_wmma2  = flop / (t_wmma2 *1e-3) / 1e9;
    printf("\nGFLOP/s (2*M*N*K / time):\n");
    printf("  cuBLAS (TF32)       : %.1f GFLOP/s   (1.00x)\n", g_cublas);
    printf("  naive-WMMA          : %.1f GFLOP/s   (%.4fx vs cuBLAS)\n", g_naive, g_naive/g_cublas);
    printf("  tiled-WMMA2(CUTLASS): %.1f GFLOP/s   (%.4fx vs cuBLAS)\n", g_wmma2, g_wmma2/g_cublas);
    // Tensor-Core engagement test: H100 FP32 CUDA-core peak ~67 TFLOP/s.
    // own >> 67 TFLOP/s  => Tensor Cores engaged; ~2.5 TFLOP/s => CUDA-core FMA floor.
    double tflops_wmma2 = g_wmma2/1000.0;
    printf("\nTensor-Core engagement (H100 FP32 CUDA-core peak ~67 TFLOP/s):\n");
    printf("  tiled-WMMA2 = %.2f TFLOP/s -> %s\n", tflops_wmma2,
        tflops_wmma2 > 67.0 ? "TENSOR CORES ENGAGED (>67 TFLOP/s CUDA-core peak)"
      : (tflops_wmma2 < 10.0 ? "CUDA-CORE FMA FLOOR (TC NOT engaged)"
                             : "AMBIGUOUS (between FMA floor and TC peak)"));
    return 0;
}
