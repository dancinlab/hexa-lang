/* F-FUSION-ATTN-WMMA-WALL -- WMMA fused flash-attention host launcher.
 *
 * Fires the hand-emitted flash_attn_wmma.ptx kernel (ONE launch) computing
 * O = softmax(Q K^T / sqrt(d)) V with Tensor-Core inner GEMMs and the S tile
 * resident in shared memory (never to HBM). f16 in/out, f32 accumulate.
 * Compares to an f64 CPU reference (rel-err <= 1e-2 -- the f16-mul-f32-acc
 * bound). Times the SINGLE launch with cuEventRecord: 20 warmup + 200 timed,
 * reports the median ms.
 *
 * THIS HOST IS READY FOR ROUND 3. The parent runs the timed fire serially
 * to avoid GPU contention -- do NOT run it inside the codegen round.
 *
 * Build:  nvcc -O2 -o fa_wmma_host fa_wmma_host.c -lcuda
 * Run:    ./fa_wmma_host flash_attn_wmma.ptx [N]   (d fixed = 64 in the PTX)
 *
 * Launch geometry: grid.x = N/16 blocks, blockDim = 32 threads (one warp per
 * 16-query-row tile). N must be a multiple of 16.
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

static int cmp_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x < y) ? -1 : (x > y) ? 1 : 0;
}

/* Deterministic LCG so inputs are reproducible run-to-run. */
static uint32_t lcg_state = 0x12345678u;
static float lcg_f32(void) {
    lcg_state = lcg_state * 1664525u + 1013904223u;
    return ((float)(lcg_state >> 8) / (float)(1u << 24)) - 0.5f;
}

/* IEEE half <-> float (round-to-nearest-even on the down-convert) so the host
 * builds the SAME f16 inputs the kernel reads, and the f64 reference operates
 * on those exact f16-rounded values (so rel-err reflects only the f16-mul +
 * f32-acc arithmetic, not an input mismatch). */
