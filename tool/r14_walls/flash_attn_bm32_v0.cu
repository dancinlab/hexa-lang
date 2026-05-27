/* BC4 round-14 kernel — flash_attn_bm32_occupancy_v0
 *
 * Pre-registered falsifier: F-FUSION-ATTN-BM32-OCCUPANCY-WALL
 *   (docs/notes/bc4-attention-smem-residency-wedge-plan-2026-05-28.md §6)
 *
 * Geometry (plan §3 + §4):
 *   BM = 32 query rows per CTA
 *   BK = 32 key/value rows per online-softmax round
 *   d  = 64 head dim (fp16 K/V/Q; fp32 accumulators; fp32 O store)
 *   4 warps/CTA = 128 threads
 *   2 QUERY warps own 16 query rows each (warp 0 -> rows 0..15, warp 1 -> 16..31).
 *   All 4 warps cooperate in the cp.async K/V tile load (128 threads x 16B = 2048B
 *   per cp.async wave -> 2 waves to fill one 32x64x2 = 4096B tile).
 *
 * Smem layout (plan §2, total 30720 B / CTA -> 3 CTAs/SM at 102400 B opt-in):
 *     Q              : 32 * 64 * 2 =  4096 B (single)
 *     K (double-buf) : 2 * 32 * 64 * 2 = 8192 B
 *     V (double-buf) : 2 * 32 * 64 * 2 = 8192 B
 *     V^T (single)   : 32 * 64 * 2 =  4096 B    (pre-transpose target; risk-d)
 *     S  (fp32)      : 32 * 32 * 4 =  4096 B
 *     P  (fp16)      : 32 * 32 * 2 =  2048 B
 *     -------------------------------- + scratch ~  192 B (per-warp red_max/red_sum + o_dbg)
 *
 * Algorithm: standard flash-attention v2 online-softmax with
 *   1. Register-resident O accumulator (key innovation; ~16 fp32 regs/thread for BM=32 d=64).
 *   2. V pre-transpose in smem each K loop (risk-d GREEN: .trans + .row.col gives
 *      only 8x8-block transpose at BK=32; non-trans + pre-transposed sVt is required).
 *   3. cp.async.cg.shared.global K/V double-buffer (R10 lever 1.34-1.50x).
 *
 * Inherits from R10 (do NOT regress):
 *   - m16n16k16 fp32 accumulator row map: elems {0,1,4,5} -> row=lane/4 ;
 *     {2,3,6,7} -> row=lane/4+8 .
 *   - acc->matrix_a repack via local reg move pa.x[i]=pa.x[i+8]=acc.x[i] .
 *   - reg-S (QK^T in accumulator regs, no smem store) + reg-P
 *     + smem-SCRATCH per-warp row-reduce (NOT warp-shuffle; R9 ruled that out).
 *
 * Verifier: companion file fa_bm32_host.cu calls this kernel + computes f64 CPU ref.
 * Numeric PASS gate: per-row-scaled rel <= 1e-2, naninf=0 at N in {2048, 4096} d=64.
 * Occupancy gate: cuOccupancyMaxActiveBlocksPerMultiprocessor >= 3 (target).
 *
 * Build:  nvcc -O2 -arch=sm_120a -Xptxas=-v flash_attn_bm32_v0.cu -c
 *         nvcc -O2 -arch=sm_120a flash_attn_bm32_v0.cu fa_bm32_host.cu -o fa_bm32_host
 */
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <mma.h>
#include <stdio.h>
#include <stdint.h>
using namespace nvcuda;

#define NWARP   4
#define NWARP_Q 2          /* warps that own query rows (others only load) */
#define BM      32
#define BK      32
#define D       64
#define HALF_BYTES(n) ((n) * 2)

/* ---------------- cp.async helpers (sm_80+) ---------------- */
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

/* Load one 32x64 half tile (4096 B = 256 16B chunks) gmem -> smem via cp.async.
 * 128 threads -> 2 chunks each. Caller commits + waits. */
__device__ __forceinline__ void load_tile32x64_cpasync(__half* dst,
                                                       const __half* src,
                                                       int tid) {
    #pragma unroll
    for (int w = 0; w < 2; ++w) {
        int idx = w * 128 + tid;             /* 0..255 chunk index */
        cp_async_16(dst + idx * 8, src + idx * 8);
    }
}

/* Pre-transpose a 32x64 half tile residing at sV[k][n] (BK rows x D cols) into
 * sVt[n][k] (D rows x BK cols). All 128 threads cooperate; 32*64 = 2048 halves
 * = 16 halves/thread. */
