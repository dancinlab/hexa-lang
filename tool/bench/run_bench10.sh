#!/usr/bin/env bash
# run_bench10.sh — HEXA-BENCH BENCH-10 driver (run ON a real H100, sm_90a Hopper, vast).
#
# Closes the LAST flame-cuBLAS losing cell D=4096/B=8 by FUSING flame's valley+AdamW glue
# (the lever BENCH-6/BENCH-9 pinned the residual to). BENCH-9 proved the GEMM is identical
# (both ride cuBLAS) and autotune/epilogue close ~0%; the gap is flame's UN-FUSED
# elementwise/optimizer kernels vs torch.compile's fused step.
#
# flame_bench_step_fused.cu measures FUSED vs UN-FUSED in the SAME source:
#   -DFUSED   : valley(LN+gelu+copy fused) + single-launch AdamW + TRANSPOSE-ELIM
#               (bwd dW = A^T @ dGq via cuBLAS OP_T — no materialized A^T pass)
#   (default) : BENCH-9 un-fused baseline (separate k_transpose) — head-to-head control
# Lanes: TF32 (-DUSE_TF32), BF16 (-DUSE_TF32 -DLANE_BF16), FP64 (-DBENCH_PREC=2).
# GEMM = cuBLAS in every lane (the winning lane).
#
# Cells: D=4096/B=8 (target) + D=2048/B=8 (regression). ratio = flame_ms / torch_compile_ms.
# GATE g5: determinism max|delta(W')|=0 + rel-RMS(fused W' vs un-fused NAIVE ref) <=1e-2.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="${T:-256}"; ITERS="${ITERS:-50}"
DSWEEP="${DSWEEP:-2048 4096}"
BSWEEP="${BSWEEP:-8}"
ARCH="${ARCH:-sm_90a}"

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE"
SRC="$HERE/flame_bench_step_fused.cu"

OUT="${OUT:-/tmp/bench10_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "############ HEXA-BENCH BENCH-10  T=$T iters=$ITERS  arch=$ARCH  D={$DSWEEP} B={$BSWEEP} ############"
log "==== nvidia-smi ===="; nvidia-smi | tee -a "$OUT"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

log "==== build flame fused+unfused lanes ===="
# TF32
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32             -o /tmp/flame_tf32_unfused "$SRC" -lcublas || { log "BUILD FAIL tf32-unfused"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DFUSED     -o /tmp/flame_tf32_fused   "$SRC" -lcublas || { log "BUILD FAIL tf32-fused"; exit 1; }
# BF16
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DLANE_BF16          -o /tmp/flame_bf16_unfused "$SRC" -lcublas || { log "BUILD FAIL bf16-unfused"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DLANE_BF16 -DFUSED  -o /tmp/flame_bf16_fused   "$SRC" -lcublas || { log "BUILD FAIL bf16-fused"; exit 1; }
# FP64
nvcc $NVCC_FLAGS -DBENCH_PREC=2             -o /tmp/flame_fp64_unfused "$SRC" -lcublas || { log "BUILD FAIL fp64-unfused"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=2 -DFUSED     -o /tmp/flame_fp64_fused   "$SRC" -lcublas || { log "BUILD FAIL fp64-fused"; exit 1; }
log "build OK"

for D in $DSWEEP; do
  for B in $BSWEEP; do
    log ""
    log "================= D=$D  B=$B  T=$T ================="
    log "--- flame TF32 UN-FUSED (BENCH-9 baseline) ---"; /tmp/flame_tf32_unfused "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame TF32 FUSED                       ---"; /tmp/flame_tf32_fused   "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame BF16 UN-FUSED (BENCH-9 baseline) ---"; /tmp/flame_bf16_unfused "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame BF16 FUSED                       ---"; /tmp/flame_bf16_fused   "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame FP64 UN-FUSED (BENCH-9 baseline) ---"; /tmp/flame_fp64_unfused "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame FP64 FUSED                       ---"; /tmp/flame_fp64_fused   "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"

    for dt in tf32 bf16 fp64; do
      for md in eager compile; do
        log "--- torch $dt $md D=$D B=$B ---"
        python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype "$dt" --mode "$md" --iters "$ITERS" 2>&1 | tee -a "$OUT"
      done
    done
  done
done

log ""
log "############ BENCH-10 DONE — raw at $OUT ############"
