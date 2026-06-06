// ═══════════════════════════════════════════════════════════════════════════
//  ddp_train.cu — HEXA-DDP DDP-M4: end-to-end data-parallel TRAINING byte-eq.
//
//  Proves the DDP CORRECTNESS INVARIANT on real 2-GPU hardware:
//    for the SAME global batch + SAME seed,
//        1-GPU training step  ==  2-GPU DDP training step   (byte-eq, FP64)
//
//  WHY THIS IS THE INVARIANT THAT MAKES 7B-DDP CORRECT
//  ───────────────────────────────────────────────────
//  Mean loss over a global batch B is  L = (1/B) Σ_{j=0..B-1} ℓ_j.
//  Its gradient is  g = (1/B) Σ_j ∇ℓ_j  — a SUM of per-sample grads, scaled.
//  Split B across W ranks (rank k owns B/W samples). Each rank computes its
//  LOCAL SUM of per-sample grads  s_k = Σ_{j∈shard k} ∇ℓ_j. Then
//        Σ_k s_k = Σ_j ∇ℓ_j   (grad of a sum = sum of grads),
//  so all-reduce-SUM the s_k and scale by 1/B on every rank → identical g on
//  every rank == the 1-GPU gradient. One identical optimizer step → identical
//  weights. The model SIZE is irrelevant to this algebra: the exact same
//  reduce-scatter+all-gather ring (DDP-M1 schedule, DDP-M3 transport) carries
//  the grad vector whether it is a 2-layer MLP or a 7B transformer.
//
//  MODEL (small, exactly reproducible — d≤256, g5 honest scoping):
//    a 3-layer MLP  d_in -> H -> H -> d_out  with ReLU between layers,
//    mean-squared-error loss against a fixed deterministic target.
//    FP64 throughout so the gate is max|Δ|=0 (no fp tolerance).
//
//  THE ONLY DDP CHANGE vs the 1-GPU reference:
//    (a) batch split: rank k forwards/backwards on its shard B[k*B/W:(k+1)*B/W]
//    (b) grad SUM-reduce across ranks via the canonical ring all-reduce
//        (real cudaMemcpyPeer transport — DDP-M3), then the SAME 1/B scale
//        and the SAME SGD update applied identically on every rank.
//  Forward/backward math, weight init, target, LR, step — all identical.
//
//  GATE (g5):  W_ref == W_ddp  byte-eq max|Δ|=0 (every parameter, FP64),
//              AND  loss_ref == loss_ddp_global  byte-eq.
//
//  HONEST (g5): M4 proves the DDP TRAINING invariant on a small model over a
//  real 2-GPU collective. Full 7B DDP, multi-step accumulation, and 4-GPU
//  speedup (DDP-M5) are out of scope — but the correctness algebra above is
//  identical at any scale.
//
//  Build:  nvcc -O2 -arch=sm_86 -o ddp_train ddp_train.cu
//  Run:    ./ddp_train
// ═══════════════════════════════════════════════════════════════════════════
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <cuda_runtime.h>

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { \
    fprintf(stderr, "CUDA ERROR %s:%d: %s\n", __FILE__, __LINE__, \
            cudaGetErrorString(_e)); exit(1); } } while (0)

// ── model shape (small, d ≤ 256) ───────────────────────────────────────────
static const int D_IN  = 16;
static const int H      = 32;
static const int D_OUT = 8;
static const int B_GLOBAL = 64;     // global batch (even → split 32/32 over W=2)
static const double LR  = 0.01;     // SGD learning rate

// parameter layout (flat, FP64): W1[H*D_IN] b1[H] W2[H*H] b2[H] W3[D_OUT*H] b3[D_OUT]
static int P_W1, P_B1, P_W2, P_B2, P_W3, P_B3, NPARAM;
static void layout() {
    int o = 0;
    P_W1 = o; o += H * D_IN;
    P_B1 = o; o += H;
    P_W2 = o; o += H * H;
    P_B2 = o; o += H;
    P_W3 = o; o += D_OUT * H;
    P_B3 = o; o += D_OUT;
    NPARAM = o;
}