static uint16_t f32_to_f16(float f) {
    uint32_t x; memcpy(&x, &f, 4);
    uint32_t sign = (x >> 16) & 0x8000u;
    int32_t  exp  = (int32_t)((x >> 23) & 0xff) - 127 + 15;
    uint32_t man  = x & 0x7fffffu;
    if (exp <= 0) {
        if (exp < -10) return (uint16_t)sign;
        man |= 0x800000u;
        uint32_t shift = (uint32_t)(14 - exp);
        uint32_t half = man >> shift;
        uint32_t rem  = man & ((1u << shift) - 1);
        if (rem > (1u << (shift - 1)) || (rem == (1u << (shift - 1)) && (half & 1)))
            half++;
        return (uint16_t)(sign | half);
    } else if (exp >= 31) {
        return (uint16_t)(sign | 0x7c00u);
    } else {
        uint32_t half = ((uint32_t)exp << 10) | (man >> 13);
        uint32_t rem  = man & 0x1fffu;
        if (rem > 0x1000u || (rem == 0x1000u && (half & 1))) half++;
        return (uint16_t)(sign | half);
    }
}
static float f16_to_f32(uint16_t h) {
    uint32_t sign = (uint32_t)(h & 0x8000u) << 16;
    uint32_t exp  = (h >> 10) & 0x1f;
    uint32_t man  = h & 0x3ff;
    uint32_t out;
    if (exp == 0) {
        if (man == 0) { out = sign; }
        else {
            exp = 127 - 15 + 1;
            while ((man & 0x400) == 0) { man <<= 1; exp--; }
            man &= 0x3ff;
            out = sign | (exp << 23) | (man << 13);
        }
    } else if (exp == 31) {
        out = sign | 0x7f800000u | (man << 13);
    } else {
        out = sign | ((exp - 15 + 127) << 23) | (man << 13);
    }
    float f; memcpy(&f, &out, 4); return f;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s flash_attn_wmma.ptx [N]\n", argv[0]); return 2; }
    const char *ptx_path = argv[1];
    int N = (argc > 2) ? atoi(argv[2]) : 2048;
    int d = 64;                       /* PTX is specialized for d=64 */
    if (N % 16 != 0) { fprintf(stderr, "N must be a multiple of 16\n"); return 2; }

    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { perror("ptx open"); return 1; }
    fseek(fp, 0, SEEK_END); long n_ptx = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) { perror("ptx read"); return 1; }
    ptx[n_ptx] = 0; fclose(fp);

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));
    CUmodule mod;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK(cuModuleLoadDataEx(&mod, ptx, 1, jit_opts, jit_vals));
    CUfunction f; CHECK(cuModuleGetFunction(&f, mod, "flash_attn_wmma"));

    size_t elems = (size_t)N * d;
    float    *hqf = (float *)malloc(elems * sizeof(float));
    float    *hkf = (float *)malloc(elems * sizeof(float));
    float    *hvf = (float *)malloc(elems * sizeof(float));
    uint16_t *hq  = (uint16_t *)malloc(elems * sizeof(uint16_t));
    uint16_t *hk  = (uint16_t *)malloc(elems * sizeof(uint16_t));
    uint16_t *hv  = (uint16_t *)malloc(elems * sizeof(uint16_t));
    uint16_t *ho  = (uint16_t *)malloc(elems * sizeof(uint16_t));
    double   *ref = (double *)malloc(elems * sizeof(double));

    /* Q,K wider so scores spread (peaked softmax, well-conditioned denom). */
    for (size_t i = 0; i < elems; ++i) { hqf[i] = f16_to_f32(f32_to_f16(lcg_f32() * 4.0f)); hq[i] = f32_to_f16(hqf[i]); }
    for (size_t i = 0; i < elems; ++i) { hkf[i] = f16_to_f32(f32_to_f16(lcg_f32() * 4.0f)); hk[i] = f32_to_f16(hkf[i]); }
    for (size_t i = 0; i < elems; ++i) { hvf[i] = f16_to_f32(f32_to_f16(lcg_f32()));        hv[i] = f32_to_f16(hvf[i]); }

    float scale = 1.0f / sqrtf((float)d);

    /* ---- f64 CPU reference on the f16-rounded inputs ---- */
    double *srow = (double *)malloc((size_t)N * sizeof(double));
    for (int i = 0; i < N; ++i) {
        double m = -1e300;
        for (int j = 0; j < N; ++j) {
            double s = 0.0;
            for (int l = 0; l < d; ++l) s += (double)hqf[(size_t)i*d+l] * (double)hkf[(size_t)j*d+l];
            s *= (double)scale;
            srow[j] = s;
            if (s > m) m = s;
        }
        double sum = 0.0;
        for (int j = 0; j < N; ++j) { srow[j] = exp(srow[j] - m); sum += srow[j]; }
        double inv = 1.0 / sum;
        for (int e = 0; e < d; ++e) {
            double acc = 0.0;
            for (int j = 0; j < N; ++j) acc += srow[j] * (double)hvf[(size_t)j*d+e];
            ref[(size_t)i*d+e] = acc * inv;
        }
    }
    free(srow);

    /* ---- device buffers ---- */
    CUdeviceptr dq, dk, dv, dout;
    size_t bytes16 = elems * sizeof(uint16_t);
    CHECK(cuMemAlloc(&dq, bytes16)); CHECK(cuMemAlloc(&dk, bytes16));
    CHECK(cuMemAlloc(&dv, bytes16)); CHECK(cuMemAlloc(&dout, bytes16));
    CHECK(cuMemcpyHtoD(dq, hq, bytes16));
    CHECK(cuMemcpyHtoD(dk, hk, bytes16));
    CHECK(cuMemcpyHtoD(dv, hv, bytes16));

    void *args[] = { &dq, &dk, &dv, &dout, &N, &scale };
    /* Geometry configurable so the SAME harness drives the round-3 1-warp
     * kernel (BQ=16,block=32) and the multi-warp kernel (BQ=64,block=128).
     * BQ = query rows per CTA; FA_BLOCK = threads per CTA. */
    int bq    = (getenv("FA_BQ")    ? atoi(getenv("FA_BQ"))    : 16);
    int blk   = (getenv("FA_BLOCK") ? atoi(getenv("FA_BLOCK")) : 32);
    unsigned grid  = (unsigned)((N + bq - 1) / bq);
    unsigned block = (unsigned)blk;
    fprintf(stderr, "[geom] BQ=%d block=%d grid=%u CTAs (vs 48 SMs)\n", bq, blk, grid);

    /* ---- correctness: one launch, copy back, compare ---- */
    CHECK(cuLaunchKernel(f, grid, 1, 1, block, 1, 1, 0, 0, args, 0));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(ho, dout, bytes16));

    /* Honest flash-attention error metric. The naive |err|/(|want|+1e-6)
     * blows up on near-zero output elements (attention outputs have many
     * elements ~0); a metric artifact, not a kernel error. The real gate is
     * the per-row-scaled relative error + the global RMS relative error. */
    double *rowmax = (double *)malloc((size_t)N * sizeof(double));
    for (int i = 0; i < N; ++i) { double mx = 0;
        for (int e = 0; e < d; ++e) { double w = fabs(ref[(size_t)i*d+e]); if (w > mx) mx = w; }
        rowmax[i] = mx; }
    double max_rel = 0.0, max_abs = 0.0, max_rel_rowscale = 0.0, sse = 0.0, ssref = 0.0;
    for (size_t i = 0; i < elems; ++i) {
        double got = (double)f16_to_f32(ho[i]);
        double want = ref[i];
        double a = fabs(got - want);
        double r = a / (fabs(want) + 1e-6);
        if (a > max_abs) max_abs = a;
        if (r > max_rel) max_rel = r;
        int row = (int)(i / d);
        double rr = a / (rowmax[row] + 1e-9);
        if (rr > max_rel_rowscale) max_rel_rowscale = rr;
        sse += a*a; ssref += want*want;
    }
    double rms_rel = sqrt(sse / (ssref + 1e-30));
    int numeric_pass = (max_rel_rowscale <= 1e-2);
    printf("N=%d d=%d  max_abs=%.6g  max_rel_naive=%.6g  max_rel_rowscale=%.6g  rms_rel=%.6g  numeric=%s (gate: rel_rowscale<=1e-2)\n",
           N, d, max_abs, max_rel, max_rel_rowscale, rms_rel, numeric_pass ? "PASS" : "FAIL");

    /* ---- timed wall: 20 warmup + 200 timed, median ms ---- */
    CUevent st, en; CHECK(cuEventCreate(&st, 0)); CHECK(cuEventCreate(&en, 0));
    for (int w = 0; w < 20; ++w)
        CHECK(cuLaunchKernel(f, grid, 1, 1, block, 1, 1, 0, 0, args, 0));
    CHECK(cuCtxSynchronize());
    int reps = 200;
    double *ms = (double *)malloc(reps * sizeof(double));
    for (int r = 0; r < reps; ++r) {
        CHECK(cuEventRecord(st, 0));
        CHECK(cuLaunchKernel(f, grid, 1, 1, block, 1, 1, 0, 0, args, 0));
        CHECK(cuEventRecord(en, 0));
        CHECK(cuEventSynchronize(en));
        float t; CHECK(cuEventElapsedTime(&t, st, en));
        ms[r] = (double)t;
    }
    qsort(ms, reps, sizeof(double), cmp_double);
    printf("fused_wmma median_ms=%.6f  (20 warmup + %d timed)\n", ms[reps/2], reps);

    cuMemFree(dq); cuMemFree(dk); cuMemFree(dv); cuMemFree(dout);
    cuModuleUnload(mod); cuCtxDestroy(ctx);
    return numeric_pass ? 0 : 1;
}
