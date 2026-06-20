// own_tf32_mma_verify.cu — census r3 verify harness for the own TF32 mma.sync GEMM
// that replaces the last cuBLAS dependency (cublasGemmEx) in the forge runtime.
//
// Compares, on row-major C[M,N]=A[M,K].B[K,N] with FP64 device inputs:
//   (1) own TF32: _hx_k_gemm_tf32_mma  (WMMA 16x16x8 -> mma.sync.m16n8k8.f32.tf32)
//   (2) oracle  : cublasGemmEx COMPUTE_32F_FAST_TF32 (the path being replaced)
//   (3) ref     : FP64 host ikj GEMM
// Reports rel-RMS(own vs ref), rel-RMS(cublas vs ref), rel-RMS(own vs cublas),
// and own/cublas device GEMM speedup. sm_120 compile is proven by building this.
//
// The kernel body is a BYTE-COPY of the emitted _hx_k_gemm_tf32_mma in
// self/cuda/runtime_cuda_emit.hexa (keep in sync). Build on aiden:
//   nvcc -arch=sm_120 -O3 tool/own_tf32_mma_verify.cu -o /tmp/own_tf32 -lcublas -lcudart
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <mma.h>

#define CK(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA %s:%d %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); exit(1);} }while(0)

// ── byte-copy of the emitted _hx_k_gemm_tf32_mma kernel ─────────────────────
__global__ void _hx_k_gemm_tf32_mma(const double* __restrict__ A,
                                    const double* __restrict__ B,
                                    double* __restrict__ C,
                                    int64_t M, int64_t K, int64_t N) {
    const int64_t row0 = (int64_t)blockIdx.y * 16;
    const int64_t col0 = (int64_t)blockIdx.x * 16;
    __shared__ float As[16*8];
    __shared__ float Bs[8*16];
    __shared__ float Cs[16*16];
    nvcuda::wmma::fragment<nvcuda::wmma::matrix_a, 16,16,8, nvcuda::wmma::precision::tf32, nvcuda::wmma::row_major> a_frag;
    nvcuda::wmma::fragment<nvcuda::wmma::matrix_b, 16,16,8, nvcuda::wmma::precision::tf32, nvcuda::wmma::row_major> b_frag;
    nvcuda::wmma::fragment<nvcuda::wmma::accumulator, 16,16,8, float> c_frag;
    nvcuda::wmma::fill_fragment(c_frag, 0.0f);
    int tid = threadIdx.x;
    for (int64_t t = 0; t < K; t += 8) {
        for (int idx = tid; idx < 128; idx += 32) {
            int i = idx >> 3, l = idx & 7;
            int64_t r = row0 + i, kk = t + l;
            float v = (r < M && kk < K) ? (float)A[r * K + kk] : 0.0f;
            As[idx] = nvcuda::wmma::__float_to_tf32(v);
        }
        for (int idx = tid; idx < 128; idx += 32) {
            int l = idx >> 4, j = idx & 15;
            int64_t kk = t + l, c = col0 + j;
            float v = (kk < K && c < N) ? (float)B[kk * N + c] : 0.0f;
            Bs[idx] = nvcuda::wmma::__float_to_tf32(v);
        }
        __syncwarp();
        nvcuda::wmma::load_matrix_sync(a_frag, As, 8);
        nvcuda::wmma::load_matrix_sync(b_frag, Bs, 16);
        nvcuda::wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
        __syncwarp();
    }
    nvcuda::wmma::store_matrix_sync(Cs, c_frag, 16, nvcuda::wmma::mem_row_major);
    for (int idx = tid; idx < 256; idx += 32) {
        int i = idx >> 4, j = idx & 15;
        int64_t r = row0 + i, c = col0 + j;
        if (r < M && c < N) C[r * N + c] = (double)Cs[idx];
    }
}
__global__ void k_cast_d2f(const double* s, float* d, int64_t n){
    int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) d[i]=(float)s[i]; }
__global__ void k_cast_f2d(const float* s, double* d, int64_t n){
    int64_t i=(int64_t)blockIdx.x*blockDim.x+threadIdx.x; if(i<n) d[i]=(double)s[i]; }

static double now_s(void){ struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec*1e-9; }

static double rel_rms(const double* C, const double* ref, int64_t n){
    double num=0, den=0;
    for(int64_t i=0;i<n;i++){ double d=C[i]-ref[i]; num+=d*d; den+=ref[i]*ref[i]; }
    return den==0.0 ? (num==0.0?0.0:INFINITY) : sqrt(num/den);
}

