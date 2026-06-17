/* devglue_determinism.c — HEXA-FUSION N1 per-glue-kernel run-to-run
 * DETERMINISM PROBE (reusable infra).
 *
 * THE FINDING (P1B-a'' #2783): the device-resident glue path carries a
 * ~1e-1 run-to-run NON-DETERMINISM. P1B-a' saw ~7e-6; P1B-a'' falsified
 * the uninitialized-OUTPUT-tail (zero-on-alloc) hypothesis — the jitter
 * is 4 orders larger → PRIMARY-DATA non-determinism (uninitialized INPUT
 * read / non-deterministic upstream reduction). This harness PERMANENTLY
 * tools what P1B-a'' did ad-hoc: it runs EACH device glue kernel ISOLATED
 * ×N on a FIXED-seed input and reports run-to-run max|Δ| PER KERNEL and
 * PER BUFFER (input-read vs output-write vs scratch) → instantly pins
 * WHICH kernel + WHICH buffer carries the jitter.
 *
 * It links against the PRODUCTION runtime (self/runtime.c) + the SAME
 * runtime_cuda.o the real clm_prod_gpu uses, and drives the glue kernels
 * through the real farr ABI (hexa_farr_zeros/set/get + the _hx_cuda_farr_
 * <op>_gpu launchers). So it measures the EXACT kernels, not a model.
 *
 * Buffer-class semantics (the N2 question):
 *   INPUT  — a buffer the kernel READS (filled by us with a fixed seed).
 *            If its post-run readback varies run-to-run, an upstream
 *            non-det / uninitialized-read corrupted a read-buffer.
 *   OUTPUT — a buffer the kernel WRITES. If its readback varies while all
 *            inputs are byte-stable, the kernel itself is non-det
 *            (atomics / unsynced shared / uninit-scratch read).
 *
 * Probe protocol per kernel, per run r=0..N-1:
 *   (1) RE-FILL every input farr from the fixed seed (so any cross-run
 *       input mutation is detected, not masked).
 *   (2) ZERO every output farr's host buffer + mark dirty_host (forces a
 *       clean H2D so a STALE device output can't leak across runs — the
 *       harness must see the KERNEL's determinism, not residue).
 *   (3) launch the kernel.
 *   (4) hexa_farr_get(out,0) forces the lazy-D2H; snapshot every farr.
 *   Then max|Δ| across runs, per farr, reported with its class.
 *
 * Build (ON POD, in ~/work, mirrors fire_p1b_aprime2.sh link):
 *   nvcc -x cu -DHEXA_CUDA -rdc=true -gencode arch=compute_90,code=sm_90 \
 *        -O2 -w -I self/cuda -I self -I . -c runtime_cuda.c -o runtime_cuda.o
 *   nvcc -dlink -arch=sm_90 runtime_cuda.o -o runtime_cuda_dlink.o
 *   gcc -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_CUDA -w -I self/cuda -I self -I . \
 *       devglue_determinism.c self/runtime.c runtime_cuda.o runtime_cuda_dlink.o \
 *       -L"$CUDA_LIB" -lcudart -lcublas -lcuda -lcudadevrt -lm -ldl -lpthread \
 *       -o devglue_determinism
 *   N=3 ./devglue_determinism
 */
#include "runtime.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* core farr ABI (hexa_int/hexa_float/hexa_as_num/hexa_farr_zeros/set/get) is
 * declared by runtime.h above — do NOT redeclare (signature must match). */

/* host farr table (mirror of the struct in runtime_cuda.c — declared here
 * because it is NOT in runtime.h's public surface; harness keeps it for
 * diagnostics, the probe itself goes through hexa_farr_get/set). */
typedef struct {
    double*  buf; int64_t len; void* d_buf;
    int loc; int pinned; int dirty_host; int dirty_dev;
} HexaFarrEntry;
extern HexaFarrEntry* _hx_farr_table;
extern int64_t        _hx_farr_count;

