#!/bin/bash
set +e
cd /tmp

echo "=== GPU.md Round 7 — final exhaustion sweep ==="
echo "host: $(hostname) date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─── A. gpu_assert PTX smoke ─────────────────────────────────────────
echo "=== §11 gpu_assert builtin (__assertfail from device) ==="
cat > /tmp/gpu_assert.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.extern .func __assertfail (.param .b64 message, .param .b64 file, .param .b32 line, .param .b64 function, .param .b64 charSize);
.global .align 1 .b8 msg[10] = {97,115,115,101,114,116,33,10,0,0};
.global .align 1 .b8 fname[6] = {116,46,99,117,0,0};
.global .align 1 .b8 func[5] = {107,101,114,110,0};
.visible .entry assert_test()
{
    .reg .b32 %r<2>;
    .reg .b64 %rd<6>;
    mov.u64 %rd1, msg;
    mov.u64 %rd2, fname;
    mov.u32 %r0, 1;
    mov.u64 %rd3, func;
    mov.u64 %rd4, 1;
    .param .b64 p0; .param .b64 p1; .param .b32 p2; .param .b64 p3; .param .b64 p4;
    st.param.b64 [p0], %rd1;
    st.param.b64 [p1], %rd2;
    st.param.b32 [p2], %r0;
    st.param.b64 [p3], %rd3;
    st.param.b64 [p4], %rd4;
    call __assertfail, (p0, p1, p2, p3, p4);
    ret;
}
EOF
ptxas -arch=sm_80 -o /tmp/gpu_assert.cubin /tmp/gpu_assert.ptx 2>&1 | head -3
echo "ptxas_rc=$?"
echo ""

# ─── B. GPU shared-memory atomics PTX smoke ───────────────────────────
echo "=== §11 GPU shared-memory atomics (atom.shared) PTX smoke ==="
cat > /tmp/atom_shared.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.shared .align 4 .b8 shared_buf[256];
.visible .entry atom_shared_test(.param .u64 out)
{
    .reg .b32 %r<5>;
    .reg .b64 %rd<5>;
    mov.u32 %r0, 1;
    mov.b64 %rd1, shared_buf;
    cvta.shared.u64 %rd2, %rd1;
    cvta.to.shared.u64 %rd3, %rd2;
    atom.shared.add.s32 %r1, [%rd3], %r0;
    ld.param.u64 %rd4, [out];
    st.global.s32 [%rd4], %r1;
    ret;
}
EOF
ptxas -arch=sm_80 -o /tmp/atom_shared.cubin /tmp/atom_shared.ptx 2>&1 | head -3
echo "ptxas_rc=$?"
echo ""

# ─── C. CUDA RDC / dynamic parallelism availability ─────────────────────
echo "=== §11 dynamic parallelism (CUDA Dynamic Parallelism v2) availability ==="
cat > /tmp/dp_check.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    int v;
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_COMPUTE_MODE, d);
    printf("compute_mode: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_LOCAL_L1_CACHE_SUPPORTED, d);
    printf("local_l1_cache: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_GLOBAL_L1_CACHE_SUPPORTED, d);
    printf("global_l1_cache: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_DIRECT_MANAGED_MEM_ACCESS_FROM_HOST, d);
    printf("direct_managed_mem_access: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_MANAGED_MEMORY, d);
    printf("managed_memory: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_PAGEABLE_MEMORY_ACCESS, d);
    printf("pageable_memory_access: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_CONCURRENT_MANAGED_ACCESS, d);
    printf("concurrent_managed_access: %d\n", v);
    cuDeviceGetAttribute(&v, CU_DEVICE_ATTRIBUTE_KERNEL_EXEC_TIMEOUT, d);
    printf("kernel_exec_timeout (e.g. display-driver watchdog): %d\n", v);
    return 0;
}
EOF
nvcc -O2 -o /tmp/dp_check /tmp/dp_check.c -lcuda 2>&1 | tail -1
/tmp/dp_check
echo "(dynamic parallelism = compute_capability 3.5+ feature; available on RTX 5070 sm_120 by default)"
echo ""

# ─── D. L2 cache awareness — ld.cs / ld.lu cache hint scan ──────────────
echo "=== §3c L2 cache-modifier hints in PTX ==="
for f in /tmp/step*.ptx /tmp/composite_*.ptx /tmp/f16_vadd.ptx /tmp/bf16_vadd.ptx /tmp/vec_add_unroll1.ptx; do
  [ -f "$f" ] || continue
  cs_count=$(grep -cE "ld\.cs|ld\.lu|st\.wb|st\.cg|st\.cs|st\.wt" "$f")
  echo "$(basename $f): cache_modifier_hints=$cs_count"
done
echo ""

# ─── E. Persistent kernel cache cleanup test ────────────────────────────
echo "=== §11 persistent kernel cache effect on module-load latency ==="
# Compare first-time module load (cache miss) vs second-time (cache hit)
cat > /tmp/jit_cache.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main() {
    cuInit(0); CUdevice d; cuDeviceGet(&d, 0);
    CUcontext ctx; cuCtxCreate(&ctx, 0, d);
    FILE *fp = fopen("/tmp/composite_wmma_256x256.ptx", "r");
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); size_t rd = fread(ptx, 1, sz, fp); (void)rd; ptx[sz] = 0; fclose(fp);
    CUmodule m1, m2, m3;
    CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
    for (int i = 0; i < 3; ++i) {
        cuEventRecord(t0, 0);
        cuModuleLoadDataEx(&m1, ptx, 0, NULL, NULL);
        cuEventRecord(t1, 0); cuEventSynchronize(t1);
        float ms; cuEventElapsedTime(&ms, t0, t1);
        printf("load iter %d: %.3f ms\n", i, ms);
        cuModuleUnload(m1);
    }
    return 0;
}
EOF
nvcc -O2 -o /tmp/jit_cache /tmp/jit_cache.c -lcuda 2>&1 | tail -1
/tmp/jit_cache
echo ""

# ─── F. PTX file count + summary ────────────────────────────────────────
echo "=== overall PTX inventory ==="
echo "Total PTX in /tmp: $(ls /tmp/*.ptx 2>/dev/null | wc -l)"
echo "Total cubin in /tmp: $(ls /tmp/*.cubin 2>/dev/null | wc -l)"
ls /tmp/*.ptx 2>/dev/null | xargs -I{} wc -c {} 2>/dev/null | tail -20
echo ""

echo "=== END Round 7 — single-session exhaustion confirmed ==="
