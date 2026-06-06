// wgmma_f16_w14.cu — W14: the PRECISION axis. Port the W10 composed-swizzle-decode
// permute-free own-GEMM (wgmma_tf32_w10.cu, gemm_w10 MODE 4) to FP16 (and BF16) operands
// with f32 accumulate on native sm_90a:
//   wgmma.mma_async.sync.aligned.m64nNk16.f32.f16.f16  (f32 accum, f16 operands)
//   BF16 second mode: ....m64nNk16.f32.bf16.bf16
//
// ===================== WHY W14 (the W13 closed-negative re-opens here) =====================
// W13 (F-FUSION-SM90-WGMMA-W13) CLOSED the TF32 async-pipeline axis: a TF32 gmma decode band
// is 32 KB; the W10 frontier fits exactly ONE at 96 KB/CTA -> 2 CTA/SM. The deep-async ring
// (NSTG=2) the overlap needs costs a 2nd 32-KB band -> 128 KB/CTA -> occupancy HALVES to 1
// CTA/SM, and the occupancy loss swamps the overlap gain (70.7 -> 51.9). 2 CTA/SM and
// decode<->MMA overlap were MUTUALLY EXCLUSIVE for the FP32-scratch TF32 kernel.
//   W14 thesis (W13's own recommendation): a 16-bit gmma band is HALF the bytes = 16 KB.
//   TWO 16-KB bands = 32 KB total fit alongside the swizzled-TMA ring at 2 CTA/SM, which
//   RE-OPENS the W13 overlap (decode of slab N+1 || wgmma of slab N) that TF32 could not
//   reach — AND 16-bit wgmma DOUBLES tensor-core throughput. So W14 attacks the 6.09x gap
//   from BOTH levers TF32 structurally could not: 2x TC + reopened overlap.
//
// ===================== GATE CHANGE (g5 honesty — STATED EXPLICITLY) =====================
// The TF32 campaign's bit-exact-vs-FP64 (rel-RMS = 0) contract DOES NOT APPLY here. A 16-bit
// operand + f32-accumulate wgmma is a genuinely different numeric. The W14 gate is a
// PRECISION-APPROPRIATE TOLERANCE vs a SAME-DTYPE reference:
//   - reference = an FP16-input / f32-accumulate CPU oracle (operands rounded to f16 EXACTLY
//     as the GPU sees them; accumulate in f64 on host = the math the tensor core approximates
//     in f32). This is the same-dtype oracle; we do NOT compare to an FP32/TF32 GEMM.
//   - tolerance: FP16 GEMM rel-RMS ~1e-3..1e-2 (K-dependent: error ~ sqrt(K)*eps_f16,
//     eps_f16 ~ 4.9e-4). We GATE rel_rms <= 1e-2 (single-tile aims much lower).
//   We do NOT claim bit-exact. cuBLAS comparison is SAME-DTYPE (cuBLAS-FP16 via __half I/O,
//   f32 compute), reported as the FP16 roofline ratio — NOT cuBLAS-TF32.
//
// ===================== THE FP16 GMMA LAYOUT RE-DERIVATION (differs from TF32 8x4) ==========
// TF32 wgmma is .k8 with an 8-row x 4-K-elem core (8*4*4B = 128B). FP16 wgmma is .k16 with an
// 8-row x 8-K-elem core (8*8*2B = 128B core matrix). The shared operand is read in K-major
// "INTER" order: strip = s>>3 (which 8-row strip), kcore = k>>3 (which 8-K core within the
// 16-wide k step), inner = (s&7) row, (k&7) col. Each 8x8 f16 core = 64 elems = 128 B.
//   f16 gmma_phys(s,k):  ((strip*KCORES + kcore)*64) + (s&7)*8 + (k&7),  KCORES = K_TILE/8.
// (analog of TF32 gmma_phys((strip*2+kcore)*32 + sr*4 + kc) but 8-wide cores, 2-byte elems.)
//
// SWIZZLE_128B for FP16: a 128-byte row = 64 f16 = 8 granules of 8 f16 (granule = 16 B). The
// SWIZZLE_128B law is the textbook g_phys = g XOR (r&7) on the 8-element granule index g=c>>3
// (W10 RE-MEASURED the same textbook law for FP32 on the 4-elem granule; we RE-MEASURE it for
// f16 8-elem granules on-GPU via MODE 2/3 dumps before trusting it). within-granule w=c&7.
//
// MODES:
//   0  COMPOSED-DECODE PROBE (gate 1): land an f16 128x64 SWIZZLE_128B A-tile, verify the
//      composed index recovers the global value bit-exactly (f16 round-trip exact). rel_rms 0.
//   1  COMPOSED single-tile wgmma m64n64k16 probe (gate 2): decode A,B into gmma INTER, run
//      ONE wgmma, rel_rms vs same-dtype f16/f64 CPU oracle. tol <=1e-2.
//   2  RAW A-DUMP (re-measure the f16 SWIZZLE_128B landed layout, unique-id).
//   3  RAW B-DUMP (re-measure the f16 B 64(N)x16(K) box layout).
//   4  FULL GEMM gemm_f16_w14 (W10 geometry, single gmma band)   — same-dtype gate + perf.
//   6  FULL GEMM gemm_f16_w14_ring (DEEP-ASYNC ring NSTG, the W13 overlap REOPENED at 2 CTA/SM)
//   7  BF16 single-tile wgmma probe (gate, .f32.bf16.bf16).
//   8  BF16 FULL GEMM (gemm_bf16_w14, single band) — same-dtype gate + perf.
//
// argv: S MODE [NST] [NSTG]
// Same-dtype gate FIRST (rel_rms<=1e-2), perf only after the gate (g5). cuBLAS-FP16 roofline.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda.h>
#include <cudaTypedefs.h>
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);return 3;}}while(0)

