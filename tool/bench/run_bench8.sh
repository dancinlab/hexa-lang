#!/usr/bin/env bash
# run_bench8.sh — HEXA-BENCH BENCH-8 driver (run ON a real H100, sm_90a Hopper, vast).
#
# Closes BENCH-7's FP64 large-D losses toward the goal "모두 이길때까지" (beat torch in
# EVERY regime). BENCH-7 found flame LOSES 7 FP64 cells at D>=1536 (up to 9.57x @D=4096/B=8)
# — but ONLY because flame's FP64 lane used the NAIVE O(D^3) k_gemm, not cuBLAS-FP64. torch's
# FP64 also has NO tensor-core path (both use FP64 CUDA cores), so the loss is flame's naive
# GEMM being slow, NOT a torch FP64 advantage. BENCH-8 adds a cuBLAS-FP64 flame lane
# (GEMM_BACKEND=5, cublasGemmEx CUBLAS_COMPUTE_64F) and re-measures.
#
#   shapes : D in {768,1536,2048,4096}  (T=256)
#   batch  : B in {1,8}
#   lanes  : FP64-cuBLAS  (flame cuBLAS-FP64 + no-Python glue  vs torch fp64)  [BENCH-8 NEW]
#            FP64-naive    (flame naive O(D^3) k_gemm           vs torch fp64)  [BENCH-7 baseline,
#                          built so the verdict has cuBLAS-vs-naive-vs-torch all on ONE pod]
#   torch  : fp64 eager + compile, matched dtype/shape. ratio = flame_ms / torch_compile_ms.
#
# GATE g5: run-to-run determinism max|delta(W')|=0 per cell (MUST). rel-RMS(cuBLAS vs naive
# FP64 ref) ~1e-14 associativity (different accumulation order) — reported, NOT gated to bit-0.
# Emits all [CFG]/[DETERMINISM]/[GATE]/[RESULT] lines verbatim for the verdict.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="${T:-256}"; ITERS="${ITERS:-50}"
DSWEEP="${DSWEEP:-768 1536 2048 4096}"
BSWEEP="${BSWEEP:-1 8}"
ARCH="${ARCH:-sm_90a}"     # H100 = Hopper sm_90a

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE"

OUT="${OUT:-/tmp/bench8_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "############ HEXA-BENCH BENCH-8 (cuBLAS-FP64)  T=$T iters=$ITERS  arch=$ARCH  D={$DSWEEP} B={$BSWEEP} ############"
log "==== nvidia-smi ===="; nvidia-smi | tee -a "$OUT"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

log "==== build flame FP64 lanes ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=2 -DGEMM_BACKEND=5 -o /tmp/flame_fp64_cublas "$HERE/flame_bench_step_og.cu" -lcublas || { log "BUILD FAIL fp64-cublas"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=2 -DGEMM_BACKEND=0 -o /tmp/flame_fp64_naive  "$HERE/flame_bench_step_og.cu"          || { log "BUILD FAIL fp64-naive"; exit 1; }
log "build OK (fp64 cuBLAS + naive)"

for D in $DSWEEP; do
  for B in $BSWEEP; do
    log ""
    log "================= D=$D  B=$B  T=$T ================="
    log "--- flame FP64-cuBLAS  D=$D B=$B ---";  /tmp/flame_fp64_cublas "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame FP64-naive   D=$D B=$B ---";  /tmp/flame_fp64_naive  "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    for md in eager compile; do
      log "--- torch fp64 $md D=$D B=$B ---"
      python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype fp64 --mode "$md" --iters "$ITERS" 2>&1 | tee -a "$OUT"
    done
  done
done

log ""
log "############ BENCH-8 DONE — raw at $OUT ############"
