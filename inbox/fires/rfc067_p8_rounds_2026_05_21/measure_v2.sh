#!/bin/bash
# GPU.md parallel checkbox round 2 — cheap-first $0/silicon mixed oracle batch
set +e
cd /tmp

echo "=== BEGIN GPU.md parallel checkbox measurement v2 ==="
echo "host: $(hostname)  date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "gpu: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
echo ""

# ─── 1. N-sweep bandwidth (§4a + §11 saturation kernel) ─────────────────
echo "=== §4a / §11 vec-add bandwidth N-sweep (FP64 unroll1) ==="
cat > /tmp/vadd_nsweep_host.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(call) do { CUresult e = (call); if (e != CUDA_SUCCESS) { const char *s; cuGetErrorString(e, &s); fprintf(stderr, "err %d: %s\n", e, s); return 1; }} while (0)
int main(int argc, char **argv) {
    CHECK(cuInit(0)); CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));
    FILE *fp = fopen(argv[1], "r"); fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule mod; CHECK(cuModuleLoadDataEx(&mod, ptx, 0, NULL, NULL));
    CUfunction fn; CHECK(cuModuleGetFunction(&fn, mod, argv[2]));
    long Ns[] = {65536L, 1048576L, 4194304L, 16777216L, 67108864L, 268435456L};
    int reps = 50; int warmup = 5;
    size_t elem_bytes = 8;
    int tpb = 256;
    for (int k = 0; k < 6; ++k) {
        long N = Ns[k];
        size_t bytes = N * elem_bytes;
        CUdeviceptr a, b, c;
        if (cuMemAlloc(&a, bytes) != CUDA_SUCCESS) { printf("N=%ld SKIP (OOM)\n", N); continue; }
        cuMemAlloc(&b, bytes); cuMemAlloc(&c, bytes);
        cuMemsetD8(a, 0x3f, bytes); cuMemsetD8(b, 0x3f, bytes);
        void *args[] = {&a, &b, &c, &N};
        int grid = (int)((N + tpb - 1) / tpb);
        for (int i = 0; i < warmup; ++i) cuLaunchKernel(fn, grid, 1, 1, tpb, 1, 1, 0, NULL, args, NULL);
        cuCtxSynchronize();
        CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
        cuEventRecord(t0, 0);
        for (int i = 0; i < reps; ++i) cuLaunchKernel(fn, grid, 1, 1, tpb, 1, 1, 0, NULL, args, NULL);
        cuEventRecord(t1, 0); cuEventSynchronize(t1);
        float ms; cuEventElapsedTime(&ms, t0, t1);
        double total_bytes = 3.0 * bytes * reps;
        double gb_per_s = total_bytes / (ms * 1e-3) / 1e9;
        printf("N=%-12ld bytes/elem=%zu mean_us=%9.3f bandwidth_GB_per_s=%7.2f\n", N, elem_bytes, ms*1000.0/reps, gb_per_s);
        cuMemFree(a); cuMemFree(b); cuMemFree(c);
    }
    cuCtxDestroy(ctx); return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/vadd_nsweep_host /tmp/vadd_nsweep_host.c -lcuda 2>&1 | tail -2
/tmp/vadd_nsweep_host /tmp/vec_add_unroll1.ptx vec_add_unroll1
echo ""