// ---- f16 GMMA 8x8-core physical index (the W14 re-derivation; KCORES = K_TILE/8). ----
// strided dim s (M for A / N for B), contiguous dim k (K). core = 8 rows x 8 K-elems (128B).
__device__ __host__ __forceinline__ int gmma_phys16(int s,int k,int KCORES){
    int strip=s>>3, sr=s&7, kcore=k>>3, kc=k&7;
    return (strip*KCORES + kcore)*64 + sr*8 + kc;
}
// ---- f16 SWIZZLE_128B physical index inside an 8-row x 64-f16 (128B) atom. ----
// granule g=c>>3 (0..7, each 8 f16 = 16B), within-granule w=c&7. textbook g_phys=g XOR (r&7).
// phys (in f16 elements) = r*64 + (g XOR (r&7))*8 + w.
__device__ __host__ __forceinline__ int sw128_f16(int r,int c){
    int g=c>>3, w=c&7, gp=g^(r&7); return r*64 + gp*8 + w;
}

// ---- mbarrier + TMA helpers (sm_90) ----
__device__ __forceinline__ void mbar_init_tx(uint64_t* b,int cnt){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.init.shared::cta.b64 [%0], %1;\n"::"r"(s),"r"(cnt));}
__device__ __forceinline__ void mbar_expect_tx(uint64_t* b,uint32_t bytes){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.arrive.expect_tx.shared::cta.b64 _, [%0], %1;\n"::"r"(s),"r"(bytes));}
__device__ __forceinline__ void mbar_wait(uint64_t* b,uint32_t phase){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("{\n.reg .pred P;\nLAB_%=:\n"
                 "mbarrier.try_wait.parity.shared::cta.b64 P, [%0], %1;\n"
                 "@!P bra LAB_%=;\n}\n"::"r"(s),"r"(phase));}
__device__ __forceinline__ void tma_load_2d(void* dst,const void* tmap,int x,int y,uint64_t* bar){
    uint32_t d=(uint32_t)__cvta_generic_to_shared(dst);
    uint32_t b=(uint32_t)__cvta_generic_to_shared(bar);
    asm volatile(
      "cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes"
      " [%0], [%1, {%2, %3}], [%4];\n"
      ::"r"(d),"l"(tmap),"r"(x),"r"(y),"r"(b):"memory");}

// wgmma descriptor (no-swizzle SS): start/LBO/SBO in 16-byte units.
__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0; d|=(uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32; return d;}

// wgmma m64n64k16 f16 macro: D += A*B, 32 f32 accumulators (n64 -> 32 regs/thread).
#define WG16(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k16.f32.f16.f16 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1,0,0;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))
// BF16 m64n64k16 macro (same operand/accum shape, .bf16.bf16).
#define WGBF(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k16.f32.bf16.bf16 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1,0,0;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))

// ======================================================================
// MODE 2 — RAW A-DUMP: measure the f16 128x64 SWIZZLE_128B landed layout (unique-id).
// ======================================================================
extern "C" __global__ void dump_a16(const __grid_constant__ CUtensorMap tmapA,
                                     float* __restrict__ gOut,int M,int K){
    const int TM=128, TKSW=64;
    extern __shared__ __align__(128) __half sm[];
    __half* As=sm; uint64_t* bar=(uint64_t*)(As+TM*TKSW);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){ mbar_expect_tx(bar,(uint32_t)(TM*TKSW*2)); tma_load_2d(As,&tmapA,0,0,bar); }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    for(int p=tid;p<TM*TKSW;p+=blockDim.x) gOut[p]=__half2float(As[p]);
}
// ======================================================================
// MODE 3 — RAW B-DUMP: f16 B 64(N)x16(K) box layout. contiguous=N (box {64,16}).
// ======================================================================
extern "C" __global__ void dump_b16(const __grid_constant__ CUtensorMap tmapB,
                                     float* __restrict__ gOut,int nfloat){
    extern __shared__ __align__(128) __half sm[];
    __half* Bs=sm; uint64_t* bar=(uint64_t*)(Bs+nfloat);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){ mbar_expect_tx(bar,(uint32_t)(nfloat*2)); tma_load_2d(Bs,&tmapB,0,0,bar); }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    for(int p=tid;p<nfloat;p+=blockDim.x) gOut[p]=__half2float(Bs[p]);
}

// ======================================================================
// MODE 0 — COMPOSED-DECODE PROBE (the W14 GATE 1). f16 128x64 tile.
//   For every logical (m,k): swizzled slot a*512 + sw128_f16(m&7,k) (atom-major, 8 rows x
//   64 f16 = 512 f16/atom) must hold the global value at (m,k). f16 round-trip is exact
//   (we materialize global directly in f16), so rel_rms must be 0.
// ======================================================================
extern "C" __global__ void probe_decode16(const __grid_constant__ CUtensorMap tmapA,
                                           const __half* __restrict__ gAref,
                                           float* __restrict__ gOutSw, float* __restrict__ gOutGm,
                                           int M,int K){
    const int TM=128, TKSW=64;
    extern __shared__ __align__(128) __half sm[];
    __half* As=sm; uint64_t* bar=(uint64_t*)(As + TM*TKSW);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){ mbar_expect_tx(bar,(uint32_t)(TM*TKSW*2)); tma_load_2d(As,&tmapA,0,0,bar); }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    for(int i=tid;i<TM*TKSW;i+=blockDim.x){
        int m=i/TKSW, k=i%TKSW;
        int a=m>>3, r=m&7;
        int sw_phys = a*512 + sw128_f16(r,k);          // atom-major: 8*64=512 f16/atom
        gOutSw[i] = __half2float(As[sw_phys]);
        gOutGm[i] = __half2float(gAref[m*K + k]);
    }
}

