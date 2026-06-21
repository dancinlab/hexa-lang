// owngemm_sm120_bf16_r3.cu — fleet-lab bf16-r3: the WingEdge sm_120 PARITY recipe.
//
// CONTEXT: the shipped OP-3 BF16 own-GEMM (owngemm_sm120_bf16.cu) runs ~2x slower
// than cuBLAS-BF16 on the RTX 5070 (sm_120) at 512/1024/2048. Research (WingEdge,
// fa-5090) overturned the "hardware ceiling" framing: that 2x is three STACKED slow
// choices, all recoverable WITHOUT warp-spec or TMA. This file rebuilds the kernel
// with EXACTLY the WingEdge sm_120 parity config:
//
//   1. 128x128x32 block tile, warp tile 64x64 (4x4 grid of 16x8 mma fragments per
//      warp), mma m16n8k16.f32.bf16.bf16.f32 — KEEP f32-accum (mandatory + matches
//      cuBLAS; f16-accum is FALSIFIED — bf16 has no f16-accum PTX path).
//   2. ldmatrix.sync.aligned.m8n8.x4.b16 fragment loads for A & B — DELETES the
//      manual packbf16 path (the uncoalesced smem bottleneck of OP-3). B is staged
//      TRANSPOSED in smem (Bs[n][k]) so a NON-trans ldmatrix yields the m16n8k16
//      .col operand (per the round-7 / bc4 probe finding: ldmatrix .trans only does
//      an 8x8-block transpose, so the column operand is fed via a pre-transposed
//      stage + non-trans ldmatrix).
//   3. 128B XOR smem swizzle matched to the x4 reads (fa-5090 formula): for a 128B
//      bf16 row, swizzle the column index by XOR-ing bits 4..6 with row bits 0..2,
//      bank-conflict-free at the x4 granularity.
//   4. 2-stage cp.async (NOT 3-stage; 3-stage REGRESSED on sm_120 at 128x128 per
//      WingEdge: register pressure). Occupancy: 128x32x2B = 8KB/operand/stage,
//      (As+Bs)=16KB/stage x2 = 32KB << 100KB sm_120 smem => >=2 blocks/SM.
//
// GATE (g5): rel-RMS vs FP64 ref <= 1e-2 (BF16 mantissa truncation expected), AND
// run-to-run determinism max|delta| = 0 (the per-output K-major mma.sync accum order
// is fixed => the kernel is its own bit-for-bit reproducer; this is the moat).
//
// This is an OPT-IN fastmode variant; the shipped default BF16 path is untouched
// (byteeq-NEUTRAL). Build/measure on aiden via build_owngemm_bf16_r3.sh.
//
// GEMM: C[M,N] = A[M,K] @ B[K,N], all row-major, BF16 matmul / FP32 accum.
//
// ===================== MEASURED VERDICT (aiden RTX 5070 sm_120) =====================
// gate PASS (rel-RMS 2.6e-3..8.0e-3 <= 1e-2) AND determinism HELD (run-to-run
// max|delta|=0, bitdiff 0/1048576). BUT perf REGRESSED, did NOT reach parity:
//   off-cuBLAS-BF16:  512=5.7x  1024=3.4x  2048=3.3x  4096=3.7x  (r3)
//                vs   512=2.0x  1024=2.0x  2048=2.0x  4096=2.1x  (64x64 baseline)
// ROOT CAUSE (captured, c1) — the DOMINANT cause is occupancy, NOT the convert-staging:
//  (B, DOMINANT) the 128x128 tile inflates registers 72 -> 118 (64 acc x 4 f32 +
//      ldmatrix temps), collapsing occupancy from ~5 blocks/SM (64x64 baseline: 72 reg,
//      18.9KB smem) to 2 blocks/SM (64K regs / (118*256) = 2). On a CONSUMER sm_120
//      card the higher warp count of the smaller baseline tile hides latency better
//      than the bigger r3 tile. This is the wall.
//  (A, REFUTED as dominant) I first suspected the fp32->bf16 convert-staging (cp.async
//      cannot convert dtype) was the cost. PROBE owngemm_sm120_bf16_r3native.cu feeds
//      BF16-NATIVE inputs (cuBLAS's form, cp.async-able, NO convert) with the same
//      128x128 tile + ldmatrix + swizzle => still 3.0-5.0x off (512=5.0x 1024=3.5x
//      2048=2.9x), SAME 118 reg / 2 blocks/SM. Removing the convert barely moved perf
//      => the convert was not the dominant cost; OCCUPANCY is.
// The WingEdge "105% parity" claim does NOT reproduce on RTX 5070 sm_120 with this
// recipe for EITHER fp32-input or bf16-native-input own-GEMM.
//
// r4 OCCUPANCY PROBE (-DBM=64 -DBN=64 -DBK=32 -DWARPS_M=2 -DWARPS_N=2): shrinking the
// tile to 64x64 did NOT restore the baseline's 72-reg / 5-block occupancy — it still
// burned 108 registers (vs baseline 72) and ran WORSE (512=3.8x 1024=4.2x 2048=3.5x
// off). CONCLUSION: the ldmatrix.x4 + scatter-transpose-B + 128B-swizzle machinery is
// itself ~36 registers heavier than the baseline's manual packbf16 path; that register
// inflation collapses occupancy independent of tile size. The "uncoalesced manual pack"
// the recipe told us to DELETE is actually the cheaper choice on this consumer card —
// it wins through higher occupancy (more warps hiding latency). The recipe's levers are
// a net LOSS here, not a win.
//
// MEASURED VERDICT: the ~2x BF16 shortfall is NOT overturned; it is the consumer-sm_120
// floor for the own square-GEMM (baseline 2.0x is the best of the tested kernels). The
// f32-accum Math-Pipe throttle + consumer tensor throughput cap raw-square parity.
// BEYOND-PARITY lives in fusion (chained-GEMM / epilogue, cuBLAS can't fuse across call
// boundaries) and DETERMINISM (run-to-run max|delta|=0 — proven HELD here, cuBLAS does
// not offer it) — the moat — NOT in re-tiling the raw square. That is the next frontier.
// ====================================================================================

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <cstdint>
#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>