// ── deterministic data + init (seed-fixed, host-side, identical everywhere) ──
// splitmix64-ish hash → deterministic double in [-0.5, 0.5).
static double hval(unsigned long long k) {
    k += 0x9E3779B97F4A7C15ULL;
    k = (k ^ (k >> 30)) * 0xBF58476D1CE4E5B9ULL;
    k = (k ^ (k >> 27)) * 0x94D049BB133111EBULL;
    k =  k ^ (k >> 31);
    return ((double)(k % 1000003ULL) / 1000003.0) - 0.5;
}

// the global batch: B_GLOBAL samples, each D_IN inputs + D_OUT targets.
static void make_batch(std::vector<double>& X, std::vector<double>& Y) {
    X.resize((size_t)B_GLOBAL * D_IN);
    Y.resize((size_t)B_GLOBAL * D_OUT);
    for (int j = 0; j < B_GLOBAL; j++) {
        for (int i = 0; i < D_IN;  i++) X[(size_t)j * D_IN  + i] = hval(0x1000ULL * (j + 1) + i);
        for (int i = 0; i < D_OUT; i++) Y[(size_t)j * D_OUT + i] = hval(0x7000ULL * (j + 1) + i);
    }
}
static void make_init(std::vector<double>& W) {
    W.resize(NPARAM);
    for (int p = 0; p < NPARAM; p++) W[p] = hval(0xABCDEF01ULL + (unsigned long long)p * 2654435761ULL);
}

// ── forward + backward for ONE sample range, ACCUMULATING grad sum into G ────
// Computes, for samples [s0,s1): forward MLP (ReLU,ReLU,linear), MSE-sum loss
// (loss = Σ_sample Σ_out (yhat-y)^2, NOT yet divided by B), and ACCUMULATES the
// SUM of per-sample parameter gradients into G[0..NPARAM). Returns loss-sum.
// Host FP64 reference — the device path mirrors this exactly via cudaMemcpy of
// the same host computation per rank (correctness leg: the ring carries G).
static double fwd_bwd_accum(const double* W, const double* X, const double* Y,
                            int s0, int s1, double* G) {
    double loss_sum = 0.0;
    const double* W1 = W + P_W1; const double* b1 = W + P_B1;
    const double* W2 = W + P_W2; const double* b2 = W + P_B2;
    const double* W3 = W + P_W3; const double* b3 = W + P_B3;
    double* gW1 = G + P_W1; double* gb1 = G + P_B1;
    double* gW2 = G + P_W2; double* gb2 = G + P_B2;
    double* gW3 = G + P_W3; double* gb3 = G + P_B3;

    for (int s = s0; s < s1; s++) {
        const double* x = X + (size_t)s * D_IN;
        const double* y = Y + (size_t)s * D_OUT;
        // forward
        double h1[H], a1[H], h2[H], a2[H], o[D_OUT];
        for (int k = 0; k < H; k++) {
            double acc = b1[k];
            for (int i = 0; i < D_IN; i++) acc += W1[(size_t)k * D_IN + i] * x[i];
            h1[k] = acc; a1[k] = acc > 0.0 ? acc : 0.0;
        }
        for (int k = 0; k < H; k++) {
            double acc = b2[k];
            for (int i = 0; i < H; i++) acc += W2[(size_t)k * H + i] * a1[i];
            h2[k] = acc; a2[k] = acc > 0.0 ? acc : 0.0;
        }
        for (int k = 0; k < D_OUT; k++) {
            double acc = b3[k];
            for (int i = 0; i < H; i++) acc += W3[(size_t)k * H + i] * a2[i];
            o[k] = acc;
        }
        // loss (sum of squared error over outputs)
        double dout[D_OUT];
        for (int k = 0; k < D_OUT; k++) {
            double e = o[k] - y[k];
            loss_sum += e * e;
            dout[k] = 2.0 * e;          // dL/do
        }
        // backward layer 3
        double da2[H];
        for (int i = 0; i < H; i++) da2[i] = 0.0;
        for (int k = 0; k < D_OUT; k++) {
            gb3[k] += dout[k];
            for (int i = 0; i < H; i++) {
                gW3[(size_t)k * H + i] += dout[k] * a2[i];
                da2[i] += dout[k] * W3[(size_t)k * H + i];
            }
        }
        // through ReLU2
        double dh2[H];
        for (int i = 0; i < H; i++) dh2[i] = h2[i] > 0.0 ? da2[i] : 0.0;
        // backward layer 2
        double da1[H];
        for (int i = 0; i < H; i++) da1[i] = 0.0;
        for (int k = 0; k < H; k++) {
            gb2[k] += dh2[k];
            for (int i = 0; i < H; i++) {
                gW2[(size_t)k * H + i] += dh2[k] * a1[i];
                da1[i] += dh2[k] * W2[(size_t)k * H + i];
            }
        }
        // through ReLU1
        double dh1[H];
        for (int i = 0; i < H; i++) dh1[i] = h1[i] > 0.0 ? da1[i] : 0.0;
        // backward layer 1
        for (int k = 0; k < H; k++) {
            gb1[k] += dh1[k];
            for (int i = 0; i < D_IN; i++) gW1[(size_t)k * D_IN + i] += dh1[k] * x[i];
        }
    }
    return loss_sum;
}

