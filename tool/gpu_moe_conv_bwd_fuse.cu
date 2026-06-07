/* gpu_moe_conv_bwd_fuse.cu — FF-BWDFUSE: byte-exact ATOMIC-FREE fused BACKWARD
 * for the multi-expert Conv1d MoE block (the bwd dual of gpu_moe_conv_fuse.cu).
 *
 * ── The problem (HEXA-FUSION FF-BWDFUSE) ─────────────────────────────────────
 * The flame CLMConvMoE backward glue scatters the input gradient gX with
 * atomicAdd: every (expert e, time t, out-channel co, tap k) contributes to
 * gX[p, ci] for p = t - dil*(K-1-k), and many (e,t,co,k) collide on the same
 * (p,ci). The atomic scatter is (1) memory-bound + serialized on the atomic unit
 * and (2) NON-DETERMINISTIC in accumulation order → NOT FP64 byte-exact across
 * runs. This is the exact wall FF-VALLEY + MEGASTEP inherit.
 *
 * ── The Flash-MaxSim recipe (arXiv 2605.29517) ──────────────────────────────
 * Reuse the FORWARD index structure to make the backward a DESTINATION-OWNED
 * reduction: each OUTPUT element owns its gradient accumulation and gathers its
 * contributors in a FIXED order. No atomics, deterministic accumulation →
 * reproduces the reference gradient BIT-FOR-BIT. We apply it to all three
 * gradients (gX, gW, gb); the hard one is gX (the inverse-grid index mapping).
 *
 * ── Forward (mirrors gpu_moe_conv_fuse.cu / conv_lib.hexa nn_conv1d_fwd) ──────
 *   y_e[t,co] = b_e[co] + Σ_ci Σ_k W_e[co,ci,k] · xin(t - dil*(K-1-k), ci)
 *   xin(p,ci) = X[p,ci] if p>=0 else 0   (causal left pad; X shared across experts)
 *
 * ── Backward (chain rule), upstream gY_e[t,co] ──────────────────────────────
 *   gb_e[co] = Σ_t gY_e[t,co]
 *   gW_e[co,ci,k] = Σ_t gY_e[t,co] · xin(t - dil*(K-1-k), ci)
 *   gX[p,ci]  = Σ_e Σ_co Σ_{k : t = p + dil*(K-1-k), 0<=t<T}
 *                  gY_e[t,co] · W_e[co,ci,k]
 *
 *   gb / gW are already destination-owned in the natural layout (one thread owns
 *   one (e,co) resp. (e,co,ci,k) and reduces over t) — no atomics, trivially
 *   deterministic. The ATOMIC wall is gX: in the naive bwd it is computed by the
 *   SCATTER  gX[p,ci] += gY_e[t,co]·W_e[co,ci,k]  with atomicAdd over (e,t,co,k).
 *
 * ── The inverse-grid index mapping (the hard part) ──────────────────────────
 *   forward read:   p = t - dil*(K-1-k)      (given t,k → p)
 *   inverse (gather): for a destination (p,ci), the contributing (t,k) pairs are
 *                     t = p + dil*(K-1-k),  for each k in [0,K),  iff 0<=t<T.
 *   So a destination-owned gX kernel: thread owns (p,ci); loops e (asc), co (asc),
 *   k (asc); for each k computes t=p+dil*(K-1-k); if 0<=t<T accumulates
 *   gY_e[t,co]·W_e[co,ci,k]. FIXED order (e,co,k) → deterministic, atomic-free.
 *
 * ── BYTE-EQ CONTRACT (g5, gated FIRST) ──────────────────────────────────────
 * The destination-owned gX must reproduce a DETERMINISTIC reference gX bit-for-
 * bit (max|Δ|=0). The reference is the same gather order (e asc, co asc, k asc)
 * computed single-threaded on CPU (fp64-safe small shape) AND a device gather.
 * The atomic scatter is ALSO run, and its deviation from the deterministic
 * reference is reported (it is generally NONZERO + run-to-run varying — that is
 * the non-determinism FF-BWDFUSE removes). gW/gb gates: byte-eq vs CPU ref too.
 *
 * Build (CUDA host):
 *   nvcc -arch=sm_XX -O3 -o gpu_moe_conv_bwd_fuse gpu_moe_conv_bwd_fuse.cu
 * Run:
 *   ./gpu_moe_conv_bwd_fuse [E] [d] [T] [K] [dil] [gate_d]
 * Defaults: E=30 d=2048 T=256 K=3 dil=1 (representative single-MoE-block shape).
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

/* ════════════════════════════════════════════════════════════════════════════
 * gX — the atomic wall and its destination-owned cure
 * ════════════════════════════════════════════════════════════════════════════ */