// ======================================================================
// MODE 1 — COMPOSED single-tile wgmma m64n64k16 f16 probe (the W14 GATE 2).
//   Decode A(64x16)+B(16x64) from SWIZZLE_128B tiles into gmma INTER, run one wgmma,
//   rel_rms vs same-dtype (f16 operands, f64 host accumulate) oracle.
// ======================================================================
extern "C" __global__ void probe_wgmma16(const __grid_constant__ CUtensorMap tmapA,
                                          const __grid_constant__ CUtensorMap tmapB,
                                          float* __restrict__ gD,int M,int N,int K){
    const int TM=64, TN=64, TKSW=64;   // TMA tile K is one 64-f16 atom (use first 16 K cols)
    extern __shared__ __align__(128) __half sm[];
    __half* Asw=sm;                       // swizzled A 64x64
    __half* Bsw=Asw + TM*TKSW;            // swizzled B atom: 64(N) x 64(K) (use first 16 K)
    __half* Ag =Bsw + TN*TKSW;            // gmma-laid A 64x16
    __half* Bg =Ag  + TM*16;              // gmma-laid B 16x64
    uint64_t* bar=(uint64_t*)(Bg + 16*TN);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        uint32_t bytes = (uint32_t)((TM*TKSW + TN*TKSW)*2);
        mbar_expect_tx(bar,bytes);
        tma_load_2d(Asw,&tmapA,0,0,bar);
        tma_load_2d(Bsw,&tmapB,0,0,bar);   // B atom: N 0..63 (box {64(N),64(K)} use first 16 K)
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    const int KCORES=16/8;   // K-tile=16 -> 2 cores of 8
    // COMPOSED decode A: logical (m 0..63, k 0..15). atom a=m>>3, r=m&7.
    for(int i=tid;i<TM*16;i+=blockDim.x){
        int m=i/16, k=i%16;
        int a=m>>3, r=m&7;
        int sw_phys = a*512 + sw128_f16(r,k);
        Ag[gmma_phys16(m,k,KCORES)] = Asw[sw_phys];
    }
    // COMPOSED decode B: logical (k 0..15, n 0..63). box {64(N),64(K)}: physical row=k,
    // within row N-granule gp holds logical n-granule (gp XOR (k&7)). (re-measured MODE3.)
    for(int i=tid;i<16*TN;i+=blockDim.x){
        int k=i/TN, n=i%TN;
        int gN=n>>3, w=n&7, gp=gN^(k&7);
        int sw_phys = k*64 + gp*8 + w;
        Bg[gmma_phys16(n,k,KCORES)] = Bsw[sw_phys];
    }
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
    uint32_t aA=(uint32_t)__cvta_generic_to_shared(Ag);
    uint32_t aB=(uint32_t)__cvta_generic_to_shared(Bg);
    uint64_t dA=mk(aA,128,256), dB=mk(aB,128,256);
    float d[32];
    #pragma unroll
    for(int i=0;i<32;++i)d[i]=0.f;
    asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
    WG16(d,dA,dB);
    asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
    // n64 output layout: 8 col-groups x (2 rows x 2 cols).
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
        if(row<64&&col<64)gD[row*64+col]=d[idx];
    }
}

// ======================================================================
// MODE 7 — BF16 single-tile wgmma m64n64k16 probe (gate). Same decode as f16 (bf16 is also
//   2-byte, SWIZZLE_128B granule = 8 elems, identical layout law) -> .f32.bf16.bf16.
// ======================================================================
extern "C" __global__ void probe_wgmma_bf16(const __grid_constant__ CUtensorMap tmapA,
                                            const __grid_constant__ CUtensorMap tmapB,
                                            float* __restrict__ gD,int M,int N,int K){
    const int TM=64, TN=64, TKSW=64;
    extern __shared__ __align__(128) __nv_bfloat16 sm[];
    __nv_bfloat16* Asw=sm;
    __nv_bfloat16* Bsw=Asw + TM*TKSW;
    __nv_bfloat16* Ag =Bsw + TN*TKSW;
    __nv_bfloat16* Bg =Ag  + TM*16;
    uint64_t* bar=(uint64_t*)(Bg + 16*TN);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        uint32_t bytes = (uint32_t)((TM*TKSW + TN*TKSW)*2);
        mbar_expect_tx(bar,bytes);
        tma_load_2d(Asw,&tmapA,0,0,bar);
        tma_load_2d(Bsw,&tmapB,0,0,bar);
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    const int KCORES=16/8;
    for(int i=tid;i<TM*16;i+=blockDim.x){
        int m=i/16, k=i%16; int a=m>>3, r=m&7;
        Ag[gmma_phys16(m,k,KCORES)] = Asw[a*512 + sw128_f16(r,k)];
    }
    for(int i=tid;i<16*TN;i+=blockDim.x){
        int k=i/TN, n=i%TN; int gN=n>>3, w=n&7, gp=gN^(k&7);
        Bg[gmma_phys16(n,k,KCORES)] = Bsw[k*64 + gp*8 + w];
    }
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
    uint32_t aA=(uint32_t)__cvta_generic_to_shared(Ag);
    uint32_t aB=(uint32_t)__cvta_generic_to_shared(Bg);
    uint64_t dA=mk(aA,128,256), dB=mk(aB,128,256);
    float d[32];
    #pragma unroll
    for(int i=0;i<32;++i)d[i]=0.f;
    asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
    WGBF(d,dA,dB);
    asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
        if(row<64&&col<64)gD[row*64+col]=d[idx];
    }
}

