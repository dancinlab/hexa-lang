// wgmma_tf32_w10.cu — W10: compose the W9-MEASURED FP32 128B-swizzle law with the
// GMMA INTER 8x4 core packing to land a PERMUTE-FREE bit-exact swizzled-TMA decode on
// native sm_90a. Resumes from W9 (#2844): SWIZZLE_128B TMA removes the W8 per-K-step
// cooperative permute (SASS 28 STS -> 0, occupancy 2 CTA/SM preserved) but the naive
// linear-swizzle wgmma descriptor FAILED rel_rms (floor 1.392) because the descriptor<->
// layout mapping is a TWO-LAYER permutation a single linear lbo/sbo cannot express.
//
// ===================== THE W9-MEASURED LAW (handoff 0249c29f) =====================
//   A SWIZZLE_128B-landed 8x32-f32 atom places logical column-granule g (g=c>>2, 0..7)
//   of row r at PHYSICAL granule  g_phys = g XOR ((r+1)&7)   (NOT the textbook g XOR r):
//       row0 mask1 row1 mask2 ... row6 mask7 row7 mask0   ((r+1)&7)
//   i.e. landed[r][g] holds global[r][ g XOR ((r+1)&7) ].  Inverting (XOR is involutive):
//   the global granule g lives at physical granule  g XOR ((r+1)&7).
//   This must STILL compose with the 8x4 INTER core packing gmma_phys (W2/W3-proven, the
//   layout the wgmma matrix descriptor expects).
//
// ===================== W10 GOAL — the COMPOSED decode =====================
//   final(r,g) = gmma_phys( g XOR ((r+1)&7), r )
//   The consumer must read the SWIZZLE_128B-landed tile in wgmma (gmma INTER) order with
//   ZERO cooperative permute. We verify the COMPOSED INDEX recovers the data bit-exactly
//   on a SINGLE TILE (rel_rms 0 GATE — cheap, like W2) BEFORE any 2048^3 perf run, then
//   a full-GEMM bit-exact gate, then perf vs the W8 66.5/6.44x frontier.
//
// MODES:
//   MODE 0  COMPOSED-DECODE PROBE (the W10 GATE): land an 8x32 (or 128x32) swizzled atom
//           via TMA, then verify final(r,g)=gmma_phys(g^((r+1)&7),r) reconstructs the
//           gmma-INTER tile that the W2 path proved bit-exact. rel_rms vs the known gmma
//           layout. This is GPU-cheap and the gate the big run is forbidden to skip.
//   MODE 1  COMPOSED single-tile wgmma m64n64k8 GEMM probe: land A,B swizzled via TMA,
//           emit into gmma layout through the COMPOSED read index, run ONE wgmma,
//           rel_rms vs CPU. Proves the composed decode feeds wgmma correctly (W2-class).
//
// argv: S MODE   (S only used as a sanity echo for MODE 0/1; the tile is fixed 128x32)
// Bit-exact GATE FIRST (rel_rms<=3e-3, ideally 0), perf only after the gate (g5).
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

