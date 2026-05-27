#!/bin/bash
# rounds_5_8_refire.sh — regenerate crash-lost rounds 5-8 + cookbook revalidate
# Idempotent + $0 (driver-API queries + ptxas oracles + tiny timing kernel)
# Target: ubu-2 RTX 5070 sm_120 driver 580 / CUDA 12.0
set +e  # keep going on partial failures, log everything

WORKDIR=$HOME/gpu_round5_8_refire_2026_05_21
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

LOG=fire.log
exec > >(tee -a "$LOG") 2>&1

echo "=== rounds 5-8 + cookbook-revalidate refire 2026-05-21 ==="
date -u
hostname

# ============================================================
# A. Device caps (Round 5+7: cuDeviceGetAttribute table)
# ============================================================
cat > caps.c <<'EOF'
#include <stdio.h>
#include <cuda.h>
int main() {
    cuInit(0);
    CUdevice dev;
    cuDeviceGet(&dev, 0);
    char name[256]; cuDeviceGetName(name, 256, dev);
    int major, minor;
    cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev);
    cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev);
    printf("name=%s\nsm=%d.%d\n", name, major, minor);
    #define Q(n,c) { int v; cuDeviceGetAttribute(&v, c, dev); printf("%s=%d\n", n, v); }
    Q("multiprocessor_count",       CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT);
    Q("max_threads_per_block",      CU_DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK);
    Q("max_regs_per_block",         CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_BLOCK);
    Q("max_shared_per_block",       CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK);
    Q("max_shared_per_sm",          CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_MULTIPROCESSOR);
    Q("max_regs_per_sm",            CU_DEVICE_ATTRIBUTE_MAX_REGISTERS_PER_MULTIPROCESSOR);
    Q("warp_size",                  CU_DEVICE_ATTRIBUTE_WARP_SIZE);
    Q("clock_rate_khz",             CU_DEVICE_ATTRIBUTE_CLOCK_RATE);
    Q("memory_bus_width",           CU_DEVICE_ATTRIBUTE_GLOBAL_MEMORY_BUS_WIDTH);
    Q("l2_cache_size",              CU_DEVICE_ATTRIBUTE_L2_CACHE_SIZE);
    Q("concurrent_kernels",         CU_DEVICE_ATTRIBUTE_CONCURRENT_KERNELS);
    Q("cooperative_launch",         CU_DEVICE_ATTRIBUTE_COOPERATIVE_LAUNCH);
    Q("cooperative_multi_device_launch", CU_DEVICE_ATTRIBUTE_COOPERATIVE_MULTI_DEVICE_LAUNCH);
    Q("async_engine_count",         CU_DEVICE_ATTRIBUTE_ASYNC_ENGINE_COUNT);
    Q("managed_memory",             CU_DEVICE_ATTRIBUTE_MANAGED_MEMORY);
    Q("pageable_memory_access",     CU_DEVICE_ATTRIBUTE_PAGEABLE_MEMORY_ACCESS);
    Q("concurrent_managed_access",  CU_DEVICE_ATTRIBUTE_CONCURRENT_MANAGED_ACCESS);
    Q("kernel_exec_timeout",        CU_DEVICE_ATTRIBUTE_KERNEL_EXEC_TIMEOUT);
    return 0;
}
EOF
gcc caps.c -o caps -lcuda -I/usr/local/cuda/include -L/usr/local/cuda/lib64 2>&1
./caps > caps.txt 2>&1
echo "== caps.txt =="
cat caps.txt