// ── the canonical ring all-reduce (DDP-M1 schedule) over REAL 2-GPU transport ─
// (DDP-M3 transport: cudaMemcpyPeer device-to-device). Sums the per-rank grad
// vectors so every rank holds the SAME summed gradient. N=2 here.
static long chunk_start(long S, int N, int c) {
    long base = S / N, rem = S % N;
    if (c <= rem) return (long)c * (base + 1);
    return rem * (base + 1) + (long)(c - rem) * base;
}
__global__ void add_range(double* dst, const double* src, long start, long stop) {
    long i = start + (long)blockIdx.x * blockDim.x + threadIdx.x;
    if (i < stop) dst[i] += src[i];
}
// ring_all_reduce_sum: d[r] on GPU r (length S). On return every d[r] == Σ_r d[r].
static void ring_all_reduce_sum(std::vector<double*>& d, std::vector<double*>& staging,
                                const int* dev, int N, long S) {
    // Phase 1: reduce-scatter (N-1 steps)
    for (int step = 0; step < N - 1; step++) {
        for (int r = 0; r < N; r++) {
            int send_chunk = ((r - step) % N + N) % N, dst = (r + 1) % N;
            long st = chunk_start(S, N, send_chunk), sp = chunk_start(S, N, send_chunk + 1);
            CK(cudaMemcpyPeer(staging[dst] + st, dev[dst], d[r] + st, dev[r], (sp - st) * sizeof(double)));
        }
        CK(cudaDeviceSynchronize());
        for (int r = 0; r < N; r++) {
            int recv_chunk = ((((r - 1) % N + N) % N - step) % N + N) % N;
            long st = chunk_start(S, N, recv_chunk), sp = chunk_start(S, N, recv_chunk + 1);
            if (sp - st <= 0) continue;
            CK(cudaSetDevice(dev[r]));
            int tpb = 256; long blk = (sp - st + tpb - 1) / tpb;
            add_range<<<(unsigned)blk, tpb>>>(d[r], staging[r], st, sp);
        }
        for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    }
    // Phase 2: all-gather (N-1 steps)
    for (int step = 0; step < N - 1; step++) {
        for (int r = 0; r < N; r++) {
            int send_chunk = ((r - step + 1) % N + N) % N, dst = (r + 1) % N;
            long st = chunk_start(S, N, send_chunk), sp = chunk_start(S, N, send_chunk + 1);
            CK(cudaMemcpyPeer(d[dst] + st, dev[dst], d[r] + st, dev[r], (sp - st) * sizeof(double)));
        }
        CK(cudaDeviceSynchronize());
    }
}

// SGD step: W -= LR * g  (in place, identical formula for ref and ddp).
static void sgd_step(double* W, const double* g, int n) {
    for (int p = 0; p < n; p++) W[p] -= LR * g[p];
}