#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){printf("CUDA-ERR %s @%d: %s\n",#x,__LINE__,cudaGetErrorString(e));exit(3);}}while(0)
#define CB(x) do{cublasStatus_t s=(x); if(s!=CUBLAS_STATUS_SUCCESS){printf("CUBLAS-ERR %d @%d\n",(int)s,__LINE__);exit(3);}}while(0)

// ---- WingEdge sm_120 parity tile (override at compile for the r4 occupancy probe) ----
#ifndef BM
#define BM 128
#endif
#ifndef BN
#define BN 128
#endif
#ifndef BK
#define BK 32                 // 2 x k16 mma steps per stage
#endif
#ifndef WARPS_M
#define WARPS_M 2             // warp grid 2x4 = 8 warps = 256 threads
#endif
#ifndef WARPS_N
#define WARPS_N 4
#endif
#define NWARP (WARPS_M*WARPS_N)   // 8
#define NTHREAD (NWARP*32)        // 256
// warp tile: BM/WARPS_M x BN/WARPS_N = 64 x 32. Per warp = 4 (m16) x 4 (n8) frags.
#define WM_FRAG (BM/WARPS_M/16)   // 4
#define WN_FRAG (BN/WARPS_N/8)    // 4
#define NSTAGE 2

// fp32 -> bf16 round-to-nearest-even (hardware).
__device__ __forceinline__ unsigned short f2bf16(float x){
    __nv_bfloat16 b = __float2bfloat16_rn(x); unsigned short u; memcpy(&u,&b,2); return u;
}

// one mma.sync m16n8k16 BF16 step. A frag = 4 regs (8 bf16), B frag = 2 regs (4 bf16),
// C/D = 4 f32 acc (in/out).
__device__ __forceinline__ void mma_m16n8k16(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}

__device__ __forceinline__ unsigned smem_u(const void* p){ return (unsigned)__cvta_generic_to_shared(p); }

// ldmatrix.x4: load 4 8x8 b16 matrices (one warp), addr = per-lane row base.
__device__ __forceinline__ void ldm_x4(unsigned* r, unsigned addr){
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];\n"
                 : "=r"(r[0]),"=r"(r[1]),"=r"(r[2]),"=r"(r[3]) : "r"(addr));
}

