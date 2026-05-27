/* a_transformer_aot.cu — forge Phase R / A Stage 2 Phase 2 falsifier
 *
 * Pre-registered hypotheses (RFC 044 §"Falsifier battery" + task spec):
 *   F-FORGE-A-STAGE2-TRANSFORMER: single Llama-style transformer block AOT
 *     trainer ≥ 1.1× PyTorch eager (large model expected 1.5-3×).
 *   F-FORGE-A-STAGE2-FUNCTIONAL: AOT loss numerically matches PyTorch on
 *     same model + same data + same init within reasonable tolerance.
 *
 * Architecture (Llama-style, single block, no biases, FP64):
 *
 *   X[B,L,D]
 *     ├── RMSNorm γ1 → x1
 *     ├── Q = x1 · Wq[D,D]       ; K = x1 · Wk[D,D]       ; V = x1 · Wv[D,D]
 *     ├── (B,nh,L,hd) reshape; causal scaled dot-product attention
 *     │     scores = Q · K^T / sqrt(hd)  (then causal mask)
 *     │     P = softmax(scores)
 *     │     A = P · V
 *     ├── attn_out = A · Wo[D,D]
 *     ├── res1 = X + attn_out
 *     ├── RMSNorm γ2 → x2
 *     ├── gate = x2 · W_gate[D,Df]   ; up = x2 · W_up[D,Df]
 *     ├── h = SiLU(gate) * up   (SwiGLU)
 *     ├── ffn_out = h · W_down[Df,D]
 *     └── Y = res1 + ffn_out
 *
 *   Loss: mean( 0.5 * (Y - target)^2 )  (per-element MSE — simple, well-defined gradient)
 *   Gradient of loss wrt Y: (Y - target) / (B·L·D)
 *
 * Why MSE vs cross-entropy:
 *   - No vocabulary projection needed (avoids extra D×V matmul + softmax over V)
 *   - Trivially differentiable; clear convergence signal
 *   - Matches PyTorch baseline 1-to-1 for functional equivalence check
 *
 * Backward pass is hand-derived from the chain rule (see comments inline).
 * AdamW updates ALL 7 weight tensors + 2 RMSNorm gammas = 9 parameters.
 *
 * cuBLAS Dgemm convention (column-major):
 *   For row-major C[M,N] = A[M,K] · B[K,N] using cuBLAS we call:
 *     cublasDgemm(H, N, N, N, M, K, &alpha, B, N, A, K, &beta, C, N)
 *   i.e. swap operands and pass the "trailing" dimension first.
 *   This trainer follows the same pattern as a_aot_trainer.cu.
 *
 * Configs (3 sizes; small first for debug, then mid, then Llama-7B-ish):
 *   small  : d=512   nh=8   hd=64    L=64   d_ffn=2048  B=1
 *   medium : d=2048  nh=16  hd=128   L=128  d_ffn=5632  B=1
 *   large  : d=4096  nh=32  hd=128   L=512  d_ffn=11008 B=1   (Llama-7B block)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define CK(call) do { \
    cudaError_t _e = (call); \
    if (_e != cudaSuccess) { fprintf(stderr, "[T] CUDA %s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(_e)); exit(1); } \
} while (0)

#define CB(call) do { \
    cublasStatus_t _s = (call); \
    if (_s != CUBLAS_STATUS_SUCCESS) { fprintf(stderr, "[T] cuBLAS %s:%d status=%d\n", __FILE__, __LINE__, (int)_s); exit(1); } \
} while (0)

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static double lcg_next(uint64_t* st) {
    *st = (*st) * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(((*st) >> 11) & 0x1FFFFFFFFFFFFFULL) / (double)(1ULL << 53);
}

static int dbl_cmp(const void* a, const void* b) {
    double aa = *(const double*)a, bb = *(const double*)b;
    return (aa > bb) - (aa < bb);
}

static double median(double* a, int n) {
    qsort(a, n, sizeof(double), dbl_cmp);
    return a[n / 2];
}

/* ===== Custom kernels =====
 *
 * Conventions:
 *   - All tensors are row-major in host-conceptual layout.
 *   - cuBLAS Dgemm calls are emitted with the "swap operands" trick so the
 *     output buffer is also in row-major layout (see header comment).
 *   - For per-row reductions (RMSNorm, softmax) we launch one block per row
 *     and use one thread inside the block. This is intentionally simple and
 *     correct; perf is dominated by cuBLAS Dgemm anyway.
 */

/* RMSNorm forward.
 *   in[N, D] → out[N, D] with cached rrms[N] = 1/sqrt(mean(x^2) + eps).
 *   gamma[D] is the learnable scale.
 *   out[i, j] = in[i, j] * rrms[i] * gamma[j]
 */
__global__ void rmsnorm_fwd(double* out, double* rrms,
                            const double* in, const double* gamma,
                            int N, int D, double eps) {
    int n = blockIdx.x;
    if (n >= N) return;
    if (threadIdx.x != 0) return;
    const double* xrow = in + (size_t)n * D;
    double* orow = out + (size_t)n * D;
    double ss = 0.0;
    for (int j = 0; j < D; j++) ss += xrow[j] * xrow[j];
    double r = 1.0 / sqrt(ss / (double)D + eps);
    rrms[n] = r;
    for (int j = 0; j < D; j++) orow[j] = xrow[j] * r * gamma[j];
}

/* RMSNorm backward.
 *   d_in[i, j] += d_out[i, j] * gamma[j] * rrms[i]
 *                 - x[i, j] * rrms[i]^3 / D * sum_k(d_out[i, k] * gamma[k] * x[i, k])
 *   d_gamma[j] += sum_i( d_out[i, j] * x[i, j] * rrms[i] )
 *
 * We split into two kernels: per-row d_in (one block per row), and a per-column
 * d_gamma reduction (we keep it simple — atomicAdd on d_gamma).
 *
 * (Derivation: y_ij = x_ij · r_i · g_j where r_i = (sum_k x_ik^2 / D + eps)^(-1/2).
 *  ∂y_ij/∂x_ip = δ_jp · r_i · g_j + x_ij · g_j · ∂r_i/∂x_ip
 *  ∂r_i/∂x_ip = -r_i^3 / D · x_ip
 *  ⇒ d_x_ip = r_i · g_p · d_y_ip - x_ip · r_i^3 / D · sum_k(d_y_ik · g_k · x_ik) )
 */
__global__ void rmsnorm_bwd_input(double* d_in,
                                   const double* d_out,
                                   const double* x, const double* gamma,
                                   const double* rrms,
                                   int N, int D) {
    int n = blockIdx.x;
    if (n >= N) return;
    if (threadIdx.x != 0) return;
    const double* xrow = x + (size_t)n * D;
    const double* dyrow = d_out + (size_t)n * D;
    double* dxrow = d_in + (size_t)n * D;
    double r = rrms[n];
    double s = 0.0;
    for (int k = 0; k < D; k++) s += dyrow[k] * gamma[k] * xrow[k];
    double coeff = r * r * r / (double)D * s;
    for (int p = 0; p < D; p++) {
        dxrow[p] = r * gamma[p] * dyrow[p] - xrow[p] * coeff;
    }
}

