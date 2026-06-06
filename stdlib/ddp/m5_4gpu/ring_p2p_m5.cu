// ════════════════════════════════════════════════════════════════════════════
//  ring_p2p_m5.cu — HEXA-DDP DDP-M5 (collective leg): real 4-GPU ring all-reduce.
//
//  Extends DDP-M3's real-P2P ring (stdlib/ddp/m3_p2p/ring_p2p.cu) from 2 ranks
//  to N=4 ranks on a real 4-GPU node, and MEASURES the all-reduce scaling
//  (per-step wall + 2(N-1) step count) as N grows 2 -> 4.
//
//  The SCHEDULE is the exact same canonical ring proven bit-exact in DDP-M1
//  (stdlib/ddp/ring_all_reduce.hexa) and run on real 2-GPU hardware in DDP-M3:
//  split each rank's length-S vector into N contiguous chunks and run 2(N-1)
//  communication steps —
//    Phase 1 reduce-scatter (N-1 steps): rank r sends one chunk to (r+1)%N,
//      the receiver ADDS it. After N-1 steps each rank owns the full SUM of
//      exactly one distinct chunk.
//    Phase 2 all-gather (N-1 steps): circulate the fully-reduced chunks around
//      the ring (overwrite, no add) so every rank holds the complete sum.
//
//  The ONLY things M5 changes vs M3 are: (1) the rank count N (2 -> 4, taken
//  from env DDP_NUM_GPUS, default 4) and the per-rank device id list — the
//  M3 chunk_start()/schedule already handle general N; (2) per-step wall-clock
//  timing so the scaling note can compare N=2 vs N=4 on the SAME total bytes.
//
//  GATE (g5): the all-reduced result on EVERY GPU == the serial elementwise sum
//  of the N input vectors, byte-eq max|delta|=0, on FP64 buffers, for N=4 with:
//    * S = 13  (S%4 = 1, boundary chunking — NOT a multiple of N), and
//    * S = 1<<20 (large).
//
//  SCALING (g5 honest): we also time the all-reduce wall at N=2 and N=4 on the
//  SAME total bytes (same S) and report per-step wall + the 2(N-1) step count
//  (2 -> 6). Ring all-reduce moves 2(N-1)/N x the per-rank data, so per-rank
//  bandwidth is near-constant while LATENCY grows with N (more steps). We STATE
//  what we measured; we do NOT model. This is the COLLECTIVE at 4-GPU + its
//  scaling — NOT 4-GPU end-to-end training speedup (that is M5b, chains on M4).
//
//  Build:  nvcc -O2 -arch=sm_80 -o ring_p2p_m5 ring_p2p_m5.cu
//  Run:    DDP_NUM_GPUS=4 ./ring_p2p_m5     # gate cases + scaling sweep
// ════════════════════════════════════════════════════════════════════════════
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <algorithm>
#include <vector>
#include <cuda_runtime.h>

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { \
    fprintf(stderr, "CUDA ERROR %s:%d: %s\n", __FILE__, __LINE__, \
            cudaGetErrorString(_e)); exit(1); } } while (0)

// ── chunk boundaries: identical to M1/M3 ring_chunk_start (S split into N
//    chunks; first (S%N) chunks get one extra element). ──────────────────────
static long chunk_start(long S, int N, int c) {
    long base = S / N;
    long rem  = S % N;
    if (c <= rem) return (long)c * (base + 1);
    return rem * (base + 1) + (long)(c - rem) * base;
}

// add: dst[i] += src[i] over [start,stop)
__global__ void add_range(double* dst, const double* src, long start, long stop) {
    long i = start + (long)blockIdx.x * blockDim.x + threadIdx.x;
    if (i < stop) dst[i] += src[i];
}