// cp.async 16-byte shared<-global, .cg (bypass L1).
__device__ __forceinline__ void cp_async_cg16(unsigned s, const void* g){
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s),"l"(g));
}
__device__ __forceinline__ void cp_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// ---- 128B XOR smem swizzle (fa-5090) ----
// Smem operand rows are BK bf16 wide (As: 128x32 bf16 = 64B rows; Bs: 128x32 = 64B
// rows). The swizzle permutes the column (along K) by XOR-ing the row index into the
// column bits so that the x4 ldmatrix (8 consecutive rows, 8 b16 = 16B each) lands on
// distinct banks. For a 64B (=32 bf16) row the bank-period is 32/2=16 banks of pairs;
// XOR the column's bits 3..4 (the 16B/8-elem ldmatrix groups) with row bits 0..2.
// The row is BK=32 bf16 wide (5-bit column, bits 0..4). ldmatrix reads in 8-elem
// (16B) groups => swizzle granularity = the two 16B groups (col bit 3). XOR col bit 3
// with row bits 0..1 stays inside the 32-elem row (max XOR = 8) => no row bleed, and
// permutes the two 16B halves across banks per 4-row block (bank-conflict-free x4).
// swz(row,col) = col ^ ((row & 3) << 3)   [col in bf16 elems, 0..31; XOR <= 24<32]
__device__ __forceinline__ int swz(int row, int col){
    return col ^ ((row & 3) << 3);
}

