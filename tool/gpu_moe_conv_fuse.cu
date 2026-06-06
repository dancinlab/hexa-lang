/* gpu_moe_conv_fuse.cu — FLAME+FORGE fused multi-expert Conv1d MoE kernel.
 *
 * THE f5e18a0f ROOT-CAUSE CURE (HEXA-FUSION whole-program-fusion thesis applied
 * to the exact measured 7B CLMConvMoE training-speed wall).
 *
 * ── The wall (measured by anima on H200, handoff f5e18a0f) ───────────────────
 * A CLMConvMoE MoE block = a ModuleList of E=30 ConvExpert, each an
 * nn.Conv1d(d, d, K) with d=6208 → 30 small Conv1d launches per step (~74s/step).
 * That UNDER-FILLS the GPU SM scheduler (each launch is too small to fill an
 * H100/H200). The "obvious" vectorization — one grouped conv
 * nn.Conv1d(E*d, E*d, K, groups=E) — made it ~11x SLOWER because a
 * groups=30 / 186240-channel grouped conv DEFEATS cuDNN group-parallelism
 * (algo-selection falls to a naive serialized path). cuDNN structurally offers
 * only two bad options: 30-separate-launches (under-fill) OR one-grouped-conv
 * (naive regression). NEITHER fills the GPU.
 *
 * ── The structural 3rd option cuDNN can't give ──────────────────────────────
 * A single HEXA-codegen / forge own-device-kernel that computes ALL E experts'
 * Conv1d in ONE GPU-SATURATING launch — the E×(per-expert conv) work laid out
 * as parallel tiles/blocks that fill the SM scheduler, WITHOUT cuDNN's
 * grouped-conv algo-selection (we own the kernel) and WITHOUT 30 separate
 * launches. Tile = (expert e, out-channel-block, time-block). Per-expert weight
 * banked. This is the flame+forge cure: boundary removal at the kernel level.
 *
 * ── Math contract (mirrors stdlib/flame/conv_lib.hexa nn_conv1d_fwd EXACTLY) ─
 *   ConvExpert e: X_e[T, d] -> Y_e[T, d], causal Conv1d(d, d, K), dilation dil.
 *   y_e[t, co] = b_e[co] + Σ_ci Σ_k W_e[co, ci, k] · xin_e(t - dil·(K-1-k), ci)
 *   xin_e(p, ci) = X_e[p, ci] if p>=0 else 0   (causal left-pad, no future leak).
 * In a MoE block every expert sees the SAME input X (shape [T, d]); each has its
 * own weight bank W_e[d, d, K] and bias b_e[d]. (This matches CLMConvMoE: the
 * router gates, but every ConvExpert is fed the block input.)
 *
 * ── Four paths benchmarked (same pod, same shape) ───────────────────────────
 *   (A) ModuleList-30  : E separate kernel launches (the under-fill baseline).
 *   (B) grouped        : ONE launch, but ONE block per expert iterates ALL
 *                        out-channels serially (the naive grouped-conv regression
 *                        anti-pattern: group-parallel, channel-serial → starves SMs).
 *   (C) fused          : ONE launch, grid = (E × out-blocks × time-blocks) →
 *                        every (expert, out-block, time-block) tile is an
 *                        independent CTA → fills the SM scheduler. THE FILL CURE,
 *                        but a NAIVE per-channel MAC inner loop → at d>=1024 every
 *                        CTA re-reads X CO_TILE×-redundantly from global → loses to
 *                        (A) in the SATURATED regime (input-bandwidth-bound).
 *   (D) tiled-fused    : (C)'s grid (same fill) BUT the input time-window is staged
 *                        into SHARED memory once per CTA (coalesced) → the ci inner
 *                        loop reads X from smem (broadcast, zero redundant global
 *                        traffic) + register-blocked time accumulators. THE
 *                        OG-FUSE-OPT cure: keeps the under-fill win AND aims to
 *                        win the saturated regime too. Same accum order (ci outer,
 *                        k inner) → byte-eq max|Δ|=0 vs (A).
 *
 * Correctness GATE (g5, FIRST — no perf number before this passes):
 *   max|Δ| of (B) and (C) vs the (A) op-by-op reference, over Y for all E experts.
 *   All three paths accumulate in the SAME order (ci outer, k inner) so the gate
 *   target is byte-exact max|Δ| = 0 in fp64. (fp32 path reported separately for
 *   the realistic training dtype; tolerance stated inline.)
 *
 * Honest framing: the per-CTA conv math here is a plain tiled MAC loop, NOT a
 * faster-than-cuDNN conv algorithm (cuDNN's conv kernel = roofline). The WIN is
 * FUSION / FILL: (C) fills the GPU where (A) under-fills (too-small launches) and
 * (B) regresses (channel-serial). If (C) does not beat (A) step-time/util on the
 * rented GPU → honest closed-negative + the exact wall.
 *
 * Build (CUDA host):
 *   nvcc -arch=sm_XX -O3 -o gpu_moe_conv_fuse gpu_moe_conv_fuse.cu
 * Run:
 *   ./gpu_moe_conv_fuse [E] [d] [T] [K] [dil]
 * Defaults: E=30 d=6208 T=256 K=3 dil=1 (representative single-MoE-block shape).
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <cuda_runtime.h>

#define CK(call) do { \
    cudaError_t _e = (call); \
    if (_e != cudaSuccess) { \
        fprintf(stderr, "[T] CUDA %s:%d %s\n", \
                __FILE__, __LINE__, cudaGetErrorString(_e)); \
        exit(2); \
    } \
} while (0)

/* ── Tiling constants ────────────────────────────────────────────────────────
 * CTA computes a (TT time-steps) × (CO out-channels) tile for ONE expert.
 * Each thread owns one out-channel; loops over its TT time-steps. Block = CO
 * threads. Choose CO=128 (occupancy-friendly), TT=8 (output reuse of x_col gather).
 */
