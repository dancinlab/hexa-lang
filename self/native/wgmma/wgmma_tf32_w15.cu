// wgmma_tf32_w15.cu — W15: DESCRIPTOR-DIRECT wgmma own-GEMM on native sm_90a.
//
// THE BREAKTHROUGH (research #2854, docs/research/sm90-wgmma-parity-rewrite-deepdive.md):
//   The W10/W11 "HW in-place swizzle ruled out, decode-copy unavoidable" (rel-RMS 1.392)
//   was a DESCRIPTOR-ENCODING BUG, not a fundamental wall. CuTe `make_gmma_desc`
//   (cute/arch/mma_sm90_desc.hpp + cute/atom/mma_traits_sm90_gmma.hpp) builds a 64-bit
//   SMEM matrix descriptor that expresses SWIZZLE_128B DIRECTLY via `layout_type_=1`, and
//   the HW de-swizzles on-read — NO software decode-copy. W15 deletes the W10 32KB gmma
//   decode scratch band entirely and feeds wgmma straight from the SWIZZLE_128B-TMA tile.
//
// ===================== THE 3 ENCODING FIXES (vs W10 MODE 5 floor 1.392) =====================
//   The 64-bit GmmaDescriptor bitfield (CuTe primary source):
//     start_address_      bits [0,14)   = (smem_addr >> 4), 16B units. Tile 128B-aligned.
//     leading_byte_offset_bits [16,30)  = LBO >> 4
//     stride_byte_offset_ bits [32,46)  = SBO >> 4
//     base_offset_        bits [49,52)  = 3-bit alignment phase
//     layout_type_        bits [62,64)  = swizzle mode: NONE=0, B128=1, B64=2, B32=3
//   BUG 1: W10 used a nonexistent "MODE5" framing — 128B swizzle = layout_type_=1 (2-bit).
//   BUG 2: W10 in-place SBO was the COMPACT 256B (no-swizzle reference). 128B is NON-compact
//          (2/4 atoms stacked in K) -> SBO = 1024 B (=128*8). (>>4 = 64.)
//   BUG 3: W10 dropped the 3-bit alignment phase (the measured g_phys = g XOR ((r+1)&7) "+1");
//          it must be CARRIED in base_offset_ when row-0 is not 128B-aligned.
//   Plus: the deeper §1 fix — the OPERAND TILE must be landed by the TMA in the CANONICAL
//   Layout_K_SW128_Atom (Swizzle<3,4,3>) byte pattern, addressed by ONE descriptor over the
//   whole tile + stepped by the K-stride. The W10 in-place attempt pointed the descriptor at
//   the ATOM-MAJOR landing (A: a*256 stacked; B: 4 side-by-side 32x32) which is NOT the
//   canonical atom the layout_type_=1 HW de-swizzle expects -> O(1) rel-RMS.
//
// ===================== W15 GATE DISCIPLINE (g5) =====================
//   MODE 0  DESCRIPTOR-DIRECT single-tile differential (the W11 single-tile re-run): land an
//           A(64x32)+B(32x64) SWIZZLE_128B tile, build the corrected descriptor, run ONE
//           wgmma m64n64k8 reading SMEM IN PLACE (no decode), rel_rms vs CPU. EXPECT 0.000.
//           Runtime-tunable (lbo,sbo,boff,swmode) so the 3 fields iterate WITHOUT recompiling.
//   MODE 2  RAW SWIZZLE DUMP (validation oracle, reused from W9/W10): land a unique-id tile,
//           copy phys->global, so the host reads the true landed Swizzle<3,4,3> law.
//   MODE 4  FULL GEMM descriptor-direct (no decode scratch) — full bit-exact gate, then perf.
//           smem drops ~32KB/CTA vs W10. Measure own GFLOP/s + occupancy + cuBLAS ratio.
//
// argv: S MODE [NST] [LBO] [SBO] [BOFF] [SWMODE]
// Bit-exact GATE FIRST (rel_rms 0), full GEMM bit-exact gate, perf ONLY after (g5).
// cuBLAS-TF32 = ROOFLINE, parity-SEEKING, NO superiority claim.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda.h>
#include <cudaTypedefs.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d\n",(int)s);return 3;}}while(0)

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

