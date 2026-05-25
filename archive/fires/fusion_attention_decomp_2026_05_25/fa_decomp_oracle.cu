/* F-FUSION-ATTN-DECOMP-WALL -- KV-split (flash-decoding) decomposition oracle.
 *
 * Round-5 of the GPU sec10 GEMM-fusion (attention) axis. The round-4 winner was
 * a single-warp wide-KV WMMA flash-attention (Bq=16, BK=256, grid=N/16). At
 * small N (512) the grid is only 32 CTAs < 48 SMs => under-occupied. This oracle
 * SPLITS the KV dimension across CTAs (flash-decoding):
 *
 *   grid.z = KV_SPLIT chunks. Each (qblock, z) CTA does a PARTIAL attention over
 *   its KV slice [z*chunk, (z+1)*chunk), emitting un-normalized partial O plus
 *   per-row running m (max) and l (sum) into a [N x KV_SPLIT x d] / [N x KV_SPLIT]
 *   scratch. A 2nd MERGE kernel combines partials across z via the flash-decoding
 *   log-sum-exp merge:  m* = max_z m_z ;  l* = sum_z l_z*exp(m_z-m*) ;
 *   O* = (sum_z exp(m_z-m*) * O_z) / l*    (O_z is the un-normalized accumulator).
 *
 * grid.x = N/Bq query blocks; Bq query rows per CTA (one 16-row WMMA tile per
 * 16 rows, so Bq in {16,32,64} = 1..4 warps' worth of 16-row sub-tiles, but we
 * keep ONE warp/CTA and loop the sub-tiles -- the round-4 multi-warp axis is
 * CLOSED). BK = KV tile width within a CTA's slice (round-4 found 256 best).
 *
 * This is a CUDA-C nvcuda::wmma ORACLE: it measures the ALGORITHMIC wall of the
 * decomposition (does KV-split close the small-N occupancy gap?) at the CUDA-C
 * floor level. Round-4 established the hand-PTX path sits a ~constant factor
 * above the CUDA-C floor (3.4-5.0x vs 1.3-2.0x); the DECOMPOSITION question is
 * purely algorithmic and is answered here. Numeric PASS (rel_rowscale<=1e-2 vs
 * f64 CPU ref, the honest per-row-scaled metric) gates every config.
 *
 * Build: nvcc -O2 -arch=sm_90a -o fa_decomp_oracle fa_decomp_oracle.cu -lcuda
 *   (sm_90a builds + JITs to sm_120 at load; or -arch=sm_120 directly)
 * Run:   ./fa_decomp_oracle N Bq KV_SPLIT BK    (d fixed = 64)
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

/* Max BK supported by static smem layout: BK=256 needs s_tile 16x256 f32 =
 * 16384 B + p_tile 16x256 f16 = 8192 B + o_tile 16x64 f32 = 4096 B = 28672 B
 * (round-4 measured 28864 with the m/l/c vectors). BK is a #define-time cap via
 * the static array; the kernel uses the runtime bk argument up to BKMAX. */
#define BKMAX 256
#define DHEAD 64

/* ===== PARTIAL kernel: one 16-row WMMA sub-tile per outer i-loop, one warp/CTA.
 * Bq query rows / CTA  => Bq/16 sub-tiles processed serially. KV slice for this
 * z = [z*kv_chunk, z*kv_chunk + kv_chunk).  Writes un-normalized O + m + l. */
