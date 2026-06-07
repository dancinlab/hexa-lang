/* ── HEXA-FUSION FF-XSTREAM — cross-stream valley overlap probe ───────────────
 *
 * THE CHEAPEST POSSIBLE LEVER. No fusion. No new fused kernel. Just concurrency.
 *
 * The flame CLMConvMoE step is bimodal: {100% in-GEMM, ~0% between}. The valley
 * kernels (per-expert Conv1d, the gate, etc.) UNDER-FILL the GPU — a single one
 * issues far fewer CTAs than the SM scheduler can host, so the device idles while
 * the kernel drains.  The E experts are MUTUALLY INDEPENDENT (each reads the same
 * shared block input X, writes a disjoint output slice Y_e).  Serially launching
 * them on ONE stream forces the hardware to drain expert e before starting e+1
 * → the under-fill compounds into the valley.
 *
 * FF-XSTREAM issues each independent expert conv on a SEPARATE CUDA stream so the
 * hardware scheduler can run a later expert's tiles WHILE an earlier one drains —
 * turning {100%,0%} into an overlapped mid-band, WITHOUT writing a single fused
 * kernel. It bounds what fusion could ever reclaim: it answers "is the
 * between-GEMM valley reclaimable AT ALL, and by how much?".
 *
 * Two dispatch modes over the IDENTICAL k_conv_single kernel (same math, same
 * inputs, only overlapped):
 *   SERIAL (HEXA_MULTISTREAM=0): all E experts on stream 0, back-to-back.
 *   MULTI  (HEXA_MULTISTREAM=1): expert e on stream[e % NSTREAMS].
 *
 * GATE (g5):
 *   (1) byte-eq: max|Δ| serial-vs-multi == 0 (concurrency must NOT change the
 *       math — same kernel, same inputs, only overlapped).
 *   (2) measure step wall + SM util mean/median, single-stream vs multi-stream.
 *
 * Build:  nvcc -arch=sm_90 -O3 -o gpu_ff_xstream gpu_ff_xstream.cu
 * Args:   E d T K dil  (defaults below — representative single-MoE-block shape).
 * Env:    HEXA_MULTISTREAM={0,1}   NSTREAMS=<n>   ITERS=<n>   WARMUP=<n>
 *
 * (run under: nvidia-smi --query-gpu=utilization.gpu --format=csv -lms 50
 *  for util MEAN/MEDIAN — the fire script wraps each mode with its own sampler.)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <cuda_runtime.h>

#define CK(call) do { \
    cudaError_t _e = (call); \
    if (_e != cudaSuccess) { \
        fprintf(stderr, "[T] CUDA %s:%d %s\n", \
                __FILE__, __LINE__, cudaGetErrorString(_e)); \
        exit(2); \
    } \
} while (0)

/* ── Tiling constants — IDENTICAL to gpu_moe_conv_fuse.cu k_conv_single. ────── */
#define CO_TILE 128
#define TT_TILE 8

/* ── Per-expert independent Conv1d launch (the valley kernel). ────────────────
 * BYTE-FOR-BYTE the k_conv_single from gpu_moe_conv_fuse.cu (the ModuleList-30
 * path A). ONE expert per launch → grid is E× smaller → each launch UNDER-FILLS.
 * grid = (ceil(d/CO), ceil(T/TT)). The accumulation order (ci ascending, k inner)
 * is fixed so serial and multi-stream produce BIT-IDENTICAL results.
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

/* Launch all E independent expert convs. streams==NULL or n==1 → serial on
 * the default stream; otherwise expert e on streams[e % n]. SAME kernel, SAME
 * grid/block, SAME inputs — only the stream assignment (overlap) differs. */
static void dispatch_experts(const float* dX, const float* dW, const float* dB,
                             float* dY, int E, int T, int d, int K, int dil,
                             cudaStream_t* streams, int nstreams) {
    dim3 block(CO_TILE);
    dim3 grid((d + CO_TILE - 1) / CO_TILE, (T + TT_TILE - 1) / TT_TILE);
    size_t we_stride = (size_t)d * d * K;
    size_t be_stride = (size_t)d;
    size_t ye_stride = (size_t)T * d;
    for (int e = 0; e < E; ++e) {
        cudaStream_t s = (streams && nstreams > 1) ? streams[e % nstreams] : 0;
        k_conv_single<<<grid, block, 0, s>>>(
            dX, dW + (size_t)e * we_stride, dB + (size_t)e * be_stride,
            dY + (size_t)e * ye_stride, T, d, K, dil);
    }
}

static double now_ms(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e3 + ts.tv_nsec * 1e-6;
}

