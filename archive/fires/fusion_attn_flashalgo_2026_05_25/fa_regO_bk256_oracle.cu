/* Round-8b: FlashAttention-2 reg-O + WIDE-KV (BK=256) combo.
 *
 * Combines the round-4 lever (BK=256 = 16 wmma key-subtiles per online-softmax
 * round; amortizes per-row softmax cost) with the round-8a lever (O accumulator
 * register-resident across the K/V loop; eliminates the per-tile smem rescale
 * round-trip).
 *
 * 1 warp / CTA, BM=16, BK=256, BKT=16 (16 inner key sub-tiles per softmax round),
 * d=64, grid=N/16. N must be a multiple of BK=256.
 *
 * Smem (vs round-4 28864 B): no o_tile (saves 4096 B) -> 24768 B/CTA
 *   s_tile : 16*256 f32 = 16384 B
 *   p_tile : 16*256 f16 =  8192 B
 *   m/l/c  : 3*16 f32   =   192 B
 *
 * Build: nvcc -O2 -arch=sm_90a -o fa_regO_bk256 fa_regO_bk256_oracle.cu
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

/* m16n16k16 f32 acc row map (verified by frag_probe.cu):
 *   elems {0,1,4,5} -> row = lane/4
 *   elems {2,3,6,7} -> row = lane/4 + 8
 */
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

#define BK 256
#define BKT 16   /* = BK/16 -- 16 wmma key sub-tiles per softmax round */

__global__ void fa_regO_bk256(const __half* q, const __half* k, const __half* v,
                              __half* o, int N, float scale) {
    __shared__ float s_tile[16*BK];   // QK^T scores [BM=16, BK=256] f32
    __shared__ __half p_tile[16*BK];  // softmax probs [16, 256] f16
    __shared__ float m_vec[16], l_vec[16], c_vec[16];

    int lane = threadIdx.x & 31;
    int qrow_base = blockIdx.x * 16;
    const __half* qb = q + (size_t)qrow_base * 64;

    if (lane < 16) { m_vec[lane] = -INFINITY; l_vec[lane] = 0.0f; }
    __syncwarp();

    // 4 O accumulator fragments, one per d-tile of 16 cols, kept in regs
    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[4];
    #pragma unroll
    for (int t = 0; t < 4; ++t) wmma::fill_fragment(oacc[t], 0.0f);

    int n_rounds = N / BK;
    for (int round = 0; round < n_rounds; ++round) {
        int krow_base = round * BK;
        const __half* kb = k + (size_t)krow_base * 64;
        const __half* vb = v + (size_t)krow_base * 64;

        // ===== QK^T big row: compute S[16 x 256] via BKT=16 sub-tiles =====
        // For each sub-tile j (col 16*j .. 16*j+15), do a 16x16 wmma over d=64.
        // S sub-tile stored into s_tile[: , 16*j : 16*j+16] (stride=BK=256).
        wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a_frag;
        for (int j = 0; j < BKT; ++j) {
            wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
            wmma::fill_fragment(s_frag, 0.0f);
            #pragma unroll
            for (int kk = 0; kk < 4; ++kk) {
                wmma::load_matrix_sync(a_frag, qb + kk*16, 64);
                wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b_frag;
                wmma::load_matrix_sync(b_frag, kb + (j*16)*64 + kk*16, 64);
                wmma::mma_sync(s_frag, a_frag, b_frag, s_frag);
            }
            #pragma unroll
            for (int i = 0; i < s_frag.num_elements; ++i) s_frag.x[i] *= scale;
            // store this 16x16 sub-tile into s_tile at column offset j*16, row-major stride=BK
            wmma::store_matrix_sync(s_tile + j*16, s_frag, BK, wmma::mem_row_major);
        }
        __syncwarp();

        // ===== online softmax across full BK=256 row =====
        if (lane < 16) {
            int i = lane;
            float s_max = -INFINITY;
            #pragma unroll 16
            for (int j = 0; j < BK; ++j) s_max = fmaxf(s_max, s_tile[i*BK+j]);
            float m_prev = m_vec[i];
            float m_new = fmaxf(m_prev, s_max);
            float c = __expf(m_prev - m_new);
            c_vec[i] = c;
            float row_sum = 0.0f;
            #pragma unroll 16
            for (int j = 0; j < BK; ++j) {
                float p = __expf(s_tile[i*BK+j] - m_new);
                row_sum += p;
                p_tile[i*BK+j] = __float2half(p);
            }
            l_vec[i] = l_vec[i]*c + row_sum;
            m_vec[i] = m_new;
        }
        __syncwarp();

        // ===== rescale running O fragments by c -- in regs =====
        #pragma unroll
        for (int t = 0; t < 4; ++t) scale_frag_rows(oacc[t], c_vec, lane);

        // ===== P[16x256] . V[256x64] accumulated into oacc[t] (16 K-sub-tiles) =====
        // For each key sub-tile j: load P[:, 16*j:16*j+16] (stride=BK=256)
        // and V_sub[16*j:16*j+16, :] (stride=64).
        // For each d-tile t: load V[16*j:16*j+16, 16*t:16*t+16] -> b_frag, mma into oacc[t].
        for (int j = 0; j < BKT; ++j) {
            wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_frag;
            wmma::load_matrix_sync(pa_frag, p_tile + j*16, BK);
            const __half* vbj = vb + (size_t)(j*16)*64;
            #pragma unroll
            for (int t = 0; t < 4; ++t) {
                wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vb_frag;
                wmma::load_matrix_sync(vb_frag, vbj + t*16, 64);
                wmma::mma_sync(oacc[t], pa_frag, vb_frag, oacc[t]);
            }
        }
        __syncwarp();
    }

    // ===== finalize: divide each row by l[i], store to global =====
    if (lane < 16) c_vec[lane] = 1.0f / l_vec[lane];
    __syncwarp();
    #pragma unroll
    for (int t = 0; t < 4; ++t) {
        scale_frag_rows(oacc[t], c_vec, lane);
        wmma::store_matrix_sync(s_tile, oacc[t], 16, wmma::mem_row_major);
        __syncwarp();
        if (lane < 16) {
            int i = lane; int row = qrow_base + i;
            if (row < N) {
                #pragma unroll
                for (int e = 0; e < 16; ++e)
                    o[(size_t)row*64 + t*16 + e] = __float2half(s_tile[i*16+e]);
            }
        }
        __syncwarp();
    }
}

