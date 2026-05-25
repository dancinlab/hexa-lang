/* F-FUSION-ATTN-WMMA-WALL -- driver-JIT sm_120 LOAD probe (NOT a timed run).
 *
 * Loads flash_attn_wmma.ptx through the CUDA driver API on the actual GPU
 * (RTX 5070 sm_120) via cuModuleLoadDataEx + CU_JIT_TARGET_FROM_CUCONTEXT.
 * This JIT-compiles the PTX for the live device's sm_120 target and resolves
 * the entry function -- proving the PTX is driver-JIT-clean on sm_120, which
 * ptxas 12.0 cannot target directly (it tops out at sm_90). NO kernel launch,
 * NO timing -- the timed wall is round-3 (run serially to avoid contention).
 *
 * Build:  nvcc -O2 -o jit_load_probe jit_load_probe.c -lcuda
 * Run:    ./jit_load_probe flash_attn_wmma.ptx
 * rc=0 + "JIT-LOAD sm_120 OK" on success.
 */
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>

#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s = NULL; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA error %d at %s:%d: %s\n", e, __FILE__, __LINE__, s ? s : "?"); \
        return 1; }} while (0)

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s flash_attn_wmma.ptx\n", argv[0]); return 2; }
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) { perror("ptx open"); return 1; }
    fseek(fp, 0, SEEK_END); long n = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = (char *)malloc(n + 1);
    if (fread(ptx, 1, n, fp) != (size_t)n) { perror("ptx read"); return 1; }
    ptx[n] = 0; fclose(fp);

    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    int maj = 0, min = 0;
    CHECK(cuDeviceGetAttribute(&maj, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
    CHECK(cuDeviceGetAttribute(&min, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
    char name[256]; CHECK(cuDeviceGetName(name, sizeof name, dev));
    printf("device: %s  sm_%d%d\n", name, maj, min);

    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));

    /* JIT-compile PTX for the live device target (sm_120). */
    CUmodule mod;
    CUjit_option jit_opts[1] = { CU_JIT_TARGET_FROM_CUCONTEXT };
    void *jit_vals[1] = { (void *)0 };
    CHECK(cuModuleLoadDataEx(&mod, ptx, 1, jit_opts, jit_vals));

    CUfunction f; CHECK(cuModuleGetFunction(&f, mod, "flash_attn_wmma"));

    /* Query the JIT-resolved static resource usage for the live target. */
    int nregs = 0, smem = 0;
    CHECK(cuFuncGetAttribute(&nregs, CU_FUNC_ATTRIBUTE_NUM_REGS, f));
    CHECK(cuFuncGetAttribute(&smem,  CU_FUNC_ATTRIBUTE_SHARED_SIZE_BYTES, f));
    printf("entry flash_attn_wmma resolved: %d regs, %d bytes static smem\n", nregs, smem);

    printf("JIT-LOAD sm_%d%d OK rc=0\n", maj, min);
    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    free(ptx);
    return 0;
}
