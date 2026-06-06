// wgmma_tf32_w12.cu — W12: make the 128x256 output tile PAY OFF via the COUPLED LEVER that
// W11 (#2850) proved is required. W11 measured the 128x256 tile ALONE regresses (66.4 < W10
// 70.7) because it collapses occupancy 2->1 CTA/SM (smem 98->147 KB/CTA). The litscan ladder's
// tile<->warp-spec coupling: the big tile only pays with >=2 consumer warpgroups AND the smem
// held under the ~114 KB/CTA ceiling (2 CTA/SM on H100's 228KB/SM).
//
// Frontier to BEAT (do NOT regress): W10 composed-decode 70.7 TFLOP/s @4096^3, 6.09x off
// cuBLAS-TF32 ~431, bit-exact, 2 CTA/SM. cuBLAS-TF32 = ROOFLINE. NO superiority claim.
//
// ===================== THE COUPLED LEVER (W12, handoff 6068c270, BOTH together) =================
// (a) WARP-SPEC REGISTER REALLOCATION — setmaxnreg.inc/dec producer-warpgroup 40 regs /
//     consumer-warpgroups 232 regs (FA3/CUTLASS ping-pong). Single-elected-thread TMA producer
//     (from W8/W10) + 2 consumer warpgroups each issuing wgmma over the 128x256 tile.
// (b) SHRINK THE 128x256 SMEM UNDER ~114 KB/CTA so 2 CTA/SM residency is restored — by
//     ELIMINATING the W10 software full-K-slab decode-copy scratch (the named W10/W11 residual).
//     The W10/W11 GMMA scratch holds the FULL 32-wide K-slab decoded (4 K8 sub-tiles
//     concatenated = 2*ABND + NBLK*BB = 12288 floats = 48KB). But the wgmma consumes each K8
//     sub-tile SEQUENTIALLY. W12 decodes ONE K8 sub-tile at a time into a scratch sized for a
//     SINGLE sub-tile (2 A-bands + 4 B-blocks, each 64x8 = 512 floats -> 6*512 = 3072 floats =
//     12KB), reused across the 4 K8 sub-steps. This is a LAYOUT-EMIT on the consumer side (the
//     proven composed-decode index is UNCHANGED, just emitted per-sub instead of per-slab) — NOT
//     a descriptor change. HW in-place swizzle was RULED OUT in W10 (rel_rms floor 1.392).
//
// SMEM BUDGET (TN=256, TKSW=32, NST=2):
//   W11 MODE6:  NST*SWBUF(98304B) + GMMA_full(49152B) + mbar = 147472B  -> 1 CTA/SM (regress)
//   W12 MODE9:  NST*SWBUF(98304B) + GMMA_sub (12288B) + mbar = 110608B  -> target 2 CTA/SM
//   (the (b) sub-tile decode reclaims 36KB, dropping the per-CTA footprint under the ~114KB
//    ceiling so 2 CTA/SM is RESTORED — the W11-pinned gating dependency.)
//
// ===================== WARP-SPEC ROLE SPLIT (a) =====================
//   blockDim = 384 (3 warpgroups). WG0 = PRODUCER (TMA issue, 40 regs via setmaxnreg.dec).
//   WG1,WG2 = CONSUMERS (wgmma over the two 64-row M-bands, 232 regs via setmaxnreg.inc).
//   Producer/consumer handshake via mbarrier full[]/empty[] (the W10 mbar machinery).
//   The consumers each own one 64-row M-band and run all 4 N-blocks (B0..B3) of the 256 tile.
//
// MODES (argv: S MODE [NST]):
//   MODE 9  = 128x256 + warp-spec (a) + sub-tile decode (b). THE W12 kernel.
//   (W10 single-tile GATE via the W10 binary MODE 0/1 in w12_run.sh BEFORE this builds, then
//    full-GEMM rel_rms gate here BEFORE any perf number, g5.)
// Bit-exact GATE FIRST (single-tile rel_rms 0, then full rel_rms<=3e-3 ideally 0), g5.

#define W10_NO_MAIN 1
#include "wgmma_tf32_w10_lib.h"