__global__ void fa_partial(const __half* q, const __half* k, const __half* v,
                           float* Opart, float* Mpart, float* Lpart,
                           int N, float scale, int Bq, int bk, int kv_split) {
    __shared__ float  s_tile[16*BKMAX];   // QK^T scores / scratch
    __shared__ __half p_tile[16*BKMAX];   // softmax probs (f16 for wmma A)
    __shared__ float  o_tile[16*DHEAD];   // running (un-normalized) O accumulator
    __shared__ float  m_vec[16], l_vec[16], c_vec[16];

    int lane = threadIdx.x & 31;
    int z = blockIdx.z;
    int kv_chunk = N / kv_split;             // N divisible by kv_split (enforced host-side)
    int kv_lo = z * kv_chunk;
    int kv_hi = kv_lo + kv_chunk;

    int sub_per_cta = Bq / 16;
    for (int sub = 0; sub < sub_per_cta; ++sub) {
        int qrow_base = blockIdx.x * Bq + sub * 16;
        if (qrow_base >= N) break;
        const __half* qb = q + (size_t)qrow_base * DHEAD;

        if (lane < 16) {
            m_vec[lane] = -INFINITY; l_vec[lane] = 0.0f;
            for (int e = 0; e < DHEAD; ++e) o_tile[lane*DHEAD+e] = 0.0f;
        }
        __syncthreads();

        /* iterate KV tiles of width bk inside this z-slice */
        for (int kt0 = kv_lo; kt0 < kv_hi; kt0 += bk) {
            int tile_w = (kt0 + bk <= kv_hi) ? bk : (kv_hi - kt0);
            int n_sub  = tile_w >> 4;        // 16-key sub-tiles in this KV tile

            /* ===== QK^T (TC): S[16 x tile_w], 16-key sub-tiles ===== */
            for (int ns = 0; ns < n_sub; ++ns) {
                int krow_base = kt0 + ns*16;
                const __half* kb = k + (size_t)krow_base * DHEAD;
                wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> a_frag;
                wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> b_frag;
                wmma::fragment<wmma::accumulator,16,16,16,float> s_frag;
                wmma::fill_fragment(s_frag, 0.0f);
                for (int kk = 0; kk < 4; ++kk) {       // d=64 -> 4 k-steps of 16
                    wmma::load_matrix_sync(a_frag, qb + kk*16, DHEAD);
                    wmma::load_matrix_sync(b_frag, kb + kk*16, DHEAD);
                    wmma::mma_sync(s_frag, a_frag, b_frag, s_frag);
                }
                for (int i = 0; i < s_frag.num_elements; ++i) s_frag.x[i] *= scale;
                wmma::store_matrix_sync(s_tile + ns*16, s_frag, bk, wmma::mem_row_major);
            }
            __syncthreads();

            /* ===== online softmax over the whole tile_w-wide S row ===== */
            if (lane < 16) {
                int i = lane;
                float s_max = -INFINITY;
                for (int j = 0; j < tile_w; ++j) s_max = fmaxf(s_max, s_tile[i*bk+j]);
                float m_prev = m_vec[i];
                float m_new  = fmaxf(m_prev, s_max);
                float c = __expf(m_prev - m_new);
                c_vec[i] = c;
                float row_sum = 0.0f;
                for (int j = 0; j < tile_w; ++j) {
                    float p = __expf(s_tile[i*bk+j] - m_new);
                    row_sum += p;
                    p_tile[i*bk+j] = __float2half(p);
                }
                l_vec[i] = l_vec[i]*c + row_sum;
                m_vec[i] = m_new;
            }
            __syncthreads();

            /* ===== rescale running O by c ===== */
            if (lane < 16) {
                int i = lane; float c = c_vec[i];
                for (int e = 0; e < DHEAD; ++e) o_tile[i*DHEAD+e] *= c;
            }
            __syncthreads();

            /* ===== P.V (TC): O += P[16 x tile_w] . V[tile_w x 64] ===== */
            for (int ns = 0; ns < n_sub; ++ns) {
                int krow_base = kt0 + ns*16;
                const __half* vb = v + (size_t)krow_base * DHEAD;
                wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa_frag;
                wmma::load_matrix_sync(pa_frag, p_tile + ns*16, bk);
                for (int t = 0; t < 4; ++t) {       // d=64 -> 4 output 16-col tiles
                    wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::row_major> vbf;
                    wmma::fragment<wmma::accumulator,16,16,16,float> opf;
                    wmma::fill_fragment(opf, 0.0f);
                    wmma::load_matrix_sync(vbf, vb + t*16, DHEAD);
                    wmma::mma_sync(opf, pa_frag, vbf, opf);
                    wmma::store_matrix_sync(s_tile, opf, 16, wmma::mem_row_major);
                    __syncthreads();
                    if (lane < 16) {
                        int i = lane;
                        for (int e = 0; e < 16; ++e)
                            o_tile[i*DHEAD + t*16 + e] += s_tile[i*16+e];
                    }
                    __syncthreads();
                }
            }
        }

        /* ===== write un-normalized partial O + m + l for this (row, z) ===== */
        if (lane < 16) {
            int i = lane; int row = qrow_base + i;
            if (row < N) {
                size_t pbase = ((size_t)row * kv_split + z) * DHEAD;
                for (int e = 0; e < DHEAD; ++e) Opart[pbase + e] = o_tile[i*DHEAD+e];
                Mpart[(size_t)row*kv_split + z] = m_vec[i];
                Lpart[(size_t)row*kv_split + z] = l_vec[i];
            }
        }
        __syncthreads();
    }
}

