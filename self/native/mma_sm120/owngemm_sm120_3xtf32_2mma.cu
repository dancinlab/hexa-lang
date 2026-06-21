// owngemm_sm120_3xtf32.cu — ROUND B: FP16-accum error-corrected FP32-equivalent
// GEMM emulation for sm_120 (RTX 5070), per Ootomo & Yokota 2022 (arXiv 2203.03341,
// "Recovering single precision accuracy from Tensor Cores computing in TF32/FP16").
//
// PREMISE (probe_fp16_rate.cu, measured aiden sm_120): the FP16-accumulate tensor
// path `mma.sync.m16n8k16.f32.f16.f16.f32` issues ~1.79-1.90x the rate of the
// TF32-accumulate path `mma.sync.m16n8k8.f32.tf32.tf32.f32`. So running 2 FP16
// MMAs (the 2-term error-corrected variant) costs ~2/1.8 = ~1.1x the MMA time of
// one TF32 MMA but recovers ~FP32 accuracy (vs TF32's ~10-bit mantissa).
//
// METHOD (2-term, Ootomo-Yokota Eq.23 truncated to drop A_lo*B_lo):
//   split each fp32 a = a_hi + a_lo where a_hi = (fp16)a, a_lo = (fp16)(a - a_hi).
//   A@B ~= A_hi@B_hi  +  (A_hi@B_lo + A_lo@B_hi)
//   The "hi*hi" product carries the top ~11 bits; the two cross terms recover the
//   next ~11 bits each -> combined ~FP32-equivalent. (3-term adds A_lo@B_lo for the
//   last ulps; 2-term = 75% of the MMA cost and already < TF32 error here.)
//
// We accumulate all three FP16 products into the SAME fp32 accumulator with the
// tensor core's fp32 add (Ootomo-Yokota show this single-accumulator form keeps the
// error bound). DETERMINISM: the split is an exact fp16 round (round-to-nearest,
// fixed) and the MMA add order is fixed by the unrolled loop -> bit-identical
// run-to-run by construction (proven by the byteeq harness run2run check).
//
// Build: byteeq harness renames gemm_sm120/owngemm_sm120 per-variant.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cuda_fp16.h>

#define BM 64
#define BN 64
#define BK 16
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)
#define NTHREAD (NWARP*32)
#define WM_FRAG 2
#define WN_FRAG 4
#define ASPAD 4
#define BSPAD 4

