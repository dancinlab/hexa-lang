// wgmma_tf32_ffepi.cu — HEXA-FUSION FF-EPILOGUE.
// Fold the FF block (bias-add + GELU + residual-add) INTO the own-GEMM (W10, sm_90a,
// TF32, bit-exact SUMMIT, OG10 70.7 TFLOP/s) EPILOGUE — applied to the accumulator
// registers d0/d1 BEFORE the global store, killing N post-GEMM launches + the
// global round-trips of the intermediate activation tensors.
//
// FF block computed:   out = gelu( C + bias[col] ) + residual[row,col]
//   C = A@B (the own-GEMM result, in d0/d1 accumulator regs).
//   gelu = exact erf-based GELU: 0.5*x*(1+erf(x/sqrt2))  — device erf() = IEEE libm,
//          SAME formula as hexa nn_gelu / forge_dispatch_gelu (clm-devfeed path).
//
// GATE (g5): byte-eq the FUSED output vs the SEPARATE-OP reference (gemm_w10 store to
//   global, then 3 separate kernels: bias_add, gelu, residual_add) — the epilogue
//   computes the SAME values, just before the store, so max|Δ| must be 0 (both paths
//   share identical float op-order: (C+bias) -> gelu -> +residual, all fp32).
//
// Reports: byte-eq max|Δ| + rel-RMS (fused vs separate), fused-vs-separate WALL,
//   launch-count delta (4 -> 1), HBM round-trip delta, occupancy of each kernel.
//
// Build: nvcc -O3 -arch=sm_90a -o ffepi wgmma_tf32_ffepi.cu -lcuda -lcublas -lcudart
// Run:   ./ffepi S            (S = square M=N=K, default 2048; needs N%128==0 K%32==0)
#define W10_NO_MAIN 1
#include "wgmma_tf32_w10_lib.h"

// device-side exact GELU, erf form (matches hexa nn_gelu / forge_dispatch_gelu).
__device__ __forceinline__ float gelu_exact(float x){
    return 0.5f*x*(1.0f+erff(x*0.70710678118654752440f));
}

// ===================================================================
// FUSED kernel: gemm_w10 body VERBATIM, epilogue folds bias+GELU+residual.
//   gBias[N] (broadcast over rows), gRes[M*N] (residual, elementwise).
//   Single launch, single store of the FINAL FF output. No intermediate
//   activation tensor written to / read from global (the C, the C+bias, and
//   the gelu(C+bias) all live in registers).
// ===================================================================
extern "C" __global__ void gemm_w10_ffepi(const __grid_constant__ CUtensorMap tmapA,
                                     const __grid_constant__ CUtensorMap tmapB,
                                     float* __restrict__ gD,
                                     const float* __restrict__ gBias,
                                     const float* __restrict__ gRes,
                                     int M,int N,int K,int NST){
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
    // ---- FUSED EPILOGUE: bias-add + GELU + residual-add on accumulator regs ----
    int rbase=bm+band*64;
    int w=lt>>5,l=lt&31,rb=w*16+(l>>2),cb=(l&3)*2;
    #pragma unroll
    for(int c=0;c<8;++c)for(int r=0;r<2;++r)for(int p=0;p<2;++p){
        int idx=c*4+r*2+p,row=rbase+rb+r*8;
        int col0=bn+cb+p+c*8, col1=bn+64+cb+p+c*8;
        if(row<M&&col0<N){
            float v=gelu_exact(d0[idx]+gBias[col0])+gRes[row*N+col0];
            gD[row*N+col0]=v;
        }
        if(row<M&&col1<N){
            float v=gelu_exact(d1[idx]+gBias[col1])+gRes[row*N+col1];
            gD[row*N+col1]=v;
        }
    }
}

// ===================================================================
// SEPARATE-OP reference kernels (the un-fused baseline = 3 extra launches +
// the activation round-trips). bias_add reads gC writes gC; gelu reads gC
// writes gC; residual_add reads gC+gRes writes gC. Each is a full HBM pass
// over the M*N output tensor (read + write).
// ===================================================================
extern "C" __global__ void k_bias_add(float* __restrict__ gC,const float* __restrict__ gBias,int M,int N){
    long i=(long)blockIdx.x*blockDim.x+threadIdx.x; if(i>=(long)M*N) return;
    gC[i]=gC[i]+gBias[i%N];
}
extern "C" __global__ void k_gelu(float* __restrict__ gC,int M,int N){
    long i=(long)blockIdx.x*blockDim.x+threadIdx.x; if(i>=(long)M*N) return;
    gC[i]=gelu_exact(gC[i]);
}
extern "C" __global__ void k_residual_add(float* __restrict__ gC,const float* __restrict__ gRes,int M,int N){
    long i=(long)blockIdx.x*blockDim.x+threadIdx.x; if(i>=(long)M*N) return;
    gC[i]=gC[i]+gRes[i];
}

// ===================================================================
// MAIN — byte-eq (fused vs separate) gate, then fused-vs-separate wall.
// ===================================================================
static int cmpd(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}

