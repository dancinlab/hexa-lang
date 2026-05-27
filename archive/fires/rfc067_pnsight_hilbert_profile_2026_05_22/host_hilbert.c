/* RFC 067 P-nsight-Hilbert -- Single-shape profile driver for ncu/nsys (2026-05-22)
 *
 * Goal: profile a SINGLE N149 Hilbert-swizzle 4-warp 64x64 hexa HGEMM kernel launch
 *       at a given M=N=K (square, M chosen at runtime by argv) so ncu kernel-replay
 *       collects metrics for ONE shape per invocation.
 *
 * KEY DIFFERENCE vs N157 host_one.c (super-block / no-swizzle):
 *   The Hilbert (Pattern B) launch grid is p x p where p = next_pow2(side),
 *   side = M/64. The kernel computes (sw_x,sw_y)=d2xy(p, ctaid.y*p+ctaid.x) and
 *   early-returns padding CTAs (sw_x>=gx || sw_y>=gy). This is bijective over the
 *   real gx x gy grid -> bit-exact. The super-block kernel used grid=(M/64,M/64);
 *   Hilbert needs the next_pow2 square launch (matches N149 host.c exactly).
 *     M=4096 -> side 64  -> p=64   (no padding)
 *     M=6144 -> side 96  -> p=128  (16384 launched, 9216 real, 7168 padding-return)
 *     M=8192 -> side 128 -> p=128  (no padding)
 *
 * Kernel body byte-identical to N107 PY / N134 super-block; ONLY the CTA visitation
 * order (Hilbert d2xy vs super-block) and launch grid (p x p vs side x side) differ.
 *
 * argv: ./host_hilbert  <ptx_path>  <M>  <entry_name>  <nreps>
 *
 * Build:
 *   nvcc -O2 -arch=sm_90 -o host_hilbert host_hilbert.c -lcuda -lcublas -lm
 *
 * Run:
 *   ./host_hilbert  sgemm_4warp_hilbert_6144x6144_grid.ptx  6144  sgemm_4warp_hilbert_6144x6144_grid  1
 */

#include <cuda.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#define CHECK_CU(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA driver error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

#define CHECK_RT(call) do { cudaError_t e = (call); \
    if (e != cudaSuccess) { \
        fprintf(stderr, "CUDA runtime error %d at %s:%d: %s\n", e, __FILE__, __LINE__, cudaGetErrorString(e)); \
        return 1; }} while (0)

/* Hilbert launch grid is p x p where p = next_pow2(side). */
static unsigned int next_pow2_u(unsigned int n) {
    unsigned int p = 1;
    while (p < n) p <<= 1;
    return p;
}

static unsigned short f32_to_f16(float f) {
    unsigned int x; memcpy(&x, &f, 4);
    unsigned int sign = (x >> 31) & 0x1;
    int exp = (int)((x >> 23) & 0xff) - 127 + 15;
    unsigned int mant = x & 0x7fffff;
    unsigned short out;
    if (exp >= 31) {
        out = (sign << 15) | (0x1f << 10) | (mant ? (mant >> 13) : 0);
    } else if (exp <= 0) {
        if (exp < -10) {
            out = (sign << 15);
        } else {
            mant |= 0x800000;
            int shift = 14 - exp;
            out = (sign << 15) | (mant >> shift);
        }
    } else {
        out = (sign << 15) | (exp << 10) | (mant >> 13);
    }
    return out;
}