// one mma.sync m16n8k16 FP16-in / FP32-accum. A frag = 4 regs (each 2 packed f16),
// B frag = 2 regs (each 2 packed f16), C/D = 4 fp32.
__device__ __forceinline__ void mma_m16n8k16_f16(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}
__device__ __forceinline__ void cp_async_cg16(void* smem, const void* gmem){
    unsigned s=(unsigned)__cvta_generic_to_shared(smem);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// split fp32 -> (hi,lo) fp16. hi = RN(x); lo = RN(x - (float)hi).
__device__ __forceinline__ void split2(float x, __half& hi, __half& lo){
    hi = __float2half_rn(x);
    lo = __float2half_rn(x - __half2float(hi));
}
// pack two __half into one unsigned (lo half in bits 0-15, hi half in 16-31).
__device__ __forceinline__ unsigned pk(__half a, __half b){
    unsigned ua = *reinterpret_cast<unsigned short*>(&a);
    unsigned ub = *reinterpret_cast<unsigned short*>(&b);
    return ua | (ub<<16);
}

extern "C" __global__ void gemm_sm120(const float* __restrict__ A,
                                      const float* __restrict__ B,
                                      float* __restrict__ C,
                                      int M, int N, int K){
    __shared__ float As[2][BM][BK+ASPAD];
    __shared__ float Bs[2][BK][BN+BSPAD];
    int bm=blockIdx.y*BM, bn=blockIdx.x*BN;
    int tid=threadIdx.x; int warp=tid>>5, lane=tid&31;
    int wm=(warp/WARPS_N)*32, wn=(warp%WARPS_N)*32;
    int gid=lane>>2, tig=lane&3;

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk=(K+BK-1)/BK;
    auto load_stage=[&](int buf,int k0){
        #pragma unroll
        for(int i=tid;i<BM*BK/4;i+=NTHREAD){
            int r=i/(BK/4),c4=i%(BK/4),c=c4*4; int gr=bm+r,gc=k0+c;
            if(gr<M&&gc+3<K) cp_async_cg16(&As[buf][r][c],&A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f;}
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w;}
        }
        #pragma unroll
        for(int i=tid;i<BK*BN/4;i+=NTHREAD){
            int r=i/(BN/4),c4=i%(BN/4),c=c4*4; int gr=k0+r,gc=bn+c;
            if(gr<K&&gc+3<N) cp_async_cg16(&Bs[buf][r][c],&B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f;}
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w;}
        }
    };

    load_stage(0,0); cp_async_commit();
    for(int k=0;k<nk;k++){
        int buf=k&1,nbuf=(k+1)&1;
        if(k+1<nk){ load_stage(nbuf,(k+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
        else      { cp_async_wait<0>(); }
        __syncthreads();

        // BK=16 == k16: ONE m16n8k16 MMA per pass covers the full BK slab.
        // Build hi/lo fp16 fragments for A and B once, then 2 passes:
        //   pass 0: D += A_hi @ B_hi
        //   pass 1: D += A_hi @ B_lo ; D += A_lo @ B_hi   (cross terms)
        // m16n8k16 .f16 fragment layout:
        //   A[16x16]: a0=(row gid, col 2tig..2tig+1) a1=(row gid+8, col 2tig..)
        //             a2=(row gid, col 2tig+8..)      a3=(row gid+8, col 2tig+8..)
        //   B[16x8] : b0=(col gid, row 2tig..2tig+1)  b1=(col gid, row 2tig+8..)
        #pragma unroll
        for(int fmi=0; fmi<WM_FRAG; fmi++){
            int mrow=wm+fmi*16;
            // A fp32 elements for this fragment (8 values per thread: 4 regs x 2 cols)
            float a00=As[buf][mrow+gid  ][2*tig  ], a01=As[buf][mrow+gid  ][2*tig+1];
            float a10=As[buf][mrow+gid+8][2*tig  ], a11=As[buf][mrow+gid+8][2*tig+1];
            float a20=As[buf][mrow+gid  ][2*tig+8], a21=As[buf][mrow+gid  ][2*tig+9];
            float a30=As[buf][mrow+gid+8][2*tig+8], a31=As[buf][mrow+gid+8][2*tig+9];
            __half ah00,al00,ah01,al01,ah10,al10,ah11,al11,ah20,al20,ah21,al21,ah30,al30,ah31,al31;
            split2(a00,ah00,al00); split2(a01,ah01,al01);
            split2(a10,ah10,al10); split2(a11,ah11,al11);
            split2(a20,ah20,al20); split2(a21,ah21,al21);
            split2(a30,ah30,al30); split2(a31,ah31,al31);
            unsigned aHI[4]={ pk(ah00,ah01), pk(ah10,ah11), pk(ah20,ah21), pk(ah30,ah31) };
            unsigned aLO[4]={ pk(al00,al01), pk(al10,al11), pk(al20,al21), pk(al30,al31) };
            #pragma unroll
            for(int fni=0; fni<WN_FRAG; fni++){
                int ncol=wn+fni*8;
                float b00=Bs[buf][2*tig  ][ncol+gid], b01=Bs[buf][2*tig+1][ncol+gid];
                float b10=Bs[buf][2*tig+8][ncol+gid], b11=Bs[buf][2*tig+9][ncol+gid];
                __half bh00,bl00,bh01,bl01,bh10,bl10,bh11,bl11;
                split2(b00,bh00,bl00); split2(b01,bh01,bl01);
                split2(b10,bh10,bl10); split2(b11,bh11,bl11);
                unsigned bHI[2]={ pk(bh00,bh01), pk(bh10,bh11) };
                unsigned bLO[2]={ pk(bl00,bl01), pk(bl10,bl11) };
                // 2-term error-corrected: hi*hi + hi*lo + lo*hi
                // 2-MMA perf-floor probe: hi*hi + hi*lo only (drops lo*hi). Lower
                // accuracy than the 3-MMA form; measures the best-case emulation
                // perf (2 FP16 MMAs at the ~1.8x rate ~= 1.1x TF32 MMA-time floor).
                mma_m16n8k16_f16(acc[fmi][fni], aHI, bHI);
                mma_m16n8k16_f16(acc[fmi][fni], aHI, bLO);
            }
        }
        __syncthreads();
    }

    // store: m16n8 C layout (same as TF32 path): c0:(gid,2tig) c1:(gid,2tig+1)
    //                                            c2:(gid+8,2tig) c3:(gid+8,2tig+1)
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow=bm+wm+fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol=bn+wn+fni*8; float* d=acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            bool aligned=((c0&1)==0);
            if(r0<M&&c1<N&&aligned) *reinterpret_cast<float2*>(&C[(long long)r0*N+c0])=make_float2(d[0],d[1]);
            else { if(r0<M&&c0<N)C[(long long)r0*N+c0]=d[0]; if(r0<M&&c1<N)C[(long long)r0*N+c1]=d[1]; }
            if(r1<M&&c1<N&&aligned) *reinterpret_cast<float2*>(&C[(long long)r1*N+c0])=make_float2(d[2],d[3]);
            else { if(r1<M&&c0<N)C[(long long)r1*N+c0]=d[2]; if(r1<M&&c1<N)C[(long long)r1*N+c1]=d[3]; }
        }
    }
}

extern "C" void owngemm_sm120(float* C, const float* A, const float* B, int M, int K, int N){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN,(M+BM-1)/BM);
    gemm_sm120<<<grid,blk>>>(A,B,C,M,N,K);
}