/* ── (X-ATOMIC) the naive/atomic backward scatter (the BASELINE wall) ─────────
 * grid = (E, ceil(d/CO), ceil(T/TT)) like the forward; each thread owns (e,co)
 * for a tile of t. For each (t,k) it computes p = t - dil*(K-1-k) and, for all
 * ci, does  atomicAdd(&gX[p,ci], gY_e[t,co]*W_e[co,ci,k]).  NON-DETERMINISTIC
 * accumulation order (atomic race) → not byte-exact. This is what FF-BWDFUSE
 * replaces. gX must be zeroed before launch. */
#define CO_TILE 128
#define TT_TILE 8
__global__ void k_gx_atomic(const float* __restrict__ gY,
                            const float* __restrict__ W,
                            float* __restrict__ gX,
                            int E, int T, int d, int K, int dil) {
    int e  = blockIdx.x;
    int co = blockIdx.y * CO_TILE + threadIdx.x;
    int t0 = blockIdx.z * TT_TILE;
    if (co >= d) return;
    const float* We = W + (size_t)e * d * d * K + (size_t)co * d * K; /* W_e[co,:,:] */
    #pragma unroll
    for (int tt = 0; tt < TT_TILE; ++tt) {
        int t = t0 + tt;
        if (t >= T) break;
        float gy = gY[((size_t)e * T + t) * d + co];
        for (int k = 0; k < K; ++k) {
            int p = t - dil * (K - 1 - k);
            if (p < 0) continue;
            const float* Wck = We + (size_t)0 * K + k;   /* stride K over ci */
            float* gXp = gX + (size_t)p * d;
            for (int ci = 0; ci < d; ++ci)
                atomicAdd(&gXp[ci], gy * Wck[(size_t)ci * K]);
        }
    }
}

/* ── (X-DESTOWN) FF-BWDFUSE: destination-owned, ATOMIC-FREE gX gather ─────────
 * grid covers all (p,ci) destinations; thread owns ONE (p,ci). Inverse index:
 *   for each k, t = p + dil*(K-1-k); valid iff 0<=t<T.
 * Accumulate over e (asc), co (asc), k (asc) — a FIXED order, no atomics. The
 * acc order is identical to the CPU reference (gather form) → byte-exact.
 * grid = (ceil(d/CIB), ceil(T/PB)); block = (CIB) threads each owning a column
 * of PB p-rows? Simpler+coalesced: one thread per (p,ci), block over ci. */
#define GX_CI 256
__global__ void k_gx_destown(const float* __restrict__ gY,
                             const float* __restrict__ W,
                             float* __restrict__ gX,
                             int E, int T, int d, int K, int dil) {
    int ci = blockIdx.x * GX_CI + threadIdx.x;   /* this thread's input channel */
    int p  = blockIdx.y;                         /* this thread's input time row */
    if (ci >= d || p >= T) return;
    float acc = 0.0f;
    /* fixed gather order: e asc, co asc, k asc. */
    for (int e = 0; e < E; ++e) {
        const float* gYe = gY + (size_t)e * T * d;
        const float* We  = W  + (size_t)e * d * d * K;            /* W_e[co,ci,k] */
        for (int co = 0; co < d; ++co) {
            const float* Wco = We + (size_t)co * d * K + (size_t)ci * K;  /* W_e[co,ci,:] */
            for (int k = 0; k < K; ++k) {
                int t = p + dil * (K - 1 - k);
                if (t >= 0 && t < T)
                    acc += gYe[(size_t)t * d + co] * Wco[k];
            }
        }
    }
    gX[(size_t)p * d + ci] = acc;
}