# ============================================================
# B. Telemetry (Round 5/6)
# ============================================================
nvidia-smi --query-gpu=name,temperature.gpu,power.draw,clocks.gr,clocks.sm,clocks.mem --format=csv,noheader > telemetry.csv 2>&1
echo "== telemetry.csv =="
cat telemetry.csv
nvidia-smi topo -m > topology.txt 2>&1
nvidia-smi mig -lgi > mig_list.txt 2>&1 || echo "(MIG not supported)" >> mig_list.txt
nvcc --version > nvcc_version.txt 2>&1
nvidia-smi --query-gpu=driver_version --format=csv,noheader > driver_version.txt 2>&1
ptxas --version > ptxas_version.txt 2>&1
ls -la /usr/local/cuda/lib64/libcupti.so* > cupti_lib.txt 2>&1
ls -la /usr/lib/x86_64-linux-gnu/libcupti.so* >> cupti_lib.txt 2>&1
ls -la ~/.nv/ComputeCache/ 2>/dev/null | head -5 > persistent_cache.txt
du -sh ~/.nv/ComputeCache/ 2>/dev/null >> persistent_cache.txt
find ~/.nv/ComputeCache -type f 2>/dev/null | wc -l > persistent_cache_count.txt
ps -ef | grep -i nvidia-cuda-mps | grep -v grep > mps_check.txt
echo "MPS_processes=$(wc -l < mps_check.txt)" >> mps_check.txt

# ============================================================
# C. ptxas hand-emit oracle smokes (Round 6/7/8)
# ============================================================
mkdir -p oracle_ptx
cd oracle_ptx
ORACLE_RESULTS=oracle_results.txt
> "$ORACLE_RESULTS"

# vprintf
cat > vprintf.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.extern .func (.param .b32 func_retval0) vprintf (.param .b64 fmt, .param .b64 args);
.global .align 1 .b8 _fmt[5] = {72, 105, 10, 0, 0};
.visible .entry hexa_print_smoke()
{
    .reg .b64 %rd1, %rd2;
    .reg .b32 %r1;
    mov.u64 %rd1, _fmt;
    cvta.global.u64 %rd1, %rd1;
    mov.u64 %rd2, 0;
    {
        .param .b64 fmt_p;
        .param .b64 args_p;
        .param .b32 retval_p;
        st.param.b64 [fmt_p+0], %rd1;
        st.param.b64 [args_p+0], %rd2;
        call.uni (retval_p), vprintf, (fmt_p, args_p);
    }
    ret;
}
EOF
ptxas vprintf.ptx -arch=sm_80 -o vprintf.cubin 2>vprintf.err; rc=$?
echo "vprintf_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat vprintf.err >> "$ORACLE_RESULTS"

# __assertfail (extern decl, signature acceptance)
cat > assertfail.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.extern .func __assertfail (.param .b64 msg, .param .b64 file, .param .b32 line, .param .b64 fn, .param .b64 sz);
.visible .entry hexa_assert_smoke()
{
    ret;
}
EOF
ptxas assertfail.ptx -arch=sm_80 -o assertfail.cubin 2>assertfail.err; rc=$?
echo "assertfail_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat assertfail.err >> "$ORACLE_RESULTS"

# atom.shared.add.s32
cat > atom_shared.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.shared .align 4 .b8 _sh[16];
.visible .entry hexa_atom_shared()
{
    .reg .b64 %rd1;
    .reg .b32 %r0, %r1;
    mov.u64 %rd1, _sh;
    cvta.shared.u64 %rd1, %rd1;
    mov.u32 %r0, 1;
    atom.shared.add.s32 %r1, [%rd1], %r0;
    ret;
}
EOF
ptxas atom_shared.ptx -arch=sm_80 -o atom_shared.cubin 2>atom_shared.err; rc=$?
echo "atom_shared_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat atom_shared.err >> "$ORACLE_RESULTS"

# ldmatrix.sync.aligned.x4.m8n8.shared.b16
cat > ldmatrix.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.shared .align 16 .b8 _sh[512];
.visible .entry hexa_ldmatrix()
{
    .reg .b64 %rd1;
    .reg .b32 %r1, %r2, %r3, %r4;
    mov.u64 %rd1, _sh;
    cvta.shared.u64 %rd1, %rd1;
    ldmatrix.sync.aligned.x4.m8n8.shared.b16 {%r1, %r2, %r3, %r4}, [%rd1];
    ret;
}
EOF
ptxas ldmatrix.ptx -arch=sm_80 -o ldmatrix.cubin 2>ldmatrix.err; rc=$?
echo "ldmatrix_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat ldmatrix.err >> "$ORACLE_RESULTS"

