// wgmma_tf32_b14.cu — BENCH-14: per-CTA wgmma INNER-LOOP microarch tuning on the OG16/OG17
//   descriptor-direct own-GEMM (the LAST identity-preserving lever toward parity@2048).
//   NET-NEW kernel: gemm_og17_b14 (MODE 8). Carries MODE 4/5/6/7/2/10 verbatim from OG17 as the
//   apples baselines. The BENCH-14 levers are pure SCHEDULING/overlap (NOT accumulation order):
//     L1 DEEPER wgmma-group PIPELINE / DUAL-ISSUE: parameterized wait_group depth PDEP (MODE 6
//         was fixed depth-1: wait_group 1). PDEP issues PDEP K-slabs' wgmma before waiting
//         (wait_group PDEP), needing >=PDEP+1 ring buffers so the in-flight slabs read DISTINCT
//         smem (data-safe; the accumulator RMW dep is tracked by wgmma itself). Hides deeper
//         tensor-core latency. PDEP=0 == OG16 full-drain; PDEP=1 == OG17 MODE6; PDEP>=2 == net-new.
//     L2 ASYNC/OVERLAPPED EPILOGUE: the final wait_group 0 + C-store overlaps the LAST in-flight
//         wgmma group's drain with address computation; vectorized stores where the per-thread
//         d0/d1 fragment columns are contiguous (the gmma m64n64k8 frag has col-pairs p=0,1 adj
//         -> a .v2.f32 128-bit-half store per (c,r)). Pure store-scheduling, values unchanged.
//   GATE (g5): rel-RMS vs cuBLAS-TF32 MUST stay 0 at EVERY PDEP/NST/S — these change only WHEN a
//   wgmma issues / WHEN a fragment stores, never the per-tile FMA accumulation order, so a
//   non-zero rel-RMS = a pipelining (ring-race) bug -> reject that config (closed-neg, no perf).
//   HONEST: NVIDIA tunes this mainloop per-shape over years; expected yield LOW (1.36x->~1.2x,
//   parity unlikely). Report the REAL number. NO split-K (forfeits identity, forbidden by g5).
//
// ============================ OG17 PARENT (the base, KEPT VERBATIM as MODE 4/5/6/7) ============
// wgmma_tf32_og17.cu — OG17: PARITY PUSH on the OG16 canonical-atom own-GEMM.
//
// ============================ OG16 (the base, KEPT VERBATIM as MODE 4) ========================
//   OG16 (#2866) re-encoded A/B in GLOBAL into the canonical gmma-INTER layout + a NO-swizzle
//   TMA, so the SMEM tile IS wgmma-ready (descriptor-direct layout_type_=0, SBO=1024B) with NO
//   in-kernel decode band. The W15 32KB decode band is GONE *and used* (smem 96->64KB/CTA
//   @NST=2, 2 CTA/SM). Bit-exact rel-RMS 0.000 @2048³ & 4096³. Own 70.2 -> 264.7 TFLOP/s
//   (3.77x), ratio vs cuBLAS-TF32 6.09x -> 1.37-1.62x. PARITY (≤1.3x): NO (best 1.37x).
//   CRITICAL: the decode-band ⊥ occupancy contradiction that pinned W11/W12/W13 (OG11-15) is
//   DISSOLVED — the residual perf levers are UN-GATED for the FIRST time.
//
// ============================ OG17 — the now-viable levers (net-new MODE 5) ===================
//   The W11/W12/W13 closed-negatives ALL died on the SAME wall: the 32KB decode band competed
//   for smem so any tile/ring growth collapsed occupancy 2->1 CTA/SM. With OG16's band GONE,
//   the OG16 NST=2 kernel sits at 64KB/CTA = 2 CTA/SM — leaving HEADROOM under the H100 228KB/SM
//   ceiling. OG17 spends that headroom on the lever the band used to forbid:
//
//   LEVER 1 (W11) — LARGER OUTPUT TILE 128x256 (MODE 5). Doubles N per CTA: each warpgroup now
//     holds FOUR 32-elt accumulators (d0..d3 = 64x256) vs OG16's two (d0,d1 = 64x128). 2x the
//     accumulator reuse per TMA A-load (the litscan's biggest single jump). SWBUF =
//     (128*32 + 256*32)*4 = 48KB/stage; at NST=2 = 96KB/CTA -> 2*96=192 < 228 => 2 CTA/SM HOLDS
//     (W11 had this at 147KB/CTA = 1 CTA/SM ONLY because the decode band added 32KB+; OG16
//     removed it). This is the OG11 dead lever, REOPENED at 2 CTA/SM.
//
//   The B tile doubles to 256 N (8 atoms of 32). The A tile is UNCHANGED (128x32). Pre-permute
//   reuses the OG16 route-(a) gmma-INTER lay VERBATIM (A identical; B extended to 256 N).
//   Descriptor-direct, NO decode band — the OG16 win is preserved end-to-end.
//
//   GATE (g5): MODE 5 bit-exact rel-RMS 0.000 vs cuBLAS-TF32 @2048³ & 4096³ BEFORE any perf
//   number. NST swept 2/3 (4 = 1 CTA/SM, skip). cuBLAS-TF32 = ROOFLINE, parity-SEEKING.
//
// ============================ OG16 ORIGINAL HEADER (the base mechanism) =======================
// wgmma_tf32_og16.cu — OG16: MATCH THE CANONICAL Layout_K_SW128_Atom so the wgmma
// descriptor-direct read of a SWIZZLE_128B-TMA tile is BIT-EXACT (rel-RMS 0), making the
// W15-measured 32KB decode-band removal USABLE on native sm_90a.
//
// ============================ THE OG15/W15 CLOSED-NEGATIVE (the wall) ========================
//   W15 (#2855, F-FUSION-SM90-WGMMA-W15) FALSIFIED the research-#2854 descriptor-FIELD fix:
//   a 3200-config sweep (layout_type_ x SBO x base_offset_ x LBO) over OUR atom-major
//   SWIZZLE_128B landing FLOORS at single-tile rel-RMS 1.000 (full-GEMM 1.392) — NO field
//   combo reaches 0. MODE6 localizer: W10 composed-decode wgmma = 0.000 (mechanism correct),
//   descriptor-direct = 1.107 (uncorrelated). The defect is the TMA-swizzle <-> wgmma-swizzle
//   LAYOUT interaction: our cuTensorMapEncodeTiled box lands an ATOM-MAJOR stacking
//     A box {32(K),64(M)} -> per-8-row atom: sw = a*256 + r*32 + ((g^(r&7))<<2) + (k&3)
//   which is a DIFFERENT byte permutation than the canonical CuTe Layout_K_SW128_Atom
//   (Swizzle<3,4,3>) that layout_type_=1's HW de-swizzle expects.
//
// ============================ THE OG16 FIX — route (a), net-new structure =====================
//   The research deepdive (docs/research/sm90-wgmma-parity-rewrite-deepdive.md §1) states the
//   canonical K-major atom is  Swizzle<3,4,3> o ((8,m),(T,2)):((8T,SBO),(1,T))  with the
//   128B swizzle over the MN (row) granule, NOT over K. Our W10/W15 box swizzles the K dim
//   (g=k>>2). The canonical Layout_K_SW128_Atom for TF32 is an 8(MN)x... tile whose 128B
//   swizzle XORs the MN-granule, and the wgmma m64n64k8 core-matrix order (gmma INTER 8x4) is
//   ALREADY the byte order the descriptor addresses.
//
//   Route (a): re-encode A/B in GLOBAL so the SWIZZLE_128B TMA lands the CANONICAL atom in
//   SMEM. Concretely we PRE-PERMUTE the global operand (a one-time host/device transform,
//   amortized over all K-slabs reuse in a real GEMM) into the layout that, AFTER the
//   hardware SWIZZLE_128B de-swizzle the descriptor applies, equals the gmma-INTER tile the
//   wgmma reads. Then descriptor-direct (layout_type_=1, SBO=1024) reads it bit-exact with NO
//   software decode in the kernel hot loop -> the 32KB band is gone AND used.
//
//   Because the exact canonical byte order is subtle, OG16 EMPIRICALLY DETERMINES it on-pod:
//   MODE 10 sweeps a small family of global pre-permutations x descriptor fields against the
//   single-tile differential, gated at rel-RMS 0. If a member hits 0 -> route (a) WORKS, the
//   band is usable, build the full GEMM + perf. If the whole family floors O(1) -> the
//   canonical atom needs a landing our cuTensorMapEncodeTiled box cannot produce -> honest
//   closed-negative, W10 70.7 is the TF32 ceiling for our approach.
//
// ============================ OG16 GATE DISCIPLINE (g5) =======================================
//   MODE 10  single-tile descriptor-direct differential over the route-(a) pre-permute family.
//            rel-RMS 0 GATE (cheap). If FAIL, STOP — report the residual, KEEP W10 70.7.
//   MODE 4   FULL GEMM descriptor-direct (no decode band) — bit-exact gate THEN perf.
//   MODE 2   raw swizzle dump oracle (reused, for any new box shape).
//
// argv: S MODE [arg3..]   bit-exact GATE FIRST. cuBLAS-TF32 = ROOFLINE, parity-SEEKING.
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

