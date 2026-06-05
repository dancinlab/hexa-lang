// wgmma_tf32_gmma.cu — W1/W2: the REAL CUTLASS-3.x GMMA::Layout core-matrix builder
// for TF32 wgmma.mma_async.m64n64k8, no-swizzle (INTERLEAVE / SWIZZLE_NONE) mode.
//
// ============================ THE CORRECTED MODEL ============================
// Authoritative facts (PTX ISA 9.7.16.5.1.2 + CUTLASS cute/arch/mma_sm90_desc.hpp +
// Colfax WGMMA tutorial):
//
//   * A "core matrix" is 8 ROWS (strided dir) x 16 BYTES (contiguous dir).
//     For TF32 (4 bytes/elem) => 16 bytes = 4 ELEMENTS. So a core matrix is 8x4 TF32.
//     (The prior kit assumed 8x8 K core strips — THIS WAS THE BUG: defects (1)+(2).)
//
//   * GmmaDescriptor 64-bit bit fields (cute/arch/mma_sm90_desc.hpp):
//       start_address_      : bits [ 0,14)   (value>>4)
//       leading_byte_offset_: bits [16,30)   (LBO>>4)
//       stride_byte_offset_ : bits [32,46)   (SBO>>4)
//       base_offset_        : bits [49,52)   (swizzle only)
//       layout_type_        : bits [62,64)   INTERLEAVE=0,B128=1,B64=2,B32=3
//
//   * No-swizzle K-major canonical INTER layout: the (8 x 4-elem) core matrices are
//     laid CONTIGUOUS (32 elems = 128 bytes each). LBO = stride between core matrices
//     along the contiguous (K) walk; SBO = stride between core matrices along the
//     strided (M for A / N for B) walk. Colfax K-major example: LBO=128B, SBO=256B.
//
// For m64n64k8 (K=8 => 2 K-core-matrices; M=64 => 8 M-core-rows; N=64 => 8 N-strips):
//   A (M=64 x K=8): M-major-of-8 x K. Core layout: for each (mo in 0..7, ko in 0..1):
//        a core matrix of 8 rows (m in mo*8..+8) x 4 cols (k in ko*4..+4).
//   B (K=8  x N=64): K x N-major-of-8. Core layout: for each (no in 0..7, ko in 0..1):
//        a core matrix of 8 rows (n in no*8..+8) x 4 cols (k in ko*4..+4).
//
// We provide several candidate core orderings (how core matrices are concatenated:
// K-inner vs strided-inner) selected by ALO/BLO, and a small descriptor sweep, but
// the PRINCIPLED default (ALO=BLO=0) is the CUTLASS INTER layout with LBO/SBO matched.
//
// MODE 0 (default): full random GEMM, rel_rms vs CPU ref  (W3 gate at 2048 is a separate
//   tiled kernel; this validates the single-tile correctness — W2 gate).
// MODE 1: single-tile identity probe — A,B chosen so D must equal a known integer ramp;
//   reports exact-match count and rel_rms 0 target (the W2 gate).
//
// argv: mode ALO BLO lA sA lB sB
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
    return d; // layout_type=0 (INTERLEAVE / no-swizzle), base_offset=0
}

// ---- GMMA INTER (no-swizzle) core-matrix physical index ----
// Core matrix = 8 strided-rows x 4 contiguous-cols (TF32). 32 elems contiguous each.
// strided dim S (M for A, N for B), contiguous dim K. S=64 -> 8 strips ; K=8 -> 2 cores.
// LO selects concatenation order of the (strip, kcore) core matrices:
//   LO==0: K-core inner  -> core_id = strip*2 + kcore        (CUTLASS INTER canonical)
//   LO==1: strip inner   -> core_id = kcore*8 + strip
__device__ __forceinline__ int gmma_phys(int s,int k,int /*S*/,int /*K*/,int LO){
    int strip = s>>3, sr = s&7;        // 8 strips of 8 strided rows
    int kcore = k>>2, kc = k&3;        // 2 core matrices of 4 contiguous (K) elems
    int core_id = (LO==0)? (strip*2 + kcore) : (kcore*8 + strip);
    // within a core matrix: 8 rows x 4 cols, row-major contiguous (32 elems)
    return core_id*32 + sr*4 + kc;
}

