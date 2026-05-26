/*
 * host_bf16.c -- GPU.md sec2c STEP-0 PROBE host harness.
 *
 * Driver-API (cuModuleLoadDataEx) load of a bf16 vec-add PTX on the
 * RTX 5070 sm_120 driver-JIT. The DECISIVE gate is whether the module
 * loads at all: if the PTX declares native `.reg .bf16` / `add.bf16` /
 * `ld.global.bf16` and the driver-JIT ptxas rejects the type, the load
 * fails with a verbatim CUDA error (printed). On a successful load the
 * harness launches the kernel and byte-compares c[i] against a bf16
 * round-trip CPU reference (a,b pre-rounded to bf16; sum rounded to bf16).
 *
 * Build: gcc -O2 host_bf16.c -I/usr/local/cuda/include -lcuda -o host_bf16
 * Fire:  ./host_bf16 <kernel.ptx>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <cuda.h>

/* IEEE 754 bfloat16 (1 sign / 8 exp / 7 mant) <-> binary32.
 * bf16 is simply the top 16 bits of an f32 (truncate or round). */
static float bf16_to_f32(uint16_t h) {
    uint32_t u = ((uint32_t)h) << 16;
    float out;
    memcpy(&out, &u, 4);
    return out;
}

/* f32 -> bf16 round-to-nearest-even. */
static uint16_t f32_to_bf16(float f) {
    uint32_t u;
    memcpy(&u, &f, 4);
    /* handle NaN: keep it quiet */
    if (((u >> 23) & 0xff) == 0xff && (u & 0x7fffff)) {
        return (uint16_t)((u >> 16) | 0x40);
    }
    uint32_t lsb = (u >> 16) & 1;
    uint32_t rounding_bias = 0x7fff + lsb;
    u += rounding_bias;
    return (uint16_t)(u >> 16);
}

#define CHECK(call) do { \
    CUresult _rc = (call); \
    if (_rc != CUDA_SUCCESS) { \
        const char *_msg = "?"; cuGetErrorString(_rc, &_msg); \
        fprintf(stderr, "[FAIL] %s = %d (%s) at %s:%d\n", #call, _rc, _msg, __FILE__, __LINE__); \
        return 2; \
    } \
} while (0)

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <kernel.ptx>\n", argv[0]); return 1; }
    const char *ptx_path = argv[1];

    FILE *f = fopen(ptx_path, "rb");
    if (!f) { perror(ptx_path); return 1; }
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    char *ptx = (char *)malloc((size_t)sz + 1);
    fread(ptx, 1, (size_t)sz, f); ptx[sz] = 0; fclose(f);

    const int N = 1024;
    uint16_t *h_a = (uint16_t *)malloc(sizeof(uint16_t) * N);
    uint16_t *h_b = (uint16_t *)malloc(sizeof(uint16_t) * N);
    uint16_t *h_c = (uint16_t *)calloc(N, sizeof(uint16_t));
    uint16_t *h_ref = (uint16_t *)calloc(N, sizeof(uint16_t));

    /* LCG fill; inputs pre-rounded to bf16. */
    uint32_t seed = 0xC0FFEE;
    for (int i = 0; i < N; i++) {
        seed = seed * 1664525u + 1013904223u;
        float av = (float)((seed >> 9) & 0x3ff) / 64.0f;   /* 0..16 */
        seed = seed * 1664525u + 1013904223u;
        float bv = (float)((seed >> 9) & 0x3ff) / 64.0f;
        h_a[i] = f32_to_bf16(av);
        h_b[i] = f32_to_bf16(bv);
        /* bf16 round-trip reference: (bf16)( (f32)a + (f32)b ) */
        h_ref[i] = f32_to_bf16(bf16_to_f32(h_a[i]) + bf16_to_f32(h_b[i]));
    }

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));

    /* --- DECISIVE GATE: driver-JIT compile the PTX --- */
    CUmodule mod;
    char jit_log[8192]; jit_log[0] = 0;
    char jit_elog[8192]; jit_elog[0] = 0;
    CUjit_option opts[4];
    void *optvals[4];
    opts[0] = CU_JIT_INFO_LOG_BUFFER;            optvals[0] = jit_log;
    opts[1] = CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES; optvals[1] = (void *)(size_t)sizeof(jit_log);
    opts[2] = CU_JIT_ERROR_LOG_BUFFER;           optvals[2] = jit_elog;
    opts[3] = CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES; optvals[3] = (void *)(size_t)sizeof(jit_elog);

    CUresult lrc = cuModuleLoadDataEx(&mod, ptx, 4, opts, optvals);
    if (lrc != CUDA_SUCCESS) {
        const char *msg = "?"; cuGetErrorString(lrc, &msg);
        printf("MODULE_LOAD: FAIL rc=%d (%s)\n", lrc, msg);
        printf("JIT_ERROR_LOG: %s\n", jit_elog[0] ? jit_elog : "(empty)");
        printf("JIT_INFO_LOG: %s\n", jit_log[0] ? jit_log : "(empty)");
        printf("VERDICT: REJECTED\n");
        return 3;
    }
    printf("MODULE_LOAD: OK\n");
    if (jit_log[0]) printf("JIT_INFO_LOG: %s\n", jit_log);

    CUfunction fn; CHECK(cuModuleGetFunction(&fn, mod, "bf16_vadd"));

    CUdeviceptr d_a, d_b, d_c;
    CHECK(cuMemAlloc(&d_a, sizeof(uint16_t) * N));
    CHECK(cuMemAlloc(&d_b, sizeof(uint16_t) * N));
    CHECK(cuMemAlloc(&d_c, sizeof(uint16_t) * N));
    CHECK(cuMemcpyHtoD(d_a, h_a, sizeof(uint16_t) * N));
    CHECK(cuMemcpyHtoD(d_b, h_b, sizeof(uint16_t) * N));
    CHECK(cuMemsetD8(d_c, 0, sizeof(uint16_t) * N));

    long long nN = N;
    void *args[4] = { &d_a, &d_b, &d_c, &nN };
    int threads = 256, blocks = (N + threads - 1) / threads;
    CHECK(cuLaunchKernel(fn, blocks, 1, 1, threads, 1, 1, 0, 0, args, 0));
    CHECK(cuCtxSynchronize());
    CHECK(cuMemcpyDtoH(h_c, d_c, sizeof(uint16_t) * N));

    int byte_mismatch = 0;
    float max_abs = 0.0f, max_abs_cref = 0.0f;
    for (int i = 0; i < N; i++) {
        if (h_c[i] != h_ref[i]) byte_mismatch++;
        float gv = bf16_to_f32(h_c[i]);
        float rv = bf16_to_f32(h_ref[i]);
        float d = fabsf(gv - rv);
        if (d > max_abs) max_abs = d;
        if (fabsf(rv) > max_abs_cref) max_abs_cref = fabsf(rv);
    }
    printf("RESULT: N=%d byte_mismatch=%d/%d max_abs=%g max_abs_cref=%g\n",
           N, byte_mismatch, N, max_abs, max_abs_cref);
    printf("VERDICT: %s\n", (byte_mismatch == 0) ? "ACCEPTED_NUMERIC_EQ" : "ACCEPTED_NUMERIC_MISMATCH");

    cuMemFree(d_a); cuMemFree(d_b); cuMemFree(d_c);
    cuModuleUnload(mod); cuCtxDestroy(ctx);
    return (byte_mismatch == 0) ? 0 : 4;
}
