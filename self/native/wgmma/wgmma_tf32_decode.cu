// wgmma_tf32_decode.cu — full decode of the wgmma A read map for a given (layout,desc).
//
// Two layouts of the A shared buffer are tested:
//   LAYOUT 0: plain row-major  As[m*K+k]
//   LAYOUT 1: core-matrix tiled As[((m/8)*(K/8? ) ...]  -> K-major 8x8 core tiles:
//             phys = (m/8)*(8*K) + (k)*8 + (m%8)      [8 rows contiguous per k]
//   LAYOUT 2: phys = (m/8)*(8*K) + (m%8)*K + k        [row-major within 8-strip]
// B is ALWAYS one-hot row KSEL (plain row-major); its descriptor fixed plausibly.
// We decode, for logical A[m][KSEL], the value V=m'*8+k' wgmma actually summed,
// printing m',k' so the permutation is explicit. Goal: find (layout,descA) with
// m'==m and k'==KSEL for all -> identity -> correct.
#include <cstdio>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)
__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0; d|=(uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32; return d;
}
extern "C" __global__ void k(const float* gA,const float* gB,float* gD,int layout,
                             uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; float* Bs=sm+M*K;
    int tid=threadIdx.x;
    for(int i=tid;i<M*K;i+=128){ int m=i/K,kk=i%K; int p;
        if(layout==0) p=m*K+kk;
        else if(layout==1) p=(m/8)*(8*K)+kk*8+(m%8);
        else p=(m/8)*(8*K)+(m%8)*K+kk;
        As[p]=gA[m*K+kk];
    }
    for(int i=tid;i<K*N;i+=128) Bs[i]=gB[i]; // B plain row-major
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
static const int M=64,N=64,K=8;
static float *dA,*dB,*dD,*hA,*hB,*hD;
static int probe(int layout,uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    // For logical A[m][KSEL]: D[m][0] should be m*8+KSEL. Count K-slices read + decode.
    int total_ok=0, kslices_active=0;
    for(int KSEL=0;KSEL<K;++KSEL){
        for(int i=0;i<K*N;++i){int kk=i/N; hB[i]=(kk==KSEL)?1.0f:0.0f;}
        cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice);
        cudaMemset(dD,0,M*N*4);
        size_t smsz=(M*K+K*N)*4;
        k<<<1,128,smsz>>>(dA,dB,dD,layout,lA,sA,lB,sB);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){ printf("  L%d lA=%u sA=%u : FAULT %s\n",layout,lA,sA,cudaGetErrorString(e)); return -2; }
        cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost);
        int ok=0,active=0;
        for(int m=0;m<M;++m){ if(hD[m*N]!=0)active=1; if((int)(hD[m*N]+0.5f)==m*8+KSEL)ok++; }
        total_ok+=ok; if(active)kslices_active++;
        if(KSEL==0){ int v0=(int)(hD[0]+0.5f),v1=(int)(hD[N]+0.5f);
            printf("    [L%d lA=%u sA=%u] KSEL0 m0->V%d(m'%d,k'%d) m1->V%d(m'%d,k'%d) ok=%d\n",
                   layout,lA,sA,v0,v0/8,v0%8,v1,v1/8,v1%8,ok); }
    }
    printf("  L%d lA=%u sA=%u lB=%u sB=%u : total_ok=%d/512 kslices_active=%d/8\n",
           layout,lA,sA,lB,sB,total_ok,kslices_active);
    return total_ok;
}
// argv: layout lA sA lB sB  -> ONE probe per process (fault isolation).
int main(int argc,char**argv){
    int layout=argc>1?atoi(argv[1]):0;
    uint32_t lA=argc>2?atoi(argv[2]):16, sA=argc>3?atoi(argv[3]):32;
    uint32_t lB=argc>4?atoi(argv[4]):32, sB=argc>5?atoi(argv[5]):256;
    hA=new float[M*K];hB=new float[K*N];hD=new float[M*N];
    for(int m=0;m<M;++m)for(int kk=0;kk<K;++kk)hA[m*K+kk]=(float)(m*8+kk);
    CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));
    int r=probe(layout,lA,sA,lB,sB);
    if(r==512)printf("IDENTITY-A FOUND layout=%d lA=%u sA=%u lB=%u sB=%u\n",layout,lA,sA,lB,sB);
    return r==512?0:1;
}