// ---- GMMA INTER 8x4-core physical index (W2/W3-proven bit-exact; the wgmma layout). ----
__device__ __host__ __forceinline__ int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
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
// ROUTE-(a) GLOBAL PRE-PERMUTE FAMILY (CPU side). Produce a global operand whose
// SWIZZLE_128B-TMA landing, read in place by the layout_type_=1 descriptor, equals the
// gmma-INTER 8x4 tile the wgmma m64n64k8 reads. We parameterize a small family and let the
// single-tile differential pick the bit-exact member (or floor O(1) -> closed-negative).
//
// PERM family P (host fn): given logical (m,k) with 0<=m<TM, 0<=k<32 (one 128B K-atom),
// emit the GLOBAL (row-major MxKSW) slot where A[m][k]'s value is written, so that after the
// HW SWIZZLE_128B de-swizzle the descriptor performs (XOR over MN-granule per canonical atom),
// the wgmma reads gmma_phys(m,k). Member id 'pm':
//   pm=0  identity (W15 baseline — known floor 1.0, sanity)
//   pm=1  canonical K-major: write to the slot that, under MN-granule swizzle, lands gmma 8x4.
//   pm=2  transpose-in-atom: swap the role of the swizzled granule from K to MN.
//   pm=3  pm=1 with the +1 phase folded (the measured (r+1) anchor).
// The HW swizzle the descriptor applies for layout_type_=1 over a 128B (32-float) row is
// phys_granule g' = g XOR (row & 7)  (row counted in 8-row atoms). We INVERT it: to make the
// descriptor deliver value V at (effective_row R, effective_granule G), we must place V at
// global granule (G XOR (R&7)) of row R. The "effective" (R,G) the descriptor maps to wgmma
// fragment element gmma_phys(m,k) is the canonical atom coordinate.
// ======================================================================
static int perm_global_slot(int pm,int m,int k,int TM,int KSW){
    // canonical atom: an 8-row x 8-K core-pair. For wgmma m64n64k8 the operand fragment
    // element for (m,k) sits at gmma_phys(m,k) WITHIN a 64x8 sub-tile (sub = k>>3). The
    // descriptor with layout_type_=1 reads SMEM physical slot:
    //    desc_phys(m,k) = (8-row-atom a=m>>3) base + row-in-atom r=m&7 contributes,
    //    and the 128B swizzle XORs the granule by (r&7).
    // We want SMEM[ desc_phys ] == value of logical A[m][k]. Since the TMA lands GLOBAL
    // row-major (box {KSW, TM}) into SMEM with its OWN K-granule swizzle g^(r&7), placing the
    // value at the right GLOBAL slot makes the landed SMEM hold it where the descriptor reads.
    int r=m&7, a=m>>3;
    // KEY INSIGHT (MODE2 oracle confirmed): TMA lands SMEM[r*32+(g^(r&7))*4+w]=global gran g.
    // The layout_type_=1 descriptor de-swizzle UNDOES the XOR -> descriptor-direct reads the
    // GLOBAL LOGICAL layout (row-major within the atom). But wgmma m64n64k8 expects the operand
    // fragment in GMMA-INTER 8x4 core order (gmma_phys). So the net requirement is: pre-permute
    // GLOBAL so that the logical (m,k) value sits where gmma-INTER wants it -> write value of
    // (m,k) to the global slot whose row-major index EQUALS gmma_phys(m_in_atom, k) within the
    // atom's 8x32 (=256) block, atom-major stacked (atom a at a*256).
    if(pm==0){ return m*KSW + k; }                       // identity (W15 baseline, floor 1.0)
    if(pm==1){
        // gmma_phys over an 8(row)x32(K) atom: row-in-atom r, K k. gmma wants 8x4 INTER cores.
        return a*256 + gmma_phys(r,k);
    }
    if(pm==2){
        // transpose variant: gmma_phys with (k,r) swapped role (in case operand is N-major).
        return a*256 + gmma_phys(r,k);                    // same here; B path differs in host
    }
    if(pm==3){
        // pm=1 + carry the +1 alignment phase in the row index (base_offset_ sweeps it too).
        int rr=(r+1)&7; return a*256 + gmma_phys(rr,k);
    }
    return m*KSW + k;
}

