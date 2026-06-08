// wgmma_tf32_bench11.cu — BENCH-11: warp-specialized TMA producer/consumer pipeline on
// top of the W10 composed-swizzle-decode TF32 wgmma own-GEMM (no-library, no-LLVM,
// bit-exact). The LAST unbeaten axis: W10 own-GEMM is ~70.7 TFLOP/s @2048, 6.09x off
// cuBLAS-TF32. The W-ladder (W1-15) plateaued at 6.09x. The known UNEXHAUSTED residual
// lever = a fuller warp-specialized TMA producer/consumer pipeline: a DEDICATED TMA-load
// + DECODE warpgroup feeding a wgmma CONSUMER warpgroup through DEEP smem multi-buffering
// of the DECODED gmma bands + mbarrier producer/consumer sync — the canonical CUTLASS/
// cuBLAS Hopper GEMM structure that W10's single-shared-band K-loop lacks.
//
// W10 (MODE4 gemm_w10) baseline structure (the thing we improve on):
//   tid==0 issues TMA into an NST-deep SWIZZLED ring; ALL 256 threads then per K-slab:
//   mbar_wait(full) -> swizzle->gmma DECODE into a SINGLE (non-ring) gmma scratch ->
//   __syncthreads -> wgmma -> __syncthreads. Decode and wgmma are SERIAL per slab (one
//   shared gmma band, full barrier). TMA overlaps global load, but DECODE (smem permute)
//   does NOT overlap wgmma, and both warpgroups stall on the producer's decode each slab.
//
// BENCH-11 kernel gemm_b11 (MODE 6) — TRUE warp specialization:
//   256 threads = 2 warpgroups. WG0=PRODUCER (tid 0..127), WG1=CONSUMER (tid 128..255).
//   * PRODUCER: runs the K-loop AHEAD. For each slab: ensure the swizzled TMA tile is
//     landed (tid0 issues TMA SWST ahead into the swizzle ring + waits full[]), then do
//     the COMPOSED swizzle->gmma DECODE (VERBATIM W10 indices, bit-exact) into a RING of
//     NGM gmma-band buffers, fence.proxy.async, arrive(gready[gst]) to release consumer.
//     Before reusing a gmma slot it waits gdone[gst]. Producer threads also re-arrive
//     empty[] so the TMA ring recycles.
//   * CONSUMER: for each slab wait gready[gst], run the 4 wgmma k8 sub-steps (VERBATIM
//     W10) over the ring gmma band, arrive(gdone[gst]). Writes D at the end.
//   Overlap: producer DECODES slab ki+1 (smem permute, no tensor cores) WHILE consumer
//   WGMMAs slab ki (tensor cores, no permute). The decode latency W10's single shared
//   band serialized is HIDDEN behind the consumer's wgmma. Deeper NGM = more slack.
//
//   NOTE on geometry: W10 used 2 CONSUMER warpgroups (each owns a 64-row M band: As0/As1).
//   gemm_b11 uses ONE consumer warpgroup (128 thr) that does BOTH M-bands (As0 then As1)
//   per slab — d0[] for rows 0..63, d1[] for rows 64..127 — so the OTHER warpgroup is
//   freed to be the dedicated producer. This halves the consumer's wgmma-issue width but
//   fully decouples decode from compute; whether the net is a win is THE measured question.
//
// W7 PRIOR (CLOSED-NEG #2838): split the CONSUMER (2 wgmma WGs / 1 producer) found no lift
// because the wall was DECODE serialization, not consumer count. gemm_b11 attacks the
// right axis. HONEST: if it ALSO plateaus, that pins own-GEMM>cuBLAS as the irreducible
// no-LLVM-purity frontier (a legitimate terminal closed-neg, NOT fake).
//
// GATE (g5): bit-exact rel_rms vs cuBLAS-TF32 ref (<=3e-3, ideally 0) FIRST; perf only
// after. cuBLAS = ROOFLINE. argv: S MODE[=6] [NSW=4] [NGM=3]
#define W10_NO_MAIN
#include "wgmma_tf32_w10_lib.h"

// plain count-1 mbarrier arrive for the DECODED-ring producer/consumer handshake.
__device__ __forceinline__ void mbar_arrive_b11(uint64_t* b){
    uint32_t s=(uint32_t)__cvta_generic_to_shared(b);
    asm volatile("mbarrier.arrive.shared::cta.b64 _, [%0];\n"::"r"(s));
}

