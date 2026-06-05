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
            float* B0=As+AB; float* B1=B0+BB;
            for(int i=lt;i<TK*64;i+=128){int kk=i/64,n=i%64; B0[gmma_phys(n,kk)]=Braw[kk*TN+n];}
            for(int i=lt;i<TK*64;i+=128){int kk=i/64,n=i%64; B1[gmma_phys(n,kk)]=Braw[kk*TN+64+n];}
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

static inline float tf(float x){uint32_t u;memcpy(&u,&x,4);u=(u+0x1000u)&0xFFFFE000u;float r;memcpy(&r,&u,4);return r;}

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):1; int NST=argc>3?atoi(argv[3]):3;
    int M=S,N=S,K=S;
    if(N%128){printf("N must be multiple of 128\n");return 1;}
    if(K%16){printf("K must be multiple of 16\n");return 1;}
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

    dim3 grid(N/128,(M+63)/64);
    int blk = (MODE==2)?256:128;
    size_t smsz;
    auto launch=[&](){
        if(MODE==0){ smsz=2*((size_t)64*8+2*8*64)*4;
            gemm_w5<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K); }
        else if(MODE==1){ smsz=(size_t)NST*((size_t)64*8+2*8*64+8*128)*4;
            gemm_apipe<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K,NST); }
        else { smsz=(size_t)NST*((size_t)64*8+2*8*64+8*128)*4 + (size_t)2*NST*8;
            gemm_ws<<<grid,blk,smsz>>>(dA,dB,dD,M,N,K,NST); }
    };
    CK(cudaMemset(dD,0,szD*4));
    if(MODE==1){ CK(cudaFuncSetAttribute(gemm_apipe,cudaFuncAttributeMaxDynamicSharedMemorySize,
        (int)((size_t)NST*((size_t)64*8+2*8*64+8*128)*4))); }
    if(MODE==2){ CK(cudaFuncSetAttribute(gemm_ws,cudaFuncAttributeMaxDynamicSharedMemorySize,
        (int)((size_t)NST*((size_t)64*8+2*8*64+8*128)*4 + (size_t)2*NST*8))); }
    launch();
    cudaError_t e=cudaGetLastError();if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("OWN-FAULT MODE=%d %s\n",MODE,cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
    double rr=sqrt(se/fmax(1e-30,sr));
    if(rr>3e-3){printf("WS S=%d MODE=%d NST=%d rel_rms=%.3e FAIL — no perf (g5)\n",S,MODE,NST,rr);return 2;}
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
    printf("WS S=%d MODE=%d NST=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
           S,MODE,NST,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
    return 0;
}
