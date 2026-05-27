/* R14 alt-A: BM=16 BK=64 wedge — single warp/CTA, biggest BK so far.
 *
 * Hypothesis: R14 BM=32 BK=32 won by BK enlargement (R10 BK=16 1.149× →
 * R14 BK=32 0.927×). Pushing further to BK=64 with single warp/CTA tests
 * whether the BK lever continues monotonically OR saturates.
 *
 * Geometry: BM=16 (1 warp × 16 query rows), BK=64 (4 inner chunks of 16
 * per softmax round), d=64. block=32 (one warp), grid=N/16. V WMMA-API
 * row_major non-trans (no pretranspose). cp.async.cg K/V double-buffer.
 *
 * Smem closed-form (no per-warp cross-warp scratch since 1 warp/CTA):
 *  Q 16·64·2 = 2048
 *  K dbuf 2·64·64·2 = 16384
 *  V dbuf 2·64·64·2 = 16384
 *  scratch (red_max + red_sum + o_dbg) ≈ 1.5 KB
 *  TOTAL ≈ 36 KB → smem-bound ~2 CTAs/SM (vs R14's 5)
 *
 * Build: nvcc -O2 -arch=sm_90 -o fa_bm16_bk64 flash_attn_bm16_bk64_v0.cu
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

#define BM    16
#define KTILE 64
#define D     64

__device__ __forceinline__ void scale_o(
    wmma::fragment<wmma::accumulator,16,16,16,float>& f, float c_lo, float c_hi) {
    f.x[0]*=c_lo; f.x[1]*=c_lo; f.x[4]*=c_lo; f.x[5]*=c_lo;
    f.x[2]*=c_hi; f.x[3]*=c_hi; f.x[6]*=c_hi; f.x[7]*=c_hi;
}

__device__ __forceinline__ void cp_async_16(void* smem_ptr, const void* gmem_ptr) {
    unsigned s = (unsigned)__cvta_generic_to_shared(smem_ptr);
    asm volatile("cp.async.cg.shared.global [%0], [%1], 16;\n" :: "r"(s), "l"(gmem_ptr));
}
__device__ __forceinline__ void cp_async_commit() { asm volatile("cp.async.commit_group;\n" ::); }
template<int N>
__device__ __forceinline__ void cp_async_wait() { asm volatile("cp.async.wait_group %0;\n" :: "n"(N)); }

/* KTILE=64 × d=64 half = 4096 halves = 8192 bytes = 512 × 16-byte. 32 threads → 16 vectors each. */
__device__ __forceinline__ void load_tile_cpasync(__half* dst, const __half* src, int tid) {
    #pragma unroll
    for (int v = 0; v < 16; ++v) {
        int off = (v * 32 + tid) * 8;
        cp_async_16(dst + off, src + off);
    }
}