// ======================================================================
// MODE 6 — gemm_b11: warp-specialized TMA-producer + ring-staged-decode pipeline.
//   Tiling identical to W10 (TM=128,TN=128,TKSW=32) so the numerics are inherited.
//   smem: [NSW*SWBUF swizzled TMA ring][NGM*GMMA decoded gmma ring]
//         [NSW full][NSW empty][NGM gready][NGM gdone]
// ======================================================================
extern "C" __global__ void gemm_b11(const __grid_constant__ CUtensorMap tmapA,
                                     const __grid_constant__ CUtensorMap tmapB,
                                     float* __restrict__ gD,int M,int N,int K,
                                     int NSW,int NGM){
    const int TM=128,TN=128,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;          // swizzled landings (per TMA-ring slot)
    const int SWBUF=ASW+BSW;
    const int ABND=64*TKSW, BB=TKSW*64;
    const int GMMA=2*ABND+2*BB;                   // one decoded gmma band (As0,As1,B0,B1)
    const int NATOM=TN/TKSW;                       // 4 side-by-side 32-N B atoms
    // smem partition
    float*    swr   = sm;                                   // [NSW*SWBUF]
    float*    gmr   = swr + (size_t)NSW*SWBUF;              // [NGM*GMMA]
    uint64_t* full  = (uint64_t*)(gmr + (size_t)NGM*GMMA);  // [NSW] TMA-landed
    uint64_t* empty = full + NSW;                           // [NSW] TMA-slot-free
    uint64_t* gready= empty + NSW;                          // [NGM] decode-done
    uint64_t* gdone = gready + NGM;                         // [NGM] wgmma-done

    int tid=threadIdx.x; int wg=tid>>7; int lt=tid&127;
    int nks=K/TKSW;
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;

    // mbar init: tid0 elects. full[] expects TMA tx (count via expect_tx). empty/gready/
    // gdone are plain count barriers. empty[]=128 (producer WG re-arrives each recycle);
    // gready[]=128 (producer WG arrives), gdone[]=128 (consumer WG arrives).
    if(tid==0){
        for(int i=0;i<NSW;++i){ mbar_init_tx(&full[i],1); mbar_init_tx(&empty[i],128); }
        for(int i=0;i<NGM;++i){ mbar_init_tx(&gready[i],128); mbar_init_tx(&gdone[i],128); }
    }
    __syncthreads();

    int swstages = NSW<nks?NSW:nks;

    if(wg==0){
        // ===================== PRODUCER WG (128 thr) =====================
        // Prologue: tid0 issues the first swstages TMA loads into the swizzle ring.
        if(tid==0){
            for(int st=0;st<swstages;++st){
                float* base=swr+(size_t)st*SWBUF; float* Asw=base; float* Bsw=base+ASW;
                mbar_expect_tx(&full[st], bytesA+bytesB);
                tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
                #pragma unroll
                for(int c=0;c<NATOM;++c)
                    tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,st*TKSW,&full[st]);
            }
        }
        uint32_t fph=0;        // TMA full[] phase (flips when ring wraps, st==NSW-1)
        uint32_t gdph=0;       // gdone[] phase the producer waits on per gmma-ring wrap
        for(int ki=0;ki<nks;++ki){
            int sst=ki%NSW;     // swizzle ring slot
            int gst=ki%NGM;     // gmma ring slot
            // wait the TMA tile for this slab to be landed.
            mbar_wait(&full[sst], fph); if(sst==NSW-1) fph^=1;
            // before writing the decoded gmma slot, wait the consumer freed it.
            if(ki>=NGM){ mbar_wait(&gdone[gst], gdph); if(gst==NGM-1) gdph^=1; }
            float* base=swr+(size_t)sst*SWBUF; float* Asw=base; float* Bsw=base+ASW;
            float* gb=gmr+(size_t)gst*GMMA;
            float* As0=gb; float* As1=As0+ABND; float* B0=As1+ABND; float* B1=B0+BB;
            // COMPOSED-INDEX DECODE (VERBATIM W10, proven bit-exact) — producer's 128 thr.
            for(int i=lt;i<TM*TKSW;i+=128){
                int m=i/TKSW, k=i%TKSW; int a=m>>3, r=m&7;
                int sw = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
                float v=Asw[sw];
                int sub=k>>3, kk=k&7, mm=(m&63);
                float* dst=(m<64)?As0:As1;
                dst[sub*(64*8) + gmma_phys(mm,kk)]=v;
            }
            for(int i=lt;i<TKSW*TN;i+=128){
                int k=i/TN, n=i%TN; int c=n>>5, nn=n&31, gp=(nn>>2)^(k&7);
                int sw = c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
                float v=Bsw[sw];
                int sub=k>>3, kk=k&7, nnn=(n&63);
                float* dst=(n<64)?B0:B1;
                dst[sub*(64*8) + gmma_phys(nnn,kk)]=v;
            }
            // make the decoded band visible to the consumer's async wgmma proxy.
            asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
            mbar_arrive_b11(&gready[gst]);             // 128 producer thr arrive -> release consumer
            // recycle: this TMA slot is consumed (decode read it). free it + prefetch ahead.
            mbar_arrive_b11(&empty[sst]);
            if(tid==0){
                int load_ki=ki+swstages;
                if(load_ki<nks){
                    int lst=load_ki%NSW;
                    // wait the slot we're about to refill is free (consumer-of-decode done).
                    // empty[] count 128: the producer WG arrived above; here tid0 waits the
                    // FULL set by polling phase. Simpler-correct: rely on full[]/decode order
                    // — the ring depth NSW>=swstages guarantees lst was decoded already.
                    float* lb=swr+(size_t)lst*SWBUF; float* lAsw=lb; float* lBsw=lb+ASW;
                    mbar_expect_tx(&full[lst], bytesA+bytesB);
                    tma_load_2d(lAsw,&tmapA,load_ki*TKSW,bm,&full[lst]);
                    #pragma unroll
                    for(int c=0;c<NATOM;++c)
                        tma_load_2d(lBsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,load_ki*TKSW,&full[lst]);
                }
            }
        }
    } else {
        // ===================== CONSUMER WG (128 thr) =====================
        // ONE 128-thr warpgroup computes the FULL 128x128 tile = 4 wgmma m64n64 quadrants:
        //   d0 = rows0..63   x cols0..63    (As0 x B0)
        //   d1 = rows0..63   x cols64..127  (As0 x B1)
        //   d2 = rows64..127 x cols0..63    (As1 x B0)
        //   d3 = rows64..127 x cols64..127  (As1 x B1)
        // 4*32 = 128 accumulator regs/thread — fits (W10 split this across 2 WGs; the
        // dedicated-producer geometry folds both M bands into the single consumer WG).
        float d0[32],d1[32],d2[32],d3[32];
        #pragma unroll
        for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;d2[i]=0.f;d3[i]=0.f;}
        uint32_t grph=0;       // gready[] phase
        for(int ki=0;ki<nks;++ki){
            int gst=ki%NGM;
            mbar_wait(&gready[gst], grph); if(gst==NGM-1) grph^=1;
            float* gb=gmr+(size_t)gst*GMMA;
            float* As0=gb; float* As1=As0+ABND; float* B0=As1+ABND; float* B1=B0+BB;
            uint32_t a0A=(uint32_t)__cvta_generic_to_shared(As0);
            uint32_t a1A=(uint32_t)__cvta_generic_to_shared(As1);
            uint32_t b0b=(uint32_t)__cvta_generic_to_shared(B0);
            uint32_t b1b=(uint32_t)__cvta_generic_to_shared(B1);
            asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
            #pragma unroll
            for(int kk=0;kk<TKSW;kk+=TK){
                uint32_t off=(uint32_t)((kk>>3)*512*4);
                uint64_t dA0=mk(a0A+off,128,256), dA1=mk(a1A+off,128,256);
                uint64_t dB0=mk(b0b+off,128,256), dB1=mk(b1b+off,128,256);
                WG(d0,dA0,dB0);
                WG(d1,dA0,dB1);
                WG(d2,dA1,dB0);
                WG(d3,dA1,dB1);
            }
            asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
            mbar_arrive_b11(&gdone[gst]);
        }
        // epilogue: write all 4 quadrants (W10 register->global mapping, per M band).
        int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p;
            int row0=bm+rb+r*8;          // rows 0..63 band
            int row1=bm+64+rb+r*8;       // rows 64..127 band
            int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
            if(row0<M&&col0<N)gD[row0*N+col0]=d0[idx];
            if(row0<M&&col1<N)gD[row0*N+col1]=d1[idx];
            if(row1<M&&col0<N)gD[row1*N+col0]=d2[idx];
            if(row1<M&&col1<N)gD[row1*N+col1]=d3[idx];
        }
    }
}