#define CO_TILE 128
#define TT_TILE 8

/* ── Fused kernel (C): grid.x = E, grid.y = ceil(d/CO_TILE), grid.z = ceil(T/TT_TILE)
 * Every (expert, out-block, time-block) is an independent CTA → E·⌈d/128⌉·⌈T/8⌉
 * CTAs in ONE launch saturate the SM scheduler.
 * Layouts (all device, fp32):
 *   X  : [T · d]               shared block input (all experts read it)
 *   W  : [E · d · d · K]       per-expert weight bank, W_e[co·d·K + ci·K + k]
 *   b  : [E · d]
 *   Y  : [E · T · d]           per-expert output
 */
__global__ void k_moe_conv_fused(const float* __restrict__ X,
                                 const float* __restrict__ W,
                                 const float* __restrict__ b,
                                 float* __restrict__ Y,
                                 int E, int T, int d, int K, int dil) {
    int e  = blockIdx.x;
    int co = blockIdx.y * CO_TILE + threadIdx.x;          /* this thread's out-channel */
    int t0 = blockIdx.z * TT_TILE;
    if (co >= d) return;

    const float* We = W + (size_t)e * d * d * K + (size_t)co * d * K; /* W_e[co, :, :] */
    float bias = b[(size_t)e * d + co];

    #pragma unroll
    for (int tt = 0; tt < TT_TILE; ++tt) {
        int t = t0 + tt;
        if (t >= T) break;
        float acc = bias;
        /* y[t,co] = b + Σ_ci Σ_k W[co,ci,k] · xin(t - dil·(K-1-k), ci)  */
        for (int ci = 0; ci < d; ++ci) {
            const float* Wc = We + ci * K;
            for (int k = 0; k < K; ++k) {
                int p = t - dil * (K - 1 - k);
                if (p >= 0) acc += Wc[k] * X[(size_t)p * d + ci];
            }
        }
        Y[((size_t)e * T + t) * d + co] = acc;
    }
}

/* ── Tiled fused kernel (D): the OG-FUSE-OPT cure for the SATURATED regime ─────
 * Same grid as (C) — grid = (E × ⌈d/CO_TILE⌉ × ⌈T/TT_TILE⌉), one CTA per
 * (expert, out-channel-block, time-block) → the SM scheduler is saturated.
 *
 * Why (C) loses at d>=1024 (the measured roofline): in (C) every one of the
 * CO_TILE threads in a CTA re-reads the SAME X[p, ci] for all ci from GLOBAL
 * memory — CO_TILE-fold redundant input traffic. At large d the X gathers
 * dominate and (C) is input-bandwidth-bound (it loses to ModuleList-30 there).
 *
 * The fix (this kernel): stage the input time-window into SHARED memory ONCE
 * per CTA, cooperatively + coalesced, then the per-out-channel ci inner loop
 * reads X from smem (a broadcast, zero extra global traffic). Input global
 * traffic drops by CO_TILE×. Weights W_e[co,ci,k] are unique per thread so they
 * still stream from global, but with a coalesced ci-block layout they hit L2.
 *
 * smem budget: stage a CI_TILE-wide slice of the time window at a time. The
 * window spans rows [t0-(K-1)·dil .. t0+TT_TILE-1] → WROWS = TT_TILE+(K-1)·dil
 * time positions. smem tile = WROWS × CI_TILE floats. We loop ci in CI_TILE
 * chunks so smem stays bounded for ANY d. CRITICAL for byte-eq: the
 * accumulation visits ci in ascending order, k inner — IDENTICAL order to the
 * reference (ci outer, k inner) → byte-exact max|Δ|=0 vs ModuleList-30.
 */