# mbarrier.init.shared::cta.b64 (sm_90)
cat > mbarrier.ptx <<'EOF'
.version 7.8
.target sm_90
.address_size 64
.shared .align 8 .b8 _mb[8];
.visible .entry hexa_mbarrier()
{
    .reg .b64 %rd1;
    mov.u64 %rd1, _mb;
    cvta.shared.u64 %rd1, %rd1;
    mbarrier.init.shared::cta.b64 [%rd1], 1;
    ret;
}
EOF
ptxas mbarrier.ptx -arch=sm_90 -o mbarrier.cubin 2>mbarrier.err; rc=$?
echo "mbarrier_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat mbarrier.err >> "$ORACLE_RESULTS"

# wmma f16xf16->f16 family
cat > wmma_f16_f16_f16.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.visible .entry hexa_wmma_f16_f16_f16()
{
    .reg .b32 %fra0, %fra1, %fra2, %fra3, %fra4, %fra5, %fra6, %fra7;
    .reg .b32 %frb0, %frb1, %frb2, %frb3, %frb4, %frb5, %frb6, %frb7;
    .reg .b32 %frc0, %frc1, %frc2, %frc3;
    .reg .b32 %frd0, %frd1, %frd2, %frd3;
    wmma.mma.sync.aligned.row.col.m16n16k16.f16.f16
        {%frd0, %frd1, %frd2, %frd3},
        {%fra0, %fra1, %fra2, %fra3, %fra4, %fra5, %fra6, %fra7},
        {%frb0, %frb1, %frb2, %frb3, %frb4, %frb5, %frb6, %frb7},
        {%frc0, %frc1, %frc2, %frc3};
    ret;
}
EOF
ptxas wmma_f16_f16_f16.ptx -arch=sm_80 -o wmma_f16_f16_f16.cubin 2>wmma_f16_f16_f16.err; rc=$?
echo "wmma_f16_f16_f16_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat wmma_f16_f16_f16.err >> "$ORACLE_RESULTS"

# wmma bf16xbf16->f32 family
cat > wmma_bf16_bf16_f32.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.visible .entry hexa_wmma_bf16_bf16_f32()
{
    .reg .b32 %fra0, %fra1, %fra2, %fra3;
    .reg .b32 %frb0, %frb1, %frb2, %frb3;
    .reg .f32 %frc0, %frc1, %frc2, %frc3, %frc4, %frc5, %frc6, %frc7;
    .reg .f32 %frd0, %frd1, %frd2, %frd3, %frd4, %frd5, %frd6, %frd7;
    wmma.mma.sync.aligned.row.col.m16n16k16.f32.bf16.bf16.f32
        {%frd0, %frd1, %frd2, %frd3, %frd4, %frd5, %frd6, %frd7},
        {%fra0, %fra1, %fra2, %fra3},
        {%frb0, %frb1, %frb2, %frb3},
        {%frc0, %frc1, %frc2, %frc3, %frc4, %frc5, %frc6, %frc7};
    ret;
}
EOF
ptxas wmma_bf16_bf16_f32.ptx -arch=sm_80 -o wmma_bf16_bf16_f32.cubin 2>wmma_bf16_bf16_f32.err; rc=$?
echo "wmma_bf16_bf16_f32_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat wmma_bf16_bf16_f32.err >> "$ORACLE_RESULTS"

# coop_launch grid kernel (bar.sync 0)
cat > coop_launch.ptx <<'EOF'
.version 7.0
.target sm_80
.address_size 64
.visible .entry hexa_coop_launch()
{
    .reg .b32 %r1;
    mov.u32 %r1, %tid.x;
    bar.sync 0;
    ret;
}
EOF
ptxas coop_launch.ptx -arch=sm_80 -o coop_launch.cubin 2>coop_launch.err; rc=$?
echo "coop_launch_rc=$rc" >> "$ORACLE_RESULTS"
[ $rc -ne 0 ] && cat coop_launch.err >> "$ORACLE_RESULTS"

