// wgmma_tf32_swz.cu — CORRECTED wgmma no-swizzle core-matrix layout.
//
// Single-tile TF32 wgmma probe: m64n64k8, one warpgroup (128 threads).
// GOAL: rel-RMS 0 on a known A/B before scaling.
//
// THE CORRECTION over probe3:
// The wgmma matrix descriptor (no-swizzle) walks shared memory as a grid of
// "core matrices". For TF32 each core matrix is 8 rows x 8 cols (an 8x8 atom),
// BUT the byte-granular unit the descriptor strides over is the K-contiguous
// 8-row leading block. The canonical CUTLASS no-swizzle layout is:
//
//   Operand A (MxK, M along the warpgroup-M=64): laid out as KMAJOR within an
//   8-row block. i.e. element (m,k) -> within its 8-row block (mblk=m/8, mi=m%8)
//   the storage offset is: mblk*(8*K) + k*8 + mi.   (K-contiguous-of-8-rows)
//   -> LBO = stride between K-major core-mtx columns = 8 rows * 8 cols *... we
//      derive from the formula below.
//
//   Operand B (KxN, N along warpgroup-N=64): wgmma B is N-major-of-8. Element
//   (k,n) -> nblk=n/8, ni=n%8: offset = nblk*(8*K) + k*8 + ni.
//
// Descriptor LBO (leadingByteOffset): bytes from one core-matrix to the next
//   along the K (contraction) direction within the same 8-row strip block.
//   With the (blk*(8*K) + k*8 + i) packing, K advances by 8 elems = 32B per k,
//   and a "core matrix" spans 8 k-values -> LBO not used the way probe3 did.
// Descriptor SBO (strideByteOffset): bytes from one 8-row strip to the next
//   = 8*K elems = 8*8*4 = 256B for A.
//
// The descriptor encodes start>>4, LBO>>4, SBO>>4 in 14-bit fields, base in 18b.
// For no-swizzle (swizzle field = 0), LBO and SBO together describe the 2D walk
// of core matrices: matrix base + (n_core_along_K * LBO) + (m_core_along_M * SBO).
//
// Run: ./swz   (no args; uses the derived LBO/SBO). Prints rel_rms + PASS/FAIL.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)

// Descriptor encode: matches PTX wgmma shared-matrix descriptor (no swizzle).
//  bits  0-13: start address >> 4   (14 bits)
//  bits 16-29: LBO (leading dim byte offset) >> 4
//  bits 32-45: SBO (stride byte offset) >> 4
//  bits 49-51: (base offset, swizzle base) = 0
//  bits 62-63: swizzle mode (00 = none)
__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0;
    d |= (uint64_t)((s   >> 4) & 0x3FFF);
    d |= ((uint64_t)((lbo >> 4) & 0x3FFF)) << 16;
    d |= ((uint64_t)((sbo >> 4) & 0x3FFF)) << 32;
    // swizzle = 0 (no swizzle), base offset 0
    return d;
}

extern "C" __global__ void k(const float* gA,const float* gB,float* gD){
    const int M=64,K=8,N=64;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; float* Bs=sm+M*K;
    int tid=threadIdx.x;
    // ---- A staging: (m,k) -> mblk=m/8, mi=m%8 : off = mblk*(8*K) + k*8 + mi ----
    // This is "8-row strips, K-major within strip, 8 rows contiguous per k".
    for(int i=tid;i<M*K;i+=128){
        int m=i/K, kk=i%K;
        int mblk=m/8, mi=m%8;
        int off = mblk*(8*K) + kk*8 + mi;
        As[off]=gA[m*K+kk];
    }
    // ---- B staging: (k,n) -> nblk=n/8, ni=n%8 : off = nblk*(8*K) + k*8 + ni ----
    for(int i=tid;i<K*N;i+=128){
        int kk=i/N, n=i%N;
        int nblk=n/8, ni=n%8;
        int off = nblk*(8*K) + kk*8 + ni;
        Bs[off]=gB[kk*N+n];
    }
    __syncthreads();
    uint32_t aA=(uint32_t)__cvta_generic_to_shared(As), aB=(uint32_t)__cvta_generic_to_shared(Bs);
    // For this packing: stride from one 8-row strip to the next = 8*K elems*4B.
    //   A: SBO_A = 8*K*4 = 256B. LBO walks K core-cols: each core matrix spans
    //   8 k-values; with k*8 packing, one core-matrix (8x8) = 8*8 elems = 256B,
    //   but K=8 means single K core-tile -> LBO unused (set to 16 min).
    // Empirically the descriptor for a single 8-row strip block uses SBO as the
    // M-core stride and LBO as the K-core stride. K=8 = exactly one core tile.
    const uint32_t LBO_A = 8*8*4;   // one 8x8 core matrix = 256B (K-core stride)
    const uint32_t SBO_A = 8*K*4;   // 8-row strip stride = 256B
    const uint32_t LBO_B = 8*8*4;
    const uint32_t SBO_B = 8*K*4;
    uint64_t dA=mk(aA,LBO_A,SBO_A), dB=mk(aB,LBO_B,SBO_B);
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
    // Epilogue: m64n64 accumulator -> C. Standard wgmma 64xN f32 layout.
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
        if(row<64&&col<64)gD[row*64+col]=d[idx];
    }
}
static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}
int main(int argc,char**argv){
    const int M=64,N=64,K=8;
    float *hA=new float[M*K],*hB=new float[K*N],*hD=new float[M*N],*Dr=new float[M*N];
    srand(1);
    for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
    for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
    for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];Dr[m*N+n]=a;}
    float *dA,*dB,*dD;CK(cudaMalloc(&dA,M*K*4));CK(cudaMalloc(&dB,K*N*4));CK(cudaMalloc(&dD,M*N*4));
    CK(cudaMemcpy(dA,hA,M*K*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,K*N*4,cudaMemcpyHostToDevice));
    CK(cudaMemset(dD,0,M*N*4));
    size_t smsz=(M*K+K*N)*4;
    k<<<1,128,smsz>>>(dA,dB,dD);
    CK(cudaGetLastError()); CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hD,dD,M*N*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;int nz=0;for(int i=0;i<M*N;++i){double d=hD[i]-Dr[i];se+=d*d;sr+=Dr[i]*Dr[i];if(hD[i]!=0)nz++;}
    double rr=sqrt(se/fmax(1e-12,sr));
    printf("LAYOUT=kmajor8 nz=%d/%d rel_rms=%.3e ref0=%.4f gpu0=%.4f ref[1]=%.4f gpu[1]=%.4f\n",
           nz,M*N,rr,Dr[0],hD[0],Dr[1],hD[1]);
    printf("WGMMA_TF32_SWZ: %s\n",rr<=3e-3?"PASS":"FAIL");
    return rr<=3e-3?0:2;
}