/* ── glue launchers (self/cuda/runtime_cuda.c) ──────────────────────── */
extern int _hx_cuda_farr_gelu_gpu(int64_t in_id, int64_t out_id, int64_t n);
extern int _hx_cuda_farr_residual_add_gpu(int64_t a_id, int64_t b_id, int64_t out_id, int64_t n);
extern int _hx_cuda_farr_groupnorm_gpu(int64_t x_id, int64_t gamma_id, int64_t beta_id,
                                       int64_t y_id, int64_t mean_id, int64_t inv_id,
                                       int64_t xhat_id, int64_t T, int64_t C, int64_t G);
extern int _hx_cuda_farr_moe_router_gpu(int64_t logits_id, int64_t ex_out_id,
                                        int64_t probs_id, int64_t y_id,
                                        int64_t T, int64_t E, int64_t C);
extern int _hx_cuda_farr_embedding_gpu(int64_t ids_id, int64_t table_id,
                                       int64_t out_id, int64_t T, int64_t d);
extern int _hx_cuda_farr_expert_pack2_gpu(int64_t ex0_id, int64_t ex1_id, int64_t out_id, int64_t n);
/* own-GEMM (conv) — C = A(MxK) · B(KxN), row-major naive-k. Same launcher as
 * the cuBLAS matmul; HEXA_OWN_GEMM=1 selects the deterministic _hx_k_gemm
 * device path (#2697). Arg order is (a_id, M, K, b_id, N, c_id). */
extern int _hx_cuda_farr_matmul_gpu(int64_t a_id, int64_t M, int64_t K,
                                    int64_t b_id, int64_t N, int64_t c_id);

/* ── helpers ────────────────────────────────────────────────────────── */
#define MAXBUF 32
typedef enum { CIN = 0, COUT = 1 } Class;
typedef struct { int64_t id; int64_t n; Class cls; const char* name; } Buf;

static int64_t mk(int64_t n) { return hexa_as_num(hexa_farr_zeros(hexa_int(n))); }

/* deterministic fixed-seed fill: a smooth bounded pattern, index-dependent,
 * NOT all-zero (zeros would mask an uninit read that happens to read 0). */
static double seedval(int64_t gidx, int64_t i) {
    /* gidx = per-buffer global offset so different buffers differ */
    double x = (double)((i * 1103515245LL + gidx * 12345LL + 7) % 9973);
    return (x / 9973.0) * 2.0 - 1.0;   /* in (-1,1) */
}
static void fill_input(int64_t id, int64_t n, int64_t gidx) {
    for (int64_t i = 0; i < n; i++)
        hexa_farr_set(hexa_int(id), hexa_int(i), hexa_float(seedval(gidx, i)));
}
/* zero an OUTPUT host buffer + mark dirty_host so the next launch H2D's a
 * clean buffer (kills stale-device cross-run residue — we measure the
 * KERNEL's determinism, not leftover bytes). */
static void zero_output(int64_t id, int64_t n) {
    for (int64_t i = 0; i < n; i++)
        hexa_farr_set(hexa_int(id), hexa_int(i), hexa_float(0.0));
}
static void snapshot(int64_t id, int64_t n, double* dst) {
    for (int64_t i = 0; i < n; i++)
        dst[i] = HX_FLOAT(hexa_farr_get(hexa_int(id), hexa_int(i)));
}

static int NRUN = 3;

