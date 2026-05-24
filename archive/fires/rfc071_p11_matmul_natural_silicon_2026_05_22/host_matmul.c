/*
 * host_matmul.c — RFC 071 P11 NATURAL-LOOP matmul source-to-silicon fire harness
 *
 * Built for /Users/ghost/core/hexa-lang/inbox/fires/rfc071_p11_matmul_natural_silicon_2026_05_22
 *
 * IDENTICAL to the P10/N129 harness EXCEPT the kernel name is `matmul_naive`
 * (the natural triple-loop fixture's fn name) instead of `matmul_kernel`.
 *
 * Loads the PTX via cuModuleLoadDataEx (driver-JIT), launches
 * matmul_naive(a, b, c, M=N=K=64), compares against CPU FP32 reference,
 * reports max_abs / max_rel + per-cell byte_mismatch counts.
 *
 * STATUS (N164, 2026-05-22): THIS HARNESS IS NOT FIRED THIS CYCLE because the
 * N143 HIR->MIR auto-synth matcher (`_hir_is_nested_matmul_body`) is WIPED from
 * origin/main (commit e8c2dc1c). The natural-loop fixture emits SCALAR-LOOP PTX
 * with ZERO `wmma.*` instructions, so firing would test the wrong code path.
 * Once N143 is restored in compiler/lower/hir_to_mir.hexa and the fixture
 * re-emits `wmma.load.a/b` + `wmma.mma` + `wmma.store.d`, this harness is
 * ready: fire on ubu-1 as below.
 *
 * Memory layout: a[64*64] f16 (LCG-fill), b[64*64] f16 (LCG-fill),
 * c[64*64] f32 (zero-init device-side). CPU reference c_ref[i,j] = sum_k
 * (float)a[i,k] * (float)b[k,j] (row-major, nn.Linear convention matching N129).
 *
 * Tolerance: 4 ULP FP32 (FP16-input, FP32-accumulate WMMA emit per N128).
 *
 * Build:  gcc -O2 host_matmul.c -lcuda -o host_matmul
 * Fire:   ./host_matmul matmul_naive.sm_80.ptx
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <cuda.h>

/* IEEE 754 binary16 -> binary32. */
static float f16_to_f32(uint16_t h) {
    uint32_t sign = (uint32_t)(h >> 15) & 0x1;
    uint32_t exp  = (uint32_t)(h >> 10) & 0x1f;
    uint32_t mant = (uint32_t)h & 0x3ff;
    uint32_t f;
    if (exp == 0) {
        if (mant == 0) {
            f = sign << 31;
        } else {
            int e = -1;
            do { e++; mant <<= 1; } while ((mant & 0x400) == 0);
            mant &= 0x3ff;
            f = (sign << 31) | ((uint32_t)(127 - 15 - e) << 23) | (mant << 13);
        }
    } else if (exp == 31) {
        f = (sign << 31) | 0x7f800000 | (mant << 13);
    } else {
        f = (sign << 31) | ((uint32_t)(exp - 15 + 127) << 23) | (mant << 13);
    }
    float out;
    memcpy(&out, &f, 4);
    return out;
}