/* ---- host driver ---- */
static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void){ lcg_state=lcg_state*1664525u+1013904223u;
    return ((float)(lcg_state>>8)/(float)(1u<<24))-0.5f; }
static int cmpd(const void*a,const void*b){ double x=*(const double*)a,y=*(const double*)b;
    return (x<y)?-1:(x>y)?1:0; }

int main(int argc, char** argv){
    int N=(argc>1)?atoi(argv[1]):512; int d=64; int do_time=(argc>2&&atoi(argv[2])==1);
    if (N % 256 != 0) { fprintf(stderr,"N must be multiple of 256 (BK)\n"); return 2; }
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
    int grid=N/16, block=32;
    fa_regO_bk256<<<grid,block>>>(dq,dk,dv,dO,N,scale);
    CK(cudaDeviceSynchronize()); CK(cudaMemcpy(ho,dO,elems*2,cudaMemcpyDeviceToHost));
    double *rowmax=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int e=0;e<d;++e){ double w=fabs(ref[(size_t)i*d+e]); if(w>mx)mx=w; } rowmax[i]=mx; }
    double max_abs=0,rel_rs=0,sse=0,ssref=0;
    for(size_t i=0;i<elems;++i){ double got=(double)__half2float(ho[i]),want=ref[i],a=fabs(got-want);
        if(a>max_abs)max_abs=a; int row=(int)(i/d); double rr=a/(rowmax[row]+1e-9); if(rr>rel_rs)rel_rs=rr; sse+=a*a; ssref+=want*want; }
    double rms=sqrt(sse/(ssref+1e-30)); int pass=(rel_rs<=1e-2);
    printf("regOv2_bk256 N=%d grid=%d(vs48SM) max_abs=%.4g rel_rowscale=%.4g rms_rel=%.4g numeric=%s",N,grid,max_abs,rel_rs,rms,pass?"PASS":"FAIL");
    if(do_time){ cudaEvent_t st,en; cudaEventCreate(&st); cudaEventCreate(&en);
        for(int w=0;w<20;++w) fa_regO_bk256<<<grid,block>>>(dq,dk,dv,dO,N,scale); cudaDeviceSynchronize();
        int reps=200; double *ms=(double*)malloc(reps*8);
        for(int r=0;r<reps;++r){ cudaEventRecord(st,0); fa_regO_bk256<<<grid,block>>>(dq,dk,dv,dO,N,scale); cudaEventRecord(en,0); cudaEventSynchronize(en); float t; cudaEventElapsedTime(&t,st,en); ms[r]=t; }
        qsort(ms,reps,8,cmpd); printf(" median_ms=%.6f",ms[reps/2]); }
    printf("\n"); return pass?0:1;
}
