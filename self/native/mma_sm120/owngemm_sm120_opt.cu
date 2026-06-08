// owngemm_sm120_opt.cu — HEXA-0POD OP-1: sm_120 TF32 own-GEMM speedup sweep.
//
// Baseline = gemm_sm120 (F-BENCH-5 #2943): mma.sync.aligned.m16n8k8.row.col.
// f32.tf32.tf32.f32, 64x64 block / BK=16 smem stage / FP32 register accum /
// RN-to-TF32. ~4.9-8.1 TFLOP/s, 3.2-6.9x off cuBLAS-TF32 on RTX 5070 (cc12.0).
//
// This file ADDS optimized variants selected by argv[3] (KERN), sweeping the
// HEXA-0POD OP-1 levers while preserving the per-output accumulation ORDER
// (TF32 RN of each operand, then the same K-major mma.sync sequence) so the
// result stays BIT-EXACT vs the baseline K0 (rel-RMS vs K0 == 0, bitdiff == 0).
//
// Levers:
//   K0 = baseline (64x64, BK=16, scalar smem load, no pipeline)              [ref]
//   K1 = +bank-conflict-free smem pad + .v4 (128-bit) global loads           (lever 2,5)
//   K2 = K1 + cp.async double-buffered BK stage (deeper pipeline)            (lever 1)
//   K3 = larger per-CTA register tile 128x64 (raise arithmetic intensity)    (lever 3)
//   K4 = K3 + cp.async double-buffer + pad + .v4 (all levers stacked)        (1+2+3+5)
//
// All variants compute C[M,N] = A[M,K] @ B[K,N] row-major, TF32 matmul/FP32
// accum, identical TF32 rounding (f2tf32) and K-major accumulation order as K0.
//
// argv: [1]=S (square), [2]=MODE (0 gate / 1 perf), [3]=KERN (0..4, default 0)
// Build: build_owngemm_opt.sh on aiden.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

#define BM 64
#define BN 64
#define BK 16
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)   // 4
#define NTHREAD (NWARP*32)        // 128
#define WM_FRAG 2
#define WN_FRAG 4

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

// cp.async 16-byte (128-bit) shared<-global, .cg (bypass L1). sm_80+ incl sm_120.
__device__ __forceinline__ void cp_async_cg16(void* smem, const void* gmem){
    unsigned s = (unsigned)__cvta_generic_to_shared(smem);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// ============================================================================
// K0 — baseline (identical to gemm_sm120 in owngemm_sm120.cu).
// ============================================================================
extern "C" __global__ void gemm_k0(const float* __restrict__ A,const float* __restrict__ B,
                                    float* __restrict__ C,int M,int N,int K){
    __shared__ float As[BM][BK];
    __shared__ float Bs[BK][BN];
    int bm=blockIdx.y*BM, bn=blockIdx.x*BN;
    int tid=threadIdx.x, warp=tid>>5, lane=tid&31;
    int wm=(warp/WARPS_N)*32, wn=(warp%WARPS_N)*32;
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    for(int k0=0;k0<K;k0+=BK){
        #pragma unroll
        for(int i=tid;i<BM*BK;i+=NTHREAD){ int r=i/BK,c=i%BK,gr=bm+r,gc=k0+c;
            As[r][c]=(gr<M&&gc<K)?A[(long long)gr*K+gc]:0.f; }
        #pragma unroll
        for(int i=tid;i<BK*BN;i+=NTHREAD){ int r=i/BN,c=i%BN,gr=k0+r,gc=bn+c;
            Bs[r][c]=(gr<K&&gc<N)?B[(long long)gr*N+gc]:0.f; }
        __syncthreads();
        #pragma unroll
        for(int ks=0;ks<BK;ks+=8){
            #pragma unroll
            for(int fmi=0;fmi<WM_FRAG;fmi++){
                int mrow=wm+fmi*16; int gid=lane>>2,tig=lane&3; unsigned af[4];
                af[0]=f2tf32(As[mrow+gid  ][ks+tig  ]); af[1]=f2tf32(As[mrow+gid+8][ks+tig  ]);
                af[2]=f2tf32(As[mrow+gid  ][ks+tig+4]); af[3]=f2tf32(As[mrow+gid+8][ks+tig+4]);
                #pragma unroll
                for(int fni=0;fni<WN_FRAG;fni++){
                    int ncol=wn+fni*8; unsigned bf[2];
                    bf[0]=f2tf32(Bs[ks+tig  ][ncol+gid]); bf[1]=f2tf32(Bs[ks+tig+4][ncol+gid]);
                    mma_m16n8k8(acc[fmi][fni],af,bf);
                }
            }
        }
        __syncthreads();
    }
    int gid=lane>>2,tig=lane&3;
    #pragma unroll
    for(int fmi=0;fmi<WM_FRAG;fmi++){ int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0;fni<WN_FRAG;fni++){ int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid,r1=mrow+gid+8,c0=ncol+2*tig,c1=ncol+2*tig+1;
            if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1];
            if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
    }
}