/* RMSNorm gamma gradient: d_gamma[j] = sum_i d_out[i,j] * x[i,j] * rrms[i] */
__global__ void rmsnorm_bwd_gamma(double* d_gamma,
                                   const double* d_out, const double* x,
                                   const double* rrms,
                                   int N, int D) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    if (j >= D) return;
    double acc = 0.0;
    for (int n = 0; n < N; n++) {
        acc += d_out[(size_t)n * D + j] * x[(size_t)n * D + j] * rrms[n];
    }
    d_gamma[j] = acc;
}

/* Causal softmax with score scaling.
 *   scores[B*nh, L, L]  →  P[B*nh, L, L]
 *   For each row i, set scores[i, j>i] = -inf, then row-softmax with the
 *   max-subtraction trick. We launch one block per (bh, i) and use one
 *   thread (rows are not huge — L ≤ 512). For larger L we'd block-reduce.
 */
__global__ void softmax_causal_scaled(double* P, const double* scores,
                                       int BH, int L, double scale) {
    int bh = blockIdx.y;
    int i = blockIdx.x;
    if (bh >= BH || i >= L) return;
    if (threadIdx.x != 0) return;
    const double* srow = scores + ((size_t)bh * L + i) * L;
    double* prow = P + ((size_t)bh * L + i) * L;
    double m = -1e300;
    for (int j = 0; j <= i; j++) {
        double s = srow[j] * scale;
        prow[j] = s;
        if (s > m) m = s;
    }
    double sum = 0.0;
    for (int j = 0; j <= i; j++) {
        double e = exp(prow[j] - m);
        prow[j] = e;
        sum += e;
    }
    double inv = 1.0 / sum;
    for (int j = 0; j <= i; j++) prow[j] *= inv;
    for (int j = i + 1; j < L; j++) prow[j] = 0.0;
}

/* Backward of (scaled causal softmax) → d_scores from d_P.
 *   d_scores[i, j] = scale * P[i, j] * (d_P[i, j] - sum_k P[i, k] * d_P[i, k])
 * For j > i (masked), d_scores = 0 (P[i,j]=0 makes it auto-zero).
 */
__global__ void softmax_causal_bwd(double* d_scores, const double* d_P, const double* P,
                                    int BH, int L, double scale) {
    int bh = blockIdx.y;
    int i = blockIdx.x;
    if (bh >= BH || i >= L) return;
    if (threadIdx.x != 0) return;
    const double* prow = P + ((size_t)bh * L + i) * L;
    const double* dprow = d_P + ((size_t)bh * L + i) * L;
    double* dsrow = d_scores + ((size_t)bh * L + i) * L;
    double s = 0.0;
    for (int j = 0; j <= i; j++) s += prow[j] * dprow[j];
    for (int j = 0; j <= i; j++) dsrow[j] = scale * prow[j] * (dprow[j] - s);
    for (int j = i + 1; j < L; j++) dsrow[j] = 0.0;
}

/* (attention forward/backward are implemented via cuBLAS strided batched
 * Dgemm + the softmax kernels above; no monolithic per-block kernel.) */

/* SwiGLU forward.  in1 = gate (pre-SiLU), in2 = up.  out = SiLU(gate) * up.
 *   SiLU(x) = x * sigmoid(x) = x / (1 + exp(-x))
 *   sigmoid_cache: store sigmoid(gate) for backward (saves recompute).
 */
__global__ void swiglu_fwd(double* out, double* sig_cache,
                            const double* gate, const double* up, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        double g = gate[i];
        double s = 1.0 / (1.0 + exp(-g));
        sig_cache[i] = s;
        out[i] = (g * s) * up[i];
    }
}

/* SwiGLU backward.
 *   h = SiLU(g) * u
 *   d/dg SiLU(g) = sigma(g) + g * sigma(g) * (1 - sigma(g))
 *                = sigma(g) * (1 + g * (1 - sigma(g)))
 *   d_g[i] = d_h[i] * u[i] * sigma(g[i]) * (1 + g[i] * (1 - sigma(g[i])))
 *   d_u[i] = d_h[i] * SiLU(g[i]) = d_h[i] * g[i] * sigma(g[i])
 */
__global__ void swiglu_bwd(double* d_gate, double* d_up,
                            const double* d_h, const double* gate,
                            const double* up, const double* sig_cache, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) {
        double g = gate[i];
        double s = sig_cache[i];
        double silu = g * s;
        d_up[i] = d_h[i] * silu;
        d_gate[i] = d_h[i] * up[i] * s * (1.0 + g * (1.0 - s));
    }
}

/* Elementwise add: out = a + b */
__global__ void elem_add(double* out, const double* a, const double* b, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) out[i] = a[i] + b[i];
}

/* Elementwise add in place: a += b */
__global__ void elem_add_inplace(double* a, const double* b, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) a[i] += b[i];
}

/* MSE forward + backward in one pass.
 *   loss = 0.5/(N) * sum (y - t)^2
 *   d_y  = (y - t) / N
 *  loss_per_row stores per-row contribution for later host reduction.
 */
__global__ void mse_loss_bwd(double* d_y, double* loss_per_row,
                              const double* y, const double* target,
                              int N, int D) {
    int n = blockIdx.x;
    if (n >= N) return;
    if (threadIdx.x != 0) return;
    const double* yr = y + (size_t)n * D;
    const double* tr = target + (size_t)n * D;
    double* dyr = d_y + (size_t)n * D;
    double s = 0.0;
    double inv = 1.0 / ((double)N * (double)D);
    for (int j = 0; j < D; j++) {
        double e = yr[j] - tr[j];
        dyr[j] = e * inv;
        s += 0.5 * e * e;
    }
    loss_per_row[n] = s / (double)D;
}

/* AdamW fused update.  Same as a_aot_trainer.cu. */
__global__ void adamw_step(double* param, double* m, double* v,
                            const double* grad, int n, int step,
                            double lr, double beta1, double beta2,
                            double eps, double wd) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    double b1t = pow(beta1, (double)step);
    double b2t = pow(beta2, (double)step);
    double bc1 = 1.0 / (1.0 - b1t);
    double bc2 = 1.0 / (1.0 - b2t);
    for (; i < n; i += stride) {
        double g = grad[i];
        double mi = beta1 * m[i] + (1.0 - beta1) * g;
        double vi = beta2 * v[i] + (1.0 - beta2) * g * g;
        m[i] = mi;
        v[i] = vi;
        double mhat = mi * bc1;
        double vhat = vi * bc2;
        double p = param[i];
        param[i] = p - lr * (mhat / (sqrt(vhat) + eps) + wd * p);
    }
}

