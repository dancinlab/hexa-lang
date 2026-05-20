#!/bin/bash
set +e
cd /tmp

echo "=== GPU.md Round 5 — telemetry + scale-up + JIT timing ==="
echo "host: $(hostname)  date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─── A. nvidia-smi telemetry snapshot ───────────────────────────────────
echo "=== §11 GPU power management + thermal awareness ==="
nvidia-smi --query-gpu=name,driver_version,clocks.gr,clocks.sm,clocks.mem,temperature.gpu,power.draw,memory.used,memory.total,utilization.gpu --format=csv 2>&1
echo ""

# ─── B. cuDeviceGetAttribute capability query ───────────────────────────
echo "=== §11 Driver capability query (cuDeviceGetAttribute) ==="
cat > /tmp/devcaps.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    char name[256]; cuDeviceGetName(name, 256, d);
    printf("device: %s\n", name);
    int v;
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, d); int major=v;
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, d); int minor=v;
    printf("compute_capability: %d.%d (sm_%d%d)\n", major, minor, major, minor);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, d);
    printf("multiprocessor_count: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK, d);
    printf("max_threads_per_block: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_BLOCK, d);
    printf("max_registers_per_block: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK, d);
    printf("max_shared_per_block: %d bytes\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_MULTIPROCESSOR, d);
    printf("max_shared_per_sm: %d bytes\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_MULTIPROCESSOR, d);
    printf("max_registers_per_sm: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_WARP_SIZE, d);
    printf("warp_size: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_CLOCK_RATE, d);
    printf("clock_khz: %d (%.2f GHz)\n", v, v/1e6);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MEMORY_CLOCK_RATE, d);
    printf("memory_clock_khz: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_GLOBAL_MEMORY_BUS_WIDTH, d);
    printf("memory_bus_width_bits: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_L2_CACHE_SIZE, d);
    printf("l2_cache_bytes: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_CONCURRENT_KERNELS, d);
    printf("concurrent_kernels: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_INTEGRATED, d);
    printf("integrated: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_TCC_DRIVER, d);
    printf("tcc_driver: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_UNIFIED_ADDRESSING, d);
    printf("unified_addressing: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_COMPUTE_PREEMPTION_SUPPORTED, d);
    printf("compute_preemption: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_COOPERATIVE_LAUNCH, d);
    printf("cooperative_launch_supported: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_ASYNC_ENGINE_COUNT, d);
    printf("async_engine_count: %d\n", v);
    return 0;
}
EOF
nvcc -O2 -o /tmp/devcaps /tmp/devcaps.c -lcuda 2>&1 | tail -1
/tmp/devcaps
echo ""

# ─── C. NVLink topology + MIG availability ──────────────────────────────
echo "=== §11 NVLink topology + MIG awareness ==="
echo "--- nvidia-smi topo -m ---"
nvidia-smi topo -m 2>&1 | head -10
echo "--- nvidia-smi mig -lgi (list GPU instances) ---"
nvidia-smi mig -lgi 2>&1 | head -10
echo ""

# ─── D. HGEMM 512 scale-up (correct k_tiles param, original host pattern) ─
echo "=== §5m HGEMM scale-up at M=N=K=512 (extends §10 row caveat) ==="
# Reuse existing 256x256 kernel — it actually computes a 64x64 output per block
# with k_tiles=K/16 K-iterations. Setting grid to N/64 × M/64 produces M×N output.
# For 512x512 with K=512, we need k_tiles=32 and grid=8x8.
cat > /tmp/hgemm512.c <<'EOF'
#include <cuda.h>
#include <cublas_v2.h>
#include <library_types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
static uint16_t f32_to_f16(float f) {
    uint32_t x; memcpy(&x,&f,4);
    uint32_t s=(x>>16)&0x8000; int32_t e=((x>>23)&0xff)-127+15; uint32_t m=x&0x007fffff;
    if (e<=0) return (uint16_t)s; if (e>=31) return (uint16_t)(s|0x7c00);
    return (uint16_t)(s|(e<<10)|(m>>13));
}
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    CUcontext c; cuCtxCreate(&c, 0, d);
    cublasHandle_t blas; cublasCreate(&blas);
    cublasSetMathMode(blas, CUBLAS_TENSOR_OP_MATH);
    FILE *fp = fopen("/tmp/composite_wmma_256x256.ptx", "r");
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule m; cuModuleLoadDataEx(&m, ptx, 0, NULL, NULL);
    CUfunction fn; cuModuleGetFunction(&fn, m, "wmma_256x256_grid");
    int shapes[] = {256, 384, 512, 768, 1024};
    for (int si = 0; si < 5; ++si) {
        int M = shapes[si], N = shapes[si], K = shapes[si];
        if (M % 64 != 0 || K % 16 != 0) { printf("M=%d skipped (not multiple of 64/16)\n", M); continue; }
        size_t bytes_ab = (size_t)M * K * 2;
        size_t bytes_c  = (size_t)M * N * 4;
        uint16_t *Ah = malloc(bytes_ab), *Bh = malloc(bytes_ab);
        srand(42);
        for (size_t i = 0; i < (size_t)M*K; ++i) Ah[i] = f32_to_f16(((float)rand()/RAND_MAX-0.5f)*0.5f);
        for (size_t i = 0; i < (size_t)K*N; ++i) Bh[i] = f32_to_f16(((float)rand()/RAND_MAX-0.5f)*0.5f);
        CUdeviceptr A, B, C, Cb;
        cuMemAlloc(&A, bytes_ab); cuMemAlloc(&B, bytes_ab);
        cuMemAlloc(&C, bytes_c); cuMemAlloc(&Cb, bytes_c);
        cuMemcpyHtoD(A, Ah, bytes_ab); cuMemcpyHtoD(B, Bh, bytes_ab);
        unsigned long long k_arg = (unsigned long long)(K / 16);
        void *args[] = {&A, &B, &C, &k_arg};
        float alpha=1.0f, beta=0.0f;
        int grid_x = N / 64, grid_y = M / 64;
        int reps = 200;
        // warmups
        for (int i = 0; i < 5; ++i) cuLaunchKernel(fn, grid_x, grid_y, 1, 512, 1, 1, 0, NULL, args, NULL);
        for (int i = 0; i < 5; ++i) cublasGemmEx(blas, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha, (void*)B, CUDA_R_16F, K, (void*)A, CUDA_R_16F, K,
            &beta, (void*)Cb, CUDA_R_32F, N, CUDA_R_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cuCtxSynchronize();
        CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
        cuEventRecord(t0, 0);
        for (int i = 0; i < reps; ++i) cuLaunchKernel(fn, grid_x, grid_y, 1, 512, 1, 1, 0, NULL, args, NULL);
        cuEventRecord(t1, 0); cuEventSynchronize(t1);
        float ms_h; cuEventElapsedTime(&ms_h, t0, t1);
        cuEventRecord(t0, 0);
        for (int i = 0; i < reps; ++i) cublasGemmEx(blas, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K,
            &alpha, (void*)B, CUDA_R_16F, K, (void*)A, CUDA_R_16F, K,
            &beta, (void*)Cb, CUDA_R_32F, N, CUDA_R_32F, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
        cuEventRecord(t1, 0); cuEventSynchronize(t1);
        float ms_b; cuEventElapsedTime(&ms_b, t0, t1);
        double hexa_tflops = 2.0*M*N*K*reps / (ms_h*1e-3) / 1e12;
        double blas_tflops = 2.0*M*N*K*reps / (ms_b*1e-3) / 1e12;
        printf("M=N=K=%d grid=%dx%d k_tiles=%llu: hexa_tflops=%.4f cublas_tflops=%.4f ratio=%.6f\n",
               M, grid_x, grid_y, k_arg, hexa_tflops, blas_tflops, hexa_tflops/blas_tflops);
        free(Ah); free(Bh);
        cuMemFree(A); cuMemFree(B); cuMemFree(C); cuMemFree(Cb);
    }
    return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/hgemm512 /tmp/hgemm512.c -lcuda -lcudart -lcublas 2>&1 | tail -2
/tmp/hgemm512
echo ""

# ─── E. JIT first-launch vs Nth-launch timing ──────────────────────────
echo "=== §11 JIT first-launch vs Nth-launch timing ==="
cat > /tmp/jit_first.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    CUcontext ctx; cuCtxCreate(&ctx, 0, d);
    FILE *fp = fopen("/tmp/empty_kernel.ptx", "r");
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule m; CUfunction fn;
    CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
    // Measure module load time (includes JIT)
    cuEventRecord(t0, 0);
    cuModuleLoadDataEx(&m, ptx, 0, NULL, NULL);
    cuModuleGetFunction(&fn, m, "empty_k");
    cuEventRecord(t1, 0); cuEventSynchronize(t1);
    float ms_load; cuEventElapsedTime(&ms_load, t0, t1);
    printf("module_load + getFunction (JIT): %.3f ms\n", ms_load);
    // Measure first kernel launch + sync
    cuEventRecord(t0, 0);
    cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, NULL, NULL, NULL);
    cuCtxSynchronize();
    cuEventRecord(t1, 0); cuEventSynchronize(t1);
    float ms_first; cuEventElapsedTime(&ms_first, t0, t1);
    printf("first launch + sync (warm JIT): %.3f ms (%.0f us)\n", ms_first, ms_first*1000);
    // Subsequent launch
    cuEventRecord(t0, 0);
    cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, NULL, NULL, NULL);
    cuCtxSynchronize();
    cuEventRecord(t1, 0); cuEventSynchronize(t1);
    float ms_second; cuEventElapsedTime(&ms_second, t0, t1);
    printf("second launch + sync: %.3f ms (%.0f us)\n", ms_second, ms_second*1000);
    return 0;
}
EOF
nvcc -O2 -o /tmp/jit_first /tmp/jit_first.c -lcuda 2>&1 | tail -1
/tmp/jit_first
echo ""

# ─── F. PTX-text determinism audit (no atomic ops in pure-arith kernels) ─
echo "=== §6a Determinism mode audit (atomic ops scan) ==="
for f in step1_wmma_16x16.ptx step2_wmma_multitile.ptx step3_wmma_64x64_grid.ptx step5_tf32_gemm.ptx f16_vadd.ptx bf16_vadd.ptx vec_add_unroll1.ptx hex_neighbor.ptx; do
  [ -f /tmp/$f ] || continue
  atomic_count=$(grep -cE "atom\.|atomic\." /tmp/$f)
  red_count=$(grep -cE "red\." /tmp/$f)
  echo "$f: atomic_ops=$atomic_count red_ops=$red_count $(if [ $atomic_count -eq 0 ] && [ $red_count -eq 0 ]; then echo 'DETERMINISTIC'; else echo 'NON-DETERMINISTIC (has atomics)'; fi)"
done
echo ""

# ─── G. ldmatrix.sync.aligned scan (sm_75+ feature) ────────────────────
echo "=== §11 ldmatrix.sync.aligned scan ==="
for f in step*.ptx composite_wmma_256x256.ptx; do
  [ -f /tmp/$f ] || continue
  count=$(grep -c "ldmatrix\.sync" /tmp/$f)
  echo "$f: ldmatrix.sync = $count"
done
echo ""

# ─── H. .shared / .local / .const memory hierarchy use ─────────────────
echo "=== §3c memory hierarchy usage scan ==="
for f in step*.ptx composite_wmma_256x256.ptx f16_vadd.ptx bf16_vadd.ptx hex_neighbor.ptx; do
  [ -f /tmp/$f ] || continue
  shared=$(grep -cE "\.shared|st\.shared|ld\.shared" /tmp/$f)
  local_use=$(grep -cE "\.local|st\.local|ld\.local" /tmp/$f)
  const=$(grep -cE "\.const\b|ld\.const" /tmp/$f)
  echo "$f: .shared=$shared .local=$local_use .const=$const"
done
echo ""

# ─── I. CUDA streams + events smoke ─────────────────────────────────────
echo "=== §11 CUDA streams + events smoke ==="
cat > /tmp/stream_smoke.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d,0); CUcontext ctx; cuCtxCreate(&ctx,0,d);
    FILE *fp = fopen("/tmp/empty_kernel.ptx","r");
    fseek(fp,0,SEEK_END); long sz=ftell(fp); fseek(fp,0,SEEK_SET);
    char *ptx=malloc(sz+1); size_t rd=fread(ptx,1,sz,fp); (void)rd; ptx[sz]=0; fclose(fp);
    CUmodule mod; cuModuleLoadDataEx(&mod,ptx,0,NULL,NULL);
    CUfunction fn; cuModuleGetFunction(&fn,mod,"empty_k");
    CUstream s1, s2; cuStreamCreate(&s1, CU_STREAM_DEFAULT); cuStreamCreate(&s2, CU_STREAM_DEFAULT);
    CUevent e0, e1; cuEventCreate(&e0, 0); cuEventCreate(&e1, 0);
    int reps = 1000;
    // warmup
    for (int i=0; i<100; ++i) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, s1, NULL, NULL);
    cuStreamSynchronize(s1);
    // single stream
    cuEventRecord(e0, s1);
    for (int i=0; i<reps; ++i) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, s1, NULL, NULL);
    cuEventRecord(e1, s1); cuEventSynchronize(e1);
    float ms_single; cuEventElapsedTime(&ms_single, e0, e1);
    // dual-stream concurrent
    cuEventRecord(e0, 0);
    for (int i=0; i<reps; ++i) {
        cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, s1, NULL, NULL);
        cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, s2, NULL, NULL);
    }
    cuStreamSynchronize(s1); cuStreamSynchronize(s2);
    cuEventRecord(e1, 0); cuEventSynchronize(e1);
    float ms_dual; cuEventElapsedTime(&ms_dual, e0, e1);
    printf("single-stream %d launches: %.3f ms (%.2f us/launch)\n", reps, ms_single, ms_single*1000.0/reps);
    printf("dual-stream %d×2 launches: %.3f ms (%.2f us/launch-pair)\n", reps, ms_dual, ms_dual*1000.0/reps);
    return 0;
}
EOF
nvcc -O2 -o /tmp/stream_smoke /tmp/stream_smoke.c -lcuda 2>&1 | tail -1
/tmp/stream_smoke
echo ""

echo "=== END Round 5 ==="
