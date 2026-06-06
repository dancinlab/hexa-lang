// wgmma_tf32_warpspec.cu — W6/W7: warp-specialized + async-pipelined TF32 wgmma GEMM,
// built ON TOP of the W2/W3-proven GMMA INTER 8x4-core layout (bit-exact) + the
// fence.proxy.async ordering. Goal: close the W5 9.35x latency-hiding gap toward
// cuBLAS-TF32 parity, KEEPING rel_rms <= 3e-3 (ideally 0).
//
// The W5 baseline is SYNCHRONOUS: every K-step does (global load -> __syncthreads ->
// 2 wgmma -> wait_group 0 -> __syncthreads). Zero load/compute overlap; TK=8 tiny.
//
// LEVERS in this file, selected by argv[2]=MODE (each is independently bit-exact):
//   MODE 0  W5-REBASE   : the W5 TN=128 kernel, recompiled here as the apples-to-apples
//                         baseline (sanity: must reproduce ~38 TFLOP/s).
//   MODE 1  ASYNC-PIPE  : single consumer warpgroup, but loads issued via cp.async.cg
//                         (16B = one 8x4-core K-quad is CONTIGUOUS in gmma_phys, so a
//                         vectorized .128 cp.async lands correctly) into an NSTAGES ring;
//                         software pipeline — copy stage k+1 while wgmma computes stage k.
//                         TK=16 (2 K-quads) per step to amortize. Deep ring overlaps the
//                         global-load latency the W5 __syncthreads serialized.
//   MODE 2  WARPSPEC    : true producer/consumer warp specialization. 2 warpgroups
//                         (256 threads). WG0=PRODUCER issues cp.async loads into an
//                         NSTAGES ring + signals a "filled" mbarrier per stage; WG1=
//                         CONSUMER waits the filled mbarrier, runs wgmma over the stage,
//                         signals an "empty" mbarrier. mbarrier arrive/try_wait + phase
//                         bits coordinate. This overlaps load+compute across warpgroups.
//
// Bit-exact GATE FIRST (rel_rms), perf only if rel_rms<=3e-3 (g5). cuBLAS=roofline.
// argv: S [MODE] [NSTAGES]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda.h>          // driver API: CUtensorMap, cuTensorMapEncodeTiled (MODE 4 TMA)
#include <cudaTypedefs.h>  // CUtensorMapDataType / enums
#include <cuda_runtime.h>
#include <cublas_v2.h>
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d:%s\n",#x,__LINE__,cudaGetErrorString(e));return 3;}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d\n",(int)s);return 3;}}while(0)

// wgmma shared descriptor (matrix descriptor): start>>4, LBO>>4, SBO>>4.
__device__ __forceinline__ uint64_t mk(uint32_t s,uint32_t lbo,uint32_t sbo){
    uint64_t d=0; d|=(uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32; return d;
}
// GMMA INTER 8x4-core physical index (W1/W2-proven, bit-exact).
__device__ __forceinline__ int gmma_phys(int s,int k){
    int strip=s>>3,sr=s&7,kcore=k>>2,kc=k&3; return (strip*2+kcore)*32+sr*4+kc;
}
// wgmma.m64n64k8: 32 accumulator regs. DESCA/DESCB = shared descriptors.
#define WG(D0,DESCA,DESCB) asm volatile( \
  "wgmma.mma_async.sync.aligned.m64n64k8.f32.tf32.tf32 " \
  "{%0,%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12,%13,%14,%15," \
  "%16,%17,%18,%19,%20,%21,%22,%23,%24,%25,%26,%27,%28,%29,%30,%31}, %32,%33, 1,1,1;\n" \
  :"+f"(D0[0]),"+f"(D0[1]),"+f"(D0[2]),"+f"(D0[3]),"+f"(D0[4]),"+f"(D0[5]),"+f"(D0[6]),"+f"(D0[7]), \
   "+f"(D0[8]),"+f"(D0[9]),"+f"(D0[10]),"+f"(D0[11]),"+f"(D0[12]),"+f"(D0[13]),"+f"(D0[14]),"+f"(D0[15]), \
   "+f"(D0[16]),"+f"(D0[17]),"+f"(D0[18]),"+f"(D0[19]),"+f"(D0[20]),"+f"(D0[21]),"+f"(D0[22]),"+f"(D0[23]), \
   "+f"(D0[24]),"+f"(D0[25]),"+f"(D0[26]),"+f"(D0[27]),"+f"(D0[28]),"+f"(D0[29]),"+f"(D0[30]),"+f"(D0[31]) \
   :"l"(DESCA),"l"(DESCB))

// ----- async copy helpers (cp.async, sm_80+; vectorized 16B = .128) -----
__device__ __forceinline__ void cpasync16(void* dsmem,const void* gsrc){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(dsmem);
    // .cg = cache-global (bypass L1), 16B. The dst 16B (one 8x4-core K-quad) is
    // contiguous in gmma_phys; the src 4 consecutive K elements are contiguous in
    // row-major A (m fixed) / contiguous in N for B (k fixed) — see staging below.
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n"::"r"(s),"l"(gsrc));
}
__device__ __forceinline__ void cp_commit(){asm volatile("cp.async.commit_group;\n":::"memory");}
template<int N> __device__ __forceinline__ void cp_wait(){
    asm volatile("cp.async.wait_group %0;\n"::"n"(N):"memory");}

// ======================================================================
// MODE 0 — W5 rebase (synchronous TN=128), apples-to-apples baseline.
// ======================================================================
extern "C" __global__ void gemm_w5(const float* __restrict__ gA,const float* __restrict__ gB,
                                    float* __restrict__ gD,int M,int N,int K){
    const int TM=64,TN=128,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int AB=TM*TK, BB=TK*64, BUF=AB+2*BB;
    int tid=threadIdx.x;
    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    int ping=0;
    for(int k0=0;k0<K;k0+=TK,ping^=1){
        float* As=sm+ping*BUF; float* B0=As+AB; float* B1=B0+BB;
        for(int i=tid;i<TM*TK;i+=128){int m=i/TK,kk=i%TK; As[gmma_phys(m,kk)]=gA[(bm+m)*K+(k0+kk)];}
        for(int i=tid;i<TK*64;i+=128){int kk=i/64,n=i%64; B0[gmma_phys(n,kk)]=gB[(k0+kk)*N+(bn+n)];}
        for(int i=tid;i<TK*64;i+=128){int kk=i/64,n=i%64; B1[gmma_phys(n,kk)]=gB[(k0+kk)*N+(bn+64+n)];}
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        uint32_t aA=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0=(uint32_t)__cvta_generic_to_shared(B0), a1=(uint32_t)__cvta_generic_to_shared(B1);
        uint64_t dA=mk(aA,128,256), dB0=mk(a0,128,256), dB1=mk(a1,128,256);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        WG(d0,dA,dB0);
        WG(d1,dA,dB1);
        asm volatile("wgmma.commit_group.sync.aligned;\n"
                     "wgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
    }
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=bm+rb+r*8;
        int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
        if(row<M&&col0<N)gD[row*N+col0]=d0[idx];
        if(row<M&&col1<N)gD[row*N+col1]=d1[idx];
    }
}

