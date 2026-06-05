// wgmma_tf32_swz.cu — TF32 wgmma m64n64k8, PLAIN row-major shared + LBO/SBO sweep.
//
// KEY INSIGHT from the passing f16 probe (wgmma_f16_probe.cu): that kernel stores
// A/B PLAIN row-major in shared (As[i]=A[i]) and feeds the descriptor LBO/SBO =
// (16,32) for A, (64,16) for B — and it computes CORRECTLY. So the wgmma no-swizzle
// descriptor reads a (near) row-major buffer directly; probe3's hand-rolled
// core-matrix re-tiling was the BUG, not the fix.
//
// This probe: store A (64x8) and B (8x64) PLAIN row-major in shared, then SWEEP
// the (LBO,SBO) descriptor immediates over the canonical no-swizzle candidates and
// report rel_rms for each. The f16 mapping scaled to tf32 (4B elem, K=8):
//   f16 m64n32k16: A LBO=16,SBO=32 ; with K=16 f16, row=32B. ratio LBO=row/2, SBO=row.
//   tf32 m64n64k8: A row = 8*4 = 32B. So candidate A: LBO=16,SBO=32 (same bytes).
//   f16 B LBO=64,SBO=16: B is 16x32 f16, row=64B. LBO=row, SBO=row/4.
//   tf32 B is 8x64, row=64*4=256B. candidate B: LBO=256,SBO=64? sweep around it.
//
// Each candidate is launched in its OWN kernel invocation guarded by a bounds-safe
// shared buffer (we over-allocate). A faulting candidate is caught and skipped.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)

__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0;
    d |= (uint64_t)((s   >> 4) & 0x3FFF);
    d |= ((uint64_t)((lbo >> 4) & 0x3FFF)) << 16;
    d |= ((uint64_t)((sbo >> 4) & 0x3FFF)) << 32;
    return d; // swizzle=0
}

// gA: 64x8 row-major, gB: 8x64 row-major. Stored PLAIN in shared.
extern "C" __global__ void k(const float* gA,const float* gB,float* gD,
                             uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; float* Bs=sm+M*K;        // plain row-major
    int tid=threadIdx.x;
    for(int i=tid;i<M*K;i+=128) As[i]=gA[i];
    for(int i=tid;i<K*N;i+=128) Bs[i]=gB[i];
    __syncthreads();
    uint32_t aA=(uint32_t)__cvta_generic_to_shared(As), aB=(uint32_t)__cvta_generic_to_shared(Bs);
    uint64_t dA=mk(aA,lA,sA), dB=mk(aB,lB,sB);
    float d[32];
    #pragma unroll
    for(int i=0;i<32;++i)d[i]=0.f;
    asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
    asm volatile(
      "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 "
      "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15,"
      "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, "
      "%32,%33, 1,1,1;\n"
      :"+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3]),"+f"(d[4]),"+f"(d[5]),"+f"(d[6]),"+f"(d[7]),
       "+f"(d[8]),"+f"(d[9]),"+f"(d[10]),"+f"(d[11]),"+f"(d[12]),"+f"(d[13]),"+f"(d[14]),"+f"(d[15]),
       "+f"(d[16]),"+f"(d[17]),"+f"(d[18]),"+f"(d[19]),"+f"(d[20]),"+f"(d[21]),"+f"(d[22]),"+f"(d[23]),
       "+f"(d[24]),"+f"(d[25]),"+f"(d[26]),"+f"(d[27]),"+f"(d[28]),"+f"(d[29]),"+f"(d[30]),"+f"(d[31])
      :"l"(dA),"l"(dB));
    asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
    asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory");
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
        if(row<64&&col<64)gD[row*64+col]=d[idx];
    }
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}

static const int M=64,N=64,K=8;
static float *dA,*dB,*dD,*hD,*Dr;
static double run_one(uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    cudaMemset(dD,0,M*N*4);
    size_t smsz=(M*K+K*N)*4;
    k<<<1,128,smsz>>>(dA,dB,dD,lA,sA,lB,sB);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess) e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("  lA=%u sA=%u lB=%u sB=%u -> FAULT %s\n",lA,sA,lB,sB,cudaGetErrorString(e)); return 9e9; }
    cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost);
    double se=0,sr=0;int nz=0;for(int i=0;i<M*N;++i){double dd=hD[i]-Dr[i];se+=dd*dd;sr+=Dr[i]*Dr[i];if(hD[i]!=0)nz++;}
    double rr=sqrt(se/fmax(1e-12,sr));
    printf("  lA=%u sA=%u lB=%u sB=%u  nz=%d rel_rms=%.3e\n",lA,sA,lB,sB,nz,rr);
    return rr;
}
int main(){
    float *hA=new float[M*K],*hB=new float[K*N];
    hD=new float[M*N]; Dr=new float[M*N];
    srand(1);
    for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
    for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
    for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];Dr[m*N+n]=a;}
    CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
    // Candidate (LBO,SBO) bytes. A row=32B (8 tf32). B row=256B (64 tf32).
    uint32_t cand[]={16,32,64,128,256,512};
    double best=9e9; uint32_t blA=0,bsA=0,blB=0,bsB=0;
    printf("=== full (LBO,SBO) x4 sweep, plain row-major shared ===\n");
    for(uint32_t lAi:cand)for(uint32_t sAi:cand)for(uint32_t lBi:cand)for(uint32_t sBi:cand){
        double rr=run_one(lAi,sAi,lBi,sBi);
        if(rr<best){best=rr;blA=lAi;bsA=sAi;blB=lBi;bsB=sBi;}
        if(rr<=3e-3){ printf("FOUND lA=%u sA=%u lB=%u sB=%u rel_rms=%.3e\n",lAi,sAi,lBi,sBi,rr); }
    }
    printf("BEST lA=%u sA=%u lB=%u sB=%u rel_rms=%.3e\n",blA,bsA,blB,bsB,best);
    printf("WGMMA_TF32_SWZ: %s\n",best<=3e-3?"PASS":"FAIL");
    return best<=3e-3?0:2;
}