/* ===== MERGE kernel: per output row, LSE-merge the kv_split partials =====
 * one warp/CTA, 16 rows/CTA (grid = N/16). Lane i (<16) owns row. */
__global__ void fa_merge(const float* Opart, const float* Mpart, const float* Lpart,
                         __half* o, int N, int kv_split) {
    int lane = threadIdx.x & 31;
    if (lane >= 16) return;
    int row = blockIdx.x * 16 + lane;
    if (row >= N) return;

    /* global max over splits */
    float m_star = -INFINITY;
    for (int z = 0; z < kv_split; ++z) {
        float mz = Mpart[(size_t)row*kv_split + z];
        m_star = fmaxf(m_star, mz);
    }
    /* l* = sum_z l_z * exp(m_z - m*) */
    float l_star = 0.0f;
    for (int z = 0; z < kv_split; ++z) {
        float mz = Mpart[(size_t)row*kv_split + z];
        float lz = Lpart[(size_t)row*kv_split + z];
        l_star += lz * __expf(mz - m_star);
    }
    float inv = 1.0f / l_star;
    /* O* = (sum_z exp(m_z-m*) * O_z) * inv  (O_z un-normalized) */
    for (int e = 0; e < DHEAD; ++e) {
        float acc = 0.0f;
        for (int z = 0; z < kv_split; ++z) {
            float mz = Mpart[(size_t)row*kv_split + z];
            float w  = __expf(mz - m_star);
            acc += w * Opart[((size_t)row*kv_split + z)*DHEAD + e];
        }
        o[(size_t)row*DHEAD + e] = __float2half(acc * inv);
    }
}

static int cmp_double(const void *a, const void *b){
    double x=*(const double*)a, y=*(const double*)b; return (x<y)?-1:(x>y)?1:0; }
static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void){ lcg_state=lcg_state*1664525u+1013904223u;
    return ((float)(lcg_state>>8)/(float)(1u<<24))-0.5f; }