#define CI_TILE 32
#define WROWS   (TT_TILE + (3 - 1) * 1)   /* upper bound for K<=3, dil==1 smem sizing */
__global__ void k_moe_conv_tiled(const float* __restrict__ X,
                                 const float* __restrict__ W,
                                 const float* __restrict__ b,
                                 float* __restrict__ Y,
                                 int E, int T, int d, int K, int dil) {
    /* smem: dynamically sized window slice, [wrows][CI_TILE] row-major.
     * wrows = TT_TILE + (K-1)*dil time positions, base = t0 - (K-1)*dil. */
    extern __shared__ float sX[];
    int e   = blockIdx.x;
    int cob = blockIdx.y * CO_TILE;
    int co  = cob + threadIdx.x;                 /* this thread's out-channel  */
    int t0  = blockIdx.z * TT_TILE;
    int wrows = TT_TILE + (K - 1) * dil;         /* time positions to stage    */
    int wbase = t0 - (K - 1) * dil;              /* first window time position */

    const float* We = (co < d) ? (W + (size_t)e * d * d * K + (size_t)co * d * K) : 0;
    float bias = (co < d) ? b[(size_t)e * d + co] : 0.0f;

    /* register-blocked accumulators: one per time-step in this CTA's tile */
    float acc[TT_TILE];
    #pragma unroll
    for (int tt = 0; tt < TT_TILE; ++tt) acc[tt] = bias;

    /* ── stream over input channels in CI_TILE chunks (ci ascending) ──────── */
    for (int cb = 0; cb < d; cb += CI_TILE) {
        int cw = (cb + CI_TILE <= d) ? CI_TILE : (d - cb);   /* live ci in chunk */

        /* cooperatively stage the window slice X[wbase..wbase+wrows-1, cb..cb+cw)
         * into smem. Coalesced: consecutive threads load consecutive ci. Causal
         * left-pad (p<0) → 0, matching xin(p,ci)=0 for p<0. */
        for (int idx = threadIdx.x; idx < wrows * cw; idx += blockDim.x) {
            int r  = idx / cw;          /* window row (time offset)  */
            int cl = idx % cw;          /* local ci within chunk     */
            int p  = wbase + r;
            sX[idx] = (p >= 0 && p < T) ? X[(size_t)p * d + (cb + cl)] : 0.0f;
        }
        __syncthreads();

        /* accumulate this chunk's contribution. ci ascending, k inner — EXACT
         * reference order → byte-eq. Only active out-channels write. */
        if (co < d) {
            for (int cl = 0; cl < cw; ++cl) {
                const float* Wc = We + (size_t)(cb + cl) * K;
                #pragma unroll
                for (int tt = 0; tt < TT_TILE; ++tt) {
                    int t = t0 + tt;
                    if (t >= T) break;
                    float a = acc[tt];
                    for (int k = 0; k < K; ++k) {
                        int p = t - dil * (K - 1 - k);
                        /* smem row for time p = p - wbase; valid by construction.
                         * p<0 staged as 0 already, so the MAC is a no-op there. */
                        int sr = p - wbase;
                        if (sr >= 0) a += Wc[k] * sX[sr * cw + cl];
                    }
                    acc[tt] = a;
                }
            }
        }
        __syncthreads();   /* protect sX before next chunk overwrites it */
    }

    if (co < d) {
        #pragma unroll
        for (int tt = 0; tt < TT_TILE; ++tt) {
            int t = t0 + tt;
            if (t >= T) break;
            Y[((size_t)e * T + t) * d + co] = acc[tt];
        }
    }
}

/* ── ModuleList-30 path (A): per-expert launch.
 * IDENTICAL math to the fused kernel, but ONE expert per launch → grid is
 * E× smaller per launch → each launch under-fills. grid = (⌈d/CO⌉, ⌈T/TT⌉).
 */
__global__ void k_conv_single(const float* __restrict__ X,
                             const float* __restrict__ We_bank,  /* W for this expert: [d·d·K] */
                             const float* __restrict__ be,       /* [d] */
                             float* __restrict__ Ye,             /* [T·d] */
                             int T, int d, int K, int dil) {
    int co = blockIdx.x * CO_TILE + threadIdx.x;
    int t0 = blockIdx.y * TT_TILE;
    if (co >= d) return;
    const float* We = We_bank + (size_t)co * d * K;
    float bias = be[co];
    #pragma unroll
    for (int tt = 0; tt < TT_TILE; ++tt) {
        int t = t0 + tt;
        if (t >= T) break;
        float acc = bias;
        for (int ci = 0; ci < d; ++ci) {
            const float* Wc = We + ci * K;
            for (int k = 0; k < K; ++k) {
                int p = t - dil * (K - 1 - k);
                if (p >= 0) acc += Wc[k] * X[(size_t)p * d + ci];
            }
        }
        Ye[(size_t)t * d + co] = acc;
    }
}