// ======================================================================
// MODE 4 — FULL GEMM gemm_f16_w14 (W10 geometry, SINGLE gmma band).
//   TM=128, TN=128, K-slab TKSW=64 (one f16 128B atom = 64 K) -> 4 wgmma k16 sub-steps.
//   256 thr = 2 consumer warpgroups + 1 elected TMA producer. The per-slab decode is the
//   composed f16 index (proven bit-exact in MODE 0/1). gmma scratch is a SINGLE shared band
//   (W10's 2-CTA/SM design). 16-bit halves the band bytes vs TF32.
// ======================================================================
extern "C" __global__ void gemm_f16_w14(const __grid_constant__ CUtensorMap tmapA,
                                        const __grid_constant__ CUtensorMap tmapB,
                                        float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=128,TKSW=64,TK=16;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) __half sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;          // swizzled landings (f16, ring NST-deep)
    const int ABND=64*TKSW, BB=TKSW*64;           // gmma-laid bands (single)
    const int SWBUF=ASW+BSW;
    const int GMMA=2*ABND+2*BB;
    __half* gmma=sm + (size_t)NST*SWBUF;
    // mbar must be 8-byte aligned: place after gmma (gmma count is even -> 16B aligned).
    uint64_t* full =(uint64_t*)(gmma + GMMA);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;                       // 2 side-by-side 64-N B atoms
    const uint32_t bytesA=ASW*2, bytesB=BSW*2;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();
    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    uint32_t fph=0;
    int stages=NST<nks?NST:nks;
    if(tid==0){
        for(int st=0;st<stages;++st){
            __half* base=sm+(size_t)st*SWBUF; __half* Asw=base; __half* Bsw=base+ASW;
            mbar_expect_tx(&full[st], bytesA+bytesB);
            tma_load_2d(Asw,&tmapA,/*x=k*/st*TKSW,/*y=m*/bm,&full[st]);
            #pragma unroll
            for(int c=0;c<NATOM;++c)
                tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,/*x=n*/bn+c*TKSW,/*y=k*/st*TKSW,&full[st]);
        }
    }
    __half* As0=gmma; __half* As1=As0+ABND; __half* B0=As1+ABND; __half* B1=B0+BB;
    const int KCORES=TK/8;  // 2 cores per k16 sub-step
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        __half* base=sm+(size_t)st*SWBUF;
        __half* Asw=base; __half* Bsw=base+ASW;
        // A decode: logical (m 0..127, k 0..63). 4 k16 sub-tiles; each sub = 64x16 gmma tile.
        for(int i=tid;i<TM*TKSW;i+=256){
            int m=i/TKSW, k=i%TKSW;
            int a=m>>3, r=m&7;
            __half v=Asw[a*512 + sw128_f16(r,k)];
            int sub=k>>4, kk=k&15, mm=(m&63);
            __half* dst=(m<64)?As0:As1;
            dst[sub*(64*16) + gmma_phys16(mm,kk,KCORES)]=v;
        }
        // B decode: logical (k 0..63, n 0..127). atom c=n>>6, nn=n&63, gp=(nn>>3)^(k&7).
        for(int i=tid;i<TKSW*TN;i+=256){
            int k=i/TN, n=i%TN;
            int c=n>>6, nn=n&63, gp=(nn>>3)^(k&7);
            __half v=Bsw[c*(TKSW*64) + k*64 + gp*8 + (nn&7)];
            int sub=k>>4, kk=k&15, nnn=(n&63);
            __half* dst=(n<64)?B0:B1;
            dst[sub*(64*16) + gmma_phys16(nnn,kk,KCORES)]=v;
        }
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        __half* As=(band==0)?As0:As1;
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0), a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            // each k16 sub-tile = 64x16 gmma tile = 1024 f16 = 2048 bytes. START bumps by sub.
            uint32_t off=(uint32_t)((kk>>4)*1024*2);
            uint64_t dA=mk(aAb+off,128,256), dB0=mk(a0b+off,128,256), dB1=mk(a1b+off,128,256);
            WG16(d0,dA,dB0);
            WG16(d1,dA,dB1);
        }
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
        if(tid==0){
            int load_ki=ki+stages;
            if(load_ki<nks){
                int lst=load_ki%NST;
                __half* lb=sm+(size_t)lst*SWBUF; __half* lAsw=lb; __half* lBsw=lb+ASW;
                mbar_expect_tx(&full[lst], bytesA+bytesB);
                tma_load_2d(lAsw,&tmapA,load_ki*TKSW,bm,&full[lst]);
                #pragma unroll
                for(int c=0;c<NATOM;++c)
                    tma_load_2d(lBsw+(size_t)c*(TKSW*64),&tmapB,bn+c*TKSW,load_ki*TKSW,&full[lst]);
            }
        }
    }
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rbase+rb+r*8;
        int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
        if(row<M&&col0<N)gD[row*N+col0]=d0[idx];
        if(row<M&&col1<N)gD[row*N+col1]=d1[idx];
    }
}

