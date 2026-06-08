#!/usr/bin/env bash
# run_bench9.sh — HEXA-BENCH BENCH-9 driver (run ON a real H100, sm_90a Hopper, vast).
#
# Closes the LAST flame-cuBLAS losing cell from BENCH-7: D=4096/B=8, where flame's
# plain cublasGemmEx (CUBLAS_GEMM_DEFAULT_TENSOR_OP) lost to torch.compile/inductor by
# TF32 1.27x · BF16 2.00x. inductor wins there by (a) GEMM algo-selection and (b)
# epilogue fusion. We attack with cuBLASLt (GEMM_BACKEND=6; backend 5 is BENCH-8's FP64):
#   - GEMM_BACKEND=6            : cublasLtMatmulAlgoGetHeuristic AUTOTUNE (TF32 lane)
#   - GEMM_BACKEND=6 -DLT_BF16 : same, BF16 lane (cast to 16BF, COMPUTE_32F)
#   - HEXA_LT_EPILOGUE=gelu     : fuse a GELU epilogue into the fwd GEMM (capability
#                                 probe; see verdict for math-applicability to THIS step)
#
# Baselines re-run on the SAME pod for a clean head-to-head:
#   - GEMM_BACKEND=1            : plain cublasGemmEx TF32  (BENCH-7 loser)
#   - GEMM_BACKEND=4           : plain cublasGemmEx BF16  (BENCH-7 loser)
#   - torch eager + compile, matched dtype
#
# Focus cells: D=4096/B=8 (the target) + D=2048/B=8 (regression check) + D=4096/B=1
# (crossover sanity). ratio = flame_ms / torch_compile_ms. GATE g5: determinism
# max|delta(W')|=0 per cell + rel-RMS(W' vs naive ref) <= 1e-2.
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

OUT="${OUT:-/tmp/bench9_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "############ HEXA-BENCH BENCH-9  T=$T iters=$ITERS  arch=$ARCH  D={$DSWEEP} B={$BSWEEP} ############"
log "==== nvidia-smi ===="; nvidia-smi | tee -a "$OUT"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

log "==== build flame lanes ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=1            -o /tmp/flame_cublas_tf32 "$HERE/flame_bench_step_og.cu" -lcublas          || { log "BUILD FAIL cublas-tf32"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=4            -o /tmp/flame_cublas_bf16 "$HERE/flame_bench_step_og.cu" -lcublas          || { log "BUILD FAIL cublas-bf16"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=6            -o /tmp/flame_lt_tf32     "$HERE/flame_bench_step_og.cu" -lcublas -lcublasLt || { log "BUILD FAIL lt-tf32"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=6 -DLT_BF16  -o /tmp/flame_lt_bf16     "$HERE/flame_bench_step_og.cu" -lcublas -lcublasLt || { log "BUILD FAIL lt-bf16"; exit 1; }
log "build OK"

for D in $DSWEEP; do
  for B in $BSWEEP; do
    log ""
    log "================= D=$D  B=$B  T=$T ================="
    log "--- flame TF32 plain-cuBLAS      D=$D B=$B ---";              /tmp/flame_cublas_tf32 "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame TF32 cuBLASLt-autotune D=$D B=$B ---";              /tmp/flame_lt_tf32     "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame TF32 cuBLASLt+gelu-epi D=$D B=$B ---"; HEXA_LT_EPILOGUE=gelu /tmp/flame_lt_tf32 "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame BF16 plain-cuBLAS      D=$D B=$B ---";              /tmp/flame_cublas_bf16 "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame BF16 cuBLASLt-autotune D=$D B=$B ---";              /tmp/flame_lt_bf16     "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame BF16 cuBLASLt+gelu-epi D=$D B=$B ---"; HEXA_LT_EPILOGUE=gelu /tmp/flame_lt_bf16 "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"

    for dt in tf32 bf16; do
      for md in eager compile; do
        log "--- torch $dt $md D=$D B=$B ---"
        python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype "$dt" --mode "$md" --iters "$ITERS" 2>&1 | tee -a "$OUT"
      done
    done
  done
done

# crossover sanity: D=4096 B=1 (BENCH-7 had flame-cuBLAS winning here)
log ""
log "================= SPOT D=4096 B=1 (crossover sanity) ================="
log "--- flame TF32 cuBLASLt-autotune ---"; /tmp/flame_lt_tf32 4096 "$T" 1 "$ITERS" 2>&1 | tee -a "$OUT"
log "--- flame BF16 cuBLASLt-autotune ---"; /tmp/flame_lt_bf16 4096 "$T" 1 "$ITERS" 2>&1 | tee -a "$OUT"
for dt in tf32 bf16; do
  log "--- torch $dt compile D=4096 B=1 ---"
  python3 "$HERE/torch_bench_step.py" --D 4096 --T "$T" --B 1 --dtype "$dt" --mode compile --iters "$ITERS" 2>&1 | tee -a "$OUT"
done

log ""
log "############ BENCH-9 DONE — raw at $OUT ############"
