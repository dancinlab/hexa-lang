#!/usr/bin/env bash
# run_bench4.sh — HEXA-BENCH BENCH-4 driver (run ON a real H100, sm_90a Hopper, vast).
#
# BENCH-3 swapped the bench step's D->D projection GEMM for a TUNED GEMM but had to use
# cuBLAS-TF32 as a PROXY for OG10 because aiden's sm_120 rejected the Hopper wgmma ISA.
# BENCH-4 runs the SAME step with the ACTUAL OG10 own-GEMM (HEXA-FUSION W10 TF32-wgmma,
# self/native/wgmma/wgmma_tf32_w10_lib.h) on a real H100 — the true (not proxy) number.
#
# 3-way: NAIVE (BENCH-1) vs real OG10 (this) vs cuBLAS-TF32 proxy (BENCH-3) vs torch.
# Expectation: OG10 is 6.09x off cuBLAS, so it should land BETWEEN naive and the proxy
# (closing the 3-8x naive gap but LESS than the proxy's ~2x).
#
# Emits all [CFG]/[DETERMINISM]/[GATE]/[RESULT] lines verbatim for the verdict.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
D="${D:-768}"; T="${T:-256}"; ITERS="${ITERS:-50}"
BSWEEP="${BSWEEP:-1 2 4 8}"
ARCH="${ARCH:-sm_90a}"     # H100 = Hopper sm_90a (wgmma.mma_async requires the 'a' variant)

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE -I$HERE/wgmma"

echo "############ HEXA-BENCH BENCH-4  D=$D T=$T iters=$ITERS  arch=$ARCH ############"
echo "==== nvidia-smi ===="
nvidia-smi
echo "==== nvcc ===="
nvcc --version | tail -2

# ---- ISA CHECK: the OG10 sm_90a wgmma own-GEMM MUST compile on a real H100 ----
echo "==== OG10 (W10 TF32-wgmma) sm_90a ISA CHECK ===="
if nvcc $NVCC_FLAGS -DW10_NO_MAIN -lcuda -lcublas -c -o /tmp/og10_isa.o "$HERE/og10_gemm_wrap.cu" 2>/tmp/og10_isa.err; then
  echo "OG10 sm_90a COMPILE: OK (real H100 — wgmma.mma_async available, as expected)"
  OG10_OK=1
else
  echo "OG10 sm_90a COMPILE: FAIL (unexpected on H100!). First errors:"
  head -8 /tmp/og10_isa.err
  OG10_OK=0
fi

# ---- build TF32 bench variants: NAIVE, cuBLAS-TF32 proxy, real OG10 ----
echo "==== build flame_bench_step_og TF32 (NAIVE + cuBLAS-TF32 proxy) ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=0 -o /tmp/flame_naive_tf32 "$HERE/flame_bench_step_og.cu" \
  || { echo "BUILD FAIL naive"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=1 -o /tmp/flame_cublas_tf32 "$HERE/flame_bench_step_og.cu" -lcublas \
  || { echo "BUILD FAIL cublas"; exit 1; }

echo "==== build flame_bench_step_og TF32 (real OG10 own-GEMM, sm_90a) ===="
if [ "$OG10_OK" = "1" ]; then
  nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=2 \
       -o /tmp/flame_og10_tf32 "$HERE/flame_bench_step_og.cu" "$HERE/og10_gemm_wrap.cu" -lcuda -lcublas \
    && echo "build OK (OG10)" || { echo "BUILD FAIL og10"; OG10_OK=0; }
else
  echo "skip OG10 build (ISA check failed)"
fi

run_flame () { local bin=$1; for B in $BSWEEP; do echo "--- $bin B=$B ---"; "/tmp/$bin" "$D" "$T" "$B" "$ITERS"; done; }
run_torch () { local md=$1; for B in $BSWEEP; do echo "--- torch tf32 $md B=$B ---"; python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype tf32 --mode "$md" --iters "$ITERS"; done; }

echo "######## FLAME TF32 — NAIVE (BENCH-1 baseline, re-measured on THIS H100) ########"
run_flame flame_naive_tf32
echo "######## FLAME TF32 — real OG10 own-GEMM (sm_90a wgmma — the BENCH-4 number) ########"
if [ "$OG10_OK" = "1" ]; then run_flame flame_og10_tf32; else echo "OG10 unavailable — skipped"; fi
echo "######## FLAME TF32 — cuBLAS-TF32 PROXY (BENCH-3 optimistic ceiling) ########"
run_flame flame_cublas_tf32

echo "######## TORCH TF32 ########"
echo "==== torch TF32 eager ===="  ; run_torch eager
echo "==== torch TF32 compile ===="; run_torch compile

# ---- FP64 flame-win regime re-confirm on H100 (BENCH-1 was on RTX 5070) ----
echo "######## FP64 flame-win re-confirm on H100 (naive-GEMM lane) ########"
nvcc $NVCC_FLAGS -DBENCH_PREC=2 -DGEMM_BACKEND=0 -o /tmp/flame_fp64 "$HERE/flame_bench_step_og.cu" \
  && { for B in $BSWEEP; do echo "--- flame fp64 B=$B ---"; /tmp/flame_fp64 "$D" "$T" "$B" "$ITERS"; done
       for B in $BSWEEP; do echo "--- torch fp64 eager B=$B ---"; python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype fp64 --mode eager --iters "$ITERS"; done; } \
  || echo "FP64 build/run skipped"

echo "############ BENCH-4 DONE ############"
