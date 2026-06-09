// owngemm_sm120_pipe.cu — HEXA-0POD OP-1b: pipeline-depth sweep harness for the
// sm_120 TF32 own-GEMM. A/B's OP-1's production kernel (BK=16, 2-stage cp.async,
// scalar epilogue) against the OP-1b levers:
//   (1) BK=32  — deeper K-tile per smem stage     (compile -DLBK=32)
//   (2) 3-stage cp.async ring (wait_group<2>)      (compile -DLSTAGES=3)
//   (3) .v2 (float2) vectorized C-store epilogue   (compile -DLVEC=1)
//
// All three are SCHEDULE/LAYOUT-only on top of OP-1's IDENTICAL per-output
// K-major mma.sync accumulation order — so every config is bit-for-bit the
// baseline (rel-RMS vs OP-1 baseline = 0, and rel-RMS vs FP64 ref unchanged).
//
// Defaults reproduce OP-1's production kernel exactly:
//   LBK=16  LSTAGES=2  LVEC=0
//
// Build: build_owngemm_pipe.sh (run on aiden). Mode 0 = GATE (vs cuBLAS + FP64),
// mode 1 = PERF (TFLOP/s + cuBLAS ratio).

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

#ifndef LBK
#define LBK 16
#endif
#ifndef LSTAGES
#define LSTAGES 2
#endif
#ifndef LVEC
#define LVEC 0
#endif

#define BM 64
#define BN 64
#define BK LBK
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)
#define NTHREAD (NWARP*32)
#define WM_FRAG 2
#define WN_FRAG 4
#define ASPAD 4
#define BSPAD 4

__device__ __forceinline__ unsigned f2tf32(float x){
    unsigned u; memcpy(&u,&x,4); u=(u+0x1000u)&0xFFFFE000u; return u;
}

__device__ __forceinline__ void mma_m16n8k8(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}

__device__ __forceinline__ void cp_async_cg16(void* smem, const void* gmem){
    unsigned s = (unsigned)__cvta_generic_to_shared(smem);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// Tiled TF32 GEMM, parameterized by BK / LSTAGES / LVEC. Same 64x64 output tile
// and IDENTICAL per-output K-major mma.sync order as OP-1's production kernel.
extern "C" __global__ void gemm_sm120_pipe(const float* __restrict__ A,
                                           const float* __restrict__ B,
                                           float* __restrict__ C,
                                           int M, int N, int K){
    __shared__ float As[LSTAGES][BM][BK+ASPAD];
    __shared__ float Bs[LSTAGES][BK][BN+BSPAD];
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32;
    int wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk = (K+BK-1)/BK;

    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/4; i+=NTHREAD){
            int r=i/(BK/4), c4=i%(BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; }
        }
        #pragma unroll
        for(int i=tid; i<BK*BN/4; i+=NTHREAD){
            int r=i/(BN/4), c4=i%(BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; }
        }
    };

    auto compute_stage = [&](int buf){
        #pragma unroll
        for(int ks=0; ks<BK; ks+=8){
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                int mrow = wm + fmi*16;
                unsigned af[4];
                af[0]=f2tf32(As[buf][mrow + gid    ][ks + tig    ]);
                af[1]=f2tf32(As[buf][mrow + gid + 8][ks + tig    ]);
                af[2]=f2tf32(As[buf][mrow + gid    ][ks + tig + 4]);
                af[3]=f2tf32(As[buf][mrow + gid + 8][ks + tig + 4]);
                #pragma unroll
                for(int fni=0; fni<WN_FRAG; fni++){
                    int ncol = wn + fni*8;
                    unsigned bf[2];
                    bf[0]=f2tf32(Bs[buf][ks + tig    ][ncol + gid]);
                    bf[1]=f2tf32(Bs[buf][ks + tig + 4][ncol + gid]);
                    mma_m16n8k8(acc[fmi][fni], af, bf);
                }
            }
        }
    };

#if LSTAGES == 2
    // ---- 2-stage double buffer (OP-1 baseline schedule) ----
    load_stage(0,0); cp_async_commit();
    for(int k=0; k<nk; k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
        else      { cp_async_wait<0>(); }
        __syncthreads();
        compute_stage(buf);
        __syncthreads();
    }
