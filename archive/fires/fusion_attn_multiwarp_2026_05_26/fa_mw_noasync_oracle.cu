/* R10: FlashAttention-2 multi-warp (BM=64, 4 warps/CTA) + cp.async K/V
 * double-buffer. The pre-registered falsifier F-FUSION-ATTN-MULTIWARP wedge:
 * R9 diagnosed the d=64 16x16 single-warp tile as LATENCY/DEPENDENCY-bound --
 * the per-tile row-reduction between QK^T mma and P.V mma sits on the critical
 * path with no other warp's work to hide it. R10 breaks that floor two ways:
 *
 *  (1) MULTI-WARP BM=64: 4 warps per CTA, each warp owns 16 INDEPENDENT query
 *      rows (warp w -> rows [w*16 .. w*16+15]). No cross-warp softmax needed
 *      (each row owned by exactly one warp). While warp 0 does its row-reduce,
 *      warps 1-3 issue their QK^T / P.V mma -> the reduction latency is hidden
 *      by warp-level parallelism (standard FA-2 "warps cooperate on a larger
 *      Q-block" structure). The 4 warps SHARE the K/V tile (loaded once per CTA
 *      into smem), so HBM traffic is not multiplied.
 *
 *  (2) cp.async.cg.shared.global K/V DOUBLE-BUFFER (sm_80+): the K/V tile load
 *      for iteration j+1 issues async while iteration j computes -> HBM load
 *      latency overlapped with the mma pipeline, not serial.
 *
 * INHERIT from R8/R9 (do NOT regress):
 *  - m16n16k16 f32 accumulator row map: elems {0,1,4,5}->row=lane/4 ;
 *    {2,3,6,7}->row=lane/4+8 (R8 finding, used in scale_o).
 *  - acc->matrix_a repack is a LOCAL reg move pa.x[i]=pa.x[i+8]=acc.x[i] on
 *    sm_120 (R9 finding) -- no cross-lane shuffle.
 *  - reg-S (QK^T in accumulator regs, no smem store) + reg-P + smem-SCRATCH
 *    row-reduce (R9's surfaced winner -- NOT warp-shuffle, R9 ruled that out).
 *
 * Geometry: BM=64, d=64, 4 warps/CTA, grid=N/64, block=128. K/V tiles are
 * 16 rows x 64 cols half each, double-buffered in smem.
 *
 * Build: nvcc -O2 -arch=sm_90a -o fa_mw_cpasync fa_mw_cpasync_oracle.cu
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

#define NWARP 4
#define BM    64          /* 4 warps * 16 query rows */
#define KTILE 16          /* K/V tile = 16 rows */
#define D     64

/* Rescale the O accumulator rows by per-row factor (c_lo for row lane/4,
 * c_hi for row lane/4+8), directly on the fragment regs. (R8 path.) */
__device__ __forceinline__ void scale_o(
    wmma::fragment<wmma::accumulator,16,16,16,float>& f, float c_lo, float c_hi) {
    f.x[0]*=c_lo; f.x[1]*=c_lo; f.x[4]*=c_lo; f.x[5]*=c_lo;
    f.x[2]*=c_hi; f.x[3]*=c_hi; f.x[6]*=c_hi; f.x[7]*=c_hi;
}

/* cp.async: copy 16 bytes (one half8) gmem->smem, cache-global, async. */
__device__ __forceinline__ void cp_async_16(void* smem_ptr, const void* gmem_ptr) {
    unsigned s = (unsigned)__cvta_generic_to_shared(smem_ptr);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" ::
                 "r"(s), "l"(gmem_ptr));
}
__device__ __forceinline__ void cp_async_commit() {
    asm volatile("cp.async.commit_group;\n" ::);
}
template<int N>
__device__ __forceinline__ void cp_async_wait() {
    asm volatile("cp.async.wait_group %0;\n" :: "n"(N));
}

/* Cooperatively load one 16x64 half tile (K or V) gmem -> smem via cp.async.
 * 16*64 = 1024 halves = 2048 bytes = 128 x 16-byte vectors. 128 threads ->
 * exactly 1 vector each. Caller commits + waits. */
__device__ __forceinline__ void load_tile_cpasync(__half* dst, const __half* src, int tid) {
    /* each thread copies a contiguous 8-half (16B) chunk */
    cp_async_16(dst + tid*8, src + tid*8);
}

