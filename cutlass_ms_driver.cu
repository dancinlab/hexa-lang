// cutlass_ms_driver.cu — standalone A/B for the HEXA-FUSION A3 multi-stage
// own-GEMM. Compares cuBLAS (Sgemm oracle, TF32) vs WMMA2 (current double-buffer
// CUTLASS-grade) vs WMMA2-MS (A3: N-stage cp.async ring + skewed shared) on the
// SAME GPU, SAME inputs.
//   • Correctness: each own kernel vs cuBLAS oracle, rel-RMS (TF32 tol 3e-3).
//     HARD GATE: WMMA2-MS rel-RMS <= 3e-3 — no perf claim if it fails.
//   • Perf: CUDA-event timing, 50 iters, square shapes (default 2048^3).
// The kernels are #included verbatim (gemm_kernels_extracted.cuh) from the .cu
// under test so the measured code IS the shipped code (no copy drift).
//
// Build:  nvcc -O3 -arch=sm_90 -lcublas cutlass_ms_driver.cu -o cutlass_ms_driver
// Run:    ./cutlass_ms_driver [M N K iters]

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <mma.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "gemm_kernels_extracted.cuh"

static cublasHandle_t g_cublas_handle;

static double rel_rms(const float* ref, const float* got, long long n) {
    double se = 0.0, sr = 0.0;
    for (long long i = 0; i < n; i++) {
        double d = (double)got[i] - (double)ref[i];
        se += d*d; sr += (double)ref[i]*(double)ref[i];
    }
    return sqrt(se / (sr > 0 ? sr : 1.0));
}

struct Res { float ms; double rms; };

int main(int argc, char** argv) {
    long long M = 2048, N = 2048, K = 2048; int iters = 50;
    if (argc >= 4) { M = atoll(argv[1]); N = atoll(argv[2]); K = atoll(argv[3]); }
    if (argc >= 5) iters = atoi(argv[4]);
    cublasCreate(&g_cublas_handle);
    cublasSetMathMode(g_cublas_handle, CUBLAS_TF32_TENSOR_OP_MATH);

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

    // Opt-in to >48KB dynamic shared for the MS kernel.
    size_t ms_smem = (size_t)HXG_MS_STAGES * (HXG_A_STAGE + HXG_B_STAGE) * sizeof(float);
    cudaError_t attr = cudaFuncSetAttribute((const void*)_hx_k_sgemm_cm_wmma2_ms,
                            cudaFuncAttributeMaxDynamicSharedMemorySize, (int)ms_smem);
    if (attr != cudaSuccess)
        printf("WARN: set dynamic smem attr (%zu bytes) -> %s\n", ms_smem, cudaGetErrorString(attr));

    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    auto timed = [&](auto launch)->float{
        launch(); cudaDeviceSynchronize();
        cudaEventRecord(e0);
        for (int it=0; it<iters; it++) launch();
        cudaEventRecord(e1); cudaEventSynchronize(e1);
        float ms=0; cudaEventElapsedTime(&ms,e0,e1);
        return ms/iters;
    };

    // 1) cuBLAS oracle: C(MxN)=A(MxK)*B(KxN), col-major, no-transpose.
    float t_cublas = timed([&]{
        cublasSgemm(g_cublas_handle, CUBLAS_OP_N, CUBLAS_OP_N,
                    (int)M,(int)N,(int)K, &alpha, dA,(int)M, dB,(int)K, &beta, dC,(int)M);
    });
    cudaMemcpy(hRef,dC,szC*4,cudaMemcpyDeviceToHost);

    // 2) WMMA2 (current double-buffer CUTLASS-grade)
    cudaMemset(dC,0,szC*4);
    dim3 w2blk(256), w2grd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N+HXG_BN-1)/HXG_BN));
    float t_wmma2 = timed([&]{
        _hx_k_sgemm_cm_wmma2<<<w2grd,w2blk>>>(0,0,M,N,K, alpha, dA,M, dB,K, beta, dC,M);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_wmma2 = rel_rms(hRef,hGot,szC);

    // 3) WMMA2-MS (A3: N-stage cp.async ring + skewed shared)
    cudaMemset(dC,0,szC*4);
    dim3 msblk(256), msgrd((unsigned)((M+HXG_BM-1)/HXG_BM),(unsigned)((N+HXG_BN-1)/HXG_BN));
    float t_ms = timed([&]{
        _hx_k_sgemm_cm_wmma2_ms<<<msgrd,msblk,ms_smem>>>(0,0,M,N,K, alpha, dA,M, dB,K, beta, dC,M);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_ms = rel_rms(hRef,hGot,szC);

    cudaError_t lerr = cudaGetLastError();

    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("MS stages=%d  skew=%d floats  (As ld=%d, Bs ld=%d, smem=%zuKB/block)\n",
           HXG_MS_STAGES, HXG_SKEW, HXG_ALD, HXG_BLD, ms_smem/1024);
    printf("shape: M=%lld N=%lld K=%lld  iters=%d  (col-major, no-transpose, alpha=1 beta=0)\n",M,N,K,iters);
    printf("last CUDA err: %s\n", cudaGetErrorString(lerr));
    printf("\n3-way ms/iter (single GEMM, CUDA-event):\n");
    printf("  cuBLAS (TF32)        : %.5f ms/iter   (1.00x)\n", t_cublas);
    printf("  WMMA2 (double-buffer): %.5f ms/iter   (%.4fx vs cuBLAS)\n", t_wmma2, t_wmma2/t_cublas);
    printf("  WMMA2-MS (A3)        : %.5f ms/iter   (%.4fx vs cuBLAS)\n", t_ms,    t_ms/t_cublas);
    printf("\nWMMA2 -> WMMA2-MS speedup : %.4fx\n", t_wmma2/t_ms);
    printf("ratio-vs-cuBLAS  before(WMMA2)=%.4fx  after(WMMA2-MS)=%.4fx\n", t_wmma2/t_cublas, t_ms/t_cublas);
    {
        double before = t_wmma2/t_cublas, after = t_ms/t_cublas;
        double residual_before = before - 1.0, residual_after = after - 1.0;
        double frac_closed = (residual_before>1e-9) ? (residual_before-residual_after)/residual_before : 0.0;
        printf("residual-vs-cuBLAS  before=%.1f%%  after=%.1f%%  fraction-of-residual-closed=%.1f%%\n",
               residual_before*100.0, residual_after*100.0, frac_closed*100.0);
    }
    printf("\ncorrectness (own vs cuBLAS oracle, rel-RMS, TF32 tol 3e-3):\n");
    printf("  WMMA2    rel-RMS = %.3e  %s\n", rms_wmma2, rms_wmma2<=3e-3?"PASS":"FAIL");
    printf("  WMMA2-MS rel-RMS = %.3e  %s   <-- HARD GATE\n", rms_ms, rms_ms<=3e-3?"PASS":"FAIL");
    return (rms_ms<=3e-3) ? 0 : 2;
}
