// avec_float4_driver.cu — A-VEC float4 own-GEMM A/B harness (HEXA-FUSION).
//
// Closes the loop on A2 (#2725, CLOSED-NEGATIVE): A2 named the residual skinny
// bottleneck as "the un-vectorized 32-bit scalar global-load inner loop of the
// 16×16-tiled split-K partial kernel". This driver measures whether float4
// (128-bit) vectorized loads + a VECW=4 register-blocked tile close a
// measurable fraction of that scalar-load gap, on the SAME GPU, against:
//   • cuBLAS (Sgemm, TF32 math, the oracle/baseline)
//   • _hx_k_sgemm_cm_splitk      (scalar split-K — A2's "current")
//   • _hx_k_sgemm_cm_splitk_vec  (float4 vectorized — the A-VEC variant)
//
// Shapes (the two A2-named LoRA skinny GEMMs + the square reference):
//   dA : M=4096 N=16   K=8192   (skinny-N, huge K)   tA=0 tB=0
//   dB : M=16   N=4096 K=8192   (skinny-M, huge K)   tA=0 tB=0
//   sq : M=N=K=2048                                    tA=0 tB=0
// (No transpose here — the harness builds A/B with the natural col-major layout
//  the vec kernel's row-contiguous float4 path targets; faithful col-major
//  cublasSgemm semantics C[i+j·ldc]=α·Σ A·B+β·C, alpha=1 beta=0.)
//
// HARD GATE (g5): correctness PASS (rel-RMS ≤ 3e-3) is REQUIRED before any
// perf number is meaningful. [OWN-SGEMM-VEC-FIRED] fires from the kernel's
// own launcher in-tree; this standalone driver prints an explicit VEC-FIRED
// marker when it dispatches the vec kernel so the probe is observable here too.
//
// Build:  see tool/avec_build_and_measure.sh  (extracts the 4 kernels verbatim)
// Run:    ./avec_float4_driver [iters]

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <mma.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// The 4 kernels (_hx_k_sgemm_cm_betascale, _hx_k_sgemm_cm_splitk,
// _hx_k_sgemm_cm_splitk_vec, _hx_k_sgemm_cm_wmma2) extracted verbatim from the
// shipped hxqwen14b_cuda.cu so the measured code IS the shipped code.
#include "avec_kernels_extracted.cuh"

static cublasHandle_t g_h;

static double rel_rms(const float* ref, const float* got, long long n) {
    double se = 0.0, sr = 0.0;
    for (long long i = 0; i < n; i++) {
        double d = (double)got[i] - (double)ref[i];
        se += d*d; sr += (double)ref[i]*(double)ref[i];
    }
    return sqrt(se / (sr > 0 ? sr : 1.0));
}