int main(int argc, char** argv) {
    int E   = (argc > 1) ? atoi(argv[1]) : 30;
    int d   = (argc > 2) ? atoi(argv[2]) : 2048;
    int T   = (argc > 3) ? atoi(argv[3]) : 256;
    int K   = (argc > 4) ? atoi(argv[4]) : 3;
    int dil = (argc > 5) ? atoi(argv[5]) : 1;

    const char* ms_env = getenv("HEXA_MULTISTREAM");
    int multistream = (ms_env && atoi(ms_env)) ? 1 : 0;
    const char* ns_env = getenv("NSTREAMS");
    int nstreams = ns_env ? atoi(ns_env) : E;       /* default: one stream per expert */
    if (nstreams < 1) nstreams = 1;
    if (nstreams > E) nstreams = E;
    const char* it_env = getenv("ITERS");
    int iters = it_env ? atoi(it_env) : 50;
    const char* wu_env = getenv("WARMUP");
    int warmup = wu_env ? atoi(wu_env) : 5;
    const char* sus_env = getenv("SUSTAIN_SEC");      /* sustained loop for util sampler */
    double sustain_sec = sus_env ? atof(sus_env) : 0.0;

    printf("# FF-XSTREAM E=%d d=%d T=%d K=%d dil=%d  mode=%s nstreams=%d iters=%d warmup=%d\n",
           E, d, T, K, dil, multistream ? "MULTI" : "SERIAL",
           multistream ? nstreams : 1, iters, warmup);

    size_t nX = (size_t)T * d;
    size_t nW = (size_t)E * d * d * K;
    size_t nB = (size_t)E * d;
    size_t nY = (size_t)E * T * d;

    float* hX = (float*)malloc(nX * sizeof(float));
    float* hW = (float*)malloc(nW * sizeof(float));
    float* hB = (float*)malloc(nB * sizeof(float));
    /* deterministic fill — same seed sequence regardless of mode. */
    uint64_t s = 0x9e3779b97f4a7c15ULL;
    #define RNG() ( s ^= s << 13, s ^= s >> 7, s ^= s << 17, \
                    ((double)((s >> 11) & ((1ULL<<53)-1)) / (double)(1ULL<<53)) )
    for (size_t i = 0; i < nX; ++i) hX[i] = (float)(RNG() * 2.0 - 1.0);
    for (size_t i = 0; i < nW; ++i) hW[i] = (float)(RNG() * 0.1 - 0.05);
    for (size_t i = 0; i < nB; ++i) hB[i] = (float)(RNG() * 0.02 - 0.01);

    float *dX, *dW, *dB, *dY;
    CK(cudaMalloc(&dX, nX * sizeof(float)));
    CK(cudaMalloc(&dW, nW * sizeof(float)));
    CK(cudaMalloc(&dB, nB * sizeof(float)));
    CK(cudaMalloc(&dY, nY * sizeof(float)));
    CK(cudaMemcpy(dX, hX, nX * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dW, hW, nW * sizeof(float), cudaMemcpyHostToDevice));
    CK(cudaMemcpy(dB, hB, nB * sizeof(float), cudaMemcpyHostToDevice));

    cudaStream_t* streams = NULL;
    if (multistream) {
        streams = (cudaStream_t*)malloc(nstreams * sizeof(cudaStream_t));
        for (int i = 0; i < nstreams; ++i)
            CK(cudaStreamCreateWithFlags(&streams[i], cudaStreamNonBlocking));
    }

    /* warmup */
    for (int w = 0; w < warmup; ++w)
        dispatch_experts(dX, dW, dB, dY, E, T, d, K, dil, streams, nstreams);
    CK(cudaDeviceSynchronize());

    /* timed loop */
    double t0 = now_ms();
    for (int i = 0; i < iters; ++i)
        dispatch_experts(dX, dW, dB, dY, E, T, d, K, dil, streams, nstreams);
    CK(cudaDeviceSynchronize());
    double t1 = now_ms();
    double per_step = (t1 - t0) / iters;
    printf("STEP_WALL_MS=%.4f  (mode=%s nstreams=%d)\n",
           per_step, multistream ? "MULTI" : "SERIAL", multistream ? nstreams : 1);

    /* dump output for the byte-eq gate (raw fp32, host-readable). */
    const char* dump = getenv("DUMP_Y");
    if (dump && dump[0]) {
        float* hY = (float*)malloc(nY * sizeof(float));
        CK(cudaMemcpy(hY, dY, nY * sizeof(float), cudaMemcpyDeviceToHost));
        FILE* f = fopen(dump, "wb");
        if (!f) { fprintf(stderr, "[T] cannot open %s\n", dump); exit(3); }
        fwrite(hY, sizeof(float), nY, f);
        fclose(f);
        free(hY);
        printf("# dumped Y[%zu] to %s\n", nY, dump);
    }

    /* sustained loop so a background nvidia-smi sampler gets a clean window. */
    if (sustain_sec > 0.0) {
        printf("# sustained loop (~%.1fs) for util capture — mode=%s\n",
               sustain_sec, multistream ? "MULTI" : "SERIAL");
        double end = now_ms() + sustain_sec * 1e3;
        while (now_ms() < end) {
            for (int i = 0; i < 20; ++i)
                dispatch_experts(dX, dW, dB, dY, E, T, d, K, dil, streams, nstreams);
            CK(cudaDeviceSynchronize());
        }
    }

    if (streams) {
        for (int i = 0; i < nstreams; ++i) CK(cudaStreamDestroy(streams[i]));
        free(streams);
    }
    CK(cudaFree(dX)); CK(cudaFree(dW)); CK(cudaFree(dB)); CK(cudaFree(dY));
    free(hX); free(hW); free(hB);
    return 0;
}
