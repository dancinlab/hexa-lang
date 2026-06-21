// owngemm_sm120_bf16_r3native.cu — fleet-lab bf16-r3 ROOT-CAUSE PROBE.
//
// The r3 fp32-input kernel regressed (3.3x off cuBLAS vs baseline 2.0x). Hypothesis:
// the regression is caused by the fp32->bf16 CONVERT-staging being incompatible with
// cp.async (lever #4 dead), NOT by the 128x128 tile / ldmatrix / swizzle themselves.
//
// This probe takes BF16-NATIVE global inputs (the WingEdge recipe's actual assumption,
// and exactly cuBLAS's input form), so cp.async can stream bf16 straight into swizzled
// smem with NO conversion. SAME 128x128x32 tile, ldmatrix.x4 frag loads, 128B XOR
// swizzle, 2-stage cp.async. If THIS reaches ~parity, the fp32 r3 regression is proven
// to be the convert-staging (root-cause A), and the recipe IS valid for bf16-native I/O.
//
// Determinism gate unchanged (fixed K-major mma.sync accum order).

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

#define BM 128
#define BN 128
#define BK 32
#define WARPS_M 2
#define WARPS_N 4
#define NWARP (WARPS_M*WARPS_N)
#define NTHREAD (NWARP*32)
#define WM_FRAG (BM/WARPS_M/16)
#define WN_FRAG (BN/WARPS_N/8)
#define NSTAGE 2

__device__ __forceinline__ void mma_m16n8k16(float* d, const unsigned* a, const unsigned* b){
    asm volatile(
      "mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 "
      "{%0,%1,%2,%3}, {%4,%5,%6,%7}, {%8,%9}, {%0,%1,%2,%3};\n"
      : "+f"(d[0]),"+f"(d[1]),"+f"(d[2]),"+f"(d[3])
      : "r"(a[0]),"r"(a[1]),"r"(a[2]),"r"(a[3]),"r"(b[0]),"r"(b[1]));
}
__device__ __forceinline__ unsigned smem_u(const void* p){ return (unsigned)__cvta_generic_to_shared(p); }
__device__ __forceinline__ void ldm_x4(unsigned* r, unsigned addr){
    asm volatile("ldmatrix.sync.aligned.m8n8.x4.shared.b16 {%0,%1,%2,%3},[%4];\n"
                 : "=r"(r[0]),"=r"(r[1]),"=r"(r[2]),"=r"(r[3]) : "r"(addr));
}
__device__ __forceinline__ void cp_async_cg16(unsigned s, const void* g){
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s),"l"(g));
}
__device__ __forceinline__ void cp_commit(){ asm volatile("cp.async.commit_group;\n"); }
template<int N> __device__ __forceinline__ void cp_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

// 8-bf16 (16B) granular swizzle: XOR the 16B-group col bit with row bits, staying in
// the BK=32-wide row. swz(row,col)=col ^ ((row&3)<<3), col in bf16 elems 0..31.
__device__ __forceinline__ int swz(int row, int col){ return col ^ ((row & 3) << 3); }