/* ===== Trainer state =====
 *
 * All matrices are conceptually row-major. cuBLAS calls use the
 * "swap operands" trick to emit row-major outputs.
 *
 * Shapes (per step):
 *   X        : [N, D]   where N = B*L
 *   x1, x2   : [N, D]   (post-RMSNorm activations)
 *   rrms1/2  : [N]      (cached for backward)
 *   Q, K, V  : [N, D]   reinterpretable as [B, nh, L, hd]  (N=B*L, D=nh*hd)
 *   attn_out_raw : [N, D]   (before Wo proj — same as the [B,nh,L,hd] aggregate flattened)
 *   attn_out : [N, D]
 *   res1     : [N, D]
 *   gate, up : [N, Df]
 *   sig_cache: [N, Df]
 *   ffn_h    : [N, Df]
 *   ffn_out  : [N, D]
 *   Y        : [N, D]
 *   target   : [N, D]
 *
 * Weights (no biases, no out-feature swap):
 *   Wq, Wk, Wv, Wo : [D, D]    (treated as Linear(D → D))
 *   W_gate, W_up   : [D, Df]   (treated as Linear(D → Df))
 *   W_down         : [Df, D]   (treated as Linear(Df → D))
 *   gamma1, gamma2 : [D]
 *
 * For each Linear we store: weight + Adam m/v (3 buffers per param tensor).
 *
 * Note: attn_out_raw is the [B, nh, L, hd] aggregate; we then flatten it as
 * [N, D] = [B*L, nh*hd] which is the same layout (since hd-fastest, then L,
 * then nh*B). For Wo projection we need attn_out_raw flattened to [N, D]
 * with D = nh*hd in (h, hd) order. But our forward stores the attention
 * aggregate as the bh-blocked layout (((b nh + h) L) + i) * hd + k = bh order
 * varies fastest by hd, then L (i), then bh. For [N=B*L, D=nh*hd] in (b,L,n h,hd)
 * order — i.e. (b varies slowest, L next, h next, hd fastest) — we DO NOT
 * have that layout natively.
 *
 * Resolution: we use a permutation step. For simplicity in this AOT impl
 * we instead reshape *Q/K/V/attn_out* logically as (B*nh, L, hd) but then
 * for the Wo projection we treat (B*nh*L, hd) collapsed into rows for a
 * Linear(hd → ???). That's wrong dimensionally.
 *
 * Cleaner approach: we choose B=1 in all configs (per task spec) so the
 * permutation simplifies. With B=1, attn_out has layout (nh, L, hd). We
 * then need to convert to (L, nh*hd) for Wo. We add a small transpose
 * kernel `nhLhd_to_LD` for B=1 (and similarly the reverse + transpose for
 * grads in backward).
 *
 * If B>1 we treat B as part of the leading row dimension and do the
 * permutation in two kernels (we keep both, just used for B=1 in practice).
 */

struct trainer {
    /* model dims */
    int B, L, D, nh, hd, Df;
    int N;  /* B*L */
    /* weights */
    double *Wq, *Wk, *Wv, *Wo;
    double *W_gate, *W_up, *W_down;
    double *gamma1, *gamma2;
    /* Adam m/v for each weight */
    double *m_Wq, *m_Wk, *m_Wv, *m_Wo;
    double *m_W_gate, *m_W_up, *m_W_down;
    double *m_gamma1, *m_gamma2;
    double *v_Wq, *v_Wk, *v_Wv, *v_Wo;
    double *v_W_gate, *v_W_up, *v_W_down;
    double *v_gamma1, *v_gamma2;
    /* activations */
    double *X, *target;
    double *x1;   /* [N, D] post RMSNorm 1 */
    double *rrms1;/* [N] */
    double *Q, *K, *V;             /* [N, D] (flat); attention reinterprets as [B,nh,L,hd] */
    /* attn_raw removed — attention computed via cuBLAS batched into attn_out_bnhLhd */
    double *attn_perm;             /* [N, D] in (B, L, nh, hd) packing — input to Wo */
    double *P_cache;               /* [B, nh, L, L] — softmax probabilities (forward cache) */
    double *scores;                /* [B, nh, L, L] — Q·K^T result (overwritten by softmax forward) */
    double *d_P;                   /* [B, nh, L, L] — gradient of P (computed in backward) */
    double *d_scores;              /* [B, nh, L, L] — gradient of scores (computed in backward) */
    double *Q_perm, *K_perm, *V_perm;     /* [B*nh, L, hd] — Q/K/V in (B,nh,L,hd) layout */
    double *attn_out_bnhLhd;       /* [B, nh, L, hd] — P · V output (pre-permute) */
    double *d_attn_out_bnhLhd;     /* [B, nh, L, hd] — d (P · V) (input to attn bwd) */
    double *d_Q_perm, *d_K_perm, *d_V_perm; /* [B*nh, L, hd] in (B,nh,L,hd) layout */
    double *attn_out;              /* [N, D] */
    double *res1;                  /* [N, D] */
    double *x2;                    /* [N, D] */
    double *rrms2;                 /* [N] */
    double *gate, *up;             /* [N, Df] */
    double *sig_cache;             /* [N, Df] */
    double *ffn_h;                 /* [N, Df] (SwiGLU output) */
    double *ffn_out;               /* [N, D] */
    double *Y;                     /* [N, D] */
    /* gradients */
    double *d_Y;
    double *d_ffn_out, *d_res1_from_ffn;
    double *d_ffn_h, *d_gate, *d_up;
    double *d_x2;
    double *d_res1_total, *d_X_residual1, *d_X_from_x1;
    double *d_attn_out, *d_attn_perm;
    double *d_Q, *d_K, *d_V;
    double *d_x1;
    /* weight gradients */
    double *d_Wq, *d_Wk, *d_Wv, *d_Wo;
    double *d_W_gate, *d_W_up, *d_W_down;
    double *d_gamma1, *d_gamma2;
    /* loss */
    double *loss_per_row;
    int step;
    cublasHandle_t cublas;
    cudaStream_t stream;
};

/* Permutation kernels (B, nh, L, hd) ↔ (B, L, nh, hd).  We need them for the
 * Wo projection (attention output → Linear(D→D)) and for the gradient flow
 * back through Wo into the attention block.
 *
 * For B=1 (the configs we run), this is just (nh, L, hd) ↔ (L, nh, hd).
 */
__global__ void perm_BnhLhd_to_BLnhhd(double* out, const double* in,
                                       int B, int nh, int L, int hd) {
    int b = blockIdx.z;
    int l = blockIdx.y;
    int h = blockIdx.x;
    if (b >= B || l >= L || h >= nh) return;
    int tid = threadIdx.x;
    int stride = blockDim.x;
    const double* src = in + ((((size_t)b * nh + h) * L) + l) * hd;
    double* dst = out + ((((size_t)b * L + l) * nh) + h) * hd;
    for (int d = tid; d < hd; d += stride) dst[d] = src[d];
}

__global__ void perm_BLnhhd_to_BnhLhd(double* out, const double* in,
                                       int B, int nh, int L, int hd) {
    int b = blockIdx.z;
    int l = blockIdx.y;
    int h = blockIdx.x;
    if (b >= B || l >= L || h >= nh) return;
    int tid = threadIdx.x;
    int stride = blockDim.x;
    const double* src = in + ((((size_t)b * L + l) * nh) + h) * hd;
    double* dst = out + ((((size_t)b * nh + h) * L) + l) * hd;
    for (int d = tid; d < hd; d += stride) dst[d] = src[d];
}