extern "C" __global__ void fa_bm16_bk64(const __half* q, const __half* k,
                                         const __half* v, __half* o,
                                         int N, float scale) {
    __shared__ __half k_sm[2][KTILE*D];   // 2 * 8192 B = 16384
    __shared__ __half v_sm[2][KTILE*D];   // 2 * 8192 B = 16384
    __shared__ float  red_max[16*4];      // 256 B
    __shared__ float  red_sum[16*4];      // 256 B
    __shared__ float  o_dbg [16*16];      // 1024 B
    /* total ~36.5 KB / CTA */

    int tid = threadIdx.x;          // 0..31
    int lane = tid;                  // single warp = lane

    int qrow_base = blockIdx.x * BM;
    const __half* qb = q + (size_t)qrow_base * D;

    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> qf[4];
    #pragma unroll
    for (int kk=0;kk<4;++kk) wmma::load_matrix_sync(qf[kk], qb + kk*16, D);

    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[4];
    #pragma unroll
    for (int t=0;t<4;++t) wmma::fill_fragment(oacc[t], 0.0f);

    float m_lo=-INFINITY, m_hi=-INFINITY, l_lo=0.0f, l_hi=0.0f;

    int n_tiles = N >> 6;   /* N / 64 */

    load_tile_cpasync(k_sm[0], k, tid);
    load_tile_cpasync(v_sm[0], v, tid);
    cp_async_commit();

    for (int kt=0; kt<n_tiles; ++kt) {
        int cur = kt & 1, nxt = (kt+1) & 1;

        if (kt+1 < n_tiles) {
            const __half* kb_n = k + (size_t)((kt+1)*KTILE) * D;
            const __half* vb_n = v + (size_t)((kt+1)*KTILE) * D;
            load_tile_cpasync(k_sm[nxt], kb_n, tid);
            load_tile_cpasync(v_sm[nxt], vb_n, tid);
            cp_async_commit();
        }
        if (kt+1 < n_tiles) cp_async_wait<1>();
        else                cp_async_wait<0>();
        __syncwarp();

        const __half* kb = k_sm[cur];
        const __half* vb = v_sm[cur];

        /* BK=64 = 4 chunks of 16 */
        #pragma unroll
        for (int kc = 0; kc < 4; ++kc) {
            const __half* kb_c = kb + kc * 16 * D;
            const __half* vb_c = vb + kc * 16 * D;

            wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
            wmma::fill_fragment(s_frag, 0.0f);
            #pragma unroll
            for (int kk=0;kk<4;++kk) {
                wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> kf;
                wmma::load_matrix_sync(kf, kb_c + kk*16, D);
                wmma::mma_sync(s_frag, qf[kk], kf, s_frag);
            }
            #pragma unroll
            for (int i=0;i<s_frag.num_elements;++i) s_frag.x[i]*=scale;

            int g_lo = lane >> 2, g_hi = g_lo + 8, slot = lane & 3;
            float pmax_lo = fmaxf(fmaxf(s_frag.x[0],s_frag.x[1]), fmaxf(s_frag.x[4],s_frag.x[5]));
            float pmax_hi = fmaxf(fmaxf(s_frag.x[2],s_frag.x[3]), fmaxf(s_frag.x[6],s_frag.x[7]));
            red_max[g_lo*4+slot] = pmax_lo;
            red_max[g_hi*4+slot] = pmax_hi;
            __syncwarp();
            float tmax_lo = fmaxf(fmaxf(red_max[g_lo*4+0],red_max[g_lo*4+1]),fmaxf(red_max[g_lo*4+2],red_max[g_lo*4+3]));
            float tmax_hi = fmaxf(fmaxf(red_max[g_hi*4+0],red_max[g_hi*4+1]),fmaxf(red_max[g_hi*4+2],red_max[g_hi*4+3]));
            __syncwarp();
            float mn_lo = fmaxf(m_lo, tmax_lo), mn_hi = fmaxf(m_hi, tmax_hi);
            float c_lo = __expf(m_lo - mn_lo), c_hi = __expf(m_hi - mn_hi);

            float p[8];
            p[0]=__expf(s_frag.x[0]-mn_lo); p[1]=__expf(s_frag.x[1]-mn_lo);
            p[4]=__expf(s_frag.x[4]-mn_lo); p[5]=__expf(s_frag.x[5]-mn_lo);
            p[2]=__expf(s_frag.x[2]-mn_hi); p[3]=__expf(s_frag.x[3]-mn_hi);
            p[6]=__expf(s_frag.x[6]-mn_hi); p[7]=__expf(s_frag.x[7]-mn_hi);

            red_sum[g_lo*4+slot] = p[0]+p[1]+p[4]+p[5];
            red_sum[g_hi*4+slot] = p[2]+p[3]+p[6]+p[7];
            __syncwarp();
            float ts_lo = red_sum[g_lo*4+0]+red_sum[g_lo*4+1]+red_sum[g_lo*4+2]+red_sum[g_lo*4+3];
            float ts_hi = red_sum[g_hi*4+0]+red_sum[g_hi*4+1]+red_sum[g_hi*4+2]+red_sum[g_hi*4+3];
            __syncwarp();
            l_lo = l_lo*c_lo + ts_lo;
            l_hi = l_hi*c_hi + ts_hi;
            m_lo = mn_lo; m_hi = mn_hi;

            wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa;
            #pragma unroll
            for (int i=0;i<8;++i) { __half h=__float2half(p[i]); pa.x[i]=h; pa.x[i+8]=h; }

            #pragma unroll
            for (int t=0;t<4;++t) scale_o(oacc[t], c_lo, c_hi);

            #pragma unroll
            for (int t=0;t<4;++t) {
                wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vf;
                wmma::load_matrix_sync(vf, vb_c + t*16, D);
                wmma::mma_sync(oacc[t], pa, vf, oacc[t]);
            }
        }
        __syncwarp();
    }

    float il_lo = 1.0f/l_lo, il_hi = 1.0f/l_hi;
    #pragma unroll
    for (int t=0;t<4;++t) {
        scale_o(oacc[t], il_lo, il_hi);
        wmma::store_matrix_sync(o_dbg, oacc[t], 16, wmma::mem_row_major);
        __syncwarp();
        if (lane < 16) {
            int row = qrow_base + lane;
            if (row < N) {
                #pragma unroll
                for (int e=0;e<16;++e) o[(size_t)row*D + t*16 + e] = __float2half(o_dbg[lane*16+e]);
            }
        }
        __syncwarp();
    }
}

