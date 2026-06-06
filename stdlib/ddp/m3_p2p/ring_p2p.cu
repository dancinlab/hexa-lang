// ════════════════════════════════════════════════════════════════════════════
//  ring_p2p.cu — HEXA-DDP DDP-M3: real 2-GPU ring all-reduce over P2P transport.
//
//  This is the REAL-HARDWARE leg of the ring all-reduce. The SCHEDULE is the
//  exact same canonical ring proven bit-exact in DDP-M1
//  (stdlib/ddp/ring_all_reduce.hexa): split each rank's length-S vector into N
//  contiguous chunks and run 2(N-1) communication steps —
//    Phase 1 reduce-scatter (N-1 steps): rank r sends one chunk to (r+1)%N,
//      the receiver ADDS it. After N-1 steps each rank owns the full SUM of
//      exactly one distinct chunk.
//    Phase 2 all-gather (N-1 steps): circulate the fully-reduced chunks around
//      the ring (overwrite, no add) so every rank holds the complete sum.
//
//  The ONLY thing M3 changes vs M1 is the transport: M1's in-process array copy
//  becomes a real cudaMemcpyPeer device-to-device copy over NVLink (or PCIe P2P
//  fallback). Each rank's vector lives in that GPU's own device memory.
//
//  GATE (g5): the all-reduced result on every GPU == the serial elementwise sum
//  of the N input vectors, byte-eq max|Δ|=0, on FP64 buffers. Tested for N=2
//  with S NOT a multiple of N (boundary chunking) and a large S.
//
//  HONEST (g5): M3 proves the COLLECTIVE works over real multi-GPU transport.
//  It is NOT end-to-end parallel training (that is DDP-M4: 1-GPU vs 2-GPU
//  same-model byte-eq over a real flame step) and NOT 4-GPU scale (DDP-M5).
//
//  Build:  nvcc -O2 -arch=sm_86 -o ring_p2p ring_p2p.cu
//  Run:    ./ring_p2p           # runs the gate cases, prints PASS/FAIL + topo note
// ════════════════════════════════════════════════════════════════════════════
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
#include <cuda_runtime.h>

#define CK(call) do { cudaError_t _e = (call); if (_e != cudaSuccess) { \
    fprintf(stderr, "CUDA ERROR %s:%d: %s\n", __FILE__, __LINE__, \
            cudaGetErrorString(_e)); exit(1); } } while (0)

// ── chunk boundaries: identical to M1 ring_chunk_start (S split into N chunks;
//    first (S%N) chunks get one extra element). ────────────────────────────────
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

int main(int argc, char** argv) {
    int ndev = 0;
    CK(cudaGetDeviceCount(&ndev));
    printf("=== ring_p2p :: visible CUDA devices = %d ===\n", ndev);
    if (ndev < 2) {
        printf("FATAL: need >= 2 GPUs on one node for DDP-M3 P2P (found %d)\n", ndev);
        return 3;
    }
    const int N = 2;                      // ranks = GPUs (M3 = 2-GPU node)
    const int dev[2] = {0, 1};

    // ── peer access: canAccessPeer probe + enable both directions ────────────
    int can01 = 0, can10 = 0;
    CK(cudaDeviceCanAccessPeer(&can01, dev[0], dev[1]));
    CK(cudaDeviceCanAccessPeer(&can10, dev[1], dev[0]));
    printf("cudaDeviceCanAccessPeer(0->1) = %d\n", can01);
    printf("cudaDeviceCanAccessPeer(1->0) = %d\n", can10);
    int p2p = (can01 && can10);
    if (p2p) {
        CK(cudaSetDevice(dev[0])); CK(cudaDeviceEnablePeerAccess(dev[1], 0));
        CK(cudaSetDevice(dev[1])); CK(cudaDeviceEnablePeerAccess(dev[0], 0));
        printf("peer access ENABLED both directions -> transport = cudaMemcpyPeer (P2P)\n");
    } else {
        printf("peer access UNAVAILABLE -> transport = staged host copy (cudaMemcpyPeer still\n");
        printf("  routes through host; correctness identical, perf caveat noted)\n");
    }

    // gate cases: S not a multiple of N (boundary), and a large S.
    long cases[] = {7, (1L << 20)};
    int rc = 0;

    for (int ci = 0; ci < 2; ci++) {
        long S = cases[ci];
        printf("\n--- case S=%ld (S%%N=%ld) ---\n", S, S % N);

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

        // ── Phase 1: reduce-scatter (N-1 steps) — schedule identical to M1 ─────
        for (int step = 0; step < N - 1; step++) {
            // simultaneous sends: rank r sends chunk (r-step+N)%N to (r+1)%N.
            for (int r = 0; r < N; r++) {
                int send_chunk = ((r - step) % N + N) % N;
                int dst = (r + 1) % N;
                long st = chunk_start(S, N, send_chunk);
                long sp = chunk_start(S, N, send_chunk + 1);
                long cnt = sp - st;
                // real inter-GPU transport: GPU r -> GPU dst.
                CK(cudaMemcpyPeer(staging[dst] + st, dev[dst],
                                  d[r] + st, dev[r], cnt * sizeof(double)));
            }
            CK(cudaDeviceSynchronize());
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

        // ── Phase 2: all-gather (N-1 steps) — overwrite, no add ───────────────
        for (int step = 0; step < N - 1; step++) {
            for (int r = 0; r < N; r++) {
                int send_chunk = ((r - step + 1) % N + N) % N;
                int dst = (r + 1) % N;
                long st = chunk_start(S, N, send_chunk);
                long sp = chunk_start(S, N, send_chunk + 1);
                long cnt = sp - st;
                CK(cudaMemcpyPeer(d[dst] + st, dev[dst],
                                  d[r] + st, dev[r], cnt * sizeof(double)));
            }
            CK(cudaDeviceSynchronize());
        }

        // ── gate: every GPU's buffer == serial elementwise sum, max|Δ|=0 ──────
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
        printf("S=%ld : max|delta| vs serial-sum = %.17g  %s\n",
               S, max_abs_diff, (max_abs_diff == 0.0) ? "BYTE-EQ PASS" : "FAIL");
        if (max_abs_diff != 0.0) rc = 1;

        for (int r = 0; r < N; r++) { CK(cudaSetDevice(dev[r])); CK(cudaFree(d[r])); CK(cudaFree(staging[r])); }
    }

    printf("\n=== DDP-M3 verdict: %s (transport=%s) ===\n",
           rc == 0 ? "GREEN - ring all-reduce byte-eq over real 2-GPU P2P" : "RED",
           p2p ? "NVLink/PCIe cudaMemcpyPeer P2P" : "staged-host fallback");
    return rc;
}