/* Zero out a buffer. */
__global__ void zero_kern(double* p, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;
    for (; i < n; i += stride) p[i] = 0.0;
}

static void alloc_zero(double** dp, size_t n) {
    CK(cudaMalloc((void**)dp, n * sizeof(double)));
    CK(cudaMemset(*dp, 0, n * sizeof(double)));
}

static void alloc_init(double** dp, size_t n, double scale, uint64_t seed) {
    CK(cudaMalloc((void**)dp, n * sizeof(double)));
    double* h = (double*)malloc(n * sizeof(double));
    uint64_t st = seed;
    for (size_t i = 0; i < n; i++) h[i] = (lcg_next(&st) - 0.5) * scale;
    CK(cudaMemcpy(*dp, h, n * sizeof(double), cudaMemcpyHostToDevice));
    free(h);
}

static void alloc_init_const(double** dp, size_t n, double val) {
    CK(cudaMalloc((void**)dp, n * sizeof(double)));
    double* h = (double*)malloc(n * sizeof(double));
    for (size_t i = 0; i < n; i++) h[i] = val;
    CK(cudaMemcpy(*dp, h, n * sizeof(double), cudaMemcpyHostToDevice));
    free(h);
}

static void trainer_init(struct trainer* t, int B, int L, int D, int nh, int Df) {
    t->B = B; t->L = L; t->D = D; t->nh = nh; t->Df = Df;
    t->hd = D / nh;
    t->N = B * L;
    t->step = 0;
    CB(cublasCreate(&t->cublas));
    CK(cudaStreamCreate(&t->stream));
    CB(cublasSetStream(t->cublas, t->stream));

    /* Kaiming-ish init: scale = sqrt(2 / fan_in) approximation via uniform */
    double sD = 2.0 / sqrt((double)D);
    double sDf = 2.0 / sqrt((double)Df);
    /* weights */
    alloc_init(&t->Wq,     (size_t)D * D,  sD, 0xA10001ULL);
    alloc_init(&t->Wk,     (size_t)D * D,  sD, 0xA10002ULL);
    alloc_init(&t->Wv,     (size_t)D * D,  sD, 0xA10003ULL);
    alloc_init(&t->Wo,     (size_t)D * D,  sD, 0xA10004ULL);
    alloc_init(&t->W_gate, (size_t)D * Df, sD, 0xA10005ULL);
    alloc_init(&t->W_up,   (size_t)D * Df, sD, 0xA10006ULL);
    alloc_init(&t->W_down, (size_t)Df * D, sDf, 0xA10007ULL);
    alloc_init_const(&t->gamma1, (size_t)D, 1.0);
    alloc_init_const(&t->gamma2, (size_t)D, 1.0);
    /* Adam m/v */
    alloc_zero(&t->m_Wq, (size_t)D * D);
    alloc_zero(&t->m_Wk, (size_t)D * D);
    alloc_zero(&t->m_Wv, (size_t)D * D);
    alloc_zero(&t->m_Wo, (size_t)D * D);
    alloc_zero(&t->m_W_gate, (size_t)D * Df);
    alloc_zero(&t->m_W_up,   (size_t)D * Df);
    alloc_zero(&t->m_W_down, (size_t)Df * D);
    alloc_zero(&t->m_gamma1, (size_t)D);
    alloc_zero(&t->m_gamma2, (size_t)D);
    alloc_zero(&t->v_Wq, (size_t)D * D);
    alloc_zero(&t->v_Wk, (size_t)D * D);
    alloc_zero(&t->v_Wv, (size_t)D * D);
    alloc_zero(&t->v_Wo, (size_t)D * D);
    alloc_zero(&t->v_W_gate, (size_t)D * Df);
    alloc_zero(&t->v_W_up,   (size_t)D * Df);
    alloc_zero(&t->v_W_down, (size_t)Df * D);
    alloc_zero(&t->v_gamma1, (size_t)D);
    alloc_zero(&t->v_gamma2, (size_t)D);
    /* activations */
    int N = t->N;
    alloc_zero(&t->X,         (size_t)N * D);
    alloc_zero(&t->target,    (size_t)N * D);
    alloc_zero(&t->x1,        (size_t)N * D);
    alloc_zero(&t->rrms1,     (size_t)N);
    alloc_zero(&t->Q,         (size_t)N * D);
    alloc_zero(&t->K,         (size_t)N * D);
    alloc_zero(&t->V,         (size_t)N * D);
    /* attn_raw retired */
    alloc_zero(&t->attn_perm, (size_t)N * D);
    alloc_zero(&t->P_cache,   (size_t)B * nh * L * L);
    alloc_zero(&t->scores,    (size_t)B * nh * L * L);
    alloc_zero(&t->d_P,       (size_t)B * nh * L * L);
    alloc_zero(&t->d_scores,  (size_t)B * nh * L * L);
    alloc_zero(&t->Q_perm,    (size_t)N * D);
    alloc_zero(&t->K_perm,    (size_t)N * D);
    alloc_zero(&t->V_perm,    (size_t)N * D);
    alloc_zero(&t->attn_out_bnhLhd,   (size_t)N * D);
    alloc_zero(&t->d_attn_out_bnhLhd, (size_t)N * D);
    alloc_zero(&t->d_Q_perm,  (size_t)N * D);
    alloc_zero(&t->d_K_perm,  (size_t)N * D);
    alloc_zero(&t->d_V_perm,  (size_t)N * D);
    alloc_zero(&t->attn_out,  (size_t)N * D);
    alloc_zero(&t->res1,      (size_t)N * D);
    alloc_zero(&t->x2,        (size_t)N * D);
    alloc_zero(&t->rrms2,     (size_t)N);
    alloc_zero(&t->gate,      (size_t)N * Df);
    alloc_zero(&t->up,        (size_t)N * Df);
    alloc_zero(&t->sig_cache, (size_t)N * Df);
    alloc_zero(&t->ffn_h,     (size_t)N * Df);
    alloc_zero(&t->ffn_out,   (size_t)N * D);
    alloc_zero(&t->Y,         (size_t)N * D);
    /* gradients */
    alloc_zero(&t->d_Y,          (size_t)N * D);
    alloc_zero(&t->d_ffn_out,    (size_t)N * D);
    alloc_zero(&t->d_res1_from_ffn, (size_t)N * D);
    alloc_zero(&t->d_ffn_h,      (size_t)N * Df);
    alloc_zero(&t->d_gate,       (size_t)N * Df);
    alloc_zero(&t->d_up,         (size_t)N * Df);
    alloc_zero(&t->d_x2,         (size_t)N * D);
    alloc_zero(&t->d_res1_total, (size_t)N * D);
    alloc_zero(&t->d_X_residual1, (size_t)N * D);
    alloc_zero(&t->d_X_from_x1,  (size_t)N * D);
    alloc_zero(&t->d_attn_out,   (size_t)N * D);
    alloc_zero(&t->d_attn_perm,  (size_t)N * D);
    /* d_attn_raw retired */
    alloc_zero(&t->d_Q,          (size_t)N * D);
    alloc_zero(&t->d_K,          (size_t)N * D);
    alloc_zero(&t->d_V,          (size_t)N * D);
    alloc_zero(&t->d_x1,         (size_t)N * D);
    /* weight grads */
    alloc_zero(&t->d_Wq, (size_t)D * D);
    alloc_zero(&t->d_Wk, (size_t)D * D);
    alloc_zero(&t->d_Wv, (size_t)D * D);
    alloc_zero(&t->d_Wo, (size_t)D * D);
    alloc_zero(&t->d_W_gate, (size_t)D * Df);
    alloc_zero(&t->d_W_up,   (size_t)D * Df);
    alloc_zero(&t->d_W_down, (size_t)Df * D);
    alloc_zero(&t->d_gamma1, (size_t)D);
    alloc_zero(&t->d_gamma2, (size_t)D);
    /* loss */
    alloc_zero(&t->loss_per_row, (size_t)N);

    /* fill X and target with deterministic noise */
    double* hX = (double*)malloc((size_t)N * D * sizeof(double));
    double* hT = (double*)malloc((size_t)N * D * sizeof(double));
    uint64_t st = 0xDEADC0DEULL;
    for (size_t i = 0; i < (size_t)N * D; i++) hX[i] = (lcg_next(&st) - 0.5) * 0.5;
    for (size_t i = 0; i < (size_t)N * D; i++) hT[i] = (lcg_next(&st) - 0.5) * 0.5;
    CK(cudaMemcpy(t->X, hX, (size_t)N * D * sizeof(double), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(t->target, hT, (size_t)N * D * sizeof(double), cudaMemcpyHostToDevice));
    free(hX); free(hT);
}

/* Row-major matmul wrapper.
 *   C[M, N] = op(A)[M, K] · op(B)[K, N]
 * cuBLAS column-major call: cublasDgemm(N, OPB, OPA, N, M, K, &a, B, ldb_eff, A, lda_eff, &b, C, N)
 * where ldb_eff, lda_eff = trailing dim of each operand in its TRANSPOSED-or-not form.
 * Specifically:
 *   if op(B) is "no transpose" → row-major B[K, N] → leading dim in column-major view = N
 *   if op(B) is "transpose"    → original B[N, K] (row-major) → leading dim = K
 *   same for A.
 */
static void rm_gemm(cublasHandle_t H,
                    int transA, int transB,
                    int M, int N, int K,
                    const double* A, const double* B, double* C,
                    double alpha, double beta) {
    int ldb = transB ? K : N;
    int lda = transA ? M : K;
    cublasOperation_t opa = transA ? CUBLAS_OP_T : CUBLAS_OP_N;
    cublasOperation_t opb = transB ? CUBLAS_OP_T : CUBLAS_OP_N;
    /* In column-major C[N×M] = op(B)[N×K] * op(A)[K×M] */
    CB(cublasDgemm(H, opb, opa, N, M, K, &alpha, B, ldb, A, lda, &beta, C, N));
}

/* Row-major strided batched matmul wrapper.
 *   For batch b in [0, batch): C_b[M, N] = op(A_b)[M, K] · op(B_b)[K, N]
 *   where A_b, B_b, C_b are at A + b*sA, B + b*sB, C + b*sC respectively.
 */
static void rm_gemm_strided(cublasHandle_t H,
                             int transA, int transB,
                             int M, int N, int K,
                             const double* A, long long sA,
                             const double* B, long long sB,
                             double* C, long long sC,
                             int batch,
                             double alpha, double beta) {
    int ldb = transB ? K : N;
    int lda = transA ? M : K;
    cublasOperation_t opa = transA ? CUBLAS_OP_T : CUBLAS_OP_N;
    cublasOperation_t opb = transB ? CUBLAS_OP_T : CUBLAS_OP_N;
    CB(cublasDgemmStridedBatched(H, opb, opa, N, M, K,
                                  &alpha,
                                  B, ldb, sB,
                                  A, lda, sA,
                                  &beta,
                                  C, N, sC,
                                  batch));
}

static void trainer_step(struct trainer* t) {
    cublasHandle_t H = t->cublas;
    cudaStream_t st = t->stream;
    int N = t->N, D = t->D, Df = t->Df;
    int B = t->B, L = t->L, nh = t->nh, hd = t->hd;
    double scale_attn = 1.0 / sqrt((double)hd);
    int threads = 256;
    auto blocks_for = [threads](int n) -> int {
        int b = (n + threads - 1) / threads;
        if (b > 65535) b = 65535;
        return b;
    };

    /* ====== FORWARD ====== */

    /* 1) RMSNorm1: x1 = rmsnorm(X, gamma1) */
    rmsnorm_fwd<<<N, 1, 0, st>>>(t->x1, t->rrms1, t->X, t->gamma1, N, D, 1e-6);

    /* 2) Q = x1 @ Wq;  K = x1 @ Wk;  V = x1 @ Wv     ([N, D] = [N, D] · [D, D]) */
    rm_gemm(H, 0, 0, N, D, D, t->x1, t->Wq, t->Q, 1.0, 0.0);
    rm_gemm(H, 0, 0, N, D, D, t->x1, t->Wk, t->K, 1.0, 0.0);
    rm_gemm(H, 0, 0, N, D, D, t->x1, t->Wv, t->V, 1.0, 0.0);

    /* Q/K/V are in row-major [N, D] = [B, L, nh*hd]. To do per-head attention as
     * batched matmul we need them in [B*nh, L, hd] layout. Permute. */
    {
        dim3 g((unsigned)nh, (unsigned)L, (unsigned)B);
        perm_BLnhhd_to_BnhLhd<<<g, 32, 0, st>>>(t->Q_perm, t->Q, B, nh, L, hd);
        perm_BLnhhd_to_BnhLhd<<<g, 32, 0, st>>>(t->K_perm, t->K, B, nh, L, hd);
        perm_BLnhhd_to_BnhLhd<<<g, 32, 0, st>>>(t->V_perm, t->V, B, nh, L, hd);
    }

    /* 3a) scores = Q · K^T per head.  Batched: BH = B*nh batches of [L, hd] · [hd, L] = [L, L]. */
    {
        long long sQ = (long long)L * hd;
        long long sK = (long long)L * hd;
        long long sS = (long long)L * L;
        rm_gemm_strided(H, 0, 1, L, L, hd,
                        t->Q_perm, sQ, t->K_perm, sK, t->scores, sS,
                        B * nh, 1.0, 0.0);
    }

    /* 3b) P = softmax(scores * scale) with causal mask.  Writes into P_cache; also leaves
     *     P_cache[i, j>i] = 0 so the matmul below works without extra masking. */
    {
        dim3 g((unsigned)L, (unsigned)(B * nh));
        softmax_causal_scaled<<<g, 1, 0, st>>>(t->P_cache, t->scores, B * nh, L, scale_attn);
    }

    /* 3c) attn_out_bnhLhd = P · V per head.  Batched: [L, L] · [L, hd] = [L, hd]. */
    {
        long long sP = (long long)L * L;
        long long sV = (long long)L * hd;
        long long sO = (long long)L * hd;
        rm_gemm_strided(H, 0, 0, L, hd, L,
                        t->P_cache, sP, t->V_perm, sV, t->attn_out_bnhLhd, sO,
                        B * nh, 1.0, 0.0);
    }

    /* 3d) Permute [B, nh, L, hd] → [B, L, nh, hd] = attn_perm for the Wo projection. */
    {
        dim3 g((unsigned)nh, (unsigned)L, (unsigned)B);
        perm_BnhLhd_to_BLnhhd<<<g, 32, 0, st>>>(t->attn_perm, t->attn_out_bnhLhd, B, nh, L, hd);
    }

    /* 4) attn_out = attn_perm @ Wo   ([N, D] = [N, D] · [D, D]) */
    rm_gemm(H, 0, 0, N, D, D, t->attn_perm, t->Wo, t->attn_out, 1.0, 0.0);

    /* 5) res1 = X + attn_out */
    {
        int n = N * D, b = blocks_for(n);
        elem_add<<<b, threads, 0, st>>>(t->res1, t->X, t->attn_out, n);
    }

    /* 6) x2 = rmsnorm(res1, gamma2) */
    rmsnorm_fwd<<<N, 1, 0, st>>>(t->x2, t->rrms2, t->res1, t->gamma2, N, D, 1e-6);

    /* 7) gate = x2 @ W_gate;  up = x2 @ W_up     ([N, Df] = [N, D] · [D, Df]) */
    rm_gemm(H, 0, 0, N, Df, D, t->x2, t->W_gate, t->gate, 1.0, 0.0);
    rm_gemm(H, 0, 0, N, Df, D, t->x2, t->W_up,   t->up,   1.0, 0.0);

    /* 8) ffn_h = SwiGLU(gate, up) */
    {
        int n = N * Df, b = blocks_for(n);
        swiglu_fwd<<<b, threads, 0, st>>>(t->ffn_h, t->sig_cache, t->gate, t->up, n);
    }

    /* 9) ffn_out = ffn_h @ W_down   ([N, D] = [N, Df] · [Df, D]) */
    rm_gemm(H, 0, 0, N, D, Df, t->ffn_h, t->W_down, t->ffn_out, 1.0, 0.0);

    /* 10) Y = res1 + ffn_out */
    {
        int n = N * D, b = blocks_for(n);
        elem_add<<<b, threads, 0, st>>>(t->Y, t->res1, t->ffn_out, n);
    }

    /* 11) loss = MSE(Y, target);  d_Y = (Y - target) / (N*D) */
    mse_loss_bwd<<<N, 1, 0, st>>>(t->d_Y, t->loss_per_row, t->Y, t->target, N, D);

    /* ====== BACKWARD ====== */

    /* Y = res1 + ffn_out  →  d_res1 += d_Y;  d_ffn_out = d_Y */
    {
        int n = N * D, b = blocks_for(n);
        /* d_res1_from_ffn collects later contributions; here residual pass-through. */
        CK(cudaMemcpyAsync(t->d_res1_total, t->d_Y, (size_t)n * sizeof(double),
                           cudaMemcpyDeviceToDevice, st));
        CK(cudaMemcpyAsync(t->d_ffn_out, t->d_Y, (size_t)n * sizeof(double),
                           cudaMemcpyDeviceToDevice, st));
    }

    /* ffn_out = ffn_h @ W_down
     *   d_W_down = ffn_h^T @ d_ffn_out  ([Df, D] = [Df, N] · [N, D])
     *   d_ffn_h  = d_ffn_out @ W_down^T ([N, Df] = [N, D] · [D, Df])
     */
    rm_gemm(H, 1, 0, Df, D, N, t->ffn_h,  t->d_ffn_out, t->d_W_down, 1.0, 0.0);
    rm_gemm(H, 0, 1, N, Df, D, t->d_ffn_out, t->W_down, t->d_ffn_h, 1.0, 0.0);

    /* SwiGLU backward: d_gate, d_up from d_ffn_h */
    {
        int n = N * Df, b = blocks_for(n);
        swiglu_bwd<<<b, threads, 0, st>>>(t->d_gate, t->d_up, t->d_ffn_h,
                                           t->gate, t->up, t->sig_cache, n);
    }

    /* gate = x2 @ W_gate   →  d_W_gate = x2^T @ d_gate ; d_x2 += d_gate @ W_gate^T
     * up   = x2 @ W_up     →  d_W_up   = x2^T @ d_up   ; d_x2 += d_up   @ W_up^T
     */
    rm_gemm(H, 1, 0, D, Df, N, t->x2, t->d_gate, t->d_W_gate, 1.0, 0.0);
    rm_gemm(H, 1, 0, D, Df, N, t->x2, t->d_up,   t->d_W_up,   1.0, 0.0);
    rm_gemm(H, 0, 1, N, D, Df, t->d_gate, t->W_gate, t->d_x2, 1.0, 0.0);
    rm_gemm(H, 0, 1, N, D, Df, t->d_up,   t->W_up,   t->d_x2, 1.0, 1.0);  /* accumulate */

    /* RMSNorm2 backward: d_x2 → d_res1 (additive into d_res1_total) + d_gamma2 */
    /* We need a scratch buffer for the additional contribution. Use d_X_from_x1 as scratch. */
    rmsnorm_bwd_input<<<N, 1, 0, st>>>(t->d_X_from_x1, t->d_x2, t->res1, t->gamma2, t->rrms2, N, D);
    rmsnorm_bwd_gamma<<<blocks_for(D), threads, 0, st>>>(t->d_gamma2, t->d_x2, t->res1, t->rrms2, N, D);
    /* Add RMSNorm2 contribution into d_res1_total */
    {
        int n = N * D, b = blocks_for(n);
        elem_add_inplace<<<b, threads, 0, st>>>(t->d_res1_total, t->d_X_from_x1, n);
    }

    /* res1 = X + attn_out  →  d_X (accumulator) += d_res1_total;  d_attn_out = d_res1_total */
    CK(cudaMemcpyAsync(t->d_X_residual1, t->d_res1_total, (size_t)N * D * sizeof(double),
                       cudaMemcpyDeviceToDevice, st));
    CK(cudaMemcpyAsync(t->d_attn_out, t->d_res1_total, (size_t)N * D * sizeof(double),
                       cudaMemcpyDeviceToDevice, st));

    /* attn_out = attn_perm @ Wo
     *   d_Wo       = attn_perm^T @ d_attn_out   ([D, D] = [D, N] · [N, D])
     *   d_attn_perm = d_attn_out @ Wo^T         ([N, D] = [N, D] · [D, D])
     */
    rm_gemm(H, 1, 0, D, D, N, t->attn_perm, t->d_attn_out, t->d_Wo,        1.0, 0.0);
    rm_gemm(H, 0, 1, N, D, D, t->d_attn_out, t->Wo,        t->d_attn_perm, 1.0, 0.0);

    /* Permute d_attn_perm [B, L, nh, hd] → d_attn_out_bnhLhd [B, nh, L, hd] for attn backward. */
    {
        dim3 g((unsigned)nh, (unsigned)L, (unsigned)B);
        perm_BLnhhd_to_BnhLhd<<<g, 32, 0, st>>>(t->d_attn_out_bnhLhd, t->d_attn_perm, B, nh, L, hd);
    }

    /* Attention backward via batched cuBLAS:
     *   out = P · V    →   d_V = P^T · d_out ;   d_P = d_out · V^T
     *   scores → P     →   d_scores = softmax_bwd(d_P, P, scale)
     *   scores = Q · K^T → d_Q = d_scores · K ; d_K = d_scores^T · Q
     */

    /* d_V_perm = P^T · d_out  ([L, hd] = [L, L]^T · [L, hd]) */
    {
        long long sP = (long long)L * L;
        long long sO = (long long)L * hd;
        long long sV = (long long)L * hd;
        rm_gemm_strided(H, 1, 0, L, hd, L,
                        t->P_cache, sP, t->d_attn_out_bnhLhd, sO, t->d_V_perm, sV,
                        B * nh, 1.0, 0.0);
    }
    /* d_P = d_out · V_perm^T  ([L, L] = [L, hd] · [L, hd]^T) */
    {
        long long sO = (long long)L * hd;
        long long sV = (long long)L * hd;
        long long sDP = (long long)L * L;
        rm_gemm_strided(H, 0, 1, L, L, hd,
                        t->d_attn_out_bnhLhd, sO, t->V_perm, sV, t->d_P, sDP,
                        B * nh, 1.0, 0.0);
    }
    /* d_scores = softmax_causal_bwd(d_P, P, scale) */
    {
        dim3 g((unsigned)L, (unsigned)(B * nh));
        softmax_causal_bwd<<<g, 1, 0, st>>>(t->d_scores, t->d_P, t->P_cache, B * nh, L, scale_attn);
    }
    /* d_Q_perm = d_scores · K_perm  ([L, hd] = [L, L] · [L, hd]) */
    {
        long long sDS = (long long)L * L;
        long long sK = (long long)L * hd;
        long long sQ = (long long)L * hd;
        rm_gemm_strided(H, 0, 0, L, hd, L,
                        t->d_scores, sDS, t->K_perm, sK, t->d_Q_perm, sQ,
                        B * nh, 1.0, 0.0);
    }
    /* d_K_perm = d_scores^T · Q_perm  ([L, hd] = [L, L]^T · [L, hd]) */
    {
        long long sDS = (long long)L * L;
        long long sQ = (long long)L * hd;
        long long sK = (long long)L * hd;
        rm_gemm_strided(H, 1, 0, L, hd, L,
                        t->d_scores, sDS, t->Q_perm, sQ, t->d_K_perm, sK,
                        B * nh, 1.0, 0.0);
    }

    /* Permute d_Q/d_K/d_V back to [N, D] = [B, L, nh, hd] for backward through Wq/Wk/Wv. */
    {
        dim3 g((unsigned)nh, (unsigned)L, (unsigned)B);
        perm_BnhLhd_to_BLnhhd<<<g, 32, 0, st>>>(t->d_Q, t->d_Q_perm, B, nh, L, hd);
        perm_BnhLhd_to_BLnhhd<<<g, 32, 0, st>>>(t->d_K, t->d_K_perm, B, nh, L, hd);
        perm_BnhLhd_to_BLnhhd<<<g, 32, 0, st>>>(t->d_V, t->d_V_perm, B, nh, L, hd);
    }

    /* Now d_Q/d_K/d_V are in [N, D] layout matching the original linear projections.
     *
     * Q = x1 @ Wq  →  d_Wq = x1^T @ d_Q ; d_x1 += d_Q @ Wq^T
     * Similarly for K, V.
     */
    rm_gemm(H, 1, 0, D, D, N, t->x1, t->d_Q, t->d_Wq, 1.0, 0.0);
    rm_gemm(H, 1, 0, D, D, N, t->x1, t->d_K, t->d_Wk, 1.0, 0.0);
    rm_gemm(H, 1, 0, D, D, N, t->x1, t->d_V, t->d_Wv, 1.0, 0.0);
    rm_gemm(H, 0, 1, N, D, D, t->d_Q, t->Wq, t->d_x1, 1.0, 0.0);
    rm_gemm(H, 0, 1, N, D, D, t->d_K, t->Wk, t->d_x1, 1.0, 1.0);
    rm_gemm(H, 0, 1, N, D, D, t->d_V, t->Wv, t->d_x1, 1.0, 1.0);

    /* RMSNorm1 backward: d_x1 → d_X (additive into d_X_residual1) + d_gamma1 */
    rmsnorm_bwd_input<<<N, 1, 0, st>>>(t->d_X_from_x1, t->d_x1, t->X, t->gamma1, t->rrms1, N, D);
    rmsnorm_bwd_gamma<<<blocks_for(D), threads, 0, st>>>(t->d_gamma1, t->d_x1, t->X, t->rrms1, N, D);
    {
        int n = N * D, b = blocks_for(n);
        elem_add_inplace<<<b, threads, 0, st>>>(t->d_X_residual1, t->d_X_from_x1, n);
    }
    /* d_X is now in d_X_residual1, but we don't need it (no upstream gradient — X is input). */

    /* ===== AdamW step on all 9 parameters ===== */
    t->step++;
    const double lr = 1e-4, b1 = 0.9, b2 = 0.999, eps = 1e-8, wd = 1e-2;
    {
        int n;
        n = D * D;
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->Wq, t->m_Wq, t->v_Wq, t->d_Wq, n, t->step, lr, b1, b2, eps, wd);
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->Wk, t->m_Wk, t->v_Wk, t->d_Wk, n, t->step, lr, b1, b2, eps, wd);
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->Wv, t->m_Wv, t->v_Wv, t->d_Wv, n, t->step, lr, b1, b2, eps, wd);
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->Wo, t->m_Wo, t->v_Wo, t->d_Wo, n, t->step, lr, b1, b2, eps, wd);
        n = D * Df;
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->W_gate, t->m_W_gate, t->v_W_gate, t->d_W_gate, n, t->step, lr, b1, b2, eps, wd);
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->W_up,   t->m_W_up,   t->v_W_up,   t->d_W_up,   n, t->step, lr, b1, b2, eps, wd);
        n = Df * D;
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->W_down, t->m_W_down, t->v_W_down, t->d_W_down, n, t->step, lr, b1, b2, eps, wd);
        n = D;
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->gamma1, t->m_gamma1, t->v_gamma1, t->d_gamma1, n, t->step, lr, b1, b2, eps, wd);
        adamw_step<<<blocks_for(n), threads, 0, st>>>(t->gamma2, t->m_gamma2, t->v_gamma2, t->d_gamma2, n, t->step, lr, b1, b2, eps, wd);
    }
}