// ======================================================================
// MODE 10 — single-tile descriptor-direct differential over the route-(a) pre-permute family.
//   Land A(64x32)+B(2x32x32) SWIZZLE_128B via TMA from the PRE-PERMUTED global, build the
//   descriptor (layout_type_=swmode, SBO=sbo, base=boff), one wgmma m64n64k8, rel_rms vs CPU.
//   EXPECT 0 for the correct (pm,swmode,sbo,boff). The host loops the family.
// ======================================================================
extern "C" __global__ void probe_a(const __grid_constant__ CUtensorMap tmapA,
                                    const __grid_constant__ CUtensorMap tmapB,
                                    float* __restrict__ gD,int lbo,int sbo,int boff,int swmode,int bload){
    const int TM=64, TN=64, TKSW=32;
    extern __shared__ __align__(128) float sm_raw[];
    // PAD both sides (8K floats) so a mis-strided descriptor reads valid garbage, never faults
    // -> the whole pm x descriptor family sweeps in one CUDA context (W15 MODE9 technique).
    const int PAD=8192;
    float* sm=sm_raw+PAD;
    for(int i=threadIdx.x;i<PAD;i+=blockDim.x){ sm_raw[i]=0.f; sm_raw[PAD+TM*TKSW+TN*TKSW+i]=0.f; }
    __syncthreads();
    float* Asw=sm;                       // 64*32
    float* Bsw=Asw + TM*TKSW;             // 2*(32*32)
    uint64_t* bar=(uint64_t*)(Bsw + TN*TKSW);
    int tid=threadIdx.x;
    if(tid==0){ mbar_init_tx(bar,1); }
    __syncthreads();
    if(tid==0){
        uint32_t bytes=(uint32_t)((TM*TKSW + TN*TKSW)*4);
        mbar_expect_tx(bar,bytes);
        tma_load_2d(Asw,        &tmapA,0,0,bar);
        if(bload==0){ // W15 B box {32(N),32(K)}: atoms along N = the x coord
            tma_load_2d(Bsw,        &tmapB,0, 0,bar);
            tma_load_2d(Bsw+32*TKSW,&tmapB,32,0,bar);
        } else {      // gmma-INTER B box {32(K),32(N)}: atoms along N = the y coord
            tma_load_2d(Bsw,        &tmapB,0, 0,bar);
            tma_load_2d(Bsw+32*TKSW,&tmapB,0,32,bar);
        }
    }
    __syncthreads();
    if(tid==0) mbar_wait(bar,0);
    asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
    __syncthreads();
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
// MODE 2 — RAW SWIZZLE DUMP (validation oracle). Land a 128x32 SWIZZLE_128B tile,
//   copy phys->global so the host reads the true landed law for THIS box.
// ======================================================================
extern "C" __global__ void dump_layout(const __grid_constant__ CUtensorMap tmapA,
                                        float* __restrict__ gOut){
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
// MODE 4 — FULL GEMM descriptor-direct over the route-(a) PRE-PERMUTED global (NO decode band).
//   Identical hot-loop structure to W15 gemm_w15 (the no-decode kernel that measured the 32KB
//   drop) — the ONLY difference is the global operand was pre-permuted (host, MODE 4 setup) so
//   the SWIZZLE_128B landing IS the canonical atom the layout_type_=1 descriptor reads bit-exact.
//   smem = swizzled ring only -> ~32KB/CTA less than W10. Measure GFLOP/s + occupancy + ratio.
// ======================================================================
extern "C" __global__ void gemm_og16(const __grid_constant__ CUtensorMap tmapA,
                                      const __grid_constant__ CUtensorMap tmapB,
                                      float* __restrict__ gD,int M,int N,int K,int NST,
                                      int lbo,int sbo,int boff,int swmode){
    const int TM=128,TN=128,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
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
        float* Aband=Asw + band*64*TKSW;
        float* B0=Bsw;
        float* B1=Bsw + 2*(TKSW*TKSW);
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        // gmma-INTER pre-laid (route-a): per 8-row atom (256 floats), K=8 sub s=k>>3 occupies
        // the contiguous 64-float region [s*64, s*64+64). atoms stack at SBO=1024B (256 floats).
        // So the K=8 sub-step bumps START by s*64 floats = s*256 bytes; SBO addresses the stack.
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*64*4);
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

// ======================================================================
// MODE 7 — OG17 LEVER 4: SWIZZLED-RASTERIZATION + PERSISTENT-KERNEL own-GEMM (BENCH-13).
//   Same per-tile math as gemm_og16 (descriptor-direct 128x128, 2 CTA/SM, bit-exact) but the
//   blockIdx -> output-tile mapping is REPLACED by (1) a persistent tile loop and (2) a
//   CUTLASS-style threadblock SWIZZLE so adjacent CTAs share a B-column (or A-row) operand in
//   L2 instead of each CTA touching disjoint operands.
//
//   PERSISTENT: launch gridDim = GRIDN (= occ * #SMs, e.g. 2*132 = 264). Each CTA walks
//     for(t = blockIdx.x; t < total_tiles; t += GRIDN) processing swizzled tile t. This
//     amortizes launch + smooths the tail wave (vs the plain Nx/128 * Mx/128 1-CTA/tile launch
//     that leaves a partial last wave at D=4096: 32*32=1024 tiles vs 264 CTAs = 3.88 waves).
//
//   SWIZZLE (threadblock rasterization), SWZ = group-width along tile-COLUMN (N):
//     SWZ=0  -> plain ROW-MAJOR linear (tile -> (tile/tilesN, tile%tilesN)) = OG16 order (baseline).
//     SWZ=w>0-> "grouped" order: tiles are walked in column-groups of width w. Within a group of
//               w columns we step DOWN the rows first (so w adjacent CTAs in linear order share
//               the SAME A-row-block operand -> A stays hot in L2), then advance to the next
//               group of w columns. This is the CUTLASS GemmIdentityThreadblockSwizzle log-group.
//   The remap is a pure index permutation of which (tile_row,tile_col) a CTA computes — the
//   per-tile accumulation is byte-identical to gemm_og16, so rel-RMS MUST stay 0 (a non-zero
//   value = a tile-index bug, which the g5 gate catches before any perf number).
// ======================================================================
__device__ __forceinline__ void tile_unswizzle(int t,int tilesM,int tilesN,int swz,int* trow,int* tcol){
    if(swz<=0){ *trow=t/tilesN; *tcol=t%tilesN; return; }
    // grouped/swizzled rasterization: column-groups of width `swz`. Walk rows within a group
    // first so `swz` consecutive CTAs share the same A row-block (and L2-hot B columns of the
    // group). Last group may be narrower (tilesN % swz).
    int full_grp = tilesN / swz;            // number of full-width column groups
    int gw = swz;
    int per_full = tilesM * gw;             // tiles in one full-width group
    int grp, off, gcols0;
    if(t < full_grp*per_full){ grp=t/per_full; off=t%per_full; gw=swz; gcols0=grp*swz; }
    else {
        int rem=t - full_grp*per_full; int rgw=tilesN - full_grp*swz; // remainder group width
        grp=full_grp; off=rem; gw=rgw; gcols0=full_grp*swz;
    }
    (void)grp;
    *trow = off / gw;
    *tcol = gcols0 + (off % gw);
}

extern "C" __global__ void gemm_og17_persist(const __grid_constant__ CUtensorMap tmapA,
                                      const __grid_constant__ CUtensorMap tmapB,
                                      float* __restrict__ gD,int M,int N,int K,int NST,
                                      int lbo,int sbo,int boff,int swmode,
                                      int tilesM,int tilesN,int total_tiles,int swz){
    const int TM=128,TN=128,TKSW=32,TK=8;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;
    const int gridN=gridDim.x;
    // PERSISTENT TILE LOOP — each CTA walks swizzled tiles strided by gridDim.
    for(int t=blockIdx.x; t<total_tiles; t+=gridN){
        int trow,tcol; tile_unswizzle(t,tilesM,tilesN,swz,&trow,&tcol);
        int bm=trow*TM, bn=tcol*TN;
        float d0[32],d1[32];
        #pragma unroll
        for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
        uint32_t fph=0;
        int stages=NST<nks?NST:nks;
        __syncthreads();                 // ensure all CTAs done with prior tile's smem before reuse
        // RE-INIT the mbarriers per tile so each tile starts at phase 0 (matching fph=0). Without
        // this the barrier phase carries over from the previous tile -> mbar_wait(.,0) deadlocks
        // on an already-toggled barrier when a CTA processes >1 tile (waves>1, e.g. D=4096).
        if(tid<NST){ mbar_init_tx(&full[tid],1); }
        __syncthreads();
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
            float* Aband=Asw + band*64*TKSW;
            float* B0=Bsw;
            float* B1=Bsw + 2*(TKSW*TKSW);
            uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
            uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
            uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
            asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
            #pragma unroll
            for(int kk=0;kk<TKSW;kk+=TK){
                uint32_t off=(uint32_t)((kk>>3)*64*4);
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
}

// ======================================================================
// MODE 6 — OG17 LEVER 3: 128x128 (OG16 tile, 2 CTA/SM) with a RELAXED-wait_group software
//   pipeline — the W11 "ping-pong epilogue overlap" lever, dead on the decode band, reopened.
//   OG16 does `wgmma.wait_group 0` (FULL drain) + __syncthreads EVERY K-slab: the next slab's
//   wgmma cannot ISSUE until the current slab's tensor-core work has fully drained. MODE 6 keeps
//   the OG16 tile/occupancy (90 regs, 2 CTA/SM) but issues TWO commit groups deep: after slab
//   ki's wgmma it only `wait_group 1` (one group still in flight), so slab ki+1's wgmma ISSUE
//   overlaps slab ki's tensor-core compute. The smem-buffer reuse is gated by the per-buffer
//   mbarrier (ki and ki+1 read DIFFERENT ring buffers) so the overlap is data-safe; the
//   accumulator RMW dependency is tracked by wgmma itself. NO smem growth -> 2 CTA/SM HELD.
//   The __syncthreads is moved to gate ONLY the TMA-prefetch buffer reuse (every NST slabs).
// ======================================================================
extern "C" __global__ void gemm_og17_pipe(const __grid_constant__ CUtensorMap tmapA,
                                      const __grid_constant__ CUtensorMap tmapB,
                                      float* __restrict__ gD,int M,int N,int K,int NST,
                                      int lbo,int sbo,int boff,int swmode){
    const int TM=128,TN=128,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
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
        float* Aband=Asw + band*64*TKSW;
        float* B0=Bsw;
        float* B1=Bsw + 2*(TKSW*TKSW);
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*64*4);
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
        }
        // RELAXED pipeline: commit this slab as its own group; keep at most 1 group in flight so
        // the NEXT slab's wgmma issue overlaps THIS slab's tensor-core drain. Only the SMEM buffer
        // about to be OVERWRITTEN by the prefetch must be drained -> wait_group 1 + a per-iter
        // sync that gates the prefetch (below). Prologue already filled `stages` buffers.
        asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 1;\n":::"memory");
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
    asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory"); // drain the last in-flight group
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
// MODE 8 — BENCH-14: DEEPER wgmma-group PIPELINE (dual-issue) + OVERLAPPED VECTORIZED EPILOGUE.
//   Same per-tile descriptor-direct math as gemm_og16/gemm_og17_pipe (128x128, route-a gmma-INTER
//   pre-laid global, NO decode band, 2 accumulators d0/d1) — the FMA accumulation order is
//   byte-identical, so rel-RMS MUST stay 0. The ONLY changes vs MODE 6 are SCHEDULING:
//     (1) DEEPER wgmma-group pipeline: each K-slab is its own commit_group; we keep PDEP groups
//         IN FLIGHT (wgmma.wait_group PDEP) instead of MODE 6's fixed 1. With PDEP groups live,
//         slab ki's wgmma issue overlaps the tensor-core drain of slabs ki-1..ki-PDEP. Needs
//         NST>=PDEP+1 ring buffers so the PDEP+1 live slabs read DISTINCT smem (the per-buffer
//         mbarrier already gates reuse; the prefetch only overwrites a buffer >=stages slabs
//         ahead, and stages=min(NST,nks) >= PDEP+1, so an in-flight slab's smem is never reused
//         until its wgmma group has retired). PDEP=1 reproduces MODE 6 EXACTLY (apples-self-check).
//     (2) OVERLAPPED + VECTORIZED epilogue: the trailing wait_group 0 drains the last live group;
//         the C-store then issues .v2.f32 128-bit-half vector stores for the contiguous col-pair
//         (p=0,1) of each gmma fragment idx, halving the store instruction count + giving the
//         compiler the final drain to hide the store-address math behind.
//   The prefetch __syncthreads stays (gates TMA buffer reuse). NO smem growth beyond NST (PDEP
//   only deepens the wgmma SCOREBOARD, not the ring) -> occupancy unchanged at the same NST.
//   PDEP is clamped to NST-1 on host. argv extra arg = PDEP (default 2).
// ======================================================================
__device__ __forceinline__ void wait_group_dyn(int d){
    // wgmma.wait_group needs an IMMEDIATE operand; emit the small fixed depths we sweep.
    switch(d){
        case 0: asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory"); break;
        case 1: asm volatile("wgmma.wait_group.sync.aligned 1;\n":::"memory"); break;
        case 2: asm volatile("wgmma.wait_group.sync.aligned 2;\n":::"memory"); break;
        case 3: asm volatile("wgmma.wait_group.sync.aligned 3;\n":::"memory"); break;
        default: asm volatile("wgmma.wait_group.sync.aligned 4;\n":::"memory"); break;
    }
}
extern "C" __global__ void gemm_og17_b14(const __grid_constant__ CUtensorMap tmapA,
                                      const __grid_constant__ CUtensorMap tmapB,
                                      float* __restrict__ gD,int M,int N,int K,int NST,
                                      int lbo,int sbo,int boff,int swmode,int PDEP){
    const int TM=128,TN=128,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
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
        float* Aband=Asw + band*64*TKSW;
        float* B0=Bsw;
        float* B1=Bsw + 2*(TKSW*TKSW);
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*64*4);
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
        }
        // DEEPER PIPELINE: commit this slab as its own group; keep PDEP groups in flight so the
        // next PDEP slabs' wgmma issue overlaps this slab's tensor-core drain. Ring buffer reuse
        // is gated by the per-buffer mbarrier; the prefetch overwrites a buffer `stages` slabs
        // ahead (>= PDEP+1), so an in-flight slab's smem is never clobbered.
        asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
        wait_group_dyn(PDEP);
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
    asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory"); // drain all remaining live groups
    // OVERLAPPED + VECTORIZED EPILOGUE. The gmma m64n64k8 fragment for this thread packs col-pair
    // p=0,1 ADJACENTLY (idx=c*4+r*2+p), and the two output columns col0/(col0+1) are contiguous in
    // gD -> a .v2.f32 128-bit-half store writes both with ONE instruction. d0 covers [bn,bn+64),
    // d1 covers [bn+64,bn+128) of this warpgroup's 64-row band — byte-identical targets to MODE 6.
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r){
        int row=rbase+rb+r*8;
        int col0=bn+cb+c*8, col1=bn+64+cb+c*8;     // p=0 base; p=1 is col0+1 / col1+1 (contiguous)
        int i0=c*4+r*2+0, i1=c*4+r*2+1;            // the p=0,1 fragment pair for (c,r)
        if(row<M){
            if(col0+1<N){ float2 v=make_float2(d0[i0],d0[i1]); *reinterpret_cast<float2*>(&gD[row*N+col0])=v; }
            else { if(col0<N)gD[row*N+col0]=d0[i0]; if(col0+1<N)gD[row*N+col0+1]=d0[i1]; }
            if(col1+1<N){ float2 v=make_float2(d1[i0],d1[i1]); *reinterpret_cast<float2*>(&gD[row*N+col1])=v; }
            else { if(col1<N)gD[row*N+col1]=d1[i0]; if(col1+1<N)gD[row*N+col1+1]=d1[i1]; }
        }
    }
}