// ============================================================================
// K1 — bank-conflict-free smem pad + vectorized .v4 global loads. As padded to
// [BM][BK+4], Bs to [BK][BN+4] to break the 32-bank stride so fragment loads
// land in distinct banks. Global loads use float4 (128-bit) on the fast path
// (K,N % 4 == 0), scalar fallback otherwise. Accumulation order UNCHANGED.
// ============================================================================
#define ASPAD 4
#define BSPAD 4
extern "C" __global__ void gemm_k1(const float* __restrict__ A,const float* __restrict__ B,
                                    float* __restrict__ C,int M,int N,int K){
    __shared__ float As[BM][BK+ASPAD];
    __shared__ float Bs[BK][BN+BSPAD];
    int bm=blockIdx.y*BM, bn=blockIdx.x*BN;
    int tid=threadIdx.x, warp=tid>>5, lane=tid&31;
    int wm=(warp/WARPS_N)*32, wn=(warp%WARPS_N)*32;
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    bool vecA=(K%4==0), vecB=(N%4==0);
    for(int k0=0;k0<K;k0+=BK){
        if(vecA){
            #pragma unroll
            for(int i=tid;i<BM*BK/4;i+=NTHREAD){ int r=i/(BK/4),c4=i%(BK/4),c=c4*4; int gr=bm+r,gc=k0+c;
                float4 v; if(gr<M){ v=*reinterpret_cast<const float4*>(&A[(long long)gr*K+gc]); } else v=make_float4(0,0,0,0);
                As[r][c+0]=v.x;As[r][c+1]=v.y;As[r][c+2]=v.z;As[r][c+3]=v.w; }
        } else { for(int i=tid;i<BM*BK;i+=NTHREAD){ int r=i/BK,c=i%BK,gr=bm+r,gc=k0+c;
                As[r][c]=(gr<M&&gc<K)?A[(long long)gr*K+gc]:0.f; } }
        if(vecB){
            #pragma unroll
            for(int i=tid;i<BK*BN/4;i+=NTHREAD){ int r=i/(BN/4),c4=i%(BN/4),c=c4*4; int gr=k0+r,gc=bn+c;
                float4 v; if(gr<K){ v=*reinterpret_cast<const float4*>(&B[(long long)gr*N+gc]); } else v=make_float4(0,0,0,0);
                Bs[r][c+0]=v.x;Bs[r][c+1]=v.y;Bs[r][c+2]=v.z;Bs[r][c+3]=v.w; }
        } else { for(int i=tid;i<BK*BN;i+=NTHREAD){ int r=i/BN,c=i%BN,gr=k0+r,gc=bn+c;
                Bs[r][c]=(gr<K&&gc<N)?B[(long long)gr*N+gc]:0.f; } }
        __syncthreads();
        #pragma unroll
        for(int ks=0;ks<BK;ks+=8){
            #pragma unroll
            for(int fmi=0;fmi<WM_FRAG;fmi++){
                int mrow=wm+fmi*16; int gid=lane>>2,tig=lane&3; unsigned af[4];
                af[0]=f2tf32(As[mrow+gid  ][ks+tig  ]); af[1]=f2tf32(As[mrow+gid+8][ks+tig  ]);
                af[2]=f2tf32(As[mrow+gid  ][ks+tig+4]); af[3]=f2tf32(As[mrow+gid+8][ks+tig+4]);
                #pragma unroll
                for(int fni=0;fni<WN_FRAG;fni++){
                    int ncol=wn+fni*8; unsigned bf[2];
                    bf[0]=f2tf32(Bs[ks+tig  ][ncol+gid]); bf[1]=f2tf32(Bs[ks+tig+4][ncol+gid]);
                    mma_m16n8k8(acc[fmi][fni],af,bf);
                }
            }
        }
        __syncthreads();
    }
    int gid=lane>>2,tig=lane&3;
    #pragma unroll
    for(int fmi=0;fmi<WM_FRAG;fmi++){ int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0;fni<WN_FRAG;fni++){ int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid,r1=mrow+gid+8,c0=ncol+2*tig,c1=ncol+2*tig+1;
            if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1];
            if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
    }
}

