// owngemm_sm120_streamk.cu — TF32 own-GEMM HYBRID Stream-K for sm_120 (RTX 5070).
//
// WALL-A closer (r2 design). The census (CloudRift sm_120 + Stream-K PPoPP'23,
// arXiv 2301.03598) reframed the own-TF32 ~0.87x-cuBLAS gap at 512-3072 as a
// PARTIAL-LAST-WAVE scheduling gap on the ~50-SM GB205: data-parallel tiling
// (one block per BMxBN output tile) wastes a whole wave's latency when the
// last wave is thin. Stream-K balances that by K-splitting work across a fixed
// persistent grid.
//
// r1 FINDING (measured, captured): a NAIVE full-K-split Stream-K with a dense
// BMxBN-per-block workspace + an O(ntiles*gridBlocks) fixup scan REGRESSED 3-16x
// at every grid size (the fixup memory traffic dwarfs the GEMM). See the lane
// report. r2 fixes BOTH:
//   (1) HYBRID: only the tiles that would form the thin partial last wave are
//       K-split (CUTLASS `sk_tiles`); the bulk run pure DATA-PARALLEL straight to
//       C (zero overhead, bit-identical to owngemm_sm120.cu). This is exactly the
//       CUTLASS hybrid (examples/74_blackwell_gemm_streamk): data-parallel for
//       full waves, Stream-K only for the remainder.
//   (2) TILE-LOCAL fixup: partials are indexed by (sk_tile_slot, k-segment) so the
//       fixup for a tile reads only ITS few segments — O(segments) not O(grid).
//
// DETERMINISM (byte-eq): NO atomics. Each Stream-K segment writes its partial to a
// pre-assigned (tile_slot, segment) workspace slot; the fixup sums a tile's
// segments in PINNED ascending k-segment order. Same input => same order =>
// bit-for-bit identical run-to-run. For a data-parallel tile the result is bit-
// identical to owngemm_sm120.cu (same f2tf32 + m16n8k8 + k-ascending order); for a
// split tile the segment partials sum in k-ascending order == the same value.
//
// Opt-in: production selects via env HEXA_TF32_STREAMK; default stays the data-
// parallel kernel. Shipped default paths untouched => byteeq-NEUTRAL.
//
// GEMM: C[M,N]=A[M,K]@B[K,N], row-major, TF32 matmul / FP32 accum.
// Modes (argv[2]): 0 GATE · 1 PERF · 2 DETERMINISM (run-to-run max|delta|, MUST 0).
// argv[3] (optional): sk_blocks override (persistent grid used for the Stream-K
//   remainder; 0 = auto = SM count).
//
// Build: build_owngemm_streamk.sh (run on aiden).

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

#define BM 64
#define BN 64
#define BK 16
#define WARPS_M 2
#define WARPS_N 2
#define NWARP (WARPS_M*WARPS_N)   // 4
#define NTHREAD (NWARP*32)        // 128
#define WM_FRAG 2
#define WN_FRAG 4
#define ASPAD 4
#define BSPAD 4