// ======================================================================
// MODE 6 — FULL GEMM gemm_f16_w14_ring: the W13 DEEP-ASYNC overlap REOPENED at 2 CTA/SM.
//   gmma decode band ring NSTG-deep (each band = As0/As1/B0/B1). At 16-bit a band is 16 KB,
//   so NSTG=2 = 32 KB of bands fits at 2 CTA/SM (the TF32 wall: 2*32KB=64KB did not). The
//   producer decodes the FUTURE slab into its band BEFORE issuing the current wgmma -> overlap.
// ======================================================================
extern "C" __global__ void gemm_f16_w14_ring(const __grid_constant__ CUtensorMap tmapA,
                                             const __grid_constant__ CUtensorMap tmapB,
                                             float* __restrict__ gD,int M,int N,int K,int NST,int NSTG){
    const int TM=128,TN=128,TKSW=64,TK=16;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) __half sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int ABND=64*TKSW, BB=TKSW*64;
    const int SWBUF=ASW+BSW;
    const int GBND=2*ABND+2*BB;                    // one gmma band
    __half* gmma=sm + (size_t)NST*SWBUF;           // NSTG bands ring here
    uint64_t* full =(uint64_t*)(gmma + (size_t)NSTG*GBND);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;
    const uint32_t bytesA=ASW*2, bytesB=BSW*2;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();
    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    uint32_t fph=0;
    int stages=NST<nks?NST:nks;
    const int KCORES=TK/8;
    // TMA prologue: fill NST swizzled stages.
    if(tid==0){
        for(int st=0;st<stages;++st){
            __half* base=sm+(size_t)st*SWBUF; __half* Asw=base; __half* Bsw=base+ASW;
            mbar_expect_tx(&full[st], bytesA+bytesB);
            tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
            #pragma unroll
            for(int c=0;c<NATOM;++c)
                tma_load_2d(Bsw+(size_t)c*(TKSW*64),&tmapB,bn+c*TKSW,st*TKSW,&full[st]);
        }
    }
    // decode the swizzled stage `ki` into gmma band `gi` (all threads).
    auto decode=[&](int ki,int gi){
        int st=ki%NST;
        __half* base=sm+(size_t)st*SWBUF; __half* Asw=base; __half* Bsw=base+ASW;
        __half* g=gmma+(size_t)gi*GBND;
        __half* As0=g; __half* As1=As0+ABND; __half* B0=As1+ABND; __half* B1=B0+BB;
        for(int i=tid;i<TM*TKSW;i+=256){
            int m=i/TKSW, k=i%TKSW; int a=m>>3, r=m&7;
            __half v=Asw[a*512 + sw128_f16(r,k)];
            int sub=k>>4, kk=k&15, mm=(m&63);
            __half* dst=(m<64)?As0:As1;
            dst[sub*(64*16) + gmma_phys16(mm,kk,KCORES)]=v;
        }
        for(int i=tid;i<TKSW*TN;i+=256){
            int k=i/TN, n=i%TN; int c=n>>6, nn=n&63, gp=(nn>>3)^(k&7);
            __half v=Bsw[c*(TKSW*64) + k*64 + gp*8 + (nn&7)];
            int sub=k>>4, kk=k&15, nnn=(n&63);
            __half* dst=(n<64)?B0:B1;
            dst[sub*(64*16) + gmma_phys16(nnn,kk,KCORES)]=v;
        }
    };
    // PROLOGUE: decode the first (NSTG-1) slabs into bands 0..NSTG-2.
    int gprol = (NSTG-1<nks)?NSTG-1:nks;
    for(int j=0;j<gprol;++j){
        int st=j%NST;
        mbar_wait(&full[st], (j/NST)&0?1:0);  // wait on stage j's TMA (phase via j)
    }
    // (simpler: wait per-slab inside the loop). Reset: do prologue decodes after waiting.
    // We re-issue cleanly below; the loop handles waits. Mark prologue bands filled.
    for(int j=0;j<gprol;++j) decode(j, j%NSTG);
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
    for(int ki=0;ki<nks;++ki){
        // PRODUCER half: decode FUTURE slab ki+(NSTG-1) into its band (different from consumer).
        int fki=ki+(NSTG-1);
        if(fki<nks){
            int fst=fki%NST;
            mbar_wait(&full[fst], (fki/NST)&1); // ensure its TMA landed
            decode(fki, fki%NSTG);
        }
        // CONSUMER half: wgmma on slab ki from band ki%NSTG.
        __half* g=gmma+(size_t)(ki%NSTG)*GBND;
        __half* As0=g; __half* As1=As0+ABND; __half* B0=As1+ABND; __half* B1=B0+BB;
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        __half* As=(band==0)?As0:As1;
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0), a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>4)*1024*2);
            uint64_t dA=mk(aAb+off,128,256), dB0=mk(a0b+off,128,256), dB1=mk(a1b+off,128,256);
            WG16(d0,dA,dB0);
            WG16(d1,dA,dB1);
        }
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
        // TMA the next swizzled stage.
        if(tid==0){
            int load_ki=ki+stages;
            if(load_ki<nks){
                int lst=load_ki%NST;
                __half* lb=sm+(size_t)lst*SWBUF; __half* lAsw=lb; __half* lBsw=lb+ASW;
                mbar_expect_tx(&full[lst], bytesA+bytesB);
                tma_load_2d(lAsw,&tmapA,load_ki*TKSW,bm,&full[lst]);
                #pragma unroll
                for(int c=0;c<NATOM;++c)
                    tma_load_2d(lBsw+(size_t)c*(TKSW*64),&tmapB,bn+c*TKSW,load_ki*TKSW,&full[lst]);
            }
        }
    }
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rbase+rb+r*8;
        int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
        if(row<M&&col0<N)gD[row*N+col0]=d0[idx];
        if(row<M&&col1<N)gD[row*N+col1]=d1[idx];
    }
}

// ======================================================================
// MODE 8 — BF16 FULL GEMM gemm_bf16_w14 (single band; identical structure to MODE 4).
// ======================================================================
extern "C" __global__ void gemm_bf16_w14(const __grid_constant__ CUtensorMap tmapA,
                                         const __grid_constant__ CUtensorMap tmapB,
                                         float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=128,TKSW=64,TK=16;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) __nv_bfloat16 sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int ABND=64*TKSW, BB=TKSW*64;
    const int SWBUF=ASW+BSW;
    const int GMMA=2*ABND+2*BB;
    __nv_bfloat16* gmma=sm + (size_t)NST*SWBUF;
    uint64_t* full =(uint64_t*)(gmma + GMMA);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;
    const uint32_t bytesA=ASW*2, bytesB=BSW*2;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();
    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    uint32_t fph=0;
    int stages=NST<nks?NST:nks;
    const int KCORES=TK/8;
    if(tid==0){
        for(int st=0;st<stages;++st){
            __nv_bfloat16* base=sm+(size_t)st*SWBUF; __nv_bfloat16* Asw=base; __nv_bfloat16* Bsw=base+ASW;
            mbar_expect_tx(&full[st], bytesA+bytesB);
            tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
            #pragma unroll
            for(int c=0;c<NATOM;++c)
                tma_load_2d(Bsw+(size_t)c*(TKSW*64),&tmapB,bn+c*TKSW,st*TKSW,&full[st]);
        }
    }
    __nv_bfloat16* As0=gmma; __nv_bfloat16* As1=As0+ABND; __nv_bfloat16* B0=As1+ABND; __nv_bfloat16* B1=B0+BB;
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        __nv_bfloat16* base=sm+(size_t)st*SWBUF;
        __nv_bfloat16* Asw=base; __nv_bfloat16* Bsw=base+ASW;
        for(int i=tid;i<TM*TKSW;i+=256){
            int m=i/TKSW, k=i%TKSW; int a=m>>3, r=m&7;
            __nv_bfloat16 v=Asw[a*512 + sw128_f16(r,k)];
            int sub=k>>4, kk=k&15, mm=(m&63);
            __nv_bfloat16* dst=(m<64)?As0:As1;
            dst[sub*(64*16) + gmma_phys16(mm,kk,KCORES)]=v;
        }
        for(int i=tid;i<TKSW*TN;i+=256){
            int k=i/TN, n=i%TN; int c=n>>6, nn=n&63, gp=(nn>>3)^(k&7);
            __nv_bfloat16 v=Bsw[c*(TKSW*64) + k*64 + gp*8 + (nn&7)];
            int sub=k>>4, kk=k&15, nnn=(n&63);
            __nv_bfloat16* dst=(n<64)?B0:B1;
            dst[sub*(64*16) + gmma_phys16(nnn,kk,KCORES)]=v;
        }
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        __nv_bfloat16* As=(band==0)?As0:As1;
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0), a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>4)*1024*2);
            uint64_t dA=mk(aAb+off,128,256), dB0=mk(a0b+off,128,256), dB1=mk(a1b+off,128,256);
            WGBF(d0,dA,dB0);
            WGBF(d1,dA,dB1);
        }
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
        if(tid==0){
            int load_ki=ki+stages;
            if(load_ki<nks){
                int lst=load_ki%NST;
                __nv_bfloat16* lb=sm+(size_t)lst*SWBUF; __nv_bfloat16* lAsw=lb; __nv_bfloat16* lBsw=lb+ASW;
                mbar_expect_tx(&full[lst], bytesA+bytesB);
                tma_load_2d(lAsw,&tmapA,load_ki*TKSW,bm,&full[lst]);
                #pragma unroll
                for(int c=0;c<NATOM;++c)
                    tma_load_2d(lBsw+(size_t)c*(TKSW*64),&tmapB,bn+c*TKSW,load_ki*TKSW,&full[lst]);
            }
        }
    }
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rbase+rb+r*8;
        int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
        if(row<M&&col0<N)gD[row*N+col0]=d0[idx];
        if(row<M&&col1<N)gD[row*N+col1]=d1[idx];
    }
}