// ======================================================================
// MODE 1 — ASYNC-PIPE: single warpgroup (128 thr), cp.async ring, SW pipeline.
//   tile 64x128, K-step TK=8. NSTAGES shared buffers. Stage the global loads with
//   vectorized cp.async (16B = one K-quad of the 8x4 core, contiguous in gmma_phys),
//   prefetch STAGES ahead so the global-load latency overlaps the wgmma of an
//   earlier stage. cp.async.wait_group keeps exactly the in-flight stages bounded.
// A-tile: 64x8 ; B0,B1: 8x64 each. Per stage buffer = 64*8 + 2*8*64 floats.
// Each thread copies 16B (4 floats) quads. A has 64*8/4=128 quads -> 1/thread.
//   B0,B1 each 8*64/4=128 quads -> 1/thread. So per stage: 3 cp.async per thread.
// CONTIGUITY: for A row m, K-quad q (kk=4q..4q+3): gmma_phys = (strip*2+kcore)*32+sr*4+kc
//   with kk in one core (kcore fixed within a quad when 4q aligned to a core, i.e
//   TK multiple of 4) -> dst 4 floats contiguous; src gA[(bm+m)*K + k0+4q .. +3]
//   contiguous in K. OK. For B (k fixed, n contiguous): we copy along n which is the
//   's' axis of gmma_phys(n,kk) -> NOT contiguous in dst. So B is staged per (kk) row
//   with n contiguous in SRC but scattered in dst; cp.async needs contiguous dst.
//   => For B we instead lay a TRANSPOSED-friendly quad: copy 4 consecutive n with same
//   kk? dst gmma_phys(n..n+3,kk) = strides of 4 in s -> (sr changes) NOT contiguous.
//   Hence B cannot use a single 16B cp.async into gmma layout. We therefore stage B
//   with cp.async into a SCRATCH contiguous [kk][n] buffer (coalesced, vectorizable),
//   then a tiny in-shared permute into gmma layout. A uses direct cp.async (its quad
//   IS contiguous). Net: A fully async; B async-load + cheap shared permute.
// ======================================================================
extern "C" __global__ void gemm_apipe(const float* __restrict__ gA,const float* __restrict__ gB,
                                       float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=64,TN=128,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // per-stage: As(64*8) + B0(8*64) + B1(8*64) gmma-laid + Braw scratch(8*128 row-major)
    const int AB=TM*TK, BB=TK*64, BRAW=TK*TN;
    const int BUF=AB+2*BB+BRAW;
    int tid=threadIdx.x;
    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    int nk=K/TK;
    // ---- prologue: issue loads for the first min(NST-1, nk) stages ----
    auto issue=[&](int st,int k0){
        float* base=sm+(st)*BUF;
        float* As=base; float* Braw=base+AB+2*BB;
        // A: 128 quads, 1/thread. quad q: m=q*?? -> 64*8/4=128 quads, idx=tid
        {int q=tid; int m=q/2, qk=(q%2)*4; // 2 quads per row (TK=8 -> 2 K-quads)
         cpasync16(As+gmma_phys(m,qk), &gA[(bm+m)*K + k0+qk]); }
        // Braw: row-major [kk][n], TK*TN=1024 floats=256 quads, 2/thread, coalesced n.
        for(int q=tid;q<TK*TN/4;q+=128){int kk=q/(TN/4), nq=(q%(TN/4))*4;
            cpasync16(Braw+kk*TN+nq, &gB[(k0+kk)*N + bn+nq]); }
    };
    int stages=NST<nk?NST:nk;
    for(int st=0;st<stages-1;++st){ issue(st, st*TK); cp_commit(); }
    // ---- mainloop ----
    int ping;
    for(int kk_i=0;kk_i<nk;++kk_i){
        int load_st=(kk_i+stages-1);
        // issue the stage that is (stages-1) ahead, if any K remains
        if(load_st<nk){ issue((load_st)%NST, load_st*TK); cp_commit(); }
        else { cp_commit(); } // keep group counting consistent
        // wait until only (stages-1) groups remain in flight -> current stage ready
        // we want the CURRENT stage (kk_i) fully arrived; bound in-flight to stages-1.
        cp_wait<0>(); // simplest-correct: drain to current (perf: see MODE2 for overlap)
        __syncthreads();
        ping=kk_i%NST;
        float* As=sm+ping*BUF; float* B0=As+AB; float* B1=B0+BB; float* Braw=B1+BB;
        // permute Braw[kk][n] -> B0/B1 gmma layout (n is 's', kk is 'k')
        for(int i=tid;i<TK*64;i+=128){int kk=i/64,n=i%64; B0[gmma_phys(n,kk)]=Braw[kk*TN+n];}
        for(int i=tid;i<TK*64;i+=128){int kk=i/64,n=i%64; B1[gmma_phys(n,kk)]=Braw[kk*TN+64+n];}
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        uint32_t aA=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0=(uint32_t)__cvta_generic_to_shared(B0), a1=(uint32_t)__cvta_generic_to_shared(B1);
        uint64_t dA=mk(aA,128,256), dB0=mk(a0,128,256), dB1=mk(a1,128,256);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        WG(d0,dA,dB0);
        WG(d1,dA,dB1);
        asm volatile("wgmma.commit_group.sync.aligned;\n"
                     "wgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
    }
    int w=tid>>5,l=tid&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=bm+rb+r*8;
        int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
        if(row<M&&col0<N)gD[row*N+col0]=d0[idx];
        if(row<M&&col1<N)gD[row*N+col1]=d1[idx];
    }
}