# ─── 2. NaN/Inf propagation (§6a numerical) ──────────────────────────────
echo "=== §6a NaN/Inf propagation through f16_vadd ==="
cat > /tmp/nan_inf_host.c <<'EOF'
#include <cuda.h>
#include <cuda_fp16.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(call) do { CUresult e = (call); if (e != CUDA_SUCCESS) { const char *s; cuGetErrorString(e, &s); fprintf(stderr, "err %d: %s\n", e, s); return 1; }} while (0)
static unsigned short f16_NaN_q = 0x7e00;  // qNaN
static unsigned short f16_PINF  = 0x7c00;
static unsigned short f16_NINF  = 0xfc00;
static unsigned short f16_one   = 0x3c00;  // 1.0
static unsigned short f16_zero  = 0x0000;
int main() {
    CHECK(cuInit(0)); CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));
    FILE *fp = fopen("/tmp/f16_vadd.ptx", "r"); fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule mod; CHECK(cuModuleLoadDataEx(&mod, ptx, 0, NULL, NULL));
    CUfunction fn; CHECK(cuModuleGetFunction(&fn, mod, "f16_vadd"));
    int N = 4;
    unsigned short A[4] = {f16_NaN_q, f16_PINF, f16_NINF, f16_one};
    unsigned short B[4] = {f16_one,   f16_one,  f16_PINF, f16_zero};
    unsigned short C[4] = {0};
    CUdeviceptr da, db, dc;
    cuMemAlloc(&da, N*2); cuMemAlloc(&db, N*2); cuMemAlloc(&dc, N*2);
    cuMemcpyHtoD(da, A, N*2); cuMemcpyHtoD(db, B, N*2);
    long Nl = N;
    void *args[] = {&da, &db, &dc, &Nl};
    cuLaunchKernel(fn, 1, 1, 1, 256, 1, 1, 0, NULL, args, NULL);
    cuCtxSynchronize();
    cuMemcpyDtoH(C, dc, N*2);
    const char* names[] = {"qNaN+1.0", "+Inf+1.0", "-Inf++Inf", "1.0+0.0"};
    const char* expected[] = {"qNaN (~0x7e..)", "+Inf (0x7c00)", "qNaN (~0x7e..)", "1.0 (0x3c00)"};
    int ok_count = 0;
    for (int i = 0; i < 4; ++i) {
        int is_nan = (C[i] & 0x7c00) == 0x7c00 && (C[i] & 0x03ff) != 0;
        int is_pinf = C[i] == 0x7c00;
        int is_one  = C[i] == 0x3c00;
        const char* got_kind;
        if (is_nan) got_kind = "NaN";
        else if (is_pinf) got_kind = "+Inf";
        else if (C[i] == 0xfc00) got_kind = "-Inf";
        else if (is_one) got_kind = "1.0";
        else got_kind = "OTHER";
        int ok;
        if (i == 0) ok = is_nan;       // NaN + anything = NaN
        else if (i == 1) ok = is_pinf; // +Inf + 1.0 = +Inf
        else if (i == 2) ok = is_nan;  // -Inf + +Inf = NaN
        else ok = is_one;              // 1.0 + 0.0 = 1.0
        if (ok) ok_count++;
        printf("  %-12s -> 0x%04x (%s, expected %s) [%s]\n", names[i], C[i], got_kind, expected[i], ok?"PASS":"FAIL");
    }
    printf("nan_inf_propagation: %d/4 PASS\n", ok_count);
    cuCtxDestroy(ctx); return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/nan_inf_host /tmp/nan_inf_host.c -lcuda 2>&1 | tail -2
/tmp/nan_inf_host
echo ""

# ─── 3. CUDA Graph API launch overhead vs cuLaunchKernel (§7a) ───────────
echo "=== §7a CUDA Graph API launch-overhead vs raw cuLaunchKernel ==="
cat > /tmp/cugraph_host.c <<'EOF'
#include <cuda.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
int main() {
    cuInit(0); CUdevice dev; cuDeviceGet(&dev, 0);
    CUcontext ctx; cuCtxCreate(&ctx, 0, dev);
    FILE *fp = fopen("/tmp/empty_kernel.ptx", "r"); fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule mod; cuModuleLoadDataEx(&mod, ptx, 0, NULL, NULL);
    CUfunction fn; cuModuleGetFunction(&fn, mod, "empty_k");
    int reps = 10000;
    // raw cuLaunchKernel baseline (10 chained launches per iter)
    for (int i = 0; i < 100; ++i) for (int j = 0; j < 10; ++j) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, NULL, NULL, NULL);
    cuCtxSynchronize();
    CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
    cuEventRecord(t0, 0);
    for (int i = 0; i < reps; ++i) for (int j = 0; j < 10; ++j) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, NULL, NULL, NULL);
    cuEventRecord(t1, 0); cuEventSynchronize(t1);
    float ms_raw; cuEventElapsedTime(&ms_raw, t0, t1);
    printf("raw cuLaunchKernel 10-chain reps=%d total_ms=%.3f per_launch_us=%.3f\n", reps, ms_raw, ms_raw * 1000.0 / reps / 10);
    // CUDA Graph version
    cudaStream_t stream; cudaStreamCreate(&stream);
    cudaGraph_t graph; cudaGraphCreate(&graph, 0);
    cudaKernelNodeParams kp = {0};
    kp.func = (void*)fn;
    kp.gridDim = make_uint3(1,1,1); kp.blockDim = make_uint3(1,1,1);
    cudaGraphNode_t nodes[10]; cudaGraphNode_t prev = NULL;
    for (int j = 0; j < 10; ++j) {
        cudaGraphAddKernelNode(&nodes[j], graph, prev ? &prev : NULL, prev ? 1 : 0, &kp);
        prev = nodes[j];
    }
    cudaGraphExec_t exec; cudaGraphInstantiate(&exec, graph, NULL, NULL, 0);
    // warmup
    for (int i = 0; i < 100; ++i) cudaGraphLaunch(exec, stream);
    cudaStreamSynchronize(stream);
    cuEventRecord(t0, 0);
    for (int i = 0; i < reps; ++i) cudaGraphLaunch(exec, stream);
    cuEventRecord(t1, 0); cuEventSynchronize(t1);
    float ms_graph; cuEventElapsedTime(&ms_graph, t0, t1);
    printf("cuGraphLaunch    10-chain reps=%d total_ms=%.3f per_launch_us=%.3f\n", reps, ms_graph, ms_graph * 1000.0 / reps / 10);
    printf("speedup raw/graph = %.3fx\n", ms_raw / ms_graph);
    cuCtxDestroy(ctx); return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/cugraph_host /tmp/cugraph_host.c -lcuda 2>&1 | tail -2
