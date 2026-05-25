/* R9: FlashAttention-2 with REGISTER-RESIDENT S/P + warp-shuffle softmax +
 * mma-from-regs P.V. Eliminates R8's residual S/P smem round-trip.
 *
 * Inheritance from R8 #1117 (fa_regO_v2): O accumulator register-resident
 * across the K/V loop with the CORRECT m16n16k16 f32 accumulator row map
 * (elems {0,1,4,5} -> row=lane/4 ; elems {2,3,6,7} -> row=lane/4+8). Do NOT
 * regress that fix.
 *
 * R9 novelty (proven bit-exact by frag_repack_probe.cu + frag_repack_partc.cu):
 *  - S = QK^T stays in accumulator REGISTERS (no smem store).
 *  - softmax rowmax + rowsum via __shfl_xor_sync over the 4 lanes sharing a row
 *    (groups of 4: lane, lane^1, lane^2, lane^3). m/l persist per-lane in regs.
 *  - P = exp(S - m_new) computed in regs in-place.
 *  - P repacked to matrix_a operand via the LOCAL move pa.x[i]=pa.x[i+8]=p[i]
 *    (acc map == matrix_a map on sm_120 -> no cross-lane shuffle needed).
 *  - P.V mma consumes P DIRECTLY from regs (matrix_a), V from smem (matrix_b).
 *  - O accumulator rescaled by the online correction c IN REGS (R8's path).
 *
 * Geometry: BQ=16, d=64, 1 warp/CTA, grid=N/16, block=32. d=64 => 4 d-tiles
 * for O (oacc[4]) and V is loaded per d-tile from smem.
 *
 * Build: nvcc -O2 -arch=sm_90a -o fa_regS_v1 fa_regS_v1_oracle.cu
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

/* Rescale the O accumulator rows by per-row factor (c_lo for row lane/4,
 * c_hi for row lane/4+8), directly on the fragment regs. (R8 path.) */
__device__ __forceinline__ void scale_o(
    wmma::fragment<wmma::accumulator,16,16,16,float>& f, float c_lo, float c_hi) {
    f.x[0]*=c_lo; f.x[1]*=c_lo; f.x[4]*=c_lo; f.x[5]*=c_lo;
    f.x[2]*=c_hi; f.x[3]*=c_hi; f.x[6]*=c_hi; f.x[7]*=c_hi;
}

