/* F-FUSION-AUTOREGRESSIVE-COMPLETE -- COMPLETE fused 2-mega-kernel decode,
 * MULTI-CTA with cooperative-groups grid.sync().
 *
 * R9 stub: 1 CTA, single-thread-per-row serial -> 40x slower body. WRONG.
 * R12 v1 : 1 CTA, multi-warp warp-coop -> still 11x slower (1 of 40 SMs idle). WRONG.
 * R12 v2 (this): MULTI-CTA (one per SM) + grid.sync() between intra-layer phases.
 *   Each GEMV's output rows are striped across ALL CTAs*warps -> uses all 40 SMs,
 *   coalesced warp-coop dots. grid.sync() sequences the phases that have a
 *   cross-CTA dependency (Q/K/V must all be in HBM before scores; attn before
 *   O-proj; etc.). The whole attention block is ONE cooperative launch; the
 *   whole FFN block is a second cooperative launch => 2 launches/layer.
 *
 * Cross-CTA shared data lives in HBM scratch (xn1, Q, K, V, attn, h) since
 * shared mem is per-CTA. grid.sync() provides the cross-CTA memory fence +
 * barrier. This is the canonical persistent/cooperative decode pattern.
 *
 * Launch: cudaLaunchCooperativeKernel, grid = numSM CTAs (query occupancy),
 * block = 256 threads (8 warps). Compile:
 *   nvcc -ptx -arch=sm_80 -o decode_fused.ptx decode_fused_kernels.cu
 */
#include <cuda_runtime.h>
#include <cooperative_groups.h>
namespace cg = cooperative_groups;

#define D    768
#define NH   12
#define HD   64
#define FF   3072
#define BLK  256
#define WPB  (BLK/32)   /* warps per block = 8 */

__device__ __forceinline__ float warp_dot(const float* w,const float* x,int K,int lane){
  float acc=0.f;
  #pragma unroll 4
  for(int c=lane;c<K;c+=32) acc += w[c]*x[c];
  for(int o=16;o>0;o>>=1) acc += __shfl_down_sync(0xffffffffu,acc,o);
  return acc; /* lane 0 */
}

/* global warp id across the whole grid, and total warp count. */
__device__ __forceinline__ int gwarp(){ return (blockIdx.x*BLK + threadIdx.x)>>5; }
__device__ __forceinline__ int gnwarp(){ return (gridDim.x*BLK)>>5; }
__device__ __forceinline__ int gtid(){ return blockIdx.x*BLK + threadIdx.x; }
__device__ __forceinline__ int gnthr(){ return gridDim.x*BLK; }

/* KERNEL 1: fused attention block, multi-CTA cooperative.
   scratch layout (HBM):  xn1[D], Qg[D], Kg[D], Vg[D], attn[D]  (all caller-alloc) */
