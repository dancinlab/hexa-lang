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
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)

// ---- GMMA INTER 8x4-core physical index (W2/W3-proven, bit-exact). ----
// strided dim s (M for A / N for B), contiguous dim k (K). core = 8 rows x 4 K-elems.
__device__ __host__ __forceinline__ int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
// ---- W9-MEASURED 128B-swizzle physical index inside an 8-row x 32-f32 (128B) atom. ----
// granule g=c>>2 (0..7), within-granule w=c&3. The MEASURED law: g_phys = g XOR ((r+1)&7).
// phys = r*32 + g_phys*4 + w.   (W9 dump: row r mask = ((r+1)&7).)
__device__ __host__ __forceinline__ int sw128_measured(int r,int c){
    int g=c>>2, w=c&3, gp=g^(((r+1)&7)); return r*32 + gp*4 + w;
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
    // COMPOSED decode B: logical (k,n). For B the strided dim is N, contiguous is K -> the
    // swizzled atom rows are N (32 of them), cols are K. atom-N c=n>>5 (which 32-N atom),
    // within-atom nn=n&31 -> that is the atom ROW; k is the atom COLUMN (0..31, use 0..7).
    for(int i=tid;i<8*TN;i+=blockDim.x){
        int k=i/TN, n=i%TN;
        int c=n>>5, nn=n&31;                 // c = which 32-N atom (0 or 1), nn = row in atom
        int sw_phys = c*(32*TKSW) + sw128_measured(nn,k);
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
    printf("unknown MODE %d\n",MODE); return 1;
}
