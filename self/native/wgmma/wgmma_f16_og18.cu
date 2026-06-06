// wgmma_f16_og18.cu — OG18: port the OG16 canonical-atom + OG17 relaxed-pipeline PARITY recipe
// (which took TF32 own-GEMM 6.09x -> 1.24x = cuBLAS-TF32 PARITY) to FP16/BF16, to close the
// OG14/W14 FP16 gap (11.5x off cuBLAS-FP16).
//
// ============================ THE OG14/W14 FP16 WALL (the thing OG18 attacks) =================
//   OG14 (#2853, F-FUSION-SM90-WGMMA-W14) ported the W10 COMPOSED-SOFTWARE-DECODE own-GEMM to
//   f16/bf16 (f32 accumulate). It was CORRECT (single-tile + full rel_rms 0, same-dtype) but
//   STALLED at 71-76 TFLOP/s = 11.5x off cuBLAS-FP16, WORSE same-dtype ratio than TF32's 6.09x.
//   ROOT CAUSE (verdict, verbatim): f16 wgmma is .k16 (TF32 is .k8), so a natural K-slab is
//   64-wide (one 128B f16 atom) and the IN-KERNEL gmma decode band holds 2x the K-elements ->
//   32 KB, the SAME KB as the TF32 32-KB band (2 bytes x 2x elements = NO byte savings). The
//   own kernel stayed decode/occupancy-bound at ~71-76 while the cuBLAS-FP16 roofline DOUBLED
//   (827 vs cuBLAS-TF32 431 @4096) -> the gap WIDENED. OG14 used the OLD atom-major hand-rolled
//   box + a per-slab software decode band (the SAME defect OG16 fixed for TF32).
//
// ============================ THE OG16+OG17 RECIPE OG18 PORTS (the TF32 PARITY win) ===========
//   OG16 (#2866): re-encode A/B in GLOBAL into the canonical gmma-INTER layout + a NO-swizzle
//     TMA -> the SMEM tile IS wgmma-ready (descriptor-direct, layout_type_=0, SBO addresses the
//     8-row atom stack) with NO in-kernel decode band. The 32KB band is GONE *and used*. TF32:
//     70.2 -> 264.7 TFLOP/s (3.77x), 6.09x -> 1.37x.
//   OG17 (#2870): with the band gone, the W11/W12/W13 levers reopen. The RELAXED-wait_group
//     ping-pong pipeline (wait_group 1 instead of 0: next slab's wgmma ISSUE overlaps this
//     slab's tensor-core drain) crossed PARITY: 280 TFLOP/s, 1.24x, bit-exact.
//
//   OG18 thesis: the OG14 FP16 wall is the SAME decode-band/occupancy bound OG16 DISSOLVED for
//   TF32. Eliminate the f16 decode band entirely (route-a: pre-lay global in the f16 gmma-INTER
//   8x8 atom + NO-swizzle TMA -> descriptor-direct, no in-kernel decode) and add OG17's relaxed
//   pipeline. If the recipe generalizes across dtypes, FP16 should ride the 2x f16 tensor-core
//   throughput it could not reach while decode-bound -> close the 11.5x gap toward PARITY.
//
// ============================ THE FP16 CANONICAL ATOM (re-derived; differs from TF32 8x4) ======
//   TF32 gmma is .k8, 8(MN)x4(K) core (8*4*4B=128B): gmma_phys(s,k)=(strip*2+kcore)*32+sr*4+kc.
//   FP16 gmma is .k16, 8(MN)x8(K) core (8*8*2B=128B): the W14-RE-DERIVED + on-GPU-MEASURED index
//     gmma_phys16(s,k) = ((strip*KCORES + kcore)*64) + (s&7)*8 + (k&7), strip=s>>3, kcore=k>>3,
//     KCORES=K_TILE/8.  (8-wide cores, 2-byte elems.) This is the operand fragment order the
//     wgmma.mma_async m64nNk16 descriptor addresses; pre-laying GLOBAL in it + NO-swizzle TMA =
//     descriptor-direct, no decode band (the OG16 route-a, f16 geometry).
//   The f16 8-row atom holds 8 rows x 64 K-elems for a 64-wide K-slab = 512 f16 = 1024 bytes.
//   SBO addresses the 8-row atom stack -> SBO = 1024 bytes (f16) vs TF32's 1024 bytes (256 f32).
//   A k16 wgmma sub-tile = 64(MN) x 16(K) = 1024 f16 = 2048 bytes; the K-sub bumps START by it.
//
// ============================ GATE (g5 — the OG14/W14 contract, NOT bit-exact-vs-FP64) =========
//   FP16 + f32-accumulate is a genuinely different numeric. Gate = rel_rms <= 1e-2 vs a
//   SAME-DTYPE reference (cuBLAS-FP16: cublasGemmEx CUDA_R_16F in, CUBLAS_COMPUTE_32F = the same
//   f32-accumulate the wgmma does). single-tile FIRST (MODE 10) then full GEMM (MODE 4/5/6)
//   @2048/4096 BEFORE any TFLOP/s. cuBLAS-FP16 = ROOFLINE (827 @4096, 2x TF32), parity-SEEKING
//   (<=1.3x), NO superiority claim. The FP16 roofline is ~2x TF32 so the ratio math differs;
//   reported honestly. BF16: same path (.f32.bf16.bf16), CUDA_R_16BF.
//
// MODES:
//   10  route-(a) single-tile descriptor-direct wgmma m64n64k16 differential (the GATE). f16.
//   2   raw SWIZZLE_128B landed-law oracle (sanity; the NO-swizzle path needs no decode but
//       MODE 10 self-checks the pre-lay).
//   4   FULL GEMM f16, 128x128 tile, descriptor-direct, NO decode band (OG16 mechanism, f16).
//   5   FULL GEMM f16, 128x256 tile (OG17 LEVER 1: 4 accumulators, 2x reuse per A-load).
//   6   FULL GEMM f16, 128x128 tile + RELAXED wait_group 1 pipeline (OG17 LEVER 3).
//   7   FULL GEMM bf16, 128x128 single band.
//
// argv: S MODE [NST] [SWM=0] [SBO=1024] [BOFF=0]   gate FIRST, perf after. cuBLAS-FP16 roofline.
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
__device__ __host__ __forceinline__ int gmma_phys16(int s,int k,int KCORES){
    int strip=s>>3, sr=s&7, kcore=k>>3, kc=k&7;
    return (strip*KCORES + kcore)*64 + sr*8 + kc;
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

// GMMA SMEM descriptor: start[0,14)>>4, LBO[16,30)>>4, SBO[32,46)>>4, base_offset_[49,52),
// layout_type_[62,64) (NONE=0,B128=1,B64=2,B32=3).
__device__ __host__ __forceinline__ uint64_t mk_desc(uint32_t s,uint32_t lbo,uint32_t sbo,
                                                     uint32_t boff,uint32_t swmode){
    uint64_t d=0;
    d|= (uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16;
    d|=((uint64_t)((sbo>>4)&0x3FFF))<<32;
    d|=((uint64_t)(boff&0x7))<<49;
    d|=((uint64_t)(swmode&0x3))<<62;
    return d;
}

// wgmma m64n64k16 f16: D += A*B, 32 f32 accumulators (n64 -> 32 regs/thread). scaleD=1.
#define WG16(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k16.f32.f16.f16 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1,0,0;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))
// bf16 m64n64k16 (same operand/accum shape, .bf16.bf16).
#define WGBF(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k16.f32.bf16.bf16 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1,0,0;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))

static inline float h16(float x){ return __half2float(__float2half(x)); }
static inline float hbf(float x){ return __bfloat162float(__float2bfloat16(x)); }

typedef CUresult (*Enc_t)(CUtensorMap*,CUtensorMapDataType,cuuint32_t,void*,
    const cuuint64_t*,const cuuint64_t*,const cuuint32_t*,const cuuint32_t*,
    CUtensorMapInterleave,CUtensorMapSwizzle,CUtensorMapL2promotion,CUtensorMapFloatOOBfill);
static Enc_t get_enc(){
    void* fn=nullptr; cudaDriverEntryPointQueryResult q;
    cudaGetDriverEntryPoint("cuTensorMapEncodeTiled",&fn,cudaEnableDefault,&q);
    return (Enc_t)fn;
}

// ======================================================================
// MODE 10 — route-(a) single-tile descriptor-direct wgmma m64n64k16 differential (the GATE).
//   The global operand is PRE-LAID in the f16 gmma-INTER 8x8 atom (host, below). A NO-swizzle
//   TMA lands it 1:1 into SMEM, so a descriptor-direct wgmma reads the operand fragment with NO
//   in-kernel decode. rel_rms vs same-dtype (f16 operands, f64 host accumulate) oracle. The host
//   sweeps SBO/boff/swmode; EXPECT a member at rel_rms ~0 (the route-a atom MATCHED for f16).
// ======================================================================
extern "C" __global__ void probe_a16(const __grid_constant__ CUtensorMap tmapA,
                                     const __grid_constant__ CUtensorMap tmapB,
                                     float* __restrict__ gD,int sbo,int boff,int swmode){
    const int TM=64, TN=64, TK=16;
    extern __shared__ __align__(128) unsigned char smem_raw[];
    // PAD both sides so a mis-strided descriptor reads valid garbage, never faults (W15 trick).
    const int PAD=8192;  // f16 elems each side
    __half* sm_raw=(__half*)smem_raw;
    __half* sm=sm_raw+PAD;
    int tid=threadIdx.x;
    // total f16 buffer = 2*PAD + data; data = Asw(TM*TK)+Bsw(TK*TN)+bar(4 f16). Upper pad base =
    // PAD+DATA, must not exceed TOTAL. Zero lower pad fully; zero upper pad only what fits (W15).
    const int DATA=TM*TK + TK*TN + 4;          // 1024+1024+4 f16
    const int TOTAL=2*PAD + TM*TK + TK*TN + 8; // matches host smsz (in f16 elems)
    for(int i=tid;i<PAD;i+=blockDim.x){ sm_raw[i]=__float2half(0.f); }
    for(int i=PAD+DATA+tid;i<TOTAL;i+=blockDim.x){ sm_raw[i]=__float2half(0.f); }
    __syncthreads();
    __half* Asw=sm;                       // 64(M) x 16(K) gmma-laid = 1024 f16
    __half* Bsw=Asw + TM*TK;              // 64(N) x 16(K) gmma-laid = 1024 f16
    uint64_t* bar=(uint64_t*)(Bsw + TK*TN);
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        uint32_t bytes=(uint32_t)((TM*TK + TK*TN)*2);
        mbar_expect_tx(bar,bytes);
        tma_load_2d(Asw,&tmapA,0,0,bar);   // A box {16(K),64(M)} pre-laid gmma-INTER, 1:1 NO-swz
        tma_load_2d(Bsw,&tmapB,0,0,bar);   // B box {16(K),64(N)} pre-laid gmma-INTER
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
    uint32_t aA=(uint32_t)__cvta_generic_to_shared(Asw);
    uint32_t aB=(uint32_t)__cvta_generic_to_shared(Bsw);
    uint64_t dA=mk_desc(aA,128,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
    uint64_t dB=mk_desc(aB,128,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
    float d[32];
    #pragma unroll
    for(int i=0;i<32;++i)d[i]=0.f;
    asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
    WG16(d,dA,dB);
    asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
        if(row<64&&col<64)gD[row*64+col]=d[idx];
    }
}

// ======================================================================
// FULL GEMM f16 — descriptor-direct over the f16 gmma-INTER PRE-LAID global, NO decode band.
//   OG16 mechanism, f16 geometry: TKSW=64 (one 128B f16 K-atom = 64 K), TK=16 (wgmma k16) ->
//   4 k16 sub-steps per slab. TM=128,TN=128. 256 thr = 2 consumer warpgroups (band wg).
//   gmma-INTER pre-laid: per 8-row atom (512 f16), the k16 sub s=k>>4 occupies the contiguous
//   1024-f16 region [s*1024, s*1024+1024) (64 rows x 16 K). The K-sub bumps START by s*1024 f16
//   = s*2048 bytes; SBO addresses the 8-row atom stack (512 f16 = 1024 bytes).
//   RELAXED=1 -> OG17 wait_group 1 pipeline (next slab issue overlaps this slab drain).
// ======================================================================
template<int RELAXED>
__device__ void gemm_og18_body(const CUtensorMap& tmapA,const CUtensorMap& tmapB,
                               float* __restrict__ gD,int M,int N,int K,int NST,
                               int lbo,int sbo,int boff,int swmode){
    const int TM=128,TN=128,TKSW=64,TK=16;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) unsigned char smem[]; __half* sm=(__half*)smem;
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
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
            tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
            #pragma unroll
            for(int c=0;c<NATOM;++c)
                tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,st*TKSW,&full[st]);
        }
    }
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        __half* base=sm+(size_t)st*SWBUF; __half* Asw=base; __half* Bsw=base+ASW;
        // A band: this warpgroup's 64 rows = the band-th 64-row half of the 128-row tile.
        __half* Aband=Asw + band*64*TKSW;
        __half* B0=Bsw;                            // N-atom 0 (cols bn..bn+63), 64x64 gmma-laid
        __half* B1=Bsw + (TKSW*TKSW);              // N-atom 1 (cols bn+64..bn+127)
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            // k16 sub s=kk>>4 occupies contiguous 1024-f16 (64x16) region -> START bumps s*1024 f16.
            uint32_t off=(uint32_t)((kk>>4)*1024*2);
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            WG16(d0,dA,dB0);
            WG16(d1,dA,dB1);
        }
        if(RELAXED){
            asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 1;\n":::"memory");
        } else {
            asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        }
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
                    tma_load_2d(lBsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,load_ki*TKSW,&full[lst]);
            }
        }
    }
    if(RELAXED){ asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory"); }
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
extern "C" __global__ void gemm_og18_f16(const __grid_constant__ CUtensorMap tmapA,
                                         const __grid_constant__ CUtensorMap tmapB,
                                         float* __restrict__ gD,int M,int N,int K,int NST,
                                         int lbo,int sbo,int boff,int swmode){
    gemm_og18_body<0>(tmapA,tmapB,gD,M,N,K,NST,lbo,sbo,boff,swmode);
}
extern "C" __global__ void gemm_og18_f16_pipe(const __grid_constant__ CUtensorMap tmapA,
                                         const __grid_constant__ CUtensorMap tmapB,
                                         float* __restrict__ gD,int M,int N,int K,int NST,
                                         int lbo,int sbo,int boff,int swmode){
    gemm_og18_body<1>(tmapA,tmapB,gD,M,N,K,NST,lbo,sbo,boff,swmode);
}

// bf16 single-band (same structure; .bf16.bf16).
extern "C" __global__ void gemm_og18_bf16(const __grid_constant__ CUtensorMap tmapA,
                                          const __grid_constant__ CUtensorMap tmapB,
                                          float* __restrict__ gD,int M,int N,int K,int NST,
                                          int lbo,int sbo,int boff,int swmode){
    const int TM=128,TN=128,TKSW=64,TK=16;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) unsigned char smem[]; __nv_bfloat16* sm=(__nv_bfloat16*)smem;
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
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
    if(tid==0){
        for(int st=0;st<stages;++st){
            __nv_bfloat16* base=sm+(size_t)st*SWBUF; __nv_bfloat16* Asw=base; __nv_bfloat16* Bsw=base+ASW;
            mbar_expect_tx(&full[st], bytesA+bytesB);
            tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
            #pragma unroll
            for(int c=0;c<NATOM;++c)
                tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,st*TKSW,&full[st]);
        }
    }
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        __nv_bfloat16* base=sm+(size_t)st*SWBUF; __nv_bfloat16* Asw=base; __nv_bfloat16* Bsw=base+ASW;
        __nv_bfloat16* Aband=Asw + band*64*TKSW;
        __nv_bfloat16* B0=Bsw; __nv_bfloat16* B1=Bsw + (TKSW*TKSW);
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>4)*1024*2);
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
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
                    tma_load_2d(lBsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,load_ki*TKSW,&full[lst]);
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
// FULL GEMM f16 — 128x256 OUTPUT TILE (OG17 LEVER 1). 4 accumulators d0..d3 (64x256).
//   B tile = 4 N-atoms of 64 (256). 2x accumulator reuse per A-load vs the 128x128 tile.
//   SWBUF = (128*64 + 256*64)*2 f16 = 48KB/stage -> NST=2 = 96KB/CTA = 2 CTA/SM (OG17 LEVER 1).
// ======================================================================
extern "C" __global__ void gemm_og18_f16_t256(const __grid_constant__ CUtensorMap tmapA,
                                         const __grid_constant__ CUtensorMap tmapB,
                                         float* __restrict__ gD,int M,int N,int K,int NST,
                                         int lbo,int sbo,int boff,int swmode){
    const int TM=128,TN=256,TKSW=64,TK=16;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) unsigned char smem[]; __half* sm=(__half*)smem;
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;                       // 4 B atoms of 64-N
    const uint32_t bytesA=ASW*2, bytesB=BSW*2;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();
    float d0[32],d1[32],d2[32],d3[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;d2[i]=0.f;d3[i]=0.f;}
    uint32_t fph=0;
    int stages=NST<nks?NST:nks;
    if(tid==0){
        for(int st=0;st<stages;++st){
            __half* base=sm+(size_t)st*SWBUF; __half* Asw=base; __half* Bsw=base+ASW;
            mbar_expect_tx(&full[st], bytesA+bytesB);
            tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
            #pragma unroll
            for(int c=0;c<NATOM;++c)
                tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,st*TKSW,&full[st]);
        }
    }
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        __half* base=sm+(size_t)st*SWBUF; __half* Asw=base; __half* Bsw=base+ASW;
        __half* Aband=Asw + band*64*TKSW;
        __half* Bg0=Bsw + 0*(TKSW*TKSW);
        __half* Bg1=Bsw + 1*(TKSW*TKSW);
        __half* Bg2=Bsw + 2*(TKSW*TKSW);
        __half* Bg3=Bsw + 3*(TKSW*TKSW);
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(Bg0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(Bg1);
        uint32_t a2b=(uint32_t)__cvta_generic_to_shared(Bg2);
        uint32_t a3b=(uint32_t)__cvta_generic_to_shared(Bg3);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>4)*1024*2);
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB2=mk_desc(a2b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB3=mk_desc(a3b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            WG16(d0,dA,dB0);
            WG16(d1,dA,dB1);
            WG16(d2,dA,dB2);
            WG16(d3,dA,dB3);
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
                    tma_load_2d(lBsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,load_ki*TKSW,&full[lst]);
            }
        }
    }
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    float* dgrp[4]={d0,d1,d2,d3};
    #pragma unroll
    for(int g=0;g<4;++g){
        float* dg=dgrp[g];
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p,row=rbase+rb+r*8;
            int col=bn+g*64+cb+p+c*8;
            if(row<M&&col<N)gD[row*N+col]=dg[idx];
        }
    }
}

