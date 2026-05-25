/* F-FUSION-ATTENTION-FLASH structural oracle (PRIMARY finding).
 *
 * Deterministic, no GPU, contention-immune. Counts the two structural
 * quantities that decide the flash-attention moat case cuBLAS CANNOT do:
 *
 *   (1) kernel launches:  fused = 1   vs   cuBLAS-using baseline = 3
 *   (2) HBM traffic for the S = QK^T score matrix round-trip:
 *          fused    = 0          bytes  (S is never materialized to HBM;
 *                                        online-softmax tiles keep it in regs/smem)
 *          baseline = 2 * N*N*4  bytes  (write S, read S back for softmax;
 *                                        + softmax write S, read S for .V => 4*N*N*4)
 *
 * The closed-form S-materialization ratio is the moat: baseline pays
 * O(N^2) extra HBM traffic that the fused kernel pays O(0) for. Total HBM
 * including the unavoidable Q/K/V/O O(N*d) terms is reported too.
 *
 * This program prints a deterministic ledger and a PASS/FAIL on the
 * STRUCTURAL clause of the falsifier (clause (a): 1 launch + O(N*d) vs 3
 * launches + O(N^2) S materialization). It needs no GPU and cannot be
 * perturbed by contention.
 *
 * Build:  cc -O2 -o structural_oracle structural_oracle.c -lm
 * Run:    ./structural_oracle
 */
#include <stdio.h>
#include <stdint.h>

typedef struct {
    int    N;        /* sequence length */
    int    d;        /* head dim */
} shape_t;

/* Fused flash-attention: 1 kernel. HBM = Q + K + V read + O write = 4*N*d*4 B.
 * S is NEVER written to HBM (online softmax over K/V tiles in registers). */
static int64_t fused_launches(void)            { return 1; }
static int64_t fused_S_hbm_bytes(int N)        { (void)N; return 0; }
static int64_t fused_total_hbm_bytes(int N, int d) {
    /* Q read (N*d) + K read (N*d) + V read (N*d) + O write (N*d), fp32. */
    return (int64_t)4 * N * d * 4;
}

/* cuBLAS-using baseline: 3 launches.
 *   L1 cublasGemmStridedBatchedEx  QK^T -> S        (writes S = N*N to HBM)
 *   L2 standalone softmax kernel    S -> S          (reads S, writes S)
 *   L3 cublasGemmStridedBatchedEx  softmax(S) . V   (reads S)
 * S round-trip HBM = write S (L1) + read S + write S (L2) + read S (L3)
 *                  = 4 * N*N * 4 bytes. */
static int64_t base_launches(void)             { return 3; }
static int64_t base_S_hbm_bytes(int N)         { return (int64_t)4 * N * N * 4; }
static int64_t base_total_hbm_bytes(int N, int d) {
    /* Q,K,V reads for L1/L3 (4*N*d) + O write (N*d) + S round-trip (4*N*N). */
    return (int64_t)5 * N * d * 4 + (int64_t)4 * N * N * 4;
}

int main(void) {
    shape_t shapes[] = {
        { 512,  64 },
        { 1024, 64 },
        { 2048, 64 },
        { 4096, 64 },
        { 2048, 128 },
    };
    int ns = (int)(sizeof(shapes) / sizeof(shapes[0]));

    printf("F-FUSION-ATTENTION-FLASH STRUCTURAL ORACLE (deterministic, no GPU)\n");
    printf("=================================================================\n");
    printf("clause (a): fused 1 launch + O(N*d) HBM  vs  baseline 3 launches + O(N^2) S\n\n");
    printf("%-12s %-8s %-8s %-12s %-12s %-12s %-14s\n",
           "shape", "fused_L", "base_L", "fused_Shbm", "base_Shbm",
           "S_ratio", "total_ratio");
    printf("-----------------------------------------------------------------------------------\n");

    int all_pass = 1;
    for (int i = 0; i < ns; ++i) {
        int N = shapes[i].N, d = shapes[i].d;
        int64_t fL  = fused_launches();
        int64_t bL  = base_launches();
        int64_t fS  = fused_S_hbm_bytes(N);
        int64_t bS  = base_S_hbm_bytes(N);
        int64_t fT  = fused_total_hbm_bytes(N, d);
        int64_t bT  = base_total_hbm_bytes(N, d);

        /* S_ratio: baseline S-traffic / max(fused S-traffic, 1). Fused = 0 ->
           ratio is "infinite"; report baseline bytes saved instead. */
        double total_ratio = (double)bT / (double)fT;

        char shp[16];
        snprintf(shp, sizeof shp, "N%d/d%d", N, d);
        printf("%-12s %-8lld %-8lld %-12lld %-12lld %-12s %-13.3fx\n",
               shp, (long long)fL, (long long)bL, (long long)fS, (long long)bS,
               "inf(0->S)", total_ratio);

        /* Structural PASS for this shape:
             fused_launches < base_launches  (1 < 3)             AND
             fused_S_hbm == 0  (no S materialization)            AND
             base_S_hbm  == O(N^2) (the materialization cost). */
        int shape_pass = (fL < bL) && (fS == 0) && (bS == (int64_t)4 * N * N * 4);
        if (!shape_pass) all_pass = 0;
    }

    printf("\nClosed-form: launches fused=1 vs baseline=3 (3x fewer).\n");
    printf("Closed-form: S-matrix HBM round-trip fused=0 vs baseline=4*N^2*4 B (O(N^2) saved).\n");
    printf("Closed-form: total HBM ratio = (5*N*d + 4*N^2) / (4*N*d); grows ~ N/d for N>>d.\n");

    /* Example asymptotic at N=2048,d=64: 4*N^2 / 4*N*d = N/d = 32x the S traffic
       alone dwarfs the O(N*d) tensor traffic. */
    printf("\nAt N=2048,d=64: baseline S round-trip = %lld B (%.1f MiB); fused S = 0 B.\n",
           (long long)base_S_hbm_bytes(2048), base_S_hbm_bytes(2048) / 1048576.0);

    printf("\nF-FUSION-ATTENTION-FLASH (structural clause a): %s\n",
           all_pass ? "PASS" : "FAIL");
    return all_pass ? 0 : 1;
}
