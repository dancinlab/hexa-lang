/* Multi-warp flash-attention -- CUDA-C wmma geometry validator.
 * CTA = WARPS warps; each warp owns one 16-query-row sub-tile. So one CTA
 * covers Bq = WARPS*16 query rows. grid = ceil(N / Bq).  This raises both
 * per-CTA work (latency hiding) and keeps the inner GEMMs on Tensor Cores,
 * with the S tile resident in shared (never to HBM) and online softmax.
 *
 * Compile-time WARPS (1,2,4,8) so we can sweep the geometry that closes the
 * gap vs cuBLAS-TC before committing it to hand-emit PTX.
 *
 * Build: nvcc -O2 -arch=sm_90a -DWARPS=4 -o fa_mw fa_multiwarp_oracle.cu
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

#ifndef WARPS
#define WARPS 4
#endif
#define BQ (WARPS*16)   /* query rows per CTA */

#define CK(call) do { cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA err %s @ %s:%d\n",cudaGetErrorString(e),__FILE__,__LINE__); return 1;}}while(0)

/* WARPS warps / CTA. Each warp w owns query sub-tile rows [w*16 .. w*16+15].
 * d=64. Per-warp shared slabs indexed by warp id. */
__global__ void fa_mw(const __half* q, const __half* k, const __half* v,
                      __half* o, int N, float scale) {
    __shared__ float s_tile[WARPS][16*16];   // per-warp QK^T / scratch
    __shared__ __half p_tile[WARPS][16*16];   // per-warp softmax probs
    __shared__ float o_tile[WARPS][16*64];    // per-warp running O
    __shared__ float m_vec[WARPS][16], l_vec[WARPS][16], c_vec[WARPS][16];

    int warp = threadIdx.x >> 5;       // 0..WARPS-1
    int lane = threadIdx.x & 31;
    int qrow_base = blockIdx.x * BQ + warp * 16;
    const __half* qb = q + (size_t)qrow_base * 64;

    float (*S)[16] = (float(*)[16])s_tile[warp];   // 16x16 view
    __half *P = p_tile[warp];
    float  *O = o_tile[warp];
    float  *mV = m_vec[warp], *lV = l_vec[warp], *cV = c_vec[warp];

    int valid = (qrow_base < N);       // last CTA may overhang

    // init -- all 32 lanes cooperate (rows 0..15, 2 cols of 64 each? use lane<16)
    if (lane < 16) { mV[lane] = -INFINITY; lV[lane] = 0.0f; }
    for (int idx = lane; idx < 16*64; idx += 32) O[idx] = 0.0f;
    __syncwarp();

    int n_tiles = N >> 4;
    for (int kt = 0; kt < n_tiles; ++kt) {
        int krow_base = kt * 16;
        const __half* kb = k + (size_t)krow_base * 64;
        const __half* vb = v + (size_t)krow_base * 64;

        // QK^T (TC)
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
        wmma::store_matrix_sync(&S[0][0], s_frag, 16, wmma::mem_row_major);
        __syncwarp();

        // online softmax: lanes 0..15 each own a row
        if (lane < 16) {
            int i = lane;
            float s_max = -INFINITY;
            #pragma unroll
            for (int j = 0; j < 16; ++j) s_max = fmaxf(s_max, S[i][j]);
            float m_prev = mV[i];
            float m_new = fmaxf(m_prev, s_max);
            float c = __expf(m_prev - m_new);
            cV[i] = c;
            float row_sum = 0.0f;
            #pragma unroll
            for (int j = 0; j < 16; ++j) {
                float p = __expf(S[i][j] - m_new);
                row_sum += p;
                P[i*16+j] = __float2half(p);
            }
            lV[i] = lV[i]*c + row_sum;
            mV[i] = m_new;
        }
        __syncwarp();

        // rescale running O by c -- all 32 lanes over 16*64 elements
        for (int idx = lane; idx < 16*64; idx += 32) {
            int row = idx >> 6;          // /64
            O[idx] *= cV[row];
        }
        __syncwarp();

        // P.V (TC) : 4 N-tiles
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_frag;
        wmma::load_matrix_sync(pa_frag, P, 16);
        #pragma unroll
        for (int t = 0; t < 4; ++t) {
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vb_frag;
            wmma::fragment<wmma::accumulator,16,16,16,float> op_frag;
            wmma::fill_fragment(op_frag, 0.0f);
            wmma::load_matrix_sync(vb_frag, vb + t*16, 64);
            wmma::mma_sync(op_frag, pa_frag, vb_frag, op_frag);
            wmma::store_matrix_sync(&S[0][0], op_frag, 16, wmma::mem_row_major);
            __syncwarp();
            // add S (16x16 partial) into O cols [t*16..t*16+15]; 32 lanes
            for (int idx = lane; idx < 16*16; idx += 32) {
                int r = idx >> 4, cc = idx & 15;
                O[r*64 + t*16 + cc] += S[r][cc];
            }
            __syncwarp();
        }
    }

    // finalize
    if (valid && lane < 16) {
        int i = lane; int row = qrow_base + i;
        if (row < N) {
            float inv = 1.0f / lV[i];
            #pragma unroll
            for (int e = 0; e < 64; ++e)
                o[(size_t)row*64+e] = __float2half(O[i*64+e] * inv);
        }
    }
}

