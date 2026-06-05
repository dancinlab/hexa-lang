// wgmma_tf32_bdecode.cu — decode the B operand read + find a (Alayout,Blayout,desc)
// where BOTH operands read identity, for TF32 m64n64k8. Per-process (fault isolation).
//
// Strategy: use A = one-hot ROW. A[m][k] = (m==MSEL && k==KSEL)?1:0. Then
//   D[m][n] = sum_k A[m][k] B[k][n] -> D[MSEL][n] = B[KSEL][n] (others 0).
// B given a distinct ramp B[k][n]=k*64+n. So D[MSEL][n] reveals the VALUE wgmma
// used as B[KSEL][n]; decode val=k'*64+n' -> wgmma mapped logical (KSEL,n) <- (k',n').
// Sweep KSEL to see if all K rows of B are reachable (the 1/8-kslice bug) and decode.
//
// A stored with the layout we WANT (we'll pass Alayout); B stored with Blayout.
// argv: Alayout Blayout lA sA lB sB
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
__device__ int amap(int m,int k,int K,int L){
    if(L==0)return m*K+k;
    if(L==1)return (m/8)*(8*K)+k*8+(m%8);
    return (m/8)*(8*K)+(m%8)*K+k;
}
__device__ int bmap(int k,int n,int K,int N,int L){
    if(L==0)return k*N+n;                       // plain row-major
    if(L==1)return (n/8)*(8*K)+k*8+(n%8);       // N-major 8-strip, k contiguous-of-8
    if(L==2)return (n/8)*(8*K)+(n%8)*K+k;       // N-major 8-strip, row-major within
    return n*K+k;                                // transposed (col-major)
}
extern "C" __global__ void kern(const float* gA,const float* gB,float* gD,int AL,int BL,
                             uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; float* Bs=sm+M*K;
    int tid=threadIdx.x;
    for(int i=tid;i<M*K;i+=128){int m=i/K,kk=i%K; As[amap(m,kk,K,AL)]=gA[m*K+kk];}
    for(int i=tid;i<K*N;i+=128){int kk=i/N,n=i%N; Bs[bmap(kk,n,K,N,BL)]=gB[kk*N+n];}
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
    int AL=argc>1?atoi(argv[1]):1, BL=argc>2?atoi(argv[2]):0;
    uint32_t lA=argc>3?atoi(argv[3]):16, sA=argc>4?atoi(argv[4]):32;
    uint32_t lB=argc>5?atoi(argv[5]):16, sB=argc>6?atoi(argv[6]):32;
    float *hA=new float[M*K],*hB=new float[K*N],*hD=new float[M*N];
    for(int i=0;i<K*N;++i){int kk=i/N,n=i%N; hB[i]=(float)(kk*64+n);} // distinct ramp
    float *dA,*dB,*dD;CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
    const int MSEL=0;
    int kactive=0;
    printf("=== B decode AL=%d BL=%d lA=%u sA=%u lB=%u sB=%u (A=one-hot row MSEL=0) ===\n",AL,BL,lA,sA,lB,sB);
    for(int KSEL=0;KSEL<K;++KSEL){
        for(int i=0;i<M*K;++i){int m=i/K,kk=i%K; hA[i]=(m==MSEL&&kk==KSEL)?1.0f:0.0f;}
        CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));
        CK(cudaMemset(dD,0,M*N*4));
        size_t smsz=(M*K+K*N)*4;
        kern<<<1,128,smsz>>>(dA,dB,dD,AL,BL,lA,sA,lB,sB);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("  KSEL=%d FAULT %s\n",KSEL,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost));
        // D[MSEL][n] should = B[KSEL][n] = KSEL*64+n. decode n0,n1.
        int v0=(int)(hD[MSEL*N+0]+0.5f), v1=(int)(hD[MSEL*N+1]+0.5f);
        int ok=0,active=0;
        for(int n=0;n<N;++n){int exp=KSEL*64+n; int got=(int)(hD[MSEL*N+n]+0.5f); if(got==exp)ok++; if(hD[MSEL*N+n]!=0)active=1;}
        if(active)kactive++;
        printf("  KSEL=%d: n0->V%d(k'%d,n'%d) n1->V%d(k'%d,n'%d) ok=%d/64 %s\n",
               KSEL,v0,v0/64,v0%64,v1,v1/64,v1%64,ok,active?"":"(ZERO)");
    }
    printf("  kslices_active=%d/8\n",kactive);
    return 0;
}