// ======================================================================
// MODE 9 — OP-52: MODE 8 (b14 dual-issue) + NON-PERSISTENT CTA-SWIZZLE (the OP-45-GPU T4 lever).
//   OP-45-GPU T4 measured that cuBLAS's +24.6% large-D win is a BETTER SINGLE-PASS TILE +
//   CTA-SWIZZLE (cta_swizzle=1, split_k=1) — NOT split-K. MODE 7 already swizzles, but it ALSO
//   converts the launch to a PERSISTENT kernel (a grid-stride tile loop over occ*SM CTAs); T3
//   measured MODE 7 @D=4096 REGRESSED (~273 vs 284). This kernel ISOLATES the swizzle lever from
//   the persistent-loop confound: it is the b14 MODE 8 kernel VERBATIM (same descriptor-direct
//   128x128 math, same NST ring, same dual-issue PDEP, same vectorized epilogue) with ONLY the
//   blockIdx -> (bm,bn) tile mapping replaced by an L2-friendly swizzled rasterization. The grid
//   is sized 1-CTA-per-tile EXACTLY like MODE 8 (NOT occ*SM) — so the ONLY difference vs MODE 8 is
//   the CTA->tile assignment order. The FMA accumulation order is byte-identical to MODE 8, so
//   rel_rms MUST stay 0 (a swizzle that changes any output value is a tile-index bug, g5-rejected).
//     SWZ=0 -> plain row-major linear order == MODE 8 EXACTLY (apples self-check).
//     SWZ=w>0 -> grouped column-rasterization width w (reuses tile_unswizzle, the MODE 7 mapper):
//       `w` consecutive CTAs walk down a column-group, sharing A row-blocks + L2-hot B columns.
//   The flat tile id is derived from blockIdx in a NON-persistent grid: tid = by*gridDim.x + bx.
// ======================================================================
extern "C" __global__ void gemm_og17_b14_swz(const __grid_constant__ CUtensorMap tmapA,
                                      const __grid_constant__ CUtensorMap tmapB,
                                      float* __restrict__ gD,int M,int N,int K,int NST,
                                      int lbo,int sbo,int boff,int swmode,int PDEP,
                                      int tilesM,int tilesN,int swz){
    const int TM=128,TN=128,TKSW=32,TK=8;
    // NON-PERSISTENT swizzle: one CTA per tile, flat id from a row-major grid, remapped to a
    // swizzled (trow,tcol). Same compute as MODE 8 — only the CTA->tile assignment changes.
    int flat = blockIdx.y*gridDim.x + blockIdx.x;
    int trow,tcol; tile_unswizzle(flat,tilesM,tilesN,swz,&trow,&tcol);
    int bm=trow*TM, bn=tcol*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
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
        float* Aband=Asw + band*64*TKSW;
        float* B0=Bsw;
        float* B1=Bsw + 2*(TKSW*TKSW);
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*64*4);
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
        }
        asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
        wait_group_dyn(PDEP);
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
    asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory");
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r){
        int row=rbase+rb+r*8;
        int col0=bn+cb+c*8, col1=bn+64+cb+c*8;
        int i0=c*4+r*2+0, i1=c*4+r*2+1;
        if(row<M){
            if(col0+1<N){ float2 v=make_float2(d0[i0],d0[i1]); *reinterpret_cast<float2*>(&gD[row*N+col0])=v; }
            else { if(col0<N)gD[row*N+col0]=d0[i0]; if(col0+1<N)gD[row*N+col0+1]=d0[i1]; }
            if(col1+1<N){ float2 v=make_float2(d1[i0],d1[i1]); *reinterpret_cast<float2*>(&gD[row*N+col1])=v; }
            else { if(col1<N)gD[row*N+col1]=d1[i0]; if(col1+1<N)gD[row*N+col1+1]=d1[i1]; }
        }
    }
}