/* ── grouped anti-pattern (B): ONE launch, ONE block per expert (grid.x = E),
 * block iterates ALL out-channels serially (group-parallel, CHANNEL-serial).
 * This is the structural shape of the cuDNN grouped-conv naive fallback: only
 * E=30 blocks → 30 CTAs cannot fill an SM scheduler with 100+ SMs, and each
 * block grinds d out-channels in series. Reproduces the 11x regression cause.
 * block = CO_TILE threads; thread strides over out-channels.
 */
__global__ void k_moe_conv_grouped(const float* __restrict__ X,
                                  const float* __restrict__ W,
                                  const float* __restrict__ b,
                                  float* __restrict__ Y,
                                  int E, int T, int d, int K, int dil) {
    int e = blockIdx.x;                  /* ONE block per expert (group-parallel only) */
    const float* We_bank = W + (size_t)e * d * d * K;
    const float* be = b + (size_t)e * d;
    float* Ye = Y + (size_t)e * T * d;
    /* channel-serial: each thread walks the full out-channel range in stride. */
    for (int co = threadIdx.x; co < d; co += blockDim.x) {
        const float* We = We_bank + (size_t)co * d * K;
        float bias = be[co];
        for (int t = 0; t < T; ++t) {
            float acc = bias;
            for (int ci = 0; ci < d; ++ci) {
                const float* Wc = We + ci * K;
                for (int k = 0; k < K; ++k) {
                    int p = t - dil * (K - 1 - k);
                    if (p >= 0) acc += Wc[k] * X[(size_t)p * d + ci];
                }
            }
            Ye[(size_t)t * d + co] = acc;
        }
    }
}

/* ── CPU reference (op-by-op, mirrors conv_lib.hexa nn_conv1d_fwd EXACTLY) ──── */
static void cpu_moe_conv(const float* X, const float* W, const float* b,
                         float* Y, int E, int T, int d, int K, int dil) {
    int dK = d * K;
    for (int e = 0; e < E; ++e) {
        const float* We = W + (size_t)e * d * d * K;
        const float* be = b + (size_t)e * d;
        float* Ye = Y + (size_t)e * T * d;
        for (int t = 0; t < T; ++t) {
            for (int co = 0; co < d; ++co) {
                float acc = be[co];
                const float* Wco = We + (size_t)co * dK;
                for (int ci = 0; ci < d; ++ci) {
                    const float* Wc = Wco + ci * K;
                    for (int k = 0; k < K; ++k) {
                        int p = t - dil * (K - 1 - k);
                        if (p >= 0) acc += Wc[k] * X[(size_t)p * d + ci];
                    }
                }
                Ye[(size_t)t * d + co] = acc;
            }
        }
    }
}

/* ── LCG (deterministic) ─────────────────────────────────────────────────── */
static float lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (float)((double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53));
}

static double max_abs_diff(const float* a, const float* b, size_t n) {
    double m = 0.0;
    for (size_t i = 0; i < n; ++i) {
        double diff = fabs((double)a[i] - (double)b[i]);
        if (diff > m) m = diff;
    }
    return m;
}