// ======================================================================
// MODE 9 — W12: 128x256 + warp-spec register-realloc (a) + per-K8-sub decode (b).
//
//   Roles (blockDim=384): warpgroup wg=tid>>7.
//     wg==0  -> PRODUCER  (only the elected thread tid==0 issues TMA; rest idle, 40 regs)
//     wg==1  -> CONSUMER band 0 (M rows bm..bm+63), 232 regs
//     wg==2  -> CONSUMER band 1 (M rows bm+64..bm+127), 232 regs
//
//   smem layout: [NST*SWBUF swizzled ring][GMMA_sub decode scratch][NST full mbar][NST empty mbar]
//   GMMA_sub = 2 A-bands + 4 B-blocks, EACH a single 64x8 gmma_phys sub-tile (512 floats).
//   = 2*512 + 4*512 = 3072 floats. Decoded fresh per K8 sub-step (the (b) shrink).
//
//   The composed-decode index is the SAME proven law as W10/W11; only the SCRATCH FOOTPRINT
//   shrinks (one K8 sub at a time) and the producer is split into its own warpgroup (a).
// ======================================================================
extern "C" __global__ __launch_bounds__(384,2)
void gemm_w12(const __grid_constant__ CUtensorMap tmapA,
              const __grid_constant__ CUtensorMap tmapB,
              float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=256,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;            // swizzled landings (NST-deep ring)
    const int SWBUF=ASW+BSW;
    const int SUB=64*8;                            // one K8 gmma sub-tile = 512 floats
    const int NBLK=TN/64;                          // 4 N-blocks (B0..B3)
    const int GMMA=2*SUB + NBLK*SUB;               // 2 A-bands + 4 B-blocks, ONE sub each = 3072
    float* gmma=sm + (size_t)NST*SWBUF;
    uint64_t* full =(uint64_t*)(gmma + GMMA);
    uint64_t* empty=full+NST;
    int tid=threadIdx.x; int wg=tid>>7;            // 0=producer 1,2=consumers
    int cons=wg-1;                                 // consumer band index (0/1) for wg 1/2
    int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;                       // 8 side-by-side 32-N B atoms
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;

    // mbar init (one thread per barrier). full[] = TMA-arrival (1 tx-thread), empty[] = consumer
    // release (256 consumer threads across the 2 consumer warpgroups).
    if(wg==0 && lt<NST){ mbar_init_tx(&full[lt],1); }
    if(wg==0 && lt>=NST && lt<2*NST){ mbar_init_tx(&empty[lt-NST],256); }
    __syncthreads();

    // ---- (a) register realloc: producer sheds regs, consumers grab them ----
    if(wg==0){ asm volatile("{ setmaxnreg.dec.sync.aligned.u32 40; }\n":::); }
    else      { asm volatile("{ setmaxnreg.inc.sync.aligned.u32 232; }\n":::); }

    int stages=NST<nks?NST:nks;

    // ================= PRODUCER WARPGROUP (wg==0) =================
    if(wg==0){
        // prologue: fill the first `stages` ring slots.
        if(lt==0){
            for(int st=0;st<stages;++st){
                float* base=sm+(size_t)st*SWBUF; float* Asw=base; float* Bsw=base+ASW;
                mbar_expect_tx(&full[st], bytesA+bytesB);
                tma_load_2d(Asw,&tmapA,st*TKSW,bm,&full[st]);
                #pragma unroll
                for(int c=0;c<NATOM;++c)
                    tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,st*TKSW,&full[st]);
            }
        }
        // steady state: wait for consumers to drain slot, refill it.
        uint32_t eph=0;
        for(int ki=stages;ki<nks;++ki){
            int st=ki%NST;
            mbar_wait(&empty[st], eph); if(st==NST-1) eph^=1;
            if(lt==0){
                float* base=sm+(size_t)st*SWBUF; float* Asw=base; float* Bsw=base+ASW;
                mbar_expect_tx(&full[st], bytesA+bytesB);
                tma_load_2d(Asw,&tmapA,ki*TKSW,bm,&full[st]);
                #pragma unroll
                for(int c=0;c<NATOM;++c)
                    tma_load_2d(Bsw+(size_t)c*(TKSW*TKSW),&tmapB,bn+c*TKSW,ki*TKSW,&full[st]);
            }
        }
        return;   // producer done
    }

    // ================= CONSUMER WARPGROUPS (wg==1,2) =================
    // band = cons (0 -> M rows 0..63 of the CTA tile, 1 -> 64..127).
    int band=cons;
    float d0[32],d1[32],d2[32],d3[32];
    #pragma unroll
    for(int i=0;i<32;++i){d0[i]=0.f;d1[i]=0.f;d2[i]=0.f;d3[i]=0.f;}
    // GMMA sub-tile scratch: each consumer band owns its OWN A-band sub; both share B-block subs.
    float* As0=gmma; float* As1=As0+SUB;           // A band0 / band1 (one K8 sub each)
    float* Bb[4]; Bb[0]=As1+SUB; Bb[1]=Bb[0]+SUB; Bb[2]=Bb[1]+SUB; Bb[3]=Bb[2]+SUB;
    uint32_t fph=0;

    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        float* base=sm+(size_t)st*SWBUF;
        float* Asw=base; float* Bsw=base+ASW;
        uint32_t aAb,b0,b1,b2,b3;

        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        // (b) per-K8-sub decode: decode sub `s`, wgmma it, reuse scratch for next sub.
        #pragma unroll
        for(int s=0;s<TKSW/TK;++s){                 // 4 K8 sub-tiles
            int kbase=s*TK;
            // -- decode this band's A sub (only my 64 M-rows) + all 4 B-block subs --
            // A: my band's 64 rows, K in [kbase,kbase+8). 64*8=512 elems / 128 thr = 4 each.
            float* Adst=(band==0)?As0:As1;
            for(int i=lt;i<64*TK;i+=128){
                int mm=i/TK, kk=i%TK;               // mm 0..63 within band, kk 0..7
                int m=band*64+mm, k=kbase+kk;        // global within-tile (m 0..127, k 0..31)
                int a=m>>3, r=m&7;
                int sw = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
                Adst[gmma_phys(mm,kk)]=Asw[sw];
            }
            // B: 4 N-blocks * 64 N * 8 K = 2048 elems / 128 thr = 16 each. Decode all (shared
            // by both consumer WGs; each WG redoes it into the shared scratch — idempotent, the
            // __syncwarp below + per-WG fence make the write visible to this WG's wgmma).
            for(int i=lt;i<NBLK*64*TK;i+=128){
                int t=i; int kk=t%TK; t/=TK; int n64=t%64; int blk=t/64;  // blk 0..3
                int n=blk*64+n64, k=kbase+kk;        // n 0..255, k 0..31
                int c=n>>5, nn=n&31, gp=(nn>>2)^(k&7);
                int sw = c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
                Bb[blk][gmma_phys(n64,kk)]=Bsw[sw];
            }
            asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
            // both consumer WGs must see a consistent decode; named barrier across 256 consumers.
            asm volatile("bar.sync 1, 256;\n":::"memory");
            float* As=(band==0)?As0:As1;
            aAb=(uint32_t)__cvta_generic_to_shared(As);
            b0=(uint32_t)__cvta_generic_to_shared(Bb[0]);
            b1=(uint32_t)__cvta_generic_to_shared(Bb[1]);
            b2=(uint32_t)__cvta_generic_to_shared(Bb[2]);
            b3=(uint32_t)__cvta_generic_to_shared(Bb[3]);
            uint64_t dA=mk(aAb,128,256);
            WG(d0,dA,mk(b0,128,256));
            WG(d1,dA,mk(b1,128,256));
            WG(d2,dA,mk(b2,128,256));
            WG(d3,dA,mk(b3,128,256));
            asm volatile("wgmma.commit_group.sync.aligned;\nwgmma.wait_group.sync.aligned 0;\n":::"memory");
            // sub-tile scratch reused next iteration; barrier so no consumer overwrites a sub
            // another consumer still reads.
            asm volatile("bar.sync 1, 256;\n":::"memory");
        }
        // release this ring slot back to the producer.
        if(lt==0){
            uint32_t e=(uint32_t)__cvta_generic_to_shared(&empty[st]);
            asm volatile("mbarrier.arrive.shared::cta.b64 _, [%0];\n"::"r"(e));
        }
    }
    // ---- epilogue: 4 N-blocks of 64 per band ----
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    float* dd[4]={d0,d1,d2,d3};
    #pragma unroll
    for(int blk=0;blk<4;++blk){
        float* D=dd[blk]; int nbase=bn+blk*64;
        #pragma unroll
        for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
            int idx=c*4+r*2+p,row=rbase+rb+r*8;
            int col=nbase+cb+p+c*8;
            if(row<M&&col<N)gD[row*N+col]=D[idx];
        }
    }
}

