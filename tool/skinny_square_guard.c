// skinny_square_guard.c — f32 square-shape NON-REGRESSION guard for the #21
// rank-2 skinny-M split-K dispatch (canonical own-GEMM path).
//
// WHY: the shipped square-parity suite (D512-D4096) runs the FP64 GEMM, so it
// never exercised the f32 skinny-M gate — leaving "does the skinny branch stay
// OFF at square shapes?" unproven. This asserts it directly against the SHIPPED
// decision function _hx_skinny_shape_ok() (single-sourced in
// self/cuda/runtime_cuda_emit.hexa, exported from runtime_cuda.o) — so the test
// can never drift from the real dispatch condition.
//
// CLAIM proven here (pure decision logic, no GPU launch → runs anywhere):
//   (1) square / large-M shapes (M=N=K=D>=512, i.e. M>=64) => shape_ok==0
//       => the skinny branch is NOT taken => [SKINNY-SPLITK-FIRED] never prints
//       => the own TF32 GEMM runs the identical owngemm tile => result is
//          BIT-UNCHANGED vs HEXA_SKINNY_SPLITK unset (same code path, by
//          construction; no reduction-order change can occur when the branch
//          is skipped).
//   (2) the measured-LOSS decode batch M=16/32 is excluded (shape_ok==0).
//   (3) the measured-WIN decode region M<=8 at an underfilling N engages
//       (shape_ok==1) — positive control so the gate isn't trivially always-0.
//
// Gate constants (measured, summer RTX5070 sm_120): M<=8 win region
// (M=1 1.27x, M=8 1.16x) vs M=16/32 loss (0.95x/0.78x); underfill knee = 128.
//
// Build/link: tool/skinny_square_guard_build (links runtime_cuda.o, CPU-side —
//   NO kernel launch, so it needs no GPU to run). Compile-verify: gcc -c rc=0.

#include <stdio.h>
#include <stdint.h>

// The SHIPPED shape gate (self/cuda/runtime_cuda_emit.hexa -> runtime_cuda.o).
extern int _hx_skinny_shape_ok(int64_t M, int64_t N);

int main(void) {
    int fail = 0;
    printf("=== #21 rank-2 skinny-M square NON-REGRESSION guard ===\n");
    printf("(tests the SHIPPED _hx_skinny_shape_ok — no GPU launch)\n\n");

    // (1) Square parity-suite shapes: M=N=K=D, so M>=64 -> must NOT engage.
    const int64_t sq[] = { 512, 768, 1024, 2048, 4096 };
    for (int i = 0; i < 5; i++) {
        int64_t D = sq[i];
        int ok = _hx_skinny_shape_ok(D, D);
        printf("  square  M=N=K=%-5lld : skinny=%d  (expect 0)%s\n",
               (long long)D, ok, ok ? "  <-- FAIL" : "");
        if (ok != 0) fail = 1;
    }

    // (2) Measured-LOSS decode batch (M>=16) at the decode projection N -> excluded.
    const int64_t lossM[] = { 16, 32 };
    for (int i = 0; i < 2; i++) {
        int ok = _hx_skinny_shape_ok(lossM[i], 1024);
        printf("  loss    M=%-2lld N=1024   : skinny=%d  (expect 0, measured-loss)%s\n",
               (long long)lossM[i], ok, ok ? "  <-- FAIL" : "");
        if (ok != 0) fail = 1;
    }

    // (3) Positive control: measured-WIN decode region (M<=8) at underfilling N.
    struct { int64_t M, N; } win[] = { {1,1024}, {4,1024}, {8,1024}, {8,3072}, {8,4096} };
    for (int i = 0; i < 5; i++) {
        int ok = _hx_skinny_shape_ok(win[i].M, win[i].N);
        printf("  win     M=%-2lld N=%-4lld  : skinny=%d  (expect 1)%s\n",
               (long long)win[i].M, (long long)win[i].N, ok, ok ? "" : "  <-- FAIL");
        if (ok != 1) fail = 1;
    }

    printf("\n=== VERDICT: %s ===\n",
           fail ? "FAIL — gate does not match the measured win/loss regions"
                : "PASS — skinny OFF at all square/loss shapes, ON only in the M<=8 win region");
    return fail;
}