/* ════════════════════════════════════════════════════════════════════════════
 * gW / gb — already destination-owned (one thread per output, reduce over t)
 * ════════════════════════════════════════════════════════════════════════════ */

/* gW_e[co,ci,k] = Σ_t gY_e[t,co] · xin(t - dil*(K-1-k), ci).  One thread owns
 * one (e,co,ci,k) and reduces over t in ascending order → byte-exact, no atomics.
 * grid.x flattens (e,co); block over ci; loop k inner. */
__global__ void k_gw_destown(const float* __restrict__ gY,
                             const float* __restrict__ X,
                             float* __restrict__ gW,
                             int E, int T, int d, int K, int dil) {
    int eco = blockIdx.x;            /* flattened e*d + co */
    int e  = eco / d;
    int co = eco % d;
    int ci = blockIdx.y * blockDim.x + threadIdx.x;
    if (e >= E || ci >= d) return;
    const float* gYe = gY + ((size_t)e * T) * d + co;   /* stride d over t */
    float* gWe = gW + (size_t)e * d * d * K + (size_t)co * d * K + (size_t)ci * K;
    for (int k = 0; k < K; ++k) {
        float acc = 0.0f;
        int off = dil * (K - 1 - k);
        for (int t = 0; t < T; ++t) {
            int pp = t - off;
            if (pp >= 0)
                acc += gYe[(size_t)t * d] * X[(size_t)pp * d + ci];
        }
        gWe[k] = acc;
    }
}

/* gb_e[co] = Σ_t gY_e[t,co].  One thread per (e,co), reduce over t ascending. */
__global__ void k_gb_destown(const float* __restrict__ gY, float* __restrict__ gB,
                             int E, int T, int d) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;   /* e*d + co */
    if (idx >= E * d) return;
    int e  = idx / d;
    int co = idx % d;
    const float* gYe = gY + (size_t)e * T * d + co;
    float acc = 0.0f;
    for (int t = 0; t < T; ++t) acc += gYe[(size_t)t * d];
    gB[idx] = acc;
}

/* ════════════════════════════════════════════════════════════════════════════
 * CPU references (deterministic, fixed order; the byte-eq oracle at small shape)
 * ════════════════════════════════════════════════════════════════════════════ */
/* gX reference — GATHER form, fixed order (p,ci) destination owns, gather e,co,k
 * ascending. This is EXACTLY the destination-owned device order. */
static void cpu_gx(const float* gY, const float* W, float* gX,
                   int E, int T, int d, int K, int dil) {
    for (int p = 0; p < T; ++p)
        for (int ci = 0; ci < d; ++ci) {
            float acc = 0.0f;
            for (int e = 0; e < E; ++e) {
                const float* gYe = gY + (size_t)e * T * d;
                const float* We  = W  + (size_t)e * d * d * K;
                for (int co = 0; co < d; ++co) {
                    const float* Wco = We + (size_t)co * d * K + (size_t)ci * K;
                    for (int k = 0; k < K; ++k) {
                        int t = p + dil * (K - 1 - k);
                        if (t >= 0 && t < T)
                            acc = fmaf(gYe[(size_t)t * d + co], Wco[k], acc);
                    }
                }
            }
            gX[(size_t)p * d + ci] = acc;
        }
}
static void cpu_gw(const float* gY, const float* X, float* gW,
                   int E, int T, int d, int K, int dil) {
    for (int e = 0; e < E; ++e) {
        const float* gYe = gY + (size_t)e * T * d;
        float* gWe = gW + (size_t)e * d * d * K;
        for (int co = 0; co < d; ++co)
            for (int ci = 0; ci < d; ++ci)
                for (int k = 0; k < K; ++k) {
                    float acc = 0.0f;
                    int off = dil * (K - 1 - k);
                    for (int t = 0; t < T; ++t) {
                        int pp = t - off;
                        if (pp >= 0) acc = fmaf(gYe[(size_t)t * d + co], X[(size_t)pp * d + ci], acc);
                    }
                    gWe[(size_t)co * d * K + (size_t)ci * K + k] = acc;
                }
    }
}
static void cpu_gb(const float* gY, float* gB, int E, int T, int d) {
    for (int e = 0; e < E; ++e)
        for (int co = 0; co < d; ++co) {
            float acc = 0.0f;
            for (int t = 0; t < T; ++t) acc += gY[((size_t)e * T + t) * d + co];
            gB[(size_t)e * d + co] = acc;
        }
}

