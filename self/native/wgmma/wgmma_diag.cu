// wgmma_diag.cu — isolate the accumulator-register -> C(row,col) mapping.
// Structured input so the EXPECTED C is C[m][n] = n (independent of subtle
// input tiling we just probe the output mapping). A[m][k]=(k==0?1:0),
// B[k][n]=(k==0? (float)n : 0). Then C[m][n]=n for every m.
// We DUMP, per thread, (warp,lane,reg_idx) -> the value it received, and infer
// the true (row,col) by matching value==col. Prints the inferred formula.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)
__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0;d|=(uint64_t)((s&0x3FFFF)>>4);d|=((uint64_t)((lbo>>4)&0x3FFF))<<16;d|=((uint64_t)((sbo>>4)&0x3FFF))<<32;return d;}
// Stage A,B into core-matrix tiled layout (8x4 tf32 core).
extern "C" __global__ void k(const float* gA,const float* gB,float* regdump){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[]; float* As=sm; float* Bs=sm+M*K;
    int tid=threadIdx.x;
    for(int i=tid;i<M*K;i+=128){int m=i/K,kk=i%K;int mt=m/8,r=m%8,kt=kk/4,c=kk%4;As[((mt*(K/4)+kt)*8+r)*4+c]=gA[m*K+kk];}
    for(int i=tid;i<K*N;i+=128){int kk=i/N,n=i%N;int kt=kk/8,r=kk%8,nt=n/4,c=n%4;Bs[((kt*(N/4)+nt)*8+r)*4+c]=gB[kk*N+n];}
    __syncthreads();
    uint64_t dA=mk((uint32_t)__cvta_generic_to_shared(As),128,256);
    uint64_t dB=mk((uint32_t)__cvta_generic_to_shared(Bs),128,256);
    float d[32];
    #pragma unroll
    for(int i=0;i<32;++i)d[i]=0.f;
    asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
    asm volatile(
      "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 "
      "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15,"
      "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1;\n"
      :"+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3]),"+f"(d[4]),"+f"(d[5]),"+f"(d[6]),"+f"(d[7]),
       "+f"(d[8]),"+f"(d[9]),"+f"(d[10]),"+f"(d[11]),"+f"(d[12]),"+f"(d[13]),"+f"(d[14]),"+f"(d[15]),
       "+f"(d[16]),"+f"(d[17]),"+f"(d[18]),"+f"(d[19]),"+f"(d[20]),"+f"(d[21]),"+f"(d[22]),"+f"(d[23]),
       "+f"(d[24]),"+f"(d[25]),"+f"(d[26]),"+f"(d[27]),"+f"(d[28]),"+f"(d[29]),"+f"(d[30]),"+f"(d[31])
      :"l"(dA),"l"(dB));
    asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
    asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory");
    // dump all 32 regs for every thread: regdump[tid*32+i]=d[i]
    for(int i=0;i<32;++i) regdump[tid*32+i]=d[i];
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}
int main(){
    const int M=64,N=64,K=8;
    float *hA=new float[M*K],*hB=new float[K*N];
    for(int i=0;i<M*K;++i){int m=i/K,kk=i%K;hA[i]=(kk==0)?1.f:0.f;}
    for(int i=0;i<K*N;++i){int kk=i/N,n=i%N;hB[i]=(kk==0)?(float)n:0.f;}
    float *dA,*dB,*dR;CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dR,128*32*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
    CK(cudaMemset(dR,0,128*32*4));
    k<<<1,128,(M*K+K*N)*4>>>(dA,dB,dR);
    CK(cudaGetLastError());CK(cudaDeviceSynchronize());
    float* hR=new float[128*32];CK(cudaMemcpy(hR,dR,128*32*4,cudaMemcpyDeviceToHost));
    // For threads 0..3 and 32 (warp1) print their 32 reg values (= expected col index).
    for(int t=0;t<5;++t){printf("tid=%d:",t);for(int i=0;i<32;++i)printf(" %.0f",hR[t*32+i]);printf("\n");}
    printf("tid=32:");for(int i=0;i<32;++i)printf(" %.0f",hR[32*32+i]);printf("\n");
    // Expected (my formula): tid t, reg idx=c*4+r*2+p -> col=(t%4... ) ; we just
    // eyeball whether reg values equal the column index they SHOULD map to.
    return 0;
}