#else
    // ---- N-stage ring (LSTAGES>=3) ----
    // Prologue: issue the first (LSTAGES-1) prefetches, each its own commit_group.
    #pragma unroll
    for(int s=0; s<LSTAGES-1; s++){
        if(s<nk){ load_stage(s, s*BK); }
        cp_async_commit();
    }
    for(int k=0; k<nk; k++){
        int buf = k % LSTAGES;
        // Prefetch the tile (LSTAGES-1) ahead into a free ring slot.
        int kp = k + (LSTAGES-1);
        if(kp<nk){ load_stage(kp % LSTAGES, kp*BK); }
        cp_async_commit();
        // Wait until only (LSTAGES-1) groups remain in flight (i.e. `buf` ready).
        cp_async_wait<LSTAGES-1>();
        __syncthreads();
        compute_stage(buf);
        __syncthreads();
    }
#endif

    // ---- epilogue ----
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
#if LVEC == 1
            // .v2 (float2 / 64-bit) store: c0,c1 are contiguous (col 2*tig, 2*tig+1),
            // c2,c3 likewise on row r1. Same bits as 2 scalar stores, one 64-bit op.
            // Fast path only when both columns in-bounds AND 8-byte aligned.
            if(r0<M && c1<N && ((c0&1)==0)){
                *reinterpret_cast<float2*>(&C[(long long)r0*N+c0]) = make_float2(d[0],d[1]);
            } else {
                if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
                if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1];
            }
            if(r1<M && c1<N && ((c0&1)==0)){
                *reinterpret_cast<float2*>(&C[(long long)r1*N+c0]) = make_float2(d[2],d[3]);
            } else {
                if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
                if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3];
            }
#else
            if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
            if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1];
            if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
            if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3];
#endif
        }
    }
}

extern "C" void owngemm_sm120(float* C, const float* A, const float* B, int M, int K, int N){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    gemm_sm120_pipe<<<grid,blk>>>(A,B,C,M,N,K);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
// FP64 reference (host) — the bit-exact gate ground truth (g5).
static void ref_fp64(const float* A,const float* B,double* R,int M,int N,int K){
    for(int i=0;i<M;i++) for(int j=0;j<N;j++){ double s=0;
        for(int k=0;k<K;k++) s += (double)A[(long long)i*K+k]*(double)B[(long long)k*N+j];
        R[(long long)i*N+j]=s; }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hR=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dC,*dR;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4)); CK(cudaMalloc(&dR,szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f, beta=0.f;
    CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
        dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
        dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CK(cudaDeviceSynchronize());

    owngemm_sm120(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM FAULT: %s\n",cudaGetErrorString(e)); return 4; }

    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));

    // FP64 gate ground truth (compute up to a cap to keep host time sane).
    double relrms_fp64 = -1.0, maxd_fp64 = -1.0;
    if(S<=2048){
        double* R64=(double*)malloc(szC*8);
        ref_fp64(hA,hB,R64,M,N,K);
        double se=0,sr=0,mx=0;
        for(size_t i=0;i<szC;i++){ double a=hC[i],b=R64[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>mx)mx=fabs(dd);}
        relrms_fp64 = sr>0? sqrt(se/szC)/sqrt(sr/szC):0.0; maxd_fp64=mx; free(R64);
    }

    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] cfg(BK=%d,STAGES=%d,VEC=%d) S=%d vs-cuBLAS rel-RMS=%.3e max|d|=%.3e | vs-FP64 rel-RMS=%.3e max|d|=%.3e\n",
           BK,LSTAGES,LVEC,S,relrms,maxd,relrms_fp64,maxd_fp64);

    if(MODE==1){
        int iters=50;
        owngemm_sm120(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120(dC,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
            dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] cfg(BK=%d,STAGES=%d,VEC=%d) S=%d own %.2f TFLOP/s (%.4f ms)  cuBLAS-TF32 %.2f TFLOP/s  off=%.3fx\n",
               BK,LSTAGES,LVEC,S,tflops,ms1,cbtf, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