// ======================================================================
// W12 main: cuBLAS gate+perf harness for MODE 9. argv: S MODE [NST].
// Single-tile bit-exact (the W10 GATE) is run via the W10 binary in w12_run.sh BEFORE this
// is built; the full-GEMM rel_rms gate runs here BEFORE any perf number (g5).
// ======================================================================
static int run_w12(int S,int MODE,int NST,Enc_t enc){
    int Mx=S,Nx=S,Kx=S;
    if(Nx%256||Kx%32){printf("MODE%d needs N%%256==0 && K%%32==0\n",MODE);return 1;}
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
      if(r!=CUDA_SUCCESS){printf("MODE%d encodeA r=%d\n",MODE,(int)r);return 4;} }
    { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
      cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
      CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
        CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
        CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
      if(r!=CUDA_SUCCESS){printf("MODE%d encodeB r=%d\n",MODE,(int)r);return 4;} }
    const int TM=128,TN=256,TKSW=32;
    size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
    size_t GMMA=(size_t)(2*64*8 + (TN/64)*64*8);   // sub-tile scratch: 2 A-bands + 4 B-blocks, 512 each
    size_t smsz=(size_t)NST*SWBUF*4 + GMMA*4 + (size_t)2*NST*8;
    dim3 grid(Nx/TN,(Mx+TM-1)/TM); int blk=384;     // 3 warpgroups (1 producer + 2 consumers)
    void* kern=(void*)gemm_w12;
    CK(cudaFuncSetAttribute((const void*)gemm_w12,
        cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
    { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)kern,blk,smsz);
      printf("OCCUPANCY MODE=%d blk=%d dynsmem=%zuB(%.1fKB) -> %d CTA/SM (%d thr/SM)\n",
             MODE,blk,smsz,smsz/1024.0,occ,occ*blk); }
    CK(cudaMemset(dD,0,szD*4));
    gemm_w12<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("MODE%d OWN-FAULT %s\n",MODE,cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
    double rr=sqrt(se/fmax(1e-30,sr));
    if(rr>3e-3){printf("W12 S=%d MODE=%d NST=%d rel_rms=%.3e FAIL — no perf (g5)\n",S,MODE,NST,rr);return 2;}
    cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));int it=20;
    gemm_w12<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST);CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));for(int i=0;i<it;++i)gemm_w12<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST);
    CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
    float mo;CK(cudaEventElapsedTime(&mo,s0,s1));mo/=it;
    double fl=2.0*(double)Mx*Nx*Kx,tfo=fl/(mo*1e-3)/1e12;
    cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,Nx,dA,Kx,&be,dR,Nx);CK(cudaDeviceSynchronize());
    CK(cudaEventRecord(s0));for(int i=0;i<it;++i)cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dB,Nx,dA,Kx,&be,dR,Nx);
    CK(cudaEventRecord(s1));CK(cudaEventSynchronize(s1));
    float mc;CK(cudaEventElapsedTime(&mc,s0,s1));mc/=it;
    double tfc=fl/(mc*1e-3)/1e12,ratio=tfc/tfo;
    printf("W12 S=%d MODE=%d NST=%d tile=128x256 own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
           S,MODE,NST,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
    return 0;
}

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):4096; int MODE=argc>2?atoi(argv[2]):9;
    int NST=argc>3?atoi(argv[3]):2;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}
    if(MODE==9) return run_w12(S,MODE,NST,enc);
    printf("W12 unknown MODE %d (use 9 = warp-spec + sub-decode 128x256)\n",MODE); return 1;
}