/* ── timing harness: median of ITERS, cuEvent ─────────────────────────────── */
static int cmp_d(const void* a, const void* b) {
    double x = *(const double*)a, y = *(const double*)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

/* ════════════════════════════════════════════════════════════════════════════
 * GATE — correctness vs CPU op-by-op reference. Run at a SMALL shape (CPU oracle
 * is E·T·d·d·K MACs — only tractable for small d). Proves all three device
 * kernels are byte-exact vs the 30-separate-conv reference; the SAME kernels then
 * run at the representative perf shape (their correctness is shape-independent).
 * Returns 1 on any gate failure.
 * ════════════════════════════════════════════════════════════════════════════ */
static int run_gate(int E, int d, int T, int K, int dil) {
    printf("\n# ── CORRECTNESS GATE (vs CPU op-by-op 30-conv reference) ──\n");
    printf("# gate shape: E=%d d=%d T=%d K=%d dil=%d (small → CPU oracle tractable)\n",
           E, d, T, K, dil);
    size_t nX = (size_t)T * d, nW = (size_t)E * d * d * K, nB = (size_t)E * d, nY = (size_t)E * T * d;

    float* hX = (float*)malloc(nX * sizeof(float));
    float* hW = (float*)malloc(nW * sizeof(float));
    float* hB = (float*)malloc(nB * sizeof(float));
    float* hY_ref = (float*)malloc(nY * sizeof(float));
    float* hY_gpu = (float*)malloc(nY * sizeof(float));
    if (!hX || !hW || !hB || !hY_ref || !hY_gpu) { fprintf(stderr, "[T] gate malloc failed\n"); return 2; }

    uint64_t s = 0x1234567890abcdefULL;
    for (size_t i = 0; i < nX; ++i) hX[i] = (lcg_next(&s) - 0.5f) * 2.0f;
    for (size_t i = 0; i < nW; ++i) hW[i] = (lcg_next(&s) - 0.5f) * 0.05f;
    for (size_t i = 0; i < nB; ++i) hB[i] = (lcg_next(&s) - 0.5f) * 0.1f;

    cpu_moe_conv(hX, hW, hB, hY_ref, E, T, d, K, dil);

    float *dX, *dW, *dB, *dY;
    CK(cudaMalloc(&dX, nX * sizeof(float))); CK(cudaMalloc(&dW, nW * sizeof(float)));
    CK(cudaMalloc(&dB, nB * sizeof(float))); CK(cudaMalloc(&dY, nY * sizeof(float)));
    CK(cudaMemcpy(dX, hX, nX * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW, hW, nW * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, nB * sizeof(float), cudaMemcpyHostToDevice));

    int n_co_blk = (d + CO_TILE - 1) / CO_TILE, n_tt_blk = (T + TT_TILE - 1) / TT_TILE;

    /* Each path's output is captured to its own host buffer so we can run the
     * gate as TWO honest sub-gates:
     *  (1) device-vs-device byte-exact: fused vs ModuleList-30 vs grouped must be
     *      bit-identical (same op order, same FMA contraction on-device) → max|Δ|=0.
     *      This is the contract that matters: the fused kernel reproduces the
     *      30-separate-conv reference EXACTLY at the bit level.
     *  (2) device-vs-CPU within fp32 FMA tolerance: the GPU contracts W·X+acc into
     *      a single fma (one rounding) where the CPU ref does mul-then-add (two
     *      roundings). This is a legitimate ~1-ULP fp32 difference, NOT a bug —
     *      same accumulation ORDER, different rounding granularity. Tolerance
     *      stated explicitly (flame byte-eq contract: FMA-contraction case). */
    float* hY_fused = (float*)malloc(nY * sizeof(float));
    float* hY_mlist = (float*)malloc(nY * sizeof(float));
    float* hY_tiled = (float*)malloc(nY * sizeof(float));
    if (!hY_fused || !hY_mlist || !hY_tiled) { fprintf(stderr,"[T] gate buf malloc failed\n"); return 2; }

    /* smem bytes for the tiled kernel: wrows·CI_TILE floats. */
    int g_wrows = TT_TILE + (K - 1) * dil;
    size_t g_smem = (size_t)g_wrows * CI_TILE * sizeof(float);

    /* (C) fused */
    CK(cudaMemset(dY, 0, nY * sizeof(float)));
    { dim3 grid(E, n_co_blk, n_tt_blk), blk(CO_TILE);
      k_moe_conv_fused<<<grid, blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hY_fused, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_fused_cpu = max_abs_diff(hY_ref, hY_fused, nY);
    printf("[GATE-FUSED]   max|Δ| vs CPU = %.3e\n", dmax_fused_cpu);

    /* (D) tiled-fused (OG-FUSE-OPT) */
    CK(cudaMemset(dY, 0, nY * sizeof(float)));
    { dim3 grid(E, n_co_blk, n_tt_blk), blk(CO_TILE);
      k_moe_conv_tiled<<<grid, blk, g_smem>>>(dX, dW, dB, dY, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hY_tiled, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_tiled_cpu = max_abs_diff(hY_ref, hY_tiled, nY);
    printf("[GATE-TILED]   max|Δ| vs CPU = %.3e\n", dmax_tiled_cpu);

    /* (A) ModuleList-30 */
    CK(cudaMemset(dY, 0, nY * sizeof(float)));
    { dim3 grid(n_co_blk, n_tt_blk), blk(CO_TILE);
      for (int e = 0; e < E; ++e)
        k_conv_single<<<grid, blk>>>(dX, dW + (size_t)e*d*d*K, dB + (size_t)e*d, dY + (size_t)e*T*d, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hY_mlist, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_mlist_cpu = max_abs_diff(hY_ref, hY_mlist, nY);
    printf("[GATE-MLIST30] max|Δ| vs CPU = %.3e\n", dmax_mlist_cpu);

    /* (B) grouped */
    CK(cudaMemset(dY, 0, nY * sizeof(float)));
    { dim3 grid(E), blk(CO_TILE);
      k_moe_conv_grouped<<<grid, blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hY_gpu, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_grp_cpu = max_abs_diff(hY_ref, hY_gpu, nY);
    printf("[GATE-GROUPED] max|Δ| vs CPU = %.3e\n", dmax_grp_cpu);

    /* sub-gate (1): device-vs-device byte-exact (the contract that matters) */
    double dmax_fused_vs_mlist = max_abs_diff(hY_fused, hY_mlist, nY);
    double dmax_grp_vs_mlist   = max_abs_diff(hY_gpu,   hY_mlist, nY);
    double dmax_tiled_vs_mlist = max_abs_diff(hY_tiled, hY_mlist, nY);
    printf("[GATE-DEV-EQ]  max|Δ|(fused vs ModuleList) = %.3e   max|Δ|(grouped vs ModuleList) = %.3e\n",
           dmax_fused_vs_mlist, dmax_grp_vs_mlist);
    printf("[GATE-DEV-EQ]  max|Δ|(TILED vs ModuleList) = %.3e  <= THE OG-FUSE-OPT CONTRACT (must be 0)\n",
           dmax_tiled_vs_mlist);
    int dev_eq_pass = (dmax_fused_vs_mlist == 0.0) && (dmax_grp_vs_mlist == 0.0)
                      && (dmax_tiled_vs_mlist == 0.0);

    /* sub-gate (2): device-vs-CPU within fp32 FMA-contraction tolerance.
     * Bound: with |W|≤0.025, |X|≤1, d=192 taps → |y|≲5; fp32 eps≈1.2e-7 →
     * worst-case FMA-vs-mul-add divergence over the sum is O(d·eps·|term|).
     * 6e-6 is a safe abs bound (observed ~3e-7). */
    double FMA_TOL = 6e-6;
    int cpu_tol_pass = (dmax_fused_cpu <= FMA_TOL) && (dmax_mlist_cpu <= FMA_TOL)
                       && (dmax_grp_cpu <= FMA_TOL) && (dmax_tiled_cpu <= FMA_TOL);

    int pass = dev_eq_pass && cpu_tol_pass;
    printf("# GATE (1) device-vs-device byte-exact (max|Δ|=0): %s\n", dev_eq_pass ? "PASS" : "FAIL");
    printf("# GATE (2) device-vs-CPU within fp32 FMA tol=%.1e: %s\n", FMA_TOL, cpu_tol_pass ? "PASS" : "FAIL");
    printf("# GATE OVERALL => %s\n", pass ? "PASS" : "FAIL");

    cudaFree(dX); cudaFree(dW); cudaFree(dB); cudaFree(dY);
    free(hX); free(hW); free(hB); free(hY_ref); free(hY_gpu); free(hY_fused); free(hY_mlist); free(hY_tiled);
    return pass ? 0 : 1;
}

int main(int argc, char** argv) {
    int E   = (argc > 1) ? atoi(argv[1]) : 30;
    int d   = (argc > 2) ? atoi(argv[2]) : 2048;
    int T   = (argc > 3) ? atoi(argv[3]) : 256;
    int K   = (argc > 4) ? atoi(argv[4]) : 3;
    int dil = (argc > 5) ? atoi(argv[5]) : 1;
    /* gate dimension (CPU-oracle tractable). Override: argv[6]. */
    int gate_d = (argc > 6) ? atoi(argv[6]) : 192;
    int gate_T = 32;

    printf("# gpu_moe_conv_fuse — fused multi-expert Conv1d MoE kernel (f5e18a0f cure)\n");
    printf("# perf shape: E=%d d=%d T=%d K=%d dil=%d\n", E, d, T, K, dil);

    int dev = 0; cudaDeviceProp prop;
    CK(cudaGetDeviceProperties(&prop, dev));
    printf("# device: %s  SMs=%d  cap=%d.%d\n", prop.name, prop.multiProcessorCount,
           prop.major, prop.minor);

    /* ════════════ GATE FIRST — no perf number before this passes ════════════ */
    int gate_rc = run_gate(E, gate_d, gate_T, K, dil);
    if (gate_rc != 0) {
        printf("[T] CORRECTNESS GATE FAILED (rc=%d) — no perf reported.\n", gate_rc);
        return 1;
    }

    /* ════════════ PERF — representative shape, device-vs-device check ════════ */
    size_t nX = (size_t)T * d;
    size_t nW = (size_t)E * d * d * K;
    size_t nB = (size_t)E * d;
    size_t nY = (size_t)E * T * d;
    printf("\n# weight bank = %.2f GB (E·d·d·K fp32), output = %.2f GB\n",
           (double)nW * sizeof(float) / 1e9, (double)nY * sizeof(float) / 1e9);

    float* hX = (float*)malloc(nX * sizeof(float));
    float* hW = (float*)malloc(nW * sizeof(float));
    float* hB = (float*)malloc(nB * sizeof(float));
    float* hY_a = (float*)malloc(nY * sizeof(float));
    float* hY_c = (float*)malloc(nY * sizeof(float));
    if (!hX || !hW || !hB || !hY_a || !hY_c) {
        fprintf(stderr, "[T] host malloc failed (need ~%.1f GB host)\n",
                (double)(nW + nY * 2) * sizeof(float) / 1e9);
        return 2;
    }
    uint64_t s = 0x1234567890abcdefULL;
    for (size_t i = 0; i < nX; ++i) hX[i] = (lcg_next(&s) - 0.5f) * 2.0f;
    for (size_t i = 0; i < nW; ++i) hW[i] = (lcg_next(&s) - 0.5f) * 0.05f;
    for (size_t i = 0; i < nB; ++i) hB[i] = (lcg_next(&s) - 0.5f) * 0.1f;

    float *dX, *dW, *dB, *dY;
    CK(cudaMalloc(&dX, nX * sizeof(float)));
    CK(cudaMalloc(&dW, nW * sizeof(float)));
    CK(cudaMalloc(&dB, nB * sizeof(float)));
    CK(cudaMalloc(&dY, nY * sizeof(float)));
    CK(cudaMemcpy(dX, hX, nX * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW, hW, nW * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, nB * sizeof(float), cudaMemcpyHostToDevice));

    int n_co_blk = (d + CO_TILE - 1) / CO_TILE;
    int n_tt_blk = (T + TT_TILE - 1) / TT_TILE;

    /* device-vs-device cross-check at perf shape: fused (C) vs ModuleList (A)
     * must agree byte-exact (same accum order) — guards the perf-shape kernels. */
    CK(cudaMemset(dY, 0, nY * sizeof(float)));
    { dim3 grid(n_co_blk, n_tt_blk), blk(CO_TILE);
      for (int e = 0; e < E; ++e)
        k_conv_single<<<grid, blk>>>(dX, dW + (size_t)e*d*d*K, dB + (size_t)e*d, dY + (size_t)e*T*d, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hY_a, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
    CK(cudaMemset(dY, 0, nY * sizeof(float)));
    { dim3 grid(E, n_co_blk, n_tt_blk), blk(CO_TILE);
      k_moe_conv_fused<<<grid, blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hY_c, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_cc = max_abs_diff(hY_a, hY_c, nY);
    printf("# perf-shape cross-check  max|Δ|(fused vs ModuleList) = %.3e (expect 0)\n", dmax_cc);
    if (dmax_cc != 0.0) { printf("[T] perf-shape cross-check FAILED — abort.\n"); return 1; }

    /* tiled (D) perf-shape cross-check vs ModuleList — same byte-eq contract. */
    int p_wrows = TT_TILE + (K - 1) * dil;
    size_t p_smem = (size_t)p_wrows * CI_TILE * sizeof(float);
    CK(cudaMemset(dY, 0, nY * sizeof(float)));
    { dim3 grid(E, n_co_blk, n_tt_blk), blk(CO_TILE);
      k_moe_conv_tiled<<<grid, blk, p_smem>>>(dX, dW, dB, dY, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hY_c, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_tc = max_abs_diff(hY_a, hY_c, nY);
    printf("# perf-shape cross-check  max|Δ|(TILED vs ModuleList) = %.3e (expect 0)\n", dmax_tc);
    if (dmax_tc != 0.0) { printf("[T] perf-shape TILED cross-check FAILED — abort.\n"); return 1; }

    printf("\n# ── PERF (median of timed iters, cuEvent) ──\n");
    const int WARMUP = 3, ITERS = 20;
    double* samp = (double*)malloc(ITERS * sizeof(double));
    cudaEvent_t e0, e1;
    CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));

    /* (A) ModuleList-30 */
    {
        dim3 grid(n_co_blk, n_tt_blk), blk(CO_TILE);
        for (int w = 0; w < WARMUP; ++w)
            for (int e = 0; e < E; ++e)
                k_conv_single<<<grid, blk>>>(dX, dW + (size_t)e*d*d*K, dB + (size_t)e*d, dY + (size_t)e*T*d, T, d, K, dil);
        CK(cudaDeviceSynchronize());
        for (int it = 0; it < ITERS; ++it) {
            CK(cudaEventRecord(e0, 0));
            for (int e = 0; e < E; ++e)
                k_conv_single<<<grid, blk>>>(dX, dW + (size_t)e*d*d*K, dB + (size_t)e*d, dY + (size_t)e*T*d, T, d, K, dil);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            samp[it] = ms;
        }
        qsort(samp, ITERS, sizeof(double), cmp_d);
        printf("[A] ModuleList-30  step = %.3f ms  (E separate launches — under-fill baseline)\n", samp[ITERS/2]);
    }

    /* (B) grouped */
    {
        dim3 grid(E), blk(CO_TILE);
        for (int w = 0; w < WARMUP; ++w)
            k_moe_conv_grouped<<<grid, blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
        CK(cudaDeviceSynchronize());
        for (int it = 0; it < ITERS; ++it) {
            CK(cudaEventRecord(e0, 0));
            k_moe_conv_grouped<<<grid, blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            samp[it] = ms;
        }
        qsort(samp, ITERS, sizeof(double), cmp_d);
        printf("[B] grouped        step = %.3f ms  (1 launch, channel-serial — regression anti-pattern)\n", samp[ITERS/2]);
    }

    /* (C) fused */
    {
        dim3 grid(E, n_co_blk, n_tt_blk), blk(CO_TILE);
        for (int w = 0; w < WARMUP; ++w)
            k_moe_conv_fused<<<grid, blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
        CK(cudaDeviceSynchronize());
        for (int it = 0; it < ITERS; ++it) {
            CK(cudaEventRecord(e0, 0));
            k_moe_conv_fused<<<grid, blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            samp[it] = ms;
        }
        qsort(samp, ITERS, sizeof(double), cmp_d);
        printf("[C] FUSED          step = %.3f ms  (1 launch, %d CTAs — naive per-channel MAC)\n",
               samp[ITERS/2], E * n_co_blk * n_tt_blk);
    }

    /* (D) tiled-fused — OG-FUSE-OPT: smem-staged input window, register-blocked */
    {
        dim3 grid(E, n_co_blk, n_tt_blk), blk(CO_TILE);
        for (int w = 0; w < WARMUP; ++w)
            k_moe_conv_tiled<<<grid, blk, p_smem>>>(dX, dW, dB, dY, E, T, d, K, dil);
        CK(cudaDeviceSynchronize());
        for (int it = 0; it < ITERS; ++it) {
            CK(cudaEventRecord(e0, 0));
            k_moe_conv_tiled<<<grid, blk, p_smem>>>(dX, dW, dB, dY, E, T, d, K, dil);
            CK(cudaEventRecord(e1, 0));
            CK(cudaEventSynchronize(e1));
            float ms; CK(cudaEventElapsedTime(&ms, e0, e1));
            samp[it] = ms;
        }
        qsort(samp, ITERS, sizeof(double), cmp_d);
        printf("[D] TILED-FUSED    step = %.3f ms  (1 launch, %d CTAs, smem=%zuB — OG-FUSE-OPT cure)\n",
               samp[ITERS/2], E * n_co_blk * n_tt_blk, p_smem);
    }

    printf("# CTA counts: A=%d/launch ×%d launches  B=%d  C=D=%d (one launch)\n",
           n_co_blk * n_tt_blk, E, E, E * n_co_blk * n_tt_blk);
    printf("# (run under: nvidia-smi --query-gpu=utilization.gpu --format=csv -lms 50  for util MEAN/PEAK)\n");

    /* ── sustained per-path loop for the util sampler ─────────────────────────
     * If MOEFUSE_ONLY=A|B|C, run ~2.5s of repeated launches of just that path so
     * a background nvidia-smi sampler gets a clean utilization window. The script
     * wraps each with its own sampler → per-path util MEAN/PEAK captured inline. */
    const char* only = getenv("MOEFUSE_ONLY");
    if (only && (only[0]=='A'||only[0]=='B'||only[0]=='C'||only[0]=='D')) {
        printf("# sustained loop path=%s (~2.5s) for util capture\n", only);
        dim3 gA(n_co_blk, n_tt_blk), gB(E), gC(E, n_co_blk, n_tt_blk), blk(CO_TILE);
        cudaEvent_t t0, t1; CK(cudaEventCreate(&t0)); CK(cudaEventCreate(&t1));
        CK(cudaEventRecord(t0, 0));
        float elapsed = 0.0f;
        long reps = 0;
        while (elapsed < 2500.0f) {
            for (int r = 0; r < 5; ++r) {
                if (only[0]=='A') { for (int e=0;e<E;++e) k_conv_single<<<gA,blk>>>(dX, dW+(size_t)e*d*d*K, dB+(size_t)e*d, dY+(size_t)e*T*d, T, d, K, dil); }
                else if (only[0]=='B') k_moe_conv_grouped<<<gB,blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
                else if (only[0]=='D') k_moe_conv_tiled<<<gC,blk,p_smem>>>(dX, dW, dB, dY, E, T, d, K, dil);
                else k_moe_conv_fused<<<gC,blk>>>(dX, dW, dB, dY, E, T, d, K, dil);
                reps++;
            }
            CK(cudaDeviceSynchronize());
            CK(cudaEventRecord(t1, 0)); CK(cudaEventSynchronize(t1));
            CK(cudaEventElapsedTime(&elapsed, t0, t1));
        }
        printf("# sustained loop done: %ld reps in %.0f ms\n", reps, elapsed);
        cudaEventDestroy(t0); cudaEventDestroy(t1);
    }

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    cudaFree(dX); cudaFree(dW); cudaFree(dB); cudaFree(dY);
    free(hX); free(hW); free(hB); free(hY_a); free(hY_c); free(samp);
    printf("\n[T] DONE — gate PASS, perf captured.\n");
    return 0;
}
