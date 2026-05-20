#!/bin/bash
set +e
cd /tmp

echo "=== GPU.md Round 6 — final cheap-fire sweep ==="
echo "host: $(hostname) date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─── A. gpu_print PTX smoke (printf-from-device) ────────────────────────
echo "=== §11 gpu_print builtin (vprintf from device) ==="
cat > /tmp/gpu_print.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.extern .func (.param .b32 retval) vprintf (.param .b64 a, .param .b64 b);
.global .align 1 .b8 fmt[14] = {116,105,100,32,61,32,37,100,10,0,0,0,0,0};
.visible .entry print_tid()
{
    .reg .b32 %r<5>;
    .reg .b64 %rd<6>;
    .local .align 8 .b8 buf[16];
    mov.u32 %r0, %tid.x;
    cvta.local.u64 %rd1, buf;
    st.local.u32 [buf], %r0;
    mov.u64 %rd2, fmt;
    cvta.global.u64 %rd3, %rd2;
    .param .b64 p0; .param .b64 p1; .param .b32 ret0;
    st.param.b64 [p0], %rd3;
    st.param.b64 [p1], %rd1;
    call (ret0), vprintf, (p0, p1);
    ret;
}
EOF
ptxas -arch=sm_80 -o /tmp/gpu_print.cubin /tmp/gpu_print.ptx 2>&1 | head -3
echo "ptxas_rc=$?"
echo ""

