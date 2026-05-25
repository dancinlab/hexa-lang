/* R11 PROBE (B): 2-stage COMPUTE pipeline on the best-d (d=64) fused attention.
 *
 * R10/R11-probe-A diagnosed the residual floor (at d=64, the closest-to-cuBLAS
 * shape) as the intra-warp SERIAL dependency chain WITHIN each K-tile:
 *     QK^T mma  ->  row max/sum reduce  ->  exp/P  ->  P.V mma
 * cp.async (R10) overlapped only the LOAD; the COMPUTE chain is still serial.
 *
 * PROBE (B) software-pipelines the COMPUTE: compute the QK^T mma for K-tile j+1
 * (independent — needs only K[j+1], no dependence on tile j's softmax) WHILE the
 * P.V mma for tile j (dependent on tile j's reduce) is in flight. The QK^T of j+1
 * is hoisted to fill the pipeline bubble that the reduce->P.V chain of j creates.
 *
 * Structure (per warp, 16 query rows, D=64 -> DTILES=4):
 *   prologue: load K/V tile0 (cp.async); s_cur = QK^T(tile0)
 *   loop j = 0..n-1:
 *     - prefetch K/V tile j+1 (cp.async) [LOAD overlap, R10]
 *     - if j+1<n: s_nxt = QK^T(tile j+1)   <-- COMPUTE hoist (independent, fills pipe)
 *     - softmax-online-update using s_cur (reduce + exp + rescale O)
 *     - P.V(tile j) into oacc                                    [dependent]
 *     - s_cur = s_nxt
 * The QK^T(j+1) mma issues before the P.V(j) mma so the warp scheduler can
 * interleave the two independent mma streams (different fragments), hiding the
 * reduce latency that R10 found is now the floor.
 *
 * Inherits ALL R10/probe-A correctness invariants (reg-S, smem-scratch reduce,
 * acc-row-map, local P->matrix_a repack). cp.async LOAD double-buffer kept.
 *
 * Build:  nvcc -O2 -arch=sm_90a -DDVAL=64 -o fa_pipe fa_pipe_oracle.cu
 * Run:    ./fa_pipe [N] [do_time]
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
using namespace nvcuda;

#define CK(call) do{cudaError_t e=(call); if(e!=cudaSuccess){\
  fprintf(stderr,"CUDA %s @ %d\n",cudaGetErrorString(e),__LINE__);return 1;}}while(0)

#ifndef DVAL
#define DVAL 64
#endif
#define NWARP  4
#define BM     64
#define KTILE  16
#define D      DVAL
#define DTILES (D/16)
#define VECS_PER_THREAD ((KTILE*D/8)/128)

__device__ __forceinline__ void scale_o(
    wmma::fragment<wmma::accumulator,16,16,16,float>& f, float c_lo, float c_hi) {
    f.x[0]*=c_lo; f.x[1]*=c_lo; f.x[4]*=c_lo; f.x[5]*=c_lo;
    f.x[2]*=c_hi; f.x[3]*=c_hi; f.x[6]*=c_hi; f.x[7]*=c_hi;
}
__device__ __forceinline__ void cp_async_16(void* smem_ptr, const void* gmem_ptr) {
    unsigned s = (unsigned)__cvta_generic_to_shared(smem_ptr);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem_ptr));
}
__device__ __forceinline__ void cp_async_commit(){ asm volatile("cp.async.commit_group;\n" ::); }
template<int N> __device__ __forceinline__ void cp_async_wait(){ asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }
__device__ __forceinline__ void load_tile_cpasync(__half* dst, const __half* src, int tid){
    #pragma unroll
    for (int v=0; v<VECS_PER_THREAD; ++v){ int off=(v*128+tid)*8; cp_async_16(dst+off, src+off); }
}

/* compute QK^T for the K tile resident at kb -> s_frag (scaled) */
__device__ __forceinline__ void qkt(
    wmma::fragment<wmma::accumulator,16,16,16,float>& s_frag,
    const wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major>* qf,
    const __half* kb, float scale) {
    wmma::fill_fragment(s_frag, 0.0f);
    #pragma unroll
    for (int kk=0;kk<DTILES;++kk){
        wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> kf;
        wmma::load_matrix_sync(kf, kb + kk*16, D);
        wmma::mma_sync(s_frag, qf[kk], kf, s_frag);
    }
    #pragma unroll
    for (int i=0;i<s_frag.num_elements;++i) s_frag.x[i]*=scale;
}

