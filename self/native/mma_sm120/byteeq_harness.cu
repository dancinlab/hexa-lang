// byteeq_harness.cu — link TWO own-GEMM variants (renamed entry syms) and assert
// their device outputs are BIT-IDENTICAL (memcmp == 0), plus rel-RMS vs cuBLAS-TF32
// and an off-ratio perf line per variant. Used to PROVE r-sched / r-3xtf32 keep
// byte-eq vs the baseline (Round A) or report rel-RMS vs FP64 (Round B).
//
// Compile each variant .cu with -DGEMM_SYM=owngemm_<tag> so the extern "C" entry
// is uniquely named; this harness declares both and drives them.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

extern "C" void owngemm_base (float* C, const float* A, const float* B, int M, int K, int N);
extern "C" void owngemm_var  (float* C, const float* A, const float* B, int M, int K, int N);

static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
// FP64 reference on host (small sizes) for rel-RMS-vs-FP64 (Round B accuracy gate).
static void ref_fp64(const float*A,const float*B,double*R,int M,int N,int K){
    for(int i=0;i<M;i++)for(int j=0;j<N;j++){ double s=0; for(int k=0;k<K;k++) s+=(double)A[(long long)i*K+k]*(double)B[(long long)k*N+j]; R[(long long)i*N+j]=s; }
}

int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;   // 0=byteeq+gate, 1=+perf, 2=+fp64ref(small)
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4);
    float *hCb=(float*)malloc(szC*4),*hCv=(float*)malloc(szC*4),*hR=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dCb,*dCv,*dR;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4));
    CK(cudaMalloc(&dCb,szC*4)); CK(cudaMalloc(&dCv,szC*4)); CK(cudaMalloc(&dR,szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f, beta=0.f;
    CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
        dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
        dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CK(cudaDeviceSynchronize());

    // run base + variant
    owngemm_base(dCb,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("BASE FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    owngemm_var(dCv,dA,dB,M,K,N);
    e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("VAR FAULT: %s\n",cudaGetErrorString(e)); return 4; }

    CK(cudaMemcpy(hCb,dCb,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hCv,dCv,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));

    // byte-eq variant vs base
    int bitdiff = memcmp(hCb,hCv,szC*4);
    long long ndiff=0; double maxbd=0;
    for(size_t i=0;i<szC;i++){ if(hCb[i]!=hCv[i]){ndiff++; double d=fabs((double)hCb[i]-hCv[i]); if(d>maxbd)maxbd=d;} }

    // run-to-run determinism of the variant (2nd run, compare to 1st)
    owngemm_var(dCv,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
    float* hCv2=(float*)malloc(szC*4); CK(cudaMemcpy(hCv2,dCv,szC*4,cudaMemcpyDeviceToHost));
    int r2r = memcmp(hCv,hCv2,szC*4);

    // rel-RMS variant vs cuBLAS-TF32
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hCv[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;

    printf("[BYTEEQ] S=%d  variant-vs-base bitdiff=%d (ndiff=%lld max|d|=%.3e)  run2run=%d  %s\n",
           S, bitdiff, ndiff, maxbd, r2r, (bitdiff==0&&r2r==0)?"BYTE-EQ-PASS":"BYTE-EQ-FAIL");
    printf("[GATE]   S=%d  variant-vs-cuBLAS-TF32 rel-RMS=%.3e max|delta|=%.3e\n", S, relrms, maxd);

    if(MODE>=2 && (long long)szC <= 4096*4096){
        double* dref=(double*)malloc(szC*8);
        ref_fp64(hA,hB,dref,M,N,K);
        double se2=0,sr2=0; for(size_t i=0;i<szC;i++){ double dd=hCv[i]-dref[i]; se2+=dd*dd; sr2+=dref[i]*dref[i]; }
        double rr2 = sr2>0? sqrt(se2/szC)/sqrt(sr2/szC):0.0;
        // also cuBLAS-TF32 vs fp64 for context
        double se3=0,sr3=0; for(size_t i=0;i<szC;i++){ double dd=hR[i]-dref[i]; se3+=dd*dd; sr3+=dref[i]*dref[i]; }
        double rr3 = sr3>0? sqrt(se3/szC)/sqrt(sr3/szC):0.0;
        printf("[FP64]   S=%d  variant-vs-FP64 rel-RMS=%.3e   cuBLAS-TF32-vs-FP64 rel-RMS=%.3e\n", S, rr2, rr3);
        free(dref);
    }

    if(MODE>=1){
        int iters=50;
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        double flops=2.0*(double)M*N*K;
        // variant perf
        owngemm_var(dCv,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEventRecord(t0); for(int it=0;it<iters;it++) owngemm_var(dCv,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double vms=ms/iters, vtf=flops/(vms*1e-3)/1e12;
        // base perf
        owngemm_base(dCb,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEventRecord(t0); for(int it=0;it<iters;it++) owngemm_base(dCb,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double bms=ms/iters, btf=flops/(bms*1e-3)/1e12;
        // cuBLAS perf
        cudaEventRecord(t0); for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
            dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cms=ms/iters, ctf=flops/(cms*1e-3)/1e12;
        printf("[PERF]   S=%d  base %.2f (off %.3fx)  variant %.2f (off %.3fx)  cuBLAS %.2f TFLOP/s\n",
               S, btf, ctf/btf, vtf, ctf/vtf, ctf);
    }
    return (bitdiff==0&&r2r==0)?0:2;
}
