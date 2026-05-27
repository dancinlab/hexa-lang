/* ═══════════════════════════════════════════════════════════════════
 * forge_rfc060b_poly_feasible.c — RFC 060 falsifier F-RFC060-POLY-FEASIBLE.
 *
 * Cheap first measurement ($0, no GPU): feed one transformer-block loop
 * nest to the isl polyhedral affine scheduler (Pluto-style) and check
 *   (a) the dependence graph is representable,
 *   (b) isl_schedule_constraints_compute_schedule returns a valid
 *       schedule (feasible ILP), and
 *   (c) it solves in seconds.
 *
 * Modeled nest = transformer-block FFN core with a preceding RMSNorm:
 *   S0r[i,k]  rmsnorm sum-of-squares      (reduction over k)
 *   S0n[i,k]  rmsnorm normalize  Xn = X*inv
 *   S1[i,j,k] matmul-1   Hm = Xn · W1     (reduction over k)
 *   S2[i,j]   silu activation   A = silu(Hm)
 *   S3[i,j,k] matmul-2   Y  = A  · W2     (reduction over k)
 * Sizes M,D,H are isl parameters (the schedule must be valid for all).
 *
 * Build:
 *   clang -std=c11 -O2 -I/opt/homebrew/include \
 *     tool/forge_rfc060b_poly_feasible.c -L/opt/homebrew/lib -lisl \
 *     -o /tmp/forge_rfc060b
 *   /tmp/forge_rfc060b
 *
 * PASS = schedule computed, non-null, in < 1.0 s wall.
 * SSOT: inbox/rfc_drafts_2026_05_12/rfc_060_forge_new_compute_paradigm.md
 * ═══════════════════════════════════════════════════════════════════ */
#include <isl/ctx.h>
#include <isl/union_set.h>
#include <isl/union_map.h>
#include <isl/schedule.h>
#include <isl/schedule_node.h>
#include <stdio.h>
#include <time.h>

int main(void) {
    isl_ctx *ctx = isl_ctx_alloc();
    int rc = 1;

    /* Iteration domains — all loop bounds affine in params M,D,H. */
    const char *domain_str =
        "[M,D,H] -> {"
        "  S0r[i,k] : 0 <= i < M and 0 <= k < D;"
        "  S0n[i,k] : 0 <= i < M and 0 <= k < D;"
        "  S1[i,j,k] : 0 <= i < M and 0 <= j < H and 0 <= k < D;"
        "  S2[i,j]   : 0 <= i < M and 0 <= j < H;"
        "  S3[i,j,k] : 0 <= i < M and 0 <= j < D and 0 <= k < H"
        "}";

    /* Validity dependences — producer -> consumer, all affine maps.
     *  S0r -> S0n : sum-of-squares of row i must finish before normalize
     *  S0n -> S1  : normalized Xn[i,k] feeds matmul-1 reduction
     *  S1  -> S2  : Hm[i,j] feeds silu
     *  S2  -> S3  : A[i,j] feeds matmul-2 reduction
     * Reduction self-deps (loop-carried on accumulator) for S0r,S1,S3. */
    const char *validity_str =
        "[M,D,H] -> {"
        "  S0r[i,k] -> S0n[i,k'] : 0 <= i < M and 0 <= k < D and 0 <= k' < D;"
        "  S0n[i,k] -> S1[i,j,k] : 0 <= i < M and 0 <= j < H and 0 <= k < D;"
        "  S1[i,j,k] -> S2[i,j]  : 0 <= i < M and 0 <= j < H and 0 <= k < D;"
        "  S2[i,j]   -> S3[i,j',j] : 0 <= i < M and 0 <= j < H and 0 <= j' < D;"
        "  S0r[i,k] -> S0r[i,k+1] : 0 <= i < M and 0 <= k < D-1;"
        "  S1[i,j,k] -> S1[i,j,k+1] : 0 <= i < M and 0 <= j < H and 0 <= k < D-1;"
        "  S3[i,j,k] -> S3[i,j,k+1] : 0 <= i < M and 0 <= j < D and 0 <= k < H-1"
        "}";

    isl_union_set *domain = isl_union_set_read_from_str(ctx, domain_str);
    isl_union_map *validity = isl_union_map_read_from_str(ctx, validity_str);
    isl_union_map *proximity = isl_union_map_copy(validity);

    if (!domain || !validity) {
        printf("F-RFC060-POLY-FEASIBLE: FAIL — domain/dependence not "
               "representable in the polyhedral model\n");
        goto done;
    }

    isl_schedule_constraints *sc =
        isl_schedule_constraints_on_domain(domain);
    sc = isl_schedule_constraints_set_validity(sc, validity);
    sc = isl_schedule_constraints_set_proximity(sc, proximity);

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    isl_schedule *sched = isl_schedule_constraints_compute_schedule(sc);
    clock_gettime(CLOCK_MONOTONIC, &t1);

    double secs = (t1.tv_sec - t0.tv_sec)
                + (t1.tv_nsec - t0.tv_nsec) / 1e9;

    if (!sched) {
        printf("F-RFC060-POLY-FEASIBLE: FAIL — no valid affine schedule "
               "(ILP infeasible)\n");
        goto done;
    }

    isl_union_map *sched_map = isl_schedule_get_map(sched);
    printf("--- isl computed schedule (transformer-block FFN+RMSNorm nest) ---\n");
    isl_union_map_dump(sched_map);
    isl_union_map_free(sched_map);
    isl_schedule_free(sched);

    int fast = (secs < 1.0);
    printf("\nF-RFC060-POLY-FEASIBLE: %s — affine schedule computed in "
           "%.4f s (threshold < 1.0 s)\n",
           fast ? "PASS" : "FAIL", secs);
    rc = fast ? 0 : 1;

done:
    isl_ctx_free(ctx);
    return rc;
}
