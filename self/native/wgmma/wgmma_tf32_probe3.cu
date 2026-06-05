// wgmma_tf32_probe3.cu — CORRECT no-swizzle core-matrix tiled staging.
//
// wgmma no-swizzle expects operands as a tiled grid of 8x16B core matrices.
// For tf32 (4B): core matrix = 8 rows x 4 cols. m64n64k8:
//   A (M=64,K=8): tiled as (MT=8 row-tiles of 8) x (KT=2 col-tiles of 4).
//   B (K=8,N=64): wgmma B is K-major; tiled as (KT=2 of... ) — B operand for
//     wgmma is stored N-major in core matrices: (NT=8 tiles of 8 along N) x
//     (KT=... ). For k8, K=8 = 2 core rows-of-8? No: B core matrix is 8(K) x
//     4(N tf32). So B tiled = (KT=1 tile of 8 along K) x (NT=16 tiles of 4 N).
//
// Within the tiled buffer, core matrix (i,j) occupies a contiguous 8x4 block
// (32 tf32 = 128B), and we place them in (row-tile major, col-tile minor)
// order. Then LBO = bytes between adjacent K-core-mtx, SBO = bytes between
// adjacent M-core-mtx. With this PACKED tiling: LBO=128 (next K tile), SBO=
// 128*KT (next M tile). We pass these as args and the host runs ONE candidate
// per process (no sticky-fault sweep).
//
// Run: ./p3 <lboA> <sboA> <lboB> <sboB>  (bytes). Prints rel_rms + PASS/FAIL.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)

__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0; d|=(uint64_t)((s&0x3FFFF)>>4);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32; return d;
}
// Stage row-major MxK A into core-matrix tiled layout in shared.
// core mtx = 8 rows x 4 tf32 cols (16B). mt in [0,M/8), kt in [0,K/4).
// tiled index = ((mt*(K/4)+kt)*8 + r)*4 + c  (packed, row-tile major).
extern "C" __global__ void k(const float* gA,const float* gB,float* gD,
                             uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; float* Bs=sm+M*K;
    int tid=threadIdx.x;
    // A: row-major (m,k) -> tiled
    for(int i=tid;i<M*K;i+=128){
        int m=i/K, kk=i%K; int mt=m/8, r=m%8, kt=kk/4, c=kk%4;
        int t=((mt*(K/4)+kt)*8+r)*4+c; As[t]=gA[m*K+kk];
    }
    // B: row-major (k,n). B core matrix = 8 rows(K) x 4 cols(N). kt in [0,K/8)
    // but K=8 -> single K row-tile of 8; nt in [0,N/4). tiled = ((kt*(N/4)+nt)*8+r)*4+c
    for(int i=tid;i<K*N;i+=128){
        int kk=i/N, n=i%N; int kt=kk/8, r=kk%8, nt=n/4, c=n%4;
        int t=((kt*(N/4)+nt)*8+r)*4+c; Bs[t]=gB[kk*N+n];
    }
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
int main(int argc,char**argv){
    uint32_t lA=argc>1?atoi(argv[1]):128, sA=argc>2?atoi(argv[2]):256;
    uint32_t lB=argc>3?atoi(argv[3]):128, sB=argc>4?atoi(argv[4]):256;
    const int M=64,N=64,K=8;
    float *hA=new float[M*K],*hB=new float[K*N],*hD=new float[M*N],*Dr=new float[M*N];
    srand(1);
    for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
    for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
    for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];Dr[m*N+n]=a;}
    float *dA,*dB,*dD;CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
    CK(cudaMemset(dD,0,M*N*4));
    size_t sm=(M*K+K*N)*4;
    k<<<1,128,sm>>>(dA,dB,dD,lA,sA,lB,sB);
    CK(cudaGetLastError()); CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;int nz=0;for(int i=0;i<M*N;++i){double d=hD[i]-Dr[i];se+=d*d;sr+=Dr[i]*Dr[i];if(hD[i]!=0)nz++;}
    double rr=sqrt(se/fmax(1e-12,sr));
    printf("lboA=%u sboA=%u lboB=%u sboB=%u  nz=%d/%d rel_rms=%.3e ref0=%.4f gpu0=%.4f\n",lA,sA,lB,sB,nz,M*N,rr,Dr[0],hD[0]);
    printf("WGMMA_TF32_PROBE3: %s\n",rr<=3e-3?"PASS":"FAIL");
    return rr<=3e-3?0:2;
}