// BF16-native inputs. A:[M,K] B:[K,N] row-major bf16. C:[M,N] fp32.
// B staged TRANSPOSED (Bs[n][k]) for the .col operand. cp.async copies 8 bf16 (16B).
extern "C" __global__ void __launch_bounds__(NTHREAD,2)
gemm_sm120_bf16_r3n(const __nv_bfloat16* __restrict__ A, const __nv_bfloat16* __restrict__ B,
                    float* __restrict__ C, int M, int N, int K){
    __shared__ __nv_bfloat16 As[NSTAGE][BM*BK];
    __shared__ __nv_bfloat16 Bs[NSTAGE][BN*BK];
    int bm = blockIdx.y*BM, bn = blockIdx.x*BN;
    int tid = threadIdx.x;
    int warp = tid>>5, lane = tid&31;
    int wm = (warp/WARPS_N)*(BM/WARPS_M);
    int wn = (warp%WARPS_N)*(BN/WARPS_N);
    float acc[WM_FRAG][WN_FRAG][4];
    #pragma unroll
    for(int i=0;i<WM_FRAG;i++)for(int j=0;j<WN_FRAG;j++)for(int e=0;e<4;e++) acc[i][j][e]=0.f;
    int nk = (K+BK-1)/BK;

    // A: 128x32 bf16 = 4096 elems / 8-per-cp.async = 512 copies / 256 thr = 2 each.
    // For A, k is contiguous in global => 8 consecutive k land in one swizzle 16B-group
    // (col 8-aligned) => cp.async directly into As[r][swz(r,c..c+7)] (contiguous).
    auto stageA = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BM*BK/8; i+=NTHREAD){
            int r=i/(BK/8), c8=i%(BK/8), c=c8*8; int gr=bm+r, gc=k0+c;
            unsigned s = smem_u(&As[buf][r*BK + swz(r,c)]);
            if(gr<M && gc+7<K) cp_async_cg16(s, &A[(long long)gr*K+gc]);
            else { __nv_bfloat16 tmp[8];
                   for(int e=0;e<8;e++) tmp[e]=(gr<M&&gc+e<K)?A[(long long)gr*K+gc+e]:(__nv_bfloat16)0;
                   #pragma unroll
                   for(int e=0;e<8;e++) As[buf][r*BK+swz(r,c+e)]=tmp[e]; }
        }
    };
    // B transposed: Bs[n][k]. Global B[k][n] => n strided. cp.async needs 8 contiguous
    // bf16 from global; along n they ARE contiguous (B[gr][bn+n..n+7]) but must scatter
    // to 8 different Bs rows => cannot cp.async a contiguous 16B into 8 rows. So B uses
    // a scalar/scatter convert-free store (still bf16, no dtype convert). To still get
    // cp.async benefit on B we instead store NON-transposed Bs[k][n] and ldmatrix.trans.
    // Here: stage Bs[k][n] (k-major), cp.async 8 contiguous n.
    // B staged TRANSPOSED Bs[n][k] (BK-wide rows) to match the CORRECT non-trans
    // ldmatrix path proven in the fp32 r3 kernel. Global B[k][n] is n-strided along the
    // transpose so this is a scatter store (no cp.async, but no dtype convert either).
    auto stageB = [&](int buf,int k0){
        #pragma unroll
        for(int i=tid; i<BN*BK; i+=NTHREAD){
            int n=i/BK, c=i%BK; int gr=k0+c, gc=bn+n;     // Bs[n][c] = B[k0+c][bn+n]
            __nv_bfloat16 vv = (gr<K && gc<N) ? B[(long long)gr*N+gc] : (__nv_bfloat16)0;
            Bs[buf][n*BK + swz(n,c)] = vv;
        }
    };

    stageA(0,0); stageB(0,0); cp_commit(); cp_wait<0>(); __syncthreads();
    for(int kt=0; kt<nk; kt++){
        int buf=kt&1, nbuf=(kt+1)&1;
        if(kt+1<nk){ stageA(nbuf,(kt+1)*BK); stageB(nbuf,(kt+1)*BK); cp_commit(); }
        #pragma unroll
        for(int ks=0; ks<BK/16; ks++){
            int kc = ks*16;
            unsigned af[WM_FRAG][4];
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++){
                int mrow = wm + fmi*16;
                int row = mrow + (lane & 15);
                int col = kc + ((lane>>4)*8);
                ldm_x4(af[fmi], smem_u(&As[buf][row*BK + swz(row,col)]));
            }
            // B: Bs[k][n] (k-major, BN-wide). The .col operand wants K x N col-major.
            // ldmatrix.x4.trans on a 16(k) x 16(n) tile gives the 8x8-block transposed
            // fragment = the col operand. addr = &Bs[kc + (lane&15? )]. Use the standard
            // row=k, col=n base: row = kc + (lane&15) ... but Bs row is k (16 rows), col n.
            unsigned bf[WN_FRAG][4];
            #pragma unroll
            for(int fni=0; fni<WN_FRAG/2; fni++){
                int ncol = wn + fni*16;                  // n base (Bs is n-major)
                int row = ncol + (lane & 15);            // n index
                int col = kc + ((lane>>4)*8);
                unsigned addr = smem_u(&Bs[buf][row*BK + swz(row,col)]);
                unsigned tmp[4];
                ldm_x4(tmp, addr);
                bf[fni*2+0][0]=tmp[0]; bf[fni*2+0][1]=tmp[2];
                bf[fni*2+1][0]=tmp[1]; bf[fni*2+1][1]=tmp[3];
            }
            #pragma unroll
            for(int fmi=0; fmi<WM_FRAG; fmi++)
                #pragma unroll
                for(int fni=0; fni<WN_FRAG; fni++)
                    mma_m16n8k16(acc[fmi][fni], af[fmi], bf[fni]);
        }
        if(kt+1<nk){ cp_wait<0>(); }
        __syncthreads();
    }
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

extern "C" void owngemm_sm120_bf16_r3n(float* C, const __nv_bfloat16* A, const __nv_bfloat16* B, int M, int K, int N){
    dim3 blk(NTHREAD); dim3 grid((N+BN-1)/BN, (M+BM-1)/BM);
    gemm_sm120_bf16_r3n<<<grid,blk>>>(A,B,C,M,N,K);
}