int main(int argc, char** argv){
    int N        = (argc>1)?atoi(argv[1]):512;
    int Bq       = (argc>2)?atoi(argv[2]):16;
    int kv_split = (argc>3)?atoi(argv[3]):1;
    int bk       = (argc>4)?atoi(argv[4]):256;
    int d = DHEAD;

    if (N % 16 != 0)       { fprintf(stderr,"N must be mult of 16\n"); return 2; }
    if (Bq % 16 != 0)      { fprintf(stderr,"Bq must be mult of 16\n"); return 2; }
    if (N % kv_split != 0) { fprintf(stderr,"N must be divisible by kv_split\n"); return 2; }
    int kv_chunk = N / kv_split;
    if (kv_chunk % 16 != 0){ fprintf(stderr,"kv_chunk (N/kv_split) must be mult of 16\n"); return 2; }
    if (bk > BKMAX)        { bk = BKMAX; }
    if (bk % 16 != 0)      { fprintf(stderr,"bk must be mult of 16\n"); return 2; }
    /* clamp bk to the chunk so we never read across the slice boundary */
    if (bk > kv_chunk) bk = kv_chunk;

    size_t elems = (size_t)N*d;
    float *hqf=(float*)malloc(elems*4), *hkf=(float*)malloc(elems*4), *hvf=(float*)malloc(elems*4);
    __half *hq=(__half*)malloc(elems*2), *hk=(__half*)malloc(elems*2), *hv=(__half*)malloc(elems*2);
    __half *ho=(__half*)malloc(elems*2);
    double *ref=(double*)malloc(elems*8);
    for(size_t i=0;i<elems;++i){ hq[i]=__float2half(lcg_f32()*4.0f); hqf[i]=__half2float(hq[i]); }
    for(size_t i=0;i<elems;++i){ hk[i]=__float2half(lcg_f32()*4.0f); hkf[i]=__half2float(hk[i]); }
    for(size_t i=0;i<elems;++i){ hv[i]=__float2half(lcg_f32());      hvf[i]=__half2float(hv[i]); }
    float scale = 1.0f/sqrtf((float)d);

    /* f64 CPU reference on the f16-rounded inputs */
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

    float *dOpart,*dMpart,*dLpart;
    CK(cudaMalloc(&dOpart, (size_t)N*kv_split*d*4));
    CK(cudaMalloc(&dMpart, (size_t)N*kv_split*4));
    CK(cudaMalloc(&dLpart, (size_t)N*kv_split*4));

    dim3 grid((N + Bq - 1)/Bq, 1, kv_split);
    dim3 block(32,1,1);
    unsigned ctas_partial = grid.x * grid.z;
    unsigned ctas_merge   = (unsigned)((N+15)/16);

    /* correctness: one full launch pair */
    fa_partial<<<grid, block>>>(dq,dk,dv,dOpart,dMpart,dLpart,N,scale,Bq,bk,kv_split);
    CK(cudaGetLastError());
    fa_merge<<<ctas_merge, 32>>>(dOpart,dMpart,dLpart,dO,N,kv_split);
    CK(cudaGetLastError());
    CK(cudaDeviceSynchronize());
    CK(cudaMemcpy(ho,dO,elems*2,cudaMemcpyDeviceToHost));

    /* honest per-row-scaled + RMS metric */
    double *rowmax=(double*)malloc((size_t)N*8);
    for(int i=0;i<N;++i){ double mx=0; for(int e=0;e<d;++e){ double w=fabs(ref[(size_t)i*d+e]); if(w>mx)mx=w; } rowmax[i]=mx; }
    double max_rel=0, max_abs=0, max_rel_rowscale=0, sse=0, ssref=0;
    for(size_t i=0;i<elems;++i){
        double got=(double)__half2float(ho[i]); double want=ref[i];
        double a=fabs(got-want); double r=a/(fabs(want)+1e-6);
        if(a>max_abs)max_abs=a; if(r>max_rel)max_rel=r;
        int row=(int)(i/d);
        double rr=a/(rowmax[row]+1e-9);
        if(rr>max_rel_rowscale)max_rel_rowscale=rr;
        sse+=a*a; ssref+=want*want;
    }
    double rms_rel=sqrt(sse/(ssref+1e-30));
    int numeric_pass=(max_rel_rowscale<=1e-2);
    printf("DECOMP N=%d Bq=%d kvsplit=%d bk=%d  ctas_partial=%u ctas_merge=%u (vs 48 SMs)  "
           "max_abs=%.6g rel_rowscale=%.6g rms_rel=%.6g numeric=%s\n",
           N,Bq,kv_split,bk,ctas_partial,ctas_merge,max_abs,max_rel_rowscale,rms_rel,
           numeric_pass?"PASS":"FAIL");

    /* timed wall: 20 warmup + 200 timed median of the PARTIAL+MERGE pair */
    cudaEvent_t st,en; CK(cudaEventCreate(&st)); CK(cudaEventCreate(&en));
    for(int w=0;w<20;++w){
        fa_partial<<<grid, block>>>(dq,dk,dv,dOpart,dMpart,dLpart,N,scale,Bq,bk,kv_split);
        fa_merge<<<ctas_merge, 32>>>(dOpart,dMpart,dLpart,dO,N,kv_split);
    }
    CK(cudaDeviceSynchronize());
    int reps=200; double *ms=(double*)malloc(reps*8);
    for(int r=0;r<reps;++r){
        CK(cudaEventRecord(st,0));
        fa_partial<<<grid, block>>>(dq,dk,dv,dOpart,dMpart,dLpart,N,scale,Bq,bk,kv_split);
        fa_merge<<<ctas_merge, 32>>>(dOpart,dMpart,dLpart,dO,N,kv_split);
        CK(cudaEventRecord(en,0));
        CK(cudaEventSynchronize(en));
        float t; CK(cudaEventElapsedTime(&t,st,en)); ms[r]=(double)t;
    }
    qsort(ms,reps,sizeof(double),cmp_double);
    printf("DECOMP_WALL N=%d Bq=%d kvsplit=%d bk=%d fused_ms=%.6f numeric=%s\n",
           N,Bq,kv_split,bk,ms[reps/2],numeric_pass?"PASS":"FAIL");

    cudaFree(dq);cudaFree(dk);cudaFree(dv);cudaFree(dO);
    cudaFree(dOpart);cudaFree(dMpart);cudaFree(dLpart);
    return numeric_pass?0:1;
}
