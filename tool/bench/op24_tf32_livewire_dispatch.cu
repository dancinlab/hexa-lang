// op24_tf32_livewire_dispatch.cu — HEXA-0POD OP-24 dispatch-unit verify.
//
// Verifies the OP-24 live wire at the DISPATCH-UNIT level: it replays the EXACT
// codepath added to self/cuda/runtime_cuda_emit.hexa's _hx_cuda_farr_matmul_gpu —
//   * FP64 default  : cublasDgemm on the FP64 row-major farr device buffers
//                     (the unchanged default path), and
//   * TF32 fastmode : cast the SAME FP64 device buffers down to fp32, run
//                     cublasGemmEx(CUBLAS_COMPUTE_32F_FAST_TF32) on a PEDANTIC-math
//                     handle, cast the fp32 result back up to the FP64 C buffer.
//
// The buffers, the row-major->col-major (Bf,N / Af,K / Cf,N) arg layout, the cast
// kernels, and the PEDANTIC handle are byte-for-byte the same as the wired runtime
// helper _hx_cuda_gemm_tf32_dev — so this is the LIVE dispatch logic in isolation,
// not the standalone OP-20 harness (which kept fp32 storage end-to-end). It proves
// the wire (FP64-in / FP64-out, TF32 compute) carries OP-20's three results.
//
// Gates (matching OP-20):
//   GATE-A  FP64-default byte-identical run-to-run  : the FP64 Dgemm dispatch is
//           bitwise stable (the opt-in branch never touches it).
//   GATE-B  TF32 self-byte-eq run-to-run            : max|delta(C_tf32)| == 0.
//   GATE-C  TF32 W14-tol vs FP64                    : rel-RMS(C_tf32 vs C_fp64) <= 1e-2.
//   SPEED   FP64_ms / TF32_ms through the live cast+GemmEx path (vs cublasDgemm).
//
// Build: nvcc -arch=sm_120 -O3 -o op24disp op24_tf32_livewire_dispatch.cu -lcublas
// Run:   ./op24disp M K N iters

#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

static void ck(cudaError_t e, const char* w){ if(e!=cudaSuccess){ printf("CUDA ERR %s: %s\n",w,cudaGetErrorString(e)); exit(2);} }
static void cbk(cublasStatus_t s, const char* w){ if(s!=CUBLAS_STATUS_SUCCESS){ printf("CUBLAS ERR %s: %d\n",w,(int)s); exit(3);} }

// ---- cast kernels: byte-for-byte the runtime _hx_k_cast_d2f / _hx_k_cast_f2d ----
__global__ void cast_d2f(const double* __restrict__ src, float* __restrict__ dst, int64_t n){
    int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) dst[i]=(float)src[i];
}
__global__ void cast_f2d(const float* __restrict__ src, double* __restrict__ dst, int64_t n){
    int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) dst[i]=(double)src[i];
}

// ---- FP64 default dispatch: the unchanged cublasDgemm path (row-major C=A.B) ----
// cublas sees row-major as col-major transposed -> Dgemm(N,N, m=N,n=M,k=K, B,N, A,K, C,N).
static void dispatch_fp64(cublasHandle_t h, double* A, double* B, double* C, int M,int K,int N){
    const double a=1.0,b=0.0;
    cbk(cublasDgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &a, B, N, A, K, &b, C, N), "Dgemm");
}

// ---- TF32 fastmode dispatch: the wired _hx_cuda_gemm_tf32_dev logic verbatim ----
// FP64 device buffers in -> cast down -> GemmEx TF32 (PEDANTIC) -> cast up -> FP64 C.
static void dispatch_tf32(cublasHandle_t h, double* A, double* B, double* C,
                          float* Af, float* Bf, float* Cf, int M,int K,int N){
    int64_t nA=(int64_t)M*K, nB=(int64_t)K*N, nC=(int64_t)M*N;
    cast_d2f<<<(unsigned)((nA+255)/256),256>>>(A,Af,nA);
    cast_d2f<<<(unsigned)((nB+255)/256),256>>>(B,Bf,nB);
    const float a=1.f,b=0.f;
    cbk(cublasGemmEx(h, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &a,
                     Bf, CUDA_R_32F, N, Af, CUDA_R_32F, K, &b,
                     Cf, CUDA_R_32F, N,
                     CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP), "GemmEx-TF32");
    cast_f2d<<<(unsigned)((nC+255)/256),256>>>(Cf,C,nC);
}

