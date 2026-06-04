// hxqwen14b_p1b2_cmp.c — Phase 1b-2 rel-RMS comparator for two p1d_driver dumps
// (cuBLAS oracle vs our own kernel: naive / tiled / regtiled). For each output
// block (y, dA, dB, dx) it reports max|Δ|, the L2 RMS of the error, the L2 RMS
// of the signal, and rel_RMS = ||err||_2 / ||signal||_2 — the correct metric for
// a GEMM whose accumulation order differs from cuBLAS (per-element max_rel is a
// denom-floored artifact on near-zero elements; rel-RMS is order-insensitive).
//
// PASS if rel_RMS <= TOL_RMS (default 1e-4; ~sqrt(K)*eps accumulation-order diff
// vs cuBLAS for fp32 is ~1e-6, comfortably inside this gate).
//
//   cc -O2 hxqwen14b_p1b2_cmp.c -lm -o p1b2_cmp
//   ./p1b2_cmp oracle.bin own.bin

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

static float* slurp(const char* path, int64_t hdr[4], int64_t* total) {
    FILE* f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "open %s fail\n", path); exit(2); }
    if (fread(hdr, sizeof(int64_t), 4, f) != 4) { fprintf(stderr, "hdr read fail %s\n", path); exit(2); }
    int64_t n = hdr[0] + hdr[1] + hdr[2] + hdr[3];
    float* p = (float*)malloc(n * sizeof(float));
    if (fread(p, sizeof(float), n, f) != (size_t)n) { fprintf(stderr, "data read fail %s\n", path); exit(2); }
    fclose(f);
    *total = n;
    return p;
}

static void cmp_block(const char* name, const float* a, const float* b, int64_t n,
                      int* fail, double tol) {
    double maxabs = 0.0, sumerr2 = 0.0, sumsig2 = 0.0;
    for (int64_t i = 0; i < n; i++) {
        double d = fabs((double)a[i] - (double)b[i]);
        if (d > maxabs) maxabs = d;
        sumerr2 += d * d;
        sumsig2 += (double)a[i] * (double)a[i];
    }
    double rms_err = sqrt(sumerr2 / (double)n);
    double rms_sig = sqrt(sumsig2 / (double)n);
    double rel_rms = (rms_sig > 1e-30) ? rms_err / rms_sig : rms_err;
    int ok = (rel_rms <= tol);
    if (!ok) *fail = 1;
    printf("  %-4s n=%-9lld max|Δ|=%.3e  RMS_err=%.3e  RMS_sig=%.3e  rel_RMS=%.3e  %s\n",
           name, (long long)n, maxabs, rms_err, rms_sig, rel_rms, ok ? "PASS" : "FAIL");
}

int main(int argc, char** argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s oracle.bin own.bin\n", argv[0]); return 1; }
    double tol = getenv("TOL_RMS") ? atof(getenv("TOL_RMS")) : 1e-4;
    int64_t h1[4], h2[4], n1, n2;
    float* o = slurp(argv[1], h1, &n1);
    float* w = slurp(argv[2], h2, &n2);
    for (int i = 0; i < 4; i++)
        if (h1[i] != h2[i]) { fprintf(stderr, "shape mismatch dim %d\n", i); return 2; }
    int fail = 0;
    printf("== Phase 1b-2 LoRA correctness (rel-RMS): oracle(%s) vs own(%s), tol_RMS=%.1e ==\n",
           argv[1], argv[2], tol);
    int64_t off = 0;
    cmp_block("y",  o + off, w + off, h1[0], &fail, tol); off += h1[0];
    cmp_block("dA", o + off, w + off, h1[1], &fail, tol); off += h1[1];
    cmp_block("dB", o + off, w + off, h1[2], &fail, tol); off += h1[2];
    cmp_block("dx", o + off, w + off, h1[3], &fail, tol);
    printf("VERDICT: %s\n", fail ? "FAIL" : "PASS");
    return fail ? 1 : 0;
}
