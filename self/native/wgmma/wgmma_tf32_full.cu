// wgmma_tf32_full.cu — full TF32 m64n64k8 GEMM, parametrized (Alayout,Blayout,descA,
// descB, epilogue-variant). ONE config per process (fault isolation). Reports rel_rms.
// Random A/B, CPU ref. Goal: find config with rel_rms <= 3e-3.
// argv: AL BL lA sA lB sB EPI
#include <cstdio>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cstdlib>
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
    if(L==0)return k*N+n;
    if(L==1)return (n/8)*(8*K)+k*8+(n%8);
    if(L==2)return (n/8)*(8*K)+(n%8)*K+k;
    return n*K+k;
}
extern "C" __global__ void kern(const float* gA,const float* gB,float* gD,int AL,int BL,int EPI,
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
    // wgmma m64nNk f32 accumulator -> register layout (PTX ISA fig.):
    // lane l in warp w. row = w*16 + l/4 + 8*(reg-pair-hi). The canonical layout:
    //   For 64xN, each thread holds N/... For n64: 32 regs. col group c (0..7) spans
    //   8 columns; within: each thread owns 2 cols (p=0,1). row = w*16 + (l/4) + r*8.
    int w=tid>>5,l=tid&31;
    if(EPI==0){
        int rb=w*16+(l>>2),cb=(l&3)*2;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
            if(row<64&&col<64)gD[row*64+col]=d[idx];
        }
    } else if(EPI==1){
        // col = (l%4)*2 + p + c*8 ; row = w*16 + l/4 + r*8 ; idx layout c*4+r*2+p (same as 0)
        // variant: swap r and the col-octet base: col = c*8 + (l%4)*2 + p, row=w*16+(l/4)+r*8
        int rb=w*16+(l>>2),cb=(l&3)*2;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p,row=rb+r*8,col=c*8+cb+p;
            if(row<64&&col<64)gD[row*64+col]=d[idx];
        }
    } else {
        // EPI==2: index order idx = c*4 + p*2 + r (swap r/p)
        int rb=w*16+(l>>2),cb=(l&3)*2;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+p*2+r,row=rb+r*8,col=cb+p+c*8;
            if(row<64&&col<64)gD[row*64+col]=d[idx];
        }
    }
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}
static const int M=64,N=64,K=8;
int main(int argc,char**argv){
    int AL=argc>1?atoi(argv[1]):0, BL=argc>2?atoi(argv[2]):0;
    uint32_t lA=argc>3?atoi(argv[3]):16, sA=argc>4?atoi(argv[4]):32;
    uint32_t lB=argc>5?atoi(argv[5]):16, sB=argc>6?atoi(argv[6]):32;
    int EPI=argc>7?atoi(argv[7]):0;
    float *hA=new float[M*K],*hB=new float[K*N],*hD=new float[M*N],*Dr=new float[M*N];
    srand(1);
    for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
    for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
    for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];Dr[m*N+n]=a;}
    float *dA,*dB,*dD;CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
    CK(cudaMemset(dD,0,M*N*4));
    size_t smsz=(M*K+K*N)*4;
    kern<<<1,128,smsz>>>(dA,dB,dD,AL,BL,EPI,lA,sA,lB,sB);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("AL=%d BL=%d lA=%u sA=%u lB=%u sB=%u EPI=%d FAULT %s\n",AL,BL,lA,sA,lB,sB,EPI,cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;int nz=0;for(int i=0;i<M*N;++i){double dd=hD[i]-Dr[i];se+=dd*dd;sr+=Dr[i]*Dr[i];if(hD[i]!=0)nz++;}
    double rr=sqrt(se/fmax(1e-12,sr));
    printf("AL=%d BL=%d lA=%u sA=%u lB=%u sB=%u EPI=%d : nz=%d rel_rms=%.3e %s\n",
           AL,BL,lA,sA,lB,sB,EPI,nz,rr, rr<=3e-3?"PASS":"");
    return rr<=3e-3?0:2;
}