int main(int argc,char**argv){
    int M = argc>1? atoi(argv[1]) : 768;
    int K = argc>2? atoi(argv[2]) : 768;
    int N = argc>3? atoi(argv[3]) : 768;
    int iters = argc>4? atoi(argv[4]) : 50;
    int64_t nA=(int64_t)M*K, nB=(int64_t)K*N, nC=(int64_t)M*N;

    // deterministic host init (fixed seed) so every run starts bit-identical.
    double *hA=(double*)malloc(nA*sizeof(double)), *hB=(double*)malloc(nB*sizeof(double));
    unsigned long s=88172645463325252ULL;
    auto rnd=[&](){ s^=s<<13; s^=s>>7; s^=s<<17; return ((double)(s>>11)/9007199254740992.0)*2.0-1.0; };
    for(int64_t i=0;i<nA;i++) hA[i]=rnd()*0.1;
    for(int64_t i=0;i<nB;i++) hB[i]=rnd()*0.1;

    double *A,*B,*Cf64,*Ct32; float *Af,*Bf,*Cf;
    ck(cudaMalloc(&A,nA*sizeof(double)),"A"); ck(cudaMalloc(&B,nB*sizeof(double)),"B");
    ck(cudaMalloc(&Cf64,nC*sizeof(double)),"Cf64"); ck(cudaMalloc(&Ct32,nC*sizeof(double)),"Ct32");
    ck(cudaMalloc(&Af,nA*sizeof(float)),"Af"); ck(cudaMalloc(&Bf,nB*sizeof(float)),"Bf"); ck(cudaMalloc(&Cf,nC*sizeof(float)),"Cf");
    ck(cudaMemcpy(A,hA,nA*sizeof(double),cudaMemcpyHostToDevice),"hA");
    ck(cudaMemcpy(B,hB,nB*sizeof(double),cudaMemcpyHostToDevice),"hB");

    // FP64 default handle (fp64-strict, mirrors g_cublas).
    cublasHandle_t hF; cbk(cublasCreate(&hF),"create-fp64"); cbk(cublasSetMathMode(hF,CUBLAS_DEFAULT_MATH),"mm-fp64");
    // TF32 handle: PEDANTIC pin = portable self-byte-eq (mirrors g_cublas_tf32).
    cublasHandle_t hT; cbk(cublasCreate(&hT),"create-tf32"); cbk(cublasSetMathMode(hT,CUBLAS_PEDANTIC_MATH),"mm-tf32");

    double *r1=(double*)malloc(nC*sizeof(double)), *r2=(double*)malloc(nC*sizeof(double));
    double *t1=(double*)malloc(nC*sizeof(double)), *t2=(double*)malloc(nC*sizeof(double));

    // GATE-A: FP64 default byte-identical run-to-run.
    dispatch_fp64(hF,A,B,Cf64,M,K,N); ck(cudaDeviceSynchronize(),"syncF1");
    ck(cudaMemcpy(r1,Cf64,nC*sizeof(double),cudaMemcpyDeviceToHost),"r1");
    dispatch_fp64(hF,A,B,Cf64,M,K,N); ck(cudaDeviceSynchronize(),"syncF2");
    ck(cudaMemcpy(r2,Cf64,nC*sizeof(double),cudaMemcpyDeviceToHost),"r2");
    double fp64_dmax=0; for(int64_t i=0;i<nC;i++){ double d=fabs(r1[i]-r2[i]); if(d>fp64_dmax)fp64_dmax=d; }
    printf("[GATE-A] FP64-default M=%d K=%d N=%d  run-to-run max|delta| = %.3e  (byte-identical ==0: %s)\n",
           M,K,N,fp64_dmax, fp64_dmax==0.0?"YES":"NO");

    // GATE-B: TF32 self-byte-eq run-to-run.
    dispatch_tf32(hT,A,B,Ct32,Af,Bf,Cf,M,K,N); ck(cudaDeviceSynchronize(),"syncT1");
    ck(cudaMemcpy(t1,Ct32,nC*sizeof(double),cudaMemcpyDeviceToHost),"t1");
    dispatch_tf32(hT,A,B,Ct32,Af,Bf,Cf,M,K,N); ck(cudaDeviceSynchronize(),"syncT2");
    ck(cudaMemcpy(t2,Ct32,nC*sizeof(double),cudaMemcpyDeviceToHost),"t2");
    double tf32_dmax=0; for(int64_t i=0;i<nC;i++){ double d=fabs(t1[i]-t2[i]); if(d>tf32_dmax)tf32_dmax=d; }
    printf("[GATE-B] TF32-live   M=%d K=%d N=%d  run-to-run max|delta| = %.3e  (self-byte-eq ==0: %s)\n",
           M,K,N,tf32_dmax, tf32_dmax==0.0?"YES":"NO");

    // GATE-C: TF32 W14-tol vs FP64 (rel-RMS).
    double num=0,den=0; for(int64_t i=0;i<nC;i++){ double d=t1[i]-r1[i]; num+=d*d; den+=r1[i]*r1[i]; }
    double relrms = den>0? sqrt(num/den) : 0.0;
    printf("[GATE-C] TF32-vs-FP64 M=%d K=%d N=%d  rel-RMS = %.3e  (W14 <=1e-2: %s)\n",
           M,K,N,relrms, relrms<=1e-2?"YES":"NO");

    // SPEED: FP64_ms / TF32_ms through the live dispatch paths.
    cudaEvent_t e0,e1; cudaEventCreate(&e0); cudaEventCreate(&e1);
    for(int w=0;w<5;w++) dispatch_fp64(hF,A,B,Cf64,M,K,N); ck(cudaDeviceSynchronize(),"warmF");
    cudaEventRecord(e0); for(int i=0;i<iters;i++) dispatch_fp64(hF,A,B,Cf64,M,K,N); cudaEventRecord(e1);
    cudaEventSynchronize(e1); float fms=0; cudaEventElapsedTime(&fms,e0,e1); fms/=iters;
    for(int w=0;w<5;w++) dispatch_tf32(hT,A,B,Ct32,Af,Bf,Cf,M,K,N); ck(cudaDeviceSynchronize(),"warmT");
    cudaEventRecord(e0); for(int i=0;i<iters;i++) dispatch_tf32(hT,A,B,Ct32,Af,Bf,Cf,M,K,N); cudaEventRecord(e1);
    cudaEventSynchronize(e1); float tms=0; cudaEventElapsedTime(&tms,e0,e1); tms/=iters;
    double ratio = tms>0? fms/tms : 0.0;
    printf("[SPEED]  M=%d K=%d N=%d  TF32_ms=%.4f  FP64_ms=%.4f  FP64/TF32=%.3fx\n", M,K,N,tms,fms,ratio);

    int passA = fp64_dmax==0.0, passB = tf32_dmax==0.0, passC = relrms<=1e-2;
    printf("[RESULT] OP-24 LIVEWIRE M=%d K=%d N=%d  fp64ByteId=%s  tf32SelfByteEq=%s  relRMSvsFP64=%.3e(W14:%s)  FP64/TF32=%.3fx  GATES=%s\n",
           M,K,N, passA?"Y":"N", passB?"Y":"N", relrms, passC?"Y":"N", ratio,
           (passA&&passB&&passC)?"PASS":"FAIL");

    cublasDestroy(hF); cublasDestroy(hT);
    cudaFree(A);cudaFree(B);cudaFree(Cf64);cudaFree(Ct32);cudaFree(Af);cudaFree(Bf);cudaFree(Cf);
    free(hA);free(hB);free(r1);free(r2);free(t1);free(t2);
    return (passA&&passB&&passC)?0:1;
}
