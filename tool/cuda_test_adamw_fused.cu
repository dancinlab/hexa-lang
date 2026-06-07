/* tool/cuda_test_adamw_fused.cu  —  HEXA-FUSION FF-FUSED-OPTIM
 *
 * GPU byte-eq + wall + launch-count oracle for the FUSED cooperative AdamW
 * optimizer tail (`_hx_cuda_farr_adamw_fused_gpu`, the _hx_k_adamw_fused
 * kernel, M2 milestone) vs the EAGER per-param tail (the clm_prod step's 17
 * separate `_hx_cuda_farr_adamw_step_inplace_gpu` launches).
 *
 * This is the FF-FUSED-OPTIM gate (g5) harness — the M2 verdict measured the
 * fused tail through the util% lens (closed-neg on util-GREEN); this measures
 * the lens FF-FUSED-OPTIM actually asks for:
 *
 *   (1) byte-eq FP64 max|Δ| == 0  vs the eager per-param AdamW tail
 *       (the fused kernel runs the IDENTICAL per-element double arithmetic;
 *        only the launch count differs, so max|Δ| MUST be exactly 0).
 *   (2) optimizer-step wall before (eager 17-launch) / after (fused 1-launch).
 *   (3) launch count before (17) / after (1).
 *
 * Tensor set = the EXACT clm_prod 17-param shape table (D-parameterized), so
 * the measured tail matches the real flame CLMConvMoE optimizer tail.
 *
 * Build (on the GPU host, alongside the emitted runtime_cuda.c):
 *   nvcc -O2 -std=c++14 -DHEXA_CUDA -gencode arch=compute_<CC>,code=sm_<CC> \
 *       -x cu runtime_cuda.c cuda_test_adamw_fused.cu \
 *       -lcublas -lcudart -lm -o test_adamw_fused
 *
 * Mirrors cuda_test_farr_adamw_inplace.cu (mock _hx_farr_table + calloc bufs).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <cuda_runtime.h>

typedef struct {
    double*  buf;
    int64_t  len;
    void*    d_buf;
    int      loc;
    int      pinned;
    int      dirty_host;
    int      dirty_dev;
} HexaFarrEntry;

#define MOCK_FARR_CAP 4096
static HexaFarrEntry _hx_farr_storage[MOCK_FARR_CAP];
HexaFarrEntry*       _hx_farr_table = _hx_farr_storage;
int64_t              _hx_farr_count = 0;

extern "C" {
    int _hx_cuda_farr_adamw_step_inplace_gpu(int64_t w_id, int64_t m_id,
                                     int64_t v_id, int64_t g_id, int64_t n,
                                     double lr, double b1, double b2,
                                     double eps, double wd, int64_t step_t);
    int _hx_cuda_farr_adamw_fused_gpu(const int64_t* w_ids, const int64_t* m_ids,
                                     const int64_t* v_ids, const int64_t* g_ids,
                                     const int64_t* ns, int np,
                                     double lr, double b1, double b2,
                                     double eps, double wd, int64_t step_t);
}

static int64_t alloc_farr(int64_t len) {
    int64_t id = _hx_farr_count++;
    if (id >= MOCK_FARR_CAP) { fprintf(stderr, "[harness] farr overflow\n"); exit(2); }
    HexaFarrEntry* e = &_hx_farr_table[id];
    e->buf = (double*)calloc((size_t)len, sizeof(double));
    if (!e->buf) { perror("calloc"); exit(2); }
    e->len = len;
    e->d_buf = NULL; e->loc = 0; e->pinned = 0; e->dirty_host = 0; e->dirty_dev = 0;
    return id;
}

static double max_abs_diff_buf(const double* a, const double* b, int64_t n) {
    double m = 0.0;
    for (int64_t i = 0; i < n; i++) { double d = fabs(a[i] - b[i]); if (d > m) m = d; }
    return m;
}

/* The exact clm_prod 17-param shape table, parameterized by model width D.
 *   vd = V*d, dd = d*d*K, ed = E*d  (V=256 vocab, E=2 experts, K=1 conv tap).
 * Slot order matches stdlib/flame/clm_prod.hexa fs_* packing (0..16). */