// wgmma m64n64k8 TF32. scaleD=1 (accumulate), scaleA=scaleB=1, no transpose.
#define WG(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))

// ---- the corrected SWIZZLE-128B GMMA matrix descriptor (research #2854 §1+§4.1). ----
//   start [0,14)>>4, LBO [16,30)>>4, SBO [32,46)>>4, base_offset_ [49,52), layout_type_ [62,64).
//   For SWIZZLE_128B in-place read: layout_type_=1, SBO=1024B (non-compact 2/4-atom K-stack).
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

static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}

typedef CUresult (*Enc_t)(CUtensorMap*,CUtensorMapDataType,cuuint32_t,void*,
    const cuuint64_t*,const cuuint64_t*,const cuuint32_t*,const cuuint32_t*,
    CUtensorMapInterleave,CUtensorMapSwizzle,CUtensorMapL2promotion,CUtensorMapFloatOOBfill);
static Enc_t get_enc(){
    void* fn=nullptr; cudaDriverEntryPointQueryResult q;
    cudaGetDriverEntryPoint("cuTensorMapEncodeTiled",&fn,cudaEnableDefault,&q);
    return (Enc_t)fn;
}

// ======================================================================
// MODE 0 — DESCRIPTOR-DIRECT single-tile wgmma differential (the W15 GATE = W11 re-run).
//   Land A(64x32)+B(32x64,2 N-atoms) via SWIZZLE_128B TMA. Build the corrected descriptor
//   (layout_type_=swmode, SBO=sbo, base_offset_=boff) pointing DIRECTLY at the landed
//   swizzled tile — NO software decode — and run one wgmma m64n64k8. rel_rms vs CPU.
//   EXPECT rel_rms 0 with the corrected encoding. The 3 fields are runtime-tunable for the
//   on-pod iterate (BUG1 swmode / BUG2 sbo / BUG3 boff) without recompiling.
// ======================================================================
extern "C" __global__ void probe_desc(const __grid_constant__ CUtensorMap tmapA,
                                       const __grid_constant__ CUtensorMap tmapB,
                                       float* __restrict__ gD,int M,int N,int K,
                                       int lbo,int sbo,int boff,int swmode){
    const int TM=64, TN=64, TKSW=32;
    extern __shared__ __align__(128) float sm[];
    // A swizzled 64x32; B = 2 side-by-side 32(N)x32(K) swizzled atoms (each 32*32 floats).
    float* Asw=sm;                       // 64*32
    float* Bsw=Asw + TM*TKSW;             // 2*(32*32)
    uint64_t* bar=(uint64_t*)(Bsw + TN*TKSW);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        uint32_t bytes=(uint32_t)((TM*TKSW + TN*TKSW)*4);
        mbar_expect_tx(bar,bytes);
        tma_load_2d(Asw,        &tmapA,0,0,bar);   // A 64x32
        tma_load_2d(Bsw,        &tmapB,0, 0,bar);  // B atom0 N0..31
        tma_load_2d(Bsw+32*TKSW,&tmapB,32,0,bar);  // B atom1 N32..63
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
    // DESCRIPTOR-DIRECT: point wgmma at the swizzled SMEM tile in place. No decode buffer.
    uint32_t aA=(uint32_t)__cvta_generic_to_shared(Asw);
    uint32_t aB=(uint32_t)__cvta_generic_to_shared(Bsw);
    uint64_t dA=mk_desc(aA,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
    uint64_t dB=mk_desc(aB,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
    float d[32];
    #pragma unroll
    for(int i=0;i<32;++i)d[i]=0.f;
    asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
    WG(d,dA,dB);
    asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
        if(row<64&&col<64)gD[row*64+col]=d[idx];
    }
}

// ======================================================================
// MODE 9 — IN-PROCESS descriptor sweep (one CUDA context). Re-runs probe_desc for many
//   (lbo,sbo,boff,swmode) in a single binary so the iterate is seconds, not minutes (the
//   per-process CUDA-context-init was the bottleneck). The A/B tmaps are encoded once; only
//   the descriptor fields vary per launch. Reports rel_rms per config + the BEST.
//   Reuses probe_desc above (declared); MODE 9 host loop lives in main().
// ======================================================================

// ---- GMMA INTER 8x4-core physical index (W2/W3-proven, bit-exact). The W10 oracle. ----
__device__ __host__ __forceinline__ int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
// ======================================================================
// MODE 6 — LOCALIZER. Land A(64x32)+B(2x32x32) swizzled, run the descriptor-direct wgmma AND
//   a W10 composed-decode wgmma (known bit-exact) in the SAME kernel, write BOTH to global so
//   the host can diff descriptor-vs-composed and isolate whether A, B, or both are misread.
//   Also dumps, for the descriptor path, the raw wgmma fragment so we can see the permutation.
// ======================================================================
extern "C" __global__ void probe_localize(const __grid_constant__ CUtensorMap tmapA,
                                           const __grid_constant__ CUtensorMap tmapB,
                                           float* __restrict__ gDdesc, float* __restrict__ gDcomp,
                                           int lbo,int sbo,int boff,int swmode){
    const int TM=64, TN=64, TKSW=32;
    extern __shared__ __align__(128) float sm[];
    float* Asw=sm;                       // 64*32 swizzled
    float* Bsw=Asw + TM*TKSW;            // 2*(32*32) swizzled
    float* Ag =Bsw + TN*TKSW;            // gmma-laid A 64x8 (composed decode)
    float* Bg =Ag  + TM*8;               // gmma-laid B 8x64
    uint64_t* bar=(uint64_t*)(Bg + 8*TN);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        uint32_t bytes=(uint32_t)((TM*TKSW + TN*TKSW)*4);
        mbar_expect_tx(bar,bytes);
        tma_load_2d(Asw,        &tmapA,0,0,bar);
        tma_load_2d(Bsw,        &tmapB,0, 0,bar);
        tma_load_2d(Bsw+32*TKSW,&tmapB,32,0,bar);
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
    // ---- W10 composed decode (bit-exact oracle) into Ag/Bg ----
    for(int i=tid;i<TM*8;i+=blockDim.x){
        int m=i/8, k=i%8; int a=m>>3, r=m&7;
        int sw_phys = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
        Ag[gmma_phys(m,k)] = Asw[sw_phys];
    }
    for(int i=tid;i<8*TN;i+=blockDim.x){
        int k=i/TN, n=i%TN; int c=n>>5, nn=n&31; int gp=(nn>>2)^(k&7);
        int sw_phys = c*(32*TKSW) + k*32 + (gp<<2) + (nn&3);
        Bg[gmma_phys(n,k)] = Bsw[sw_phys];
    }
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
    // ---- composed wgmma ----
    {
        uint32_t aA=(uint32_t)__cvta_generic_to_shared(Ag);
        uint32_t aB=(uint32_t)__cvta_generic_to_shared(Bg);
        uint64_t dA=mk_desc(aA,128,256,0,0), dB=mk_desc(aB,128,256,0,0); // no-swizzle gmma layout
        float d[32];
        #pragma unroll
        for(int i=0;i<32;++i)d[i]=0.f;
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        WG(d,dA,dB);
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
            if(row<64&&col<64)gDcomp[row*64+col]=d[idx];
        }
    }
    __syncthreads();
    // ---- descriptor-direct wgmma (the W15 path under test) ----
    {
        uint32_t aA=(uint32_t)__cvta_generic_to_shared(Asw);
        uint32_t aB=(uint32_t)__cvta_generic_to_shared(Bsw);
        uint64_t dA=mk_desc(aA,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
        uint64_t dB=mk_desc(aB,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
        float d[32];
        #pragma unroll
        for(int i=0;i<32;++i)d[i]=0.f;
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        WG(d,dA,dB);
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p,row=rb+r*8,col=cb+p+c*8;
            if(row<64&&col<64)gDdesc[row*64+col]=d[idx];
        }
    }
}

// ======================================================================
// MODE 2 — RAW SWIZZLE DUMP (validation oracle). Land a 128x32 SWIZZLE_128B tile where
//   global A[m][k]=m*32+k (unique id), copy shared[p] verbatim to global so the HOST reads,
//   per physical slot p, the landed (m,k). Measures the true Swizzle<3,4,3> law for THIS box.
// ======================================================================
extern "C" __global__ void dump_layout(const __grid_constant__ CUtensorMap tmapA,
                                        float* __restrict__ gOut,int M,int K){
    const int TM=128, TKSW=32;
    extern __shared__ __align__(128) float sm[];
    float* As=sm; uint64_t* bar=(uint64_t*)(As+TM*TKSW);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){ mbar_expect_tx(bar,(uint32_t)(TM*TKSW*4)); tma_load_2d(As,&tmapA,0,0,bar); }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    for(int p=tid;p<TM*TKSW;p+=blockDim.x) gOut[p]=As[p];
}