// Run one shape: cuBLAS oracle vs scalar split-K vs float4 vec split-K.
// G = split factor (clamp(k/512,1,32)), same as the in-tree launcher.
static int run_shape(const char* tag, int M, int N, int K, int iters) {
    long long szA=(long long)M*K, szB=(long long)K*N, szC=(long long)M*N;
    float *hA=(float*)malloc(szA*4), *hB=(float*)malloc(szB*4);
    float *hRef=(float*)malloc(szC*4), *hGot=(float*)malloc(szC*4);
    srand(1234);
    for (long long i=0;i<szA;i++) hA[i]=(float)(rand()%2001-1000)/1000.0f;
    for (long long i=0;i<szB;i++) hB[i]=(float)(rand()%2001-1000)/1000.0f;
    float *dA,*dB,*dC; cudaMalloc(&dA,szA*4); cudaMalloc(&dB,szB*4); cudaMalloc(&dC,szC*4);
    cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice);
    cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice);
    float alpha=1.0f, beta=0.0f;
    int G=K/512; if(G<1)G=1; if(G>32)G=32;

    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    auto timed=[&](auto launch)->float{
        launch(); cudaDeviceSynchronize();
        cudaEventRecord(e0);
        for(int it=0;it<iters;it++) launch();
        cudaEventRecord(e1); cudaEventSynchronize(e1);
        float ms=0; cudaEventElapsedTime(&ms,e0,e1); return ms/iters;
    };

    // 1) cuBLAS oracle (col-major, no transpose)
    float t_cublas=timed([&]{
        cublasSgemm(g_h,CUBLAS_OP_N,CUBLAS_OP_N,M,N,K,&alpha,dA,M,dB,K,&beta,dC,M);
    });
    cudaMemcpy(hRef,dC,szC*4,cudaMemcpyDeviceToHost);

    dim3 sblk(16,16);
    dim3 sgrd_scale((unsigned)((M+15)/16),(unsigned)((N+15)/16));
    dim3 sgrd((unsigned)((M+15)/16),(unsigned)((N+15)/16),(unsigned)G);

    // 2) scalar split-K (A2 "current")
    float t_scalar=timed([&]{
        _hx_k_sgemm_cm_betascale<<<sgrd_scale,sblk>>>((long long)M,(long long)N,beta,dC,(long long)M);
        _hx_k_sgemm_cm_splitk<<<sgrd,sblk>>>(0,0,(long long)M,(long long)N,(long long)K,
            alpha,dA,(long long)M,dB,(long long)K,dC,(long long)M,G);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_scalar=rel_rms(hRef,hGot,szC);

    // 3) float4 vectorized split-K (the A-VEC variant)
    dim3 vblk(16/4,16);   // (HXSK/HXVECW)×HXSK = 4×16 = 64 threads
    dim3 vgrd((unsigned)((M+15)/16),(unsigned)((N+15)/16),(unsigned)G);
    static int vfired=0; if(!vfired){vfired=1; fprintf(stderr,"[OWN-SGEMM-VEC-FIRED] driver -> _hx_k_sgemm_cm_splitk_vec (float4 128-bit, VECW=4 register-blocked)\n");}
    float t_vec=timed([&]{
        _hx_k_sgemm_cm_betascale<<<sgrd_scale,sblk>>>((long long)M,(long long)N,beta,dC,(long long)M);
        _hx_k_sgemm_cm_splitk_vec<<<vgrd,vblk>>>(0,0,(long long)M,(long long)N,(long long)K,
            alpha,dA,(long long)M,dB,(long long)K,dC,(long long)M,G);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_vec=rel_rms(hRef,hGot,szC);

    int pass_scalar = rms_scalar<=3e-3, pass_vec = rms_vec<=3e-3;
    // gap closed: cuBLAS is 1.00x. scalar is t_scalar/t_cublas off; vec is
    // t_vec/t_cublas off. Fraction of the (scalar-cuBLAS) gap that vec closes:
    //   frac = (t_scalar - t_vec) / (t_scalar - t_cublas)
    double gap_scalar = t_scalar - t_cublas;
    double frac_closed = (gap_scalar>1e-9) ? (t_scalar - t_vec)/gap_scalar : 0.0;

    printf("\n=== %s : M=%d N=%d K=%d  G=%d  iters=%d ===\n", tag,M,N,K,G,iters);
    printf("  cuBLAS (TF32)      : %.5f ms/iter   (1.00x baseline)\n", t_cublas);
    printf("  scalar split-K     : %.5f ms/iter   (%.2fx vs cuBLAS)   rel-RMS=%.3e %s\n",
           t_scalar, t_scalar/t_cublas, rms_scalar, pass_scalar?"PASS":"FAIL");
    printf("  float4 VEC split-K : %.5f ms/iter   (%.2fx vs cuBLAS)   rel-RMS=%.3e %s\n",
           t_vec, t_vec/t_cublas, rms_vec, pass_vec?"PASS":"FAIL");
    printf("  scalar->vec speedup: %.3fx     fraction of (scalar->cuBLAS) gap closed by vec: %.1f%%\n",
           t_scalar/t_vec, frac_closed*100.0);
    if(!pass_vec) printf("  [g5] CORRECTNESS FAIL on vec — perf number NOT a valid claim for this shape\n");

    cudaFree(dA);cudaFree(dB);cudaFree(dC);
    free(hA);free(hB);free(hRef);free(hGot);
    return pass_vec ? 0 : 1;
}

int main(int argc, char** argv) {
    int iters = (argc>=2)?atoi(argv[1]):50;
    cublasCreate(&g_h);
    cublasSetMathMode(g_h, CUBLAS_TF32_TENSOR_OP_MATH);
    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("A-VEC float4 own-GEMM A/B — cuBLAS vs scalar split-K vs float4 vec split-K\n");
    printf("g5: rel-RMS <= 3e-3 HARD gate (TF32); perf is meaningless unless vec PASSes.\n");

    int fail = 0;
    fail |= run_shape("dA (skinny-N)", 4096, 16,   8192, iters);
    fail |= run_shape("dB (skinny-M)", 16,   4096, 8192, iters);
    fail |= run_shape("sq (square)",   2048, 2048, 2048, iters);

    printf("\n=== VERDICT: %s ===\n", fail? "at least one shape FAILED rel-RMS gate" : "all shapes PASS rel-RMS <= 3e-3");
    return fail;
}