extern "C" __global__ void fa_mw_noasync(const __half* q, const __half* k,
                                         const __half* v, __half* o,
                                         int N, float scale) {
    /* single-buffer K/V tiles in smem (NO cp.async, NO double-buffer) */
    __shared__ __half k_sm[KTILE*D];   // 2048 B
    __shared__ __half v_sm[KTILE*D];   // 2048 B
    /* per-warp reduction scratch + finalize store scratch */
    __shared__ float  red_max[NWARP][16*4];
    __shared__ float  red_sum[NWARP][16*4];
    __shared__ float  o_dbg [NWARP][16*16];

    int tid  = threadIdx.x;          // 0..127
    int wid  = tid >> 5;             // warp id 0..3
    int lane = tid & 31;

    int qrow_base = blockIdx.x * BM + wid * 16;   // this warp's 16 query rows
    const __half* qb = q + (size_t)qrow_base * D;

    // Q resident in matrix_a fragments across the whole K loop (4 d-tiles)
    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> qf[4];
    #pragma unroll
    for (int kk=0;kk<4;++kk) wmma::load_matrix_sync(qf[kk], qb + kk*16, D);

    // O accumulators (one per d-tile), register-resident across the K loop
    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[4];
    #pragma unroll
    for (int t=0;t<4;++t) wmma::fill_fragment(oacc[t], 0.0f);

    float m_lo=-INFINITY, m_hi=-INFINITY, l_lo=0.0f, l_hi=0.0f;

    int n_tiles = N >> 4;

    for (int kt=0; kt<n_tiles; ++kt) {
        /* synchronous cooperative load of CURRENT tile into smem (no async) */
        const __half* kb_g = k + (size_t)(kt*KTILE) * D;
        const __half* vb_g = v + (size_t)(kt*KTILE) * D;
        #pragma unroll
        for (int i=0;i<8;++i) { k_sm[tid*8+i] = kb_g[tid*8+i]; v_sm[tid*8+i] = vb_g[tid*8+i]; }
        __syncthreads();

        const __half* kb = k_sm;
        const __half* vb = v_sm;

        // ---- S = Q.K^T into accumulator regs (K from smem) ----
        wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
        wmma::fill_fragment(s_frag, 0.0f);
        #pragma unroll
        for (int kk=0;kk<4;++kk) {
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> kf;
            wmma::load_matrix_sync(kf, kb + kk*16, D);
            wmma::mma_sync(s_frag, qf[kk], kf, s_frag);
        }
        #pragma unroll
        for (int i=0;i<s_frag.num_elements;++i) s_frag.x[i]*=scale;

        // ---- row max via per-warp SMEM scratch (R9 winner, NOT shfl) ----
        int g_lo = lane >> 2, g_hi = g_lo + 8, slot = lane & 3;
        float pmax_lo = fmaxf(fmaxf(s_frag.x[0],s_frag.x[1]), fmaxf(s_frag.x[4],s_frag.x[5]));
        float pmax_hi = fmaxf(fmaxf(s_frag.x[2],s_frag.x[3]), fmaxf(s_frag.x[6],s_frag.x[7]));
        red_max[wid][g_lo*4+slot] = pmax_lo;
        red_max[wid][g_hi*4+slot] = pmax_hi;
        __syncwarp();
        float tmax_lo = fmaxf(fmaxf(red_max[wid][g_lo*4+0],red_max[wid][g_lo*4+1]),fmaxf(red_max[wid][g_lo*4+2],red_max[wid][g_lo*4+3]));
        float tmax_hi = fmaxf(fmaxf(red_max[wid][g_hi*4+0],red_max[wid][g_hi*4+1]),fmaxf(red_max[wid][g_hi*4+2],red_max[wid][g_hi*4+3]));
        __syncwarp();
        float mn_lo = fmaxf(m_lo, tmax_lo), mn_hi = fmaxf(m_hi, tmax_hi);
        float c_lo = __expf(m_lo - mn_lo), c_hi = __expf(m_hi - mn_hi);

        // ---- P = exp(S - m_new) in regs ----
        float p[8];
        p[0]=__expf(s_frag.x[0]-mn_lo); p[1]=__expf(s_frag.x[1]-mn_lo);
        p[4]=__expf(s_frag.x[4]-mn_lo); p[5]=__expf(s_frag.x[5]-mn_lo);
        p[2]=__expf(s_frag.x[2]-mn_hi); p[3]=__expf(s_frag.x[3]-mn_hi);
        p[6]=__expf(s_frag.x[6]-mn_hi); p[7]=__expf(s_frag.x[7]-mn_hi);

        // ---- row sum via per-warp SMEM scratch ----
        red_sum[wid][g_lo*4+slot] = p[0]+p[1]+p[4]+p[5];
        red_sum[wid][g_hi*4+slot] = p[2]+p[3]+p[6]+p[7];
        __syncwarp();
        float ts_lo = red_sum[wid][g_lo*4+0]+red_sum[wid][g_lo*4+1]+red_sum[wid][g_lo*4+2]+red_sum[wid][g_lo*4+3];
        float ts_hi = red_sum[wid][g_hi*4+0]+red_sum[wid][g_hi*4+1]+red_sum[wid][g_hi*4+2]+red_sum[wid][g_hi*4+3];
        __syncwarp();
        l_lo = l_lo*c_lo + ts_lo;
        l_hi = l_hi*c_hi + ts_hi;
        m_lo = mn_lo; m_hi = mn_hi;

        // ---- repack P -> matrix_a regs (LOCAL move, no shuffle; R9) ----
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa;
        #pragma unroll
        for (int i=0;i<8;++i) { __half h=__float2half(p[i]); pa.x[i]=h; pa.x[i+8]=h; }

        // ---- rescale running O by c (in regs) ----
        #pragma unroll
        for (int t=0;t<4;++t) scale_o(oacc[t], c_lo, c_hi);

        // ---- P.V into oacc: V fragments from smem ----
        #pragma unroll
        for (int t=0;t<4;++t) {
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vf;
            wmma::load_matrix_sync(vf, vb + t*16, D);
            wmma::mma_sync(oacc[t], pa, vf, oacc[t]);
        }
        __syncthreads();   /* tile consumed; safe to overwrite buffer cur next */
    }

    // ---- finalize: divide each row by l, store O ----
    float il_lo = 1.0f/l_lo, il_hi = 1.0f/l_hi;
    #pragma unroll
    for (int t=0;t<4;++t) {
        scale_o(oacc[t], il_lo, il_hi);
        wmma::store_matrix_sync(o_dbg[wid], oacc[t], 16, wmma::mem_row_major);
        __syncwarp();
        if (lane < 16) {
            int row = qrow_base + lane;
            if (row < N) {
                #pragma unroll
                for (int e=0;e<16;++e) o[(size_t)row*D + t*16 + e] = __float2half(o_dbg[wid][lane*16+e]);
            }
        }
        __syncwarp();
    }
}

