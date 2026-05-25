/* Algorithm oracle for the round-3 flash-attention design, written in CUDA-C
 * nvcuda::wmma (NOT the shipped kernel -- a correctness validator only).
 * Replicates EXACTLY the round-3 PTX algorithm: 1 warp / CTA, BM=BN=16, d=64,
 * grid = N/16, online softmax, S tile in shared, both inner GEMMs on Tensor
 * Cores, O accumulator in shared with per-tile rescale-by-c. If THIS passes
 * numeric vs f64 ref, the algorithm is correct and the round-3 bug is in the
 * hand-PTX fragment handling. If it FAILS too, the algorithm itself is wrong.
 *
 * Build: nvcc -O2 -arch=sm_90a -o fa_wmma_oracle fa_wmma_oracle.cu -lcuda
 * (-arch sm_90a then JIT to sm_120 at load, or build sm_120 directly)
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

/* one warp per CTA, BM=BN=16, d=64 -- exact round-3 design */
__global__ void fa_oracle(const __half* q, const __half* k, const __half* v,
                          __half* o, int N, float scale) {
    __shared__ float s_tile[16*16];   // QK^T scores / scratch
    __shared__ __half p_tile[16*16];  // softmax probs (f16 for wmma A)
    __shared__ float o_tile[16*64];   // running O accumulator
    __shared__ float m_vec[16], l_vec[16], c_vec[16];

    int lane = threadIdx.x & 31;
    int qrow_base = blockIdx.x * 16;
    const __half* qb = q + (size_t)qrow_base * 64;

    // init
    if (lane < 16) {
        m_vec[lane] = -INFINITY; l_vec[lane] = 0.0f;
        for (int e = 0; e < 64; ++e) o_tile[lane*64+e] = 0.0f;
    }
    __syncthreads();

    int n_tiles = N >> 4;
    for (int kt = 0; kt < n_tiles; ++kt) {
        int krow_base = kt * 16;
        const __half* kb = k + (size_t)krow_base * 64;
        const __half* vb = v + (size_t)krow_base * 64;

        // ===== QK^T (TC) : S[16x16] = Q . K^T over d=64 =====
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a_frag;
        wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b_frag;
        wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
        wmma::fill_fragment(s_frag, 0.0f);
        for (int kk = 0; kk < 4; ++kk) {
            wmma::load_matrix_sync(a_frag, qb + kk*16, 64);
            wmma::load_matrix_sync(b_frag, kb + kk*16, 64);
            wmma::mma_sync(s_frag, a_frag, b_frag, s_frag);
        }
        for (int i = 0; i < s_frag.num_elements; ++i) s_frag.x[i] *= scale;
        wmma::store_matrix_sync(s_tile, s_frag, 16, wmma::mem_row_major);
        __syncthreads();

        // ===== online softmax on S tile in shared =====
        if (lane < 16) {
            int i = lane;
            float s_max = -INFINITY;
            for (int j = 0; j < 16; ++j) s_max = fmaxf(s_max, s_tile[i*16+j]);
            float m_prev = m_vec[i];
            float m_new = fmaxf(m_prev, s_max);
            float c = __expf(m_prev - m_new);
            c_vec[i] = c;
            float row_sum = 0.0f;
            for (int j = 0; j < 16; ++j) {
                float p = __expf(s_tile[i*16+j] - m_new);
                row_sum += p;
                p_tile[i*16+j] = __float2half(p);
            }
            l_vec[i] = l_vec[i]*c + row_sum;
            m_vec[i] = m_new;
        }
        __syncthreads();

        // ===== rescale running O by c =====
        if (lane < 16) {
            int i = lane; float c = c_vec[i];
            for (int e = 0; e < 64; ++e) o_tile[i*64+e] *= c;
        }
        __syncthreads();

        // ===== P.V (TC) : O_partial[16x64] = P[16x16] . V[16x64], 4 N-tiles =====
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_frag;
        wmma::load_matrix_sync(pa_frag, p_tile, 16);
        for (int t = 0; t < 4; ++t) {
            wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vb_frag;
            wmma::fragment<wmma::accumulator,16,16,16,float> op_frag;
            wmma::fill_fragment(op_frag, 0.0f);
            wmma::load_matrix_sync(vb_frag, vb + t*16, 64);
            wmma::mma_sync(op_frag, pa_frag, vb_frag, op_frag);
            wmma::store_matrix_sync(s_tile, op_frag, 16, wmma::mem_row_major);
            __syncthreads();
            if (lane < 16) {
                int i = lane;
                for (int e = 0; e < 16; ++e)
                    o_tile[i*64 + t*16 + e] += s_tile[i*16+e];
            }
            __syncthreads();
        }
    }

    // finalize O[i][:] = o_tile[i][:] / l[i]
    if (lane < 16) {
        int i = lane; int row = qrow_base + i;
        if (row < N) {
            float inv = 1.0f / l_vec[i];
            for (int e = 0; e < 64; ++e)
                o[(size_t)row*64+e] = __float2half(o_tile[i*64+e] * inv);
        }
    }
}

static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void){ lcg_state=lcg_state*1664525u+1013904223u;
    return ((float)(lcg_state>>8)/(float)(1u<<24))-0.5f; }

int main(int argc, char** argv){
    int N = (argc>1)?atoi(argv[1]):512;
    int d = 64;
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

    fa_oracle<<<N/16, 32>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(ho,dO,elems*2,cudaMemcpyDeviceToHost));

    /* metrics: (1) max_abs (2) max_rel naive eps=1e-6 (3) per-element rel
     * relative to the per-ROW output magnitude (the meaningful attention
     * error scale) (4) global RMS rel. Near-zero outputs make naive max_rel
     * blow up; the row-scaled rel is the honest flash-attention metric. */
    double max_rel=0, max_abs=0, max_rel_rowscale=0;
    double sse=0, ssref=0;
    /* per-row max |ref| */
    double *rowmax=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int e=0;e<d;++e){ double w=fabs(ref[(size_t)i*d+e]); if(w>mx)mx=w; } rowmax[i]=mx; }
    for(size_t i=0;i<elems;++i){
        double got=(double)__half2float(ho[i]); double want=ref[i];
        double a=fabs(got-want); double r=a/(fabs(want)+1e-6);
        if(a>max_abs)max_abs=a; if(r>max_rel)max_rel=r;
        int row=(int)(i/d);
        double rr = a/(rowmax[row]+1e-9);
        if(rr>max_rel_rowscale)max_rel_rowscale=rr;
        sse += a*a; ssref += want*want;
    }
    double rms_rel = sqrt(sse/(ssref+1e-30));
    printf("ORACLE(cuda-c wmma) N=%d d=%d max_abs=%.6g max_rel_naive=%.6g max_rel_rowscale=%.6g rms_rel=%.6g numeric=%s\n",
        N,d,max_abs,max_rel,max_rel_rowscale,rms_rel,(max_rel_rowscale<=1e-2)?"PASS":"FAIL");
    return (max_rel_rowscale<=1e-2)?0:1;
}
