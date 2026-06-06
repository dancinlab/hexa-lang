// a_skinny_splitk2_driver.cu — A-SKINNY two-pass atomic-free split-K A/B harness.
//
// HEXA-FUSION A-family, the LAST own-GEMM-vs-cuBLAS skinny gap. Prior verdicts:
//   • F-FUSION-SPLITK-SKINNY (#2714): scalar split-K closed 64-66% of the
//     step-time gap; NAMED residual-of-residual §4a: the single-pass atomicAdd
//     into a tiny 16-wide output column SERIALIZES G writers on the same cache
//     lines. Verbatim fix: "A two-pass split-K (partials buffer + a tree
//     reduction kernel) ... would recover more — a further separable kernel
//     step, NOT a tuning knob."
//   • F-FUSION-AVEC-FLOAT4 (#2738): float4 closed 16% of the scalar gap on dA
//     (skinny-N) but REGRESSED dB (skinny-M, M=16) by -90% — float4 row-block
//     is the wrong regime for skinny-M. So the skinny-M residual is UNADDRESSED.
//
// This driver measures the never-built two-pass kernel against:
//   • cuBLAS (Sgemm, TF32 math — the roofline oracle / 1.00x baseline)
//   • _hx_k_sgemm_cm_splitk          (scalar single-pass split-K, atomicAdd)
//   • _hx_k_sgemm_cm_splitk2 (PASS1 partial + PASS2 reduce, atomic-free)
//
// Shapes = the REAL 5 skinny R=16 LoRA GEMMs of clm_prod (the named target),
// where M is the LoRA-output (tiny) dim and K large. Plus a square reference.
// faithful col-major cublasSgemm: C[i+j·ldc]=α·Σ A·B+β·C, alpha=1 beta=0.
//
// HARD GATE (g5): rel-RMS <= 3e-3 (TF32) REQUIRED before any perf is a claim.
// [OWN-SGEMM-SPLITK2-FIRED] prints when the two-pass arm dispatches.
//
// Build: tool/a_skinny_splitk2_build.sh    Run: ./a_skinny_splitk2_driver [iters]

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <mma.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// Kernels (betascale, splitk, splitk2_partial, splitk2_reduce, splitk_vec,
// wmma2) extracted verbatim from the shipped hxqwen14b_cuda.cu so the measured
// code IS the shipped code.
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

