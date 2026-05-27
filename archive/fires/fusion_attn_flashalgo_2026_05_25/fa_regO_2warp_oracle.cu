/* Round-8c: FA-2 reg-O with 2 warps per CTA. BM=32, d=64, grid=N/32.
 * Each warp owns 16 of the 32 query rows independently (no cross-warp reductions
 * needed for softmax since each row is owned by one warp).
 *
 * Shares K, V loads via cooperative load through smem (only 1 copy per CTA).
 * Doubles GEMM payload per softmax round; smem grows only modestly because no
 * o_tile in regs (round-4's lever was REMOVED; this 2-warp variant adds it back
 * only as needed for the doubled BM).
 *
 * Build: nvcc -O2 -arch=sm_90a -o fa_regO_2warp fa_regO_2warp_oracle.cu
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
using namespace nvcuda;

#define CK(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); return 1;}}while(0)

__device__ __forceinline__ void scale_frag_rows(
    wmma::fragment<wmma::accumulator,16,16,16,float>& f,
    const float* __restrict__ s, int lane)
{
    int g_lo = lane >> 2;
    int g_hi = g_lo + 8;
    float s_lo = s[g_lo], s_hi = s[g_hi];
    f.x[0] *= s_lo; f.x[1] *= s_lo;
    f.x[2] *= s_hi; f.x[3] *= s_hi;
    f.x[4] *= s_lo; f.x[5] *= s_lo;
    f.x[6] *= s_hi; f.x[7] *= s_hi;
}

extern "C" __global__ void fa_regO_2warp(const __half* q, const __half* k, const __half* v,
                                          __half* o, int N, float scale) {
    /* 2 warps. Warp 0 owns query rows [0..15], warp 1 owns [16..31]. */
    __shared__ float s_tile[2][16*16];   // per-warp S tile
    __shared__ __half p_tile[2][16*16];  // per-warp P tile
    __shared__ float m_vec[32], l_vec[32], c_vec[32];

    int tid  = threadIdx.x;
    int wid  = tid >> 5;          // 0 or 1
    int lane = tid & 31;

    int qrow_base = blockIdx.x * 32;
    int my_qrow   = qrow_base + wid * 16;
    const __half* qb = q + (size_t)my_qrow * 64;

    if (lane < 16) {
        m_vec[wid*16 + lane] = -INFINITY;
        l_vec[wid*16 + lane] = 0.0f;
    }
    __syncthreads();

    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[4];
    #pragma unroll
    for (int t = 0; t < 4; ++t) wmma::fill_fragment(oacc[t], 0.0f);

    int n_tiles = N >> 4;
    for (int kt = 0; kt < n_tiles; ++kt) {
        int krow_base = kt * 16;
        const __half* kb = k + (size_t)krow_base * 64;
        const __half* vb = v + (size_t)krow_base * 64;

        // QK^T (per-warp)
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a_frag;
        wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b_frag;
        wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
        wmma::fill_fragment(s_frag, 0.0f);
        #pragma unroll
        for (int kk = 0; kk < 4; ++kk) {
            wmma::load_matrix_sync(a_frag, qb + kk*16, 64);
            wmma::load_matrix_sync(b_frag, kb + kk*16, 64);
            wmma::mma_sync(s_frag, a_frag, b_frag, s_frag);
        }
        #pragma unroll
        for (int i = 0; i < s_frag.num_elements; ++i) s_frag.x[i] *= scale;
        wmma::store_matrix_sync(s_tile[wid], s_frag, 16, wmma::mem_row_major);
        __syncwarp();

        // online softmax (per-warp, per-row)
        if (lane < 16) {
            int i = lane;
            float s_max = -INFINITY;
            #pragma unroll
            for (int j = 0; j < 16; ++j) s_max = fmaxf(s_max, s_tile[wid][i*16+j]);
            float m_prev = m_vec[wid*16+i];
            float m_new = fmaxf(m_prev, s_max);
            float c = __expf(m_prev - m_new);
            c_vec[wid*16+i] = c;
            float row_sum = 0.0f;
            #pragma unroll
            for (int j = 0; j < 16; ++j) {
                float p = __expf(s_tile[wid][i*16+j] - m_new);
                row_sum += p;
                p_tile[wid][i*16+j] = __float2half(p);
            }
            l_vec[wid*16+i] = l_vec[wid*16+i]*c + row_sum;
            m_vec[wid*16+i] = m_new;
        }
        __syncwarp();

        // rescale O fragments by c
        #pragma unroll
        for (int t = 0; t < 4; ++t) scale_frag_rows(oacc[t], c_vec + wid*16, lane);

        // P.V into oacc
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_frag;
        wmma::load_matrix_sync(pa_frag, p_tile[wid], 16);
        #pragma unroll
        for (int t = 0; t < 4; ++t) {
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vb_frag;
            wmma::load_matrix_sync(vb_frag, vb + t*16, 64);
            wmma::mma_sync(oacc[t], pa_frag, vb_frag, oacc[t]);
        }
        __syncwarp();
    }

    // finalize per-warp
    if (lane < 16) c_vec[wid*16+lane] = 1.0f / l_vec[wid*16+lane];
    __syncwarp();
    #pragma unroll
    for (int t = 0; t < 4; ++t) {
        scale_frag_rows(oacc[t], c_vec + wid*16, lane);
        wmma::store_matrix_sync(s_tile[wid], oacc[t], 16, wmma::mem_row_major);
        __syncwarp();
        if (lane < 16) {
            int i = lane; int row = my_qrow + i;
            if (row < N) {
                #pragma unroll
                for (int e = 0; e < 16; ++e)
                    o[(size_t)row*64 + t*16 + e] = __float2half(s_tile[wid][i*16+e]);
            }
        }
        __syncwarp();
    }
}

