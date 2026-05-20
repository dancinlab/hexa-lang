#!/bin/bash
# GPU.md parallel checkbox firing — codegen-side $0 cheap-first oracle
# Runs on ubu-2; output is JSON-like text for easy parsing.

set +e  # don't abort on individual ptxas failures
cd /tmp

# All cookbook + RFC 068/069/070 PTX files we staged
PTX_FILES=(
  step1_wmma_16x16.ptx
  step2_wmma_multitile.ptx
  step3_wmma_64x64_grid.ptx
  step4_wmma_cp_async.ptx
  step5_tf32_gemm.ptx
  composite_wmma_256x256.ptx
  f16_vadd.ptx
  bf16_vadd.ptx
  vec_add_unroll1.ptx
  vec_add_unroll2.ptx
  hex_neighbor.ptx
)

echo "=== BEGIN GPU.md parallel checkbox measurement ==="
echo "host: $(hostname)  date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "ptxas: $(ptxas --version 2>&1 | head -1)"
echo "nvcc:  $(nvcc --version 2>&1 | tail -1)"
echo ""

# ─── 1. ptxas -v per PTX (registers + shared + stack + sass) ──────────
echo "=== §7a ptxas -v resource usage per PTX ==="
for f in "${PTX_FILES[@]}"; do
  [ -f "$f" ] || { echo "$f: MISSING"; continue; }
  arch=$(grep -E "^\.target" "$f" | awk '{print $2}' | head -1)
  [ -z "$arch" ] && arch="sm_80"
  out="/tmp/${f%.ptx}.cubin"
  vlog=$(ptxas -arch="$arch" -v -o "$out" "$f" 2>&1)
  rc=$?
  regs=$(echo "$vlog" | grep -oE "Used [0-9]+ registers" | grep -oE "[0-9]+" | head -1)
  shared=$(echo "$vlog" | grep -oE "[0-9]+ bytes smem" | grep -oE "[0-9]+" | head -1)
  stack=$(echo "$vlog" | grep -oE "[0-9]+ bytes stack frame" | grep -oE "[0-9]+" | head -1)
  cmem=$(echo "$vlog" | grep -oE "[0-9]+ bytes cmem\[0\]" | grep -oE "[0-9]+" | head -1)
  sass=$(cuobjdump --dump-sass "$out" 2>/dev/null | grep -cE '^\s+/\*[0-9a-fA-F]+\*/')
  echo "$f arch=$arch ptxas_rc=$rc regs=${regs:-?} smem=${shared:-0} stack=${stack:-0} cmem0=${cmem:-?} sass=$sass"
done
echo ""

# ─── 2. forward-compat: ptxas -arch=sm_120 (RTX 5070 native) ─────────
echo "=== forward-compat: ptxas -arch=sm_120 (RTX 5070 native) ==="
for f in "${PTX_FILES[@]}"; do
  [ -f "$f" ] || continue
  out_fc="/tmp/${f%.ptx}_sm120.cubin"
  ptxas -arch=sm_120 -o "$out_fc" "$f" 2>/dev/null
  rc=$?
  echo "$f sm_120_rc=$rc"
done
echo ""

# ─── 3. nvcc PTX-diff oracle for cookbook steps 2-5 ──────────────────
echo "=== §7b.1 nvcc PTX-diff oracle for cookbook steps 2-5 ==="
cat > /tmp/wmma_multitile_ref.cu <<'EOF'
#include <mma.h>
using namespace nvcuda::wmma;
extern "C" __global__ void wmma_multitile_ref(const __half *a, const __half *b, float *c) {
    fragment<matrix_a, 16, 16, 16, __half, row_major> A;
    fragment<matrix_b, 16, 16, 16, __half, col_major> B;
    fragment<accumulator, 16, 16, 16, float> C;
    fill_fragment(C, 0.0f);
    #pragma unroll
    for (int k = 0; k < 4; ++k) {
        load_matrix_sync(A, a + k * 256, 16);
        load_matrix_sync(B, b + k * 256, 16);
        mma_sync(C, A, B, C);
    }
    store_matrix_sync(c, C, 16, mem_row_major);
}
EOF

cat > /tmp/wmma_64x64_ref.cu <<'EOF'
#include <mma.h>
using namespace nvcuda::wmma;
extern "C" __global__ void wmma_64x64_ref(const __half *a, const __half *b, float *c) {
    int wm = (blockIdx.x * blockDim.x + threadIdx.x) / 32;  // warp id
    int wy = wm / 4;
    int wx = wm % 4;
    fragment<matrix_a, 16, 16, 16, __half, row_major> A;
    fragment<matrix_b, 16, 16, 16, __half, col_major> B;
    fragment<accumulator, 16, 16, 16, float> C;
    fill_fragment(C, 0.0f);
    load_matrix_sync(A, a + wy * 16 * 64, 64);
    load_matrix_sync(B, b + wx * 16 * 64, 64);
    mma_sync(C, A, B, C);
    store_matrix_sync(c + wy * 16 * 64 + wx * 16, C, 64, mem_row_major);
}
EOF