/* run one kernel ISOLATED ×NRUN; report per-buffer run-to-run max|Δ|. */
static void probe(const char* kname, int (*launch)(Buf*),
                  Buf* bufs, int nbuf) {
    double* snap[MAXBUF];   /* [buf] -> NRUN*n flattened: snap[b][r*n+i] */
    for (int b = 0; b < nbuf; b++) snap[b] = (double*)malloc(sizeof(double) * NRUN * bufs[b].n);

    int rc_last = 0;
    for (int r = 0; r < NRUN; r++) {
        int gidx = 0;
        for (int b = 0; b < nbuf; b++) {
            if (bufs[b].cls == CIN)  fill_input(bufs[b].id, bufs[b].n, gidx);
            else                     zero_output(bufs[b].id, bufs[b].n);
            gidx += 131;   /* distinct seed offset per buffer */
        }
        rc_last = launch(bufs);
        for (int b = 0; b < nbuf; b++)
            snapshot(bufs[b].id, bufs[b].n, snap[b] + (int64_t)r * bufs[b].n);
    }

    printf("\n=== KERNEL %s  (rc=%d, runs=%d) ===\n", kname, rc_last, NRUN);
    if (rc_last != 0) { printf("  LAUNCH FAILED (rc=%d) — kernel did not fire, deltas meaningless\n", rc_last); }
    double kmax = 0.0; const char* kmax_buf = "-"; int kmax_cls = CIN;
    for (int b = 0; b < nbuf; b++) {
        double mx = 0.0; int64_t arg = -1;
        for (int64_t i = 0; i < bufs[b].n; i++) {
            double base = snap[b][i];   /* run 0 */
            for (int r = 1; r < NRUN; r++) {
                double d = fabs(snap[b][(int64_t)r * bufs[b].n + i] - base);
                if (d > mx) { mx = d; arg = i; }
            }
        }
        printf("  %-7s %-10s n=%-8lld  run2run max|Δ|=%.6e  @i=%lld  (r0=%.10g)\n",
               bufs[b].cls == CIN ? "INPUT" : "OUTPUT", bufs[b].name,
               (long long)bufs[b].n, mx, (long long)arg, arg >= 0 ? snap[b][arg] : 0.0);
        if (mx > kmax) { kmax = mx; kmax_buf = bufs[b].name; kmax_cls = bufs[b].cls; }
    }
    printf("  --> KERNEL %s run-to-run max|Δ| = %.6e  (carried by %s buffer '%s')\n",
           kname, kmax, kmax_cls == CIN ? "INPUT" : "OUTPUT", kmax_buf);
    for (int b = 0; b < nbuf; b++) free(snap[b]);
}

/* ── per-kernel launch shims (fixed dims) ───────────────────────────── */
/* dims chosen small-but-representative; T multiple of G, etc. */
#define T_ 128
#define C_ 64
#define G_ 8
#define E_ 2
#define D_ 64

static Buf gelu_b[2];
static int gelu_l(Buf* b){ return _hx_cuda_farr_gelu_gpu(b[0].id, b[1].id, T_*C_); }

static Buf resid_b[3];
static int resid_l(Buf* b){ return _hx_cuda_farr_residual_add_gpu(b[0].id, b[1].id, b[2].id, T_*C_); }

static Buf gn_b[7];
static int gn_l(Buf* b){ return _hx_cuda_farr_groupnorm_gpu(b[0].id,b[1].id,b[2].id,b[3].id,b[4].id,b[5].id,b[6].id, T_,C_,G_); }

static Buf moe_b[4];
static int moe_l(Buf* b){ return _hx_cuda_farr_moe_router_gpu(b[0].id,b[1].id,b[2].id,b[3].id, T_,E_,C_); }

static Buf emb_b[3];
static int emb_l(Buf* b){ return _hx_cuda_farr_embedding_gpu(b[0].id,b[1].id,b[2].id, T_, D_); }

static Buf pack_b[3];
static int pack_l(Buf* b){ return _hx_cuda_farr_expert_pack2_gpu(b[0].id,b[1].id,b[2].id, T_*C_); }

/* own-GEMM: M=T, K=C, N=C  (a square-ish conv-shaped GEMM) */
#define MM_M T_
#define MM_K C_
#define MM_N C_
static Buf mm_b[3];
static int mm_l(Buf* b){ return _hx_cuda_farr_matmul_gpu(b[0].id, MM_M,MM_K, b[1].id, MM_N, b[2].id); }