// ============================================================================
// K2 — K1 + cp.async double-buffered BK stage. Prefetch the next BK tile into
// the alternate smem buffer while the MMAs consume the current one, overlapping
// global->smem latency with tensor-core work. Accumulation order UNCHANGED.
// ============================================================================
extern "C" __global__ void gemm_k2(const float* __restrict__ A,const float* __restrict__ B,
                                    float* __restrict__ C,int M,int N,int K){
    __shared__ float As[2][BM][BK+ASPAD];
    __shared__ float Bs[2][BK][BN+BSPAD];
    int bm=blockIdx.y*BM, bn=blockIdx.x*BN;
    int tid=threadIdx.x, warp=tid>>5, lane=tid&31;
    int wm=(warp/WARPS_N)*32, wn=(warp%WARPS_N)*32;
    int gid=lane>>2,tig=lane&3;
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    int nk=(K+BK-1)/BK;
    auto load_stage=[&](int buf,int k0){
        #pragma unroll
        for(int i=tid;i<BM*BK/4;i+=NTHREAD){ int r=i/(BK/4),c4=i%(BK/4),c=c4*4; int gr=bm+r,gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0); if(gr<M){ for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; } }
        #pragma unroll
        for(int i=tid;i<BK*BN/4;i+=NTHREAD){ int r=i/(BN/4),c4=i%(BN/4),c=c4*4; int gr=k0+r,gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0); if(gr<K){ for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; } }
    };
    load_stage(0,0); cp_async_commit();
    for(int k=0;k<nk;k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
        else { cp_async_wait<0>(); }
        __syncthreads();
        #pragma unroll
        for(int ks=0;ks<BK;ks+=8){
            #pragma unroll
            for(int fmi=0;fmi<WM_FRAG;fmi++){
                int mrow=wm+fmi*16; unsigned af[4];
                af[0]=f2tf32(As[buf][mrow+gid  ][ks+tig  ]); af[1]=f2tf32(As[buf][mrow+gid+8][ks+tig  ]);
                af[2]=f2tf32(As[buf][mrow+gid  ][ks+tig+4]); af[3]=f2tf32(As[buf][mrow+gid+8][ks+tig+4]);
                #pragma unroll
                for(int fni=0;fni<WN_FRAG;fni++){
                    int ncol=wn+fni*8; unsigned bf[2];
                    bf[0]=f2tf32(Bs[buf][ks+tig  ][ncol+gid]); bf[1]=f2tf32(Bs[buf][ks+tig+4][ncol+gid]);
                    mma_m16n8k8(acc[fmi][fni],af,bf);
                }
            }
        }
        __syncthreads();
    }
    #pragma unroll
    for(int fmi=0;fmi<WM_FRAG;fmi++){ int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0;fni<WN_FRAG;fni++){ int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid,r1=mrow+gid+8,c0=ncol+2*tig,c1=ncol+2*tig+1;
            if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1];
            if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
    }
}