cat > /tmp/tf32_ref.cu <<'EOF'
#include <mma.h>
using namespace nvcuda::wmma;
extern "C" __global__ void tf32_ref(const float *a, const float *b, float *c) {
    fragment<matrix_a, 16, 16, 8, precision::tf32, row_major> A;
    fragment<matrix_b, 16, 16, 8, precision::tf32, col_major> B;
    fragment<accumulator, 16, 16, 8, float> C;
    fill_fragment(C, 0.0f);
    load_matrix_sync(A, a, 16);
    load_matrix_sync(B, b, 16);
    #pragma unroll
    for (int i = 0; i < A.num_elements; ++i) A.x[i] = __float_to_tf32(A.x[i]);
    #pragma unroll
    for (int i = 0; i < B.num_elements; ++i) B.x[i] = __float_to_tf32(B.x[i]);
    mma_sync(C, A, B, C);
    store_matrix_sync(c, C, 16, mem_row_major);
}
EOF

for pair in "step2_wmma_multitile.ptx:wmma_multitile_ref:sm_80" "step3_wmma_64x64_grid.ptx:wmma_64x64_ref:sm_80" "step5_tf32_gemm.ptx:tf32_ref:sm_80"; do
  hexa=$(echo "$pair" | cut -d: -f1)
  ref=$(echo "$pair" | cut -d: -f2)
  arch=$(echo "$pair" | cut -d: -f3)
  refptx="/tmp/${ref}.ptx"
  nvcc -arch="$arch" -ptx "/tmp/${ref}.cu" -o "$refptx" 2>&1 | head -2
  [ ! -f "$refptx" ] && { echo "$hexa vs $ref: NVCC FAILED"; continue; }
  refcubin="/tmp/${ref}.cubin"
  ptxas -arch="$arch" -o "$refcubin" "$refptx" 2>/dev/null
  hexa_sass=$(cuobjdump --dump-sass "/tmp/${hexa%.ptx}.cubin" 2>/dev/null | grep -cE '^\s+/\*[0-9a-fA-F]+\*/')
  ref_sass=$(cuobjdump --dump-sass "$refcubin" 2>/dev/null | grep -cE '^\s+/\*[0-9a-fA-F]+\*/')
  echo "$hexa vs $ref: hexa_sass=$hexa_sass ref_sass=$ref_sass ratio=$(echo "scale=3; $hexa_sass / $ref_sass" | bc)"
done
echo ""

# ─── 4. vec-add bandwidth measurement (§4a) ──────────────────────────
echo "=== §4a vec-add bandwidth measurement (FP64 PR #82 + f16 PR #189) ==="
# Build a minimal host driver inline
cat > /tmp/vadd_bw_host.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#define CHECK(call) do { CUresult e = (call); \
    if (e != CUDA_SUCCESS) { const char *s; cuGetErrorString(e, &s); \
        fprintf(stderr, "CUDA err %d: %s\n", e, s); return 1; }} while (0)

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s <ptx> <kernel_name>\n", argv[0]); return 1; }
    CHECK(cuInit(0));
    CUdevice dev; CHECK(cuDeviceGet(&dev, 0));
    CUcontext ctx; CHECK(cuCtxCreate(&ctx, 0, dev));
    FILE *fp = fopen(argv[1], "r"); if (!fp) { perror("fopen"); return 1; }
    fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); fread(ptx, 1, sz, fp); ptx[sz] = 0; fclose(fp);
    CUmodule mod; CUjit_option opts[] = {CU_JIT_TARGET_FROM_CUCONTEXT};
    CHECK(cuModuleLoadDataEx(&mod, ptx, 0, NULL, NULL));
    CUfunction fn; CHECK(cuModuleGetFunction(&fn, mod, argv[2]));
    // N = 2^24 = 16M elements
    long N = 16 * 1024 * 1024;
    size_t elem_bytes = 8;  // f64 default; adjusts via argv[3]
    if (argc >= 4) elem_bytes = atol(argv[3]);
    size_t bytes = N * elem_bytes;
    CUdeviceptr a, b, c;
    CHECK(cuMemAlloc(&a, bytes)); CHECK(cuMemAlloc(&b, bytes)); CHECK(cuMemAlloc(&c, bytes));
    CHECK(cuMemsetD8(a, 0x3f, bytes));
    CHECK(cuMemsetD8(b, 0x3f, bytes));
    int reps = 100;
    int warmup = 10;
    void *args[] = {&a, &b, &c, &N};
    int tpb = 256; int grid = (int)((N + tpb - 1) / tpb);
    // warmup
    for (int i = 0; i < warmup; ++i) {
        cuLaunchKernel(fn, grid, 1, 1, tpb, 1, 1, 0, NULL, args, NULL);
    }
    CHECK(cuCtxSynchronize());
    CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
    cuEventRecord(t0, 0);
    for (int i = 0; i < reps; ++i) {
        cuLaunchKernel(fn, grid, 1, 1, tpb, 1, 1, 0, NULL, args, NULL);
    }
    cuEventRecord(t1, 0);
    cuEventSynchronize(t1);
    float ms; cuEventElapsedTime(&ms, t0, t1);
    double total_bytes = 3.0 * bytes * reps;  // 2 reads + 1 write per elem
    double gb_per_s = total_bytes / (ms * 1e-3) / 1e9;
    printf("N=%ld elem_bytes=%zu reps=%d total_ms=%.4f mean_us=%.4f bandwidth_GB_per_s=%.4f\n",
           N, elem_bytes, reps, ms, ms * 1000.0 / reps, gb_per_s);
    cuCtxDestroy(ctx);
    return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/vadd_bw_host /tmp/vadd_bw_host.c -lcuda 2>&1 | tail -3

