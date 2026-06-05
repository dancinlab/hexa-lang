// wgmma_tf32_revlayout.cu — REVERSE-ENGINEER the wgmma no-swizzle shared layout
// for TF32 m64n64k8 directly on the hardware, deterministically.
//
// Method: B = identity-selector. Set B[k][n] = 1 if n==COL else 0 (one-hot column).
// Then D[m][n] = sum_k A[m][k]*B[k][n] = A[m][COL] for n==COL ... no — that picks a
// COLUMN of B, giving D[:,COL] = A @ e_COL = sum_k A[m][k]*delta = A[m][COL]? No:
// D[m][n] = sum_k A[m][k] B[k][n]. With B[k][n]=delta(k,K0) (one-hot ROW k=K0 across
// all n): D[m][n] = A[m][K0] for all n. So sweeping K0 reads out A's columns and tells
// us which shared slot wgmma read for logical A[m][K0].
//
// Simpler & exhaustive: set A shared buffer so As[phys]=phys (a ramp). Set B=identity
// over N (B[k][n]=delta(k,?)) ... Instead we directly probe the PERMUTATION:
// We place a KNOWN value at exactly ONE physical shared slot of A (As[p]=1, else 0),
// B=all-ones-in-one-column, and observe which D[m][n] lights up -> maps physical slot p
// to logical (m,k). Doing this for the relevant slots reconstructs the layout. But
// 512 launches is fine and fault-free (we only WRITE shared, descriptor offsets fixed).
//
// We use descriptor LBO=16,SBO=32 for A (the f16-analog) and LBO=16,SBO=... for B,
// but the descriptor walk is what we're probing, so we fix a SINGLE plausible desc and
// vary the physical-slot content. Output: for each physical A-slot p in [0,64), which
// (m,k) logical position wgmma attributes it to (via the lit D entry). That IS the map.
//
// Concretely (compact): A[m][k] = m*8 + k  (a distinct value per logical cell, range
// 0..511 fits exactly in tf32). B = one-hot: B[k][n] = (k==KSEL)?1:0. Then
// D[m][n] = A[m][KSEL] for every n. So D[m][0] tells us the VALUE wgmma used as
// A[m][KSEL]; decode value=m'*8+k' -> wgmma thinks (m,KSEL) <- physical-cell that holds
// logical (m',k'). We sweep KSEL in [0,8) and read D[m][0] for all m -> full A map.
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
// gA stored PLAIN row-major: As[m*8+k]=m*8+k. gB plain row-major one-hot column KSEL.
extern "C" __global__ void k(const float* gA,const float* gB,float* gD,
                             uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; float* Bs=sm+M*K;
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
static const int M=64,N=64,K=8;
int main(int argc,char**argv){
    uint32_t lA=argc>1?atoi(argv[1]):16, sA=argc>2?atoi(argv[2]):32;
    uint32_t lB=argc>3?atoi(argv[3]):16, sB=argc>4?atoi(argv[4]):32;
    float *hA=new float[M*K],*hB=new float[K*N],*hD=new float[M*N];
    for(int m=0;m<M;++m)for(int kk=0;kk<K;++kk)hA[m*K+kk]=(float)(m*8+kk); // distinct ramp
    float *dA,*dB,*dD;CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));
    printf("=== wgmma A-operand layout probe (desc lA=%u sA=%u lB=%u sB=%u) ===\n",lA,sA,lB,sB);
    printf("For logical A[m][KSEL], wgmma actually used value V (=m'*8+k'). map per KSEL:\n");
    for(int KSEL=0;KSEL<K;++KSEL){
        for(int i=0;i<K*N;++i){int kk=i/N; hB[i]=(kk==KSEL)?1.0f:0.0f;}
        CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
        CK(cudaMemset(dD,0,M*N*4));
        size_t smsz=(M*K+K*N)*4;
        k<<<1,128,smsz>>>(dA,dB,dD,lA,sA,lB,sB);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("KSEL=%d FAULT %s\n",KSEL,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost));
        // D[m][0] should equal A[m][KSEL] = m*8+KSEL if layout correct.
        // Print first 8 rows' observed value vs expected.
        printf("KSEL=%d : ",KSEL);
        int ok=0;
        for(int m=0;m<M;++m){ int exp=m*8+KSEL; if((int)(hD[m*N+0]+0.5f)==exp)ok++; }
        printf("rows_correct=%d/64  sample m0..3 obs=[%.0f %.0f %.0f %.0f] exp=[%d %d %d %d]\n",
               ok,hD[0],hD[1*N],hD[2*N],hD[3*N],KSEL,8+KSEL,16+KSEL,24+KSEL);
    }
    return 0;
}
