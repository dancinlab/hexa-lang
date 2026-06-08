#!/usr/bin/env bash
# run_bench3.sh — HEXA-BENCH BENCH-3 driver (run ON aiden, the free pool RTX 5070).
#
# Re-runs the BENCH-1 TF32 batch sweep, but with the bench step's D->D projection
# GEMM swapped from the NAIVE tiled CUDA-core kernel to a TUNED GEMM.
#
# OG10 (HEXA-FUSION W10 TF32-wgmma own-GEMM) is sm_90a (Hopper). aiden is sm_120
# (consumer Blackwell). The ISA check (ptxas -arch=sm_120 on wgmma_tf32_w10.cu)
# FAILS: 'wgmma.mma_async/fence/commit_group/wait_group not supported on sm_120'.
# So OG10-exact cannot run here; we use cuBLAS-TF32 (CUBLAS_COMPUTE_32F_FAST_TF32)
# as the tuned-GEMM PROXY = the realistic ceiling a sm_90a OG10 would approximate.
#
# Emits all [CFG]/[DETERMINISM]/[GATE]/[RESULT] lines verbatim for the verdict.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
D="${D:-768}"; T="${T:-256}"; ITERS="${ITERS:-50}"
BSWEEP="${BSWEEP:-1 2 4 8}"
ARCH="${ARCH:-sm_120}"     # RTX 5070 = consumer Blackwell sm_120

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB"

echo "############ HEXA-BENCH BENCH-3  D=$D T=$T iters=$ITERS  arch=$ARCH ############"
echo "==== nvidia-smi ===="
nvidia-smi
echo "==== nvcc ===="
nvcc --version | tail -2

# ---- ISA CHECK: can the OG10 sm_90a wgmma own-GEMM compile for sm_120? ----
echo "==== OG10 (W10 TF32-wgmma) sm_120 ISA CHECK ===="
if [ -f "$HOME/wgmma_tf32_w10.cu" ]; then
  if nvcc $NVCC_FLAGS -lcuda -o /tmp/w10_sm120 "$HOME/wgmma_tf32_w10.cu" 2>/tmp/w10_isa.err; then
    echo "OG10 sm_120 COMPILE: OK (unexpected — wgmma available on this sm_120!)"
    OG10_OK=1
  else
    echo "OG10 sm_120 COMPILE: FAIL (expected). First errors:"
    grep -m4 "not supported on .target 'sm_120'" /tmp/w10_isa.err || head -4 /tmp/w10_isa.err
    OG10_OK=0
  fi
else
  echo "OG10 source wgmma_tf32_w10.cu not staged on host — skipping ISA probe"
  OG10_OK=0
fi

# ---- build TF32 bench variants ----
echo "==== build flame_bench_step_og TF32 (NAIVE baseline + cuBLAS-TF32 proxy) ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=0 -o /tmp/flame_naive_tf32 "$HERE/flame_bench_step_og.cu" \
  || { echo "BUILD FAIL naive"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=1 -o /tmp/flame_cublas_tf32 "$HERE/flame_bench_step_og.cu" -lcublas \
  || { echo "BUILD FAIL cublas"; exit 1; }
echo "build OK"

run_flame () { local bin=$1; for B in $BSWEEP; do echo "--- $bin B=$B ---"; "/tmp/$bin" "$D" "$T" "$B" "$ITERS"; done; }
run_torch () { local md=$1; for B in $BSWEEP; do echo "--- torch tf32 $md B=$B ---"; python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype tf32 --mode "$md" --iters "$ITERS"; done; }

echo "######## FLAME TF32 — NAIVE (BENCH-1 baseline, re-measured on this binary) ########"
run_flame flame_naive_tf32
echo "######## FLAME TF32 — cuBLAS-TF32 PROXY (tuned/own-GEMM stand-in for OG10) ########"
run_flame flame_cublas_tf32

echo "######## TORCH TF32 ########"
echo "==== torch TF32 eager ===="  ; run_torch eager
echo "==== torch TF32 compile ===="; run_torch compile
echo "############ BENCH-3 DONE ############"
