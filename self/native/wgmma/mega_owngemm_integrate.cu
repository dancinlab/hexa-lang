// mega_owngemm_integrate.cu — HEXA-FUSION MEGA-OWNGEMM-INTEGRATE
//
// GOAL: wire the OG17 TF32-PARITY wgmma own-GEMM into the persistent whole-step
// cooperative megakernel (_hx_k_clm_megafwd, self/cuda/runtime_cuda_emit.hexa),
// replacing the naive grid-stride device GEMM (_hx_dev_conv_tf32). VALUE =
// COMPLETENESS / own-ability (NOT util/perf — util-via-megakernel is a CLOSED
// NEGATIVE; byte-eq perp util-lift). cuBLAS = roofline, no superiority claim.
//
// =================== THE CO-RESIDENCE QUESTION (pre-registered g5) ===================
// The megakernel is launched via cudaLaunchCooperativeKernel and sized to ONE WAVE
// (numSM x cudaOccupancyMaxActiveBlocksPerMultiprocessor) so EVERY block is
// co-resident across grid.sync() — a HARD cooperative-launch requirement. The whole
// megakernel (every conv/GEMM/GN/gelu) runs under ONE uniform <gridDim, blockDim=64>
// geometry. The in-kernel GEMM is a __device__ fn (grid_group&), grid-stride, ONE
// thread per output cell, NO smem, NO warpgroup, NO TMA.
//
// OG17 (gemm_og16 / gemm_og17_t256 / gemm_og17_pipe) is a standalone __global__:
//   - 256 threads/block (2 warpgroups); wgmma.m64n64k8 REQUIRES a full 128-thread
//     warpgroup per MMA. blockDim=64 (the megakernel's) CANNOT issue wgmma.
//   - 64-96 KB DYNAMIC shared memory / CTA (cudaFuncAttributeMaxDynamicSharedMemorySize).
//   - __grid_constant__ CUtensorMap TMA descriptor kernel params (host-built per-GEMM,
//     cannot be re-encoded inside a running device kernel).
//   - mbarrier ring buffers; tile-mapped grid (blockIdx.y*128, blockIdx.x*TN), NOT a
//     grid-stride loop over a uniform megakernel grid.
//
// FALSIFIER (pre-registered): if OG17's per-CTA occupancy (256 thr + 64-96KB dyn smem)
// CANNOT co-reside as a single cooperative wave at the megakernel's required grid
// (one-wave coverage of the GEMM output tiles) OR the wgmma warpgroup / TMA-descriptor
// requirements are incompatible with the megakernel's __device__/grid.sync() in-line
// call model, then the OG17 parity kernel and the coop whole-step megakernel are
// MUTUALLY EXCLUSIVE on occupancy/structure -> HONEST CLOSED-NEGATIVE.
//
// This probe MEASURES the four hard incompatibilities on real sm_90a (H100):
//   PROBE A: OG17 standalone wgmma GEMM occupancy — cudaOccupancyMaxActiveBlocksPerMultiprocessor
//            for gemm_og17_pipe @ 256 thr + its dyn-smem (NST=2,3). blocks/SM and one-wave grid.
//   PROBE B: the megakernel coop one-wave constraint — for a wgmma-issuing kernel at 256 thr,
//            does (numSM x blocksPerSM) >= the GEMM tile grid the whole-step needs? i.e. can a
//            wgmma GEMM cover all output tiles in ONE coop wave (the coop residency ceiling)?
//   PROBE C: warpgroup/blockDim mismatch — the megakernel launches blockDim=64; wgmma needs 128.
//            Demonstrated as a structural fact (compile-time / launch-config), reported.
//   PROBE D: byte-eq sanity — OG17 gemm_og17_pipe rel-RMS vs cuBLAS-TF32 (the parity gate the
//            standalone already passes), confirming the kernel we WOULD wire is the parity one.
//
// argv: S [NST]  — runs all probes, prints a structured PROBE-* report + a CO-RESIDE verdict.
//
// NOTE: the OG17 device kernels (gemm_og17_pipe etc.) + helpers are #included from the
// sibling wgmma_tf32_og17.cu via -DMEGA_PROBE (which suppresses its main()).
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda.h>
#include <cudaTypedefs.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define MEGA_PROBE 1
#include "wgmma_tf32_og17.cu"   // pulls in gemm_og17_pipe, mk_desc, gmma_phys, get_enc, tf, etc.