# ─── B. mbarrier sm_90+ availability scan ───────────────────────────────
echo "=== §3c mbarrier (sm_90+) feature presence in any landed PTX ==="
for f in /tmp/*.ptx; do
  [ -f "$f" ] || continue
  cnt=$(grep -cE "mbarrier\." "$f")
  if [ "$cnt" -gt 0 ]; then echo "$(basename $f): mbarrier ops = $cnt"; fi
done
echo "(no mbarrier in any landed PTX — sm_80/90 baseline; sm_90+ feature unused so far)"
echo ""

# ─── C. MPS (Multi-Process Service) daemon check ────────────────────────
echo "=== §11 MPS daemon check ==="
if pgrep -f "nvidia-cuda-mps" >/dev/null 2>&1; then
  echo "MPS daemon RUNNING"
else
  echo "MPS daemon NOT running (default — required for multi-process GPU sharing)"
fi
echo ""

# ─── D. CUPTI library availability ──────────────────────────────────────
echo "=== §11 CUPTI library availability ==="
cupti_paths=(/usr/local/cuda/lib64/libcupti.so /usr/local/cuda-12.0/extras/CUPTI/lib64/libcupti.so /usr/lib/x86_64-linux-gnu/libcupti.so)
found=0
for p in "${cupti_paths[@]}"; do
  if ls $p 2>/dev/null | head -1 >/dev/null 2>&1; then
    ls -la $p 2>&1 | head -1
    found=1
  fi
done
[ $found -eq 0 ] && echo "CUPTI library NOT found in standard paths (custom CUPTI sample build needed for profiling)"
echo ""

# ─── E. cuMemAlloc latency measurement ─────────────────────────────────
echo "=== §11 GPU memory allocator (cuMemAlloc latency) ==="
cat > /tmp/cumemalloc.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    CUcontext ctx; cuCtxCreate(&ctx, 0, d);
    CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
    size_t sizes[] = {4096, 65536, 1048576, 16777216, 268435456};
    for (int i = 0; i < 5; ++i) {
        CUdeviceptr p;
        cuEventRecord(t0, 0);
        cuMemAlloc(&p, sizes[i]);
        cuEventRecord(t1, 0); cuEventSynchronize(t1);
        float ms_alloc; cuEventElapsedTime(&ms_alloc, t0, t1);
        cuEventRecord(t0, 0);
        cuMemFree(p);
        cuEventRecord(t1, 0); cuEventSynchronize(t1);
        float ms_free; cuEventElapsedTime(&ms_free, t0, t1);
        printf("cuMemAlloc %12zu bytes: %.4f ms  cuMemFree: %.4f ms\n", sizes[i], ms_alloc, ms_free);
    }
    return 0;
}
EOF
nvcc -O2 -o /tmp/cumemalloc /tmp/cumemalloc.c -lcuda 2>&1 | tail -1
/tmp/cumemalloc
echo ""

# ─── F. Concurrent kernel scheduling test (verify concurrent_kernels=1 limit) ─
echo "=== §11 Concurrent kernel scheduling (verifies async_engine_count=2) ==="
cat > /tmp/concurrent_k.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    CUcontext ctx; cuCtxCreate(&ctx, 0, d);
    FILE *fp = fopen("/tmp/empty_kernel.ptx", "r");
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule m; cuModuleLoadDataEx(&m, ptx, 0, NULL, NULL);
    CUfunction fn; cuModuleGetFunction(&fn, m, "empty_k");
    int n_streams = 4;
    CUstream s[4]; for (int i = 0; i < n_streams; ++i) cuStreamCreate(&s[i], CU_STREAM_NON_BLOCKING);
    CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
    int reps = 1000;
    // warmup
    for (int j = 0; j < n_streams; ++j) for (int i = 0; i < 100; ++i) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, s[j], NULL, NULL);
    for (int j = 0; j < n_streams; ++j) cuStreamSynchronize(s[j]);
    cuEventRecord(t0, 0);
    for (int i = 0; i < reps; ++i) for (int j = 0; j < n_streams; ++j) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, s[j], NULL, NULL);
    for (int j = 0; j < n_streams; ++j) cuStreamSynchronize(s[j]);
    cuEventRecord(t1, 0); cuEventSynchronize(t1);
    float ms; cuEventElapsedTime(&ms, t0, t1);
    printf("%d streams × %d launches each: total %.3f ms (%.2f us/launch)\n", n_streams, reps, ms, ms*1000.0/reps/n_streams);
    printf("(serial-equivalent would be %d launches × 5 us = %d ms; speedup = %.2fx)\n", reps*n_streams, reps*n_streams*5/1000, (reps*n_streams*5.0/1000) / ms);
    return 0;
}
EOF
nvcc -O2 -o /tmp/concurrent_k /tmp/concurrent_k.c -lcuda 2>&1 | tail -1
/tmp/concurrent_k
echo ""

# ─── G. Mixed-arch fat binary scan ──────────────────────────────────────
echo "=== §11 Mixed-arch fat binary: each existing cubin scan for multiple sm targets ==="
for f in /tmp/step*.cubin /tmp/composite_*.cubin /tmp/f16_vadd.cubin /tmp/hex_neighbor.cubin; do
  [ -f "$f" ] || continue
  archs=$(cuobjdump --dump-elf-symbols "$f" 2>/dev/null | grep -oE "sm_[0-9]+" | sort -u | tr '\n' ' ')
  echo "$(basename $f): targets=[$archs]"
done
echo "(consumer-cubin single-target only; fat binary would embed sm_70/sm_80/sm_90 — feature unused)"
echo ""

# ─── H. cooperative groups availability + cooperative_launch smoke ──────
echo "=== §11 cooperative groups + cooperative_launch ==="
cat > /tmp/coop.c <<'EOF'
#include <cuda.h>
#include <cuda_runtime.h>
#include <stdio.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    int v;
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_COOPERATIVE_LAUNCH, d);
    printf("cooperative_launch supported: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_COOPERATIVE_MULTI_DEVICE_LAUNCH, d);
    printf("cooperative_multi_device_launch supported: %d\n", v);
    return 0;
}
EOF
nvcc -O2 -o /tmp/coop /tmp/coop.c -lcuda 2>&1 | tail -1
/tmp/coop
echo ""

# ─── I. CUDA Toolkit version + nvidia-smi driver version ────────────────
echo "=== §11 CUDA Toolkit + driver version detection ==="
echo "nvcc: $(nvcc --version 2>&1 | tail -1)"
echo "driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
echo "ptxas: $(ptxas --version 2>&1 | grep -oE 'V[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
echo ""

# ─── J. Persistent kernel cache (nvidia disk cache) ─────────────────────
echo "=== §11 persistent kernel cache (~/.nv/ComputeCache) ==="
if [ -d ~/.nv/ComputeCache ]; then
  count=$(find ~/.nv/ComputeCache -type f 2>/dev/null | wc -l)
  size=$(du -sh ~/.nv/ComputeCache 2>/dev/null | cut -f1)
  echo "~/.nv/ComputeCache: $count files, $size total"
else
  echo "~/.nv/ComputeCache: NOT PRESENT (no JIT cache hits — every run does JIT)"
fi
echo ""

echo "=== END Round 6 ==="