# Determine kernel symbols
for pair in "f16_vadd.ptx:2" "vec_add_unroll1.ptx:8" "vec_add_unroll2.ptx:8"; do
  ptx=$(echo "$pair" | cut -d: -f1)
  elem=$(echo "$pair" | cut -d: -f2)
  [ ! -f "/tmp/$ptx" ] && { echo "$ptx: MISSING"; continue; }
  kname=$(grep -oE '\.visible \.entry [a-zA-Z_][a-zA-Z_0-9]*' "/tmp/$ptx" | awk '{print $3}' | head -1)
  [ -z "$kname" ] && kname=$(grep -oE '\.entry [a-zA-Z_][a-zA-Z_0-9]*' "/tmp/$ptx" | awk '{print $2}' | head -1)
  echo "$ptx kernel=$kname:"
  /tmp/vadd_bw_host "/tmp/$ptx" "$kname" "$elem" 2>&1 | tail -2
done
echo ""

# ─── 5. kernel-launch overhead (empty kernel 100k reps) ───────────────
echo "=== §4a kernel-launch overhead (empty kernel) ==="
cat > /tmp/empty_kernel.ptx <<EOF
.version 7.0
.target sm_80
.address_size 64

.visible .entry empty_k()
{
    ret;
}
EOF

cat > /tmp/launch_overhead_host.c <<'EOF'
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    cuInit(0);
    CUdevice dev; cuDeviceGet(&dev, 0);
    CUcontext ctx; cuCtxCreate(&ctx, 0, dev);
    FILE *fp = fopen(argv[1], "r"); fseek(fp, 0, SEEK_END); long sz = ftell(fp); fseek(fp, 0, SEEK_SET);
    char *ptx = malloc(sz + 1); fread(ptx, 1, sz, fp); ptx[sz] = 0; fclose(fp);
    CUmodule mod; cuModuleLoadDataEx(&mod, ptx, 0, NULL, NULL);
    CUfunction fn; cuModuleGetFunction(&fn, mod, "empty_k");
    int reps = 100000;
    // warmup
    for (int i = 0; i < 100; ++i) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, NULL, NULL, NULL);
    cuCtxSynchronize();
    CUevent t0, t1; cuEventCreate(&t0, 0); cuEventCreate(&t1, 0);
    cuEventRecord(t0, 0);
    for (int i = 0; i < reps; ++i) cuLaunchKernel(fn, 1, 1, 1, 1, 1, 1, 0, NULL, NULL, NULL);
    cuEventRecord(t1, 0);
    cuEventSynchronize(t1);
    float ms; cuEventElapsedTime(&ms, t0, t1);
    printf("empty_kernel reps=%d total_ms=%.4f mean_us=%.4f\n", reps, ms, ms * 1000.0 / reps);
    cuCtxDestroy(ctx);
    return 0;
}
EOF
nvcc -O2 -arch=sm_80 -o /tmp/launch_overhead_host /tmp/launch_overhead_host.c -lcuda 2>&1 | tail -2
/tmp/launch_overhead_host /tmp/empty_kernel.ptx 2>&1 | tail -2
echo ""

# ─── 6. cuobjdump per-kernel resource usage (compact) ────────────────
echo "=== §7a per-kernel resource usage from cubin ==="
for f in "${PTX_FILES[@]}"; do
  out="/tmp/${f%.ptx}.cubin"
  [ ! -f "$out" ] && continue
  ri=$(cuobjdump --dump-resource-usage "$out" 2>/dev/null | tr -d '\n' | sed 's/  */ /g')
  echo "$f: $ri"
done

echo ""
echo "=== END GPU.md parallel checkbox measurement ==="