int main(int argc,char**argv){
    int S=argc>1?atoi(argv[1]):2048;
    int Mx=S,Nx=S,Kx=S;
    if(Nx%128||Kx%32){printf("FFEPI needs N%%128==0 && K%%32==0\n");return 1;}
    Enc_t enc=get_enc();
    if(!enc){printf("cuTensorMapEncodeTiled unavailable (CUDA<12?)\n");return 4;}

    size_t szA=(size_t)Mx*Kx,szB=(size_t)Kx*Nx,szD=(size_t)Mx*Nx;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4);
    float *hBias=(float*)malloc((size_t)Nx*4),*hRes=(float*)malloc(szD*4);
    float *hFus=(float*)malloc(szD*4),*hSep=(float*)malloc(szD*4);
    srand(7);
    for(size_t i=0;i<szA;++i)hA[i]=tf(((rand()%17)-8)*0.0625f);
    for(size_t i=0;i<szB;++i)hB[i]=tf(((rand()%17)-8)*0.0625f);
    for(int i=0;i<Nx;++i)hBias[i]=((rand()%17)-8)*0.03125f;
    for(size_t i=0;i<szD;++i)hRes[i]=((rand()%17)-8)*0.03125f;

    float *dA,*dB,*dBias,*dRes,*dC,*dFus;
    CK(cudaMalloc(&dA,szA*4));CK(cudaMalloc(&dB,szB*4));
    CK(cudaMalloc(&dBias,(size_t)Nx*4));CK(cudaMalloc(&dRes,szD*4));
    CK(cudaMalloc(&dC,szD*4));CK(cudaMalloc(&dFus,szD*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dBias,hBias,(size_t)Nx*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dRes,hRes,szD*4,cudaMemcpyHostToDevice));

    // swizzled tmaps (identical to W10 MODE4): A box{32(K),128(M)}, B box{32(N),32(K)}.
    CUtensorMap tmapA{},tmapB{};
    { cuuint64_t gd[2]={(cuuint64_t)Kx,(cuuint64_t)Mx}; cuuint64_t gs[1]={(cuuint64_t)Kx*4};
      cuuint32_t bd[2]={32,128}; cuuint32_t es[2]={1,1};
      CUresult r=enc(&tmapA,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dA,gd,gs,bd,es,
        CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
        CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
      if(r!=CUDA_SUCCESS){printf("encodeA r=%d\n",(int)r);return 4;} }
    { cuuint64_t gd[2]={(cuuint64_t)Nx,(cuuint64_t)Kx}; cuuint64_t gs[1]={(cuuint64_t)Nx*4};
      cuuint32_t bd[2]={32,32}; cuuint32_t es[2]={1,1};
      CUresult r=enc(&tmapB,CU_TENSOR_MAP_DATA_TYPE_FLOAT32,2,dB,gd,gs,bd,es,
        CU_TENSOR_MAP_INTERLEAVE_NONE,CU_TENSOR_MAP_SWIZZLE_128B,
        CU_TENSOR_MAP_L2_PROMOTION_NONE,CU_TENSOR_MAP_FLOAT_OOB_FILL_NONE);
      if(r!=CUDA_SUCCESS){printf("encodeB r=%d\n",(int)r);return 4;} }

    const int TM=128,TN=128,TKSW=32;
    size_t SWBUF=(size_t)(TM*TKSW + TN*TKSW);
    size_t GMMA=(size_t)(2*64*TKSW + 2*TKSW*64);
    int NST=3;
    size_t smsz=(size_t)NST*SWBUF*4 + GMMA*4 + (size_t)2*NST*8;
    dim3 grid(Nx/128,(Mx+TM-1)/TM); int blk=256;
    CK(cudaFuncSetAttribute(gemm_w10,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));
    CK(cudaFuncSetAttribute(gemm_w10_ffepi,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)smsz));

    int occ_g=0,occ_f=0;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ_g,(const void*)gemm_w10,blk,smsz);
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&occ_f,(const void*)gemm_w10_ffepi,blk,smsz);
    printf("OCCUPANCY  gemm_w10(separate-GEMM)=%d CTA/SM   gemm_w10_ffepi(fused)=%d CTA/SM   (dynsmem=%zuB blk=%d)\n",
           occ_g,occ_f,smsz,blk);

    int ebt=256; long tot=(long)Mx*Nx; int egrid=(int)((tot+ebt-1)/ebt);

    // ---- SEPARATE-OP path: GEMM -> bias_add -> gelu -> residual_add ----
    CK(cudaMemset(dC,0,szD*4));
    gemm_w10<<<grid,blk,smsz>>>(tmapA,tmapB,dC,Mx,Nx,Kx,NST);
    k_bias_add<<<egrid,ebt>>>(dC,dBias,Mx,Nx);
    k_gelu<<<egrid,ebt>>>(dC,Mx,Nx);
    k_residual_add<<<egrid,ebt>>>(dC,dRes,Mx,Nx);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("SEPARATE FAULT %s\n",cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hSep,dC,szD*4,cudaMemcpyDeviceToHost));

    // ---- FUSED path: single launch, FF folded in epilogue ----
    CK(cudaMemset(dFus,0,szD*4));
    gemm_w10_ffepi<<<grid,blk,smsz>>>(tmapA,tmapB,dFus,dBias,dRes,Mx,Nx,Kx,NST);
    e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){printf("FUSED FAULT %s\n",cudaGetErrorString(e));return 4;}
    CK(cudaMemcpy(hFus,dFus,szD*4,cudaMemcpyDeviceToHost));

    // ---- BYTE-EQ GATE: fused vs separate ----
    double se=0,sr=0,mx=0; long nbit=0;
    for(size_t i=0;i<szD;++i){
        double dd=(double)hFus[i]-hSep[i];
        if(fabs(dd)>mx)mx=fabs(dd);
        if(hFus[i]==hSep[i])nbit++;
        se+=dd*dd; sr+=(double)hSep[i]*hSep[i];
    }
    double rr=sqrt(se/fmax(1e-30,sr));
    int byteeq=(mx==0.0);
    printf("BYTE-EQ (fused vs separate)  S=%d  max|Δ|=%.3e  rel_rms=%.3e  bit-identical=%ld/%zu  %s\n",
           S,mx,rr,nbit,szD, byteeq?"PASS (max|Δ|=0)":"FAIL");
    if(!byteeq){printf("byte-eq FAIL — no wall measurement (g5)\n");return 2;}

    // ---- WALL: separate (4 launches) vs fused (1 launch). 20 warmup + 200 timed median ----
    cudaEvent_t s0,s1;CK(cudaEventCreate(&s0));CK(cudaEventCreate(&s1));
    int WARM=20,IT=200;
    double *sep_ms=(double*)malloc(IT*sizeof(double));
    double *fus_ms=(double*)malloc(IT*sizeof(double));
    auto sep=[&](){ gemm_w10<<<grid,blk,smsz>>>(tmapA,tmapB,dC,Mx,Nx,Kx,NST);
                    k_bias_add<<<egrid,ebt>>>(dC,dBias,Mx,Nx);
                    k_gelu<<<egrid,ebt>>>(dC,Mx,Nx);
                    k_residual_add<<<egrid,ebt>>>(dC,dRes,Mx,Nx); };
    auto fus=[&](){ gemm_w10_ffepi<<<grid,blk,smsz>>>(tmapA,tmapB,dFus,dBias,dRes,Mx,Nx,Kx,NST); };

    for(int i=0;i<WARM;++i)sep(); CK(cudaDeviceSynchronize());
    for(int i=0;i<IT;++i){ CK(cudaEventRecord(s0)); sep(); CK(cudaEventRecord(s1)); CK(cudaEventSynchronize(s1));
        float t;CK(cudaEventElapsedTime(&t,s0,s1)); sep_ms[i]=t; }
    for(int i=0;i<WARM;++i)fus(); CK(cudaDeviceSynchronize());
    for(int i=0;i<IT;++i){ CK(cudaEventRecord(s0)); fus(); CK(cudaEventRecord(s1)); CK(cudaEventSynchronize(s1));
        float t;CK(cudaEventElapsedTime(&t,s0,s1)); fus_ms[i]=t; }
    qsort(sep_ms,IT,sizeof(double),cmpd); qsort(fus_ms,IT,sizeof(double),cmpd);
    double sepM=sep_ms[IT/2], fusM=fus_ms[IT/2];

    // round-trip accounting: each separate elementwise kernel = 1 HBM read+write pass of
    // M*N fp32 (k_bias_add, k_gelu, k_residual_add). residual is read by both paths once.
    // The FUSED epilogue removes the 3 elementwise passes' C round-trips: it never stores
    // the bare GEMM C nor re-reads it for bias/gelu — only the final FF result is stored.
    // global traffic removed = 3 extra full read+write passes of the M*N output (the bias
    // pass writes+reads, the gelu pass writes+reads, the residual pass writes+reads) MINUS
    // the residual read (still needed once in the fused path). Net removed ~ 3 RW of M*N
    // (≈ 6 * M*N * 4 bytes of HBM traffic the separate path issues that fusion does not).
    double sz_mn_gb=(double)szD*4/1e9;
    double removed_gb=6.0*sz_mn_gb;  // 3 elementwise passes * (read+write) of M*N fp32
    printf("WALL  S=%d  separate(4 launches)=%.4f ms  fused(1 launch)=%.4f ms  speedup(sep/fus)=%.3fx\n",
           S,sepM,fusM,sepM/fusM);
    printf("LAUNCH-DELTA  separate=4 launches  fused=1 launch  (-3 launches, -75%%)\n");
    printf("ROUNDTRIP-DELTA  separate issues 3 extra elementwise HBM passes over M*N (%.3f GB each RW); "
           "fused removes them: ~%.3f GB HBM traffic removed/step\n", 2.0*sz_mn_gb, removed_gb);
    printf("SUMMARY  byte-eq=%s  fused %.3fx vs separate  launch 4->1  occ sep=%d fused=%d CTA/SM\n",
           byteeq?"YES":"NO", sepM/fusM, occ_g, occ_f);
    return 0;
}