// Tiled BF16 GEMM, WingEdge parity recipe. A,B,C row-major fp32 inputs. fp32 staged
// into smem AS bf16 (converted at the cp.async-fed global read into a tmp then stored;
// to keep cp.async we instead stage fp32 and convert at smem write — but that loses
// the ldmatrix-on-bf16 width. So here we stage bf16 directly: each thread reads fp32
// from global, RN-converts, writes bf16 into swizzled smem. The global read is still
// 128-bit-coalesced; cp.async is replaced by a convert-store stage for the bf16 smem
// (cp.async cannot convert). 2-stage software pipeline via double smem buffer.)
extern "C" __global__ void __launch_bounds__(NTHREAD,2)
gemm_sm120_bf16_r3(const float* __restrict__ A, const float* __restrict__ B,
                   float* __restrict__ C, int M, int N, int K){
    // bf16 smem, double-buffered. As: [stage][BM][BK], Bs transposed: [stage][BN][BK].
    __shared__ __nv_bfloat16 As[NSTAGE][BM*BK];
    __shared__ __nv_bfloat16 Bs[NSTAGE][BN*BK];

    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*(BM/WARPS_M);   // warp row offset (0 or 64)
    int wn = (warp%WARPS_N)*(BN/WARPS_N);   // warp col offset (0,32,64,96)

    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;

    int nk = (K+BK-1)/BK;

    // stage a BK panel into smem buffer `buf`. A panel: BM x BK (128x32). Each thread
    // converts/stores; 128*32=4096 elems / 256 threads = 16 each. B panel: BK x BN read
    // from global (B[k][n]) but stored TRANSPOSED as Bs[n][k] (128x32) for the .col frag.
    // float4-vectorized global read (128-bit coalesced), RN-convert 4 fp32 -> bf16,
    // store the 4-elem group contiguously into swizzled smem. The float4 lands at a
    // 4-aligned col c (c%8 in {0,4}) which stays inside one 8-elem swizzle block
    // (swz XORs only bits 3..4, bits 0..2 untouched) => +0..+3 is contiguous post-swz.
    auto stage = [&](int buf, int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/4; i+=NTHREAD){
            int r=i/(BK/4), c4=i%(BK/4), c=c4*4; int gr=bm+r, gc=k0+c;
            float4 v=make_float4(0,0,0,0);
            if(gr<M){ if(gc+3<K) v=*reinterpret_cast<const float4*>(&A[(long long)gr*K+gc]);
                      else for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<K)?A[(long long)gr*K+gc+e]:0.f; }
            int base = r*BK + swz(r,c);
            As[buf][base+0]=__float2bfloat16_rn(v.x); As[buf][base+1]=__float2bfloat16_rn(v.y);
            As[buf][base+2]=__float2bfloat16_rn(v.z); As[buf][base+3]=__float2bfloat16_rn(v.w);
        }
        // B is staged TRANSPOSED (Bs[n][k]); global B[k][n] is row-major so along n it is
        // strided => read 4 consecutive n (one float4 over B[gr][bn+n..n+3]) and scatter
        // them to 4 different Bs rows at the same k-col. Contiguous global read, scattered
        // (but bank-spread) smem write.
        #pragma unroll
        for(int i=tid; i<BN*BK/4; i+=NTHREAD){
            int c=i/(BN/4), n4=i%(BN/4), n=n4*4; int gr=k0+c, gc=bn+n;   // c in 0..BK-1, n in 0..BN-1
            float4 v=make_float4(0,0,0,0);
            if(gr<K){ if(gc+3<N) v=*reinterpret_cast<const float4*>(&B[(long long)gr*N+gc]);
                      else for(int e=0;e<4;e++)((float*)&v)[e]=(gc+e<N)?B[(long long)gr*N+gc+e]:0.f; }
            Bs[buf][(n+0)*BK + swz(n+0,c)]=__float2bfloat16_rn(v.x);
            Bs[buf][(n+1)*BK + swz(n+1,c)]=__float2bfloat16_rn(v.y);
            Bs[buf][(n+2)*BK + swz(n+2,c)]=__float2bfloat16_rn(v.z);
            Bs[buf][(n+3)*BK + swz(n+3,c)]=__float2bfloat16_rn(v.w);
        }
    };

    stage(0,0); cp_commit(); __syncthreads();

    for(int kt=0; kt<nk; kt++){
        int buf=kt&1, nbuf=(kt+1)&1;
        if(kt+1<nk){ stage(nbuf,(kt+1)*BK); }
        // consume current buf: 2 k16 sub-steps within the BK=32 panel.
        #pragma unroll
        for(int ks=0; ks<BK/16; ks++){
            int kc = ks*16;   // column base in the panel
            // --- A fragments: WM_FRAG m16 rows, ldmatrix.x4 over 16x16 b16 ---
            // ldmatrix m8n8.x4 reads a 16x16 b16 tile: lane l provides the row base of
            // 8 rows; the 4 sub-matrices tile the 16x16. addr = &As[mrow + (lane&15)][kc..]
            // with the .x4 selecting the two 8-row halves and two 8-col halves.
            unsigned af[WM_FRAG][4];
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                int mrow = wm + fmi*16;
                int row = mrow + (lane & 15);
                int col = kc + ((lane>>4)*8);        // 0 or 8
                unsigned addr = smem_u(&As[buf][row*BK + swz(row,col)]);
                ldm_x4(af[fmi], addr);
            }
            // --- B fragments: WN_FRAG n8 cols, from transposed Bs[n][k] ---
            // Bs is [BN][BK] (n-major). The .col operand wants K x N = 16 x 8 col-major.
            // A non-trans ldmatrix.x4 over a 16x16 b16 tile of Bs (rows = n, cols = k)
            // delivers 4 sub-matrices; we feed regs (b0,b2) per n8 fragment (the probe's
            // mapping). We load a 16x16 (16 n-rows x 16 k-cols) and split to two n8 frags.
            unsigned bf[WN_FRAG][4];
            #pragma unroll
            for(int fni=0; fni<WN_FRAG/2; fni++){
                int ncol = wn + fni*16;
                int row = ncol + (lane & 15);        // n index
                int col = kc + ((lane>>4)*8);
                unsigned addr = smem_u(&Bs[buf][row*BK + swz(row,col)]);
                unsigned tmp[4];
                ldm_x4(tmp, addr);
                // tmp[0],tmp[2] -> n8 frag (fni*2);  tmp[1],tmp[3] -> n8 frag (fni*2+1)
                bf[fni*2+0][0]=tmp[0]; bf[fni*2+0][1]=tmp[2];
                bf[fni*2+1][0]=tmp[1]; bf[fni*2+1][1]=tmp[3];
            }
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++)
                #pragma unroll
                for(int fni=0; fni<WN_FRAG; fni++)
                    mma_m16n8k16(acc[fmi][fni], af[fmi], bf[fni]);
        }
        __syncthreads();
    }

    // store: m16n8 C fragment fp32. c0:(gid,2*tig) c1:(gid,2*tig+1) c2:(gid+8,2*tig) c3:(gid+8,2*tig+1)
    int gid = lane>>2, tig = lane&3;
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