// ============================================================================
// K3 — larger per-CTA register tile: 128x64 block (BM2=128), BK=16, 8 warps
// (4 warp-rows x 2 warp-cols), each warp still owns a 32x32 sub-tile. Raises
// arithmetic intensity (one B tile reused across 4 warp-rows). Pad + .v4.
// Accumulation order per output UNCHANGED.
// ============================================================================
#define BM2 128
#define WARPS_M2 4
#define WARPS_N2 2
#define NWARP2 (WARPS_M2*WARPS_N2) // 8
#define NTHREAD2 (NWARP2*32)       // 256
extern "C" __global__ void gemm_k3(const float* __restrict__ A,const float* __restrict__ B,
                                    float* __restrict__ C,int M,int N,int K){
    __shared__ float As[BM2][BK+ASPAD];
    __shared__ float Bs[BK][BN+BSPAD];
    int bm=blockIdx.y*BM2, bn=blockIdx.x*BN;
    int tid=threadIdx.x, warp=tid>>5, lane=tid&31;
    int wm=(warp/WARPS_N2)*32, wn=(warp%WARPS_N2)*32;
    int gid=lane>>2,tig=lane&3;
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    bool vecA=(K%4==0), vecB=(N%4==0);
    for(int k0=0;k0<K;k0+=BK){
        if(vecA){
            #pragma unroll
            for(int i=tid;i<BM2*BK/4;i+=NTHREAD2){ int r=i/(BK/4),c4=i%(BK/4),c=c4*4; int gr=bm+r,gc=k0+c;
                float4 v; if(gr<M){ v=*reinterpret_cast<const float4*>(&A[(long long)gr*K+gc]); } else v=make_float4(0,0,0,0);
                As[r][c+0]=v.x;As[r][c+1]=v.y;As[r][c+2]=v.z;As[r][c+3]=v.w; }
        } else { for(int i=tid;i<BM2*BK;i+=NTHREAD2){ int r=i/BK,c=i%BK,gr=bm+r,gc=k0+c;
                As[r][c]=(gr<M&&gc<K)?A[(long long)gr*K+gc]:0.f; } }
        if(vecB){
            #pragma unroll
            for(int i=tid;i<BK*BN/4;i+=NTHREAD2){ int r=i/(BN/4),c4=i%(BN/4),c=c4*4; int gr=k0+r,gc=bn+c;
                float4 v; if(gr<K){ v=*reinterpret_cast<const float4*>(&B[(long long)gr*N+gc]); } else v=make_float4(0,0,0,0);
                Bs[r][c+0]=v.x;Bs[r][c+1]=v.y;Bs[r][c+2]=v.z;Bs[r][c+3]=v.w; }
        } else { for(int i=tid;i<BK*BN;i+=NTHREAD2){ int r=i/BN,c=i%BN,gr=k0+r,gc=bn+c;
                Bs[r][c]=(gr<K&&gc<N)?B[(long long)gr*N+gc]:0.f; } }
        __syncthreads();
        #pragma unroll
        for(int ks=0;ks<BK;ks+=8){
            #pragma unroll
            for(int fmi=0;fmi<WM_FRAG;fmi++){
                int mrow=wm+fmi*16; unsigned af[4];
                af[0]=f2tf32(As[mrow+gid  ][ks+tig  ]); af[1]=f2tf32(As[mrow+gid+8][ks+tig  ]);
                af[2]=f2tf32(As[mrow+gid  ][ks+tig+4]); af[3]=f2tf32(As[mrow+gid+8][ks+tig+4]);
                #pragma unroll
                for(int fni=0;fni<WN_FRAG;fni++){
                    int ncol=wn+fni*8; unsigned bf[2];
                    bf[0]=f2tf32(Bs[ks+tig  ][ncol+gid]); bf[1]=f2tf32(Bs[ks+tig+4][ncol+gid]);
                    mma_m16n8k8(acc[fmi][fni],af,bf);
                }
            }
        }
        __syncthreads();
    }
    #pragma unroll
    for(int fmi=0;fmi<WM_FRAG;fmi++){ int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0;fni<WN_FRAG;fni++){ int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid,r1=mrow+gid+8,c0=ncol+2*tig,c1=ncol+2*tig+1;
            if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1];
            if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
    }
}

// ============================================================================
// K4 — K3 (128x64 register tile) + cp.async double-buffer + pad + .v4. All
// levers stacked. Accumulation order per output UNCHANGED.
// ============================================================================
extern "C" __global__ void gemm_k4(const float* __restrict__ A,const float* __restrict__ B,
                                    float* __restrict__ C,int M,int N,int K){
    __shared__ float As[2][BM2][BK+ASPAD];
    __shared__ float Bs[2][BK][BN+BSPAD];
    int bm=blockIdx.y*BM2, bn=blockIdx.x*BN;
    int tid=threadIdx.x, warp=tid>>5, lane=tid&31;
    int wm=(warp/WARPS_N2)*32, wn=(warp%WARPS_N2)*32;
    int gid=lane>>2,tig=lane&3;
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    int nk=(K+BK-1)/BK;
    auto load_stage=[&](int buf,int k0){
        #pragma unroll
        for(int i=tid;i<BM2*BK/4;i+=NTHREAD2){ int r=i/(BK/4),c4=i%(BK/4),c=c4*4; int gr=bm+r,gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0); if(gr<M){ for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; } }
        #pragma unroll
        for(int i=tid;i<BK*BN/4;i+=NTHREAD2){ int r=i/(BN/4),c4=i%(BN/4),c=c4*4; int gr=k0+r,gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0); if(gr<K){ for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; } }
    };
    load_stage(0,0); cp_async_commit();
    for(int k=0;k<nk;k++){
        int buf=k&1, nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
        else { cp_async_wait<0>(); }
        __syncthreads();
        #pragma unroll
        for(int ks=0;ks<BK;ks+=8){
            #pragma unroll
            for(int fmi=0;fmi<WM_FRAG;fmi++){
                int mrow=wm+fmi*16; unsigned af[4];
                af[0]=f2tf32(As[buf][mrow+gid  ][ks+tig  ]); af[1]=f2tf32(As[buf][mrow+gid+8][ks+tig  ]);
                af[2]=f2tf32(As[buf][mrow+gid  ][ks+tig+4]); af[3]=f2tf32(As[buf][mrow+gid+8][ks+tig+4]);
                #pragma unroll
                for(int fni=0;fni<WN_FRAG;fni++){
                    int ncol=wn+fni*8; unsigned bf[2];
                    bf[0]=f2tf32(Bs[buf][ks+tig  ][ncol+gid]); bf[1]=f2tf32(Bs[buf][ks+tig+4][ncol+gid]);
                    mma_m16n8k8(acc[fmi][fni],af,bf);
                }
            }
        }
        __syncthreads();
    }
    #pragma unroll
    for(int fmi=0;fmi<WM_FRAG;fmi++){ int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0;fni<WN_FRAG;fni++){ int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid,r1=mrow+gid+8,c0=ncol+2*tig,c1=ncol+2*tig+1;
            if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1];
            if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
    }
}