extern "C" __global__ void decode_attn_fused(
    const float* __restrict__ x, const float* __restrict__ g1,
    const float* __restrict__ Wq,const float* __restrict__ Wk,
    const float* __restrict__ Wv,const float* __restrict__ Wo,
    float* __restrict__ Kc, float* __restrict__ Vc,
    float* __restrict__ xout,
    float* __restrict__ xn1, float* __restrict__ Qg,
    float* __restrict__ Kg,  float* __restrict__ Vg, float* __restrict__ attn,
    float* __restrict__ ssscr,         /* [gridDim] partial sum-sq */
    float* __restrict__ pscr,          /* [NH*KW*(2+HD)] flash partials */
    int L, float scale)
{
  cg::grid_group grid = cg::this_grid();
  int tid=threadIdx.x, lane=tid&31, warp=tid>>5;
  int gw=gwarp(), gnw=gnwarp(), gt=gtid(), gn=gnthr();
  __shared__ float red[BLK];

  /* ---- RMSNorm: grid-wide sum of squares via per-CTA partial -> ssscr ---- */
  float ss=0.f;
  for(int i=gt;i<D;i+=gn){ float v=x[i]; ss+=v*v; }
  red[tid]=ss; __syncthreads();
  for(int s=BLK/2;s>0;s>>=1){ if(tid<s) red[tid]+=red[tid+s]; __syncthreads(); }
  if(tid==0) ssscr[blockIdx.x]=red[0];
  grid.sync();
  /* reduce ssscr (every thread reads all CTA partials -- gridDim small) */
  float tot=0.f; for(int b=0;b<gridDim.x;b++) tot+=ssscr[b];
  float inv=rsqrtf(tot/(float)D + 1e-5f);
  for(int i=gt;i<D;i+=gn) xn1[i]=x[i]*inv*g1[i];
  grid.sync();

  /* ---- Q/K/V GEMV: global warp gw owns rows {gw, gw+gnw, ...} ---- */
  for(int r=gw;r<D;r+=gnw){
    float q=warp_dot(Wq+(size_t)r*D, xn1, D, lane);
    float k=warp_dot(Wk+(size_t)r*D, xn1, D, lane);
    float v=warp_dot(Wv+(size_t)r*D, xn1, D, lane);
    if(lane==0){ Qg[r]=q; Kg[r]=k; Vg[r]=v; }
  }
  grid.sync();

  /* ---- KV-cache append at row L (grid-strided, coalesced) ---- */
  for(int i=gt;i<D;i+=gn){ Kc[(size_t)L*D+i]=Kg[i]; Vc[(size_t)L*D+i]=Vg[i]; }
  grid.sync();

  /* ---- FLASH-style masked single-q attention, PARALLELIZED OVER KEYS ----
     R12 v2 bug: only NH=12 warps active (1/head) streaming all L keys serially
     -> attn phase 12-warp bound, scales badly with L. v3 fix: split the L keys
     across KW warps PER HEAD. Each warp computes a PARTIAL online-softmax state
     (m,l,acc[2]) over its key-stripe, writes (m,l,a0,a1) to HBM partials, then
     after grid.sync ONE warp/head combines the KW partials (flash merge).
     KW = gnw/NH warps per head (e.g. 768/12 = 64). lane owns 2 of HD=64 dims. */
  int Lp1=L+1;
  int KW = gnw / NH; if(KW<1) KW=1;          /* warps per head */
  int head = gw / KW;                         /* which head this warp serves */
  int kwi  = gw % KW;                         /* this warp's key-stripe index */
  if(head<NH){
    const float* q=Qg + head*HD;
    float m=-3.4e38f,l=0.f,a0=0.f,a1=0.f;
    int c0=lane,c1=lane+32;
    /* this warp handles keys {kwi, kwi+KW, kwi+2KW, ...} */
    for(int t=kwi;t<Lp1;t+=KW){
      const float* kc=Kc + (size_t)t*D + head*HD;
      float pd=q[c0]*kc[c0]+q[c1]*kc[c1];
      for(int o=16;o>0;o>>=1) pd += __shfl_down_sync(0xffffffffu,pd,o);
      float s=__shfl_sync(0xffffffffu,pd,0)*scale;
      float mn=fmaxf(m,s); float corr=__expf(m-mn); float p=__expf(s-mn);
      l=l*corr+p;
      const float* vc=Vc + (size_t)t*D + head*HD;
      a0=a0*corr+p*vc[c0]; a1=a1*corr+p*vc[c1]; m=mn;
    }
    /* write partial state to HBM: pstate layout [head*KW + kwi] x (m,l,a0[64]) -
       store m,l + the per-dim acc. We reuse attn-sized scratch via pscr. */
    /* pscr layout: for (head,kwi): m at base, l at base+1, then 64 acc dims.
       base = (head*KW + kwi) * (2+HD). Each lane writes its 2 acc dims. */
    float* ps = pscr + (size_t)(head*KW + kwi)*(2+HD);
    if(lane==0){ ps[0]=m; ps[1]=l; }
    ps[2+c0]=a0; ps[2+c1]=a1;
  }
  grid.sync();
  /* ---- flash-merge KW partials per head: one warp per head combines ---- */
  if(gw<NH){
    int h=gw; int lane2=lane;
    int c0=lane2, c1=lane2+32;
    float M=-3.4e38f;
    /* pass 1: global max over partials */
    for(int j=0;j<KW;j++){ float pm=pscr[(size_t)(h*KW+j)*(2+HD)+0]; if(pm>M)M=pm; }
    float L_=0.f, A0=0.f, A1=0.f;
    for(int j=0;j<KW;j++){ float* ps=pscr+(size_t)(h*KW+j)*(2+HD);
      float pm=ps[0], pl=ps[1]; float w=__expf(pm-M);
      L_ += pl*w; A0 += ps[2+c0]*w; A1 += ps[2+c1]*w; }
    float invl=1.f/L_;
    attn[h*HD+c0]=A0*invl; attn[h*HD+c1]=A1*invl;
  }
  grid.sync();

  /* ---- O GEMV (global warp stripe rows) + residual x += O ---- */
  for(int r=gw;r<D;r+=gnw){
    float o=warp_dot(Wo+(size_t)r*D, attn, D, lane);
    if(lane==0) xout[r]=x[r]+o;
  }
}

/* KERNEL 2: fused FFN block, multi-CTA cooperative. */
extern "C" __global__ void decode_ffn_fused(
    const float* __restrict__ xin, const float* __restrict__ g2,
    const float* __restrict__ Wg,const float* __restrict__ Wu,const float* __restrict__ Wd,
    float* __restrict__ xn2, float* __restrict__ hscr, float* __restrict__ out,
    float* __restrict__ ssscr, int dummyL)
{
  cg::grid_group grid = cg::this_grid();
  int tid=threadIdx.x, lane=tid&31;
  int gw=gwarp(), gnw=gnwarp(), gt=gtid(), gn=gnthr();
  __shared__ float red[BLK];

  /* ---- RMSNorm(xin,g2) grid-wide ---- */
  float ss=0.f;
  for(int i=gt;i<D;i+=gn){ float v=xin[i]; ss+=v*v; }
  red[tid]=ss; __syncthreads();
  for(int s=BLK/2;s>0;s>>=1){ if(tid<s) red[tid]+=red[tid+s]; __syncthreads(); }
  if(tid==0) ssscr[blockIdx.x]=red[0];
  grid.sync();
  float tot=0.f; for(int b=0;b<gridDim.x;b++) tot+=ssscr[b];
  float inv=rsqrtf(tot/(float)D + 1e-5f);
  for(int i=gt;i<D;i+=gn) xn2[i]=xin[i]*inv*g2[i];
  grid.sync();

  /* ---- gate+up GEMV (global warp stripe FF rows) + SwiGLU -> hscr ---- */
  for(int r=gw;r<FF;r+=gnw){
    float gg=warp_dot(Wg+(size_t)r*D, xn2, D, lane);
    float uu=warp_dot(Wu+(size_t)r*D, xn2, D, lane);
    if(lane==0){ float sg=1.f/(1.f+__expf(-gg)); hscr[r]=gg*sg*uu; }
  }
  grid.sync();

  /* ---- down GEMV (global warp stripe D rows, dot over FF) + residual ---- */
  for(int r=gw;r<D;r+=gnw){
    float dd=warp_dot(Wd+(size_t)r*FF, hscr, FF, lane);
    if(lane==0) out[r]=xin[r]+dd;
  }
}