// ---- the megakernel's launch params (from runtime_cuda_emit.hexa coop launcher) ----
static const int MEGA_BLOCK = 64;   // _hx_k_groupnorm_coop / megafwd block_sz

int main(int argc,char**argv){
    int S   = argc>1?atoi(argv[1]):2048;
    int NST = argc>2?atoi(argv[2]):3;
    int dev=0; cudaGetDevice(&dev);
    cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    int numSM=p.multiProcessorCount;
    int coop=0; cudaDeviceGetAttribute(&coop,cudaDevAttrCooperativeLaunch,dev);
    printf("=== MEGA-OWNGEMM-INTEGRATE probe ===\n");
    printf("DEVICE %s sm_%d%d numSM=%d cooperativeLaunch=%d smemPerSM=%zuKB smemOptin=%zuKB\n",
        p.name,p.major,p.minor,numSM,coop,(size_t)p.sharedMemPerMultiprocessor/1024,
        (size_t)p.sharedMemPerBlockOptin/1024);

    // ---------- PROBE A: OG17 wgmma GEMM occupancy (256 thr + dyn smem) ----------
    const int TM=128,TN=128,TKSW=32;
    size_t SWBUF=(size_t)(TM*TKSW+TN*TKSW)*4;            // 128x128 OG17 tile
    size_t dynsmem=(size_t)NST*SWBUF + (size_t)NST*sizeof(uint64_t);
    int og17_thr=256;
    cudaError_t fe=cudaFuncSetAttribute((const void*)gemm_og17_pipe,
        cudaFuncAttributeMaxDynamicSharedMemorySize,(int)dynsmem);
    printf("PROBE-A og17_pipe thr=%d NST=%d dynsmem=%zuKB setAttr=%s\n",
        og17_thr,NST,dynsmem/1024,cudaGetErrorString(fe));
    int blocksPerSM_og=0;
    cudaError_t oe=cudaOccupancyMaxActiveBlocksPerMultiprocessor(&blocksPerSM_og,
        (const void*)gemm_og17_pipe, og17_thr, dynsmem);
    printf("PROBE-A occ: blocksPerSM(og17 wgmma)=%d (%s) -> one_wave_grid=%d CTAs\n",
        blocksPerSM_og, cudaGetErrorString(oe), blocksPerSM_og*numSM);

    // ---------- PROBE B: the GEMM output-tile grid vs the coop one-wave ceiling ----------
    // The whole-step megakernel's largest conv-GEMM is [T x Cout] with the clm_prod shape.
    // For OG17 the output grid = (N/TN) x (M/TM) tiles. With S=2048: (2048/128)^2 = 256 tiles.
    int tilesM=(S+TM-1)/TM, tilesN=(S+TN-1)/TN;
    long og_tiles=(long)tilesM*tilesN;
    long coop_ceiling=(long)blocksPerSM_og*numSM;
    printf("PROBE-B GEMM output tiles @S=%d = %ldx%ld=%ld ; coop one-wave ceiling(wgmma)=%ld\n",
        S,(long)tilesM,(long)tilesN,og_tiles,coop_ceiling);
    printf("PROBE-B co-reside-all-tiles-in-one-wave = %s\n",
        (og_tiles<=coop_ceiling)?"YES":"NO (GEMM grid EXCEEDS coop wave -> needs >1 wave -> grid.sync DEADLOCK)");

    // ---------- PROBE C: warpgroup / blockDim mismatch ----------
    printf("PROBE-C megakernel blockDim=%d ; wgmma.m64n64k8 requires a 128-thread warpgroup; "
           "OG17 uses %d-thread (2 warpgroup) CTAs. blockDim=%d CANNOT issue wgmma = %s\n",
        MEGA_BLOCK, og17_thr, MEGA_BLOCK,
        (MEGA_BLOCK<128)?"STRUCTURAL MISMATCH":"ok");

    // ---------- PROBE D: OG17 byte-eq sanity (the parity kernel we WOULD wire) ----------
    // Run gemm_og17_pipe MODE6 path inline: build pre-laid operands, one cuBLAS ref, rel-RMS.
    Enc_t enc=get_enc();
    if(!enc){printf("PROBE-D SKIP: cuTensorMapEncodeTiled unavailable\n");}
    else {
        int Mx=S,Nx=S,Kx=S;
        if(Nx%128||Kx%32||Mx%128){printf("PROBE-D SKIP: S not 128/32 aligned\n");}
        else {
            size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
            float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hR=(float*)malloc(szD*4),*hD=(float*)malloc(szD*4);
            srand(7);
            for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
            for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
            float *dAo,*dBo,*dR,*dA,*dB,*dD;
            cudaMalloc(&dAo,szA*4);cudaMalloc(&dBo,szB*4);cudaMalloc(&dR,szD*4);
            cudaMalloc(&dA,szA*4);cudaMalloc(&dB,szB*4);cudaMalloc(&dD,szD*4);
            cudaMemcpy(dAo,hA,szA*4,cudaMemcpyHostToDevice);
            cudaMemcpy(dBo,hB,szB*4,cudaMemcpyHostToDevice);
            cublasHandle_t h;cublasCreate(&h);cublasSetMathMode(h,CUBLAS_TF32_TENSOR_OP_MATH);
            float al=1.f,be=0.f;
            cublasSgemm(h,CUBLAS_OP_N,CUBLAS_OP_N,Nx,Mx,Kx,&al,dBo,Nx,dAo,Kx,&be,dR,Nx);
            cudaDeviceSynchronize();
            cudaMemcpy(hR,dR,szD*4,cudaMemcpyDeviceToHost);
            float *hAp=(float*)calloc(szA,4),*hBp=(float*)calloc(szB,4);
            for(int m=0;m<Mx;++m)for(int k=0;k<Kx;++k){
                int tile=m>>7,mloc=m&127,a=mloc>>3,r=mloc&7,katom=k>>5,kk=k&31;
                int pp=a*256+gmma_phys(r,kk); int srow=tile*128+(pp>>5),scol=katom*32+(pp&31);
                hAp[(size_t)srow*Kx+scol]=hA[(size_t)m*Kx+k];
            }
            for(int k=0;k<Kx;++k)for(int n=0;n<Nx;++n){
                int tile=n>>7,nloc=n&127,c=nloc>>5,na=(nloc&31)>>3,r=nloc&7,katom=k>>5,kk=k&31;
                int pp=na*256+gmma_phys(r,kk); int gN=tile*128+c*32+(pp&31),gK=katom*32+(pp>>5);
                hBp[(size_t)gK*Nx+gN]=hB[(size_t)k*Nx+n];
            }
            cudaMemcpy(dA,hAp,szA*4,cudaMemcpyHostToDevice);
            cudaMemcpy(dB,hBp,szB*4,cudaMemcpyHostToDevice);
            CUtensorMap tmapA{},tmapB{};
            { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
              cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
              enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
                CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
                CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE); }
            { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
              cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
              enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
                CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_NONE,
                CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE); }
            dim3 grid(Nx/TN,Mx/TM),blk(256);
            gemm_og17_pipe<<<grid,blk,dynsmem>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,128,1024,0,0);
            cudaError_t le=cudaDeviceSynchronize();
            cudaMemcpy(hD,dD,szD*4,cudaMemcpyDeviceToHost);
            double se=0,sr=0;
            for(size_t i=0;i<szD;++i){double e=(double)hD[i]-hR[i]; se+=e*e; sr+=(double)hR[i]*hR[i];}
            double rel=sqrt(se/(sr>0?sr:1));
            // timed reps
            cudaEvent_t e0,e1; cudaEventCreate(&e0);cudaEventCreate(&e1);
            int reps=5; cudaEventRecord(e0);
            for(int r=0;r<reps;++r) gemm_og17_pipe<<<grid,blk,dynsmem>>>(tmapA,tmapB,dD,Mx,Nx,Kx,NST,128,1024,0,0);
            cudaEventRecord(e1); cudaEventSynchronize(e1);
            float ms=0; cudaEventElapsedTime(&ms,e0,e1); ms/=reps;
            double tflops=2.0*Mx*Nx*Kx/(ms*1e-3)/1e12;
            printf("PROBE-D og17_pipe @S=%d NST=%d launch=%s rel_rms=%.3e %s ; %.1f TFLOP/s\n",
                S,NST,cudaGetErrorString(le),rel,(rel==0.0)?"BIT-EXACT":"(nonzero)",tflops);
        }
    }
    printf("=== probe done ===\n");
    return 0;
}