int main(int argc, char** argv) {
    const char* nr = getenv("N"); if (nr) NRUN = atoi(nr); if (NRUN < 2) NRUN = 3;
    printf("############################################################\n");
    printf("### HEXA-FUSION N1 — per-glue-kernel run-to-run DETERMINISM PROBE\n");
    printf("###   N=%d isolated runs/kernel · fixed-seed input · max|Δ| per buffer-class\n", NRUN);
    printf("###   INPUT=read-buffer  OUTPUT=write-buffer (the N2 buffer-class split)\n");
    printf("############################################################\n");

    /* gelu: in -> out, n=T*C */
    gelu_b[0]=(Buf){mk(T_*C_),T_*C_,CIN,"in"};   gelu_b[1]=(Buf){mk(T_*C_),T_*C_,COUT,"out"};
    probe("gelu", gelu_l, gelu_b, 2);

    /* residual_add: a,b -> out */
    resid_b[0]=(Buf){mk(T_*C_),T_*C_,CIN,"a"}; resid_b[1]=(Buf){mk(T_*C_),T_*C_,CIN,"b"}; resid_b[2]=(Buf){mk(T_*C_),T_*C_,COUT,"out"};
    probe("residual_add", resid_l, resid_b, 3);

    /* groupnorm: x,gamma,beta -> y,mean,inv,xhat */
    gn_b[0]=(Buf){mk(T_*C_),T_*C_,CIN,"x"}; gn_b[1]=(Buf){mk(C_),C_,CIN,"gamma"}; gn_b[2]=(Buf){mk(C_),C_,CIN,"beta"};
    gn_b[3]=(Buf){mk(T_*C_),T_*C_,COUT,"y"}; gn_b[4]=(Buf){mk(G_),G_,COUT,"mean"}; gn_b[5]=(Buf){mk(G_),G_,COUT,"inv"}; gn_b[6]=(Buf){mk(T_*C_),T_*C_,COUT,"xhat"};
    probe("groupnorm", gn_l, gn_b, 7);

    /* moe_router: logits(T*E), ex_out(E*T*C) -> probs(T*E), y(T*C) */
    moe_b[0]=(Buf){mk(T_*E_),T_*E_,CIN,"logits"}; moe_b[1]=(Buf){mk(E_*T_*C_),E_*T_*C_,CIN,"ex_out"};
    moe_b[2]=(Buf){mk(T_*E_),T_*E_,COUT,"probs"}; moe_b[3]=(Buf){mk(T_*C_),T_*C_,COUT,"y"};
    probe("moe_router", moe_l, moe_b, 4);

    /* embedding: ids(T), table(?*D) -> out(T*D). ids must be valid int indices. */
    emb_b[0]=(Buf){mk(T_),T_,CIN,"ids"}; emb_b[1]=(Buf){mk(256*D_),256*D_,CIN,"table"}; emb_b[2]=(Buf){mk(T_*D_),T_*D_,COUT,"out"};
    /* override ids with valid indices [0,255] (seedval gives floats in (-1,1)) */
    for (int64_t i=0;i<T_;i++) hexa_farr_set(hexa_int(emb_b[0].id), hexa_int(i), hexa_float((double)((i*37)%256)));
    probe("embedding", emb_l, emb_b, 3);

    /* expert_pack2: ex0,ex1 -> out(2*n) */
    pack_b[0]=(Buf){mk(T_*C_),T_*C_,CIN,"ex0"}; pack_b[1]=(Buf){mk(T_*C_),T_*C_,CIN,"ex1"}; pack_b[2]=(Buf){mk(2*T_*C_),2*T_*C_,COUT,"out"};
    probe("expert_pack2", pack_l, pack_b, 3);

    /* own-GEMM matmul: A(MxK),B(KxN) -> C(MxN) */
    mm_b[0]=(Buf){mk(MM_M*MM_K),MM_M*MM_K,CIN,"A"}; mm_b[1]=(Buf){mk(MM_K*MM_N),MM_K*MM_N,CIN,"B"}; mm_b[2]=(Buf){mk(MM_M*MM_N),MM_M*MM_N,COUT,"C"};
    probe("own_gemm_matmul", mm_l, mm_b, 3);

    printf("\n############################################################\n");
    printf("### N1 PROBE COMPLETE. Any kernel with run2run max|Δ| > 0 is NON-DETERMINISTIC.\n");
    printf("### OUTPUT-carried Δ = the kernel itself races; INPUT-carried Δ = upstream/read corruption.\n");
    printf("############################################################\n");
    return 0;
}