extern "C" __global__ void kern(const float* gA,const float* gB,float* gD,int ALO,int BLO,
                             uint32_t lA,uint32_t sA,uint32_t lB,uint32_t sB){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; float* Bs=sm+M*K;
    int tid=threadIdx.x;
    // A logical [m][k] (M strided, K contiguous) -> GMMA core layout
    for(int i=tid;i<M*K;i+=128){int m=i/K,kk=i%K; As[gmma_phys(m,kk,M,K,ALO)]=gA[m*K+kk];}
    // B logical [k][n]; for wgmma B operand the strided dim is N, contiguous is K.
    for(int i=tid;i<K*N;i+=128){int kk=i/N,n=i%N; Bs[gmma_phys(n,kk,N,K,BLO)]=gB[kk*N+n];}
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
    // wgmma m64nNk f32 accumulator -> register layout (PTX ISA):
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
        if(row<64&&col<64)gD[row*64+col]=d[idx];
    }
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}
static const int M=64,N=64,K=8;
int main(int argc,char**argv){
    int mode=argc>1?atoi(argv[1]):0;
    int ALO=argc>2?atoi(argv[2]):0, BLO=argc>3?atoi(argv[3]):0;
    // CUTLASS INTER K-major canonical: LBO/SBO between contiguous core matrices.
    // Default candidates derived from Colfax (LBO=128, SBO=256) scaled to this tile.
    uint32_t lA=argc>4?atoi(argv[4]):128, sA=argc>5?atoi(argv[5]):256;
    uint32_t lB=argc>6?atoi(argv[6]):128, sB=argc>7?atoi(argv[7]):256;
    float *hA=new float[M*K],*hB=new float[K*N],*hD=new float[M*N],*Dr=new float[M*N];
    if(mode==1){
        // single-tile identity probe: A = identity-ish ramp, B = ramp, decode exact.
        // Use A[m][k]=(m==k? small)  -> instead use full ramp & rel_rms-0 target via int.
        for(int m=0;m<M;++m)for(int kk=0;kk<K;++kk)hA[m*K+kk]=tf((float)((m+kk)%4)-1.5f);
        for(int kk=0;kk<K;++kk)for(int n=0;n<N;++n)hB[kk*N+n]=tf((float)((kk+n)%4)-1.5f);
    } else {
        srand(1);
        for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
        for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
    }
    for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];Dr[m*N+n]=a;}
    float *dA,*dB,*dD;CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
    CK(cudaMemset(dD,0,M*N*4));
    size_t smsz=(M*K+K*N)*4;
    kern<<<1,128,smsz>>>(dA,dB,dD,ALO,BLO,lA,sA,lB,sB);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("mode=%d ALO=%d BLO=%d lA=%u sA=%u lB=%u sB=%u FAULT %s\n",mode,ALO,BLO,lA,sA,lB,sB,cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;int nz=0,exact=0;for(int i=0;i<M*N;++i){double dd=hD[i]-Dr[i];se+=dd*dd;sr+=Dr[i]*Dr[i];if(hD[i]!=0)nz++;if(fabs(dd)<1e-4)exact++;}
    double rr=sqrt(se/fmax(1e-12,sr));
    printf("mode=%d ALO=%d BLO=%d lA=%u sA=%u lB=%u sB=%u : nz=%d exact=%d/%d rel_rms=%.3e %s\n",
           mode,ALO,BLO,lA,sA,lB,sB,nz,exact,M*N,rr, rr<=3e-3?"PASS":"");
    return rr<=3e-3?0:2;
}