// One shape: cuBLAS oracle vs scalar split-K vs two-pass atomic-free split-K.
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

    // Scratch partials buffer for the two-pass kernel: G·M·N floats.
    float* dP=nullptr; cudaMalloc(&dP,(size_t)G*(size_t)szC*sizeof(float));

    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    auto timed=[&](auto launch)->float{
        launch(); cudaDeviceSynchronize();
        cudaEventRecord(e0);
        for(int it=0;it<iters;it++) launch();
        cudaEventRecord(e1); cudaEventSynchronize(e1);
        float ms=0; cudaEventElapsedTime(&ms,e0,e1); return ms/iters;
    };

    // 1) cuBLAS oracle (col-major, no transpose) — the roofline.
    float t_cublas=timed([&]{
        cublasSgemm(g_h,CUBLAS_OP_N,CUBLAS_OP_N,M,N,K,&alpha,dA,M,dB,K,&beta,dC,M);
    });
    cudaMemcpy(hRef,dC,szC*4,cudaMemcpyDeviceToHost);

    dim3 sblk(16,16);
    dim3 sgrd_scale((unsigned)((M+15)/16),(unsigned)((N+15)/16));
    dim3 sgrd((unsigned)((M+15)/16),(unsigned)((N+15)/16),(unsigned)G);

    // 2) scalar single-pass split-K (atomicAdd) — the named "current".
    float t_scalar=timed([&]{
        _hx_k_sgemm_cm_betascale<<<sgrd_scale,sblk>>>((long long)M,(long long)N,beta,dC,(long long)M);
        _hx_k_sgemm_cm_splitk<<<sgrd,sblk>>>(0,0,(long long)M,(long long)N,(long long)K,
            alpha,dA,(long long)M,dB,(long long)K,dC,(long long)M,G);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_scalar=rel_rms(hRef,hGot,szC);

    // 3) TWO-PASS atomic-free split-K — THE LEVER.
    dim3 rblk(16,16);
    dim3 rgrd((unsigned)((M+15)/16),(unsigned)((N+15)/16));
    static int s2fired=0; if(!s2fired){s2fired=1; fprintf(stderr,"[OWN-SGEMM-SPLITK2-FIRED] driver -> _hx_k_sgemm_cm_splitk2 (TWO-PASS atomic-free partials buffer + fixed-order reduce)\n");}
    float t_two=timed([&]{
        _hx_k_sgemm_cm_splitk2_partial<<<sgrd,sblk>>>(0,0,(long long)M,(long long)N,(long long)K,
            dA,(long long)M,dB,(long long)K,dP,G);
        _hx_k_sgemm_cm_splitk2_reduce<<<rgrd,rblk>>>((long long)M,(long long)N,
            alpha,beta,dP,dC,(long long)M,G);
    });
    cudaMemcpy(hGot,dC,szC*4,cudaMemcpyDeviceToHost);
    double rms_two=rel_rms(hRef,hGot,szC);

    int pass_scalar = rms_scalar<=3e-3, pass_two = rms_two<=3e-3;
    double gap_scalar = t_scalar - t_cublas;
    double frac_closed = (gap_scalar>1e-9) ? (t_scalar - t_two)/gap_scalar : 0.0;

    printf("\n=== %s : M=%d N=%d K=%d  G=%d  iters=%d ===\n", tag,M,N,K,G,iters);
    printf("  cuBLAS (TF32)        : %.5f ms/iter   (1.00x baseline)\n", t_cublas);
    printf("  scalar split-K       : %.5f ms/iter   (%.2fx vs cuBLAS)   rel-RMS=%.3e %s\n",
           t_scalar, t_scalar/t_cublas, rms_scalar, pass_scalar?"PASS":"FAIL");
    printf("  two-pass split-K     : %.5f ms/iter   (%.2fx vs cuBLAS)   rel-RMS=%.3e %s\n",
           t_two, t_two/t_cublas, rms_two, pass_two?"PASS":"FAIL");
    printf("  scalar->2pass speedup: %.3fx     fraction of (scalar->cuBLAS) gap closed by 2pass: %.1f%%\n",
           t_scalar/t_two, frac_closed*100.0);
    // own GFLOP/s (2*M*N*K flops): the verbatim own-vs-cuBLAS GFLOP/s the task wants.
    double flop = 2.0*(double)M*(double)N*(double)K;
    printf("  GFLOP/s  cuBLAS=%.1f  scalar=%.1f  two-pass=%.1f\n",
           flop/(t_cublas*1e6), flop/(t_scalar*1e6), flop/(t_two*1e6));
    if(!pass_two) printf("  [g5] CORRECTNESS FAIL on two-pass — perf number NOT a valid claim\n");

    cudaFree(dA);cudaFree(dB);cudaFree(dC);cudaFree(dP);
    free(hA);free(hB);free(hRef);free(hGot);
    return pass_two ? 0 : 1;
}

int main(int argc, char** argv) {
    int iters = (argc>=2)?atoi(argv[1]):50;
    cublasCreate(&g_h);
    cublasSetMathMode(g_h, CUBLAS_TF32_TENSOR_OP_MATH);
    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("GPU: %s (sm_%d%d)\n", p.name, p.major, p.minor);
    printf("A-SKINNY two-pass atomic-free split-K A/B — cuBLAS vs scalar split-K vs two-pass\n");
    printf("g5: rel-RMS <= 3e-3 HARD gate (TF32); PARITY/OWNERSHIP framing only, NO superiority claim.\n");

    int fail = 0;
    // The 5 real R=16 skinny LoRA GEMMs of clm_prod (per F-FUSION-SPLITK-SKINNY §2)
    // GEMM[0] fwd_tmp (16,8192) K4096 ; [2] bwd_u (16,8192) K4096 ; [3] bwd_tmp (16,8192) K4096
    // [4] bwd_dB (16,4096) K8192 ; [5] bwd_dA (4096,16) K8192
    fail |= run_shape("fwd_tmp  (m16,n8192,k4096)", 16,   8192, 4096, iters);
    fail |= run_shape("bwd_u    (m16,n8192,k4096)", 16,   8192, 4096, iters);
    fail |= run_shape("bwd_tmp  (m16,n8192,k4096)", 16,   8192, 4096, iters);
    fail |= run_shape("bwd_dB   (m16,n4096,k8192)", 16,   4096, 8192, iters);  // skinny-M, the worst
    fail |= run_shape("bwd_dA   (m4096,n16,k8192)", 4096, 16,   8192, iters);  // skinny-N
    fail |= run_shape("sq       (2048^3)",          2048, 2048, 2048, iters);

    printf("\n=== VERDICT: %s ===\n", fail? "at least one shape FAILED rel-RMS gate" : "all shapes PASS rel-RMS <= 3e-3");
    return fail;
}