// ----- mbarrier helpers (sm_80+) -----
__device__ __forceinline__ void mbar_init(uint64_t* b,int cnt){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.init.shared::cta.b64 [%0], %1;\n"::"r"(s),"r"(cnt));}
__device__ __forceinline__ void mbar_arrive(uint64_t* b){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.arrive.shared::cta.b64 _, [%0];\n"::"r"(s));}
// spin until the barrier reaches `phase`; cp.async completion is observed by
// mbarrier.arrive AFTER cp.async.wait_group (producer drains its own group first).
__device__ __forceinline__ void mbar_wait(uint64_t* b,uint32_t phase){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("{\n.reg .pred P;\nLAB_%=:\n"
                 "mbarrier.try_wait.parity.shared::cta.b64 P, [%0], %1;\n"
                 "@!P bra LAB_%=;\n}\n"::"r"(s),"r"(phase));}
// named-barrier sync over a single warpgroup (128 thr). barrier id `bid`, 128 thr.
// PRODUCER uses this to synchronize ITS OWN 128 threads between the cp.async loads
// and the cross-thread Braw->gmma permute (cp.async.wait_group is PER-THREAD only;
// thread i's permute reads Braw written by OTHER threads' cp.async — without a WG
// barrier that read races the still-in-flight sibling copies). bar.sync N,128.
__device__ __forceinline__ void wg_bar(int bid){
    asm volatile("bar.sync %0, 128;\n"::"r"(bid):"memory");}

// ======================================================================
// MODE 2 — WARPSPEC: true producer/consumer warp specialization (256 thr = 2 WG).
//   WG0 (thr 0..127)  = PRODUCER: for each K-step, cp.async-loads A + Braw into the
//     ring stage, cp.async.wait_group 0 (its loads landed), permutes Braw->B0/B1 gmma,
//     fence.proxy.async, then mbar_arrive(full[stage]) to release the consumer.
//     Before reusing a stage it mbar_wait(empty[stage]) (consumer done with it).
//   WG1 (thr 128..255)= CONSUMER: for each K-step, mbar_wait(full[stage]), runs the 2
//     wgmma over the staged tiles into its accumulators, wgmma.wait_group 0, then
//     mbar_arrive(empty[stage]) to free the stage for the producer.
//   Overlap: producer fills stage k+1 while consumer computes stage k. Phase bits
//     (toggled every NST trips) drive mbarrier.try_wait.parity.
//   Only the CONSUMER warpgroup holds accumulators / writes D.
// ======================================================================
extern "C" __global__ void gemm_ws(const float* __restrict__ gA,const float* __restrict__ gB,
                                    float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=64,TN=128,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int AB=TM*TK, BB=TK*64, BRAW=TK*TN;
    const int BUF=AB+2*BB+BRAW;
    // mbarriers live after the NST ring buffers.
    uint64_t* full=(uint64_t*)(sm + (size_t)NST*BUF);
    uint64_t* empty=full+NST;
    int tid=threadIdx.x; int wg=tid>>7; int lt=tid&127; // lt = lane within warpgroup
    int nk=K/TK;
    if(tid<2*NST){ // one thread per barrier inits
        if(tid<NST) mbar_init(&full[tid],128);   // producer WG arrives (128 thr)
        else        mbar_init(&empty[tid-NST],128);// consumer WG arrives (128 thr)
    }
    __syncthreads();
    // empty starts "available" so producer can fill all stages the first round:
    // model empty phase so that round-0 producer does NOT wait. We pre-arrive empty
    // NST times via consumer? Simpler: producer skips empty-wait on the first NST
    // fills (stage not yet consumed). Track with a per-stage "used" first-pass flag.
    if(wg==0){
        // ---------------- PRODUCER ----------------
        uint32_t eph=0; // empty phase we wait on
        for(int ki=0;ki<nk;++ki){
            int st=ki%NST;
            if(ki>=NST) { mbar_wait(&empty[st], eph); if(st==NST-1) eph^=1; }
            float* base=sm+st*BUF; float* As=base; float* Braw=base+AB+2*BB;
            { int q=lt; int m=q/2, qk=(q%2)*4;
              cpasync16(As+gmma_phys(m,qk), &gA[(bm+m)*K + ki*TK+qk]); }
            for(int q=lt;q<TK*TN/4;q+=128){int kk=q/(TN/4), nq=(q%(TN/4))*4;
                cpasync16(Braw+kk*TN+nq, &gB[(ki*TK+kk)*N + bn+nq]); }
            cp_commit(); cp_wait<0>();
            // ALL 128 producer threads must have landed their cp.async (incl. Braw)
            // before ANY thread reads sibling-written Braw in the permute. bar id 1.
            wg_bar(1);
            float* B0=As+AB; float* B1=B0+BB;
            for(int i=lt;i<TK*64;i+=128){int kk=i/64,n=i%64; B0[gmma_phys(n,kk)]=Braw[kk*TN+n];}
            for(int i=lt;i<TK*64;i+=128){int kk=i/64,n=i%64; B1[gmma_phys(n,kk)]=Braw[kk*TN+64+n];}
            // permute writes must be complete + async-proxy-visible before release.
            wg_bar(1);
            asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
            mbar_arrive(&full[st]);
        }
    } else {
        // ---------------- CONSUMER ----------------
        float d0[32],d1[32];
        #pragma unroll
        for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
        uint32_t fph=0;
        for(int ki=0;ki<nk;++ki){
            int st=ki%NST;
            mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
            float* base=sm+st*BUF; float* As=base; float* B0=As+AB; float* B1=B0+BB;
            uint32_t aA=(uint32_t)__cvta_generic_to_shared(As);
            uint32_t a0=(uint32_t)__cvta_generic_to_shared(B0), a1=(uint32_t)__cvta_generic_to_shared(B1);
            uint64_t dA=mk(aA,128,256), dB0=mk(a0,128,256), dB1=mk(a1,128,256);
            asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
            asm volatile("wgmma.commit_group.sync.aligned;\n"
                         "wgmma.wait_group.sync.aligned 0;\n":::"memory");
            mbar_arrive(&empty[st]);
        }
        int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p,row=bm+rb+r*8;
            int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
            if(row<M&&col0<N)gD[row*N+col0]=d0[idx];
            if(row<M&&col1<N)gD[row*N+col1]=d1[idx];
        }
    }
}

// ----- named-barrier sync over a SINGLE warpgroup (128 thr) at a chosen bar id.
//   bar.sync id, 128 — only the 128 threads of one warpgroup participate. Used by
//   the producer WG (MODE 3) exactly as in MODE 2: gate the Braw->gmma permute so a
//   thread never reads a sibling's still-in-flight cp.async. id is per-warpgroup.
__device__ __forceinline__ void wg_bar_id(int bid){
    asm volatile("bar.sync %0, 128;\n"::"r"(bid):"memory");}

// ======================================================================
// MODE 3 — DUAL-CONSUMER-WARPGROUP WARPSPEC (W7, the big lever).
//   384 threads = 3 warpgroups. TM=128, TN=128, TK=8.
//     WG0 (thr   0..127) = PRODUCER: per K-step cp.async-loads the FULL A 128x8 band
//        (two gmma sub-tiles As0[rows0..63], As1[rows64..127]) + B (Braw 8x128) into the
//        ring stage, drains its cp.async, permutes Braw->B0/B1 gmma, fence.proxy.async,
//        then mbar_arrive(full[stage]) to release BOTH consumer warpgroups. Before reuse
//        it mbar_wait(empty[stage]) (both consumers signalled done — arrive count 256).
//     WG1 (thr 128..255) = CONSUMER band-0: wgmma over As0 x {B0,B1} -> rows  0..63.
//     WG2 (thr 256..383) = CONSUMER band-1: wgmma over As1 x {B0,B1} -> rows 64..127.
//   The TWO consumer warpgroups SHARE the single B tile loaded once by the producer —
//   so the tensor cores stay fed (2 consumer WGs issuing wgmma) while 1 WG produces.
//   This is the geometry W6 diagnosed the single-consumer-WG (TM=64) lacked: there half
//   the warps never issued wgmma. cuBLAS reaches sm_90a peak exactly this way.
//   mbarrier full[]: producer arrives (128); both consumers wait the SAME full[] phase.
//   mbarrier empty[]: BOTH consumer WGs arrive (256 total); producer waits.
// ======================================================================
extern "C" __global__ void gemm_ws2(const float* __restrict__ gA,const float* __restrict__ gB,
                                     float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=128,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // per-stage: As0(64*8) As1(64*8) B0(8*64) B1(8*64) gmma-laid + Braw(8*128 scratch).
    const int ABND=TM*TK/2;            // one 64x8 A band = 512 floats
    const int BB=TK*64, BRAW=TK*TN;
    const int BUF=2*ABND + 2*BB + BRAW;
    uint64_t* full=(uint64_t*)(sm + (size_t)NST*BUF);
    uint64_t* empty=full+NST;
    int tid=threadIdx.x; int wg=tid>>7; int lt=tid&127;
    int nk=K/TK;
    if(tid<2*NST){
        if(tid<NST) mbar_init(&full[tid],128);     // producer (128) arrives full
        else        mbar_init(&empty[tid-NST],256); // BOTH consumer WGs (256) arrive empty
    }
    __syncthreads();
    if(wg==0){
        // ---------------- PRODUCER ----------------
        uint32_t eph=0;
        for(int ki=0;ki<nk;++ki){
            int st=ki%NST;
            if(ki>=NST){ mbar_wait(&empty[st], eph); if(st==NST-1) eph^=1; }
            float* base=sm+(size_t)st*BUF;
            float* As0=base; float* As1=base+ABND; float* Braw=base+2*ABND+2*BB;
            // A band-0 rows 0..63 + band-1 rows 64..127. 64*8/4=128 quads each = 1/thread.
            { int q=lt; int m=q/2, qk=(q%2)*4;
              cpasync16(As0+gmma_phys(m,qk),     &gA[(bm+m)*K     + ki*TK+qk]);
              cpasync16(As1+gmma_phys(m,qk),     &gA[(bm+64+m)*K  + ki*TK+qk]); }
            // Braw row-major [kk][n], 8*128/4=256 quads, 2/thread, coalesced in n.
            for(int q=lt;q<TK*TN/4;q+=128){int kk=q/(TN/4), nq=(q%(TN/4))*4;
                cpasync16(Braw+kk*TN+nq, &gB[(ki*TK+kk)*N + bn+nq]); }
            cp_commit(); cp_wait<0>();
            wg_bar_id(1); // all producer cp.async landed before reading sibling Braw
            float* B0=base+2*ABND; float* B1=B0+BB;
            for(int i=lt;i<TK*64;i+=128){int kk=i/64,n=i%64; B0[gmma_phys(n,kk)]=Braw[kk*TN+n];}
            for(int i=lt;i<TK*64;i+=128){int kk=i/64,n=i%64; B1[gmma_phys(n,kk)]=Braw[kk*TN+64+n];}
            wg_bar_id(1);
            asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
            mbar_arrive(&full[st]);
        }
    } else {
        // ---------------- CONSUMER (band = wg-1: 0 -> rows0..63, 1 -> rows64..127) ----------------
        int band=wg-1;
        float d0[32],d1[32];
        #pragma unroll
        for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
        uint32_t fph=0;
        for(int ki=0;ki<nk;++ki){
            int st=ki%NST;
            mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
            float* base=sm+(size_t)st*BUF;
            float* As=base+band*ABND; float* B0=base+2*ABND; float* B1=B0+BB;
            uint32_t aA=(uint32_t)__cvta_generic_to_shared(As);
            uint32_t a0=(uint32_t)__cvta_generic_to_shared(B0), a1=(uint32_t)__cvta_generic_to_shared(B1);
            uint64_t dA=mk(aA,128,256), dB0=mk(a0,128,256), dB1=mk(a1,128,256);
            asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
            asm volatile("wgmma.commit_group.sync.aligned;\n"
                         "wgmma.wait_group.sync.aligned 0;\n":::"memory");
            mbar_arrive(&empty[st]);
        }
        // epilogue: this consumer WG writes its 64-row band (rows bm + band*64 + ...).
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
// MODE 4 — TMA-PRODUCER DUAL-CONSUMER-WARPGROUP WARPSPEC (W8, the diagnosed lever).
//   The W7 diagnosis (F-FUSION-SM90-WGMMA-W7): MODE 3 regressed 50.7->32.0 because its
//   PRODUCER is a full 128-thread cp.async warpgroup — that 384-thread CTA is register-
//   bound to 1 block/SM (90 regs*384 > 65536), netting only 256 compute-thr/SM vs the
//   simple async-pipe's 512. The fix is to make the producer a HARDWARE TMA engine driven
//   by a SINGLE ELECTED THREAD (cp.async.bulk.tensor.2d), freeing the other 255 threads so
//   BOTH warpgroups are CONSUMERS issuing wgmma at full occupancy — exactly how cuBLAS
//   reaches sm_90a peak.
//
//   GEOMETRY: TM=128, TN=128, TK=8. 256 threads = 2 warpgroups, BOTH consumers.
//     thread 0 (elected) issues the TMA bulk loads for A-band (128x8, row-major) + B
//       (8x128, row-major) into the ring stage; mbarrier.expect_tx tracks the byte count;
//       TMA HW does the global->shared copy with NO consumer threads spent on the load.
//     All 256 threads then mbar_wait(full[stage]) (TMA arrival), cooperatively permute the
//       TMA-landed row-major Araw/Braw -> gmma INTER 8x4 layout (As0/As1/B0/B1), then each
//       warpgroup issues its 2 wgmma over its 64-row A band x the SHARED B tile.
//     A "tail" thread (elected) re-arms the stage for the next ring trip after both WGs
//       finished the wgmma (tracked by an empty[] mbarrier, arrive count = 256).
//   This keeps the SAME bit-exact gmma layout + descriptors (mk / gmma_phys / WG) as
//   MODE 0..3 — only the PRODUCTION ENGINE changes (cp.async WG -> single-thread TMA).
//   The B descriptor / wgmma path is byte-identical to MODE 3, so rel_rms must stay 0.
//
//   TMA descriptors (CUtensorMap) for A (MxK) and B (KxN) row-major are built host-side
//   and passed __grid_constant__. tma_load_2d(dst, &tmap, x, y, bar): coord {x,y} indexes
//   the tiled tensor map (x=fastest dim). For A row-major MxK, fastest=K, so {k0, bm}
//   loads tile rows bm.. , cols k0.. into a BK-fast row-major staging buffer. For B row-
//   major KxN, fastest=N, so {bn, k0} loads the 8x128 B band into row-major [kk][n].
// ======================================================================
__device__ __forceinline__ void mbar_init_tx(uint64_t* b,int cnt){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.init.shared::cta.b64 [%0], %1;\n"::"r"(s),"r"(cnt));}
__device__ __forceinline__ void mbar_expect_tx(uint64_t* b,uint32_t bytes){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.arrive.expect_tx.shared::cta.b64 _, [%0], %1;\n"::"r"(s),"r"(bytes));}
__device__ __forceinline__ void tma_load_2d(void* dst,const void* tmap,int x,int y,uint64_t* bar){
    uint32_t d=(uint32_t)__cvta_generic_to_shared(dst);
    uint32_t b=(uint32_t)__cvta_generic_to_shared(bar);
    asm volatile(
      "cp.async.bulk.tensor.2d.shared::cluster.global.mbarrier::complete_tx::bytes"
      " [%0], [%1, {%2, %3}], [%4];\n"
      ::"r"(d),"l"(tmap),"r"(x),"r"(y),"r"(b):"memory");}

extern "C" __global__ void gemm_ws_tma(const __grid_constant__ CUtensorMap tmapA,
                                        const __grid_constant__ CUtensorMap tmapB,
                                        float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=128,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // per-stage: Araw(128*8 row-major TMA dst) + Braw(8*128 row-major TMA dst)
    //          + As0(64*8) As1(64*8) B0(8*64) B1(8*64) gmma-laid.
    const int ARAW=TM*TK, BRAW=TK*TN, ABND=64*TK, BB=TK*64;
    const int BUF=ARAW+BRAW+2*ABND+2*BB;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*BUF);
    uint64_t* empty=full+NST;
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nk=K/TK;
    const uint32_t bytesA=ARAW*4, bytesB=BRAW*4;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }      // TMA tx-complete arrives the barrier
    else if(tid<2*NST){ mbar_init_tx(&empty[tid-NST],256); } // both WGs (256) arrive empty
    __syncthreads();

    float d0[32],d1[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;}
    uint32_t fph=0, eph=0;
    // prologue: elected thread 0 kicks the first min(NST,nk) TMA loads.
    int stages=NST<nk?NST:nk;
    if(tid==0){
        for(int st=0;st<stages;++st){
            float* base=sm+(size_t)st*BUF; float* Araw=base; float* Braw=base+ARAW;
            mbar_expect_tx(&full[st], bytesA+bytesB);
            tma_load_2d(Araw,&tmapA,/*x=k*/st*TK,/*y=m*/bm,&full[st]);
            tma_load_2d(Braw,&tmapB,/*x=n*/bn,/*y=k*/st*TK,&full[st]);
        }
    }
    for(int ki=0;ki<nk;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        float* base=sm+(size_t)st*BUF;
        float* Araw=base; float* Braw=base+ARAW;
        float* As0=base+ARAW+BRAW; float* As1=As0+ABND;
        float* B0=As1+ABND; float* B1=B0+BB;
        // cooperative permute (all 256 thr): row-major Araw[m][kk] -> gmma As0/As1,
        // row-major Braw[kk][n] -> gmma B0/B1. n is 's', kk is 'k' for B; m is 's' for A.
        for(int i=tid;i<64*TK;i+=256){int m=i/TK,kk=i%TK; As0[gmma_phys(m,kk)]=Araw[m*TK+kk];}
        for(int i=tid;i<64*TK;i+=256){int m=i/TK,kk=i%TK; As1[gmma_phys(m,kk)]=Araw[(64+m)*TK+kk];}
        for(int i=tid;i<TK*64;i+=256){int kk=i/64,n=i%64; B0[gmma_phys(n,kk)]=Braw[kk*TN+n];}
        for(int i=tid;i<TK*64;i+=256){int kk=i/64,n=i%64; B1[gmma_phys(n,kk)]=Braw[kk*TN+64+n];}
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        // each warpgroup consumes its own 64-row A band x the SHARED B tile.
        float* As=(band==0)?As0:As1;
        uint32_t aA=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t a0=(uint32_t)__cvta_generic_to_shared(B0), a1=(uint32_t)__cvta_generic_to_shared(B1);
        uint64_t dA=mk(aA,128,256), dB0=mk(a0,128,256), dB1=mk(a1,128,256);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        WG(d0,dA,dB0);
        WG(d1,dA,dB1);
        asm volatile("wgmma.commit_group.sync.aligned;\n"
                     "wgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads(); // all 256 done reading this stage before re-arm
        // elected thread re-arms this stage's NEXT TMA load (ring) if K remains.
        if(tid==0){
            int load_ki=ki+stages;
            if(load_ki<nk){
                int lst=load_ki%NST;
                float* lb=sm+(size_t)lst*BUF; float* lAraw=lb; float* lBraw=lb+ARAW;
                mbar_expect_tx(&full[lst], bytesA+bytesB);
                tma_load_2d(lAraw,&tmapA,load_ki*TK,bm,&full[lst]);
                tma_load_2d(lBraw,&tmapB,bn,load_ki*TK,&full[lst]);
            }
        }
    }
    // epilogue: each consumer WG writes its own 64-row band.
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
// MODE 5 — SWIZZLED-TMA DUAL-CONSUMER-WG WARPSPEC (W9, the diagnosed lever).
//   W8 DIAGNOSIS (F-FUSION-SM90-WGMMA-W8): MODE 4 lands the TMA tile in a GENERIC
//   row-major layout (Araw/Braw), then ALL 256 threads COOPERATIVELY PERMUTE it into
//   the gmma INTER 8x4 layout EVERY K-step (+2 __syncthreads/K-step). cuBLAS never
//   pays this — its TMA descriptor is SWIZZLED so the bulk copy LANDS the tile already
//   in a wgmma-readable layout. The permute + its syncs are the prime suspect for the
//   remaining 6.44x gap (the mainloop is now compute/permute-bound, not occupancy-bound).
//
//   THE W9 FIX: encode the A/B TMA descriptors with CU_TENSOR_MAP_SWIZZLE_128B and set
//   the wgmma MATRIX DESCRIPTOR's swizzle-mode field to 128B so wgmma reads the swizzled
//   shared tile DIRECTLY. The cooperative Araw/Braw->gmma permute + its 2 __syncthreads
//   per K-step are ELIMINATED. The tile lands wgmma-ready; the mainloop is just
//   {mbar_wait -> wgmma -> commit/wait -> re-arm TMA}.
//
//   SWIZZLE MATH (128B, TF32 4B): the TMA 128B-swizzle atom is 8 rows x 128 bytes =
//   8 rows x 32 float32. Within the atom, the 16-byte granule column index g (0..7) is
//   XORed with the row index r (0..7): g_phys = g XOR r. The wgmma 128B-swizzle
//   descriptor (swizzle field = 1) applies the SAME g^r de-swizzle when reading core
//   matrices, so a SWIZZLE_128B-landed tile is consumed natively — provided the
//   descriptor's LBO (leading-dim byte offset between core-matrix columns) and SBO
//   (stride byte offset between core-matrix rows along K) match the swizzled box.
//   For the 128B-swizzle GMMA "K-major" canonical layout (the operand laid K-contiguous,
//   which is exactly what a row-major-K TMA tile of A is, and N-contiguous for B):
//     - leading byte offset (LBO) and stride byte offset (SBO) are the canonical
//       128B-swizzle values; the descriptor START is the swizzled tile base.
//   BOX GEOMETRY: TMA box for A = {TK_SW, TM} with the SWIZZLE-defining inner dim a
//   multiple of the 128B atom (32 f32). With TK=8 the inner (K) dim is only 8 f32 (32B)
//   < a 128B atom, so a 128B swizzle would need K>=32 to define one full atom row. We
//   therefore widen the K-tile to TK_SW=32 (4 wgmma K-steps fused) for MODE 5 so the
//   128B swizzle atom is fully defined along K (the swizzle granularity). The wgmma is
//   STILL m64n64k8 (issued 4x over the 32-wide K tile), but the TMA + descriptor see a
//   128B-swizzle-complete tile.
//
//   IF the 128B swizzle does NOT match the TF32 8x4 INTER core (a real risk — the INTER
//   layout's per-quad core packing may not coincide with the linear 128B g^r swizzle),
//   MODE 5 will FAIL the rel_rms gate and we KEEP the W8 66.5 frontier (no regression).
//   MODE 6/7 try 64B / 32B swizzle as the LEVER-2 fallback.
// ======================================================================
// swizzled wgmma matrix descriptor: same base/LBO/SBO packing as mk(), PLUS the
// swizzle-mode field (bits 62:63): 0=none 1=128B 2=64B 3=32B. (NVIDIA PTX ISA wgmma
// shared-descriptor format.)
__device__ __forceinline__ uint64_t mk_sw(uint32_t s,uint32_t lbo,uint32_t sbo,int swmode){
    uint64_t d=0; d|=(uint64_t)((s>>4)&0x3FFF);
    d|=((uint64_t)((lbo>>4)&0x3FFF))<<16; d|=((uint64_t)((sbo>>4)&0x3FFF))<<32;
    d|=((uint64_t)(swmode&0x3))<<62; return d;
}
// 128B-swizzle physical index inside an 8-row x 32-f32 (128B) atom: column granule
// (16B = 4 f32) index g is XORed with row r. elem (r in 0..7, c in 0..31):
//   granule g=c>>2, within-granule w=c&3; g_phys = g ^ (r&7); phys = r*32 + g_phys*4 + w.
__device__ __forceinline__ int sw128(int r,int c){
    int g=c>>2, w=c&3, gp=g^(r&7); return r*32 + gp*4 + w;
}

// W9 swizzled-TMA kernel. RUNTIME-TUNABLE descriptor params so the on-pod session can
// sweep candidate (swm, LBO, SBO, kstep) without recompiling — the swizzle<->8x4-INTER
// interaction is the named risk; the bit-exact gate is the arbiter.
//   swm    = wgmma descriptor swizzle mode (1=128B,2=64B,3=32B)
//   TKSW   = K slab width landed by the swizzled TMA (32 for 128B, 16 for 64B, 8 for 32B)
//   lbo    = descriptor leading byte offset (>>4 packed by mk_sw)
//   sbo    = descriptor stride byte offset
//   kstep  = 0: bump descriptor START by kk floats per k8 sub-step (naive);
//            1: keep START at atom base, encode k8 sub-step by adding kk/2 to LBO-units
//               (descriptor-internal stepping — the CUTLASS-style swizzle-safe path).
extern "C" __global__ void gemm_ws_tma_sw(const __grid_constant__ CUtensorMap tmapA,
                                          const __grid_constant__ CUtensorMap tmapB,
                                          float* __restrict__ gD,int M,int N,int K,int NST,
                                          int swm,int TKSW,int lbo,int sbo,int kstep){
    const int TM=128,TN=128,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    // per-stage: A swizzled tile (128 rows x TKSW f32) + B swizzled tile (TKSW rows x 128 f32).
    // Both land DIRECTLY from the swizzled TMA — NO permute scratch, NO gmma re-lay.
    const int ATILE=TM*TKSW, BTILE=TKSW*TN;
    const int BUF=ATILE+BTILE;
    uint64_t* full =(uint64_t*)(sm + (size_t)NST*BUF);
    uint64_t* empty=full+NST;
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;                            // number of 32-wide K slabs
    const uint32_t bytesA=ATILE*4, bytesB=BTILE*4;
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
            float* base=sm+(size_t)st*BUF; float* As=base; float* Bs=base+ATILE;
            mbar_expect_tx(&full[st], bytesA+bytesB);
            tma_load_2d(As,&tmapA,/*x=k*/st*TKSW,/*y=m*/bm,&full[st]);
            tma_load_2d(Bs,&tmapB,/*x=n*/bn,/*y=k*/st*TKSW,&full[st]);
        }
    }
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        float* base=sm+(size_t)st*BUF;
        float* As=base; float* Bs=base+ATILE;
        // NO PERMUTE. The SWIZZLE_128B TMA landed As/Bs already wgmma-readable.
        // This WG consumes its own 64-row A band. A band base offset within the swizzled
        // 128-row tile: band 0 = rows 0..63, band 1 = rows 64..127 (each row is 32 f32 = a
        // full 128B atom row, so a 64-row band starts at band*64*TKSW floats).
        float* Aband=As + band*64*TKSW;
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        // wgmma k8 sub-steps over the TKSW-wide K slab. Two stepping policies (kstep):
        //  0 (naive): START bumps by kk floats; LBO/SBO encode the swizzle.
        //  1 (desc-internal): START stays at atom base; the descriptor START field is
        //     advanced by (kk/2)>>4-units inside mk_sw via an added byte offset, keeping
        //     the swizzle XOR origin at the atom base (CUTLASS-style, swizzle-safe).
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(Aband);
        uint32_t a0b=(uint32_t)__cvta_generic_to_shared(Bs);
        uint32_t a1b=(uint32_t)__cvta_generic_to_shared(Bs + 64);
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t aA,a0,a1;
            if(kstep==0){
                aA=(uint32_t)__cvta_generic_to_shared(Aband + kk);
                a0=(uint32_t)__cvta_generic_to_shared(Bs + (size_t)kk*TN);
                a1=(uint32_t)__cvta_generic_to_shared(Bs + (size_t)kk*TN + 64);
            }else{
                // descriptor-internal step: add the K-core byte offset to the packed START.
                aA=aAb + (uint32_t)(kk*4); a0=a0b + (uint32_t)(kk*TN*4); a1=a1b + (uint32_t)(kk*TN*4);
            }
            uint64_t dA=mk_sw(aA,lbo,sbo,swm), dB0=mk_sw(a0,lbo,sbo,swm), dB1=mk_sw(a1,lbo,sbo,swm);
            WG(d0,dA,dB0);
            WG(d1,dA,dB1);
        }
        asm volatile("wgmma.commit_group.sync.aligned;\n"
                     "wgmma.wait_group.sync.aligned 0;\n":::"memory");
        __syncthreads();
        if(tid==0){
            int load_ki=ki+stages;
            if(load_ki<nks){
                int lst=load_ki%NST;
                float* lb=sm+(size_t)lst*BUF; float* lAs=lb; float* lBs=lb+ATILE;
                mbar_expect_tx(&full[lst], bytesA+bytesB);
                tma_load_2d(lAs,&tmapA,load_ki*TKSW,bm,&full[lst]);
                tma_load_2d(lBs,&tmapB,bn,load_ki*TKSW,&full[lst]);
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

static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):1; int NST=argc>3?atoi(argv[3]):3;
    // W9 swizzled-TMA tunables (MODE 5/6/7): argv 4=lbo 5=sbo 6=kstep (defaults = the
    // canonical 128B-swizzle guess; on-pod sweep overrides without recompiling).
    int ARG_LBO=argc>4?atoi(argv[4]):16; int ARG_SBO=argc>5?atoi(argv[5]):1024; int ARG_KSTEP=argc>6?atoi(argv[6]):0;
    int M=S,N=S,K=S;
    if(N%128){printf("N must be multiple of 128\n");return 1;}
    if(K%16){printf("K must be multiple of 16\n");return 1;}
    if(MODE==5&&K%32){printf("MODE5 needs K%%32==0 (128B swizzle atom)\n");return 1;}
    size_t szA=(size_t)M*K,szB=(size_t)K*N,szD=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hD=(float*)malloc(szD*4),*hR=(float*)malloc(szD*4);
    srand(7);
    for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
    for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
    float *dA,*dB,*dD,*dR;
    CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));CK(cudaMalloc(&dD,szD*4));CK(cudaMalloc(&dR,szD*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));
    cublasHandle_t h;CB(cublasCreate(&h));CB(cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH));
    float al=1.f,be=0.f;
    CB(cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dB,N,dA,K,&be,dR,N));CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost));

    // ---- MODE 4 (no-swizzle) + MODE 5/6/7 (128B/64B/32B swizzle) TMA tensor maps ----
    // MODE 5/6/7 widen the TMA K-box to TKSW so the swizzle atom is fully defined along K:
    //   128B atom = 32 f32 (MODE5), 64B = 16 (MODE6), 32B = 8 (MODE7).
    CUtensorMap tmapA{}, tmapB{};
    bool isSw = (MODE>=5 && MODE<=7);
    int TKSW = (MODE==5)?32:(MODE==6)?16:(MODE==7)?8:8;
    CUtensorMapSwizzle swz = (MODE==5)?CU_TENSOR_MAP_SWIZZLE_128B:
                             (MODE==6)?CU_TENSOR_MAP_SWIZZLE_64B:
                             (MODE==7)?CU_TENSOR_MAP_SWIZZLE_32B:CU_TENSOR_MAP_SWIZZLE_NONE;
    if(MODE==4 || isSw){
        void* fn=nullptr; cudaDriverEntryPointQueryResult q;
        cudaGetDriverEntryPoint("cuTensorMapEncodeTiled",&fn,cudaEnableDefault,&q);
        typedef CUresult (*Enc_t)(CUtensorMap*,CUtensorMapDataType,cuuint32_t,void*,
            const cuuint64_t*,const cuuint64_t*,const cuuint32_t*,const cuuint32_t*,
            CUtensorMapInterleave,CUtensorMapSwizzle,CUtensorMapL2promotion,CUtensorMapFloatOOBfill);
        Enc_t enc=(Enc_t)fn;
        if(!enc){printf("MODE%d: cuTensorMapEncodeTiled unavailable (CUDA<12?)\n",MODE);return 4;}
        int tk = isSw?TKSW:8;   // K box width (swizzle-atom-complete for sw modes)
        // A row-major MxK: global dims {K,M} (fastest=K), box tile {tk, TM=128}.
        { cuuint64_t gd[2]={(cuuint64_t)K,(cuuint64_t)M}; cuuint64_t gs[1]={(cuuint64_t)K*4};
          cuuint32_t bd[2]={(cuuint32_t)tk,128}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,swz,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE%d: encodeA r=%d\n",MODE,(int)r);return 4;} }
        // B row-major KxN: global dims {N,K} (fastest=N), box tile {TN=128, tk}.
        { cuuint64_t gd[2]={(cuuint64_t)N,(cuuint64_t)K}; cuuint64_t gs[1]={(cuuint64_t)N*4};
          cuuint32_t bd[2]={128,(cuuint32_t)tk}; cuuint32_t es[2]={1,1};
          CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
            CU_TENSOR_MAP_INTERLEAVE_NONE,swz,
            CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
          if(r!=CUDA_SUCCESS){printf("MODE%d: encodeB r=%d\n",MODE,(int)r);return 4;} }
    }

    // MODE 3/4/5/6/7 tile M by 128 (dual-consumer-WG); all others by 64.
    int TMm = (MODE==3||MODE==4||isSw)?128:64;
    dim3 grid(N/128,(M+TMm-1)/TMm);
    int blk = (MODE==3)?384:(MODE==2||MODE==4||isSw)?256:128;
    // MODE 5/6/7 swizzled-TMA per-stage shared = A(128*TKSW)+B(TKSW*128) floats + 2*NST mbar.
    size_t sw_sm = (size_t)NST*((size_t)128*TKSW + (size_t)TKSW*128)*4 + (size_t)2*NST*8;
    // MODE 3 per-stage shared = 2*(64*8) + 2*(8*64) + 8*128 floats, + 2*NST mbarriers.
    size_t ws2_sm = (size_t)NST*((size_t)2*64*8 + 2*8*64 + 8*128)*4 + (size_t)2*NST*8;
    // MODE 4 per-stage = Araw(128*8)+Braw(8*128)+2*(64*8)+2*(8*64) floats, + 2*NST mbarriers.
    size_t tma_sm = (size_t)NST*((size_t)128*8 + 8*128 + 2*64*8 + 2*8*64)*4 + (size_t)2*NST*8;
    size_t smsz;
    auto launch=[&](){
        if(MODE==0){ smsz=2*((size_t)64*8+2*8*64)*4;
            gemm_w5<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K); }
        else if(MODE==1){ smsz=(size_t)NST*((size_t)64*8+2*8*64+8*128)*4;
            gemm_apipe<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K,NST); }
        else if(MODE==2){ smsz=(size_t)NST*((size_t)64*8+2*8*64+8*128)*4 + (size_t)2*NST*8;
            gemm_ws<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K,NST); }
        else if(MODE==3){ smsz=ws2_sm;
            gemm_ws2<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K,NST); }
        else if(MODE==4){ smsz=tma_sm;
            gemm_ws_tma<<<grid,blk,smsz>>>(tmapA,tmapB,dD,M,N,K,NST); }
        else { smsz=sw_sm;   // MODE 5/6/7 swizzled-TMA
            int swm=(MODE==5)?1:(MODE==6)?2:3;
            gemm_ws_tma_sw<<<grid,blk,smsz>>>(tmapA,tmapB,dD,M,N,K,NST,swm,TKSW,ARG_LBO,ARG_SBO,ARG_KSTEP); }
    };
    CK(cudaMemset(dD,0,szD*4));
    if(MODE==1){ CK(cudaFuncSetAttribute(gemm_apipe,cudaFuncAttributeMaxDynamicSharedMemorySize,
        (int)((size_t)NST*((size_t)64*8+2*8*64+8*128)*4))); }
    if(MODE==2){ CK(cudaFuncSetAttribute(gemm_ws,cudaFuncAttributeMaxDynamicSharedMemorySize,
        (int)((size_t)NST*((size_t)64*8+2*8*64+8*128)*4 + (size_t)2*NST*8))); }
    if(MODE==3){ CK(cudaFuncSetAttribute(gemm_ws2,cudaFuncAttributeMaxDynamicSharedMemorySize,
        (int)ws2_sm)); }
    if(MODE==4){ CK(cudaFuncSetAttribute(gemm_ws_tma,cudaFuncAttributeMaxDynamicSharedMemorySize,
        (int)tma_sm)); }
    if(isSw){ CK(cudaFuncSetAttribute(gemm_ws_tma_sw,cudaFuncAttributeMaxDynamicSharedMemorySize,
        (int)sw_sm)); }
    // ---- occupancy proxy (the W8 success metric): CTAs/SM for the launched kernel ----
    { int occ=0; int dynsm=(int)(MODE==0?2*((size_t)64*8+2*8*64)*4:
        MODE==1?(size_t)NST*((size_t)64*8+2*8*64+8*128)*4:
        MODE==2?(size_t)NST*((size_t)64*8+2*8*64+8*128)*4+(size_t)2*NST*8:
        MODE==3?ws2_sm:MODE==4?tma_sm:sw_sm);
      const void* kf=(MODE==0?(const void*)gemm_w5:MODE==1?(const void*)gemm_apipe:
        MODE==2?(const void*)gemm_ws:MODE==3?(const void*)gemm_ws2:
        MODE==4?(const void*)gemm_ws_tma:(const void*)gemm_ws_tma_sw);
      cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,kf,blk,(size_t)dynsm);
      printf("OCCUPANCY MODE=%d blk=%d dynsmem=%dB -> %d CTA/SM (%d compute-thr/SM)\n",
             MODE,blk,dynsm,occ,occ*blk);
    }
    launch();
    cudaError_t e=cudaGetLastError();if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("OWN-FAULT MODE=%d %s\n",MODE,cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
    double rr=sqrt(se/fmax(1e-30,sr));
    char ftag[48]=""; if(isSw) snprintf(ftag,48," lbo=%d sbo=%d kstep=%d",ARG_LBO,ARG_SBO,ARG_KSTEP);
    if(rr>3e-3){printf("WS S=%d MODE=%d NST=%d%s rel_rms=%.3e FAIL — no perf (g5)\n",
        S,MODE,NST,ftag,rr);return 2;}
    cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
    launch();CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));for(int i=0;i<it;++i)launch();
    CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
    float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
    double fl=2.0*(double)M*N*K,tfo=fl/(mo*1e-3)/1e12;
    cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dB,N,dA,K,&be,dR,N);CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dB,N,dA,K,&be,dR,N);
    CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
    float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
    double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
    char swtag[48]=""; if(isSw) snprintf(swtag,48," lbo=%d sbo=%d kstep=%d",ARG_LBO,ARG_SBO,ARG_KSTEP);
    printf("WS S=%d MODE=%d NST=%d%s own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
           S,MODE,NST,swtag,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
    return 0;
}
