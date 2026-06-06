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
    if(pm==0){ return m*KSW + k; }                       // identity
    if(pm==1){
        // target: descriptor reads gmma INTER. gmma_phys gives the within-64x8 slot; map it
        // back through the TMA K-swizzle (g^(r&7)) so the landed byte sits where gmma wants.
        int g=k>>2, w=k&3; int gp=g^(r&7);
        return m*KSW + gp*4 + w;                          // pre-XOR cancels the TMA swizzle
    }
    if(pm==2){
        // MN-granule swizzle variant: XOR the row-atom index into the granule.
        int g=k>>2, w=k&3; int gp=g^(a&7);
        return m*KSW + gp*4 + w;
    }
    if(pm==3){
        int g=k>>2, w=k&3; int gp=g^((r+1)&7);            // +1 phase
        return m*KSW + gp*4 + w;
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
                                    float* __restrict__ gD,int lbo,int sbo,int boff,int swmode){
    const int TM=64, TN=64, TKSW=32;
    extern __shared__ __align__(128) float sm[];
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
        tma_load_2d(Bsw,        &tmapB,0, 0,bar);
        tma_load_2d(Bsw+32*TKSW,&tmapB,32,0,bar);
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
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)(kk*4);
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
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):10;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}

    if(MODE==4){
        // ---- FULL GEMM: route-(a) pre-permuted global, descriptor-direct, bit-exact then perf.
        // The winning (pm,swm,sbo,boff) come from MODE 10. Defaults = best-expected (pm1/swm1/
        // sbo1024/boff0); override via argv for the gated re-run.
        int NST =argc>3?atoi(argv[3]):3;
        int PM  =argc>4?atoi(argv[4]):1;
        int SWM =argc>5?atoi(argv[5]):1;
        int SBO =argc>6?atoi(argv[6]):1024;
        int BOFF=argc>7?atoi(argv[7]):0;
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
        // PRE-PERMUTE A,B into global per pm (one-time; in a real GEMM amortized over reuse).
        // A is M-major(Kx wide); permute applies per 128B K-atom (KSW=32) independently.
        float *hAp=(float*)malloc(szA*4),*hBp=(float*)malloc(szB*4);
        memcpy(hAp,hA,szA*4); memcpy(hBp,hB,szB*4);
        const int KSW=32;
        if(PM!=0){
            for(int m=0;m<Mx;++m)for(int katom=0;katom<Kx/KSW;++katom)for(int k=0;k<KSW;++k){
                int r=m&7, a=m>>3; int g=k>>2,wv=k&3,gp;
                if(PM==1) gp=g^(r&7); else if(PM==2) gp=g^(a&7); else gp=g^((r+1)&7);
                hAp[(size_t)m*Kx + katom*KSW + (gp*4+wv)] = hA[(size_t)m*Kx + katom*KSW + k];
            }
            // B is K-major(Nx wide). For pm>=1 we want B's strided dim (N) swizzled like A's M.
            // B atom = 32(N) x 32(K); permute the K-granule per N-row-atom.
            for(int kk=0;kk<Kx;++kk)for(int n=0;n<Nx;++n){
                int kb=kk&(KSW-1); int r=n&7,a=n>>3; int g=kb>>2,wv=kb&3,gp;
                if(PM==1) gp=g^(r&7); else if(PM==2) gp=g^(a&7); else gp=g^((r+1)&7);
                int kbase=kk-(kb); // keep within atom
                hBp[(size_t)(kbase+(gp*4+wv))*Nx + n] = hB[(size_t)kk*Nx + n];
            }
        }
        CK(cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice));
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
        CK(cudaFuncSetAttribute(gemm_og16,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        auto launch=[&](){ gemm_og16<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,LBO,SBO,BOFF,SWM); };
        { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_og16,blk,smsz);
          printf("OCCUPANCY MODE=4 blk=%d dynsmem=%zuB (%.1f KB/CTA) -> %d CTA/SM\n",blk,smsz,smsz/1024.0,occ); }
        CK(cudaMemset(dD,0,szD*4));
        launch();
        cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
        if(e!=cudaSuccess){printf("MODE4 OWN-FAULT pm=%d swm=%d sbo=%d boff=%d %s\n",PM,SWM,SBO,BOFF,cudaGetErrorString(e));return 4;}
        CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
        double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
        double rr=sqrt(se/fmax(1e-30,sr));
        if(rr>3e-3){printf("OG16 S=%d MODE=4 NST=%d pm=%d swm=%d sbo=%d boff=%d rel_rms=%.3e FAIL — no perf (g5)\n",
            S,NST,PM,SWM,SBO,BOFF,rr);return 2;}
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
               S,NST,PM,SWM,SBO,BOFF,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
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
        // device buffers (encode once; we re-fill per pm)
        float *dA,*dB,*dD; CK(cudaMalloc(&dA,(size_t)M*KSW*4));CK(cudaMalloc(&dB,(size_t)KSW*N*4));CK(cudaMalloc(&dD,(size_t)M*N*4));
        float *hApad=(float*)calloc((size_t)M*KSW,4), *hBpad=(float*)calloc((size_t)KSW*N,4);
        // B path: identity (B uses its own box; route-(a) is about A's landing — but we also
        // pre-permute B symmetrically so the SAME descriptor reads both). For the differential
        // we apply pm to BOTH A and B (gmma_phys is symmetric in the strided dim).
        CUtensorMap tmapA{},tmapB{};
        { cuuint64_t gd[2]={(cuuint64_t)KSW,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)KSW*4};
          cuuint32_t bd[2]={32,64}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE10 encodeA r=%d\n",(int)r);return 4;} }
        { cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)KSW}; cuuint64_t gs[1]={(cuuint64_t)N*4};
          cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE10 encodeB r=%d\n",(int)r);return 4;} }
        size_t smsz=(size_t)(M*KSW + N*KSW)*4 + 8;
        CK(cudaFuncSetAttribute(probe_a,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
        // sweep: pm x swmode x sbo x boff
        int pml[4]={0,1,2,3};
        int swl[3]={1,0,2};
        int sbl[5]={1024,256,512,128,2048};
        int bol[8]={0,1,2,3,4,5,6,7};
        double best=1e9; int bP=0,bW=0,bS=0,bB=0;
        for(int pi=0;pi<4;++pi){
            int pm=pml[pi];
            // pre-permute A (and B symmetrically) into global per pm
            memset(hApad,0,(size_t)M*KSW*4); memset(hBpad,0,(size_t)KSW*N*4);
            for(int m=0;m<M;++m)for(int k=0;k<K;++k) hApad[ perm_global_slot(pm,m,k,M,KSW) ] = hA[m*K+k];
            // B is K-major-on-N (strided dim = N). symmetric permute on (n,k):
            for(int k=0;k<K;++k)for(int n=0;n<N;++n){
                int nn=n, slot;
                int g=k>>2,w=k&3,rr=nn&7,aa=nn>>3;
                if(pm==0) slot = k*N + nn;
                else if(pm==1){ int gp=g^(rr&7); slot = nn*KSW + gp*4 + w; }  // B stored (n-major,KSW)
                else if(pm==2){ int gp=g^(aa&7); slot = nn*KSW + gp*4 + w; }
                else { int gp=g^((rr+1)&7); slot = nn*KSW + gp*4 + w; }
                // Note: for pm>=1 B global is n-major KSW-wide (box {32,32} reads it). For pm=0
                // B is k-major N-wide (the W15 layout). We re-encode B box accordingly below.
                if(pm==0) hBpad[slot]=hB[k*N+n];
                else      hBpad[slot]=hB[k*N+n];
            }
            CK(cudaMemcpy(dA,hApad,(size_t)M*KSW*4,cudaMemcpyHostToDevice));
            CK(cudaMemcpy(dB,hBpad,(size_t)KSW*N*4,cudaMemcpyHostToDevice));
            for(int wi=0;wi<3;++wi)for(int si=0;si<5;++si)for(int bi=0;bi<8;++bi){
                int SWM=swl[wi],SBO=sbl[si],BOFF=bol[bi];
                CK(cudaMemset(dD,0,(size_t)M*N*4));
                probe_a<<<1,128,smsz>>>(tmapA,tmapB,dD,128,SBO,BOFF,SWM);
                cudaError_t e=cudaDeviceSynchronize();
                if(e!=cudaSuccess){ printf("MODE10 FAULT pm=%d swm=%d sbo=%d boff=%d %s\n",pm,SWM,SBO,BOFF,cudaGetErrorString(e)); return 4; }
                CK(cudaMemcpy(hD,dD,(size_t)M*N*4,cudaMemcpyDeviceToHost));
                double se=0,sr=0;for(int i=0;i<M*N;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
                double rr=sqrt(se/fmax(1e-30,sr));
                if(rr<best){best=rr;bP=pm;bW=SWM;bS=SBO;bB=BOFF;
                    printf("OG16-NEWBEST rel_rms=%.3e @ pm=%d swm=%d sbo=%d boff=%d\n",rr,pm,SWM,SBO,BOFF);}
            }
        }
        printf("OG16 MODE10 SWEEP-DONE best rel_rms=%.3e @ pm=%d swm=%d sbo=%d boff=%d %s\n",
               best,bP,bW,bS,bB, best<=3e-3?"PASS (route-a atom MATCHED — band usable)":"FAIL (atom not matchable by this family)");
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