extern "C" __global__ void fa_regS_v1(const __half* q, const __half* k,
                                      const __half* v, __half* o, int N, float scale) {
    __shared__ __half v_tile[16*64];   // current K/V block's V (16 rows x d=64)
    __shared__ float o_dbg[16*16];     // finalize store scratch
    int lane = threadIdx.x & 31;
    int qrow_base = blockIdx.x * 16;
    const __half* qb = q + (size_t)qrow_base * 64;

    // Q resident in matrix_a fragments across the whole K loop (4 d-tiles)
    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> qf[4];
    #pragma unroll
    for (int kk=0;kk<4;++kk) wmma::load_matrix_sync(qf[kk], qb + kk*16, 64);

    // O accumulators (one per d-tile), register-resident across the K loop
    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[4];
    #pragma unroll
    for (int t=0;t<4;++t) wmma::fill_fragment(oacc[t], 0.0f);

    // running softmax state, per-lane in regs: m/l for the two rows this lane owns
    float m_lo=-INFINITY, m_hi=-INFINITY, l_lo=0.0f, l_hi=0.0f;

    int n_tiles = N >> 4;
    for (int kt=0; kt<n_tiles; ++kt) {
        const __half* kb = k + (size_t)(kt*16) * 64;
        const __half* vb = v + (size_t)(kt*16) * 64;

        // ---- S = Q.K^T into accumulator regs ----
        wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
        wmma::fill_fragment(s_frag, 0.0f);
        #pragma unroll
        for (int kk=0;kk<4;++kk) {
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> kf;
            wmma::load_matrix_sync(kf, kb + kk*16, 64);
            wmma::mma_sync(s_frag, qf[kk], kf, s_frag);
        }
        #pragma unroll
        for (int i=0;i<s_frag.num_elements;++i) s_frag.x[i]*=scale;

        // ---- row max over this tile via shfl_xor (in regs) ----
        float tmax_lo = fmaxf(fmaxf(s_frag.x[0],s_frag.x[1]), fmaxf(s_frag.x[4],s_frag.x[5]));
        float tmax_hi = fmaxf(fmaxf(s_frag.x[2],s_frag.x[3]), fmaxf(s_frag.x[6],s_frag.x[7]));
        #pragma unroll
        for (int off=1; off<4; off<<=1) {
            tmax_lo = fmaxf(tmax_lo, __shfl_xor_sync(0xffffffffu, tmax_lo, off));
            tmax_hi = fmaxf(tmax_hi, __shfl_xor_sync(0xffffffffu, tmax_hi, off));
        }
        // online update: m_new, correction c
        float mn_lo = fmaxf(m_lo, tmax_lo), mn_hi = fmaxf(m_hi, tmax_hi);
        float c_lo = __expf(m_lo - mn_lo), c_hi = __expf(m_hi - mn_hi);

        // ---- P = exp(S - m_new) in regs ----
        float p[8];
        p[0]=__expf(s_frag.x[0]-mn_lo); p[1]=__expf(s_frag.x[1]-mn_lo);
        p[4]=__expf(s_frag.x[4]-mn_lo); p[5]=__expf(s_frag.x[5]-mn_lo);
        p[2]=__expf(s_frag.x[2]-mn_hi); p[3]=__expf(s_frag.x[3]-mn_hi);
        p[6]=__expf(s_frag.x[6]-mn_hi); p[7]=__expf(s_frag.x[7]-mn_hi);

        // ---- row sum via shfl_xor, online l update ----
        float ts_lo = p[0]+p[1]+p[4]+p[5];
        float ts_hi = p[2]+p[3]+p[6]+p[7];
        #pragma unroll
        for (int off=1; off<4; off<<=1) {
            ts_lo += __shfl_xor_sync(0xffffffffu, ts_lo, off);
            ts_hi += __shfl_xor_sync(0xffffffffu, ts_hi, off);
        }
        l_lo = l_lo*c_lo + ts_lo;
        l_hi = l_hi*c_hi + ts_hi;
        m_lo = mn_lo; m_hi = mn_hi;

        // ---- repack P -> matrix_a regs (LOCAL move, no shuffle) ----
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa;
        #pragma unroll
        for (int i=0;i<8;++i) { __half h=__float2half(p[i]); pa.x[i]=h; pa.x[i+8]=h; }

        // ---- rescale running O by c (in regs) ----
        #pragma unroll
        for (int t=0;t<4;++t) scale_o(oacc[t], c_lo, c_hi);

        // ---- load V block to smem (cooperative), then P.V into oacc ----
        for (int idx=lane; idx<16*64; idx+=32) v_tile[idx] = vb[idx];
        __syncwarp();
        #pragma unroll
        for (int t=0;t<4;++t) {
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vf;
            wmma::load_matrix_sync(vf, v_tile + t*16, 64);
            wmma::mma_sync(oacc[t], pa, vf, oacc[t]);
        }
        __syncwarp();
    }

    // ---- finalize: divide each row by l, store O ----
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
                for (int e=0;e<16;++e) o[(size_t)row*64 + t*16 + e] = __float2half(o_dbg[lane*16+e]);
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
    int grid=N/16,block=32;
    fa_regS_v1<<<grid,block>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize());CK(cudaMemcpy(ho,dO,ne*2,cudaMemcpyDeviceToHost));
    double *rmx=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){double mx=0;for(int x=0;x<d;++x){double w=fabs(ref[(size_t)i*d+x]);if(w>mx)mx=w;}rmx[i]=mx;}
    double maxa=0,relrs=0,sse=0,ssr=0;
    for(size_t i=0;i<ne;++i){double g=(double)__half2float(ho[i]),w=ref[i],a=fabs(g-w);
        if(a>maxa)maxa=a;int r=(int)(i/d);double rr=a/(rmx[r]+1e-9);if(rr>relrs)relrs=rr;sse+=a*a;ssr+=w*w;}
    double rms=sqrt(sse/(ssr+1e-30));int pass=(relrs<=1e-2);
    printf("regS_v1 N=%d grid=%d max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g numeric=%s",
           N,grid,maxa,relrs,rms,pass?"PASS":"FAIL");
    if(do_time){cudaEvent_t s,n;cudaEventCreate(&s);cudaEventCreate(&n);
        for(int w=0;w<20;++w)fa_regS_v1<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaDeviceSynchronize();
        int reps=200;double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){cudaEventRecord(s,0);fa_regS_v1<<<grid,block>>>(dq,dk,dv,dO,N,scale);cudaEventRecord(n,0);cudaEventSynchronize(n);float t;cudaEventElapsedTime(&t,s,n);ms[r]=t;}
        qsort(ms,reps,8,cmpd);printf(" median_ms=%.6f",ms[reps/2]);}
    printf("\n");return pass?0:1;
}