extern "C" __global__ void fa_pipe(const __half* q, const __half* k,
                                   const __half* v, __half* o,
                                   int N, float scale) {
    __shared__ __half k_sm[3][KTILE*D];   /* triple-buffer: tiles j, j+1, j+2 live */
    __shared__ __half v_sm[3][KTILE*D];
    __shared__ float  red_max[NWARP][16*4];
    __shared__ float  red_sum[NWARP][16*4];
    __shared__ float  o_dbg [NWARP][16*16];

    int tid=threadIdx.x, wid=tid>>5, lane=tid&31;
    int qrow_base = blockIdx.x*BM + wid*16;
    const __half* qb = q + (size_t)qrow_base*D;

    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> qf[DTILES];
    #pragma unroll
    for (int kk=0;kk<DTILES;++kk) wmma::load_matrix_sync(qf[kk], qb+kk*16, D);

    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[DTILES];
    #pragma unroll
    for (int t=0;t<DTILES;++t) wmma::fill_fragment(oacc[t], 0.0f);

    float m_lo=-INFINITY,m_hi=-INFINITY,l_lo=0.f,l_hi=0.f;
    int n_tiles = N>>4;

    /* prologue: prefetch tile0 AND tile1 (2 cp.async groups in flight) into the
       triple-buffer. Wait tile0, compute s_cur = QK^T(tile0). Keeps R10's
       double-deep LOAD overlap (wait_group<1>) AND adds the COMPUTE hoist. */
    load_tile_cpasync(k_sm[0], k, tid);
    load_tile_cpasync(v_sm[0], v, tid);
    cp_async_commit();
    if (n_tiles > 1) {
        load_tile_cpasync(k_sm[1], k + (size_t)KTILE*D, tid);
        load_tile_cpasync(v_sm[1], v + (size_t)KTILE*D, tid);
        cp_async_commit();
    }
    cp_async_wait<1>();      /* tile0 ready, tile1 still outstanding (overlap) */
    __syncthreads();

    wmma::fragment<wmma::accumulator,16,16,16,float> s_cur, s_nxt;
    qkt(s_cur, qf, k_sm[0], scale);

    for (int kt=0; kt<n_tiles; ++kt) {
        int cur = kt % 3, nxt = (kt+1) % 3, nn = (kt+2) % 3;

        /* prefetch tile j+2 into its own triple-buffer slot (no race with the
           j-tile V read below; 2 cp.async groups stay in flight => LOAD overlap) */
        if (kt+2 < n_tiles) {
            const __half* kb_n = k + (size_t)((kt+2)*KTILE)*D;
            const __half* vb_n = v + (size_t)((kt+2)*KTILE)*D;
            load_tile_cpasync(k_sm[nn], kb_n, tid);
            load_tile_cpasync(v_sm[nn], vb_n, tid);
            cp_async_commit();
        }
        /* COMPUTE HOIST: QK^T(tile j+1) from the already-prefetched nxt slot.
           wait_group<1> keeps tile j+2's load outstanding (overlap preserved). */
        if (kt+1 < n_tiles) {
            cp_async_wait<1>();
            __syncthreads();
            qkt(s_nxt, qf, k_sm[nxt], scale);   /* independent — fills the pipe */
        } else {
            cp_async_wait<0>();
        }

        /* ---- online softmax update using s_cur (tile j) ---- */
        int g_lo=lane>>2, g_hi=g_lo+8, slot=lane&3;
        float pmax_lo=fmaxf(fmaxf(s_cur.x[0],s_cur.x[1]),fmaxf(s_cur.x[4],s_cur.x[5]));
        float pmax_hi=fmaxf(fmaxf(s_cur.x[2],s_cur.x[3]),fmaxf(s_cur.x[6],s_cur.x[7]));
        red_max[wid][g_lo*4+slot]=pmax_lo; red_max[wid][g_hi*4+slot]=pmax_hi;
        __syncwarp();
        float tmax_lo=fmaxf(fmaxf(red_max[wid][g_lo*4+0],red_max[wid][g_lo*4+1]),fmaxf(red_max[wid][g_lo*4+2],red_max[wid][g_lo*4+3]));
        float tmax_hi=fmaxf(fmaxf(red_max[wid][g_hi*4+0],red_max[wid][g_hi*4+1]),fmaxf(red_max[wid][g_hi*4+2],red_max[wid][g_hi*4+3]));
        __syncwarp();
        float mn_lo=fmaxf(m_lo,tmax_lo), mn_hi=fmaxf(m_hi,tmax_hi);
        float c_lo=__expf(m_lo-mn_lo), c_hi=__expf(m_hi-mn_hi);

        float p[8];
        p[0]=__expf(s_cur.x[0]-mn_lo);p[1]=__expf(s_cur.x[1]-mn_lo);
        p[4]=__expf(s_cur.x[4]-mn_lo);p[5]=__expf(s_cur.x[5]-mn_lo);
        p[2]=__expf(s_cur.x[2]-mn_hi);p[3]=__expf(s_cur.x[3]-mn_hi);
        p[6]=__expf(s_cur.x[6]-mn_hi);p[7]=__expf(s_cur.x[7]-mn_hi);

        red_sum[wid][g_lo*4+slot]=p[0]+p[1]+p[4]+p[5];
        red_sum[wid][g_hi*4+slot]=p[2]+p[3]+p[6]+p[7];
        __syncwarp();
        float ts_lo=red_sum[wid][g_lo*4+0]+red_sum[wid][g_lo*4+1]+red_sum[wid][g_lo*4+2]+red_sum[wid][g_lo*4+3];
        float ts_hi=red_sum[wid][g_hi*4+0]+red_sum[wid][g_hi*4+1]+red_sum[wid][g_hi*4+2]+red_sum[wid][g_hi*4+3];
        __syncwarp();
        l_lo=l_lo*c_lo+ts_lo; l_hi=l_hi*c_hi+ts_hi; m_lo=mn_lo; m_hi=mn_hi;

        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa;
        #pragma unroll
        for (int i=0;i<8;++i){ __half hh=__float2half(p[i]); pa.x[i]=hh; pa.x[i+8]=hh; }
        #pragma unroll
        for (int t=0;t<DTILES;++t) scale_o(oacc[t], c_lo, c_hi);

        /* P.V(tile j) — dependent; the hoisted QK^T(j+1) above is in flight */
        const __half* vb = v_sm[cur];
        #pragma unroll
        for (int t=0;t<DTILES;++t){
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vf;
            wmma::load_matrix_sync(vf, vb + t*16, D);
            wmma::mma_sync(oacc[t], pa, vf, oacc[t]);
        }
        __syncthreads();

        s_cur = s_nxt;   /* promote next tile's QK^T to current */
    }

    float il_lo=1.f/l_lo, il_hi=1.f/l_hi;
    #pragma unroll
    for (int t=0;t<DTILES;++t){
        scale_o(oacc[t], il_lo, il_hi);
        wmma::store_matrix_sync(o_dbg[wid], oacc[t], 16, wmma::mem_row_major);
        __syncwarp();
        if (lane<16){ int row=qrow_base+lane; if (row<N){
            #pragma unroll
            for (int e=0;e<16;++e) o[(size_t)row*D + t*16 + e]=__float2half(o_dbg[wid][lane*16+e]); } }
        __syncwarp();
    }
}