// ===================== HOST PRE-LAY (route-a): f16 gmma-INTER global ========================
// A logical (m,k) -> the SMEM slot the descriptor reads = gmma_phys16 within the 8-row atom,
// atom-major (atom a=mloc>>3 at a*512 f16), per 128-row tile, per 64-K slab. The NO-swizzle TMA
// box {64(K),128(M)} fetches global[box] -> smem 1:1, so we write global at the slot the box
// fetches for smem index p. KCORES for a full 64-K slab = 8 (gmma_phys16 over 0..63 K).
// We use KCORES=4 PER k16 sub-tile laid contiguously (sub s=k>>4 at s*1024), matching the
// descriptor START bump s*1024. So smem slot for (mloc,k) = a*512_per_sub?  -> simplest: lay
// each k16 sub as its own 64x16 gmma block (KCORES=2) at s*1024 within the slab.
static int a_smem_slot(int mloc,int k){
    int a=mloc>>3, r=mloc&7;
    int sub=k>>4, kk=k&15;         // k16 sub-tile s, local K 0..15
    return sub*1024 + a*128 + gmma_phys16(r,kk,2);  // KCORES=2 (16/8), atom a at a*128 within sub
}
// NOTE on a_smem_slot geometry: within one k16 sub (64 rows x 16 K = 1024 f16), the 8-row atom a
// occupies a*128 (8 rows x 16 K = 128 f16). gmma_phys16(r,kk,2): kcore=kk>>3 (0..1), within
// (strip=0 since r<8) -> (kcore)*64 + r*8 + (kk&7), range 0..127. atom-major a*128 stacks them.
// SBO addresses the 8-row atom stack = 128 f16 = 256 bytes? No: SBO is the stride between
// 8-row atoms the descriptor walks for the 64-row operand. 64 rows = 8 atoms of 8 -> SBO=128 f16.
// We sweep SBO in MODE10 to confirm.

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):10;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}

    if(MODE==10){
        // ---- route-(a) f16 single-tile differential. A(64x16),B(64x16 as K-major) pre-laid
        //      gmma-INTER; NO-swizzle TMA; sweep SBO/boff/swmode; rel_rms ~0 GATE.
        const int M=64,N=64,K=16;
        float *hAf=(float*)malloc((size_t)M*K*4),*hBf=(float*)malloc((size_t)K*N*4);
        float *hD=(float*)malloc((size_t)M*N*4),*hR=(float*)malloc((size_t)M*N*4);
        srand(3);
        for(int i=0;i<M*K;++i)hAf[i]=h16(((rand()%17)-8)*0.125f);
        for(int i=0;i<K*N;++i)hBf[i]=h16(((rand()%17)-8)*0.125f);
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){double a=0;for(int kk=0;kk<K;++kk)a+=(double)hAf[m*K+kk]*hBf[kk*N+n];hR[m*N+n]=(float)a;}
        // PRE-LAY A into gmma-INTER (global == the smem the NO-swz TMA lands). The box {16(K),
        // 64(M)} fetches global row=m, col=k -> smem[m*16+k]? No: NO-swizzle TMA lands SMEM
        // contiguous box-row-major. We instead make GLOBAL hold the gmma block directly and use
        // a box that fetches it 1:1: global laid as 1024 f16 row-major == smem 1024 f16. Box
        // {16,64}: smem[p] = global[(p/16)*16 + p%16] = global[p]. So write hAp[a_smem_slot]=val.
        __half* hAp=(__half*)calloc((size_t)M*K,2); __half* hBp=(__half*)calloc((size_t)K*N,2);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k) hAp[a_smem_slot(m,k)]=__float2half(hAf[m*K+k]);
        // B: logical (k,n). operand B fragment in gmma_phys16(n,k) order (N is the "MN" dim of B).
        for(int k=0;k<K;++k)for(int n=0;n<N;++n) hBp[a_smem_slot(n,k)]=__float2half(hBf[k*N+n]);
        __half *dA,*dB; float* dD;
        CK(cudaMalloc(&dA,(size_t)M*K*2));CK(cudaMalloc(&dB,(size_t)K*N*2));CK(cudaMalloc(&dD,(size_t)M*N*4));
        CK(cudaMemcpy(dA,hAp,(size_t)M*K*2,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB,hBp,(size_t)K*N*2,cudaMemcpyHostToDevice));
        // box {16(K),64(M)}: contiguous=K=16, 64 rows. lands smem 1:1 row-major (no swizzle).
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)K*2};
          cuuint32_t bd[2]={16,64}; cuuint32_t es[2]={1,1};
          if(enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT16,2,dA,gd,gs,bd,es,
             CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
             CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE)!=CUDA_SUCCESS){printf("MODE10 encA fail\n");return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)N}; cuuint64_t gs[1]={(cuuint64_t)K*2};
          cuuint32_t bd[2]={16,64}; cuuint32_t es[2]={1,1};
          if(enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT16,2,dB,gd,gs,bd,es,
             CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
             CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE)!=CUDA_SUCCESS){printf("MODE10 encB fail\n");return 4;} }
        const int PAD=8192;
        size_t smsz=(size_t)(2*PAD + M*K + K*N)*2 + 16;
        CK(cudaFuncSetAttribute(probe_a16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        int sbl[5]={128,256,1024,512,2048};
        int swl[2]={0,1};
        int bol[8]={0,1,2,3,4,5,6,7};
        double best=1e9; int bS=0,bW=0,bB=0;
        for(int wi=0;wi<2;++wi)for(int si=0;si<5;++si)for(int bi=0;bi<8;++bi){
            int SWM=swl[wi],SBO=sbl[si],BOFF=bol[bi];
            CK(cudaMemset(dD,0,(size_t)M*N*4));
            probe_a16<<<1,128,smsz>>>(tmapA,tmapB,dD,SBO,BOFF,SWM);
            cudaError_t e=cudaDeviceSynchronize();
            if(e!=cudaSuccess){ cudaGetLastError(); continue; }
            CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
            double se=0,sr=0;for(int i=0;i<M*N;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
            double rr=sqrt(se/fmax(1e-30,sr));
            if(rr<best){best=rr;bS=SBO;bW=SWM;bB=BOFF;
                printf("OG18-F16-NEWBEST rel_rms=%.3e @ swm=%d sbo=%d boff=%d\n",rr,SWM,SBO,BOFF);}
        }
        printf("OG18 MODE10 f16 single-tile SWEEP-DONE best rel_rms=%.3e @ swm=%d sbo=%d boff=%d %s\n",
               best,bW,bS,bB, best<=1e-2?"PASS (f16 route-a atom MATCHED — band-free, gate)":"FAIL (atom not matchable)");
        return best<=1e-2?0:2;
    }

    if(MODE==4||MODE==5||MODE==6||MODE==7){
        // FULL GEMM. 4=f16 128x128, 5=f16 128x256, 6=f16 128x128+relaxed-pipe, 7=bf16 128x128.
        int NST =argc>3?atoi(argv[3]):3;
        int SWM =argc>4?atoi(argv[4]):0;
        int SBO =argc>5?atoi(argv[5]):128;
        int BOFF=argc>6?atoi(argv[6]):0;
        int LBO =128;
        bool bf=(MODE==7);
        int TN=(MODE==5)?256:128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%TN||Kx%64||Mx%128){printf("MODE%d needs N%%%d==0 && K%%64==0 && M%%128==0\n",MODE,TN);return 1;}
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        char* hA=(char*)malloc(szA*2); char* hB=(char*)malloc(szB*2);
        float* hD=(float*)malloc(szD*4); float* hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i){float v=((rand()%17)-8)*0.0625f; if(bf)((__nv_bfloat16*)hA)[i]=__float2bfloat16(v); else ((__half*)hA)[i]=__float2half(v);}
        for(size_t i=0;i<szB;++i){float v=((rand()%17)-8)*0.0625f; if(bf)((__nv_bfloat16*)hB)[i]=__float2bfloat16(v); else ((__half*)hB)[i]=__float2half(v);}
        void *dAo,*dBo,*dA,*dB; float *dD,*dR;
        CK(cudaMalloc(&dAo,szA*2));CK(cudaMalloc(&dBo,szB*2));
        CK(cudaMalloc(&dA,szA*2));CK(cudaMalloc(&dB,szB*2));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        CK(cudaMemcpy(dAo,hA,szA*2,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*2,cudaMemcpyHostToDevice));
        // SAME-DTYPE cuBLAS reference (roofline + oracle): cublasGemmEx f16/bf16 in, f32 compute.
        cublasHandle_t h;CB(cublasCreate(&h));
        float al=1.f,be=0.f;
        cudaDataType_t ctype = bf?CUDA_R_16BF:CUDA_R_16F;
        CB(cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,ctype,Nx,dAo,ctype,Kx,&be,dR,CUDA_R_32F,Nx,
                        CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // PRE-LAY A,B into f16 gmma-INTER GLOBAL (route-a). The kernel reads each 64-K slab as
        // per-8-row-atom gmma blocks, 4 k16 subs each at s*1024 f16. A box {64(K),128(M)} lands
        // smem[p] from global row(M)=bm+p/64, col(K)=slab*64+p%64 -> write global at that slot.
        char* hAp=(char*)calloc(szA,2); char* hBp=(char*)calloc(szB,2);
        // A: per (tile=m>>7, slab=k>>6) the 128x64 smem block, slot = a_full(mloc,kloc).
        // smem block 128x64 = 8192 f16: a_full(mloc 0..127, kloc 0..63) = a_smem_slot of the
        // 64-row band? No: 128 rows = 16 atoms. The kernel's Aband = band*64*64 offsets the
        // upper 64-row half. So lay the 128x64 block as: row-block b=mloc>>6 (0/1) at b*(64*64),
        // then a_smem_slot within the 64-row sub (mloc&63, kloc).
        for(size_t m=0;m<(size_t)Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=(int)(m&127), slab=k>>6, kloc=k&63;
            int bsub=mloc>>6, mm=mloc&63;             // which 64-row band (0/1)
            int p = bsub*(64*64) + a_smem_slot(mm,kloc);   // smem slot within the 128x64 block
            int srow = tile*128 + (p>>6);             // box row = global M
            int scol = slab*64 + (p&63);              // box col = global K
            size_t off=(size_t)srow*Kx + scol;
            if(bf)((__nv_bfloat16*)hAp)[off]=((__nv_bfloat16*)hA)[m*Kx+k];
            else  ((__half*)hAp)[off]=((__half*)hA)[m*Kx+k];
        }
        // B: per (tile=n>>?, slab) load atom-by-atom, box {64(K),64(N)} per N-atom. The kernel
        // loads atom c=(n within TN)>>6 at c*(64*64). Within atom: a_smem_slot(nn&63,kloc).
        for(int k=0;k<Kx;++k)for(size_t n=0;n<(size_t)Nx;++n){
            int tile=(int)(n/TN), nloc=(int)(n%TN), c=nloc>>6, nn=nloc&63, slab=k>>6, kloc=k&63;
            int p = a_smem_slot(nn,kloc);             // smem slot within the 64-N atom (4096 f16)
            int gN = tile*TN + c*64 + (p&63);         // global N
            int gK = slab*64 + (p>>6);                // global K
            size_t off=(size_t)gK*Nx + gN;
            if(bf)((__nv_bfloat16*)hBp)[off]=((__nv_bfloat16*)hB)[(size_t)k*Nx+n];
            else  ((__half*)hBp)[off]=((__half*)hB)[(size_t)k*Nx+n];
        }
        CK(cudaMemcpy(dA,hAp,szA*2,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*2,cudaMemcpyHostToDevice));
        CUtensorMapDataType dt = bf?CU_TENSOR_MAP_DATA_TYPE_BFLOAT16:CU_TENSOR_MAP_DATA_TYPE_FLOAT16;
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*2};
          cuuint32_t bd[2]={64,128}; cuuint32_t es[2]={1,1};
          if(enc(&tmapA,dt,2,dA,gd,gs,bd,es,CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
             CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE)!=CUDA_SUCCESS){printf("MODE%d encA fail\n",MODE);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*2};
          cuuint32_t bd[2]={64,64}; cuuint32_t es[2]={1,1};
          if(enc(&tmapB,dt,2,dB,gd,gs,bd,es,CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
             CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE)!=CUDA_SUCCESS){printf("MODE%d encB fail\n",MODE);return 4;} }
        const int TM=128,TKSW=64;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*2 + (size_t)NST*8;
        dim3 grid(Nx/TN,(Mx+TM-1)/TM); int blk=256;
        const void* fn; const char* tag;
        if(MODE==4){ fn=(const void*)gemm_og18_f16; tag="OG18-F16-128"; }
        else if(MODE==5){ fn=(const void*)gemm_og18_f16_t256; tag="OG18-F16-256"; }
        else if(MODE==6){ fn=(const void*)gemm_og18_f16_pipe; tag="OG18-F16-PIPE"; }
        else { fn=(const void*)gemm_og18_bf16; tag="OG18-BF16-128"; }
        CK(cudaFuncSetAttribute(fn,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){
            if(MODE==4) gemm_og18_f16<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM);
            else if(MODE==5) gemm_og18_f16_t256<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM);
            else if(MODE==6) gemm_og18_f16_pipe<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM);
            else gemm_og18_bf16<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM);
        };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,fn,blk,smsz);
          printf("OCCUPANCY %s MODE=%d NST=%d blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM\n",tag,MODE,NST,blk,smsz,smsz/1024.0,occ); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE%d OWN-FAULT swm=%d sbo=%d boff=%d %s\n",MODE,SWM,SBO,BOFF,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        double tol=1e-2;
        if(rr>tol){printf("%s S=%d MODE=%d NST=%d swm=%d sbo=%d boff=%d rel_rms=%.3e FAIL (tol %.0e same-dtype) — no perf (g5)\n",
            tag,S,MODE,NST,SWM,SBO,BOFF,rr,tol);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,ctype,Nx,dAo,ctype,Kx,&be,dR,CUDA_R_32F,Nx,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasGemmEx(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,ctype,Nx,dAo,ctype,Kx,&be,dR,CUDA_R_32F,Nx,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        const char* dtag = bf?"cuBLAS-BF16":"cuBLAS-FP16";
        printf("%s S=%d MODE=%d NST=%d swm=%d sbo=%d boff=%d own=%.1f TFLOP/s %s=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e (tol %.0e same-dtype) PARITY=%s\n",
               tag,S,MODE,NST,SWM,SBO,BOFF,tfo,dtag,tfc,ratio,rr,tol,ratio<=1.3?"YES":"NO");
        return 0;
    }
    printf("unknown MODE %d\n",MODE); return 1;
}