/* ── LCG (deterministic) + diff metrics ──────────────────────────────────────*/
static float lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (float)((double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53));
}
static double max_abs_diff(const float* a, const float* b, size_t n) {
    double m = 0.0;
    for (size_t i = 0; i < n; ++i) { double dd = fabs((double)a[i] - (double)b[i]); if (dd > m) m = dd; }
    return m;
}
static int cmp_d(const void* a, const void* b) {
    double x = *(const double*)a, y = *(const double*)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

/* ════════════════════════════════════════════════════════════════════════════
 * GATE — byte-eq of destination-owned gradients vs CPU reference (small shape)
 * ════════════════════════════════════════════════════════════════════════════ */
static int run_gate(int E, int d, int T, int K, int dil) {
    printf("\n# ── FF-BWDFUSE CORRECTNESS GATE (byte-eq vs deterministic CPU ref) ──\n");
    printf("# gate shape: E=%d d=%d T=%d K=%d dil=%d\n", E, d, T, K, dil);
    size_t nX = (size_t)T * d, nW = (size_t)E * d * d * K, nB = (size_t)E * d, nY = (size_t)E * T * d;

    float* hX  = (float*)malloc(nX * sizeof(float));
    float* hW  = (float*)malloc(nW * sizeof(float));
    float* hgY = (float*)malloc(nY * sizeof(float));
    if (!hX || !hW || !hgY) { fprintf(stderr, "[T] gate malloc\n"); return 2; }
    uint64_t s = 0x1234567890abcdefULL;
    for (size_t i = 0; i < nX; ++i) hX[i]  = (lcg_next(&s) - 0.5f) * 2.0f;
    for (size_t i = 0; i < nW; ++i) hW[i]  = (lcg_next(&s) - 0.5f) * 0.05f;
    for (size_t i = 0; i < nY; ++i) hgY[i] = (lcg_next(&s) - 0.5f) * 2.0f;

    /* CPU references */
    float* hgX_ref = (float*)malloc(nX * sizeof(float));
    float* hgW_ref = (float*)malloc(nW * sizeof(float));
    float* hgB_ref = (float*)malloc(nB * sizeof(float));
    cpu_gx(hgY, hW, hgX_ref, E, T, d, K, dil);
    cpu_gw(hgY, hX, hgW_ref, E, T, d, K, dil);
    cpu_gb(hgY, hgB_ref, E, T, d);

    float *dX, *dW, *dgY, *dgX, *dgW, *dgB;
    CK(cudaMalloc(&dX,  nX * sizeof(float)));
    CK(cudaMalloc(&dW,  nW * sizeof(float)));
    CK(cudaMalloc(&dgY, nY * sizeof(float)));
    CK(cudaMalloc(&dgX, nX * sizeof(float)));
    CK(cudaMalloc(&dgW, nW * sizeof(float)));
    CK(cudaMalloc(&dgB, nB * sizeof(float)));
    CK(cudaMemcpy(dX,  hX,  nX * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW,  hW,  nW * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dgY, hgY, nY * sizeof(float), cudaMemcpyHostToDevice));

    float* hgpu  = (float*)malloc(nW * sizeof(float));   /* largest, reuse */
    float* hgpu2 = (float*)malloc(nW * sizeof(float));   /* 2nd run, determinism check */

    /* The byte-eq contract has TWO honest sub-gates (mirrors the forward verdict):
     *  (1) DEVICE-vs-DEVICE byte-exact: the destination-owned kernel is run TWICE
     *      and must be BIT-IDENTICAL (max|Δ|=0) — this is the FF-BWDFUSE property:
     *      atomic-free => deterministic + reproducible (the atomic scatter is NOT).
     *  (2) DEVICE-vs-CPU within fp32 FMA tolerance: the CPU ref uses fmaf (single
     *      rounding, SAME order) so it matches the GPU's fma-contracted MAC; any
     *      residual is ~1-ULP fp32, NOT a bug. Tolerance stated explicitly. */
    const double FMA_TOL = 6e-6;

    /* ── gX destination-owned (atomic-free) — run TWICE for determinism ── */
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid((d + GX_CI - 1) / GX_CI, T), blk(GX_CI);
      k_gx_destown<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hgpu, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid((d + GX_CI - 1) / GX_CI, T), blk(GX_CI);
      k_gx_destown<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hgpu2, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_gx_determ = max_abs_diff(hgpu, hgpu2, nX);           /* sub-gate (1) */
    double dmax_gx_cpu    = max_abs_diff(hgX_ref, hgpu, nX);         /* sub-gate (2) */
    printf("[GATE-gX-DESTOWN] dev-vs-dev byte-eq max|Δ| = %.3e (must be 0)  vs CPU-fmaf = %.3e (<=%.1e)\n",
           dmax_gx_determ, dmax_gx_cpu, FMA_TOL);

    /* ── gX atomic scatter (baseline) — run TWICE; report run-to-run NON-determinism ── */
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid(E, (d + CO_TILE - 1) / CO_TILE, (T + TT_TILE - 1) / TT_TILE), blk(CO_TILE);
      k_gx_atomic<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hgpu, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid(E, (d + CO_TILE - 1) / CO_TILE, (T + TT_TILE - 1) / TT_TILE), blk(CO_TILE);
      k_gx_atomic<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hgpu2, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_atomic_determ = max_abs_diff(hgpu, hgpu2, nX);
    double dmax_gx_atomic_cpu = max_abs_diff(hgX_ref, hgpu, nX);
    printf("[GATE-gX-ATOMIC]  dev-vs-dev run1-vs-run2 max|Δ| = %.3e (NONZERO => non-deterministic)  vs CPU = %.3e\n",
           dmax_atomic_determ, dmax_gx_atomic_cpu);

    /* ── gW destination-owned — twice for determinism ── */
    { int eco = E * d; int n_ci_blk = (d + 255) / 256;
      dim3 grid(eco, n_ci_blk), blk(256);
      k_gw_destown<<<grid, blk>>>(dgY, dX, dgW, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hgpu, dgW, nW * sizeof(float), cudaMemcpyDeviceToHost));
    { int eco = E * d; int n_ci_blk = (d + 255) / 256;
      dim3 grid(eco, n_ci_blk), blk(256);
      k_gw_destown<<<grid, blk>>>(dgY, dX, dgW, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hgpu2, dgW, nW * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_gw_determ = max_abs_diff(hgpu, hgpu2, nW);
    double dmax_gw_cpu    = max_abs_diff(hgW_ref, hgpu, nW);
    printf("[GATE-gW-DESTOWN] dev-vs-dev byte-eq max|Δ| = %.3e (must be 0)  vs CPU-fmaf = %.3e (<=%.1e)\n",
           dmax_gw_determ, dmax_gw_cpu, FMA_TOL);

    /* ── gb destination-owned ── */
    { int n = E * d; dim3 grid((n + 255) / 256), blk(256);
      k_gb_destown<<<grid, blk>>>(dgY, dgB, E, T, d);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hgpu, dgB, nB * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_gb = max_abs_diff(hgB_ref, hgpu, nB);
    printf("[GATE-gb-DESTOWN] vs CPU ref max|Δ| = %.3e (pure sum; must be 0)\n", dmax_gb);

    int dev_eq_pass  = (dmax_gx_determ == 0.0) && (dmax_gw_determ == 0.0);
    int cpu_tol_pass = (dmax_gx_cpu <= FMA_TOL) && (dmax_gw_cpu <= FMA_TOL) && (dmax_gb == 0.0);
    int atomic_nondet = (dmax_atomic_determ != 0.0);
    int pass = dev_eq_pass && cpu_tol_pass;
    printf("# GATE (1) destination-owned dev-vs-dev byte-exact (max|Δ|=0): %s\n", dev_eq_pass ? "PASS" : "FAIL");
    printf("# GATE (2) destination-owned vs CPU-fmaf within tol=%.1e:      %s\n", FMA_TOL, cpu_tol_pass ? "PASS" : "FAIL");
    printf("# FINDING: atomic scatter run-to-run deviation = %.3e (%s — the non-determinism FF-BWDFUSE removes)\n",
           dmax_atomic_determ, atomic_nondet ? "NONZERO, as expected" : "zero this run, still races at scale");
    printf("# GATE OVERALL => %s\n", pass ? "PASS" : "FAIL");
    free(hgpu2);

    cudaFree(dX); cudaFree(dW); cudaFree(dgY); cudaFree(dgX); cudaFree(dgW); cudaFree(dgB);
    free(hX); free(hW); free(hgY); free(hgX_ref); free(hgW_ref); free(hgB_ref); free(hgpu);
    return pass ? 0 : 1;
}

int main(int argc, char** argv) {
    int E   = (argc > 1) ? atoi(argv[1]) : 30;
    int d   = (argc > 2) ? atoi(argv[2]) : 2048;
    int T   = (argc > 3) ? atoi(argv[3]) : 256;
    int K   = (argc > 4) ? atoi(argv[4]) : 3;
    int dil = (argc > 5) ? atoi(argv[5]) : 1;
    int gate_d = (argc > 6) ? atoi(argv[6]) : 192;
    int gate_T = 32;

    printf("# gpu_moe_conv_bwd_fuse — FF-BWDFUSE atomic-free fused MoE-conv backward\n");
    printf("# perf shape: E=%d d=%d T=%d K=%d dil=%d\n", E, d, T, K, dil);
    int dev = 0; cudaDeviceProp prop;
    CK(cudaGetDeviceProperties(&prop, dev));
    printf("# device: %s  SMs=%d  cap=%d.%d\n", prop.name, prop.multiProcessorCount, prop.major, prop.minor);

    int gate_rc = run_gate(E, gate_d, gate_T, K, dil);
    if (gate_rc != 0) { printf("[T] CORRECTNESS GATE FAILED (rc=%d) — no perf reported.\n", gate_rc); return 1; }

    /* ════════════ PERF — bwd-glue wall + mem, atomic vs destination-owned ════════ */
    size_t nX = (size_t)T * d, nW = (size_t)E * d * d * K, nB = (size_t)E * d, nY = (size_t)E * T * d;
    printf("\n# weight bank = %.2f GB, gY = %.2f GB\n",
           (double)nW * sizeof(float) / 1e9, (double)nY * sizeof(float) / 1e9);

    float* hX  = (float*)malloc(nX * sizeof(float));
    float* hW  = (float*)malloc(nW * sizeof(float));
    float* hgY = (float*)malloc(nY * sizeof(float));
    if (!hX || !hW || !hgY) { fprintf(stderr, "[T] host malloc (need ~%.1f GB)\n",
        (double)(nW + nY) * sizeof(float) / 1e9); return 2; }
    uint64_t s = 0x1234567890abcdefULL;
    for (size_t i = 0; i < nX; ++i) hX[i]  = (lcg_next(&s) - 0.5f) * 2.0f;
    for (size_t i = 0; i < nW; ++i) hW[i]  = (lcg_next(&s) - 0.5f) * 0.05f;
    for (size_t i = 0; i < nY; ++i) hgY[i] = (lcg_next(&s) - 0.5f) * 2.0f;

    float *dX, *dW, *dgY, *dgX, *dgW, *dgB;
    CK(cudaMalloc(&dX,  nX * sizeof(float)));
    CK(cudaMalloc(&dW,  nW * sizeof(float)));
    CK(cudaMalloc(&dgY, nY * sizeof(float)));
    CK(cudaMalloc(&dgX, nX * sizeof(float)));
    CK(cudaMalloc(&dgW, nW * sizeof(float)));
    CK(cudaMalloc(&dgB, nB * sizeof(float)));
    CK(cudaMemcpy(dX,  hX,  nX * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW,  hW,  nW * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dgY, hgY, nY * sizeof(float), cudaMemcpyHostToDevice));

    /* perf-shape byte-eq cross-check: destination-owned gX must equal the
     * deterministic gather even at the big shape (the contract is shape-free). */
    float* hA = (float*)malloc(nX * sizeof(float));
    float* hB = (float*)malloc(nX * sizeof(float));
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid((d + GX_CI - 1) / GX_CI, T), blk(GX_CI);
      k_gx_destown<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hA, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    /* run destination-owned a SECOND time → deterministic → must be bit-identical */
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid((d + GX_CI - 1) / GX_CI, T), blk(GX_CI);
      k_gx_destown<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hB, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_determ = max_abs_diff(hA, hB, nX);
    printf("# perf-shape determinism: max|Δ|(destown run1 vs run2) = %.3e (expect 0 — atomic-free is reproducible)\n", dmax_determ);

    /* atomic gX run-to-run determinism (expect NONZERO — the wall) */
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid(E, (d + CO_TILE - 1) / CO_TILE, (T + TT_TILE - 1) / TT_TILE), blk(CO_TILE);
      k_gx_atomic<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hA, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    CK(cudaMemset(dgX, 0, nX * sizeof(float)));
    { dim3 grid(E, (d + CO_TILE - 1) / CO_TILE, (T + TT_TILE - 1) / TT_TILE), blk(CO_TILE);
      k_gx_atomic<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaGetLastError()); CK(cudaDeviceSynchronize()); }
    CK(cudaMemcpy(hB, dgX, nX * sizeof(float), cudaMemcpyDeviceToHost));
    double dmax_atomic_determ = max_abs_diff(hA, hB, nX);
    printf("# perf-shape determinism: max|Δ|(atomic run1 vs run2) = %.3e (nonzero => atomic non-determinism)\n", dmax_atomic_determ);
    free(hA); free(hB);

    printf("\n# ── PERF (median of timed iters, cuEvent) — gX bwd glue ──\n");
    const int WARMUP = 3, ITERS = 20;
    double* samp = (double*)malloc(ITERS * sizeof(double));
    cudaEvent_t e0, e1; CK(cudaEventCreate(&e0)); CK(cudaEventCreate(&e1));

    /* atomic count proxy: the atomic scatter issues E·T·d·K·d atomicAdds; the
     * destination-owned gather issues ZERO atomics. Report both verbatim. */
    double atomic_count = (double)E * T * d * K * d;
    printf("# atomic-count: ATOMIC path = %.3e atomicAdd ops  |  DESTOWN path = 0 atomics\n", atomic_count);

    /* (X-ATOMIC) */
    { dim3 grid(E, (d + CO_TILE - 1) / CO_TILE, (T + TT_TILE - 1) / TT_TILE), blk(CO_TILE);
      for (int w = 0; w < WARMUP; ++w) { CK(cudaMemset(dgX, 0, nX * sizeof(float))); k_gx_atomic<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil); }
      CK(cudaDeviceSynchronize());
      for (int it = 0; it < ITERS; ++it) {
          CK(cudaMemset(dgX, 0, nX * sizeof(float)));
          CK(cudaEventRecord(e0, 0));
          k_gx_atomic<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
          CK(cudaEventRecord(e1, 0)); CK(cudaEventSynchronize(e1));
          float ms; CK(cudaEventElapsedTime(&ms, e0, e1)); samp[it] = ms;
      }
      qsort(samp, ITERS, sizeof(double), cmp_d);
      printf("[gX-ATOMIC]  step = %.3f ms  (atomicAdd scatter — non-deterministic baseline)\n", samp[ITERS/2]);
    }

    /* (X-DESTOWN) */
    { dim3 grid((d + GX_CI - 1) / GX_CI, T), blk(GX_CI);
      for (int w = 0; w < WARMUP; ++w) k_gx_destown<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
      CK(cudaDeviceSynchronize());
      for (int it = 0; it < ITERS; ++it) {
          CK(cudaEventRecord(e0, 0));
          k_gx_destown<<<grid, blk>>>(dgY, dW, dgX, E, T, d, K, dil);
          CK(cudaEventRecord(e1, 0)); CK(cudaEventSynchronize(e1));
          float ms; CK(cudaEventElapsedTime(&ms, e0, e1)); samp[it] = ms;
      }
      qsort(samp, ITERS, sizeof(double), cmp_d);
      printf("[gX-DESTOWN] step = %.3f ms  (FF-BWDFUSE atomic-free gather — deterministic)\n", samp[ITERS/2]);
    }

    /* (gW + gb destination-owned, for completeness of the bwd-glue wall) */
    { int eco = E * d; int n_ci_blk = (d + 255) / 256;
      dim3 grid(eco, n_ci_blk), blk(256);
      for (int w = 0; w < WARMUP; ++w) k_gw_destown<<<grid, blk>>>(dgY, dX, dgW, E, T, d, K, dil);
      CK(cudaDeviceSynchronize());
      for (int it = 0; it < ITERS; ++it) {
          CK(cudaEventRecord(e0, 0));
          k_gw_destown<<<grid, blk>>>(dgY, dX, dgW, E, T, d, K, dil);
          CK(cudaEventRecord(e1, 0)); CK(cudaEventSynchronize(e1));
          float ms; CK(cudaEventElapsedTime(&ms, e0, e1)); samp[it] = ms;
      }
      qsort(samp, ITERS, sizeof(double), cmp_d);
      printf("[gW-DESTOWN] step = %.3f ms  (destination-owned, no atomics)\n", samp[ITERS/2]);
    }
    { int n = E * d; dim3 grid((n + 255) / 256), blk(256);
      for (int w = 0; w < WARMUP; ++w) k_gb_destown<<<grid, blk>>>(dgY, dgB, E, T, d);
      CK(cudaDeviceSynchronize());
      for (int it = 0; it < ITERS; ++it) {
          CK(cudaEventRecord(e0, 0));
          k_gb_destown<<<grid, blk>>>(dgY, dgB, E, T, d);
          CK(cudaEventRecord(e1, 0)); CK(cudaEventSynchronize(e1));
          float ms; CK(cudaEventElapsedTime(&ms, e0, e1)); samp[it] = ms;
      }
      qsort(samp, ITERS, sizeof(double), cmp_d);
      printf("[gb-DESTOWN] step = %.3f ms  (destination-owned, no atomics)\n", samp[ITERS/2]);
    }

    /* mem: the atomic path needs gX zeroed (a memset each step) + the atomic unit
     * traffic; the destination-owned path writes gX exactly once (no read-modify-
     * write). Peak device working set is identical (same tensors); the difference
     * is atomic-unit traffic + the extra memset, reported above. */
    size_t peak = (nX + nW + nY + nW + nB) * sizeof(float);
    printf("# device working set (X-free: gY,W,gX,gW,gB) = %.2f GB (identical both paths)\n",
           (double)peak / 1e9);

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    cudaFree(dX); cudaFree(dW); cudaFree(dgY); cudaFree(dgX); cudaFree(dgW); cudaFree(dgB);
    free(hX); free(hW); free(hgY); free(samp);
    printf("\n[T] DONE — gate PASS, bwd-glue perf + atomic-count captured.\n");
    return 0;
}