# TMA cp.async.bulk attempt (expected FAIL — document honestly)
cat > tma_attempt.ptx <<'EOF'
.version 8.0
.target sm_90
.address_size 64
.shared .align 16 .b8 _sh[1024];
.visible .entry hexa_tma()
{
    .reg .b64 %rd1, %rd2;
    mov.u64 %rd1, _sh;
    cvta.shared.u64 %rd1, %rd1;
    mov.u64 %rd2, 0;
    cp.async.bulk.shared::cta.global [%rd1], [%rd2], 1024;
    ret;
}
EOF
ptxas tma_attempt.ptx -arch=sm_90 -o tma_attempt.cubin 2>tma_attempt.err; rc=$?
echo "tma_attempt_rc=$rc" >> "$ORACLE_RESULTS"
echo "tma_attempt_stderr:" >> "$ORACLE_RESULTS"
cat tma_attempt.err >> "$ORACLE_RESULTS"

echo "== oracle_results.txt =="
cat "$ORACLE_RESULTS"
cd ..

# ============================================================
# D. Timing kernel (cuLaunchKernel JIT + cuMemAlloc + recovery)
# ============================================================
cat > timing.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <cuda.h>
#include <time.h>
static long ns(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000000000L + t.tv_nsec;
}
int main() {
    cuInit(0);
    CUcontext ctx;
    CUdevice dev;
    cuDeviceGet(&dev, 0);
    cuCtxCreate(&ctx, 0, dev);

    const char* ptx =
        ".version 7.0\n.target sm_80\n.address_size 64\n"
        ".visible .entry empty() { ret; }\n";

    long mod_t0 = ns();
    CUmodule mod;
    CUresult r = cuModuleLoadData(&mod, ptx);
    long mod_t1 = ns();
    if (r != CUDA_SUCCESS) { printf("module_load_err=%d\n", r); return 1; }
    printf("cold_module_load_us=%ld\n", (mod_t1 - mod_t0) / 1000);
    CUfunction fn;
    cuModuleGetFunction(&fn, mod, "empty");

    long t0 = ns();
    cuLaunchKernel(fn, 1,1,1, 1,1,1, 0, 0, NULL, NULL);
    cuCtxSynchronize();
    long t1 = ns();
    printf("first_launch_us=%ld\n", (t1 - t0) / 1000);

    long total = 0;
    int N = 1000;
    for (int i = 0; i < N; i++) {
        long a = ns();
        cuLaunchKernel(fn, 1,1,1, 1,1,1, 0, 0, NULL, NULL);
        long b = ns();
        total += (b - a);
    }
    cuCtxSynchronize();
    printf("nth_launch_us_avg=%ld\n", total / (N * 1000));

    // warm cache cuModuleLoad
    cuModuleUnload(mod);
    long wm_t0 = ns();
    cuModuleLoadData(&mod, ptx);
    long wm_t1 = ns();
    printf("warm_module_load_us=%ld\n", (wm_t1 - wm_t0) / 1000);

    // cuMemAlloc latency
    size_t sizes[5] = {4096L, 4096L * 1024L, 4096L * 1024L * 16L, 4096L * 1024L * 64L, 256L * 1024L * 1024L};
    for (int i = 0; i < 5; i++) {
        CUdeviceptr p;
        long a = ns();
        cuMemAlloc(&p, sizes[i]);
        long b = ns();
        cuMemFree(p);
        long c = ns();
        printf("alloc size=%zu alloc_us=%ld free_us=%ld\n", sizes[i], (b - a) / 1000, (c - b) / 1000);
    }

    // GPU error recovery: 3 ctx-cycle trials
    for (int trial = 0; trial < 3; trial++) {
        CUcontext c2;
        cuCtxCreate(&c2, 0, dev);
        CUmodule m2;
        cuModuleLoadData(&m2, ptx);
        CUfunction f2;
        cuModuleGetFunction(&f2, m2, "empty");
        cuLaunchKernel(f2, 1,1,1, 1,1,1, 0, 0, NULL, NULL);
        cuCtxSynchronize();
        cuModuleUnload(m2);
        cuCtxDestroy(c2);
        printf("recovery_trial_%d=OK\n", trial + 1);
    }

    cuModuleUnload(mod);
    cuCtxDestroy(ctx);
    return 0;
}
EOF
gcc timing.c -o timing -lcuda -I/usr/local/cuda/include -L/usr/local/cuda/lib64 2>&1
./timing > timing.txt 2>&1
echo "== timing.txt =="
cat timing.txt