// ── one full ring all-reduce over the first N visible GPUs. ───────────────────
//   Returns max|delta| vs the serial elementwise sum (0.0 == byte-eq PASS).
//   `wall_ms_out` (optional) receives the wall-clock ms of the 2(N-1)
//   communication-step loop only (alloc/h2d/d2h/gate excluded), so N=2 vs N=4
//   timings compare the COLLECTIVE itself on the same total bytes.
static double ring_all_reduce(int N, const int* dev, long S, double* wall_ms_out) {
    // host input: rank r holds vector r (deterministic, distinct per rank).
    std::vector<std::vector<double>> hin(N, std::vector<double>(S));
    std::vector<double> serial(S, 0.0);
    for (int r = 0; r < N; r++)
        for (long i = 0; i < S; i++) {
            double v = (double)((r * 1000003L + i * 7L + 1) % 9973) - 4096.0;
            hin[r][i] = v;
            serial[i] += v;            // reference: serial elementwise sum
        }

    // device buffers: d[r] lives on GPU r, holds rank r's vector.
    // staging[r] on GPU r receives an incoming chunk before the add.
    std::vector<double*> d(N, nullptr), staging(N, nullptr);
    for (int r = 0; r < N; r++) {
        CK(cudaSetDevice(dev[r]));
        CK(cudaMalloc(&d[r], S * sizeof(double)));
        CK(cudaMalloc(&staging[r], S * sizeof(double)));
        CK(cudaMemcpy(d[r], hin[r].data(), S * sizeof(double), cudaMemcpyHostToDevice));
    }
    for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }

    // ── time ONLY the 2(N-1) communication-step loop ─────────────────────────
    cudaEvent_t t0, t1;
    CK(cudaSetDevice(dev[0]));
    CK(cudaEventCreate(&t0)); CK(cudaEventCreate(&t1));
    CK(cudaEventRecord(t0));

    // ── Phase 1: reduce-scatter (N-1 steps) — schedule identical to M1/M3 ─────
    for (int step = 0; step < N - 1; step++) {
        // simultaneous sends: rank r sends chunk (r-step)%N to (r+1)%N.
        for (int r = 0; r < N; r++) {
            int send_chunk = ((r - step) % N + N) % N;
            int dst = (r + 1) % N;
            long st = chunk_start(S, N, send_chunk);
            long sp = chunk_start(S, N, send_chunk + 1);
            long cnt = sp - st;
            if (cnt <= 0) continue;
            // real inter-GPU transport: GPU r -> GPU dst.
            CK(cudaMemcpyPeer(staging[dst] + st, dev[dst],
                              d[r] + st, dev[r], cnt * sizeof(double)));
        }
        for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
        // apply adds at each receiver (dst += incoming chunk).
        for (int r = 0; r < N; r++) {
            int recv_chunk = ((((r - 1) % N + N) % N - step) % N + N) % N;
            long st = chunk_start(S, N, recv_chunk);
            long sp = chunk_start(S, N, recv_chunk + 1);
            long cnt = sp - st;
            if (cnt <= 0) continue;
            CK(cudaSetDevice(dev[r]));
            int tpb = 256; long blk = (cnt + tpb - 1) / tpb;
            add_range<<<(unsigned)blk, tpb>>>(d[r], staging[r], st, sp);
        }
        for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    }

    // ── Phase 2: all-gather (N-1 steps) — overwrite, no add ───────────────────
    for (int step = 0; step < N - 1; step++) {
        for (int r = 0; r < N; r++) {
            int send_chunk = ((r - step + 1) % N + N) % N;
            int dst = (r + 1) % N;
            long st = chunk_start(S, N, send_chunk);
            long sp = chunk_start(S, N, send_chunk + 1);
            long cnt = sp - st;
            if (cnt <= 0) continue;
            CK(cudaMemcpyPeer(d[dst] + st, dev[dst],
                              d[r] + st, dev[r], cnt * sizeof(double)));
        }
        for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaDeviceSynchronize()); }
    }

    CK(cudaSetDevice(dev[0]));
    CK(cudaEventRecord(t1)); CK(cudaEventSynchronize(t1));
    float ms = 0.0f; CK(cudaEventElapsedTime(&ms, t0, t1));
    if (wall_ms_out) *wall_ms_out = (double)ms;
    CK(cudaEventDestroy(t0)); CK(cudaEventDestroy(t1));

    // ── gate: every GPU's buffer == serial elementwise sum, max|delta|=0 ──────
    double max_abs_diff = 0.0;
    for (int r = 0; r < N; r++) {
        std::vector<double> hout(S);
        CK(cudaSetDevice(dev[r]));
        CK(cudaMemcpy(hout.data(), d[r], S * sizeof(double), cudaMemcpyDeviceToHost));
        for (long i = 0; i < S; i++) {
            double dlt = fabs(hout[i] - serial[i]);
            if (dlt > max_abs_diff) max_abs_diff = dlt;
        }
    }

    for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaFree(d[r])); CK(cudaFree(staging[r])); }
    return max_abs_diff;
}