#ifdef OWNGEMM_MAIN
static void fill(float* x, long long n, unsigned seed){
    for(long long i=0;i<n;i++){ unsigned h=(unsigned)(i*2654435761u)^seed; x[i]=((h&0xffff)/65535.f-0.5f)*0.2f; }
}
static void ref_fp64(const float* A,const float* B,double* R,int M,int N,int K){
    for(int i=0;i<M;i++) for(int j=0;j<N;j++){
        double s=0; for(int k=0;k<K;k++) s+=(double)A[(long long)i*K+k]*(double)B[(long long)k*N+j];
        R[(long long)i*N+j]=s; }
}
int main(int argc,char**argv){
    int S = argc>1?atoi(argv[1]):768; int MODE = argc>2?atoi(argv[2]):0;
    int M=S,N=S,K=S; size_t szA=(size_t)M*K, szB=(size_t)K*N, szC=(size_t)M*N;
    float *hA=(float*)malloc(szA*4),*hB=(float*)malloc(szB*4),*hC=(float*)malloc(szC*4),*hC2=(float*)malloc(szC*4);
    fill(hA,szA,11); fill(hB,szB,22);
    __nv_bfloat16 *hAb=(__nv_bfloat16*)malloc(szA*2),*hBb=(__nv_bfloat16*)malloc(szB*2);
    for(size_t i=0;i<szA;i++) hAb[i]=__float2bfloat16_rn(hA[i]);
    for(size_t i=0;i<szB;i++) hBb[i]=__float2bfloat16_rn(hB[i]);
    __nv_bfloat16 *dAb,*dBb; float *dC;
    CK(cudaMalloc(&dAb,szA*2)); CK(cudaMalloc(&dBb,szB*2)); CK(cudaMalloc(&dC,szC*4));
    CK(cudaMemcpy(dAb,hAb,szA*2,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dBb,hBb,szB*2,cudaMemcpyHostToDevice));
    owngemm_sm120_bf16_r3n(dC,dAb,dBb,M,K,N);
    cudaError_t e=cudaGetLastError(); if(e==cudaSuccess)e=cudaDeviceSynchronize();
    if(e!=cudaSuccess){ printf("R3N FAULT: %s\n",cudaGetErrorString(e)); return 4; }
    CK(cudaMemcpy(hC,dC,szC*4,cudaMemcpyDeviceToHost));
    double relrms=0.0;
    if(MODE!=1){
        double *hR=(double*)malloc(szC*8); ref_fp64(hA,hB,hR,M,N,K);
        double se=0,sr=0,maxd=0;
        for(size_t i=0;i<szC;i++){ double a=hC[i],b=hR[i],dd=a-b; se+=dd*dd; sr+=b*b; if(fabs(dd)>maxd)maxd=fabs(dd); }
        relrms = sr>0?sqrt(se/szC)/sqrt(sr/szC):0.0;
        printf("[GATE] S=%d r3native vs FP64: rel-RMS=%.3e max|delta|=%.3e (gate<=1e-2: %s)\n",
               S,relrms,maxd, relrms<=1e-2?"PASS":"FAIL");
    }
    if(MODE==2){
        CK(cudaMemset(dC,0,szC*4)); owngemm_sm120_bf16_r3n(dC,dAb,dBb,M,K,N); CK(cudaDeviceSynchronize());
        CK(cudaMemcpy(hC2,dC,szC*4,cudaMemcpyDeviceToHost));
        double md=0; size_t nb=0;
        for(size_t i=0;i<szC;i++){ double dd=fabs((double)hC[i]-(double)hC2[i]); if(dd>md)md=dd;
            unsigned u1,u2; memcpy(&u1,&hC[i],4); memcpy(&u2,&hC2[i],4); if(u1!=u2)nb++; }
        printf("[DET] S=%d run-to-run max|delta|=%.3e bitdiff=%zu/%zu (%s)\n",S,md,nb,szC,(md==0&&nb==0)?"HELD":"BROKEN");
    }
    if(MODE==1){
        float *dCb; CK(cudaMalloc(&dCb,szC*4));
        cublasHandle_t cb; CB(cublasCreate(&cb)); const float al=1.f,be=0.f; int it=50;
        owngemm_sm120_bf16_r3n(dC,dAb,dBb,M,K,N); CK(cudaDeviceSynchronize());
        cudaEvent_t t0,t1; cudaEventCreate(&t0); cudaEventCreate(&t1);
        cudaEventRecord(t0); for(int i=0;i<it;i++) owngemm_sm120_bf16_r3n(dC,dAb,dBb,M,K,N);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        float ms=0; cudaEventElapsedTime(&ms,t0,t1); double ms1=ms/it;
        double fl=2.0*(double)M*N*K, tf=fl/(ms1*1e-3)/1e12;
        CB(cublasGemmEx(cb,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dBb,CUDA_R_16BF,N,dAb,CUDA_R_16BF,K,&be,dCb,CUDA_R_32F,N,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP));
        CK(cudaDeviceSynchronize());
        cudaEventRecord(t0); for(int i=0;i<it;i++)
          cublasGemmEx(cb,CUBLAS_OP_N,CUBLAS_OP_N,N,M,K,&al,dBb,CUDA_R_16BF,N,dAb,CUDA_R_16BF,K,&be,dCb,CUDA_R_32F,N,CUBLAS_COMPUTE_32F,CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cudaEventRecord(t1); CK(cudaEventSynchronize(t1));
        cudaEventElapsedTime(&ms,t0,t1); double cbms=ms/it, cbtf=fl/(cbms*1e-3)/1e12;
        printf("[PERF] S=%d r3native %.2f TFLOP/s (%.4f ms)  cuBLAS-BF16 %.2f TFLOP/s  off=%.2fx ratio=%.3fx\n",
               S,tf,ms1,cbtf,cbtf/tf,tf/cbtf);
    }
    return relrms<=1e-2?0:2;
}
#endif