typedef CUresult (*Enc_t)(CUtensorMap*,CUtensorMapDataType,cuuint32_t,void*,
    const cuuint64_t*,const cuuint64_t*,const cuuint32_t*,const cuuint32_t*,
    CUtensorMapInterleave,CUtensorMapSwizzle,CUtensorMapL2promotion,CUtensorMapFloatOOBfill);
static Enc_t get_enc(){
    void* fn=nullptr; cudaDriverEntryPointQueryResult q;
    cudaGetDriverEntryPoint("cuTensorMapEncodeTiled",&fn,cudaEnableDefault,&q);
    return (Enc_t)fn;
}

// host f16 round-trip (mimic GPU operand rounding).
static inline float h16(float x){ return __half2float(__float2half(x)); }
static inline float hbf(float x){ return __bfloat162float(__float2bfloat16(x)); }

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):0;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}

    if(MODE==0){
        // f16 composed-decode gate. A 128x64 f16, box {64(K),128(M)} SWIZZLE_128B.
        const int M=128,K=64;
        __half* hA=(__half*)malloc((size_t)M*K*2);
        srand(7);
        for(int i=0;i<M*K;++i)hA[i]=__float2half(((rand()%17)-8)*0.0625f);
        __half *dA; float *dOsw,*dOgm;
        CK(cudaMalloc(&dA,(size_t)M*K*2));
        CK(cudaMalloc(&dOsw,(size_t)M*K*4)); CK(cudaMalloc(&dOgm,(size_t)M*K*4));
        CK(cudaMemcpy(dA,hA,(size_t)M*K*2,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{};
        cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)K*2};
        cuuint32_t bd[2]={64,128}; cuuint32_t es[2]={1,1};
        CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT16,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("MODE0 encodeA r=%d\n",(int)r);return 4;}
        size_t smsz=(size_t)(M*K)*2 + 8;
        CK(cudaFuncSetAttribute(probe_decode16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        CK(cudaMemset(dOsw,0,(size_t)M*K*4)); CK(cudaMemset(dOgm,0,(size_t)M*K*4));
        probe_decode16<<<1,128,smsz>>>(tmapA,dA,dOsw,dOgm,M,K);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE0 FAULT %s\n",cudaGetErrorString(e));return 4;}
        float* hOsw=(float*)malloc((size_t)M*K*4); float* hOgm=(float*)malloc((size_t)M*K*4);
        CK(cudaMemcpy(hOsw,dOsw,(size_t)M*K*4,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(hOgm,dOgm,(size_t)M*K*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0; int exact=0; for(int i=0;i<M*K;++i){double dd=(double)hOsw[i]-hOgm[i];se+=dd*dd;sr+=(double)hOgm[i]*hOgm[i]; if(fabs(dd)<1e-6)exact++;}
        double rr=sqrt(se/fmax(1e-30,sr));
        printf("W14-F16 MODE=0 composed-decode: exact=%d/%d rel_rms=%.3e %s\n",
               exact,M*K,rr, rr<=1e-3?"PASS (f16 composed law recovers swizzled tile)":"FAIL");
        return rr<=1e-3?0:2;
    }
    if(MODE==2){
        // RAW A-DUMP: f16 128x64 SWIZZLE_128B landed layout (unique id m*64+k).
        const int M=128,K=64;
        __half* hA=(__half*)malloc((size_t)M*K*2);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k)hA[m*K+k]=__float2half((float)(m*64+k));
        __half* dA; float* dO; CK(cudaMalloc(&dA,(size_t)M*K*2)); CK(cudaMalloc(&dO,(size_t)M*K*4));
        CK(cudaMemcpy(dA,hA,(size_t)M*K*2,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{};
        cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)K*2};
        cuuint32_t bd[2]={64,128}; cuuint32_t es[2]={1,1};
        CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT16,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("MODE2 encodeA r=%d\n",(int)r);return 4;}
        size_t smsz=(size_t)(M*K)*2 + 8;
        CK(cudaFuncSetAttribute(dump_a16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        dump_a16<<<1,128,smsz>>>(tmapA,dO,M,K);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE2 FAULT %s\n",cudaGetErrorString(e));return 4;}
        float* hO=(float*)malloc((size_t)M*K*4);
        CK(cudaMemcpy(hO,dO,(size_t)M*K*4,cudaMemcpyDeviceToHost));
        printf("W14-F16-ADUMP 128x64 SWIZZLE_128B (phys slot -> landed m*64+k), atom0/atom1:\n");
        for(int atom=0;atom<2;++atom){
            printf("--- atom %d (phys rows %d..%d) ---\n",atom,atom*8,atom*8+7);
            for(int pr=0;pr<8;++pr){
                printf("pr=%d: ",pr);
                for(int pg=0;pg<8;++pg){ int p=atom*512+pr*64+pg*8; int id=(int)hO[p]; printf("[g%d:m%d,k%d] ",pg,id/64,id%64); }
                printf("\n");
            }
        }
        printf("--- atom0 granule XOR-mask (landed_k_granule XOR phys_granule) per row ---\n");
        for(int pr=0;pr<8;++pr){ printf("pr=%d: ",pr);
            for(int pg=0;pg<8;++pg){int p=pr*64+pg*8;int id=(int)hO[p];int k=id%64;printf("%d ",(k>>3)^pg);} printf("\n"); }
        return 0;
    }
    if(MODE==3){
        // RAW B-DUMP: f16 B 64(N)x16(K) box {64(N),16(K)}, contiguous=N. global B[k][n]=k*64+n.
        const int KK=16, NN=64;
        __half* hB=(__half*)malloc((size_t)KK*NN*2);
        for(int k=0;k<KK;++k)for(int n=0;n<NN;++n)hB[k*NN+n]=__float2half((float)(k*64+n));
        __half* dB; float* dO; CK(cudaMalloc(&dB,(size_t)KK*NN*2)); CK(cudaMalloc(&dO,(size_t)KK*NN*4));
        CK(cudaMemcpy(dB,hB,(size_t)KK*NN*2,cudaMemcpyHostToDevice));
        CUtensorMap tmapB{};
        cuuint64_t gd[2]={(cuuint64_t)NN,(cuuint64_t)KK}; cuuint64_t gs[1]={(cuuint64_t)NN*2};
        cuuint32_t bd[2]={64,16}; cuuint32_t es[2]={1,1};
        CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT16,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("MODE3 encodeB r=%d\n",(int)r);return 4;}
        size_t smsz=(size_t)(KK*NN)*2 + 8;
        CK(cudaFuncSetAttribute(dump_b16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        dump_b16<<<1,128,smsz>>>(tmapB,dO,KK*NN);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE3 FAULT %s\n",cudaGetErrorString(e));return 4;}
        float* hO=(float*)malloc((size_t)KK*NN*4);
        CK(cudaMemcpy(hO,dO,(size_t)KK*NN*4,cudaMemcpyDeviceToHost));
        printf("W14-F16-BDUMP 64(N)x16(K) SWIZZLE_128B (phys slot -> landed k*64+n):\n");
        for(int pr=0;pr<8;++pr){ printf("pr=%d(k=%d): ",pr,pr);
            for(int pg=0;pg<8;++pg){ int p=pr*64+pg*8; int id=(int)hO[p]; printf("[g%d:k%d,n%d] ",pg,id/64,id%64); }
            printf("\n");
        }
        return 0;
    }
    if(MODE==1||MODE==7){
        // single-tile wgmma probe (f16 MODE1 / bf16 MODE7). m64n64k16, K=16.
        const int M=64,N=64,K=16,KSW=64;
        bool bf = (MODE==7);
        float *hAf=(float*)malloc((size_t)M*K*4),*hBf=(float*)malloc((size_t)K*N*4);
        float *hD=(float*)malloc((size_t)M*N*4),*hR=(float*)malloc((size_t)M*N*4);
        srand(3);
        // operands rounded to the target dtype EXACTLY as the GPU sees them (same-dtype oracle).
        for(int i=0;i<M*K;++i){float v=((rand()%17)-8)*0.125f; hAf[i]= bf?hbf(v):h16(v);}
        for(int i=0;i<K*N;++i){float v=((rand()%17)-8)*0.125f; hBf[i]= bf?hbf(v):h16(v);}
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){double a=0;for(int kk=0;kk<K;++kk)a+=(double)hAf[m*K+kk]*hBf[kk*N+n];hR[m*N+n]=(float)a;}
        size_t esz = 2; // both f16 and bf16 are 2 bytes
        void *dA,*dB; float* dD;
        // pad A to M x KSW, B to KSW(rows used K) x N in the dtype.
        char* hApad=(char*)calloc((size_t)M*KSW,esz); char* hBpad=(char*)calloc((size_t)K*N,esz);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k){ if(bf)((__nv_bfloat16*)hApad)[m*KSW+k]=__float2bfloat16(hAf[m*K+k]); else ((__half*)hApad)[m*KSW+k]=__float2half(hAf[m*K+k]); }
        for(int k=0;k<K;++k)for(int n=0;n<N;++n){ if(bf)((__nv_bfloat16*)hBpad)[k*N+n]=__float2bfloat16(hBf[k*N+n]); else ((__half*)hBpad)[k*N+n]=__float2half(hBf[k*N+n]); }
        CK(cudaMalloc(&dA,(size_t)M*KSW*esz));CK(cudaMalloc(&dB,(size_t)K*N*esz));CK(cudaMalloc(&dD,(size_t)M*N*4));
        CK(cudaMemcpy(dA,hApad,(size_t)M*KSW*esz,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB,hBpad,(size_t)K*N*esz,cudaMemcpyHostToDevice));
        CK(cudaMemset(dD,0,(size_t)M*N*4));
        CUtensorMapDataType dt = bf?CU_TENSOR_MAP_DATA_TYPE_BFLOAT16:CU_TENSOR_MAP_DATA_TYPE_FLOAT16;
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)KSW,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)KSW*esz};
          cuuint32_t bd[2]={64,64}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,dt,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE%d encodeA r=%d\n",MODE,(int)r);return 4;} }
        // B box {64(N),16(K)} -> but TMA tile must be {64,64} K-atom? B has only K=16 rows.
        // box {64(N),16(K)}: contiguous N=64 == atom, 16 K rows.
        { cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)K}; cuuint64_t gs[1]={(cuuint64_t)N*esz};
          cuuint32_t bd[2]={64,16}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,dt,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE%d encodeB r=%d\n",MODE,(int)r);return 4;} }
        size_t smsz=(size_t)(M*KSW + N*KSW + M*16 + 16*N)*esz + 16;
        if(bf){
            CK(cudaFuncSetAttribute(probe_wgmma_bf16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
            probe_wgmma_bf16<<<1,128,smsz>>>(tmapA,tmapB,dD,M,N,K);
        } else {
            CK(cudaFuncSetAttribute(probe_wgmma16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
            probe_wgmma16<<<1,128,smsz>>>(tmapA,tmapB,dD,M,N,K);
        }
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE%d FAULT %s\n",MODE,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;int exact=0;for(int i=0;i<M*N;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];if(fabs(dd)<1e-2*fmax(1.0,fabs(hR[i])))exact++;}
        double rr=sqrt(se/fmax(1e-30,sr));
        printf("W14-%s MODE=%d composed-wgmma: exact=%d/%d rel_rms=%.3e %s (tol 1e-2, same-dtype oracle)\n",
               bf?"BF16":"F16",MODE,exact,M*N,rr, rr<=1e-2?"PASS (composed decode feeds wgmma)":"FAIL");
        return rr<=1e-2?0:2;
    }
    if(MODE==4||MODE==6||MODE==8){
        // FULL GEMM. MODE4=f16 single band, MODE6=f16 deep-async ring, MODE8=bf16 single band.
        int NST=argc>3?atoi(argv[3]):3;
        int NSTG=argc>4?atoi(argv[4]):2;
        bool bf=(MODE==8);
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%64){printf("MODE%d needs N%%128==0 && K%%64==0\n",MODE);return 1;}
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        // host operands rounded to dtype; same-dtype CPU-equivalent reference = cuBLAS same-dtype.
        char* hA=(char*)malloc(szA*2); char* hB=(char*)malloc(szB*2);
        float* hD=(float*)malloc(szD*4); float* hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i){float v=((rand()%17)-8)*0.0625f; if(bf)((__nv_bfloat16*)hA)[i]=__float2bfloat16(v); else ((__half*)hA)[i]=__float2half(v);}
        for(size_t i=0;i<szB;++i){float v=((rand()%17)-8)*0.0625f; if(bf)((__nv_bfloat16*)hB)[i]=__float2bfloat16(v); else ((__half*)hB)[i]=__float2half(v);}
        void *dA,*dB; float *dD,*dR;
        CK(cudaMalloc(&dA,szA*2));CK(cudaMalloc(&dB,szB*2));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        CK(cudaMemcpy(dA,hA,szA*2,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,szB*2,cudaMemcpyHostToDevice));
        // SAME-DTYPE cuBLAS reference (roofline + correctness oracle): cublasGemmEx f16/bf16 in,
        // f32 compute. CUBLAS_COMPUTE_32F = the same f32-accumulate the wgmma does.
        cublasHandle_t h;CB(cublasCreate(&h));
        float al=1.f,be=0.f;
        cudaDataType_t ctype = bf?CUDA_R_16BF:CUDA_R_16F;
        CB(cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,ctype,Nx,dA,ctype,Kx,&be,dR,CUDA_R_32F,Nx,
                        CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        CUtensorMapDataType dt = bf?CU_TENSOR_MAP_DATA_TYPE_BFLOAT16:CU_TENSOR_MAP_DATA_TYPE_FLOAT16;
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*2};
          cuuint32_t bd[2]={64,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,dt,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE%d encodeA r=%d\n",MODE,(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*2};
          cuuint32_t bd[2]={64,64}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,dt,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE%d encodeB r=%d\n",MODE,(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=64;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t GBND=(size_t)(2*64*TKSW + 2*TKSW*64);
        dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
        size_t smsz; const void* fn; const char* tag;
        if(MODE==4){ smsz=(size_t)NST*SWBUF*2 + GBND*2 + (size_t)NST*8; fn=(const void*)gemm_f16_w14; tag="F16-SINGLE"; }
        else if(MODE==8){ smsz=(size_t)NST*SWBUF*2 + GBND*2 + (size_t)NST*8; fn=(const void*)gemm_bf16_w14; tag="BF16-SINGLE"; }
        else { smsz=(size_t)NST*SWBUF*2 + (size_t)NSTG*GBND*2 + (size_t)NST*8; fn=(const void*)gemm_f16_w14_ring; tag="F16-RING"; }
        CK(cudaFuncSetAttribute(fn,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){
            if(MODE==4) gemm_f16_w14<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST);
            else if(MODE==8) gemm_bf16_w14<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST);
            else gemm_f16_w14_ring<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,NSTG);
        };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,fn,blk,smsz);
          printf("OCCUPANCY %s MODE=%d NST=%d NSTG=%d blk=%d dynsmem=%zuB (%.1f KB) -> %d CTA/SM (%d compute-thr/SM)\n",
                 tag,MODE,NST,NSTG,blk,smsz,smsz/1024.0,occ,occ*blk); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE%d OWN-FAULT %s\n",MODE,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        // K-scaled tolerance: ~ sqrt(K)*eps; gate at 1e-2 (generous for f16, tighter bf16 too).
        double tol=1e-2;
        if(rr>tol){printf("W14-%s S=%d MODE=%d NST=%d NSTG=%d rel_rms=%.3e FAIL (tol %.0e, same-dtype cuBLAS oracle) — no perf (g5)\n",tag,S,MODE,NST,NSTG,rr,tol);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        // SAME-DTYPE cuBLAS roofline timing.
        cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,ctype,Nx,dA,ctype,Kx,&be,dR,CUDA_R_32F,Nx,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,ctype,Nx,dA,ctype,Kx,&be,dR,CUDA_R_32F,Nx,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        const char* dtag = bf?"cuBLAS-BF16":"cuBLAS-FP16";
        printf("W14-%s S=%d MODE=%d NST=%d NSTG=%d own=%.1f TFLOP/s %s=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e (tol %.0e same-dtype) PARITY=%s\n",
               tag,S,MODE,NST,NSTG,tfo,dtag,tfc,ratio,rr,tol,ratio<=1.3?"YES":"NO");
        return 0;
    }
    printf("unknown MODE %d\n",MODE); return 1;
}