static int load_ptx_kernel(const char *ptx_path, const char *entry,
                           CUmodule *out_mod, CUfunction *out_fn)
{
    FILE *fp = fopen(ptx_path, "rb");
    if (!fp) { fprintf(stderr, "ptx open %s: ", ptx_path); perror(""); return 1; }
    fseek(fp, 0, SEEK_END);
    long n_ptx = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n_ptx + 1);
    if (fread(ptx, 1, n_ptx, fp) != (size_t)n_ptx) {
        fprintf(stderr, "ptx short read %s\n", ptx_path); return 1;
    }
    ptx[n_ptx] = 0;
    fclose(fp);

    char log_err[8192]; log_err[0] = 0;
    char log_info[8192]; log_info[0] = 0;
    CUjit_option jit_opts[5] = {
        CU_JIT_TARGET_FROM_CUCONTEXT,
        CU_JIT_ERROR_LOG_BUFFER,
        CU_JIT_ERROR_LOG_BUFFER_SIZE_BYTES,
        CU_JIT_INFO_LOG_BUFFER,
        CU_JIT_INFO_LOG_BUFFER_SIZE_BYTES,
    };
    void *jit_vals[5] = {
        (void *)0,
        (void *)log_err,
        (void *)(uintptr_t)sizeof(log_err),
        (void *)log_info,
        (void *)(uintptr_t)sizeof(log_info),
    };
    CUresult e = cuModuleLoadDataEx(out_mod, ptx, 5, jit_opts, jit_vals);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleLoadDataEx %s: %s\n", ptx_path, s ? s : "?");
        if (log_err[0]) fprintf(stderr, "  ptxas err: %s\n", log_err);
        free(ptx); return 1;
    }
    e = cuModuleGetFunction(out_fn, *out_mod, entry);
    if (e != CUDA_SUCCESS) {
        const char *s = NULL; cuGetErrorString(e, &s);
        fprintf(stderr, "cuModuleGetFunction %s %s: %s\n", ptx_path, entry, s ? s : "?");
        free(ptx); return 1;
    }
    free(ptx);
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: %s <ptx_path> <M> <entry_name> [nreps=10]\n", argv[0]);
        return 2;
    }
    const char *ptx_path = argv[1];
    int M = atoi(argv[2]);
    const char *entry = argv[3];
    int nreps = (argc >= 5) ? atoi(argv[4]) : 10;
    int warmup = 3;
    int N = M, K = M;

    CHECK_CU(cuInit(0));
    CUdevice  dev;     CHECK_CU(cuDeviceGet(&dev, 0));
    CUcontext ctx;     CHECK_CU(cuCtxCreate(&ctx, 0, dev));

    char dev_name[256];
    CHECK_CU(cuDeviceGetName(dev_name, sizeof(dev_name), dev));
    int sm_major = 0, sm_minor = 0;
    CHECK_CU(cuDeviceGetAttribute(&sm_major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK_CU(cuDeviceGetAttribute(&sm_minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    fprintf(stderr, "Device: %s sm_%d%d\n", dev_name, sm_major, sm_minor);

    CUmodule mod; CUfunction fn;
    if (load_ptx_kernel(ptx_path, entry, &mod, &fn) != 0) return 1;

    int regs = 0, shmem = 0;
    cuFuncGetAttribute(&regs,  CU_FUNC_ATTRIBUTE_NUM_REGS, fn);
    cuFuncGetAttribute(&shmem, CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, fn);
    fprintf(stderr, "shape M=%d entry=%s regs/thd=%d shmem=%d B\n", M, entry, regs, shmem);

    const size_t ASZ = (size_t)M * (size_t)K;
    const size_t BSZ = (size_t)K * (size_t)N;
    const size_t CSZ = (size_t)M * (size_t)N;

    unsigned short *ha = (unsigned short *)malloc(ASZ * sizeof(unsigned short));
    unsigned short *hb = (unsigned short *)malloc(BSZ * sizeof(unsigned short));
    if (!ha || !hb) { fprintf(stderr, "host malloc failed\n"); return 1; }
    for (size_t i = 0; i < ASZ; ++i) ha[i] = f32_to_f16((float)((i % 8) - 4) * 0.0625f);
    for (size_t i = 0; i < BSZ; ++i) hb[i] = f32_to_f16((float)((i % 5) - 2) * 0.125f);

    CUdeviceptr da = 0, db = 0, dc = 0;
    CHECK_CU(cuMemAlloc(&da, ASZ * sizeof(unsigned short)));
    CHECK_CU(cuMemAlloc(&db, BSZ * sizeof(unsigned short)));
    CHECK_CU(cuMemAlloc(&dc, CSZ * sizeof(float)));
    CHECK_CU(cuMemcpyHtoD(da, ha, ASZ * sizeof(unsigned short)));
    CHECK_CU(cuMemcpyHtoD(db, hb, BSZ * sizeof(unsigned short)));
    CHECK_CU(cuMemsetD8(dc, 0, CSZ * sizeof(float)));

    const int K_PER_TILE = 16;
    int K_TILES_TOTAL = K / K_PER_TILE;
    unsigned long long k_arg = (unsigned long long)K_TILES_TOTAL;
    void *kargs[4] = { &da, &db, &dc, &k_arg };

    /* HILBERT launch: grid = p x p where p = next_pow2(side), side = M/64.
     * Kernel internally does d2xy + early-return for padding CTAs. */
    unsigned int side = (unsigned int)(M / 64);
    unsigned int p    = next_pow2_u(side);
    unsigned int gx = p;
    unsigned int gy = p;
    fprintf(stderr, "launch grid=(%u,%u,1) block=(128,1,1) side=%u p=%u K_TILES=%d (real=%u padding=%u)\n",
            gx, gy, side, p, K_TILES_TOTAL, side * side, p * p - side * side);

    /* warmup */
    for (int i = 0; i < warmup; ++i) {
        CHECK_CU(cuLaunchKernel(fn, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
    }
    CHECK_CU(cuCtxSynchronize());

    /* timed launches with cuEvent (for non-ncu sanity timing) */
    cudaEvent_t ev_a, ev_b;
    CHECK_RT(cudaEventCreate(&ev_a));
    CHECK_RT(cudaEventCreate(&ev_b));

    double sum_ms = 0.0, min_ms = 1e30, max_ms = 0.0;
    for (int i = 0; i < nreps; ++i) {
        CHECK_RT(cudaEventRecord(ev_a, 0));
        CHECK_CU(cuLaunchKernel(fn, gx, gy, 1, 128, 1, 1, 0, NULL, kargs, NULL));
        CHECK_RT(cudaEventRecord(ev_b, 0));
        CHECK_RT(cudaEventSynchronize(ev_b));
        float ms = 0.0f;
        CHECK_RT(cudaEventElapsedTime(&ms, ev_a, ev_b));
        sum_ms += (double)ms;
        if (ms < min_ms) min_ms = ms;
        if (ms > max_ms) max_ms = ms;
    }
    double mean_ms = sum_ms / nreps;
    double flops = 2.0 * (double)M * (double)N * (double)K;
    double tflops = flops / (mean_ms / 1000.0) / 1e12;
    fprintf(stderr, "M=%d nreps=%d mean=%.3fms min=%.3fms max=%.3fms TFLOPS=%.3f\n",
            M, nreps, mean_ms, min_ms, max_ms, tflops);

    cudaEventDestroy(ev_a);
    cudaEventDestroy(ev_b);
    cuMemFree(da); cuMemFree(db); cuMemFree(dc);
    free(ha); free(hb);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return 0;
}