static const int V_VOCAB = 256, E_EXP = 2, K_TAP = 1;
static int g_lens[17];
static int build_shapes(int d) {
    int vd = V_VOCAB * d, dd = d * d * K_TAP, ed = E_EXP * d;
    int s[17] = { vd,            /* 0 embed   */
                  dd, d,         /* 1 ecW 2 ecB */
                  dd, d,         /* 3 tcW 4 tcB */
                  d,  d,         /* 5 tgG 6 tgB */
                  ed, E_EXP,     /* 7 rW  8 rB  */
                  dd, d,         /* 9 e0W 10 e0B */
                  dd, d,         /* 11 e1W 12 e1B */
                  d,  d,         /* 13 noG 14 noB */
                  vd, V_VOCAB }; /* 15 roW 16 roB */
    long tot = 0;
    for (int i = 0; i < 17; i++) { g_lens[i] = s[i]; tot += s[i]; }
    return (int)tot;
}

/* deterministic per-tensor init (W,m,v,g) — same seed for fused & eager sets. */
static void fill_param(int64_t w, int64_t m, int64_t v, int64_t g, int slot) {
    HexaFarrEntry* e = &_hx_farr_table[w];
    for (int64_t i = 0; i < e->len; i++) {
        double x = (double)(i + 1) * 0.0137 + (double)slot * 0.91;
        _hx_farr_table[w].buf[i] = 0.5 * sin(x) - 0.01;
        _hx_farr_table[m].buf[i] = 0.013 * sin(x * 1.7);
        _hx_farr_table[v].buf[i] = 0.0011 * (1.0 + 0.5 * sin(x * 0.3)) + 1e-6;
        _hx_farr_table[g].buf[i] = 0.2 * sin(x * 2.3);
    }
}