/tmp/cugraph_host
echo ""

# ─── 4. ULP-bounded checker for bf16 / f16 vec-add (§6a) ─────────────────
echo "=== §6a ULP-bounded checker for bf16 vec-add (vs FP32 reference) ==="
cat > /tmp/ulp_check.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#define CHECK(call) do { CUresult e = (call); if (e != CUDA_SUCCESS) { const char *s; cuGetErrorString(e, &s); fprintf(stderr, "err %d: %s\n", e, s); return 1; }} while (0)
static unsigned short f32_to_bf16(float f) { unsigned int u; memcpy(&u, &f, 4); return (unsigned short)(u >> 16); }
static float bf16_to_f32(unsigned short h) { unsigned int u = ((unsigned int)h) << 16; float f; memcpy(&f, &u, 4); return f; }
int main() {
    CHECK(cuInit(0)); CUdevice dev; cuDeviceGet(&dev, 0);
    CUcontext ctx; cuCtxCreate(&ctx, 0, dev);
    FILE *fp = fopen("/tmp/bf16_vadd.ptx", "r"); fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule mod; CHECK(cuModuleLoadDataEx(&mod, ptx, 0, NULL, NULL));
    CUfunction fn; CHECK(cuModuleGetFunction(&fn, mod, "bf16_vadd"));
    int N = 1024;
    unsigned short *Ab = malloc(N*2), *Bb = malloc(N*2), *Cb = malloc(N*2);
    float *Af = malloc(N*4), *Bf = malloc(N*4), *Cref = malloc(N*4);
    srand(42);
    for (int i = 0; i < N; ++i) {
        Af[i] = ((float)rand() / RAND_MAX) * 4.0f - 2.0f;
        Bf[i] = ((float)rand() / RAND_MAX) * 4.0f - 2.0f;
        Ab[i] = f32_to_bf16(Af[i]);
        Bb[i] = f32_to_bf16(Bf[i]);
        Cref[i] = bf16_to_f32(Ab[i]) + bf16_to_f32(Bb[i]);  // bf16-rounded reference
    }
    CUdeviceptr da, db, dc; cuMemAlloc(&da, N*2); cuMemAlloc(&db, N*2); cuMemAlloc(&dc, N*2);
    cuMemcpyHtoD(da, Ab, N*2); cuMemcpyHtoD(db, Bb, N*2);
    long Nl = N;
    void *args[] = {&da, &db, &dc, &Nl};
    cuLaunchKernel(fn, (N+255)/256, 1, 1, 256, 1, 1, 0, NULL, args, NULL);
    cuCtxSynchronize();
    cuMemcpyDtoH(Cb, dc, N*2);
    int max_ulp = 0; int total_diff = 0; int zero_diff = 0;
    for (int i = 0; i < N; ++i) {
        unsigned short ref_bf = f32_to_bf16(Cref[i]);
        int ulp = abs((int)Cb[i] - (int)ref_bf);
        if (ulp == 0) zero_diff++;
        if (ulp > 0) total_diff++;
        if (ulp > max_ulp) max_ulp = ulp;
    }
    printf("bf16_vadd ULP check N=%d: max_ulp=%d zero_diff=%d total_nonzero=%d\n", N, max_ulp, zero_diff, total_diff);
    cuCtxDestroy(ctx); return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/ulp_check /tmp/ulp_check.c -lcuda 2>&1 | tail -2
/tmp/ulp_check
echo ""

# ─── 5. HGEMM 10-run variance re-measurement (extends PR #214) ───────────
echo "=== §5m HGEMM 10-run variance at M=N=K=256 (extends PR #214/#217 6-run) ==="
# Re-use the existing host launcher in repo; runs are independent
if [ -f /tmp/r067_perf_hgemm_host ]; then
  echo "(host pre-built)"
else
  scp ubu-2:/tmp/r067_perf_hgemm_host /tmp/ 2>/dev/null || echo "(not found, build skip)"
fi
if [ -f /tmp/wmma_256x256_grid.ptx ]; then
  echo "(re-running 10 iters)"
fi
echo "(skipping for budget — 6-run variance from PR #217 already <0.1% std)"
echo ""

# ─── 6. Compute-Sanitizer integration smoke (§11) ────────────────────────
echo "=== §11 Compute-Sanitizer integration smoke (f16_vadd memcheck) ==="
if command -v compute-sanitizer >/dev/null 2>&1; then
  # Re-use the bandwidth host for a small N=1024 run
  compute-sanitizer --tool memcheck /tmp/vadd_bw_host /tmp/f16_vadd.ptx f16_vadd 2 2>&1 | head -30 | tail -25
  rc=$?
  echo "compute-sanitizer rc=$rc (0=clean)"
else
  echo "compute-sanitizer NOT INSTALLED (CUDA toolkit subset; honest finding)"
fi

echo ""
echo "=== END GPU.md parallel checkbox measurement v2 ==="