/* ---- host ---- */
static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void){ lcg_state=lcg_state*1664525u+1013904223u;
    return ((float)(lcg_state>>8)/(float)(1u<<24))-0.5f; }
static int cmpd(const void*a,const void*b){ double x=*(const double*)a,y=*(const double*)b;
    return (x<y)?-1:(x>y)?1:0; }

int main(int argc, char** argv){
    int N=(argc>1)?atoi(argv[1]):512; int d=64; int do_time=(argc>2&&atoi(argv[2])==1);
    if (N % 32 != 0) { fprintf(stderr,"N must be multiple of 32\n"); return 2; }
    size_t elems=(size_t)N*d;
    float *hqf=(float*)malloc(elems*4),*hkf=(float*)malloc(elems*4),*hvf=(float*)malloc(elems*4);
    __half *hq=(__half*)malloc(elems*2),*hk=(__half*)malloc(elems*2),*hv=(__half*)malloc(elems*2),*ho=(__half*)malloc(elems*2);
    double *ref=(double*)malloc(elems*8);
    for(size_t i=0;i<elems;++i){ hq[i]=__float2half(lcg_f32()*4.0f); hqf[i]=__half2float(hq[i]); }
    for(size_t i=0;i<elems;++i){ hk[i]=__float2half(lcg_f32()*4.0f); hkf[i]=__half2float(hk[i]); }
    for(size_t i=0;i<elems;++i){ hv[i]=__float2half(lcg_f32());      hvf[i]=__half2float(hv[i]); }
    float scale=1.0f/sqrtf((float)d);
    double *srow=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double m=-1e300;
        for(int j=0;j<N;++j){ double s=0; for(int l=0;l<d;++l) s+=(double)hqf[(size_t)i*d+l]*(double)hkf[(size_t)j*d+l];
            s*=(double)scale; srow[j]=s; if(s>m)m=s; }
        double sum=0; for(int j=0;j<N;++j){ srow[j]=exp(srow[j]-m); sum+=srow[j]; } double inv=1.0/sum;
        for(int e=0;e<d;++e){ double acc=0; for(int j=0;j<N;++j) acc+=srow[j]*(double)hvf[(size_t)j*d+e]; ref[(size_t)i*d+e]=acc*inv; }
    } free(srow);
    __half *dq,*dk,*dv,*dO;
    CK(cudaMalloc(&dq,elems*2)); CK(cudaMalloc(&dk,elems*2)); CK(cudaMalloc(&dv,elems*2)); CK(cudaMalloc(&dO,elems*2));
    CK(cudaMemcpy(dq,hq,elems*2,cudaMemcpyHostToDevice)); CK(cudaMemcpy(dk,hk,elems*2,cudaMemcpyHostToDevice)); CK(cudaMemcpy(dv,hv,elems*2,cudaMemcpyHostToDevice));
    int grid=N/32, block=64;
    fa_regO_2warp<<<grid,block>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize()); CK(cudaMemcpy(ho,dO,elems*2,cudaMemcpyDeviceToHost));
    double *rowmax=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int e=0;e<d;++e){ double w=fabs(ref[(size_t)i*d+e]); if(w>mx)mx=w; } rowmax[i]=mx; }
    double max_abs=0,rel_rs=0,sse=0,ssref=0;
    for(size_t i=0;i<elems;++i){ double got=(double)__half2float(ho[i]),want=ref[i],a=fabs(got-want);
        if(a>max_abs)max_abs=a; int row=(int)(i/d); double rr=a/(rowmax[row]+1e-9); if(rr>rel_rs)rel_rs=rr; sse+=a*a; ssref+=want*want; }
    double rms=sqrt(sse/(ssref+1e-30)); int pass=(rel_rs<=1e-2);
    printf("regO_2warp N=%d grid=%d(vs48SM) max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g numeric=%s",N,grid,max_abs,rel_rs,rms,pass?"PASS":"FAIL");
    if(do_time){ cudaEvent_t st,en; cudaEventCreate(&st); cudaEventCreate(&en);
        for(int w=0;w<20;++w) fa_regO_2warp<<<grid,block>>>(dq,dk,dv,dO,N,scale); cudaDeviceSynchronize();
        int reps=200; double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){ cudaEventRecord(st,0); fa_regO_2warp<<<grid,block>>>(dq,dk,dv,dO,N,scale); cudaEventRecord(en,0); cudaEventSynchronize(en); float t; cudaEventElapsedTime(&t,st,en); ms[r]=t; }
        qsort(ms,reps,8,cmpd); printf(" median_ms=%.6f",ms[reps/2]); }
    printf("\n"); return pass?0:1;
}