static uint32_t lcg=0x12345678u;
static float rndf(){ lcg=lcg*1664525u+1013904223u; return ((float)(lcg>>8)/(float)(1u<<24))-0.5f; }
static int cmpd(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}

int main(int argc,char**argv){
    int N=(argc>1)?atoi(argv[1]):2048; int d=64; int do_time=(argc>2&&atoi(argv[2])==1);
    if (N % BM != 0) { fprintf(stderr,"N must be multiple of %d\n", BM); return 2; }
    if (N % KTILE != 0) { fprintf(stderr,"N must be multiple of KTILE=%d\n", KTILE); return 2; }
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

    int grid=N/BM,block=32;
    int nblk=-1;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&nblk, fa_bm16_bk64, block, 0);
    printf("occupancy_max_active_blocks_per_sm=%d ", nblk);

    fa_bm16_bk64<<<grid,block>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize());CK(cudaMemcpy(ho,dO,ne*2,cudaMemcpyDeviceToHost));

    double *rmx=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){double mx=0;for(int x=0;x<d;++x){double w=fabs(ref[(size_t)i*d+x]);if(w>mx)mx=w;}rmx[i]=mx;}
    double maxa=0,relrs=0,sse=0,ssr=0; long nanc=0;
    for(size_t i=0;i<ne;++i){double g=(double)__half2float(ho[i]),w=ref[i];
        if(isnan(g)||isinf(g)) nanc++;
        double a=fabs(g-w);
        if(a>maxa)maxa=a;int r=(int)(i/d);double rr=a/(rmx[r]+1e-9);if(rr>relrs)relrs=rr;sse+=a*a;ssr+=w*w;}
    double rms=sqrt(sse/(ssr+1e-30));int pass=(relrs<=1e-2)&&(nanc==0);
    printf("bm16_bk64 N=%d grid=%d block=%d max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g naninf=%ld numeric=%s",
           N,grid,block,maxa,relrs,rms,nanc,pass?"PASS":"FAIL");
    if(do_time){cudaEvent_t s,n;cudaEventCreate(&s);cudaEventCreate(&n);
        for(int w=0;w<20;++w)fa_bm16_bk64<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaDeviceSynchronize();
        int reps=200;double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){cudaEventRecord(s,0);fa_bm16_bk64<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaEventRecord(n,0);cudaEventSynchronize(n);float t;cudaEventElapsedTime(&t,s,n);ms[r]=t;}
        qsort(ms,reps,8,cmpd);printf(" median_ms=%.6f",ms[reps/2]);}
    printf("\n");return pass?0:1;
}