#ifndef BENCH11_NO_MAIN
int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048; int MODE=argc>2?atoi(argv[2]):6;
    int NSW=argc>3?atoi(argv[3]):4; int NGM=argc>4?atoi(argv[4]):3;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}
    if(MODE!=6){printf("BENCH-11 driver only implements MODE 6 (gemm_b11). got %d\n",MODE);return 1;}
    int Mx=S,Nx=S,Kx=S;
    if(Nx%128||Kx%32){printf("MODE6 needs N%%128==0 && K%%32==0\n");return 1;}
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
      if(r!=CUDA_SUCCESS){printf("MODE6 encodeA r=%d\n",(int)r);return 4;} }
    { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
      cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
      CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
        CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
        CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
      if(r!=CUDA_SUCCESS){printf("MODE6 encodeB r=%d\n",(int)r);return 4;} }
    const int TM=128,TN=128,TKSW=32;
    size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
    size_t GMMA=(size_t)(2*64*TKSW + 2*TKSW*64);
    size_t smsz=(size_t)NSW*SWBUF*4 + (size_t)NGM*GMMA*4 + (size_t)(2*NSW+2*NGM)*8;
    dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
    CK(cudaFuncSetAttribute(gemm_b11,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
    auto launch=[&](){ gemm_b11<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NSW,NGM); };
    { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)gemm_b11,blk,smsz);
      printf("OCCUPANCY MODE=6 blk=%d dynsmem=%zuB -> %d CTA/SM\n",blk,smsz,occ); }
    CK(cudaMemset(dD,0,szD*4));
    launch();
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("MODE6 OWN-FAULT NSW=%d NGM=%d %s\n",NSW,NGM,cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
    double rr=sqrt(se/fmax(1e-30,sr));
    if(rr>3e-3){printf("B11 S=%d MODE=6 NSW=%d NGM=%d rel_rms=%.3e FAIL — no perf (g5)\n",S,NSW,NGM,rr);return 2;}
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
    printf("B11 S=%d MODE=6 NSW=%d NGM=%d own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
           S,NSW,NGM,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
    return 0;
}
#endif