extern "C" void owngemm_sm120_bf16_r3(float* C, const float* A, const float* B, int M, int K, int N){
    dim3 blk(NTHREAD);
    dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    gemm_sm120_bf16_r3<<<grid,blk>>>(A,B,C,M,N,K);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
static void ref_fp64(const float* A,const float* B,double* R,int M,int N,int K){
    for(int i=0;i<M;i++) for(int j=0;j<N;j++){
        double s=0; for(int k=0;k<K;k++) s+=(double)A[(long long)i*K+k]*(double)B[(long long)k*N+j];
        R[(long long)i*N+j]=s;
    }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768;
    int MODE = argc>2?atoi(argv[2]):0;
    int M=S,N=S,K=S;
    size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hC2=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    float *dA,*dB,*dC;
    CK(cudaMalloc(&dA,szA*4)); CK(cudaMalloc(&dB,szB*4)); CK(cudaMalloc(&dC,szC*4));
    CK(cudaMemcpy(dA,hA,szA*4,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB,hB,szB*4,cudaMemcpyHostToDevice));

    owngemm_sm120_bf16_r3(dC,dA,dB,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("OWNGEMM-R3 FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));

    double relrms = 0.0;
    if(MODE!=1 && MODE!=4){   // skip the O(n^3) CPU FP64 ref for pure-perf modes
        double *hR=(double*)malloc(szC*8);
        ref_fp64(hA,hB,hR,M,N,K);
        double se=0,sr=0,maxd=0;
        for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
        relrms = sr>0 ? sqrt(se/szC)/sqrt(sr/szC) : 0.0;
        printf("[GATE] S=%d own-GEMM-BF16-r3 vs FP64 ref: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
               S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");
    }

    if(MODE==2){
        CK(cudaMemset(dC,0,szC*4));
        owngemm_sm120_bf16_r3(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hC2,dC,szC*4,cudaMemcpyDeviceToHost));
        double md=0; size_t nbit=0;
        for(size_t i=0;i<szC;i++){ double dd=fabs((double)hC[i]-(double)hC2[i]); if(dd>md)md=dd;
            unsigned u1,u2; memcpy(&u1,&hC[i],4); memcpy(&u2,&hC2[i],4); if(u1!=u2)nbit++; }
        printf("[DET] S=%d run-to-run max|delta|=%.3e bitdiff=%zu/%zu (determinism: %s)\n",
               S,md,nbit,szC, (md==0.0&&nbit==0)?"HELD":"BROKEN");
    }

    if(MODE==1){
        __nv_bfloat16 *dAb,*dBb; float *dCb;
        CK(cudaMalloc(&dAb,szA*2)); CK(cudaMalloc(&dBb,szB*2)); CK(cudaMalloc(&dCb,szC*4));
        __nv_bfloat16 *hAb=(__nv_bfloat16*)malloc(szA*2),*hBb=(__nv_bfloat16*)malloc(szB*2);
        for(size_t i=0;i<szA;i++) hAb[i]=__float2bfloat16(hA[i]);
        for(size_t i=0;i<szB;i++) hBb[i]=__float2bfloat16(hB[i]);
        CK(cudaMemcpy(dAb,hAb,szA*2,cudaMemcpyHostToDevice));
        CK(cudaMemcpy(dBb,hBb,szB*2,cudaMemcpyHostToDevice));
        cublasHandle_t cb; CB(cublasCreate(&cb));
        const float alpha=1.f, beta=0.f;
        int iters=50;
        owngemm_sm120_bf16_r3(dC,dA,dB,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++) owngemm_sm120_bf16_r3(dC,dA,dB,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/iters;
        double flops=2.0*(double)M*N*K, tflops=flops/(ms1*1e-3)/1e12;
        CB(cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dBb, CUDA_R_16BF, N, dAb, CUDA_R_16BF, K, &beta,
            dCb, CUDA_R_32F, N, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CK(cudaDeviceSynchronize());
        cudaEventRecord(t0);
        for(int it=0;it<iters;it++)
          cublasGemmEx(cb, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha,
            dBb, CUDA_R_16BF, N, dAb, CUDA_R_16BF, K, &beta,
            dCb, CUDA_R_32F, N, CUBLAS_COMPUTE_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/iters, cbtf=flops/(cbms*1e-3)/1e12;
        printf("[PERF] S=%d own-GEMM-BF16-r3 %.2f TFLOP/s (%.4f ms)  cuBLAS-BF16 %.2f TFLOP/s (%.4f ms)  off-cuBLAS=%.2fx ratio=%.3fx\n",
               S,tflops,ms1,cbtf,cbms, cbtf/tflops, tflops/cbtf);
    }
    return relrms<=1e-2?0:2;
}
#endif