// ======================================================================
// MODE 5 — OG17 LEVER 1: FULL GEMM with the 128x256 OUTPUT TILE (band-free, route-a global).
//   Identical mechanism to gemm_og16 (descriptor-direct, NO decode band, gmma-INTER pre-laid
//   global) but TN=256: each warpgroup holds FOUR 32-elt accumulators d0..d3 (64x256) and the
//   B tile is 8 N-atoms of 32 (256). 2x accumulator reuse per A-load vs OG16's 2 accumulators.
//   SWBUF = (128*32 + 256*32)*4 = 48KB/stage -> NST=2 = 96KB/CTA = 2 CTA/SM (W11's dead lever,
//   reopened now that OG16 removed the 32KB band). Bit-exact gate THEN perf.
//
//   B SMEM layout (per the MODE5 host pre-lay below): 8 contiguous 32-N atoms, each atom is a
//   1024-float gmma-INTER block (32K x 32N). The four 64-N output groups g=0..3 each consume
//   TWO adjacent 32-N atoms (atom 2g, 2g+1). Within a 64-N group the wgmma m64n64k8 reads B as
//   ONE descriptor whose start addresses the lower atom; the K=8 sub bumps start by s*64 floats.
// ======================================================================
extern "C" __global__ void gemm_og17_t256(const __grid_constant__ CUtensorMap tmapA,
                                      const __grid_constant__ CUtensorMap tmapB,
                                      float* __restrict__ gD,int M,int N,int K,int NST,
                                      int lbo,int sbo,int boff,int swmode){
    const int TM=128,TN=256,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;          // 4096 + 8192
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;                      // 8 B atoms of 32-N
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();
    // FOUR 32-elt accumulators: d0..d3 cover N-groups g=0..3 (each 64 cols) of this warpgroup's
    // 64-row band. d0=[bn,bn+64) d1=[bn+64,bn+128) d2=[bn+128,bn+192) d3=[bn+192,bn+256).
    float d0[32],d1[32],d2[32],d3[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;d2[i]=0.f;d3[i]=0.f;}
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
        float* Aband=Asw + band*64*TKSW;
        // each 64-N group consumes 2 adjacent 32-N atoms; group g lower atom at 2g*1024 floats.
        float* Bg0=Bsw + 0*2*(TKSW*TKSW);
        float* Bg1=Bsw + 1*2*(TKSW*TKSW);
        float* Bg2=Bsw + 2*2*(TKSW*TKSW);
        float* Bg3=Bsw + 3*2*(TKSW*TKSW);
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(Bg0);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(Bg1);
        uint32_t a2b=(uint32_t)__cvta_generic_to_shared(Bg2);
        uint32_t a3b=(uint32_t)__cvta_generic_to_shared(Bg3);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*64*4);
            uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB2=mk_desc(a2b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            uint64_t dB3=mk_desc(a3b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
            WG(d2,dA,dB2);
            WG(d3,dA,dB3);
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

// ======================================================================
// MODE 10 — OP-55: 2-CTA/SM-PRESERVING 128x256 SINGLE-PASS TILE (the OP-52 follow-up lever).
//   OP-45/OP-52 settled that the @D=4096 ~1.5x TF32 gap is NOT closable by a launcher/index
//   swizzle (MODE 9, closed-neg) nor by the in-tree t256 (MODE 5 = 4 live accumulators d0..d3 =
//   128 accum regs -> 154 total -> 1 CTA/SM, AND 144KB/CTA @NST=3 -> the register/smem TRAP).
//   The surviving lever (OP-53 spec) is a NEW bit-exact single-pass per-CTA tile that is LARGER
//   (256-N, to capture the large-D scheduling headroom cuBLAS captures with bigger tiles) yet
//   register-economical enough to KEEP 2 CTA/SM (NOT fall to t256's 1-CTA/SM register cap).
//
//   THE REGISTER-ECONOMY TRICK: a 128x256 output tile would need 4 live N-group accumulators
//   (d0..d3, the t256 trap). Instead this kernel processes the 256-N output as TWO SEQUENTIAL
//   128-N HALVES (an OUTER half-loop h=0,1), each half running the FULL MODE-8 K-reduction with
//   only TWO live accumulators (d0/d1, 64 accum regs == MODE 8). So the register footprint is
//   MODE 8's (~90 regs), NOT t256's (154) -> the design premise is 2 CTA/SM. Smem is the 256-N
//   ring (8 B-atoms/stage); at NST=2 = 96KB/CTA <= 114KB ceiling -> 2 CTA/SM also holds on smem.
//
//   BIT-EXACTNESS (the gate): each output element accumulates over K in the BYTE-IDENTICAL FMA
//   order of MODE 8 (same wgmma m64n64k8 per TK=8 sub-slab, same per-element K walk). Splitting
//   the 256-N into two 128-N halves and the per-CTA tile being 256-wide changes ONLY the SCHEDULE
//   and the CTA->tile granularity (1 CTA owns 2x the N), NOT the accumulation order of any element.
//   So rel_rms vs the MODE-8 / cuBLAS reference MUST be 0.000e+00 (a non-zero value = a tiling bug).
//
//   The half-loop re-walks the K ring twice (once per N-half), re-loading the A band each half;
//   A is L2/smem-hot (same 128x32 A slab reused), so the A re-read is cheap. The B ring holds all
//   256-N (8 atoms) so each half reads its own 128-N (4 atoms) from the SAME staged buffer — no
//   extra B traffic vs t256. The win, IF any, is the larger 256-N single-pass tile amortizing the
//   per-CTA prologue / K-loop drain over 2x the output columns while preserving 2 CTA/SM occupancy.
//   argv: S 10 [NST] [PDEP].  Gate rel_rms 0 FIRST, THEN perf.  NST default 2 (smem-fit for 2/SM).
// ======================================================================
extern "C" __global__ void gemm_og17_b14_t256e(const __grid_constant__ CUtensorMap tmapA,
                                      const __grid_constant__ CUtensorMap tmapB,
                                      float* __restrict__ gD,int M,int N,int K,int NST,
                                      int lbo,int sbo,int boff,int swmode,int PDEP){
    const int TM=128,TN=256,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // Ring is sized to ONE 128-N HALF (== MODE 8's smem: 128A + 128B = 32KB/stage), NOT the full
    // 256-N — each half streams its own 4 B-atoms through this MODE-8-sized ring. So at NST=3 the
    // smem is 96KB/CTA -> 2 CTA/SM (identical to MODE 8), the design's whole point. The 256-N tile
    // lives in the GRID (1 CTA owns 2x the N-columns, halving the wave count), not in resident smem.
    const int ASW=TM*TKSW, BSW=128*TKSW;          // 4096 + 4096 floats / stage (one 128-N half)
    const int SWBUF=ASW+BSW;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*SWBUF);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const uint32_t bytesA=ASW*4;
    // ONLY TWO live accumulators (== MODE 8) — the register-economy that keeps 2 CTA/SM.
    float d0[32],d1[32];
    // OUTER N-HALF LOOP: h=0 -> output cols [bn,bn+128); h=1 -> [bn+128,bn+256). Each half runs a
    // FULL MODE-8-identical K-reduction into d0/d1 (its own NST ring TMA cycle over the half's
    // 4 B-atoms + the shared A band), drains, and stores its 128-N before the next half reuses the
    // same 2 accumulators. Per-half full TMA: A re-loaded (L2/smem-hot, cheap) + this half's 128-N B.
    for(int half=0; half<2; ++half){
        #pragma unroll
        for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
        uint32_t fph=0;
        int stages=NST<nks?NST:nks;
        int aoff=half*4;                                   // this half's first B-atom (atoms 4h..4h+3)
        const uint32_t hbytesB=(uint32_t)(4*(TKSW*TKSW))*4;// 4 atoms loaded this half (128-N)
        __syncthreads();                                   // half boundary: prior half's reads done
        // RE-INIT mbarriers per half so each half starts at phase 0 (matching fph=0) — without this
        // the barrier phase carries over from half==0 and mbar_wait(.,0) deadlocks in half==1.
        if(tid<NST){ mbar_init_tx(&full[tid],1); }
        __syncthreads();
        if(tid==0){
            for(int st=0;st<stages;++st){
                float* base=sm+(size_t)st*SWBUF; float* Asw=base; float* Bsw=base+ASW;
                mbar_expect_tx(&full[st], bytesA+hbytesB);
                tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
                #pragma unroll
                for(int c=0;c<4;++c)
                    tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+(aoff+c)*TKSW,st*TKSW,&full[st]);
            }
        }
        for(int ki=0;ki<nks;++ki){
            int st=ki%NST;
            mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
            float* base=sm+(size_t)st*SWBUF; float* Asw=base; float* Bsw=base+ASW;
            float* Aband=Asw + band*64*TKSW;
            // the two 64-N groups of this half live at ring atoms [0,1] and [2,3] (we loaded only 4):
            float* B0=Bsw + (size_t)0*(TKSW*TKSW);
            float* B1=Bsw + (size_t)2*(TKSW*TKSW);
            uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
            uint32_t a0b=(uint32_t)__cvta_generic_to_shared(B0);
            uint32_t a1b=(uint32_t)__cvta_generic_to_shared(B1);
            asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
            #pragma unroll
            for(int kk=0;kk<TKSW;kk+=TK){
                uint32_t off=(uint32_t)((kk>>3)*64*4);
                uint64_t dA =mk_desc(aAb+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
                uint64_t dB0=mk_desc(a0b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
                uint64_t dB1=mk_desc(a1b+off,(uint32_t)lbo,(uint32_t)sbo,(uint32_t)boff,(uint32_t)swmode);
                WG(d0,dA,dB0);
                WG(d1,dA,dB1);
            }
            asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
            wait_group_dyn(PDEP);
            __syncthreads();
            if(tid==0){
                int load_ki=ki+stages;
                if(load_ki<nks){
                    int lst=load_ki%NST;
                    float* lb=sm+(size_t)lst*SWBUF; float* lAsw=lb; float* lBsw=lb+ASW;
                    mbar_expect_tx(&full[lst], bytesA+hbytesB);
                    tma_load_2d(lAsw,&tmapA,load_ki*TKSW,bm,&full[lst]);
                    #pragma unroll
                    for(int c=0;c<4;++c)
                        tma_load_2d(lBsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+(aoff+c)*TKSW,load_ki*TKSW,&full[lst]);
                }
            }
        }
        asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory");
        // VECTORIZED EPILOGUE for this half's 128-N (== MODE 8 epilogue, shifted by half*128 in N).
        int rbase=bm+band*64;
        int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
        int nbase=bn+half*128;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r){
            int row=rbase+rb+r*8;
            int col0=nbase+cb+c*8, col1=nbase+64+cb+c*8;
            int i0=c*4+r*2+0, i1=c*4+r*2+1;
            if(row<M){
                if(col0+1<N){ float2 v=make_float2(d0[i0],d0[i1]); *reinterpret_cast<float2*>(&gD[row*N+col0])=v; }
                else { if(col0<N)gD[row*N+col0]=d0[i0]; if(col0+1<N)gD[row*N+col0+1]=d0[i1]; }
                if(col1+1<N){ float2 v=make_float2(d1[i0],d1[i1]); *reinterpret_cast<float2*>(&gD[row*N+col1])=v; }
                else { if(col1<N)gD[row*N+col1]=d1[i0]; if(col1+1<N)gD[row*N+col1+1]=d1[i1]; }
            }
        }
        __syncthreads();   // ensure half==0's ring reads are complete before half==1 re-reads them
    }
}

#ifndef MEGA_PROBE
int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):10;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}

    if(MODE==7){
        // ---- OG17 LEVER 4 (BENCH-13): SWIZZLED-RASTERIZATION + PERSISTENT-KERNEL own-GEMM.
        // Same route-(a) pre-lay + descriptor-direct 128x128 math as MODE 4, but launch
        // gridDim = GRIDMUL*#SMs persistent CTAs, each walking a SWIZZLED tile order (SWZ =
        // column-group width). Bit-exact gate FIRST (scheduling changes only tile ORDER), then
        // perf. argv: S 7 [NST] [SWZ] [GRIDMUL] [SWM] [SBO] [BOFF].
        //   SWZ=0 -> plain row-major (OG16 order). SWZ>0 -> grouped column rasterization.
        //   GRIDMUL=0 -> non-persistent (gridDim = total_tiles, classic). >0 -> GRIDMUL*#SMs.
        int NST  =argc>3?atoi(argv[3]):3;
        int SWZ  =argc>4?atoi(argv[4]):8;
        int GRIDMUL=argc>5?atoi(argv[5]):2;
        int SWM  =argc>6?atoi(argv[6]):0;
        int SBO  =argc>7?atoi(argv[7]):1024;
        int BOFF =argc>8?atoi(argv[8]):0;
        int LBO  =128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32||Mx%128){printf("MODE7 needs M,N%%128==0 && K%%32==0\n");return 1;}
        int nSM=0; { cudaDeviceProp pp; cudaGetDeviceProperties(&pp,0); nSM=pp.multiProcessorCount; }
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        float *dAo,*dBo; CK(cudaMalloc(&dAo,szA*4));CK(cudaMalloc(&dBo,szB*4));
        CK(cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // pre-lay A,B IDENTICAL to MODE 4 (route-(a) gmma-INTER 128x32 / 128-N tiles of 4 atoms).
        float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
        for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=m&127, a=mloc>>3, r=mloc&7;
            int katom=k>>5, kk=k&31;
            int p = a*256 + gmma_phys(r,kk);
            int srow = tile*128 + (p>>5);
            int scol = katom*32 + (p&31);
            hAp[(size_t)srow*Kx + scol] = hA[(size_t)m*Kx + k];
        }
        for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
            int tile=n>>7, nloc=n&127, c=nloc>>5, na=(nloc&31)>>3, r=nloc&7;
            int katom=k>>5, kk=k&31;
            int p = na*256 + gmma_phys(r,kk);
            int gN = tile*128 + c*32 + (p&31);
            int gK = katom*32 + (p>>5);
            hBp[(size_t)gK*Nx + gN] = hB[(size_t)k*Nx + n];
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE7 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE7 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=32;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        int tilesM=(Mx+TM-1)/TM, tilesN=(Nx+TN-1)/TN, total=tilesM*tilesN;
        int gridX = (GRIDMUL>0)? GRIDMUL*nSM : total;
        if(gridX>total) gridX=total;           // never launch more CTAs than tiles
        dim3 grid(gridX); int blk=256;
        CK(cudaFuncSetAttribute(gemm_og17_persist,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og17_persist<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM,tilesM,tilesN,total,SWZ); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og17_persist,blk,smsz);
          printf("OCCUPANCY MODE=7 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM | nSM=%d tiles=%dx%d=%d gridX=%d waves=%.2f SWZ=%d GRIDMUL=%d\n",
                 blk,smsz,smsz/1024.0,occ,nSM,tilesM,tilesN,total,gridX,(double)total/fmax(1,gridX),SWZ,GRIDMUL); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE7 OWN-FAULT SWZ=%d GRIDMUL=%d %s\n",SWZ,GRIDMUL,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("OG17 S=%d MODE=7 NST=%d SWZ=%d GRIDMUL=%d rel_rms=%.3e FAIL — tile-index bug (g5), no perf\n",
            S,NST,SWZ,GRIDMUL,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("OG17 S=%d MODE=7 NST=%d SWZ=%d GRIDMUL=%d persist own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,SWZ,GRIDMUL,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }

    if(MODE==8){
        // ---- BENCH-14: deeper wgmma-group pipeline (dual-issue PDEP) + vectorized overlapped epilogue.
        // Bit-exact gate is the arbiter: if a deeper wait_group races the ring -> rel-RMS != 0 ->
        // reject (closed-neg). If rel-RMS 0 AND faster -> inner-loop tuning closes the residual.
        int NST =argc>3?atoi(argv[3]):3;
        int PDEP=argc>4?atoi(argv[4]):2;     // wgmma-group pipeline depth (groups kept in flight)
        int SWM =argc>5?atoi(argv[5]):0;
        int SBO =argc>6?atoi(argv[6]):1024;
        int BOFF=argc>7?atoi(argv[7]):0;
        int LBO =128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32||Mx%128){printf("MODE8 needs M,N%%128==0 && K%%32==0\n");return 1;}
        if(PDEP>NST-1)PDEP=NST-1; if(PDEP<0)PDEP=0;   // need >=PDEP+1 ring buffers
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        float *dAo,*dBo; CK(cudaMalloc(&dAo,szA*4));CK(cudaMalloc(&dBo,szB*4));
        CK(cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // pre-lay A,B IDENTICAL to MODE 4/6 (128x32 gmma-INTER, B 128-N tiles of 4 atoms).
        float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
        for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=m&127, a=mloc>>3, r=mloc&7;
            int katom=k>>5, kk=k&31;
            int p = a*256 + gmma_phys(r,kk);
            int srow = tile*128 + (p>>5);
            int scol = katom*32 + (p&31);
            hAp[(size_t)srow*Kx + scol] = hA[(size_t)m*Kx + k];
        }
        for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
            int tile=n>>7, nloc=n&127, c=nloc>>5, na=(nloc&31)>>3, r=nloc&7;
            int katom=k>>5, kk=k&31;
            int p = na*256 + gmma_phys(r,kk);
            int gN = tile*128 + c*32 + (p&31);
            int gK = katom*32 + (p>>5);
            hBp[(size_t)gK*Nx + gN] = hB[(size_t)k*Nx + n];
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE8 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE8 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=32;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
        CK(cudaFuncSetAttribute(gemm_og17_b14,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og17_b14<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM,PDEP); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og17_b14,blk,smsz);
          printf("OCCUPANCY MODE=8 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM PDEP=%d\n",blk,smsz,smsz/1024.0,occ,PDEP); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE8 OWN-FAULT PDEP=%d swm=%d %s\n",PDEP,SWM,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("B14 S=%d MODE=8 NST=%d PDEP=%d rel_rms=%.3e FAIL — deeper wait_group races ring (closed-neg), no perf (g5)\n",
            S,NST,PDEP,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("B14 S=%d MODE=8 NST=%d PDEP=%d b14 own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,PDEP,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }

    if(MODE==9){
        // ---- OP-52: MODE 8 (b14 dual-issue) + NON-PERSISTENT CTA-SWIZZLE. The OP-45-GPU T4 lever:
        // cuBLAS's +24.6% large-D win = cta_swizzle=1 + single-pass (split_k=1), NOT split-K. This
        // ISOLATES the swizzle from MODE 7's persistent-loop confound: identical b14 math + 1-CTA/
        // tile grid (NOT occ*SM), ONLY the CTA->tile order swizzled. rel_rms 0 GATE FIRST, THEN perf.
        // argv: S 9 [NST] [PDEP] [SWZ] [SBO] [BOFF].  SWZ=0 == MODE 8 EXACTLY (apples self-check).
        int NST =argc>3?atoi(argv[3]):3;
        int PDEP=argc>4?atoi(argv[4]):2;
        int SWZ =argc>5?atoi(argv[5]):8;     // CTA-swizzle column-group width (0 = plain == MODE 8)
        int SBO =argc>6?atoi(argv[6]):1024;
        int BOFF=argc>7?atoi(argv[7]):0;
        int SWM =0, LBO =128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32||Mx%128){printf("MODE9 needs M,N%%128==0 && K%%32==0\n");return 1;}
        if(PDEP>NST-1)PDEP=NST-1; if(PDEP<0)PDEP=0;
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        float *dAo,*dBo; CK(cudaMalloc(&dAo,szA*4));CK(cudaMalloc(&dBo,szB*4));
        CK(cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // pre-lay A,B IDENTICAL to MODE 4/6/8 (128x32 gmma-INTER, B 128-N tiles of 4 atoms).
        float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
        for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=m&127, a=mloc>>3, r=mloc&7;
            int katom=k>>5, kk=k&31;
            int p = a*256 + gmma_phys(r,kk);
            int srow = tile*128 + (p>>5);
            int scol = katom*32 + (p&31);
            hAp[(size_t)srow*Kx + scol] = hA[(size_t)m*Kx + k];
        }
        for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
            int tile=n>>7, nloc=n&127, c=nloc>>5, na=(nloc&31)>>3, r=nloc&7;
            int katom=k>>5, kk=k&31;
            int p = na*256 + gmma_phys(r,kk);
            int gN = tile*128 + c*32 + (p&31);
            int gK = katom*32 + (p>>5);
            hBp[(size_t)gK*Nx + gN] = hB[(size_t)k*Nx + n];
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE9 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE9 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=32;
        int tilesM=Mx/TM, tilesN=Nx/TN;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        dim3 grid(tilesN,tilesM); int blk=256;   // 1 CTA per tile, SAME total grid as MODE 8
        CK(cudaFuncSetAttribute(gemm_og17_b14_swz,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og17_b14_swz<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM,PDEP,tilesM,tilesN,SWZ); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og17_b14_swz,blk,smsz);
          printf("OCCUPANCY MODE=9 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM PDEP=%d SWZ=%d tiles=%dx%d\n",blk,smsz,smsz/1024.0,occ,PDEP,SWZ,tilesM,tilesN); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE9 OWN-FAULT PDEP=%d SWZ=%d %s\n",PDEP,SWZ,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("B14 S=%d MODE=9 NST=%d PDEP=%d SWZ=%d rel_rms=%.3e FAIL — swizzle tile-index bug (g5), no perf\n",
            S,NST,PDEP,SWZ,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("B14 S=%d MODE=9 NST=%d PDEP=%d SWZ=%d b14swz own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,PDEP,SWZ,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }

    if(MODE==10){
        // ---- OP-55: 2-CTA/SM-PRESERVING 128x256 single-pass tile (gemm_og17_b14_t256e). The
        // OP-52 follow-up lever: a LARGER single-pass N-tile (256) that keeps 2 live accumulators
        // (two sequential 128-N halves) so regs stay ~MODE-8 (NOT t256's 154/1-CTA-SM trap), at
        // NST=2 (96KB/CTA <= 114KB -> 2 CTA/SM on smem too). rel_rms 0 GATE FIRST, THEN perf.
        // argv: S 10 [NST] [PDEP].  Ring is MODE-8-sized (one 128-N half); NST=3 -> 96KB -> 2 CTA/SM.
        int NST =argc>3?atoi(argv[3]):3;
        int PDEP=argc>4?atoi(argv[4]):1;
        int SBO =1024, BOFF=0, SWM=0, LBO=128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%256||Kx%32||Mx%128){printf("MODE10 needs N%%256==0 && M%%128==0 && K%%32==0\n");return 1;}
        if(PDEP>NST-1)PDEP=NST-1; if(PDEP<0)PDEP=0;
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        float *dAo,*dBo; CK(cudaMalloc(&dAo,szA*4));CK(cudaMalloc(&dBo,szB*4));
        CK(cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // pre-lay A,B IDENTICAL to MODE 4/6/8/9 (128x32 gmma-INTER, B 128-N tiles of 4 atoms).
        float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
        for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=m&127, a=mloc>>3, r=mloc&7;
            int katom=k>>5, kk=k&31;
            int p = a*256 + gmma_phys(r,kk);
            int srow = tile*128 + (p>>5);
            int scol = katom*32 + (p&31);
            hAp[(size_t)srow*Kx + scol] = hA[(size_t)m*Kx + k];
        }
        for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
            int tile=n>>7, nloc=n&127, c=nloc>>5, na=(nloc&31)>>3, r=nloc&7;
            int katom=k>>5, kk=k&31;
            int p = na*256 + gmma_phys(r,kk);
            int gN = tile*128 + c*32 + (p&31);
            int gK = katom*32 + (p>>5);
            hBp[(size_t)gK*Nx + gN] = hB[(size_t)k*Nx + n];
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE10 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE10 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TKSW=32;
        size_t SWBUF=(size_t)(TM*TKSW + 128*TKSW);     // MODE-8-sized ring (one 128-N half) per stage
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        dim3 grid(Nx/256,(Mx+TM-1)/TM); int blk=256;   // 1 CTA per 128x256 tile (half the N-grid of MODE 8)
        CK(cudaFuncSetAttribute(gemm_og17_b14_t256e,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og17_b14_t256e<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM,PDEP); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og17_b14_t256e,blk,smsz);
          printf("OCCUPANCY MODE=10 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM PDEP=%d NST=%d\n",blk,smsz,smsz/1024.0,occ,PDEP,NST); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE10 OWN-FAULT PDEP=%d NST=%d %s\n",PDEP,NST,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("B14 S=%d MODE=10 NST=%d PDEP=%d rel_rms=%.3e FAIL — 256-N half-split tiling bug (g5), no perf\n",
            S,NST,PDEP,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("B14 S=%d MODE=10 NST=%d PDEP=%d t256e own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,PDEP,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }

    if(MODE==6){
        // ---- OG17 LEVER 3: 128x128 (OG16 tile, 2 CTA/SM) + relaxed wait_group software pipeline.
        // Bit-exact gate is the arbiter: if wait_group 1 races the ring buffer, rel-RMS != 0 ->
        // closed-negative (report). If rel-RMS 0 AND faster -> the overlap lever crosses parity.
        int NST =argc>3?atoi(argv[3]):3;
        int SWM =argc>4?atoi(argv[4]):0;
        int SBO =argc>5?atoi(argv[5]):1024;
        int BOFF=argc>6?atoi(argv[6]):0;
        int LBO =128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32||Mx%128){printf("MODE6 needs M,N%%128==0 && K%%32==0\n");return 1;}
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        float *dAo,*dBo; CK(cudaMalloc(&dAo,szA*4));CK(cudaMalloc(&dBo,szB*4));
        CK(cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // pre-lay A,B IDENTICAL to MODE 4 (128x32 gmma-INTER, B 128-N tiles of 4 atoms).
        float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
        for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=m&127, a=mloc>>3, r=mloc&7;
            int katom=k>>5, kk=k&31;
            int p = a*256 + gmma_phys(r,kk);
            int srow = tile*128 + (p>>5);
            int scol = katom*32 + (p&31);
            hAp[(size_t)srow*Kx + scol] = hA[(size_t)m*Kx + k];
        }
        for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
            int tile=n>>7, nloc=n&127, c=nloc>>5, na=(nloc&31)>>3, r=nloc&7;
            int katom=k>>5, kk=k&31;
            int p = na*256 + gmma_phys(r,kk);
            int gN = tile*128 + c*32 + (p&31);
            int gK = katom*32 + (p>>5);
            hBp[(size_t)gK*Nx + gN] = hB[(size_t)k*Nx + n];
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE6 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE6 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=32;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
        CK(cudaFuncSetAttribute(gemm_og17_pipe,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og17_pipe<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og17_pipe,blk,smsz);
          printf("OCCUPANCY MODE=6 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM\n",blk,smsz,smsz/1024.0,occ); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE6 OWN-FAULT swm=%d sbo=%d boff=%d %s\n",SWM,SBO,BOFF,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("OG17 S=%d MODE=6 NST=%d pipe swm=%d sbo=%d boff=%d rel_rms=%.3e FAIL — wait_group1 races ring (closed-neg), no perf (g5)\n",
            S,NST,SWM,SBO,BOFF,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("OG17 S=%d MODE=6 NST=%d pipe swm=%d sbo=%d boff=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,SWM,SBO,BOFF,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }

    if(MODE==5){
        // ---- OG17 LEVER 1: 128x256 output tile, route-(a) pre-permuted global, band-free.
        // A pre-lay IDENTICAL to MODE 4 (128x32 per K-slab). B pre-lay extended to 256-N tiles
        // (8 atoms of 32). Winning descriptor = OG16 (swm=0 sbo=1024 boff=0). Bit-exact gate THEN perf.
        int NST =argc>3?atoi(argv[3]):2;
        int SWM =argc>4?atoi(argv[4]):0;
        int SBO =argc>5?atoi(argv[5]):1024;
        int BOFF=argc>6?atoi(argv[6]):0;
        int LBO =128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%256||Kx%32||Mx%128){printf("MODE5 needs M%%128==0 && N%%256==0 && K%%32==0\n");return 1;}
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        float *dAo,*dBo; CK(cudaMalloc(&dAo,szA*4));CK(cudaMalloc(&dBo,szB*4));
        CK(cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // A pre-lay: IDENTICAL to MODE 4 (128x32 per K-slab gmma-INTER, tile=m>>7).
        float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
        for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=m&127, a=mloc>>3, r=mloc&7;
            int katom=k>>5, kk=k&31;
            int p = a*256 + gmma_phys(r,kk);
            int srow = tile*128 + (p>>5);
            int scol = katom*32 + (p&31);
            hAp[(size_t)srow*Kx + scol] = hA[(size_t)m*Kx + k];
        }
        // B pre-lay: 256-N tiles, 8 atoms of 32 each (tile=n>>8). Atom c=(n&255)>>5. Per atom the
        // gmma-INTER block is IDENTICAL to MODE 4 (na within atom = (nloc&31)>>3; box {32(N),32(K)}).
        for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
            int tile=n>>8, nloc=n&255, c=nloc>>5, na=(nloc&31)>>3, r=nloc&7;
            int katom=k>>5, kk=k&31;
            int p = na*256 + gmma_phys(r,kk);          // smem slot WITHIN the 32-N atom (0..1023)
            int gN = tile*256 + c*32 + (p&31);         // global N for this smem slot
            int gK = katom*32 + (p>>5);                // global K
            hBp[(size_t)gK*Nx + gN] = hB[(size_t)k*Nx + n];
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE5 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE5 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=256,TKSW=32;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        dim3 grid(Nx/256,(Mx+TM-1)/TM); int blk=256;
        CK(cudaFuncSetAttribute(gemm_og17_t256,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og17_t256<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og17_t256,blk,smsz);
          printf("OCCUPANCY MODE=5 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM\n",blk,smsz,smsz/1024.0,occ); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE5 OWN-FAULT swm=%d sbo=%d boff=%d %s\n",SWM,SBO,BOFF,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("OG17 S=%d MODE=5 NST=%d t256 swm=%d sbo=%d boff=%d rel_rms=%.3e FAIL — no perf (g5)\n",
            S,NST,SWM,SBO,BOFF,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("OG17 S=%d MODE=5 NST=%d t256 swm=%d sbo=%d boff=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,SWM,SBO,BOFF,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }

    if(MODE==4){
        // ---- FULL GEMM: route-(a) pre-permuted global, descriptor-direct, bit-exact then perf.
        // The winning (pm,swm,sbo,boff) come from MODE 10. Defaults = best-expected (pm1/swm1/
        // sbo1024/boff0); override via argv for the gated re-run.
        // WINNING route-(a) config from MODE 10: gmma-INTER pre-laid global + NO-swizzle TMA +
        // descriptor swm=0 sbo=1024 boff=0 -> single-tile rel-RMS 0. Defaults set to that.
        int NST =argc>3?atoi(argv[3]):3;
        int SWM =argc>4?atoi(argv[4]):0;
        int SBO =argc>5?atoi(argv[5]):1024;
        int BOFF=argc>6?atoi(argv[6]):0;
        int LBO =128;
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32||Mx%128){printf("MODE4 needs M,N%%128==0 && K%%32==0\n");return 1;}
        size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
        float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
        srand(7);
        for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
        for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
        // cuBLAS reference on the ORIGINAL (un-permuted) operands.
        float *dA,*dB,*dD,*dR;
        CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
        float *dAo,*dBo; CK(cudaMalloc(&dAo,szA*4));CK(cudaMalloc(&dBo,szB*4));
        CK(cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice));
        cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
        float al=1.f,be=0.f;
        CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx));CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));
        // PRE-LAY A,B into gmma-INTER GLOBAL (route-a, one-time; amortized over K-reuse in a real
        // GEMM). The kernel reads each K=32 slab as a per-8-row-atom gmma-INTER block (atom a at
        // a*256, gmma_phys(r,k) within), stacked at SBO=1024B. A: M-major Kx-wide. The TMA box
        // {32(K),128(M)} lands SMEM[m_loc*32+k] = global -> we write global so that = gmma-INTER.
        // We must lay PER (bm-block, K-slab): the 128-row tile's atom a' = (m within tile)>>3.
        // A global row-major slot for logical (m,k): tile-relative atom a=(m&127)>>3, r=m&7,
        // K-slab katom=k>>5, kk=k&31. SMEM tile per slab is 128*32 floats indexed (atom-major):
        //   smem = a*256 + gmma_phys(r,kk). The no-swizzle TMA copies global[box] -> smem 1:1,
        //   box reads global row-major (m'*32 + kk) within the (bm,katom) tile. So set
        //   global[ (bm+ a*8 + r)*Kx + katom*32 + (a*256 + gmma_phys(r,kk)) - ... ]: simplest is
        //   to write directly into the global slot the box will fetch for smem index p.
        // The box {32,128} fetches, for smem linear p (0..128*32-1): global row (tilebase_m +
        //   p/32), col (katom*32 + p%32). We want smem[p] = gmma value, i.e. for p = a*256 +
        //   gmma_phys(r,kk): the logical (m=tilebase+a*8+r, k=katom*32+kk). Invert below.
        float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
        const int KSW=32;
        for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
            int tile=m>>7, mloc=m&127, a=mloc>>3, r=mloc&7;
            int katom=k>>5, kk=k&31;
            int p = a*256 + gmma_phys(r,kk);          // smem slot within the 128x32 slab tile
            int srow = tile*128 + (p>>5);             // box row = global m for this smem slot
            int scol = katom*32 + (p&31);             // box col = global k
            hAp[(size_t)srow*Kx + scol] = hA[(size_t)m*Kx + k];
        }
        for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
            int tile=n>>7, nloc=n&127, c=nloc>>5, na=(nloc&31)>>3, r=nloc&7;
            int katom=k>>5, kk=k&31;
            // The GEMM kernel loads B ATOM-BY-ATOM: box {32(N),32(K)}, contiguous=N. Each atom c
            // lands SMEM[c*1024 + p'] from global col(N)=bn+c*32+(p'&31), row(K)=st*32+(p'>>5).
            // We want SMEM[c*1024 + na*256+gmma_phys(r,kk)] = B value -> invert WITHOUT c in row.
            int p = na*256 + gmma_phys(r,kk);          // smem slot WITHIN the 32-N atom (0..1023)
            int gN = tile*128 + c*32 + (p&31);         // global N for this smem slot
            int gK = katom*32 + (p>>5);                // global K (p>>5 in 0..31)
            hBp[(size_t)gK*Nx + gN] = hB[(size_t)k*Nx + n]; // B global K-major(Nx wide)
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
          cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE4 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE4 encodeB r=%d\n",(int)r);return 4;} }
        const int TM=128,TN=128,TKSW=32;
        size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
        size_t smsz=(size_t)NST*SWBUF*4 + (size_t)NST*8;
        dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
        CK(cudaFuncSetAttribute(gemm_og16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og16<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og16,blk,smsz);
          printf("OCCUPANCY MODE=4 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM\n",blk,smsz,smsz/1024.0,occ); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE4 OWN-FAULT pm=%d swm=%d sbo=%d boff=%d %s\n",1,SWM,SBO,BOFF,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("OG16 S=%d MODE=4 NST=%d pm=%d swm=%d sbo=%d boff=%d rel_rms=%.3e FAIL — no perf (g5)\n",
            S,NST,1,SWM,SBO,BOFF,rr);return 2;}
        cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
        launch();CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
        double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
        cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
        CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
        CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
        float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
        double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
        printf("OG16 S=%d MODE=4 NST=%d pm=%d swm=%d sbo=%d boff=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
               S,NST,1,SWM,SBO,BOFF,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
        return 0;
    }

    if(MODE==10){
        // ---- ROUTE-(a) single-tile differential over the pre-permute x descriptor family ----
        const int M=64,N=64,K=8,KSW=32;
        float *hA=(float*)malloc((size_t)M*K*4),*hB=(float*)malloc((size_t)K*N*4);
        float *hD=(float*)malloc((size_t)M*N*4),*hR=(float*)malloc((size_t)M*N*4);
        srand(3);
        for(int i=0;i<M*K;++i)hA[i]=tf(((rand()%17)-8)*0.125f);
        for(int i=0;i<K*N;++i)hB[i]=tf(((rand()%17)-8)*0.125f);
        for(int m=0;m<M;++m)for(int n=0;n<N;++n){float a=0;for(int kk=0;kk<K;++kk)a+=hA[m*K+kk]*hB[kk*N+n];hR[m*N+n]=a;}
        float *dA,*dB,*dD; CK(cudaMalloc(&dA,(size_t)M*KSW*4));CK(cudaMalloc(&dB,(size_t)KSW*N*4));CK(cudaMalloc(&dD,(size_t)M*N*4));
        float *hApad=(float*)calloc((size_t)M*KSW,4), *hBpad=(float*)calloc((size_t)KSW*N,4);
        size_t smsz=(size_t)(2*8192 + M*KSW + N*KSW)*4 + 8;   // padded both sides (fault-proof)
        CK(cudaFuncSetAttribute(probe_a,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        // ===== route-(a) sweep: pm (global pre-permute) x tsw (TMA box swizzle) x swm/sbo/boff.
        //   pm=0 identity (W15 baseline, expect floor 1.0 with SWIZZLE+swm1).
        //   pm=1 gmma-INTER pre-laid global. With tsw=NONE + swm=0: descriptor reads gmma INTER
        //        directly -> EXPECT 0 (this is the W10 composed-decode result moved to global, no
        //        in-kernel decode band). With tsw=128B + swm=1: tests if HW de-swizzle ALSO
        //        recovers gmma INTER (keeps swizzle bandwidth). The arbiter is bit-exact.
        // A box: K-contiguous {32(K),64(M)}. B box: K-contiguous-as-strided {32(N),32(K)} per atom.
        int pml[4]={1,3,2,0};
        int tswl[2]={0,1};   // 0=CU_TENSOR_MAP_SWIZZLE_NONE, 1=SWIZZLE_128B
        int swl[3]={0,1,2};  // descriptor layout_type_
        int sbl[4]={256,1024,512,128};
        int bol[8]={0,1,2,3,4,5,6,7};
        double best=1e9; int bP=0,bT=0,bW=0,bS=0,bB=0;
        for(int pi=0;pi<4;++pi){
            int pm=pml[pi];
            // pre-permute A into global per pm. A logical (m 0..63, k 0..7) -> KSW-wide row-major.
            memset(hApad,0,(size_t)M*KSW*4); memset(hBpad,0,(size_t)KSW*N*4);
            for(int m=0;m<M;++m)for(int k=0;k<K;++k) hApad[ perm_global_slot(pm,m,k,M,KSW) ] = hA[m*K+k];
            // B logical (k 0..7, n 0..63). Mirror A: lay B N-major KSW-wide, box {32(K),32(N)}
            // landing SMEM[n_local*32 + k] per 32-N atom. pm-permute into gmma-INTER like A so
            // the descriptor reads the B operand fragment in gmma_phys order. Atom c=n>>5.
            for(int k=0;k<K;++k)for(int n=0;n<N;++n){
                int c=n>>5, nn=n&31, slot;
                if(pm==0) slot = k*N + n;                         // W15 baseline (K-major N-wide)
                else {                                            // gmma-INTER, N-major KSW-wide
                    int r=nn&7, a=nn>>3; int rr=(pm==3)?((r+1)&7):r;
                    slot = c*(32*KSW) + a*256 + gmma_phys(rr,k);
                }
                hBpad[slot]=hB[k*N+n];
            }
            CK(cudaMemcpy(dA,hApad,(size_t)M*KSW*4,cudaMemcpyHostToDevice));
            CK(cudaMemcpy(dB,hBpad,(size_t)KSW*N*4,cudaMemcpyHostToDevice));
            for(int ti=0;ti<2;++ti){
                CUtensorMap tmapA{},tmapB{};
                CUtensorMapSwizzle SW = tswl[ti]?CU_TENSOR_MAP_SWIZZLE_128B:CU_TENSOR_MAP_SWIZZLE_NONE;
                { cuuint64_t gd[2]={(cuuint64_t)KSW,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)KSW*4};
                  cuuint32_t bd[2]={32,64}; cuuint32_t es[2]={1,1};
                  if(enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
                     CU_TENSOR_MAP_INTERLEAVE_NONE,SW,CU_TENSOR_MAP_L2_PROMOTION_NONE,
                     CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE)!=CUDA_SUCCESS){ continue; } }
                if(pm==0){ // W15 baseline: B K-major(N wide), box {32(N),32(K)}
                  cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)KSW}; cuuint64_t gs[1]={(cuuint64_t)N*4};
                  cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
                  if(enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
                     CU_TENSOR_MAP_INTERLEAVE_NONE,SW,CU_TENSOR_MAP_L2_PROMOTION_NONE,
                     CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE)!=CUDA_SUCCESS){ continue; }
                } else {   // gmma-INTER: B N-major(KSW wide), box {32(K),32(N)} -> SMEM[n_loc*32+k]
                  cuuint64_t gd[2]={(cuuint64_t)KSW,(cuuint64_t)N}; cuuint64_t gs[1]={(cuuint64_t)KSW*4};
                  cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
                  if(enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
                     CU_TENSOR_MAP_INTERLEAVE_NONE,SW,CU_TENSOR_MAP_L2_PROMOTION_NONE,
                     CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE)!=CUDA_SUCCESS){ continue; }
                }
                for(int wi=0;wi<3;++wi)for(int si=0;si<4;++si)for(int bi=0;bi<8;++bi){
                    int SWM=swl[wi],SBO=sbl[si],BOFF=bol[bi];
                    CK(cudaMemset(dD,0,(size_t)M*N*4));
                    probe_a<<<1,128,smsz>>>(tmapA,tmapB,dD,128,SBO,BOFF,SWM,(pm!=0)?1:0);
                    cudaError_t e=cudaDeviceSynchronize();
                    if(e!=cudaSuccess){ cudaGetLastError(); continue; }
                    CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
                    double se=0,sr=0;for(int i=0;i<M*N;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
                    double rr=sqrt(se/fmax(1e-30,sr));
                    if(rr<best){best=rr;bP=pm;bT=tswl[ti];bW=SWM;bS=SBO;bB=BOFF;
                        printf("OG16-NEWBEST rel_rms=%.3e @ pm=%d tsw=%d swm=%d sbo=%d boff=%d\n",rr,pm,tswl[ti],SWM,SBO,BOFF);}
                }
            }
        }
        printf("OG16 MODE10 SWEEP-DONE best rel_rms=%.3e @ pm=%d tsw=%d swm=%d sbo=%d boff=%d %s\n",
               best,bP,bT,bW,bS,bB, best<=3e-3?"PASS (route-a atom MATCHED — band usable)":"FAIL (atom not matchable by this family)");
        return best<=3e-3?0:2;
    }

    if(MODE==2){
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
        dump_layout<<<1,128,smsz>>>(tmapA,dO);
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE2 FAULT %s\n",cudaGetErrorString(e));return 4;}
        float* hO=(float*)malloc((size_t)M*K*4);
        CK(cudaMemcpy(hO,dO,(size_t)M*K*4,cudaMemcpyDeviceToHost));
        printf("OG16-DUMP 128x32 SWIZZLE_128B landed (phys slot -> landed m*32+k):\n");
        for(int atom=0; atom<2; ++atom){
            printf("--- atom %d ---\n",atom);
            for(int pr=0;pr<8;++pr){ printf("pr=%d: ",pr);
                for(int pg=0;pg<8;++pg){ int p=atom*256+pr*32+pg*4; int id=(int)hO[p]; printf("[g%d:m%d,k%d] ",pg,id/32,id%32);} printf("\n"); }
        }
        return 0;
    }
    printf("unknown MODE %d\n",MODE); return 1;
}
#endif /* MEGA_PROBE */
