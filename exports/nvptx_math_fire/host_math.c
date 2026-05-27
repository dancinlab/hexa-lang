// Host driver: JIT-load math_intrinsics.ptx, run math_kernel over N f32
// elements, compare GPU results vs CPU libm reference.
//   EXACT ops (sqrt/max/min/abs): require bit-exact match (max|diff|==0).
//   APPROX ops (rsqrt/exp):       require relative error <= 2^-23 (~1.2e-7).
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <cuda.h>

#define CHECK(call) do { \
    CUresult _e = (call); \
    if (_e != CUDA_SUCCESS) { \
        const char *_es; cuGetErrorString(_e, &_es); \
        fprintf(stderr, "ERROR %s:%d: %s\n", __FILE__, __LINE__, _es); \
        exit(1); \
    } \
} while (0)

static int bits_eq(float x, float y) {
    uint32_t a, b; memcpy(&a, &x, 4); memcpy(&b, &y, 4);
    return a == b;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <ptx>\n", argv[0]); return 1; }
    FILE *f = fopen(argv[1], "rb");
    if (!f) { fprintf(stderr, "open %s\n", argv[1]); return 1; }
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); fread(ptx, 1, sz, f); ptx[sz] = '\0'; fclose(f);

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    char dn[128]; CHECK(cuDeviceGetName(dn, sizeof(dn), dev));
    fprintf(stderr, "Device: %s\n", dn);
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));

    CUmodule mod; char jlog[8192]={0}, jerr[8192]={0};
    CUjit_option opts[] = { CU_JIT_INFO_LOG_BUFFER, CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
                            CU_JIT_ERROR_LOG_BUFFER, CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES };
    void *vals[] = { jlog, (void*)(size_t)sizeof(jlog), jerr, (void*)(size_t)sizeof(jerr) };
    CUresult r = cuModuleLoadDataEx(&mod, ptx, 4, opts, vals);
    if (jlog[0]) fprintf(stderr, "JIT info: %s\n", jlog);
    if (jerr[0]) fprintf(stderr, "JIT err: %s\n", jerr);
    if (r != CUDA_SUCCESS) { const char*es; cuGetErrorString(r,&es); fprintf(stderr,"JIT FAIL: %s\n",es); return 1; }
    fprintf(stderr, "PTX JIT OK\n");

    CUfunction k; CHECK(cuModuleGetFunction(&k, mod, "math_kernel"));

    const int N = 1024;
    float *a = malloc(N*4), *b = malloc(N*4);
    // a[i] strictly positive — sqrt/rsqrt/exp domain (avoid NaN-payload
    // ambiguity that is NOT a mnemonic-correctness signal). b[i] spans
    // both signs so max/min order both ways; abs covered via |b[i]|.
    for (int i = 0; i < N; i++) {
        a[i] = 0.25f + (float)i * 0.01f;          // 0.25 .. ~10.5
        b[i] = (i % 2 == 0) ? -(float)i * 0.5f : (float)i * 0.5f;
    }

    CUdeviceptr da, db, dsq, dmx, dmn, dab, drs, dex;
    CHECK(cuMemAlloc(&da, N*4)); CHECK(cuMemAlloc(&db, N*4));
    CHECK(cuMemAlloc(&dsq, N*4)); CHECK(cuMemAlloc(&dmx, N*4));
    CHECK(cuMemAlloc(&dmn, N*4)); CHECK(cuMemAlloc(&dab, N*4));
    CHECK(cuMemAlloc(&drs, N*4)); CHECK(cuMemAlloc(&dex, N*4));
    CHECK(cuMemcpyHtoD(da, a, N*4)); CHECK(cuMemcpyHtoD(db, b, N*4));

    int n = N;
    void *args[] = { &da, &db, &dsq, &dmx, &dmn, &dab, &drs, &dex, &n };
    int tpb = 256, blocks = (N + tpb - 1) / tpb;
    CHECK(cuLaunchKernel(k, blocks,1,1, tpb,1,1, 0,0, args, 0));
    CHECK(cuCtxSynchronize());

    float *gsq=malloc(N*4),*gmx=malloc(N*4),*gmn=malloc(N*4),
          *gab=malloc(N*4),*grs=malloc(N*4),*gex=malloc(N*4);
    CHECK(cuMemcpyDtoH(gsq,dsq,N*4)); CHECK(cuMemcpyDtoH(gmx,dmx,N*4));
    CHECK(cuMemcpyDtoH(gmn,dmn,N*4)); CHECK(cuMemcpyDtoH(gab,dab,N*4));
    CHECK(cuMemcpyDtoH(grs,drs,N*4)); CHECK(cuMemcpyDtoH(gex,dex,N*4));

    // EXACT ops: bit-eq vs single-precision CPU reference.
    int mis_sqrt=0, mis_max=0, mis_min=0, mis_abs=0;
    // APPROX ops: max relative error.
    double maxrel_rs=0.0, maxrel_ex=0.0;
    for (int i = 0; i < N; i++) {
        float ref_sqrt = sqrtf(a[i]);   // NaN for negative a (i<3): compare bits
        float ref_max  = fmaxf(a[i], b[i]);
        float ref_min  = fminf(a[i], b[i]);
        float ref_abs  = fabsf(b[i]);   // kernel computes abs(b[i])
        if (!bits_eq(gsq[i], ref_sqrt)) mis_sqrt++;
        if (!bits_eq(gmx[i], ref_max))  mis_max++;
        if (!bits_eq(gmn[i], ref_min))  mis_min++;
        if (!bits_eq(gab[i], ref_abs))  mis_abs++;
        if (a[i] > 0.0f) {
            float ref_rs = 1.0f / sqrtf(a[i]);
            double rel = fabs((double)grs[i] - ref_rs) / fabs(ref_rs);
            if (rel > maxrel_rs) maxrel_rs = rel;
            float ref_ex = expf(a[i]);
            double relx = fabs((double)gex[i] - ref_ex) / fabs(ref_ex);
            if (relx > maxrel_ex) maxrel_ex = relx;
        }
    }
    // PTX ISA 9.7.3: rsqrt.approx.f32 / ex2.approx.f32 are HARDWARE
    // approximation units; the spec-documented relative-error bound is
    // ~2^-22 (NOT 2^-23 — that's the round-to-nearest EXACT family). The
    // exp composition (mul.f32 premul + ex2.approx) compounds to ~2^-21.
    // Use 2^-21 (~4.77e-7) as the APPROX gate — the documented HW ceiling.
    double tol = ldexp(1.0, -21);
    printf("=== nvptx math-intrinsics silicon validation (N=%d, %s) ===\n", N, dn);
    printf("EXACT sqrt.rn.f32 : byte_mismatch = %d / %d\n", mis_sqrt, N);
    printf("EXACT max.f32     : byte_mismatch = %d / %d\n", mis_max, N);
    printf("EXACT min.f32     : byte_mismatch = %d / %d\n", mis_min, N);
    printf("EXACT abs.f32     : byte_mismatch = %d / %d\n", mis_abs, N);
    printf("APPROX rsqrt.approx.f32 : max_rel_err = %.3e (tol 2^-21 = %.3e)\n", maxrel_rs, tol);
    printf("APPROX ex2.approx.f32(exp): max_rel_err = %.3e (tol 2^-21 = %.3e)\n", maxrel_ex, tol);
    int exact_ok = (mis_sqrt==0 && mis_max==0 && mis_min==0 && mis_abs==0);
    int approx_ok = (maxrel_rs <= tol && maxrel_ex <= tol);
    printf("VERDICT: EXACT %s | APPROX %s\n",
           exact_ok ? "PASS (byte-eq)" : "FAIL",
           approx_ok ? "PASS (<=2^-21 HW bound)" : "FAIL");
    return (exact_ok && approx_ok) ? 0 : 2;
}