static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void){ lcg_state=lcg_state*1664525u+1013904223u;
    return ((float)(lcg_state>>8)/(float)(1u<<24))-0.5f; }
static int cmpd(const void*a,const void*b){ double x=*(const double*)a,y=*(const double*)b;
    return (x<y)?-1:(x>y)?1:0; }

int main(int argc, char** argv){
    int N = (argc>1)?atoi(argv[1]):512;
    int d = 64;
    int do_time = (argc>2 && atoi(argv[2])==1);
    size_t elems = (size_t)N*d;
    float *hqf=(float*)malloc(elems*4), *hkf=(float*)malloc(elems*4), *hvf=(float*)malloc(elems*4);
    __half *hq=(__half*)malloc(elems*2), *hk=(__half*)malloc(elems*2), *hv=(__half*)malloc(elems*2);
    __half *ho=(__half*)malloc(elems*2);
    double *ref=(double*)malloc(elems*8);
    for(size_t i=0;i<elems;++i){ hq[i]=__float2half(lcg_f32()*4.0f); hqf[i]=__half2float(hq[i]); }
    for(size_t i=0;i<elems;++i){ hk[i]=__float2half(lcg_f32()*4.0f); hkf[i]=__half2float(hk[i]); }
    for(size_t i=0;i<elems;++i){ hv[i]=__float2half(lcg_f32());      hvf[i]=__half2float(hv[i]); }
    float scale = 1.0f/sqrtf((float)d);

    double *srow=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){
        double m=-1e300;
        for(int j=0;j<N;++j){ double s=0; for(int l=0;l<d;++l) s+=(double)hqf[(size_t)i*d+l]*(double)hkf[(size_t)j*d+l];
            s*=(double)scale; srow[j]=s; if(s>m)m=s; }
        double sum=0; for(int j=0;j<N;++j){ srow[j]=exp(srow[j]-m); sum+=srow[j]; }
        double inv=1.0/sum;
        for(int e=0;e<d;++e){ double acc=0; for(int j=0;j<N;++j) acc+=srow[j]*(double)hvf[(size_t)j*d+e];
            ref[(size_t)i*d+e]=acc*inv; }
    }
    free(srow);

    __half *dq,*dk,*dv,*dO;
    CK(cudaMalloc(&dq,elems*2)); CK(cudaMalloc(&dk,elems*2));
    CK(cudaMalloc(&dv,elems*2)); CK(cudaMalloc(&dO,elems*2));
    CK(cudaMemcpy(dq,hq,elems*2,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dk,hk,elems*2,cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dv,hv,elems*2,cudaMemcpyHostToDevice));

    int grid = (N + BQ - 1) / BQ;
    int block = WARPS*32;
    fa_mw<<<grid, block>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(ho,dO,elems*2,cudaMemcpyDeviceToHost));

    double *rowmax=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int e=0;e<d;++e){ double w=fabs(ref[(size_t)i*d+e]); if(w>mx)mx=w; } rowmax[i]=mx; }
    double max_abs=0,max_rel_rowscale=0,sse=0,ssref=0;
    for(size_t i=0;i<elems;++i){
        double got=(double)__half2float(ho[i]); double want=ref[i];
        double a=fabs(got-want); if(a>max_abs)max_abs=a;
        int row=(int)(i/d); double rr=a/(rowmax[row]+1e-9); if(rr>max_rel_rowscale)max_rel_rowscale=rr;
        sse+=a*a; ssref+=want*want;
    }
    double rms_rel=sqrt(sse/(ssref+1e-30));
    int pass=(max_rel_rowscale<=1e-2);
    printf("MW WARPS=%d BQ=%d N=%d grid=%d(vs48SM) max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g numeric=%s",
        WARPS,BQ,N,grid,max_abs,max_rel_rowscale,rms_rel,pass?"PASS":"FAIL");

    if (do_time) {
        cudaEvent_t st,en; cudaEventCreate(&st); cudaEventCreate(&en);
        for(int w=0;w<20;++w) fa_mw<<<grid,block>>>(dq,dk,dv,dO,N,scale);
        cudaDeviceSynchronize();
        int reps=200; double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){ cudaEventRecord(st,0); fa_mw<<<grid,block>>>(dq,dk,dv,dO,N,scale);
            cudaEventRecord(en,0); cudaEventSynchronize(en); float t; cudaEventElapsedTime(&t,st,en); ms[r]=t; }
        qsort(ms,reps,8,cmpd);
        printf(" median_ms=%.6f", ms[reps/2]);
    }
    printf("\n");
    return pass?0:1;
}