static uint32_t lcg=0x12345678u;
static float rndf(){ lcg=lcg*1664525u+1013904223u; return ((float)(lcg>>8)/(float)(1u<<24))-0.5f; }
static int cmpd(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}

int main(int argc,char**argv){
    int N=(argc>1)?atoi(argv[1]):512; int d=D; int do_time=(argc>2&&atoi(argv[2])==1);
    if (N%BM!=0){fprintf(stderr,"N mult of %d\n",BM);return 2;}
    size_t ne=(size_t)N*d;
    float *qf=(float*)malloc(ne*4),*kf=(float*)malloc(ne*4),*vf=(float*)malloc(ne*4);
    __half *hq=(__half*)malloc(ne*2),*hk=(__half*)malloc(ne*2),*hv=(__half*)malloc(ne*2),*ho=(__half*)malloc(ne*2);
    double *ref=(double*)malloc(ne*8);
    for(size_t i=0;i<ne;++i){hq[i]=__float2half(rndf()*4.0f);qf[i]=__half2float(hq[i]);}
    for(size_t i=0;i<ne;++i){hk[i]=__float2half(rndf()*4.0f);kf[i]=__half2float(hk[i]);}
    for(size_t i=0;i<ne;++i){hv[i]=__float2half(rndf());     vf[i]=__half2float(hv[i]);}
    float scale=1.0f/sqrtf((float)d);
    double *sr=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){double m=-1e300;
        for(int j=0;j<N;++j){double s=0;for(int l=0;l<d;++l)s+=(double)qf[(size_t)i*d+l]*(double)kf[(size_t)j*d+l];
            s*=(double)scale;sr[j]=s;if(s>m)m=s;}
        double sum=0;for(int j=0;j<N;++j){sr[j]=exp(sr[j]-m);sum+=sr[j];}double inv=1.0/sum;
        for(int x=0;x<d;++x){double a=0;for(int j=0;j<N;++j)a+=sr[j]*(double)vf[(size_t)j*d+x];ref[(size_t)i*d+x]=a*inv;}
    } free(sr);
    __half *dq,*dk,*dv,*dO;
    CK(cudaMalloc(&dq,ne*2));CK(cudaMalloc(&dk,ne*2));CK(cudaMalloc(&dv,ne*2));CK(cudaMalloc(&dO,ne*2));
    CK(cudaMemcpy(dq,hq,ne*2,cudaMemcpyHostToDevice));CK(cudaMemcpy(dk,hk,ne*2,cudaMemcpyHostToDevice));CK(cudaMemcpy(dv,hv,ne*2,cudaMemcpyHostToDevice));
    int grid=N/BM,block=NWARP*32;
    fa_pipe<<<grid,block>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize());CK(cudaMemcpy(ho,dO,ne*2,cudaMemcpyDeviceToHost));
    double *rmx=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){double mx=0;for(int x=0;x<d;++x){double w=fabs(ref[(size_t)i*d+x]);if(w>mx)mx=w;}rmx[i]=mx;}
    double maxa=0,relrs=0,sse=0,ssr=0; long nanc=0;
    for(size_t i=0;i<ne;++i){double g=(double)__half2float(ho[i]),w=ref[i];
        if(isnan(g)||isinf(g)) nanc++;
        double a=fabs(g-w); if(a>maxa)maxa=a;int r=(int)(i/d);double rr=a/(rmx[r]+1e-9);if(rr>relrs)relrs=rr;sse+=a*a;ssr+=w*w;}
    double rms=sqrt(sse/(ssr+1e-30));int pass=(relrs<=1e-2)&&(nanc==0);
    printf("fa_pipe D=%d N=%d grid=%d block=%d max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g naninf=%ld numeric=%s",
           d,N,grid,block,maxa,relrs,rms,nanc,pass?"PASS":"FAIL");
    if(do_time){cudaEvent_t s,n;cudaEventCreate(&s);cudaEventCreate(&n);
        for(int w=0;w<20;++w)fa_pipe<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaDeviceSynchronize();
        int reps=200;double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){cudaEventRecord(s,0);fa_pipe<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaEventRecord(n,0);cudaEventSynchronize(n);float t;cudaEventElapsedTime(&t,s,n);ms[r]=t;}
        qsort(ms,reps,8,cmpd);printf(" median_ms=%.6f",ms[reps/2]);}
    printf("\n");return pass?0:1;
}