static void run(int64_t d, int reps){
    int64_t M=d,K=d,N=d;
    double *hA=(double*)malloc(M*K*sizeof(double));
    double *hB=(double*)malloc(K*N*sizeof(double));
    double *hC=(double*)malloc(M*N*sizeof(double));
    double *ref=(double*)malloc(M*N*sizeof(double));
    uint64_t x=0x1234567u+(uint64_t)d;
    for(int64_t i=0;i<M*K;i++){ x^=x<<13;x^=x>>7;x^=x<<17; hA[i]=((double)(x&0xFFFFFFFFu)/4294967296.0)*2.0-1.0; }
    for(int64_t i=0;i<K*N;i++){ x^=x<<13;x^=x>>7;x^=x<<17; hB[i]=((double)(x&0xFFFFFFFFu)/4294967296.0)*2.0-1.0; }
    // FP64 ikj reference
    for(int64_t i=0;i<M*N;i++) ref[i]=0.0;
    for(int64_t i=0;i<M;i++) for(int64_t k=0;k<K;k++){ double av=hA[i*K+k];
        for(int64_t j=0;j<N;j++) ref[i*N+j]+=av*hB[k*N+j]; }

    double *dA,*dB,*dC; float *fA,*fB,*fC;
    CK(cudaMalloc(&dA,M*K*sizeof(double))); CK(cudaMalloc(&dB,K*N*sizeof(double))); CK(cudaMalloc(&dC,M*N*sizeof(double)));
    CK(cudaMalloc(&fA,M*K*sizeof(float)));  CK(cudaMalloc(&fB,K*N*sizeof(float)));  CK(cudaMalloc(&fC,M*N*sizeof(float)));
    CK(cudaMemcpy(dA,hA,M*K*sizeof(double),cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,K*N*sizeof(double),cudaMemcpyHostToDevice));

    // ── own TF32 mma.sync ──
    dim3 blk(32); dim3 grd((unsigned)((N+15)/16),(unsigned)((M+15)/16));
    _hx_k_gemm_tf32_mma<<<grd,blk>>>(dA,dB,dC,M,K,N); CK(cudaGetLastError()); CK(cudaDeviceSynchronize());
    double t0=now_s();
    for(int r=0;r<reps;r++) _hx_k_gemm_tf32_mma<<<grd,blk>>>(dA,dB,dC,M,K,N);
    CK(cudaDeviceSynchronize()); double t_own=(now_s()-t0)/reps;
    CK(cudaMemcpy(hC,dC,M*N*sizeof(double),cudaMemcpyDeviceToHost));
    double rms_own_ref=rel_rms(hC,ref,M*N);
    double *own=(double*)malloc(M*N*sizeof(double)); for(int64_t i=0;i<M*N;i++) own[i]=hC[i];

    // ── cublasGemmEx TF32 (the path being replaced) ──
    cublasHandle_t h; cublasCreate(&h); cublasSetMathMode(h,CUBLAS_PEDANTIC_MATH);
    int64_t nA=M*K,nB=K*N,nC=M*N;
    k_cast_d2f<<<(unsigned)((nA+255)/256),256>>>(dA,fA,nA);
    k_cast_d2f<<<(unsigned)((nB+255)/256),256>>>(dB,fB,nB);
    CK(cudaDeviceSynchronize());
    const float alpha=1.0f,beta=0.0f;
    cublasStatus_t st=cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,(int)N,(int)M,(int)K,
        &alpha,fB,CUDA_R_32F,(int)N,fA,CUDA_R_32F,(int)K,&beta,fC,CUDA_R_32F,(int)N,
        CUBLAS_COMPUTE_32F_FAST_TF32,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    if(st!=CUBLAS_STATUS_SUCCESS){ fprintf(stderr,"cublasGemmEx failed %d\n",(int)st); exit(1);}
    CK(cudaDeviceSynchronize());
    t0=now_s();
    for(int r=0;r<reps;r++) cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,(int)N,(int)M,(int)K,
        &alpha,fB,CUDA_R_32F,(int)N,fA,CUDA_R_32F,(int)K,&beta,fC,CUDA_R_32F,(int)N,
        CUBLAS_COMPUTE_32F_FAST_TF32,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
    CK(cudaDeviceSynchronize()); double t_cub=(now_s()-t0)/reps;
    k_cast_f2d<<<(unsigned)((nC+255)/256),256>>>(fC,dC,nC); CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hC,dC,M*N*sizeof(double),cudaMemcpyDeviceToHost));
    double rms_cub_ref=rel_rms(hC,ref,M*N);
    double rms_own_cub=rel_rms(own,hC,M*N);

    double gf=2.0*(double)M*N*K*1e-9;
    printf("d=%-5lld own/ref=%.3e cublas/ref=%.3e own/cublas=%.3e | own %.3f ms %.1f GFLOP/s | cublas %.3f ms %.1f GFLOP/s | speedup own/cublas=%.3fx\n",
        (long long)d, rms_own_ref, rms_cub_ref, rms_own_cub,
        t_own*1e3, gf/t_own, t_cub*1e3, gf/t_cub, t_cub/t_own);
    free(hA);free(hB);free(hC);free(ref);free(own);
    cudaFree(dA);cudaFree(dB);cudaFree(dC);cudaFree(fA);cudaFree(fB);cudaFree(fC);
    cublasDestroy(h);
}

int main(void){
    int dev; cudaGetDevice(&dev); cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    printf("# GPU=%s sm_%d%d\n", p.name, p.major, p.minor);
    run(256, 50); run(512, 30); run(1024, 20); run(2048, 8); run(4096, 4);
    printf("# OWN-TF32-MMA-VERIFY DONE\n");
    return 0;
}