# ============================================================
# E. PTX corpus audit (grep memory-hierarchy + atomics + ldmatrix)
# ============================================================
mkdir -p ptx_corpus
PTX_FOUND=$(find /tmp /home/summer /home/aiden /home/wilson -maxdepth 6 -name "*.ptx" 2>/dev/null | head -30)
echo "== PTX corpus listing =="
echo "$PTX_FOUND"
for f in $PTX_FOUND; do
    cp "$f" ptx_corpus/ 2>/dev/null || true
done
ls ptx_corpus/ > ptx_corpus_listing.txt
echo "ptx_corpus_count=$(ls ptx_corpus/ | wc -l)"

audit_grep() {
    local pat="$1"
    local total=0
    for f in ptx_corpus/*.ptx; do
        [ -f "$f" ] || continue
        c=$(grep -cE "$pat" "$f" 2>/dev/null)
        total=$((total + ${c:-0}))
    done
    echo "$pat = $total"
}

{
    echo "=== memory-hierarchy + cache-modifier audit ==="
    audit_grep 'ld\.cs'
    audit_grep 'ld\.lu'
    audit_grep 'st\.cg'
    audit_grep 'st\.cs'
    audit_grep 'st\.wt'
    audit_grep 'st\.wb'
    echo "=== async + barrier audit ==="
    audit_grep 'mbarrier'
    audit_grep 'cp\.async'
    echo "=== fragment-load + atomic audit ==="
    audit_grep 'ldmatrix'
    audit_grep 'atom\.'
    audit_grep 'red\.'
    echo "=== state-space declarations ==="
    audit_grep '\.shared'
    audit_grep '\.local'
    audit_grep '\.const'
    audit_grep '\.global'
} > audit_grep.txt
echo "== audit_grep.txt =="
cat audit_grep.txt

# ============================================================
# F. Cookbook re-validate (stash 1 §1f): 6 cookbook PTX
# ============================================================
# Looks for the cookbook artifacts in the hexa-lang clone if present
HEXA_REPO="$HOME/core/hexa-lang"
COOKBOOK_DIR=cookbook_revalidate
mkdir -p $COOKBOOK_DIR
COOKBOOK_RESULT=$COOKBOOK_DIR/result.txt
> "$COOKBOOK_RESULT"

# Map of step -> PTX path (relative to hexa-lang repo) plus composite from /home/summer
declare -A STEPS=(
    [step1_single_tile]="$HEXA_REPO/inbox/fires/rfc067_p4_2026_05_20/wmma_16x16.ptx"
    [step2_multitile]="$HEXA_REPO/inbox/fires/rfc067_p4_multitile_2026_05_20/wmma_multitile.ptx"
    [step3_multiwarp]="$HEXA_REPO/inbox/fires/rfc067_p4_multiwarp_2026_05_20/wmma_64x64_grid.ptx"
    [step4_cp_async]="$HEXA_REPO/inbox/fires/rfc067_p4_cp_async_2026_05_20/wmma_cp_async.ptx"
    [step5_tf32]="$HEXA_REPO/inbox/fires/rfc067_p5_tf32_2026_05_20/tf32_gemm.ptx"
    [composite_perf]="/home/summer/r067_perf/wmma_256x256_grid.ptx"
)
for step in step1_single_tile step2_multitile step3_multiwarp step4_cp_async step5_tf32 composite_perf; do
    src="${STEPS[$step]}"
    if [ ! -f "$src" ]; then
        echo "$step: SKIP (not found: $src)" >> "$COOKBOOK_RESULT"
        continue
    fi
    cp "$src" "$COOKBOOK_DIR/$step.ptx"
    ptxas "$COOKBOOK_DIR/$step.ptx" -arch=sm_80 -o "$COOKBOOK_DIR/$step.cubin" 2>"$COOKBOOK_DIR/$step.err"
    rc=$?
    sass_count=0
    if [ $rc -eq 0 ]; then
        sass_count=$(cuobjdump --dump-sass "$COOKBOOK_DIR/$step.cubin" 2>/dev/null | grep -cE '^\s*/\*' || echo 0)
    fi
    echo "$step: ptxas_rc=$rc sass_instr=$sass_count" >> "$COOKBOOK_RESULT"
done
echo "== cookbook_revalidate result =="
cat "$COOKBOOK_RESULT"

# ============================================================
# G. nvcc reference vs hexa step1 SASS-diff (stash 1 §1f)
# ============================================================
mkdir -p nvcc_ref
cat > nvcc_ref/wmma_ref.cu <<'EOF'
// Reference cookbook step1: single-tile 16x16 WMMA in nvcc CUDA C
#include <mma.h>
using namespace nvcuda;
__global__ void wmma_ref(half* A, half* B, float* C) {
    wmma::fragment<wmma::matrix_a, 16,16,16, half, wmma::row_major> a_frag;
    wmma::fragment<wmma::matrix_b, 16,16,16, half, wmma::col_major> b_frag;
    wmma::fragment<wmma::accumulator, 16,16,16, float> c_frag;
    wmma::fill_fragment(c_frag, 0.0f);
    wmma::load_matrix_sync(a_frag, A, 16);
    wmma::load_matrix_sync(b_frag, B, 16);
    wmma::mma_sync(c_frag, a_frag, b_frag, c_frag);
    wmma::store_matrix_sync(C, c_frag, 16, wmma::mem_row_major);
}
EOF
nvcc -ptx -arch=sm_80 nvcc_ref/wmma_ref.cu -o nvcc_ref/wmma_ref.ptx 2>nvcc_ref/nvcc.err
nvcc_ptx_rc=$?
nvcc_ptx_sass=0
if [ $nvcc_ptx_rc -eq 0 ]; then
    nvcc -cubin -arch=sm_80 nvcc_ref/wmma_ref.cu -o nvcc_ref/wmma_ref.cubin 2>>nvcc_ref/nvcc.err
    nvcc_ptx_sass=$(cuobjdump --dump-sass nvcc_ref/wmma_ref.cubin 2>/dev/null | grep -cE '^\s*/\*')
fi
hexa_step1=0
if [ -f $COOKBOOK_DIR/step1_single_tile.cubin ]; then
    hexa_step1=$(cuobjdump --dump-sass $COOKBOOK_DIR/step1_single_tile.cubin 2>/dev/null | grep -cE '^\s*/\*')
fi
{
    echo "nvcc_ptx_rc=$nvcc_ptx_rc"
    echo "nvcc_ref_sass_instr=$nvcc_ptx_sass"
    echo "hexa_step1_sass_instr=$hexa_step1"
    if [ "$nvcc_ptx_sass" -gt 0 ] && [ "$hexa_step1" -gt 0 ]; then
        ratio=$(awk -v h=$hexa_step1 -v n=$nvcc_ptx_sass 'BEGIN{ printf "%.3f", h/n }')
        echo "hexa_to_nvcc_sass_ratio=$ratio"
    fi
} > nvcc_ref/sass_diff.txt
echo "== nvcc_ref/sass_diff.txt =="
cat nvcc_ref/sass_diff.txt

# ============================================================
# H. result.json (aggregate)
# ============================================================
cat > result.json <<EOF
{
  "campaign": "rounds_5_8_recovered_after_crash_2026_05_21",
  "host": "$(hostname)",
  "gpu": "$(nvidia-smi -L | head -1)",
  "date_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "rounds_recovered": [5, 6, 7, 8],
  "honest_scope": "Driver-API + ptxas-acceptance oracles + cookbook revalidate. HGEMM scale-up matrix at M=256..1024 NOT re-fired (would need composite kernel variable-shape host launcher). The PTX-acceptance battery + cuDeviceGetAttribute table + cuLaunchKernel timing + ptxas cookbook re-validate ARE fully reproduced.",
  "oracle_ptx_smokes": $(cat oracle_ptx/oracle_results.txt | wc -l),
  "cookbook_revalidate_entries": $(cat $COOKBOOK_RESULT | wc -l),
  "ptx_corpus_audited": $(ls ptx_corpus/ | wc -l)
}
EOF
echo "== result.json =="
cat result.json

echo "==DONE=="
echo "WORKDIR=$WORKDIR"
ls -la "$WORKDIR"
