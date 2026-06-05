// wgmma_tf32_gemm_w5.cu — W5 pipeline tune. Same W2/W3-proven GMMA INTER 8x4-core
// layout + the critical fence.proxy.async ordering, but:
//   * WIDE N tile: TN=128 -> 2 wgmma.m64n64k8 per K-step reusing the SAME A tile
//     (raises arithmetic intensity, amortizes A load + descriptor setup).
//   * single commit_group per K-step over both wgmma, wait_group 0 once.
//   * still bit-exact (the proxy fence is kept). Reports rel_rms + own/cuBLAS TFLOP/s.
//
// This is the honest first pipeline-tune step toward closing the W4 sub-parity gap.
// argv: S
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d\n",(int)s);return 3;}}while(0)
__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0; d|=(uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32; return d;
}
__device__ __forceinline__ int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
#define WG(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))

extern "C" __global__ void gemm(const float* __restrict__ gA,const float* __restrict__ gB,
                                float* __restrict__ gD,int M,int N,int K){
    const int TM=64,TN=128,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // A:64x8(512) + B0:8x64(512) + B1:8x64(512) per buffer; double-buffered
    const int AB=TM*TK, BB=TK*64, BUF=AB+2*BB;
    int tid=threadIdx.x;
    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    int ping=0;
    for(int k0=0;k0<K;k0+=TK,ping^=1){
        float* As=sm+ping*BUF; float* B0=As+AB; float* B1=B0+BB;
        for(int i=tid;i<TM*TK;i+=128){int m=i/TK,kk=i%TK; As[gmma_phys(m,kk)]=gA[(bm+m)*K+(k0+kk)];}
        for(int i=tid;i<TK*64;i+=128){int kk=i/64,n=i%64; B0[gmma_phys(n,kk)]=gB[(k0+kk)*N+(bn+n)];}
        for(int i=tid;i<TK*64;i+=128){int kk=i/64,n=i%64; B1[gmma_phys(n,kk)]=gB[(k0+kk)*N+(bn+64+n)];}
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        uint32_t aA=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0=(uint32_t)__cvta_generic_to_shared(B0), a1=(uint32_t)__cvta_generic_to_shared(B1);
        uint64_t dA=mk(aA,128,256), dB0=mk(a0,128,256), dB1=mk(a1,128,256);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        WG(d0,dA,dB0);
        WG(d1,dA,dB1);
        asm volatile("wgmma.commit_group.sync.aligned;\n"
                     "wgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
    }
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=bm+rb+r*8;
        int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
        if(row<M&&col0<N)gD[row*N+col0]=d0[idx];
        if(row<M&&col1<N)gD[row*N+col1]=d1[idx];
    }
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}
int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int M=S,N=S,K=S;
    if(N%128){printf("N must be multiple of 128\n");return 1;}
    size_t szA=(size_t)M*K,szB=(size_t)K*N,szD=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
    srand(7);
    for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
    for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
    float *dA,*dB,*dD,*dR;
    CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));
    cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
    float al=1.f,be=0.f;
    CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dB,N,dA,K,&be,dR,N));CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
    dim3 grid(N/128,(M+63)/64),blk(128);
    size_t smsz=2*((size_t)64*8+2*8*64)*4;
    CK(cudaMemset(dD,0,szD*4));
    gemm<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K);
    cudaError_t e=cudaGetLastError();if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("OWN-FAULT %s\n",cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
    double rr=sqrt(se/fmax(1e-30,sr));
    if(rr>3e-3){printf("W5 S=%d rel_rms=%.3e FAIL — no perf\n",S,rr);return 2;}
    cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
    gemm<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K);CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));for(int i=0;i<it;++i)gemm<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K);
    CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
    float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
    double fl=2.0*(double)M*N*K,tfo=fl/(mo*1e-3)/1e12;
    cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dB,N,dA,K,&be,dR,N);CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dB,N,dA,K,&be,dR,N);
    CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
    float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
    double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
    printf("W5 S=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
           S,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
    return 0;
}
