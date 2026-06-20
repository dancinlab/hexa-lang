// own_tf32_production_path.cu — census r3 (7->0) PRODUCTION-PATH measurement.
//
// Includes the EMITTED production runtime_cuda.c (from runtime_cuda_emit.hexa via
// tool/emit_runtime_cuda_via_python.py) so the EXACT emitted static functions are
// exercised — NOT a standalone re-copy of the kernel. We call:
//   _hx_cuda_gemm_tf32_own_dev   (HEXA_TF32_OWN=1 path: mma.sync parity own-GEMM)
//   _hx_cuda_gemm_tf32_dev       (default TF32 path:    cublasGemmEx)
// directly on FP64 device buffers, exactly as _hx_cuda_farr_matmul_gpu dispatches.
//
// Compares own vs cublasGemmEx-TF32 (same-dtype accuracy) and FP64 reference; reports
// own/cuBLAS speed ratio + rel-RMS per square shape d=512/1024/2048/4096.
//
// Build (aiden, sm_120): nvcc -O3 -arch=sm_120 -DHEXA_CUDA -x cu \
//   tool/own_tf32_production_path.cu -o /tmp/owntf_prod -lcudart -lcublas
//
#define OWNTF_PROD_HARNESS 1
#include "OWNTF_RUNTIME_C"   // replaced by build script with emitted /tmp/runtime_cuda.c path

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define HCK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)

static void fill(double* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.0-0.5)*0.2; }
}

// FP64 reference cuBLAS Dgemm via the runtime's own g_cublas handle path is internal;
// do a direct cublasDgemm here for the FP64 oracle (row-major C=A.B -> col trick).
static double* d_alloc(long long n){ double* p; HCK(cudaMalloc((void**)&p,(size_t)n*sizeof(double))); return p; }

int main(int argc,char**argv){
    int sizes[4] = {512,1024,2048,4096};
    cublasHandle_t cbref; cublasCreate(&cbref);
    printf("=== census r3 PRODUCTION-PATH own-TF32 vs cublasGemmEx-TF32 (sm_120) ===\n");
    printf("%-6s %-14s %-14s %-9s %-12s %-12s\n","d","own TFLOP/s","cuBLAS TFLOP/s","own/cuB","own relRMS","cuB relRMS");
    for(int si=0; si<4; si++){
        int S=sizes[si]; long long M=S,N=S,K=S;
        long long szA=M*K, szB=K*N, szC=M*N;
        double *hA=(double*)malloc(szA*8),*hB=(double*)malloc(szB*8);
        double *hOwn=(double*)malloc(szC*8),*hCub=(double*)malloc(szC*8),*hRef=(double*)malloc(szC*8);
        fill(hA,szA,11); fill(hB,szB,22);
        double *dA=d_alloc(szA),*dB=d_alloc(szB),*dCown=d_alloc(szC),*dCcub=d_alloc(szC),*dRef=d_alloc(szC);
        HCK(cudaMemcpy(dA,hA,szA*8,cudaMemcpyHostToDevice));
        HCK(cudaMemcpy(dB,hB,szB*8,cudaMemcpyHostToDevice));

        // FP64 reference: row-major C=A.B -> cublasDgemm(N,N, N,M,K, B,N, A,K, C,N)
        const double a1=1.0,b0=0.0;
        cublasDgemm(cbref,CUBLAS_OP_N,CUBLAS_OP_N,(int)N,(int)M,(int)K,&a1,dB,(int)N,dA,(int)K,&b0,dRef,(int)N);
        HCK(cudaDeviceSynchronize());

        // PRODUCTION emitted functions (static, visible via include).
        if(_hx_cuda_gemm_tf32_own_dev(dA,dB,dCown,M,K,N)!=0){ printf("own dispatch FAIL d=%d\n",S); return 4; }
        if(_hx_cuda_gemm_tf32_dev    (dA,dB,dCcub,M,K,N)!=0){ printf("cub dispatch FAIL d=%d\n",S); return 4; }
        HCK(cudaDeviceSynchronize());

        HCK(cudaMemcpy(hOwn,dCown,szC*8,cudaMemcpyDeviceToHost));
        HCK(cudaMemcpy(hCub,dCcub,szC*8,cudaMemcpyDeviceToHost));
        HCK(cudaMemcpy(hRef,dRef,szC*8,cudaMemcpyDeviceToHost));
        // rel-RMS vs FP64 ref
        double seO=0,seC=0,sr=0;
        for(long long i=0;i<szC;i++){ double r=hRef[i]; sr+=r*r;
            double dO=hOwn[i]-r, dC=hCub[i]-r; seO+=dO*dO; seC+=dC*dC; }
        double relO = sr>0? sqrt(seO/szC)/sqrt(sr/szC):0.0;
        double relC = sr>0? sqrt(seC/szC)/sqrt(sr/szC):0.0;

        // perf timing — both via the production dispatchers (incl cast + alloc overhead,
        // i.e. the REAL emitted cost). 30 iters after 3 warmup.
        int warm=3, iters=30;
        for(int w=0;w<warm;w++){ _hx_cuda_gemm_tf32_own_dev(dA,dB,dCown,M,K,N); }
        HCK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) _hx_cuda_gemm_tf32_own_dev(dA,dB,dCown,M,K,N);
        cudaEventRecord(t1); HCK(cudaEventSynchronize(t1));
        float msO=0; cudaEventElapsedTime(&msO,t0,t1); double ms1O=msO/iters;
        for(int w=0;w<warm;w++){ _hx_cuda_gemm_tf32_dev(dA,dB,dCcub,M,K,N); }
        HCK(cudaDeviceSynchronize());
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) _hx_cuda_gemm_tf32_dev(dA,dB,dCcub,M,K,N);
        cudaEventRecord(t1); HCK(cudaEventSynchronize(t1));
        float msC=0; cudaEventElapsedTime(&msC,t0,t1); double ms1C=msC/iters;
        double flops=2.0*(double)M*N*K;
        double tfO=flops/(ms1O*1e-3)/1e12, tfC=flops/(ms1C*1e-3)/1e12;
        printf("%-6d %-14.2f %-14.2f %-9.3f %-12.2e %-12.2e\n",S,tfO,tfC,tfO/tfC,relO,relC);
        fflush(stdout);
        cudaFree(dA);cudaFree(dB);cudaFree(dCown);cudaFree(dCcub);cudaFree(dRef);
        free(hA);free(hB);free(hOwn);free(hCub);free(hRef);
    }
    printf("=== done ===\n");
    return 0;
}