/* ---- host: f64 oracle + honest per-row-scaled rel-err + optional timing ---- */
static uint32_t lcg=0x12345678u;
static float rndf(){ lcg=lcg*1664525u+1013904223u; return ((float)(lcg>>8)/(float)(1u<<24))-0.5f; }
static int cmpd(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}

int main(int argc,char**argv){
    int N=(argc>1)?atoi(argv[1]):512; int d=64; int do_time=(argc>2&&atoi(argv[2])==1);
    if (N % BM != 0) { fprintf(stderr,"N must be multiple of %d\n", BM); return 2; }
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
    fa_mw_noasync<<<grid,block>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize());CK(cudaMemcpy(ho,dO,ne*2,cudaMemcpyDeviceToHost));
    double *rmx=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){double mx=0;for(int x=0;x<d;++x){double w=fabs(ref[(size_t)i*d+x]);if(w>mx)mx=w;}rmx[i]=mx;}
    double maxa=0,relrs=0,sse=0,ssr=0; long nanc=0;
    for(size_t i=0;i<ne;++i){double g=(double)__half2float(ho[i]),w=ref[i];
        if(isnan(g)||isinf(g)) nanc++;
        double a=fabs(g-w);
        if(a>maxa)maxa=a;int r=(int)(i/d);double rr=a/(rmx[r]+1e-9);if(rr>relrs)relrs=rr;sse+=a*a;ssr+=w*w;}
    double rms=sqrt(sse/(ssr+1e-30));int pass=(relrs<=1e-2)&&(nanc==0);
    printf("mw_noasync N=%d grid=%d block=%d max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g naninf=%ld numeric=%s",
           N,grid,block,maxa,relrs,rms,nanc,pass?"PASS":"FAIL");
    if(do_time){cudaEvent_t s,n;cudaEventCreate(&s);cudaEventCreate(&n);
        for(int w=0;w<20;++w)fa_mw_noasync<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaDeviceSynchronize();
        int reps=200;double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){cudaEventRecord(s,0);fa_mw_noasync<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaEventRecord(n,0);cudaEventSynchronize(n);float t;cudaEventElapsedTime(&t,s,n);ms[r]=t;}
        qsort(ms,reps,8,cmpd);printf(" median_ms=%.6f",ms[reps/2]);}
    printf("\n");return pass?0:1;
}