// ======================================================================
// MODE 4 — FULL GEMM, DESCRIPTOR-DIRECT swizzled-TMA dual-consumer-WG warpspec (the W15 GEMM).
//   Geometry = W10 MODE 4: TM=128, TN=128, 256 thr = 2 consumer warpgroups, 1 elected TMA
//   producer. DIFFERENCE vs W10: NO gmma decode scratch band. The consumer wgmma reads the
//   SWIZZLE_128B-landed tile IN PLACE via the corrected layout_type_=swmode descriptor.
//   smem = swizzled ring only (NST*(128*32 + 128*32)*4) -> ~32KB/CTA less than W10.
//   K slab = TKSW=32 (one 128B atom) -> 4 wgmma k8 sub-steps per slab; the descriptor START
//   bumps by the in-atom K offset (kk K-elems) each sub-step.
// ======================================================================
extern "C" __global__ void gemm_w15(const __grid_constant__ CUtensorMap tmapA,
                                     const __grid_constant__ CUtensorMap tmapB,
                                     float* __restrict__ gD,int M,int N,int K,int NST,
                                     int lbo,int sbo,int boff,int swmode){
    const int TM=128,TN=128,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;          // swizzled landings (staged NST-deep)
    const int SWBUF=ASW+BSW;                      // NO gmma scratch -> ~half the W10 smem
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;                      // 4 side-by-side 32-N B atoms
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();
    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    uint32_t fph=0;
    int stages=NST<nks?NST:nks;
    if(tid==0){
        for(int st=0;st<stages;++st){
            float* base=sm+(size_t)st*SWBUF; float* Asw=base; float* Bsw=base+ASW;
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
        float* base=sm+(size_t)st*SWBUF; float* Asw=base; float* Bsw=base+ASW;
        // band's 64-row A: atoms band*8 .. band*8+7 of the 16-atom stacked tile.
        float* Aband=Asw + band*64*TKSW;
        float* B0=Bsw;                            // atoms 0,1 (N 0..63)
        float* B1=Bsw + 2*(TKSW*TKSW);            // atoms 2,3 (N 64..127)
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)(kk*4);        // bump START by kk K-elems within the atom
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
        }
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
        if(tid==0){
            int load_ki=ki+stages;
            if(load_ki<nks){
                int lst=load_ki%NST;
                float* lb=sm+(size_t)lst*SWBUF; float* lAsw=lb; float* lBsw=lb+ASW;
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

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):0;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}

    if(MODE==0){
        // ---- DESCRIPTOR-DIRECT single-tile wgmma differential (the W15 GATE) ----
        int LBO =argc>3?atoi(argv[3]):128;
        int SBO =argc>4?atoi(argv[4]):1024;   // BUG2 fix: non-compact 128B SBO
        int BOFF=argc>5?atoi(argv[5]):0;      // BUG3: alignment phase
        int SWM =argc>6?atoi(argv[6]):1;      // BUG1 fix: layout_type_=1 (B128)
        const int M=64,N=64,K=8;
        float *hA=(float*)malloc((size_t)M*K*4),*hB=(float*)malloc((size_t)K*N*4);
        float *hD=(float*)malloc((size_t)M*N*4),*hR=(float*)malloc((size_t)M*N*4);
        srand(3);
        for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
        for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];hR[m*N+n]=a;}
        const int KSW=32;
        float *hApad=(float*)calloc((size_t)M*KSW,4), *hBpad=(float*)calloc((size_t)KSW*N,4);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k)hApad[m*KSW+k]=hA[m*K+k];
        for(int k=0;k<K;++k)for(int n=0;n<N;++n)hBpad[k*N+n]=hB[k*N+n];
        float *dA,*dB,*dD; CK(cudaMalloc(&dA,(size_t)M*KSW*4));CK(cudaMalloc(&dB,(size_t)KSW*N*4));CK(cudaMalloc(&dD,(size_t)M*N*4));
        CK(cudaMemcpy(dA,hApad,(size_t)M*KSW*4,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB,hBpad,(size_t)KSW*N*4,cudaMemcpyHostToDevice));
        CK(cudaMemset(dD,0,(size_t)M*N*4));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)KSW,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)KSW*4};
          cuuint32_t bd[2]={32,64}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE0 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)KSW}; cuuint64_t gs[1]={(cuuint64_t)N*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE0 encodeB r=%d\n",(int)r);return 4;} }
        size_t smsz=(size_t)(M*KSW + N*KSW)*4 + 8;
        CK(cudaFuncSetAttribute(probe_desc,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        probe_desc<<<1,128,smsz>>>(tmapA,tmapB,dD,M,N,K,LBO,SBO,BOFF,SWM);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE0 FAULT lbo=%d sbo=%d boff=%d swm=%d %s\n",LBO,SBO,BOFF,SWM,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;int exact=0;for(int i=0;i<M*N;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];if(fabs(dd)<1e-4)exact++;}
        double rr=sqrt(se/fmax(1e-30,sr));
        printf("W15-PROBE MODE=0 desc-direct lbo=%d sbo=%d boff=%d swm=%d: exact=%d/%d rel_rms=%.3e %s\n",
               LBO,SBO,BOFF,SWM,exact,M*N,rr, rr<=3e-3?"PASS (descriptor views swizzled tile)":"FAIL");
        return rr<=3e-3?0:2;
    }

    if(MODE==2){
        // ---- RAW SWIZZLE DUMP (validation oracle) ----
        const int M=128,K=32;
        float* hA=(float*)malloc((size_t)M*K*4);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k)hA[m*K+k]=(float)(m*32+k);
        float *dA,*dO; CK(cudaMalloc(&dA,(size_t)M*K*4)); CK(cudaMalloc(&dO,(size_t)M*K*4));
        CK(cudaMemcpy(dA,hA,(size_t)M*K*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{};
        cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)K*4};
        cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
        CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("MODE2 encodeA r=%d\n",(int)r);return 4;}
        size_t smsz=(size_t)(M*K)*4 + 8;
        CK(cudaFuncSetAttribute(dump_layout,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        dump_layout<<<1,128,smsz>>>(tmapA,dO,M,K);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE2 FAULT %s\n",cudaGetErrorString(e));return 4;}
        float* hO=(float*)malloc((size_t)M*K*4);
        CK(cudaMemcpy(hO,dO,(size_t)M*K*4,cudaMemcpyDeviceToHost));
        printf("W15-DUMP 128x32 SWIZZLE_128B landed layout (phys slot -> landed m*32+k):\n");
        for(int atom=0; atom<2; ++atom){
            printf("--- atom %d (phys rows %d..%d) ---\n",atom,atom*8,atom*8+7);
            for(int pr=0;pr<8;++pr){
                printf("pr=%d: ",pr);
                for(int pg=0;pg<8;++pg){
                    int p=atom*256 + pr*32 + pg*4;
                    int id=(int)hO[p]; int m=id/32,k=id%32;
                    printf("[g%d:m%d,k%d] ",pg,m,k);
                }
                printf("\n");
            }
        }
        return 0;
    }

    if(MODE==4){
        // ---- FULL GEMM: descriptor-direct swizzled-TMA, bit-exact gate then perf ----
        int NST =argc>3?atoi(argv[3]):3;
        int LBO =argc>4?atoi(argv[4]):128;
        int SBO =argc>5?atoi(argv[5]):1024;
        int BOFF=argc>6?atoi(argv[6]):0;
        int SWM =argc>7?atoi(argv[7]):1;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32){printf("MODE4 needs N%%128==0 && K%%32==0\n");return 1;}
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,Nx,dA,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE4 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE4 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=32;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
        CK(cudaFuncSetAttribute(gemm_w15,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_w15<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_w15,blk,smsz);
          printf("OCCUPANCY MODE=4 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM (%d compute-thr/SM)\n",
                 blk,smsz,smsz/1024.0,occ,occ*blk); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE4 OWN-FAULT lbo=%d sbo=%d boff=%d swm=%d %s\n",LBO,SBO,BOFF,SWM,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("W15 S=%d MODE=4 NST=%d lbo=%d sbo=%d boff=%d swm=%d rel_rms=%.3e FAIL — no perf (g5)\n",
            S,NST,LBO,SBO,BOFF,SWM,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,Nx,dA,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,Nx,dA,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("W15 S=%d MODE=4 NST=%d lbo=%d sbo=%d boff=%d swm=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,LBO,SBO,BOFF,SWM,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }
    if(MODE==9 || MODE==6){
        // ---- IN-PROCESS sweep / localizer (one CUDA context) ----
        const int M=64,N=64,K=8;
        float *hA=(float*)malloc((size_t)M*K*4),*hB=(float*)malloc((size_t)K*N*4);
        float *hD=(float*)malloc((size_t)M*N*4),*hR=(float*)malloc((size_t)M*N*4);
        float *hC=(float*)malloc((size_t)M*N*4);
        srand(3);
        for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
        for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];hR[m*N+n]=a;}
        const int KSW=32;
        float *hApad=(float*)calloc((size_t)M*KSW,4), *hBpad=(float*)calloc((size_t)KSW*N,4);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k)hApad[m*KSW+k]=hA[m*K+k];
        for(int k=0;k<K;++k)for(int n=0;n<N;++n)hBpad[k*N+n]=hB[k*N+n];
        float *dA,*dB,*dD,*dC; CK(cudaMalloc(&dA,(size_t)M*KSW*4));CK(cudaMalloc(&dB,(size_t)KSW*N*4));
        CK(cudaMalloc(&dD,(size_t)M*N*4));CK(cudaMalloc(&dC,(size_t)M*N*4));
        CK(cudaMemcpy(dA,hApad,(size_t)M*KSW*4,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB,hBpad,(size_t)KSW*N*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)KSW,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)KSW*4};
          cuuint32_t bd[2]={32,64}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)KSW}; cuuint64_t gs[1]={(cuuint64_t)N*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("encodeB r=%d\n",(int)r);return 4;} }
        size_t sm0=(size_t)(M*KSW + N*KSW)*4 + 8;
        size_t sm6=(size_t)(M*KSW + N*KSW + M*8 + 8*N)*4 + 8;
        CK(cudaFuncSetAttribute(probe_desc,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)sm0));
        CK(cudaFuncSetAttribute(probe_localize,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)sm6));

        if(MODE==6){
            int LBO=argc>3?atoi(argv[3]):128, SBO=argc>4?atoi(argv[4]):1024;
            int BOFF=argc>5?atoi(argv[5]):0, SWM=argc>6?atoi(argv[6]):1;
            CK(cudaMemset(dD,0,(size_t)M*N*4)); CK(cudaMemset(dC,0,(size_t)M*N*4));
            probe_localize<<<1,128,sm6>>>(tmapA,tmapB,dD,dC,LBO,SBO,BOFF,SWM);
            cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
            if(e!=cudaSuccess){printf("MODE6 FAULT %s\n",cudaGetErrorString(e));return 4;}
            CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
            CK(cudaMemcpy(hC,dC,(size_t)M*N*4,cudaMemcpyDeviceToHost));
            // diff composed-vs-CPU (should be 0) and desc-vs-CPU and desc-vs-composed.
            double seC=0,seD=0,seDC=0,sr=0;
            for(int i=0;i<M*N;++i){double t=hR[i];sr+=t*t;
                seC+=(hC[i]-t)*(hC[i]-t); seD+=(hD[i]-t)*(hD[i]-t); seDC+=(hD[i]-hC[i])*(hD[i]-hC[i]);}
            printf("MODE6 localize lbo=%d sbo=%d boff=%d swm=%d: composed_rel=%.3e desc_rel=%.3e desc_vs_composed=%.3e\n",
                   LBO,SBO,BOFF,SWM,sqrt(seC/fmax(1e-30,sr)),sqrt(seD/fmax(1e-30,sr)),sqrt(seDC/fmax(1e-30,sr)));
            // print first 4x4 of each for visual permutation read
            printf("CPU   row0: %.2f %.2f %.2f %.2f\n",hR[0],hR[1],hR[2],hR[3]);
            printf("COMP  row0: %.2f %.2f %.2f %.2f\n",hC[0],hC[1],hC[2],hC[3]);
            printf("DESC  row0: %.2f %.2f %.2f %.2f\n",hD[0],hD[1],hD[2],hD[3]);
            printf("DESC  col0: %.2f %.2f %.2f %.2f (rows0-3)\n",hD[0],hD[64],hD[128],hD[192]);
            return 0;
        }
        // MODE 9 — in-process field sweep
        double best=1e9; int bL=0,bS=0,bB=0,bW=0;
        int swl[4]={1,2,3,0};
        int sbl[8]={1024,512,256,128,2048,64,16,4096};
        int lbl[8]={128,16,256,1024,0,64,512,2048};
        for(int wi=0;wi<4;++wi)for(int si=0;si<8;++si)for(int bo=0;bo<8;++bo)for(int li=0;li<8;++li){
            int SWM=swl[wi],SBO=sbl[si],BOFF=bo,LBO=lbl[li];
            CK(cudaMemset(dD,0,(size_t)M*N*4));
            probe_desc<<<1,128,sm0>>>(tmapA,tmapB,dD,M,N,K,LBO,SBO,BOFF,SWM);
            if(cudaDeviceSynchronize()!=cudaSuccess){cudaGetLastError();continue;}
            CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
            double se=0,sr=0;for(int i=0;i<M*N;++i){double dd=hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
            double rr=sqrt(se/fmax(1e-30,sr));
            if(rr<best){best=rr;bL=LBO;bS=SBO;bB=BOFF;bW=SWM;
                printf("NEWBEST rel_rms=%.3e @ lbo=%d sbo=%d boff=%d swm=%d\n",rr,LBO,SBO,BOFF,SWM);}
        }
        printf("MODE9 SWEEP-DONE best rel_rms=%.3e @ lbo=%d sbo=%d boff=%d swm=%d\n",best,bL,bS,bB,bW);
        return best<=3e-3?0:2;
    }
    printf("unknown MODE %d\n",MODE); return 1;
}