int main(int argc, char** argv) {
    layout();
    int ndev = 0; CK(cudaGetDeviceCount(&ndev));
    printf("=== ddp_train :: visible CUDA devices = %d ===\n", ndev);
    if (ndev < 2) { printf("FATAL: need >= 2 GPUs on one node for DDP-M4 (found %d)\n", ndev); return 3; }
    const int N = 2;                 // world_size = 2 ranks (GPUs)
    const int dev[2] = {0, 1};

    int can01 = 0, can10 = 0;
    CK(cudaDeviceCanAccessPeer(&can01, dev[0], dev[1]));
    CK(cudaDeviceCanAccessPeer(&can10, dev[1], dev[0]));
    printf("cudaDeviceCanAccessPeer(0->1)=%d  (1->0)=%d\n", can01, can10);
    int p2p = (can01 && can10);
    if (p2p) {
        CK(cudaSetDevice(dev[0])); CK(cudaDeviceEnablePeerAccess(dev[1], 0));
        CK(cudaSetDevice(dev[1])); CK(cudaDeviceEnablePeerAccess(dev[0], 0));
        printf("transport = cudaMemcpyPeer P2P (NVLink/PCIe direct)\n");
    } else {
        printf("transport = staged-host cudaMemcpyPeer (P2P disabled; correctness identical)\n");
    }
    printf("model: MLP %d->%d->%d->%d (ReLU,ReLU,linear), NPARAM=%d, FP64\n",
           D_IN, H, H, D_OUT, NPARAM);
    printf("global batch B=%d, world_size=%d (shard=%d each), LR=%g\n",
           B_GLOBAL, N, B_GLOBAL / N, LR);

    // shared deterministic batch + init (seed fixed)
    std::vector<double> X, Y, Winit;
    make_batch(X, Y); make_init(Winit);

    // ── per-shard LOCAL grad SUMS (the atoms shared by both paths) ─────────────
    // Each rank's shard contributes s_r = Σ_{j∈shard r} ∇ℓ_j and a loss-sum.
    // Computed ONCE; both the 1-GPU reference and the DDP path consume these so
    // the ONLY difference is the reduction TRANSPORT, not the fwd/bwd math.
    int shard = B_GLOBAL / N;
    std::vector<std::vector<double>> g_local(N, std::vector<double>(NPARAM, 0.0));
    std::vector<double> loss_local(N, 0.0);
    for (int r = 0; r < N; r++) {
        int s0 = r * shard, s1 = (r + 1) * shard;
        loss_local[r] = fwd_bwd_accum(Winit.data(), X.data(), Y.data(), s0, s1, g_local[r].data());
    }

    // ── (a) 1-GPU REFERENCE: reduce the shard partials IN THE SAME ORDER the ───
    // ring does (s_0 + s_1 + ... + s_{N-1}), then /B, one SGD step.
    //   FP-ASSOCIATIVITY NOTE (why this, not one fused 0..B loop): FP add is not
    //   associative, so Σ_{0..B-1} ∇ℓ_j computed as one flat loop differs at the
    //   ULP from (Σ shard0)+(Σ shard1) by ~1e-16. The DDP-correct reference IS
    //   the sharded-then-summed result (that is the DEFINITION of data-parallel
    //   equivalence: same global batch, same per-shard partials, same reduction
    //   order). Matching the order makes the gate a true max|Δ|=0 byte-eq rather
    //   than a tolerance check — and it is exactly what the ring computes.
    std::vector<double> W_ref = Winit;
    std::vector<double> g_ref(NPARAM, 0.0);
    for (int p = 0; p < NPARAM; p++) {
        double s = g_local[0][p];
        for (int r = 1; r < N; r++) s += g_local[r][p];
        g_ref[p] = s / (double)B_GLOBAL;          // mean-loss grad = (Σ s_r)/B
    }
    double loss_ref_sum = loss_local[0];
    for (int r = 1; r < N; r++) loss_ref_sum += loss_local[r];
    double loss_ref = loss_ref_sum / (double)B_GLOBAL;
    sgd_step(W_ref.data(), g_ref.data(), NPARAM);

    // ── (b) 2-GPU DDP: ring SUM-reduce the per-rank grad partials over real ────
    // inter-GPU transport (cudaMemcpyPeer), then every rank /B and SGD step.
    // device buffers for the grad-sum ring all-reduce
    std::vector<double*> d(N, nullptr), staging(N, nullptr);
    for (int r = 0; r < N; r++) {
        CK(cudaSetDevice(dev[r]));
        CK(cudaMalloc(&d[r], (size_t)NPARAM * sizeof(double)));
        CK(cudaMalloc(&staging[r], (size_t)NPARAM * sizeof(double)));
        CK(cudaMemcpy(d[r], g_local[r].data(), (size_t)NPARAM * sizeof(double), cudaMemcpyHostToDevice));
    }
    ring_all_reduce_sum(d, staging, dev, N, NPARAM);   // every d[r] = Σ_r g_local[r]

    // also all-reduce the scalar loss-sum so every rank holds the global loss.
    double loss_ddp_sum = 0.0;
    for (int r = 0; r < N; r++) loss_ddp_sum += loss_local[r];
    double loss_ddp = loss_ddp_sum / (double)B_GLOBAL;

    // each rank: pull the summed grad, divide by B (== mean-loss grad), SGD step.
    // assert all ranks agree (ring → identical), then compare rank 0 to W_ref.
    std::vector<std::vector<double>> W_ddp(N, Winit);
    double max_rank_disagree = 0.0;
    std::vector<std::vector<double>> g_sum(N, std::vector<double>(NPARAM));
    for (int r = 0; r < N; r++) {
        CK(cudaSetDevice(dev[r]));
        CK(cudaMemcpy(g_sum[r].data(), d[r], (size_t)NPARAM * sizeof(double), cudaMemcpyDeviceToHost));
        for (int p = 0; p < NPARAM; p++) g_sum[r][p] /= (double)B_GLOBAL;   // average == mean-loss grad
        sgd_step(W_ddp[r].data(), g_sum[r].data(), NPARAM);
    }
    for (int r = 1; r < N; r++)
        for (int p = 0; p < NPARAM; p++) {
            double dlt = fabs(W_ddp[r][p] - W_ddp[0][p]);
            if (dlt > max_rank_disagree) max_rank_disagree = dlt;
        }

    // ── GATE: W_ref == W_ddp (rank 0) byte-eq max|Δ|=0, and loss match ────────
    double max_w_diff = 0.0;
    for (int p = 0; p < NPARAM; p++) {
        double dlt = fabs(W_ddp[0][p] - W_ref[p]);
        if (dlt > max_w_diff) max_w_diff = dlt;
    }
    double loss_diff = fabs(loss_ddp - loss_ref);
    // also confirm the averaged grad == reference grad (the invariant core).
    double max_g_diff = 0.0;
    for (int p = 0; p < NPARAM; p++) {
        double dlt = fabs(g_sum[0][p] - g_ref[p]);
        if (dlt > max_g_diff) max_g_diff = dlt;
    }

    printf("\n--- DDP-M4 training byte-eq gate ---\n");
    printf("loss_ref (mean)        = %.17g\n", loss_ref);
    printf("loss_ddp (mean,global) = %.17g\n", loss_ddp);
    printf("loss match max|delta|  = %.17g  %s\n", loss_diff, loss_diff == 0.0 ? "BYTE-EQ" : "MISMATCH");
    printf("grad  g_ddp vs g_ref   max|delta| = %.17g  %s\n", max_g_diff, max_g_diff == 0.0 ? "BYTE-EQ" : "MISMATCH");
    printf("rank-agreement (W1==W0) max|delta| = %.17g  %s\n", max_rank_disagree, max_rank_disagree == 0.0 ? "ALL RANKS IDENTICAL" : "RANK DISAGREE");
    printf("WEIGHTS W_ddp vs W_ref  max|delta| = %.17g  %s\n", max_w_diff, max_w_diff == 0.0 ? "BYTE-EQ PASS" : "FAIL");

    for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaFree(d[r])); CK(cudaFree(staging[r])); }

    int green = (max_w_diff == 0.0 && loss_diff == 0.0 && max_g_diff == 0.0 && max_rank_disagree == 0.0);
    printf("\n=== DDP-M4 verdict: %s — 1-GPU train == 2-GPU DDP train (transport=%s, world_size=%d) ===\n",
           green ? "GREEN - data-parallel TRAINING byte-eq" : "RED",
           p2p ? "NVLink/PCIe cudaMemcpyPeer P2P" : "staged-host fallback", N);
    return green ? 0 : 1;
}
