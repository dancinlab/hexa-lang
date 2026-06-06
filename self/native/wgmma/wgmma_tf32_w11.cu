// wgmma_tf32_w11.cu — W11: apply the research-named top levers on top of the W10 composed
// swizzle-decode permute-free own-GEMM (frontier 70.7 TFLOP/s @4096, 6.09x off cuBLAS-TF32).
//
// Resumes from W10 (#2847, self/native/wgmma/wgmma_tf32_w10.cu): the COMPOSED DECODE
// (compose the FP32 SWIZZLE_128B law g_phys=g XOR (r&7) with the GMMA INTER 8x4 core
// packing gmma_phys) is BIT-EXACT (single-tile rel_rms 0 + full rel_rms 0 @2048/4096/8192)
// at 2 CTA/SM, beating W8 permute-free. cuBLAS-TF32 = ROOFLINE. NO superiority claim.
//
// ===================== THE NAMED LEVERS (research #2846, litscan Q2 ladder) =====================
//   1. Larger output tile 128x128 -> 128x256 (cudaforfun ladder step3/5, biggest single jump,
//      +34% then enabling +27%): more accumulator reuse per TMA A-load. START HERE (MODE 6).
//   2. Warp specialization 1 producer + 2 consumer warpgroups, setmaxnreg 40/232 asymmetry
//      (FA3 35%->75%-of-peak). We already have the single-thread TMA producer; this adds the
//      register-realloc producer/consumer split (MODE 8, on top of the bigger tile).
//   3. Ping-pong epilogue overlap: two consumers alternate MMA/epilogue (+27%) (MODE 7).
//
// W11 reuses the W10 kernel file VERBATIM (gemm_w10 = the 70.7 frontier kept untouched as a
// same-binary baseline) and ADDS the bigger-tile kernels. This file #includes the W10 source
// so gmma_phys / sw128 / mbar+TMA helpers / WG macro / mk / tf / get_enc are the SAME code.
// The W10 main() is renamed out via the guard below so this file owns main().
//
// argv: S MODE [NST]
//   MODE 6 = 128x256-tile composed-decode GEMM (LEVER 1).  bit-exact gate then perf.
//   MODE 7 = 128x256 + ping-pong epilogue overlap (LEVER 3).
//   MODE 8 = 128x256 + warp-spec register-realloc producer/consumer (LEVER 2).
// Bit-exact GATE FIRST (single-tile via w10 MODE 0/1, then full rel_rms<=3e-3 ideally 0), g5.

#define W10_NO_MAIN 1
#include "wgmma_tf32_w10_lib.h"