int main(int argc, char** argv) {
    int ndev = 0;
    CK(cudaGetDeviceCount(&ndev));
    printf("=== ring_p2p_m5 :: visible CUDA devices = %d ===\n", ndev);

    int N = 4;
    const char* envN = getenv("DDP_NUM_GPUS");
    if (envN && *envN) { int v = atoi(envN); if (v >= 2) N = v; }
    if (ndev < N) {
        printf("FATAL: need >= %d GPUs on one node for DDP-M5 (found %d)\n", N, ndev);
        return 3;
    }
    printf("ranks N = %d  (2(N-1) = %d communication steps)\n", N, 2 * (N - 1));

    std::vector<int> dev(N);
    for (int r = 0; r < N; r++) dev[r] = r;

    // ── peer access: canAccessPeer probe + enable all directed pairs ─────────
    int p2p_all = 1, p2p_any = 0;
    for (int a = 0; a < N; a++)
        for (int b = 0; b < N; b++) {
            if (a == b) continue;
            int can = 0;
            CK(cudaDeviceCanAccessPeer(&can, dev[a], dev[b]));
            printf("cudaDeviceCanAccessPeer(%d->%d) = %d\n", dev[a], dev[b], can);
            if (can) {
                p2p_any = 1;
                CK(cudaSetDevice(dev[a]));
                cudaError_t e = cudaDeviceEnablePeerAccess(dev[b], 0);
                if (e != cudaSuccess && e != cudaErrorPeerAccessAlreadyEnabled) {
                    fprintf(stderr, "enablePeerAccess(%d->%d): %s\n",
                            dev[a], dev[b], cudaGetErrorString(e));
                }
            } else {
                p2p_all = 0;
            }
        }
    const char* transport = p2p_all ? "direct P2P (cudaMemcpyPeer, NVLink/PCIe)"
                          : p2p_any ? "MIXED direct-P2P + host-staged (cudaMemcpyPeer)"
                                    : "staged host copy (cudaMemcpyPeer routes via host)";
    printf("transport = %s\n", transport);

    int rc = 0;

    // ── gate cases: S=13 (S%4=1 boundary, NOT a multiple of N) + large S ─────
    long cases[] = {13, (1L << 20)};
    for (int ci = 0; ci < 2; ci++) {
        long S = cases[ci];
        printf("\n--- GATE case N=%d S=%ld (S%%N=%ld) ---\n", N, S, S % N);
        double md = ring_all_reduce(N, dev.data(), S, nullptr);
        printf("N=%d S=%ld : max|delta| vs serial-sum = %.17g  %s\n",
               N, S, md, (md == 0.0) ? "BYTE-EQ PASS" : "FAIL");
        if (md != 0.0) rc = 1;
    }

    // ── scaling sweep: per-step wall at N=2 vs N=4 on the SAME total bytes ────
    //   (median of REPS warm runs; first run discarded as warmup). We report
    //   the all-reduce wall and the per-STEP wall (= wall / 2(N-1)).
    printf("\n=== SCALING SWEEP (same total bytes; per-step wall) ===\n");
    long S_scale = (1L << 22);                 // 4M doubles = 32 MiB per rank
    int REPS = 6;
    int Nlist[] = {2, N};                       // 2 then the full N (=4)
    int nN = (N == 2) ? 1 : 2;
    for (int k = 0; k < nN; k++) {
        int Nk = Nlist[k];
        if (ndev < Nk) { printf("  (skip N=%d: only %d GPUs)\n", Nk, ndev); continue; }
        std::vector<double> walls;
        double md_last = 0.0;
        for (int rep = 0; rep < REPS; rep++) {
            double w = 0.0;
            md_last = ring_all_reduce(Nk, dev.data(), S_scale, &w);
            if (rep > 0) walls.push_back(w);     // discard warmup rep 0
        }
        // median
        std::sort(walls.begin(), walls.end());
        double med = walls.empty() ? 0.0 :
            (walls.size() % 2 ? walls[walls.size()/2]
                              : 0.5*(walls[walls.size()/2 - 1] + walls[walls.size()/2]));
        int steps = 2 * (Nk - 1);
        double per_step = steps ? med / steps : med;
        printf("  N=%d  steps=2(N-1)=%d  S=%ld  all-reduce wall(median)=%.4f ms"
               "  per-step=%.4f ms  byte-eq(md)=%.17g %s\n",
               Nk, steps, S_scale, med, per_step, md_last,
               (md_last == 0.0) ? "PASS" : "FAIL");
        if (md_last != 0.0) rc = 1;
    }

    printf("\n=== DDP-M5 (collective leg) verdict: %s ===\n",
           rc == 0 ? "GREEN - 4-rank ring all-reduce byte-eq over real multi-GPU + scaling measured"
                   : "RED");
    printf("transport=%s\n", transport);
    return rc;
}