// ---- GMMA INTER 8x4-core physical index (W2/W3-proven, bit-exact). ----
// strided dim s (M for A / N for B), contiguous dim k (K). core = 8 rows x 4 K-elems.
__device__ __host__ __forceinline__ int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
// ---- W9-MEASURED 128B-swizzle physical index inside an 8-row x 32-f32 (128B) atom. ----
// granule g=c>>2 (0..7), within-granule w=c&3. The W10 RE-MEASURED law (MODE2 dump on the
// FULL 128x32 box, this GPU): landed[pr][pg] holds global granule (pg XOR pr), row-preserving,
// atom-major. So the TEXTBOOK g_phys = g XOR (r&7) IS correct for FP32 SWIZZLE_128B (the W9
// (r+1)&7 reading came from a partial/8-row probe). phys = r*32 + (g XOR (r&7))*4 + w.
__device__ __host__ __forceinline__ int sw128_measured(int r,int c){
    int g=c>>2, w=c&3, gp=g^(r&7); return r*32 + gp*4 + w;
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

// wgmma m64n64k8 macro.
__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0; d|=(uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32; return d;}
#define WG(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))

// swizzled wgmma matrix descriptor: start/LBO/SBO + base_offset (bits 49:51) + swizzle
// mode (bits 62:63). For SWIZZLE_128B in-place read (swmode=1).
__device__ __forceinline__ uint64_t mk_sw(uint32_t s,uint32_t lbo,uint32_t sbo,uint32_t boff,int swmode){
    uint64_t d=0; d|=(uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32;
    d|=((uint64_t)(boff&0x7))<<49; d|=((uint64_t)(swmode&0x3))<<62; return d;}

// ======================================================================
// MODE 5 — IN-PLACE swizzle-mode-1 descriptor GEMM (the true permute-free read).
//   The composed law is the TEXTBOOK g XOR r (W10 MODE 2/3 measured). So the wgmma 128B
//   swizzle descriptor (swmode=1) SHOULD de-swizzle the SWIZZLE_128B-landed tile IN PLACE
//   with NO decode buffer -> recovers smem (32KB/stage vs 64KB) for 2+ CTA/SM AND removes
//   the decode (the W9 SASS permute-free goal). RUNTIME-TUNABLE (lbo,sbo,boff) so the
//   descriptor<->atom-stacking interaction is swept; bit-exact gate is the arbiter.
// ======================================================================
extern "C" __global__ void gemm_w10_inplace(const __grid_constant__ CUtensorMap tmapA,
                                            const __grid_constant__ CUtensorMap tmapB,
                                            float* __restrict__ gD,int M,int N,int K,int NST,
                                            int lbo,int sbo,int boff){
    const int TM=128,TN=128,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int BUF=ASW+BSW;                       // NO gmma bands -> half the smem
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*BUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg;
    int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;
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
            float* base=sm+(size_t)st*BUF; float* Asw=base; float* Bsw=base+ASW;
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
        float* base=sm+(size_t)st*BUF; float* Asw=base; float* Bsw=base+ASW;
        // band's 64-row A: atoms band*8 .. band*8+7 of the 16-atom stacked tile.
        float* Aband=Asw + band*64*TKSW;       // atom-major: 64 rows = 8 atoms * 256 floats
        float* B0=Bsw;                          // atoms 0,1 (N 0..63)
        float* B1=Bsw + 2*(TKSW*TKSW);          // atoms 2,3 (N 64..127)
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            // k8 sub-step: bump START by kk K-elems within the swizzled atom.
            uint32_t off=(uint32_t)(kk*4);
            uint64_t dA =mk_sw(aAb+off,lbo,sbo,boff,1);
            uint64_t dB0=mk_sw(a0b+off,lbo,sbo,boff,1);
            uint64_t dB1=mk_sw(a1b+off,lbo,sbo,boff,1);
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
        }
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
        if(tid==0){
            int load_ki=ki+stages;
            if(load_ki<nks){
                int lst=load_ki%NST;
                float* lb=sm+(size_t)lst*BUF; float* lAsw=lb; float* lBsw=lb+ASW;
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
// MODE 0 — COMPOSED-DECODE PROBE (the W10 GATE).
//   thread0 TMA-loads one SWIZZLE_128B A-tile (128 rows x 32 f32 = 4 atom-cols per
//   8-row group? no: each ROW is 32 f32 = one 128B atom row; an atom = 8 rows). The
//   tile is 128x32 = 16 vertically-stacked 8-row atoms. The swizzle is PER-ATOM (each
//   8-row block independently g^((r+1)&7) with r the WITHIN-ATOM row).
//   We then VERIFY: reading the swizzled tile at the COMPOSED index recovers the same
//   data the W2 gmma_phys layout holds. Specifically, for every logical (m,k):
//     gmma-layout value at gmma_phys(m,k)  ==  swizzled-tile value at composed(m,k).
//   We materialize BOTH from the SAME global A and diff -> rel_rms 0 == the law composes.
// ======================================================================
extern "C" __global__ void probe_decode(const __grid_constant__ CUtensorMap tmapA,
                                         const float* __restrict__ gAref,
                                         float* __restrict__ gOutSw, float* __restrict__ gOutGm,
                                         int M,int K){
    // tile 128 (M) x 32 (K). One swizzled atom = 8 rows x 32 f32.
    const int TM=128, TKSW=32;
    extern __shared__ __align__(128) float sm[];
    float* As=sm;                              // swizzled-landed A tile (TM*TKSW)
    uint64_t* bar=(uint64_t*)(As + TM*TKSW);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        mbar_expect_tx(bar,(uint32_t)(TM*TKSW*4));
        tma_load_2d(As,&tmapA,/*x=k*/0,/*y=m*/0,bar);
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    // For each logical (m,k): swizzled physical position WITHIN this 128x32 tile.
    // atom index a = m>>3 (which 8-row atom), r = m&7 (within-atom row). Each atom is
    // 8*32=256 floats stored contiguously (atom-major). The W9 law indexes within the atom.
    for(int i=tid;i<TM*TKSW;i+=blockDim.x){
        int m=i/TKSW, k=i%TKSW;
        int a=m>>3, r=m&7;
        int sw_in_atom = sw128_measured(r,k);          // physical slot inside the 8x32 atom
        int sw_phys    = a*256 + sw_in_atom;           // atom-major stacking
        // COMPOSED decode: the value the wgmma gmma-INTER layout wants at gmma_phys(m,k)
        // is the swizzled-tile value at sw_phys. Emit both reconstructions for diffing.
        gOutSw[i] = As[sw_phys];                        // value read via composed swizzle index
        gOutGm[i] = gAref[m*K + k];                      // the TRUE global value at (m,k)
    }
}

// ======================================================================
// MODE 1 — COMPOSED single-tile wgmma probe.
//   Land A(64x8 logical, but TMA tile 64x32 swizzled) + B(8x64) swizzled via TMA, then
//   emit into a gmma-INTER buffer THROUGH the composed read index (no W8-style transpose
//   permute — a pure index remap), run one wgmma, rel_rms vs CPU. Proves the composed
//   decode feeds wgmma bit-exactly. (K=8 here; the swizzle atom is still 32-K wide for the
//   TMA, we use the first 8 K columns.)
// ======================================================================
extern "C" __global__ void probe_wgmma(const __grid_constant__ CUtensorMap tmapA,
                                        const __grid_constant__ CUtensorMap tmapB,
                                        float* __restrict__ gD,int M,int N,int K){
    const int TM=64, TN=64, TKSW=32;
    extern __shared__ __align__(128) float sm[];
    float* Asw=sm;                       // swizzled A 64x32
    float* Bsw=Asw + TM*TKSW;             // swizzled B (N-atoms): 2 atoms of 32-N x 32-K
    float* Ag =Bsw + TN*TKSW;             // gmma-laid A 64x8
    float* Bg =Ag  + TM*8;                // gmma-laid B 8x64
    uint64_t* bar=(uint64_t*)(Bg + 8*TN);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        // A: tile 64x32 swizzled. B: contiguous box=N must==atom width 32 -> 2 side-by-side
        // 32-N atoms (TN/32=2). Each B atom is 32-N x 32-K swizzled.
        uint32_t bytes = (uint32_t)((TM*TKSW + TN*TKSW)*4);
        mbar_expect_tx(bar,bytes);
        tma_load_2d(Asw,&tmapA,0,0,bar);
        tma_load_2d(Bsw,            &tmapB,0,  0,bar);  // B atom 0: N 0..31
        tma_load_2d(Bsw+32*TKSW,    &tmapB,32, 0,bar);  // B atom 1: N 32..63
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    // COMPOSED decode A: logical (m,k) -> swizzled slot. atom a=m>>3, r=m&7.
    for(int i=tid;i<TM*8;i+=blockDim.x){
        int m=i/8, k=i%8;
        int a=m>>3, r=m&7;
        int sw_phys = a*256 + sw128_measured(r,k);
        Ag[gmma_phys(m,k)] = Asw[sw_phys];
    }
    // COMPOSED decode B: logical (k,n). W10 B-DUMP (MODE 3) MEASURED the box{32(N),32(K)}
    // layout: physical ROW pr == logical k; within row, the N-granule gp holds logical
    // n-granule (gp XOR (k&7)). So global (k, n_in_atom) lives at physical
    //   k*32 + ((n_in_atom>>2) XOR (k&7))*4 + (n_in_atom&3)   inside its 32-N atom.
    // 2 atoms across N (c=n>>5), each atom = 32*32 floats. wgmma B operand wants gmma_phys(n,k).
    for(int i=tid;i<8*TN;i+=blockDim.x){
        int k=i/TN, n=i%TN;
        int c=n>>5, nn=n&31;                 // c = which 32-N atom (0/1), nn = N within atom
        int gN=nn>>2, w=nn&3, gp=gN^(k&7);
        int sw_phys = c*(32*TKSW) + k*32 + gp*4 + w;
        Bg[gmma_phys(n,k)] = Bsw[sw_phys];
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
// MODE 4 — FULL GEMM, COMPOSED-DECODE swizzled-TMA dual-consumer-WG warpspec (the W10 GEMM).
//   Geometry = W8 MODE 4: TM=128, TN=128, 256 thr = 2 consumer warpgroups, single elected
//   TMA producer thread (full occupancy). DIFFERENCE vs W8: the A/B TMA descriptors are
//   SWIZZLE_128B (tile lands wgmma-near-ready, no Braw transpose scratch), and the per-slab
//   decode is the W10 COMPOSED INDEX (proven bit-exact above): swizzled slot -> gmma INTER.
//   K slab = TKSW=32 (one 128B atom) -> 4 wgmma k8 sub-steps per slab.
//   The W8 cooperative Araw/Braw->gmma TRANSPOSE permute (28 STS) is replaced by a pure
//   composed index copy from the swizzled tile (no row-major scratch, no transpose).
// ======================================================================
extern "C" __global__ void gemm_w10(const __grid_constant__ CUtensorMap tmapA,
                                     const __grid_constant__ CUtensorMap tmapB,
                                     float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=128,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // per-stage: Asw(128*32 swizzled) + Bsw(4 atoms * 32*32 swizzled)
    //          + As0(64*32) As1(64*32) B0(32*64) B1(32*64) gmma-laid (full TKSW K).
    const int ASW=TM*TKSW, BSW=TN*TKSW;        // swizzled landings (staged NST-deep)
    const int ABND=64*TKSW, BB=TKSW*64;         // gmma-laid bands (single, NOT ring-staged)
    const int SWBUF=ASW+BSW;                     // only the swizzled tiles ring
    const int GMMA=2*ABND+2*BB;                  // one gmma-band scratch (shared across slabs)
    // layout: [NST*SWBUF swizzled ring][GMMA gmma scratch][NST full mbar][NST empty mbar]
    float* gmma=sm + (size_t)NST*SWBUF;
    uint64_t* full =(uint64_t*)(gmma + GMMA);
    uint64_t* empty=full+NST;
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;                     // 4 side-by-side 32-N B atoms
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    else if(tid<2*NST){ mbar_init_tx(&empty[tid-NST],256); }
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
            tma_load_2d(Asw,&tmapA,/*x=k*/st*TKSW,/*y=m*/bm,&full[st]);
            #pragma unroll
            for(int c=0;c<NATOM;++c)
                tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,/*x=n*/bn+c*TKSW,/*y=k*/st*TKSW,&full[st]);
        }
    }
    // single shared gmma scratch (NOT ring-staged) — decoded fresh each slab.
    float* As0=gmma; float* As1=As0+ABND; float* B0=As1+ABND; float* B1=B0+BB;
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        float* base=sm+(size_t)st*SWBUF;
        float* Asw=base; float* Bsw=base+ASW;
        // COMPOSED-INDEX decode (proven bit-exact): swizzled tile -> gmma INTER. The gmma
        // band holds 4 INDEPENDENT k8 sub-tiles concatenated: sub = k>>3, each sub is a
        // 64x8 gmma_phys tile (256 floats). The wgmma k8 sub-step START bumps by one sub.
        // A: logical (m 0..127, k 0..TKSW-1). atom a=m>>3, r=m&7. swizzled slot as measured.
        for(int i=tid;i<TM*TKSW;i+=256){
            int m=i/TKSW, k=i%TKSW;
            int a=m>>3, r=m&7;
            int sw = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
            float v=Asw[sw];
            int sub=k>>3, kk=k&7, mm=(m&63);
            float* dst=(m<64)?As0:As1;
            dst[sub*(64*8) + gmma_phys(mm,kk)]=v;
        }
        // B: logical (k 0..TKSW-1, n 0..127). atom c=n>>5, nn=n&31, gp=(nn>>2)^(k&7).
        for(int i=tid;i<TKSW*TN;i+=256){
            int k=i/TN, n=i%TN;
            int c=n>>5, nn=n&31, gp=(nn>>2)^(k&7);
            int sw = c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
            float v=Bsw[sw];
            int sub=k>>3, kk=k&7, nnn=(n&63);
            float* dst=(n<64)?B0:B1;
            dst[sub*(64*8) + gmma_phys(nnn,kk)]=v;
        }
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        float* As=(band==0)?As0:As1;
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0), a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        // 4 wgmma k8 sub-steps over the 32-wide K slab; gmma bands are contiguous 8x4 cores
        // so the k8 sub-step bumps START by 8 K-elems = gmma_phys stride of one kcore-pair.
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            // each k8 sub-tile is an independent 64x8 gmma_phys tile = 512 floats. START
            // bumps by sub*512 floats = sub*2048 bytes.
            uint32_t off=(uint32_t)((kk>>3)*512*4);
            uint64_t dA=mk(aAb+off,128,256), dB0=mk(a0b+off,128,256), dB1=mk(a1b+off,128,256);
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

// ======================================================================
// MODE 2 — RAW SWIZZLE DUMP. Land a 128x32 SWIZZLE_128B tile where global A[m][k]=m*32+k
//   (a unique integer id per logical element). Copy shared[p] verbatim to global so the
//   HOST can read, for every physical slot p, which logical (m,k) landed there. This
//   MEASURES the true TMA-landed layout for THIS box on THIS GPU (no guessing) — the W9
//   dump done properly + at the full 128-row box W10 needs.
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
    for(int p=tid;p<TM*TKSW;p+=blockDim.x) gOut[p]=As[p];   // physical slot p -> its landed id
}
// generic dump: nfloat total floats in one swizzled tile (box defined host-side).
extern "C" __global__ void dump_gen(const __grid_constant__ CUtensorMap tmap,
                                    float* __restrict__ gOut,int nfloat){
    extern __shared__ __align__(128) float sm[];
    float* As=sm; uint64_t* bar=(uint64_t*)(As+nfloat);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){ mbar_expect_tx(bar,(uint32_t)(nfloat*4)); tma_load_2d(As,&tmap,0,0,bar); }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    __syncthreads();
    for(int p=tid;p<nfloat;p+=blockDim.x) gOut[p]=As[p];
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

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):0;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}

    if(MODE==0){
        // ---- COMPOSED-DECODE PROBE (the W10 GATE) ----
        const int M=128,K=32;
        float* hA=(float*)malloc((size_t)M*K*4);
        srand(7);
        for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dOsw,*dOgm; CK(cudaMalloc(&dA,(size_t)M*K*4));
        CK(cudaMalloc(&dOsw,(size_t)M*K*4)); CK(cudaMalloc(&dOgm,(size_t)M*K*4));
        CK(cudaMemcpy(dA,hA,(size_t)M*K*4,cudaMemcpyHostToDevice));
        // A row-major MxK, swizzled tile box {32,128}: contiguous=K=32 == 128B atom. OK.
        CUtensorMap tmapA{};
        cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)K*4};
        cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
        CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("MODE0 encodeA r=%d\n",(int)r);return 4;}
        size_t smsz=(size_t)(M*K)*4 + 8;
        CK(cudaFuncSetAttribute(probe_decode,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        CK(cudaMemset(dOsw,0,(size_t)M*K*4)); CK(cudaMemset(dOgm,0,(size_t)M*K*4));
        probe_decode<<<1,128,smsz>>>(tmapA,dA,dOsw,dOgm,M,K);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE0 FAULT %s\n",cudaGetErrorString(e));return 4;}
        float* hOsw=(float*)malloc((size_t)M*K*4); float* hOgm=(float*)malloc((size_t)M*K*4);
        CK(cudaMemcpy(hOsw,dOsw,(size_t)M*K*4,cudaMemcpyDeviceToHost));
        CK(cudaMemcpy(hOgm,dOgm,(size_t)M*K*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0; int exact=0; for(int i=0;i<M*K;++i){double dd=(double)hOsw[i]-hOgm[i];se+=dd*dd;sr+=(double)hOgm[i]*hOgm[i]; if(fabs(dd)<1e-6)exact++;}
        double rr=sqrt(se/fmax(1e-30,sr));
        printf("W10-PROBE MODE=0 composed-decode: exact=%d/%d rel_rms=%.3e %s\n",
               exact,M*K,rr, rr<=3e-3?"PASS (composed law recovers swizzled tile)":"FAIL");
        return rr<=3e-3?0:2;
    }

    if(MODE==1){
        // ---- COMPOSED single-tile wgmma probe ----
        const int M=64,N=64,K=8;
        float *hA=(float*)malloc((size_t)M*K*4),*hB=(float*)malloc((size_t)K*N*4);
        float *hD=(float*)malloc((size_t)M*N*4),*hR=(float*)malloc((size_t)M*N*4);
        srand(3);
        for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
        for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];hR[m*N+n]=a;}
        // TMA tiles are swizzle-atom-wide in K (32). Allocate device A/B padded to K=32.
        const int KSW=32;
        float *hApad=(float*)calloc((size_t)M*KSW,4), *hBpad=(float*)calloc((size_t)KSW*N,4);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k)hApad[m*KSW+k]=hA[m*K+k];
        for(int k=0;k<K;++k)for(int n=0;n<N;++n)hBpad[k*N+n]=hB[k*N+n];   // B logical [k][n], K rows padded to 32
        float *dA,*dB,*dD; CK(cudaMalloc(&dA,(size_t)M*KSW*4));CK(cudaMalloc(&dB,(size_t)KSW*N*4));CK(cudaMalloc(&dD,(size_t)M*N*4));
        CK(cudaMemcpy(dA,hApad,(size_t)M*KSW*4,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dB,hBpad,(size_t)KSW*N*4,cudaMemcpyHostToDevice));
        CK(cudaMemset(dD,0,(size_t)M*N*4));
        // A row-major M x KSW, box {32,64} (contiguous K=32 == atom).
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)KSW,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)KSW*4};
          cuuint32_t bd[2]={32,64}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE1 encodeA r=%d\n",(int)r);return 4;} }
        // B row-major KSW x N. Swizzle needs contiguous box(N) == 32. box {32,32}.
        { cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)KSW}; cuuint64_t gs[1]={(cuuint64_t)N*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE1 encodeB r=%d\n",(int)r);return 4;} }
        size_t smsz=(size_t)(M*KSW + N*KSW + M*8 + 8*N)*4 + 8;
        CK(cudaFuncSetAttribute(probe_wgmma,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        probe_wgmma<<<1,128,smsz>>>(tmapA,tmapB,dD,M,N,K);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE1 FAULT %s\n",cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;int exact=0;for(int i=0;i<M*N;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];if(fabs(dd)<1e-4)exact++;}
        double rr=sqrt(se/fmax(1e-30,sr));
        printf("W10-PROBE MODE=1 composed-wgmma: exact=%d/%d rel_rms=%.3e %s\n",
               exact,M*N,rr, rr<=3e-3?"PASS (composed decode feeds wgmma)":"FAIL");
        return rr<=3e-3?0:2;
    }
    if(MODE==3){
        // ---- RAW B-DUMP: measure the true B 32(N)x32(K) SWIZZLE_128B landed layout ----
        // B row-major KxN, contiguous=N. One swizzle atom box {32(N),32(K)}. global B[k][n]=k*32+n.
        const int KK=32, NN=32;
        float* hB=(float*)malloc((size_t)KK*NN*4);
        for(int k=0;k<KK;++k)for(int n=0;n<NN;++n)hB[k*NN+n]=(float)(k*32+n);
        float *dB,*dO; CK(cudaMalloc(&dB,(size_t)KK*NN*4)); CK(cudaMalloc(&dO,(size_t)KK*NN*4));
        CK(cudaMemcpy(dB,hB,(size_t)KK*NN*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapB{};
        cuuint64_t gd[2]={(cuuint64_t)NN,(cuuint64_t)KK}; cuuint64_t gs[1]={(cuuint64_t)NN*4};
        cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
        CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
        if(r!=CUDA_SUCCESS){printf("MODE3 encodeB r=%d\n",(int)r);return 4;}
        size_t smsz=(size_t)(KK*NN)*4 + 8;
        CK(cudaFuncSetAttribute(dump_gen,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        dump_gen<<<1,128,smsz>>>(tmapB,dO,KK*NN);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE3 FAULT %s\n",cudaGetErrorString(e));return 4;}
        float* hO=(float*)malloc((size_t)KK*NN*4);
        CK(cudaMemcpy(hO,dO,(size_t)KK*NN*4,cudaMemcpyDeviceToHost));
        printf("W10-BDUMP 32(N)x32(K) SWIZZLE_128B (phys slot -> landed k*32+n):\n");
        for(int pr=0;pr<8;++pr){              // physical row 0..7 of the single atom
            printf("pr=%d: ",pr);
            for(int pg=0;pg<8;++pg){ int p=pr*32+pg*4; int id=(int)hO[p]; printf("[g%d:k%d,n%d] ",pg,id/32,id%32); }
            printf("\n");
        }
        return 0;
    }
    if(MODE==2){
        // ---- RAW SWIZZLE DUMP: measure the true 128x32 landed layout ----
        const int M=128,K=32;
        float* hA=(float*)malloc((size_t)M*K*4);
        for(int m=0;m<M;++m)for(int k=0;k<K;++k)hA[m*K+k]=(float)(m*32+k); // unique id
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
        // For physical slot p, hO[p] = (m*32+k) of the logical element that landed there.
        // Print the within-atom permutation for the first 8 atoms (rows 0..63) compactly:
        // for each physical row pr in 0..7 of atom 0, list the landed (m,k) per granule.
        printf("W10-DUMP 128x32 SWIZZLE_128B landed layout (phys slot -> landed m*32+k):\n");
        // Atom 0 = physical floats 0..255 (8 rows x 32). Show landed k-granule per (pr,pg).
        for(int atom=0; atom<2; ++atom){
            printf("--- atom %d (phys rows %d..%d) ---\n",atom,atom*8,atom*8+7);
            for(int pr=0;pr<8;++pr){
                printf("pr=%d: ",pr);
                for(int pg=0;pg<8;++pg){
                    int p=atom*256 + pr*32 + pg*4;        // physical slot, granule start
                    int id=(int)hO[p]; int m=id/32,k=id%32;
                    printf("[g%d:m%d,k%d] ",pg,m,k);
                }
                printf("\n");
            }
        }
        // Also derive, per physical (pr,pg) in atom 0, the XOR mask = landed_g XOR pg and
        // whether landed row == pr (is the swizzle row-preserving?).
        printf("--- atom0 granule XOR-mask table (landed_k_granule XOR phys_granule) per row ---\n");
        for(int pr=0;pr<8;++pr){
            printf("pr=%d masks: ",pr);
            for(int pg=0;pg<8;++pg){
                int p=pr*32+pg*4; int id=(int)hO[p]; int k=id%32; int lg=k>>2;
                printf("%d ",lg^pg);
            }
            // landed m for this physical row (should be constant == pr if row-preserving)
            int id0=(int)hO[pr*32]; printf(" | landed_m@g0=%d\n",id0/32);
        }
        return 0;
    }
    if(MODE==4){
        // ---- FULL GEMM: composed-decode swizzled-TMA, bit-exact gate then perf ----
        int NST=argc>3?atoi(argv[3]):3;
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
        // swizzled tmaps: A box{32(K),128(M)}, B box{32(N),32(K)} (B as 32-N atoms).
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
        size_t GMMA=(size_t)(2*64*TKSW + 2*TKSW*64);
        size_t smsz=(size_t)NST*SWBUF*4 + GMMA*4 + (size_t)2*NST*8;
        dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
        CK(cudaFuncSetAttribute(gemm_w10,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_w10<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_w10,blk,smsz);
          printf("OCCUPANCY MODE=4 blk=%d dynsmem=%zuB -> %d CTA/SM (%d compute-thr/SM)\n",blk,smsz,occ,occ*blk); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE4 OWN-FAULT %s\n",cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("W10 S=%d MODE=4 NST=%d rel_rms=%.3e FAIL — no perf (g5)\n",S,NST,rr);return 2;}
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
        printf("W10 S=%d MODE=4 NST=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }
    if(MODE==5){
        // ---- IN-PLACE swizzle-descriptor GEMM: sweep (lbo,sbo,boff), bit-exact gate, perf ----
        int NST=argc>3?atoi(argv[3]):3;
        int ARG_LBO=argc>4?atoi(argv[4]):16; int ARG_SBO=argc>5?atoi(argv[5]):1024; int ARG_BOFF=argc>6?atoi(argv[6]):0;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32){printf("MODE5 needs N%%128==0 && K%%32==0\n");return 1;}
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
          if(r!=CUDA_SUCCESS){printf("MODE5 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE5 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=32;
        size_t BUF=(size_t)(TM*TKSW + TN*TKSW);   // in-place: no gmma bands
        size_t smsz=(size_t)NST*BUF*4 + (size_t)NST*8;
        dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
        CK(cudaFuncSetAttribute(gemm_w10_inplace,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_w10_inplace<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,ARG_LBO,ARG_SBO,ARG_BOFF); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_w10_inplace,blk,smsz);
          printf("OCCUPANCY MODE=5 blk=%d dynsmem=%zuB -> %d CTA/SM (%d compute-thr/SM)\n",blk,smsz,occ,occ*blk); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE5 OWN-FAULT lbo=%d sbo=%d boff=%d %s\n",ARG_LBO,ARG_SBO,ARG_BOFF,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("W10 S=%d MODE=5 NST=%d lbo=%d sbo=%d boff=%d rel_rms=%.3e FAIL — no perf (g5)\n",
            S,NST,ARG_LBO,ARG_SBO,ARG_BOFF,rr);return 2;}
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
        printf("W10 S=%d MODE=5 NST=%d lbo=%d sbo=%d boff=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,ARG_LBO,ARG_SBO,ARG_BOFF,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }
    printf("unknown MODE %d\n",MODE); return 1;
}