__device__ __forceinline__ void pretranspose_v_to_smem(const __half* sV,
                                                       __half* sVt,
                                                       int tid) {
    #pragma unroll
    for (int e = 0; e < 16; ++e) {
        int i = e * 128 + tid;
        int k = i / D;               /* 0..31 row in sV */
        int n = i - k * D;           /* 0..63 col in sV */
        sVt[n * BK + k] = sV[k * D + n];
    }
}

/* Rescale O accumulator rows by per-row factor.
 * Row map of m16n16k16 fp32 accumulator on sm_80+:
 *   elems {0,1,4,5} -> row = lane/4
 *   elems {2,3,6,7} -> row = lane/4 + 8
 */
__device__ __forceinline__ void scale_o(
    wmma::fragment<wmma::accumulator,16,16,16,float>& f,
    float c_lo, float c_hi) {
    f.x[0]*=c_lo; f.x[1]*=c_lo; f.x[4]*=c_lo; f.x[5]*=c_lo;
    f.x[2]*=c_hi; f.x[3]*=c_hi; f.x[6]*=c_hi; f.x[7]*=c_hi;
}

/* ---------------- the kernel ---------------- */
extern "C" __global__ __launch_bounds__(128, 3)
void flash_attn_bm32_occupancy_v0(const __half* __restrict__ q,
                                  const __half* __restrict__ k,
                                  const __half* __restrict__ v,
                                  float* __restrict__ o,
                                  int N, float scale) {
    /* ----- smem layout (total ~ 30720 B + scratch) ----- */
    __shared__ __half q_sm[BM * D];                 /*  4096 B */
    __shared__ __half k_sm[2][BK * D];              /*  8192 B (double-buf) */
    __shared__ __half v_sm[2][BK * D];              /*  8192 B (double-buf) */
    __shared__ __half vt_sm[D * BK];                /*  4096 B (V^T, single) */
    /* per-warp row-reduce scratch (only query warps use these slots) */
    __shared__ float  red_max[NWARP_Q][16 * 4];     /*    512 B */
    __shared__ float  red_sum[NWARP_Q][16 * 4];     /*    512 B */
    /* shared scratch for register-O -> global store via row-major store_matrix_sync */
    __shared__ float  o_dbg [NWARP_Q][16 * 16];     /*   2048 B */

    int tid  = threadIdx.x;          /* 0..127 */
    int wid  = tid >> 5;             /* warp id 0..3 */
    int lane = tid & 31;

    int qrow_base = blockIdx.x * BM;             /* CTA's query-row base */
    const __half* qb = q + (size_t)qrow_base * D;

    /* ---- one-shot Q load (cp.async, 4096 B = 256 chunks of 16B, 128 thd * 2 chunks) ---- */
    #pragma unroll
    for (int w = 0; w < 2; ++w) {
        int idx = w * 128 + tid;
        if (idx < BM * D / 8) {                  /* 256 chunks */
            cp_async_16(q_sm + idx * 8, qb + idx * 8);
        }
    }
    cp_async_commit();

    /* ---- prologue: cp.async-prefetch K/V tile 0 into buffer 0 ---- */
    load_tile32x64_cpasync(k_sm[0], k, tid);
    load_tile32x64_cpasync(v_sm[0], v, tid);
    cp_async_commit();

    cp_async_wait<1>();                          /* Q now in smem */
    __syncthreads();

    /* Q resident in matrix_a fragments across the K loop (4 d-tiles).
     * Only query warps (0, 1) hold these; warps 2-3 just load + sync. */
    wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> qf[4];
    if (wid < NWARP_Q) {
        const __half* qbase = q_sm + wid * 16 * D;   /* warp's 16 query rows */
        #pragma unroll
        for (int kk = 0; kk < 4; ++kk) {
            wmma::load_matrix_sync(qf[kk], qbase + kk * 16, D);
        }
    }

    /* O accumulators (one per d-tile = 4 fragments), register-resident.
     * Each query warp holds 4 frags x 8 fp32 regs = 32 fp32 regs from O alone.
     * (matches plan section 4 estimate of 16 fp32/thread averaged over 4 warps:
     *  query warps carry 32; load-only warps 2-3 carry 0 -> mean 16.) */
    wmma::fragment<wmma::accumulator,16,16,16,float> oacc[4];
    if (wid < NWARP_Q) {
        #pragma unroll
        for (int t = 0; t < 4; ++t) wmma::fill_fragment(oacc[t], 0.0f);
    }

    float m_lo = -INFINITY, m_hi = -INFINITY, l_lo = 0.0f, l_hi = 0.0f;

    /* Number of BK-sized K/V tiles. */
    int n_tiles = N / BK;

    for (int kt = 0; kt < n_tiles; ++kt) {
        int cur = kt & 1, nxt = (kt + 1) & 1;

        /* prefetch NEXT tile async */
        if (kt + 1 < n_tiles) {
            const __half* kb_n = k + (size_t)((kt + 1) * BK) * D;
            const __half* vb_n = v + (size_t)((kt + 1) * BK) * D;
            load_tile32x64_cpasync(k_sm[nxt], kb_n, tid);
            load_tile32x64_cpasync(v_sm[nxt], vb_n, tid);
            cp_async_commit();
        }
        /* wait until CURRENT tile is in smem (keep NEXT outstanding) */
        if (kt + 1 < n_tiles) cp_async_wait<1>();
        else                  cp_async_wait<0>();
        __syncthreads();

        const __half* kb = k_sm[cur];
        const __half* vb = v_sm[cur];

        /* Pre-transpose V[cur] -> vt_sm (risk-d work-around at BK=32). */
        pretranspose_v_to_smem(vb, vt_sm, tid);
        __syncthreads();

        if (wid < NWARP_Q) {
            /* For this query warp, BK=32 keys split into 2 sub-tiles of 16 keys each.
             * Each sub-tile gives one S fragment (16 query rows x 16 keys). */

            /* ---- S = Q . K^T (two 16x16 fragments along the BK axis) ---- */
            wmma::fragment<wmma::accumulator,16,16,16,float> s_frag[2];
            #pragma unroll
            for (int n2 = 0; n2 < 2; ++n2) wmma::fill_fragment(s_frag[n2], 0.0f);

            #pragma unroll
            for (int kk = 0; kk < 4; ++kk) {
                /* d-stride load of K^T sub-tile: 16 keys x 16 d-cols, col_major
                 * gives the K^T frag. Two sub-tiles in n direction. */
                #pragma unroll
                for (int n2 = 0; n2 < 2; ++n2) {
                    wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> kf;
                    /* K rows [n2*16 .. n2*16+15], K cols [kk*16 .. kk*16+15] */
                    wmma::load_matrix_sync(kf, kb + n2 * 16 * D + kk * 16, D);
                    wmma::mma_sync(s_frag[n2], qf[kk], kf, s_frag[n2]);
                }
            }
            #pragma unroll
            for (int n2 = 0; n2 < 2; ++n2) {
                #pragma unroll
                for (int i = 0; i < 8; ++i) s_frag[n2].x[i] *= scale;
            }

            /* ---- row-max across BOTH s_frag halves via per-warp smem scratch ---- */
            int g_lo = lane >> 2, g_hi = g_lo + 8, slot = lane & 3;
            float pmax_lo = -INFINITY, pmax_hi = -INFINITY;
            #pragma unroll
            for (int n2 = 0; n2 < 2; ++n2) {
                float a_lo = fmaxf(fmaxf(s_frag[n2].x[0], s_frag[n2].x[1]),
                                   fmaxf(s_frag[n2].x[4], s_frag[n2].x[5]));
                float a_hi = fmaxf(fmaxf(s_frag[n2].x[2], s_frag[n2].x[3]),
                                   fmaxf(s_frag[n2].x[6], s_frag[n2].x[7]));
                if (a_lo > pmax_lo) pmax_lo = a_lo;
                if (a_hi > pmax_hi) pmax_hi = a_hi;
            }
            red_max[wid][g_lo * 4 + slot] = pmax_lo;
            red_max[wid][g_hi * 4 + slot] = pmax_hi;
            __syncwarp();
            float tmax_lo = fmaxf(fmaxf(red_max[wid][g_lo*4+0], red_max[wid][g_lo*4+1]),
                                  fmaxf(red_max[wid][g_lo*4+2], red_max[wid][g_lo*4+3]));
            float tmax_hi = fmaxf(fmaxf(red_max[wid][g_hi*4+0], red_max[wid][g_hi*4+1]),
                                  fmaxf(red_max[wid][g_hi*4+2], red_max[wid][g_hi*4+3]));
            __syncwarp();
            float mn_lo = fmaxf(m_lo, tmax_lo);
            float mn_hi = fmaxf(m_hi, tmax_hi);
            float c_lo  = __expf(m_lo - mn_lo);
            float c_hi  = __expf(m_hi - mn_hi);

            /* ---- P = exp(S - m_new), stored as two 8-elem reg arrays ---- */
            float p0[8], p1[8];
            #pragma unroll
            for (int n2 = 0; n2 < 2; ++n2) {
                float* p = (n2 == 0) ? p0 : p1;
                p[0] = __expf(s_frag[n2].x[0] - mn_lo);
                p[1] = __expf(s_frag[n2].x[1] - mn_lo);
                p[4] = __expf(s_frag[n2].x[4] - mn_lo);
                p[5] = __expf(s_frag[n2].x[5] - mn_lo);
                p[2] = __expf(s_frag[n2].x[2] - mn_hi);
                p[3] = __expf(s_frag[n2].x[3] - mn_hi);
                p[6] = __expf(s_frag[n2].x[6] - mn_hi);
                p[7] = __expf(s_frag[n2].x[7] - mn_hi);
            }

            /* ---- row-sum across both halves ---- */
            float ps_lo = (p0[0]+p0[1]+p0[4]+p0[5]) + (p1[0]+p1[1]+p1[4]+p1[5]);
            float ps_hi = (p0[2]+p0[3]+p0[6]+p0[7]) + (p1[2]+p1[3]+p1[6]+p1[7]);
            red_sum[wid][g_lo * 4 + slot] = ps_lo;
            red_sum[wid][g_hi * 4 + slot] = ps_hi;
            __syncwarp();
            float ts_lo = red_sum[wid][g_lo*4+0]+red_sum[wid][g_lo*4+1]
                        + red_sum[wid][g_lo*4+2]+red_sum[wid][g_lo*4+3];
            float ts_hi = red_sum[wid][g_hi*4+0]+red_sum[wid][g_hi*4+1]
                        + red_sum[wid][g_hi*4+2]+red_sum[wid][g_hi*4+3];
            __syncwarp();
            l_lo = l_lo * c_lo + ts_lo;
            l_hi = l_hi * c_hi + ts_hi;
            m_lo = mn_lo;
            m_hi = mn_hi;

            /* ---- repack P -> matrix_a fragments (local reg move; R9) ----
             * Two pa fragments: pa[0] = P columns 0..15, pa[1] = columns 16..31. */
            wmma::fragment<wmma::matrix_a,16,16,16,__half,wmma::row_major> pa[2];
            #pragma unroll
            for (int n2 = 0; n2 < 2; ++n2) {
                float* p = (n2 == 0) ? p0 : p1;
                #pragma unroll
                for (int i = 0; i < 8; ++i) {
                    __half h = __float2half(p[i]);
                    pa[n2].x[i]   = h;
                    pa[n2].x[i+8] = h;
                }
            }

            /* ---- rescale running O by c (in regs) ---- */
            #pragma unroll
            for (int t = 0; t < 4; ++t) scale_o(oacc[t], c_lo, c_hi);

            /* ---- P . V into oacc using V^T pre-transposed slot ----
             * O[m,d_col] += sum_k P[m,k] * V[k, d_col]
             *            = sum_k P[m,k] * Vt[d_col, k]   (Vt[n][k] = V[k][n])
             * P is row_major; Vt is row_major with rows = output d_col, cols = k.
             * Using wmma matrix_b with row_major + col=k dimension gives the
             * non-trans path (risk-d cleared).
             *
             * Output O d-dim split into 4 chunks of 16 cols each.
             * BK=32 keys split into 2 mma-k steps of 16 each.
             */
            #pragma unroll
            for (int t = 0; t < 4; ++t) {
                #pragma unroll
                for (int n2 = 0; n2 < 2; ++n2) {
                    /* vt_sm rows [t*16 .. t*16+15] (16 d-output cols), cols [n2*16 .. n2*16+15] (k).
                     * For wmma matrix_b row_major, the "rows" are the K-dim of the mma (k=16),
                     * the "cols" are the N-dim of the output (16 d-cols). We want
                     * output_d_col x k laid out as ROWS=k, COLS=d_col. So we transpose:
                     * load from vt_sm at offset (n2*16, t*16) but read as col_major. */
                    wmma::fragment<wmma::matrix_b,16,16,16,__half,wmma::col_major> vf;
                    /* vt_sm[d_col=t*16 + col_within_16][k=n2*16 + row_within_16]
                     * load_matrix_sync with leading dim BK + col_major treats the
                     * leading dim as the row stride and reads consecutive columns. */
                    wmma::load_matrix_sync(vf, vt_sm + (t * 16) * BK + n2 * 16, BK);
                    wmma::mma_sync(oacc[t], pa[n2], vf, oacc[t]);
                }
            }
        }
        __syncthreads();   /* tile consumed; safe to overwrite buffer cur next */
    }

    /* ---- finalize: divide each row by l, store O as fp32 to global ---- */
    if (wid < NWARP_Q) {
        float il_lo = 1.0f / l_lo, il_hi = 1.0f / l_hi;
        #pragma unroll
        for (int t = 0; t < 4; ++t) {
            scale_o(oacc[t], il_lo, il_hi);
            wmma::store_matrix_sync(o_dbg[wid], oacc[t], 16, wmma::mem_row_major);
            __syncwarp();
            if (lane < 16) {
                int row = qrow_base + wid * 16 + lane;
                if (row < N) {
                    #pragma unroll
                    for (int e = 0; e < 16; ++e) {
                        o[(size_t)row * D + t * 16 + e] = o_dbg[wid][lane * 16 + e];
                    }
                }
            }
            __syncwarp();
        }
    }
}