static void trainer_destroy(struct trainer* t) {
    /* not bothering to free all — process exits after this anyway.  Just core handles. */
    cudaStreamDestroy(t->stream);
    cublasDestroy(t->cublas);
}

int main(int argc, char** argv) {
    int n_dev = 0;
    cudaGetDeviceCount(&n_dev);
    if (n_dev <= 0) { fprintf(stderr, "[T] FATAL: no CUDA device\n"); return 1; }

    int cc_major = 0, cc_minor = 0;
    cudaDeviceGetAttribute(&cc_major, cudaDevAttrComputeCapabilityMajor, 0);
    cudaDeviceGetAttribute(&cc_minor, cudaDevAttrComputeCapabilityMinor, 0);
    char pci[256] = "unknown";
    cudaDeviceGetPCIBusId(pci, sizeof(pci), 0);
    size_t mem_free = 0, mem_total = 0;
    cudaMemGetInfo(&mem_free, &mem_total);
    fprintf(stderr, "[T] device 0: pci=%s cc=%d.%d mem=%ld MB\n",
            pci, cc_major, cc_minor, (long)(mem_total >> 20));

    int cublas_major = 0, cublas_minor = 0, cublas_patch = 0;
    cublasHandle_t htmp; cublasCreate(&htmp);
    cublasGetProperty(MAJOR_VERSION, &cublas_major);
    cublasGetProperty(MINOR_VERSION, &cublas_minor);
    cublasGetProperty(PATCH_LEVEL, &cublas_patch);
    cublasDestroy(htmp);

    /* Three configs: small (debug), medium, large (Llama-7B block-ish) */
    struct cfg_t { int B, L, D, nh, Df; int n_warm, n_iter; const char* label; };
    struct cfg_t all_configs[] = {
        { 1,  64,  512,   8,  2048,  3, 30, "small"  },   /* hd=64,  ~few MB */
        { 1, 128, 2048,  16,  5632,  3, 20, "medium" },   /* hd=128, ~tens MB */
        { 1, 512, 4096,  32, 11008,  2, 10, "large"  },   /* hd=128, Llama-7B block */
    };
    const char* preset = (argc > 1) ? argv[1] : "all";
    struct cfg_t configs[3]; int n_cfg = 0;
    for (int i = 0; i < (int)(sizeof(all_configs)/sizeof(all_configs[0])); i++) {
        if (strcmp(preset, "all") == 0 || strcmp(preset, all_configs[i].label) == 0) {
            configs[n_cfg++] = all_configs[i];
        }
    }
    fprintf(stderr, "[T] preset=%s · selected %d configs\n", preset, n_cfg);

    FILE* jf = fopen("result.json", "w");
    if (!jf) { fprintf(stderr, "[T] cannot open result.json\n"); return 2; }
    fprintf(jf, "{\n");
    fprintf(jf, "  \"experiment\": \"forge_phaseR_a_transformer_aot\",\n");
    fprintf(jf, "  \"date\": \"2026-05-17\",\n");
    fprintf(jf, "  \"device_pci\": \"%s\",\n", pci);
    fprintf(jf, "  \"device_cc\": \"%d.%d\",\n", cc_major, cc_minor);
    fprintf(jf, "  \"device_mem_mb\": %ld,\n", (long)(mem_total >> 20));
    fprintf(jf, "  \"cublas_version\": \"%d.%d.%d\",\n", cublas_major, cublas_minor, cublas_patch);
    fprintf(jf, "  \"hypothesis\": \"AOT single-block-transformer train_step >= 1.1x PyTorch eager\",\n");
    fprintf(jf, "  \"configs\": [\n");

    for (int c = 0; c < n_cfg; c++) {
        struct cfg_t* cf = &configs[c];
        fprintf(stderr, "[T] === config: %s B=%d L=%d D=%d nh=%d hd=%d Df=%d (warm=%d iter=%d) ===\n",
                cf->label, cf->B, cf->L, cf->D, cf->nh, cf->D / cf->nh, cf->Df, cf->n_warm, cf->n_iter);
        struct trainer t;
        trainer_init(&t, cf->B, cf->L, cf->D, cf->nh, cf->Df);

        /* Capture initial loss */
        trainer_step(&t);
        CK(cudaStreamSynchronize(t.stream));
        double host_loss[2048] = {0};
        int N_check = (t.N > 2048) ? 2048 : t.N;
        CK(cudaMemcpy(host_loss, t.loss_per_row, N_check * sizeof(double), cudaMemcpyDeviceToHost));
        double initial_loss = 0; for (int i = 0; i < N_check; i++) initial_loss += host_loss[i];
        initial_loss /= N_check;

        /* Warmup */
        for (int w = 0; w < cf->n_warm; w++) trainer_step(&t);
        CK(cudaStreamSynchronize(t.stream));

        /* Time */
        double* samples = (double*)malloc(cf->n_iter * sizeof(double));
        for (int it = 0; it < cf->n_iter; it++) {
            double t0 = now_sec();
            trainer_step(&t);
            CK(cudaStreamSynchronize(t.stream));
            samples[it] = (now_sec() - t0) * 1000.0;
        }
        double med_ms = median(samples, cf->n_iter);
        double min_ms = samples[0];
        double max_ms = samples[cf->n_iter - 1];
        double mean_ms = 0; for (int i = 0; i < cf->n_iter; i++) mean_ms += samples[i];
        mean_ms /= cf->n_iter;
        free(samples);

        /* Final loss */
        CK(cudaMemcpy(host_loss, t.loss_per_row, N_check * sizeof(double), cudaMemcpyDeviceToHost));
        double final_loss = 0; for (int i = 0; i < N_check; i++) final_loss += host_loss[i];
        final_loss /= N_check;

        fprintf(stderr, "[T]   median=%.4f ms · min=%.4f · max=%.4f · mean=%.4f · initial_loss=%.6f · final_loss=%.6f\n",
                med_ms, min_ms, max_ms, mean_ms, initial_loss, final_loss);

        if (c > 0) fprintf(jf, ",\n");
        fprintf(jf,
            "    { \"label\":\"%s\", \"B\":%d, \"L\":%d, \"D\":%d, \"nh\":%d, \"hd\":%d, \"Df\":%d, "
            "\"step_ms_median\":%.6f, \"step_ms_min\":%.6f, \"step_ms_max\":%.6f, "
            "\"step_ms_mean\":%.6f, "
            "\"initial_loss\":%.6f, \"final_loss\":%.6f, \"n_warm\":%d, \"n_iter\":%d }",
            cf->label, cf->B, cf->L, cf->D, cf->nh, cf->D / cf->nh, cf->Df,
            med_ms, min_ms, max_ms, mean_ms, initial_loss, final_loss,
            cf->n_warm, cf->n_iter);

        trainer_destroy(&t);
    }

    fprintf(jf, "\n  ]\n");
    fprintf(jf, "}\n");
    fclose(jf);

    fprintf(stderr, "[T] DONE — %d configs (transformer AOT trainer measurement)\n", n_cfg);
    return 0;
}