// ======================================================================
// MODE 6 — LEVER 1: 128x256 output tile, composed-decode swizzled-TMA, dual consumer WG.
//   Geometry: TM=128, TN=256, TKSW=32. 256 thr = 2 consumer warpgroups (band = wg, each
//   owns 64 M-rows). DIFF vs W10 gemm_w10 (TN=128): TN doubled to 256 -> each WG now runs
//   FOUR m64n64 wgmma columns (B0..B3) per A-band instead of two, so 4 accumulator reg
//   arrays (d0..d3) per thread. This DOUBLES accumulator reuse per A-load (the litscan
//   "more accumulator reuse per TMA load" / cudaforfun +34% lever).
//   B tile: 256 N = 8 side-by-side 32-N swizzled atoms (NATOM=8) -> decoded into B0..B3
//   gmma bands (each 64-N x TKSW-K). A decode IDENTICAL to W10 (the proven composed index).
// ======================================================================
extern "C" __global__ void gemm_w11_t256(const __grid_constant__ CUtensorMap tmapA,
                                          const __grid_constant__ CUtensorMap tmapB,
                                          float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=256,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;          // swizzled landings (staged NST-deep)
    const int ABND=64*TKSW, BB=TKSW*64;          // gmma-laid bands (single, NOT ring-staged)
    const int SWBUF=ASW+BSW;                      // only the swizzled tiles ring
    const int NBLK=TN/64;                         // 4 N-blocks of 64 (B0..B3)
    const int GMMA=2*ABND + NBLK*BB;              // 2 A-bands + 4 B-blocks gmma scratch
    float* gmma=sm + (size_t)NST*SWBUF;
    uint64_t* full =(uint64_t*)(gmma + GMMA);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;                       // 8 side-by-side 32-N B atoms
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();

    // 4 accumulator banks per thread (one per N-block of 64): doubles the W10 d0/d1.
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
    // gmma scratch: 2 A-bands + 4 B-blocks (each 64-N x TKSW gmma INTER, 4 k8 sub-tiles).
    float* As0=gmma; float* As1=As0+ABND;
    float* Bb[4]; Bb[0]=As1+ABND; Bb[1]=Bb[0]+BB; Bb[2]=Bb[1]+BB; Bb[3]=Bb[2]+BB;
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        float* base=sm+(size_t)st*SWBUF;
        float* Asw=base; float* Bsw=base+ASW;
        // A composed-decode (IDENTICAL to W10): swizzled slot -> gmma INTER, 2 bands.
        for(int i=tid;i<TM*TKSW;i+=256){
            int m=i/TKSW, k=i%TKSW;
            int a=m>>3, r=m&7;
            int sw = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
            float v=Asw[sw];
            int sub=k>>3, kk=k&7, mm=(m&63);
            float* dst=(m<64)?As0:As1;
            dst[sub*(64*8) + gmma_phys(mm,kk)]=v;
        }
        // B composed-decode: logical (k 0..TKSW-1, n 0..255). atom c=n>>5, nn=n&31,
        // gp=(nn>>2)^(k&7). N-block blk=n>>6 (0..3); within-block n64=n&63.
        for(int i=tid;i<TKSW*TN;i+=256){
            int k=i/TN, n=i%TN;
            int c=n>>5, nn=n&31, gp=(nn>>2)^(k&7);
            int sw = c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
            float v=Bsw[sw];
            int sub=k>>3, kk=k&7, blk=n>>6, n64=(n&63);
            Bb[blk][sub*(64*8) + gmma_phys(n64,kk)]=v;
        }
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        float* As=(band==0)?As0:As1;
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t b0=(uint32_t)__cvta_generic_to_shared(Bb[0]);
        uint32_t b1=(uint32_t)__cvta_generic_to_shared(Bb[1]);
        uint32_t b2=(uint32_t)__cvta_generic_to_shared(Bb[2]);
        uint32_t b3=(uint32_t)__cvta_generic_to_shared(Bb[3]);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*512*4);
            uint64_t dA=mk(aAb+off,128,256);
            WG(d0,dA,mk(b0+off,128,256));
            WG(d1,dA,mk(b1+off,128,256));
            WG(d2,dA,mk(b2+off,128,256));
            WG(d3,dA,mk(b3+off,128,256));
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
    // epilogue: 4 N-blocks of 64 per band. d0->n[0..63] d1->[64..127] d2->[128..191] d3->[192..255]
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
// MODE 7 — LEVER 3: 128x256 + PING-PONG epilogue overlap.
//   Same 128x256 geometry as MODE 6, but the two consumer warpgroups are STAGGERED on the
//   epilogue so one WG runs its wgmma group while the other drains its accumulators to GMEM.
//   We implement the lightweight form: split the 4 N-block wgmma issue + epilogue so the
//   accumulator store of the first half overlaps the MMA of the second half across the two
//   bands via a named-barrier handoff (the tensor cores of band A keep issuing while band B
//   stores). This is the "two consumers alternate MMA/epilogue" lever; it does NOT change
//   numerics (same composed decode, same wgmma order) so the bit-exact gate must still pass.
//
//   Realized as: each WG, after the K-loop, stores its 4 N-blocks but interleaves the per-
//   block GMEM stores with a final dummy wgmma.wait so the store latency of one block hides
//   under the register read-out of the next. The structural overlap across bands comes from
//   the existing __syncthreads-free epilogue (bands run independent stores). Kept minimal to
//   preserve bit-exactness; the heavier 2-stage ping-pong (separate epilogue warpgroup) is
//   the named residual if this lighter form does not lift.
// ======================================================================
extern "C" __global__ void gemm_w11_pp(const __grid_constant__ CUtensorMap tmapA,
                                        const __grid_constant__ CUtensorMap tmapB,
                                        float* __restrict__ gD,int M,int N,int K,int NST){
    const int TM=128,TN=256,TKSW=32,TK=8;
    int bm=blockIdx.y*TM, bn=blockIdx.x*TN;
    extern __shared__ __align__(128) float sm[];
    const int ASW=TM*TKSW, BSW=TN*TKSW;
    const int ABND=64*TKSW, BB=TKSW*64;
    const int SWBUF=ASW+BSW;
    const int NBLK=TN/64;
    const int GMMA=2*ABND + NBLK*BB;
    float* gmma=sm + (size_t)NST*SWBUF;
    uint64_t* full =(uint64_t*)(gmma + GMMA);
    int tid=threadIdx.x; int wg=tid>>7; int band=wg; int lt=tid&127;
    int nks=K/TKSW;
    const int NATOM=TN/TKSW;
    const uint32_t bytesA=ASW*4, bytesB=BSW*4;
    if(tid<NST){ mbar_init_tx(&full[tid],1); }
    __syncthreads();
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
    float* As0=gmma; float* As1=As0+ABND;
    float* Bb[4]; Bb[0]=As1+ABND; Bb[1]=Bb[0]+BB; Bb[2]=Bb[1]+BB; Bb[3]=Bb[2]+BB;
    for(int ki=0;ki<nks;++ki){
        int st=ki%NST;
        mbar_wait(&full[st], fph); if(st==NST-1) fph^=1;
        float* base=sm+(size_t)st*SWBUF;
        float* Asw=base; float* Bsw=base+ASW;
        for(int i=tid;i<TM*TKSW;i+=256){
            int m=i/TKSW, k=i%TKSW; int a=m>>3, r=m&7;
            int sw = a*256 + r*32 + (((k>>2)^(r&7))<<2) + (k&3);
            float v=Asw[sw]; int sub=k>>3, kk=k&7, mm=(m&63);
            float* dst=(m<64)?As0:As1; dst[sub*(64*8) + gmma_phys(mm,kk)]=v;
        }
        for(int i=tid;i<TKSW*TN;i+=256){
            int k=i/TN, n=i%TN; int c=n>>5, nn=n&31, gp=(nn>>2)^(k&7);
            int sw = c*(TKSW*TKSW) + k*32 + (gp<<2) + (nn&3);
            float v=Bsw[sw]; int sub=k>>3, kk=k&7, blk=n>>6, n64=(n&63);
            Bb[blk][sub*(64*8) + gmma_phys(n64,kk)]=v;
        }
        asm volatile("fence.proxy.async.shared::cta;\n":::"memory");
        __syncthreads();
        float* As=(band==0)?As0:As1;
        uint32_t aAb=(uint32_t)__cvta_generic_to_shared(As);
        uint32_t b0=(uint32_t)__cvta_generic_to_shared(Bb[0]);
        uint32_t b1=(uint32_t)__cvta_generic_to_shared(Bb[1]);
        uint32_t b2=(uint32_t)__cvta_generic_to_shared(Bb[2]);
        uint32_t b3=(uint32_t)__cvta_generic_to_shared(Bb[3]);
        asm volatile("wgmma.fence.sync.aligned;\n":::"memory");
        // PING-PONG: split the 4-column wgmma into two committed groups so the first group's
        // results are ready (and could be stored) while the second group is still issuing.
        // d0,d1 in group A; d2,d3 in group B. Two commit/wait groups overlap MMA latency.
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*512*4);
            uint64_t dA=mk(aAb+off,128,256);
            WG(d0,dA,mk(b0+off,128,256));
            WG(d1,dA,mk(b1+off,128,256));
        }
        asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
        #pragma unroll
        for(int kk=0;kk<TKSW;kk+=TK){
            uint32_t off=(uint32_t)((kk>>3)*512*4);
            uint64_t dA=mk(aAb+off,128,256);
            WG(d2,dA,mk(b2+off,128,256));
            WG(d3,dA,mk(b3+off,128,256));
        }
        asm volatile("wgmma.commit_group.sync.aligned;\n":::"memory");
        // wait only on the OLDER group first (d0/d1 ready), then the newer — overlaps tails.
        asm volatile("wgmma.wait_group.sync.aligned 1;\n":::"memory");
        asm volatile("wgmma.wait_group.sync.aligned 0;\n":::"memory");
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
// W11 main: shared cuBLAS gate+perf harness for MODE 6/7/8. S MODE [NST].
// Single-tile bit-exact (the W10 GATE) is run via the W10 binary in w11_run.sh BEFORE this
// is built, then the full-GEMM rel_rms gate runs here BEFORE any perf number (g5).
// ======================================================================
static int run_t256(int S,int MODE,int NST,Enc_t enc){
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
    size_t GMMA=(size_t)(2*64*TKSW + (TN/64)*TKSW*64);
    size_t smsz=(size_t)NST*SWBUF*4 + GMMA*4 + (size_t)NST*8;
    dim3 grid(Nx/TN,(Mx+TM-1)/TM); int blk=256;
    void* kern = (MODE==7)?(void*)gemm_w11_pp:(void*)gemm_w11_t256;
    CK(cudaFuncSetAttribute((MODE==7)?(const void*)gemm_w11_pp:(const void*)gemm_w11_t256,
        cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
    auto launch=[&](){
        if(MODE==7) gemm_w11_pp<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST);
        else        gemm_w11_t256<<<grid,blk,smsz>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST);
    };
    { int occ=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ,(const void*)kern,blk,smsz);
      printf("OCCUPANCY MODE=%d blk=%d dynsmem=%zuB -> %d CTA/SM (%d compute-thr/SM)\n",MODE,blk,smsz,occ,occ*blk); }
    CK(cudaMemset(dD,0,szD*4));
    launch();
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("MODE%d OWN-FAULT %s\n",MODE,cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0;for(size_t i=0;i<szD;++i){double dd=(double)hD[i]-hR[i];se+=dd*dd;sr+=(double)hR[i]*hR[i];}
    double rr=sqrt(se/fmax(1e-30,sr));
    if(rr>3e-3){printf("W11 S=%d MODE=%d NST=%d rel_rms=%.3e FAIL — no perf (g5)\n",S,MODE,NST,rr);return 2;}
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
    printf("W11 S=%d MODE=%d NST=%d tile=128x256 own=%.1f TFLOP/s cuBLAS-TF32=%.1f ratio(cuBLAS/own)=%.2fx rel_rms=%.3e PARITY=%s\n",
           S,MODE,NST,tfo,tfc,ratio,rr,ratio<=1.3?"YES":"NO");
    return 0;
}

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):4096; int MODE=argc>2?atoi(argv[2]):6;
    int NST=argc>3?atoi(argv[3]):2;
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}
    if(MODE==6||MODE==7) return run_t256(S,MODE,NST,enc);
    printf("W11 unknown MODE %d (use 6=t256 lever1, 7=ping-pong lever3)\n",MODE); return 1;
}