/* f32 -> f16 round-to-nearest-even. */
static uint16_t f32_to_f16(float f) {
    uint32_t u;
    memcpy(&u, &f, 4);
    uint32_t sign = (u >> 16) & 0x8000;
    int32_t  exp  = (int32_t)((u >> 23) & 0xff) - 127 + 15;
    uint32_t mant = u & 0x7fffff;
    if (exp <= 0) {
        if (exp < -10) return (uint16_t)sign;
        mant |= 0x800000;
        uint32_t shift = (uint32_t)(14 - exp);
        uint32_t h = mant >> shift;
        if ((mant >> (shift - 1)) & 1) h += 1;
        return (uint16_t)(sign | h);
    } else if (exp >= 31) {
        return (uint16_t)(sign | 0x7c00);
    }
    uint16_t h = (uint16_t)(sign | (exp << 10) | (mant >> 13));
    if ((mant >> 12) & 1) h += 1;
    return h;
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
    if (argc < 2) {
        fprintf(stderr, "usage: %s <kernel.ptx>\n", argv[0]);
        return 1;
    }
    const char *ptx_path = argv[1];

    FILE *f = fopen(ptx_path, "rb");
    if (!f) { perror(ptx_path); return 1; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *ptx = (char *)malloc((size_t)sz + 1);
    fread(ptx, 1, (size_t)sz, f);
    ptx[sz] = 0;
    fclose(f);

    const int M = 64, N = 64, K = 64;

    uint16_t *h_a = (uint16_t *)malloc(sizeof(uint16_t) * (size_t)(M * K));
    uint16_t *h_b = (uint16_t *)malloc(sizeof(uint16_t) * (size_t)(K * N));
    float    *h_c = (float    *)calloc((size_t)(M * N), sizeof(float));
    float    *h_ref = (float  *)calloc((size_t)(M * N), sizeof(float));

    uint32_t seed = 0xC0FFEE;
    for (int i = 0; i < M * K; i++) {
        seed = seed * 1664525u + 1013904223u;
        float v = ((float)(seed & 0xFFFF) / 65535.0f) * 2.0f - 1.0f;
        h_a[i] = f32_to_f16(v);
    }
    for (int i = 0; i < K * N; i++) {
        seed = seed * 1664525u + 1013904223u;
        float v = ((float)(seed & 0xFFFF) / 65535.0f) * 2.0f - 1.0f;
        h_b[i] = f32_to_f16(v);
    }

    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            float acc = 0.0f;
            for (int k = 0; k < K; k++) {
                acc += f16_to_f32(h_a[i * K + k]) * f16_to_f32(h_b[k * N + j]);
            }
            h_ref[i * N + j] = acc;
        }
    }

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));

    CUmodule mod;
    char log_err[8192]; log_err[0] = 0;
    char log_info[4096]; log_info[0] = 0;
    CUjit_option opts[5] = {
        CU_JIT_TARGET_FROM_CUCONTEXT,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
    };
    void *vals[5] = {
        (void *)0,
        (void *)log_err,
        (void *)(uintptr_t)sizeof(log_err),
        (void *)log_info,
        (void *)(uintptr_t)sizeof(log_info),
    };
    CUresult mod_rc = cuModuleLoadDataEx(&mod, ptx, 5, opts, vals);
    if (mod_rc != CUDA_SUCCESS) {
        const char *m = "?"; cuGetErrorString(mod_rc, &m);
        fprintf(stderr, "[FAIL] cuModuleLoadDataEx = %d (%s)\n  err log: %s\n  info log: %s\n",
                mod_rc, m, log_err, log_info);
        return 3;
    }
    fprintf(stderr, "[JIT info] %s\n", log_info);

    CUfunction kernel;
    CHECK(cuModuleGetFunction(&kernel, mod, "matmul_naive"));

    CUdeviceptr d_a, d_b, d_c;
    CHECK(cuMemAlloc(&d_a, sizeof(uint16_t) * (size_t)(M * K)));
    CHECK(cuMemAlloc(&d_b, sizeof(uint16_t) * (size_t)(K * N)));
    CHECK(cuMemAlloc(&d_c, sizeof(float)    * (size_t)(M * N)));
    CHECK(cuMemcpyHtoD(d_a, h_a, sizeof(uint16_t) * (size_t)(M * K)));
    CHECK(cuMemcpyHtoD(d_b, h_b, sizeof(uint16_t) * (size_t)(K * N)));
    CHECK(cuMemsetD32(d_c, 0, (size_t)(M * N)));

    int Mi = M, Ni = N, Ki = K;
    void *params[6];
    params[0] = &d_a;
    params[1] = &d_b;
    params[2] = &d_c;
    params[3] = &Mi;
    params[4] = &Ni;
    params[5] = &Ki;

    CHECK(cuLaunchKernel(kernel,
        /* gridDim  */ (unsigned)(N / 16), (unsigned)(M / 16), 1u,
        /* blockDim */ 32u, 1u, 1u,
        /* shared   */ 0,
        /* stream   */ NULL,
        /* params   */ params,
        /* extra    */ NULL));
    CHECK(cuCtxSynchronize());

    CHECK(cuMemcpyDtoH(h_c, d_c, sizeof(float) * (size_t)(M * N)));

    double max_abs = 0.0, max_rel = 0.0;
    int byte_mismatch = 0;
    int first_nonzero = -1;
    int c_nonzero = 0;
    for (int i = 0; i < M * N; i++) {
        if (h_c[i] != 0.0f && first_nonzero < 0) first_nonzero = i;
        if (h_c[i] != 0.0f) c_nonzero++;
        double a = (double)h_c[i];
        double r = (double)h_ref[i];
        double d = fabs(a - r);
        if (d > max_abs) max_abs = d;
        double rel = (fabs(r) > 1e-12) ? d / fabs(r) : 0.0;
        if (rel > max_rel) max_rel = rel;
        if (memcmp(&h_c[i], &h_ref[i], sizeof(float)) != 0) byte_mismatch++;
    }

    printf("{\n");
    printf("  \"M\": %d, \"N\": %d, \"K\": %d,\n", M, N, K);
    printf("  \"max_abs\": %.6e,\n", max_abs);
    printf("  \"max_rel\": %.6e,\n", max_rel);
    printf("  \"byte_mismatch\": %d,\n", byte_mismatch);
    printf("  \"c_nonzero_cells\": %d,\n", c_nonzero);
    printf("  \"first_nonzero_idx\": %d,\n", first_nonzero);
    printf("  \"ref_first_8\": [%.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f],\n",
        h_ref[0], h_ref[1], h_ref[2], h_ref[3], h_ref[4], h_ref[5], h_ref[6], h_ref[7]);
    printf("  \"got_first_8\": [%.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f]\n",
        h_c[0], h_c[1], h_c[2], h_c[3], h_c[4], h_c[5], h_c[6], h_c[7]);
    printf("}\n");

    cuMemFree(d_a); cuMemFree(d_b); cuMemFree(d_c);
    cuModuleUnload(mod); cuCtxDestroy(ctx);
    free(h_a); free(h_b); free(h_c); free(h_ref); free(ptx);
    return (max_abs > 1e-2) ? 4 : 0;
}