int main(int argc, char** argv) {
    int d = (argc > 1) ? atoi(argv[1]) : 256;
    int reps = (argc > 2) ? atoi(argv[2]) : 50;
    const double lr = 0.05, b1 = 0.9, b2 = 0.999, eps = 1e-8, wd = 0.0;
    const int NP = 17;

    int total = build_shapes(d);
    printf("=== FF-FUSED-OPTIM byte-eq + wall + launch-count oracle ===\n");
    printf("clm_prod 17-param tail @ D=%d  (V=%d E=%d K=%d)  total elems=%d  reps=%d\n",
           d, V_VOCAB, E_EXP, K_TAP, total, reps);

    /* Set A = FUSED (one launch).  Set B = EAGER (17 launches). Identical init. */
    int64_t Aw[17], Am[17], Av[17], Ag[17];
    int64_t Bw[17], Bm[17], Bv[17], Bg[17];
    int64_t fw_ids[17], fm_ids[17], fv_ids[17], fg_ids[17], fns[17];
    for (int p = 0; p < NP; p++) {
        int n = g_lens[p];
        Aw[p] = alloc_farr(n); Am[p] = alloc_farr(n); Av[p] = alloc_farr(n); Ag[p] = alloc_farr(n);
        Bw[p] = alloc_farr(n); Bm[p] = alloc_farr(n); Bv[p] = alloc_farr(n); Bg[p] = alloc_farr(n);
        fw_ids[p] = Aw[p]; fm_ids[p] = Am[p]; fv_ids[p] = Av[p]; fg_ids[p] = Ag[p]; fns[p] = n;
    }
    /* identical seed into A and B */
    for (int p = 0; p < NP; p++) {
        fill_param(Aw[p], Am[p], Av[p], Ag[p], p);
        int n = g_lens[p];
        memcpy(_hx_farr_table[Bw[p]].buf, _hx_farr_table[Aw[p]].buf, (size_t)n*sizeof(double));
        memcpy(_hx_farr_table[Bm[p]].buf, _hx_farr_table[Am[p]].buf, (size_t)n*sizeof(double));
        memcpy(_hx_farr_table[Bv[p]].buf, _hx_farr_table[Av[p]].buf, (size_t)n*sizeof(double));
        memcpy(_hx_farr_table[Bg[p]].buf, _hx_farr_table[Ag[p]].buf, (size_t)n*sizeof(double));
    }

    /* ---- correctness: one step, fused (A) vs eager 17-launch (B) ---- */
    int rcF = _hx_cuda_farr_adamw_fused_gpu(fw_ids, fm_ids, fv_ids, fg_ids, fns, NP,
                                            lr, b1, b2, eps, wd, /*step_t=*/1);
    if (rcF != 0) {
        printf("  FUSED rc=%d (no cooperativeLaunch / CUDA fail) — gate UNTESTED\n", rcF);
        return 3;
    }
    for (int p = 0; p < NP; p++)
        (void)_hx_cuda_farr_adamw_step_inplace_gpu(Bw[p], Bm[p], Bv[p], Bg[p],
                                 g_lens[p], lr, b1, b2, eps, wd, /*step_t=*/1);

    double maxd = 0.0;
    for (int p = 0; p < NP; p++) {
        int n = g_lens[p];
        double dW = max_abs_diff_buf(_hx_farr_table[Aw[p]].buf, _hx_farr_table[Bw[p]].buf, n);
        double dM = max_abs_diff_buf(_hx_farr_table[Am[p]].buf, _hx_farr_table[Bm[p]].buf, n);
        double dV = max_abs_diff_buf(_hx_farr_table[Av[p]].buf, _hx_farr_table[Bv[p]].buf, n);
        if (dW > maxd) maxd = dW;
        if (dM > maxd) maxd = dM;
        if (dV > maxd) maxd = dV;
    }
    int byteeq = (maxd == 0.0);
    printf("[FF-FUSED-OPTIM-BYTEEQ] fused(1 launch) vs eager(%d launch) max|Δ|=%.3e  => %s\n",
           NP, maxd, byteeq ? "PASS (max|Δ|=0)" : "FAIL");

    /* ---- wall: optimizer tail, eager (17 launch) vs fused (1 launch) ---- */
    cudaEvent_t e0, e1;
    cudaEventCreate(&e0); cudaEventCreate(&e1);

    /* warm */
    for (int p = 0; p < NP; p++)
        (void)_hx_cuda_farr_adamw_step_inplace_gpu(Bw[p], Bm[p], Bv[p], Bg[p],
                                 g_lens[p], lr, b1, b2, eps, wd, 2);
    (void)_hx_cuda_farr_adamw_fused_gpu(fw_ids, fm_ids, fv_ids, fg_ids, fns, NP,
                                        lr, b1, b2, eps, wd, 2);
    cudaDeviceSynchronize();

    /* EAGER: 17 launches per tail */
    cudaEventRecord(e0);
    for (int r = 0; r < reps; r++)
        for (int p = 0; p < NP; p++)
            (void)_hx_cuda_farr_adamw_step_inplace_gpu(Bw[p], Bm[p], Bv[p], Bg[p],
                                     g_lens[p], lr, b1, b2, eps, wd, 3 + r);
    cudaEventRecord(e1); cudaEventSynchronize(e1);
    float ms_eager = 0.0f; cudaEventElapsedTime(&ms_eager, e0, e1);

    /* FUSED: 1 cooperative launch per tail */
    cudaEventRecord(e0);
    for (int r = 0; r < reps; r++)
        (void)_hx_cuda_farr_adamw_fused_gpu(fw_ids, fm_ids, fv_ids, fg_ids, fns, NP,
                                            lr, b1, b2, eps, wd, 3 + r);
    cudaEventRecord(e1); cudaEventSynchronize(e1);
    float ms_fused = 0.0f; cudaEventElapsedTime(&ms_fused, e0, e1);

    double eager_us = (double)ms_eager * 1000.0 / reps;
    double fused_us = (double)ms_fused * 1000.0 / reps;
    printf("[FF-FUSED-OPTIM-WALL] optimizer tail per step:\n");
    printf("    EAGER (17 launch) = %.3f us/step\n", eager_us);
    printf("    FUSED ( 1 launch) = %.3f us/step\n", fused_us);
    printf("    speedup = %.3fx   launch count: %d -> 1\n",
           eager_us / fused_us, NP);

    cudaEventDestroy(e0); cudaEventDestroy(e1);
    printf("=== FF-FUSED-OPTIM: byte-eq %s  speedup %.3fx ===\n",
           byteeq ? "PASS" : "FAIL", eager_us / fused_us);
    return byteeq ? 0 : 1;
}