// host dispatch
extern "C" void owngemm_sm120_k(int kern,float* C,const float* A,const float* B,int M,int K,int N){
    if(kern==3||kern==4){
        dim3 blk(NTHREAD2); dim3 grid((N+BN-1)/BN,(M+BM2-1)/BM2);
        if(kern==3) gemm_k3<<<grid,blk>>>(A,B,C,M,N,K);
        else        gemm_k4<<<grid,blk>>>(A,B,C,M,N,K);
    } else {
        dim3 blk(NTHREAD); dim3 grid((N+BN-1)/BN,(M+BM-1)/BM);
        if(kern==0) gemm_k0<<<grid,blk>>>(A,B,C,M,N,K);
        else if(kern==1) gemm_k1<<<grid,blk>>>(A,B,C,M,N,K);
        else gemm_k2<<<grid,blk>>>(A,B,C,M,N,K);
    }
}

#ifdef OWNGEMM_MAIN
static void fill(float* x,long long n,unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):768;
    int MODE=argc>2?atoi(argv[2]):0;
    int KERN=argc>3?atoi(argv[3]):0;
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K,szB=(size_t)K*N,szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hR=(float*)malloc(szC*4),*hK0=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dC,*dR,*dK0;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4)); CK(cudaMalloc(&dR,szC*4)); CK(cudaMalloc(&dK0,szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb,CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f,beta=0.f;
    CB(cublasGemmEx(cb,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&alpha,
        dB,CUDA_R_32F,N,dA,CUDA_R_32F,K,&beta,
        dR,CUDA_R_32F,N,CUBLAS_COMPUTE_32F_FAST_TF32,CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CK(cudaDeviceSynchronize());

    // K0 baseline result for the BIT-EXACT gate (optimized kernel must match K0).
    owngemm_sm120_k(0,dK0,dA,dB,M,K,N);
    { cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
      if(e!=cudaSuccess){ printf("K0 FAULT: %s\n",cudaGetErrorString(e)); return 4; } }
    CK(cudaMemcpy(hK0,dK0,szC*4,cudaMemcpyDeviceToHost));

    owngemm_sm120_k(KERN,dC,dA,dB,M,K,N);
    { cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
      if(e!=cudaSuccess){ printf("OWNGEMM K%d FAULT: %s\n",KERN,cudaGetErrorString(e)); return 4; } }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));

    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms=sr>0?sqrt(se/szC)/sqrt(sr/szC):0.0;
    double se0=0,sr0=0,maxd0=0; long long bitdiff=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hK0[i],dd=a-b; se0+=dd*dd; sr0+=b*b; if(fabs(dd)>maxd0)maxd0=fabs(dd);
        unsigned ua,ub; memcpy(&ua,&hC[i],4); memcpy(&ub,&hK0[i],4); if(ua!=ub) bitdiff++; }
    double relrms0=sr0>0?sqrt(se0/szC)/sqrt(sr0/szC):0.0;
    printf("[GATE] S=%d K%d vs cuBLAS-TF32: rel-RMS=%.3e max|d|=%.3e | vs K0: rel-RMS=%.3e max|d|=%.3e bitdiff=%lld/%zu (bit-exact-vs-K0: %s)\n",
           S,KERN,relrms,maxd,relrms0,maxd0,bitdiff,szC,(bitdiff==0?"YES":"NO"));

    if(MODE==1){
        int iters=50;
        owngemm_sm120_k(KERN,dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_k(KERN,dC,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&alpha,
            dB,CUDA_R_32F,N,dA,CUDA_R_32F,K,&beta,
            dR,CUDA_R_32F,N,CUBLAS_COMPUTE_32F_FAST_TF32,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters,cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] S=%d K%d own %.2f TFLOP/s (%.4f ms)  cuBLAS-TF32 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,KERN,tflops,ms1,cbtf,cbms,cbtf/tflops);
    }
    return (relrms<=1e-2)?0:2;
}
#endif