__device__ __forceinline__ unsigned f2tf32(float x){
    unsigned u; memcpy(&u,&x,4); u=(u+0x1000u)&0xFFFFE000u; return u;
}
__device__ __forceinline__ void mma_m16n8k8(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k8.row.col.f32.tf32.tf32.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}
__device__ __forceinline__ void cp_async_cg16(void* smem, const void* gmem){
    unsigned s = (unsigned)__cvta_generic_to_shared(smem);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// device GEMM-MAC over k-chunk range [kc0,kc1) for output tile (tm,tn); identical
// fragment math to owngemm_sm120 (same f2tf32 + m16n8k8 + k-ascending order).
__device__ __forceinline__ void mac_krange(
    const float* __restrict__ A, const float* __restrict__ B,
    int M, int N, int K, int tm, int tn, int kc0, int kc1,
    float acc[WM_FRAG][WN_FRAG][4]){
    __shared__ float As[2][BM][BK+ASPAD];
    __shared__ float Bs[2][BK][BN+BSPAD];
    int bm = tm*BM, bn = tn*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*32, wn = (warp%WARPS_N)*32;
    int gid = lane>>2, tig = lane&3;

    auto load_stage = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/4; i+=NTHREAD){
            int r=i/(BK/4), c4=i%(BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            if(gr<M && gc+3<K) cp_async_cg16(&As[buf][r][c], &A[(long long)gr*K+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<M){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
                   As[buf][r][c+0]=v.x;As[buf][r][c+1]=v.y;As[buf][r][c+2]=v.z;As[buf][r][c+3]=v.w; }
        }
        #pragma unroll
        for(int i=tid; i<BK*BN/4; i+=NTHREAD){
            int r=i/(BN/4), c4=i%(BN/4), c=c4*4; int gr=k0+r, gc=bn+c;
            if(gr<K && gc+3<N) cp_async_cg16(&Bs[buf][r][c], &B[(long long)gr*N+gc]);
            else { float4 v=make_float4(0,0,0,0);
                   if(gr<K){ for(int e=0;e<4;e++) ((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
                   Bs[buf][r][c+0]=v.x;Bs[buf][r][c+1]=v.y;Bs[buf][r][c+2]=v.z;Bs[buf][r][c+3]=v.w; }
        }
    };

    int nchunk = kc1-kc0;
    load_stage(0, kc0*BK); cp_async_commit();
    for(int kk=0; kk<nchunk; kk++){
        int buf=kk&1, nbuf=(kk+1)&1;
        if(kk+1<nchunk){ load_stage(nbuf,(kc0+kk+1)*BK); cp_async_commit(); cp_async_wait<1>(); }
        else           { cp_async_wait<0>(); }
        __syncthreads();
        #pragma unroll
        for(int ks=0; ks<BK; ks+=8){
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                int mrow = wm + fmi*16;
                unsigned af[4];
                af[0]=f2tf32(As[buf][mrow + gid    ][ks + tig    ]);
                af[1]=f2tf32(As[buf][mrow + gid + 8][ks + tig    ]);
                af[2]=f2tf32(As[buf][mrow + gid    ][ks + tig + 4]);
                af[3]=f2tf32(As[buf][mrow + gid + 8][ks + tig + 4]);
                #pragma unroll
                for(int fni=0; fni<WN_FRAG; fni++){
                    int ncol = wn + fni*8;
                    unsigned bf[2];
                    bf[0]=f2tf32(Bs[buf][ks + tig    ][ncol + gid]);
                    bf[1]=f2tf32(Bs[buf][ks + tig + 4][ncol + gid]);
                    mma_m16n8k8(acc[fmi][fni], af, bf);
                }
            }
        }
        __syncthreads();
    }
}

__device__ __forceinline__ void store_acc_to_C(
    float* __restrict__ C, int M, int N, int tm, int tn,
    float acc[WM_FRAG][WN_FRAG][4]){
    int bm=tm*BM, bn=tn*BN;
    int lane=threadIdx.x&31, warp=threadIdx.x>>5;
    int wm=(warp/WARPS_N)*32, wn=(warp%WARPS_N)*32;
    int gid=lane>>2, tig=lane&3;
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = bm + wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = bn + wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            if(r0<M && c0<N) C[(long long)r0*N+c0]=d[0];
            if(r0<M && c1<N) C[(long long)r0*N+c1]=d[1];
            if(r1<M && c0<N) C[(long long)r1*N+c0]=d[2];
            if(r1<M && c1<N) C[(long long)r1*N+c1]=d[3];
        }
    }
}

// write a register acc tile to a dense workspace slot (segment partial).
__device__ __forceinline__ void store_acc_to_ws(
    float* __restrict__ ws, long long base,
    float acc[WM_FRAG][WN_FRAG][4]){
    int lane=threadIdx.x&31, warp=threadIdx.x>>5;
    int wm=(warp/WARPS_N)*32, wn=(warp%WARPS_N)*32;
    int gid=lane>>2, tig=lane&3;
    #pragma unroll
    for(int fmi=0; fmi<WM_FRAG; fmi++){
        int mrow = wm + fmi*16;
        #pragma unroll
        for(int fni=0; fni<WN_FRAG; fni++){
            int ncol = wn + fni*8;
            float* d = acc[fmi][fni];
            int r0=mrow+gid, r1=mrow+gid+8, c0=ncol+2*tig, c1=ncol+2*tig+1;
            ws[base + (long long)r0*BN + c0]=d[0];
            ws[base + (long long)r0*BN + c1]=d[1];
            ws[base + (long long)r1*BN + c0]=d[2];
            ws[base + (long long)r1*BN + c1]=d[3];
        }
    }
}

// ---------------------------------------------------------------------------
// HYBRID Stream-K plan (host-computed, passed to kernels).
//   nDPtiles : tiles 0..nDPtiles-1 are pure DATA-PARALLEL (full waves) -> one
//              block each, straight to C, zero overhead.
//   The remaining (ntiles - nDPtiles) "remainder" tiles (the thin partial wave)
//              are STREAM-K: each split into `kseg` k-segments, distributed over
//              `skBlocks` persistent blocks. A segment partial is written to
//              ws[(skTileSlot*kseg + segIdx)*BM*BN]; the fixup sums a tile's
//              `kseg` segments in ascending segIdx (== ascending k) order.
//   We pick nDPtiles = floor(ntiles / waveTiles) * waveTiles where waveTiles =
//   SMs*blocksPerSM (the data-parallel wave width). The remainder = ntiles mod
//   waveTiles tiles form the partial wave.
// ---------------------------------------------------------------------------

// Data-parallel pass: one block per DP tile, straight to C (== baseline kernel).
extern "C" __global__ void gemm_sm120_dp(
    const float* __restrict__ A, const float* __restrict__ B, float* __restrict__ C,
    int M, int N, int K, int tilesN, int nk){
    int tileId = blockIdx.x;
    int tm = tileId / tilesN, tn = tileId % tilesN;
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    mac_krange(A,B,M,N,K,tm,tn,0,nk,acc);
    store_acc_to_C(C,M,N,tm,tn,acc);
}

// PERSISTENT data-parallel pass (path "P"): a FIXED grid of `pBlocks` persistent
// blocks grid-strides over ALL `ntiles` tiles, each computing one tile full-K to
// C. This removes the partial-last-wave latency WITHOUT any workspace/fixup/2nd
// launch: with pBlocks == one wave width, the scheduler hands the next tile to
// whichever block finishes first, so the tail is balanced. Bit-identical to the
// data-parallel baseline (each tile still full-K by one block, same order) =>
// byte-eq. This is the zero-overhead form of the Stream-K scheduling idea.
extern "C" __global__ void gemm_sm120_persist(
    const float* __restrict__ A, const float* __restrict__ B, float* __restrict__ C,
    int M, int N, int K, int tilesN, int nk, int ntiles){
    for(int tileId=blockIdx.x; tileId<ntiles; tileId+=gridDim.x){
        int tm = tileId / tilesN, tn = tileId % tilesN;
        float acc[WM_FRAG][WN_FRAG][4];
        #pragma unroll
        for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
        mac_krange(A,B,M,N,K,tm,tn,0,nk,acc);
        store_acc_to_C(C,M,N,tm,tn,acc);
    }
}

// Stream-K remainder pass: persistent grid of skBlocks blocks sweeps the flat
// segment space [0, nRem*kseg). segment s = (remIdx, segIdx); remIdx in
// [0,nRem) maps to global tile (firstRemTile+remIdx); segIdx in [0,kseg) maps to
// k-chunk range [segIdx*segLen, min((segIdx+1)*segLen, nk)). Writes its partial
// to ws[(remIdx*kseg+segIdx)*BM*BN].
extern "C" __global__ void gemm_sm120_sk(
    const float* __restrict__ A, const float* __restrict__ B,
    int M, int N, int K, int tilesN, int nk,
    int firstRemTile, int nRem, int kseg, int segLen, int skBlocks,
    float* __restrict__ ws){
    int b = blockIdx.x;
    long long nseg = (long long)nRem*kseg;
    long long s0 = (long long)b*nseg/skBlocks;
    long long s1 = (long long)(b+1)*nseg/skBlocks;
    for(long long s=s0; s<s1; s++){
        int remIdx = (int)(s / kseg);
        int segIdx = (int)(s % kseg);
        int kc0 = segIdx*segLen;
        int kc1 = kc0+segLen; if(kc1>nk) kc1=nk;
        if(kc0>=kc1) continue;
        int tileId = firstRemTile + remIdx;
        int tm = tileId / tilesN, tn = tileId % tilesN;
        float acc[WM_FRAG][WN_FRAG][4];
        #pragma unroll
        for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
        mac_krange(A,B,M,N,K,tm,tn,kc0,kc1,acc);
        long long base = ((long long)remIdx*kseg + segIdx)*BM*BN;
        store_acc_to_ws(ws, base, acc);
    }
}

// Fixup: one block per remainder tile. Sums its `kseg` segment partials in
// ascending segIdx (== ascending k) order -> final C. Pinned order => byte-eq.
extern "C" __global__ void gemm_sm120_sk_fixup(
    float* __restrict__ C, int M, int N, int tilesN, int nk,
    int firstRemTile, int kseg, int segLen,
    const float* __restrict__ ws){
    int remIdx = blockIdx.x;
    int tileId = firstRemTile + remIdx;
    int tm = tileId / tilesN, tn = tileId % tilesN;
    int bm = tm*BM, bn = tn*BN;
    // number of LIVE segments for this tile (some trailing segIdx may be empty if
    // kseg*segLen > nk; we still wrote only live ones, dead ones never written).
    for(int idx=threadIdx.x; idx<BM*BN; idx+=blockDim.x){
        int lr = idx / BN, lc = idx % BN;
        int gr = bm+lr, gc = bn+lc;
        if(gr>=M || gc>=N) continue;
        float sum = 0.f;
        for(int segIdx=0; segIdx<kseg; segIdx++){
            int kc0 = segIdx*segLen; if(kc0>=nk) break;     // no more live segments
            long long base = ((long long)remIdx*kseg + segIdx)*BM*BN;
            sum += ws[base + (long long)lr*BN + lc];
        }
        C[(long long)gr*N+gc] = sum;
    }
}

// host plan + launch.
struct SKPlan { int waveTiles, nDPtiles, firstRemTile, nRem, kseg, segLen, skBlocks; };

static SKPlan plan_streamk(int M,int N,int K,int skBlocksOverride){
    int dev=0; cudaDeviceProp p; cudaGetDeviceProperties(&p,dev);
    int tilesM=(M+BM-1)/BM, tilesN=(N+BN-1)/BN, ntiles=tilesM*tilesN, nk=(K+BK-1)/BK;
    int bpsm=0; cudaOccupancyMaxActiveBlocksPerMultiprocessor(&bpsm,(const void*)gemm_sm120_dp,NTHREAD,0);
    if(bpsm<1) bpsm=1;
    int waveTiles = p.multiProcessorCount * bpsm;   // data-parallel wave width
    SKPlan q;
    q.waveTiles = waveTiles;
    int fullWaves = ntiles / waveTiles;
    q.nDPtiles = fullWaves * waveTiles;
    q.firstRemTile = q.nDPtiles;
    q.nRem = ntiles - q.nDPtiles;                    // partial-wave tiles
    q.skBlocks = skBlocksOverride>0?skBlocksOverride:p.multiProcessorCount;
    if(q.nRem>0){
        // split each remainder tile's nk chunks so skBlocks stay busy: aim for
        // ~ skBlocks segments total across the nRem tiles -> kseg ~ skBlocks/nRem,
        // clamped to [1, nk]. Choose segLen = ceil(nk/kseg).
        int kseg = (q.skBlocks + q.nRem - 1) / q.nRem;   // ceil(skBlocks/nRem)
        if(kseg<1) kseg=1; if(kseg>nk) kseg=nk;
        q.kseg = kseg;
        q.segLen = (nk + kseg - 1)/kseg;
        // recompute effective kseg from segLen (so last segment is non-empty)
        q.kseg = (nk + q.segLen - 1)/q.segLen;
    } else { q.kseg=0; q.segLen=0; }
    return q;
}

extern "C" void owngemm_sm120_streamk(float* C, const float* A, const float* B,
                                      int M, int K, int N, const SKPlan* q, float* ws){
    int tilesM=(M+BM-1)/BM, tilesN=(N+BN-1)/BN, nk=(K+BK-1)/BK;
    dim3 blk(NTHREAD);
    if(q->nDPtiles>0)
        gemm_sm120_dp<<<q->nDPtiles,blk>>>(A,B,C,M,N,K,tilesN,nk);
    if(q->nRem>0){
        gemm_sm120_sk<<<q->skBlocks,blk>>>(A,B,M,N,K,tilesN,nk,
            q->firstRemTile,q->nRem,q->kseg,q->segLen,q->skBlocks,ws);
        gemm_sm120_sk_fixup<<<q->nRem,256>>>(C,M,N,tilesN,nk,
            q->firstRemTile,q->kseg,q->segLen,ws);
    }
}

// path "P": single persistent-grid data-parallel launch (no fixup, byte-eq).
extern "C" void owngemm_sm120_persist(float* C, const float* A, const float* B,
                                      int M, int K, int N, int pBlocks){
    int tilesM=(M+BM-1)/BM, tilesN=(N+BN-1)/BN, ntiles=tilesM*tilesN, nk=(K+BK-1)/BK;
    dim3 blk(NTHREAD);
    gemm_sm120_persist<<<pBlocks,blk>>>(A,B,C,M,N,K,tilesN,nk,ntiles);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;
    int skOverride = argc>3?atoi(argv[3]):0;
    int M=S,N=S,K=S;
    int tilesM=(M+BM-1)/BM, tilesN=(N+BN-1)/BN, ntiles=tilesM*tilesN;
    SKPlan q = plan_streamk(M,N,K,skOverride);
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),
          *hC2=(float*)malloc(szC*4),*hR=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dC,*dR,*dWs=nullptr;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4)); CK(cudaMalloc(&dR,szC*4));
    size_t wsSlots = (size_t)q.nRem*q.kseg;
    if(wsSlots>0) CK(cudaMalloc(&dWs, wsSlots*BM*BN*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    cublasHandle_t cb; CB(cublasCreate(&cb));
    CB(cublasSetMathMode(cb, CUBLAS_TF32_TENSOR_OP_MATH));
    const float alpha=1.f, beta=0.f;
    CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
        dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
        dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    CK(cudaDeviceSynchronize());

    owngemm_sm120_streamk(dC,dA,dB,M,K,N,&q,dWs);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("STREAMK FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    CK(cudaMemcpy(hR,dR,szC*4,cudaMemcpyDeviceToHost));
    double se=0,sr=0,maxd=0;
    for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
    double relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
    printf("[GATE] S=%d wave=%d nDP=%d nRem=%d kseg=%d skB=%d streamk-TF32 vs cuBLAS: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
           S,q.waveTiles,q.nDPtiles,q.nRem,q.kseg,q.skBlocks,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");

    if(MODE==2){
        owngemm_sm120_streamk(dC,dA,dB,M,K,N,&q,dWs); CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hC2,dC,szC*4,cudaMemcpyDeviceToHost));
        double md=0; size_t nbit=0;
        for(size_t i=0;i<szC;i++){ double dd=fabs((double)hC[i]-(double)hC2[i]); if(dd>md)md=dd;
            unsigned u1,u2; memcpy(&u1,&hC[i],4); memcpy(&u2,&hC2[i],4); if(u1!=u2)nbit++; }
        printf("[DET] S=%d run-to-run max|delta|=%.3e bitdiff=%zu/%zu (determinism: %s)\n",
               S,md,nbit,szC, (md==0.0&&nbit==0)?"HELD":"BROKEN");
    }

    if(MODE==3){
        // path P: persistent grid-stride DP. pBlocks from argv[3] (0=auto wave).
        int pBlocks = skOverride>0?skOverride:q.waveTiles;
        CK(cudaMemset(dC,0,szC*4));
        owngemm_sm120_persist(dC,dA,dB,M,K,N,pBlocks);
        cudaError_t pe=cudaGetLastError(); if(pe==cudaSuccess)pe=cudaDeviceSynchronize();
        if(pe!=cudaSuccess){ printf("PERSIST FAULT: %s\n",cudaGetErrorString(pe)); return 4; }
        CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
        double pse=0,psr=0,pmx=0;
        for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; pse+=dd*dd; psr+=b*b; if(fabs(dd)>pmx)pmx=fabs(dd); }
        double prr = psr>0?sqrt(pse/szC)/sqrt(psr/szC):0.0;
        // determinism
        owngemm_sm120_persist(dC,dA,dB,M,K,N,pBlocks); CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hC2,dC,szC*4,cudaMemcpyDeviceToHost));
        size_t nbit=0; for(size_t i=0;i<szC;i++){ unsigned u1,u2; memcpy(&u1,&hC[i],4); memcpy(&u2,&hC2[i],4); if(u1!=u2)nbit++; }
        int iters=50;
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_persist(dC,dA,dB,M,K,N,pBlocks);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
            dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERSIST] S=%d pBlocks=%d ntiles=%d rel-RMS=%.3e max|d|=%.3e bitdiff=%zu persist-TF32 %.2f TFLOP/s  cuBLAS %.2f TFLOP/s  off-cuBLAS=%.2fx (det:%s)\n",
               S,pBlocks,ntiles,prr,pmx,nbit,tflops,cbtf,cbtf/tflops, nbit==0?"HELD":"BROKEN");
    }

    if(MODE==1){
        int iters=50;
        owngemm_sm120_streamk(dC,dA,dB,M,K,N,&q,dWs); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_streamk(dC,dA,dB,M,K,N,&q,dWs);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dB, CUDA_R_32F, N, dA, CUDA_R_32F, K, &beta,
            dR, CUDA_R_32F, N, CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] S=%d nDP=%d nRem=%d kseg=%d streamk-TF32 %.2f TFLOP/s (%.4f ms)  cuBLAS-TF32 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx\n",
               S,q.nDPtiles,q.nRem,q.kseg,tflops,ms1,cbtf,cbms, cbtf/tflops);
    }
    return relrms<=1e-2?0:2;
}
#endif
