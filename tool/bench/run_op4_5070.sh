#!/usr/bin/env bash
# run_op4_5070.sh — HEXA-0POD OP-4 driver: flame fused training step vs torch on the
# FREE consumer GPU aiden (RTX 5070, sm_120). Maps the consumer-card win/lose frontier
# across D={768,1536,2048} x B={1,8} x dtype={FP64,TF32,BF16}.
#
# flame lane = the cuBLAS-backed FUSED step (flame_bench_step_fused.cu -DFUSED — the
# speed lane: fused valley LN+gelu+copy + single-launch AdamW + transpose-elim, GEMM=cuBLAS).
# torch lane = torch_bench_step.py eager + compile (inductor), matched dtype/shape.
#
# Per cell records: flame ms/step, torch-eager ms/step, torch-compile ms/step, ratio
# (flame_ms / torch_compile_ms), WIN/LOSE (flame WINS if flame_ms < torch_compile_ms).
# OOM cells reported (12GB cap), NOT counted as a loss.
#
# GATE g5: per-cell determinism max|delta(W')|=0 + rel-RMS(fused vs unfused-naive ref) <=1e-2.
#
# Run ON aiden via: sidecar pool on aiden "bash - < run_op4_5070.sh"  (self-contained; it
# copies itself + the two bench sources up). Driver is invoked from the repo on aiden after
# the sources are synced.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="${T:-256}"; ITERS="${ITERS:-50}"
DSWEEP="${DSWEEP:-768 1536 2048}"
BSWEEP="${BSWEEP:-1 8}"
ARCH="${ARCH:-sm_120}"

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE"
SRC="$HERE/flame_bench_step_fused.cu"

OUT="${OUT:-/tmp/op4_5070_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "############ HEXA-0POD OP-4 — flame fused step vs torch on RTX 5070 (sm_120) ############"
log "T=$T iters=$ITERS arch=$ARCH D={$DSWEEP} B={$BSWEEP} dtype={FP64,TF32,BF16}"
log "==== nvidia-smi ===="; nvidia-smi | tee -a "$OUT"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

log "==== build flame FUSED lanes (the speed lane) ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DFUSED            -o /tmp/flame_tf32_fused "$SRC" -lcublas || { log "BUILD FAIL tf32-fused"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DLANE_BF16 -DFUSED -o /tmp/flame_bf16_fused "$SRC" -lcublas || { log "BUILD FAIL bf16-fused"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=2 -DFUSED                       -o /tmp/flame_fp64_fused "$SRC" -lcublas || { log "BUILD FAIL fp64-fused"; exit 1; }
log "build OK"

# Exclusivity guard for the timed loops: shared GPU (parallel OP-2/OP-3 agents).
wait_gpu(){
  for try in $(seq 1 30); do
    read u m < <(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits | head -1 | tr -d ',')
    if [ "${u:-100}" -lt 5 ] && [ "${m:-99999}" -lt 800 ]; then return 0; fi
    log "  [wait_gpu] util=${u}% mem=${m}MiB busy — sleep 20s (try $try/30)"; sleep 20
  done
  log "  [wait_gpu] WARN GPU still busy after 30 tries — proceeding (best-effort)"; return 0
}

for D in $DSWEEP; do
  for B in $BSWEEP; do
    log ""
    log "================= D=$D  B=$B  T=$T ================="
    wait_gpu
    log "--- flame TF32 FUSED ---"; /tmp/flame_tf32_fused "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    wait_gpu
    log "--- flame BF16 FUSED ---"; /tmp/flame_bf16_fused "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    wait_gpu
    log "--- flame FP64 FUSED ---"; /tmp/flame_fp64_fused "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    for dt in tf32 bf16 fp64; do
      for md in eager compile; do
        wait_gpu
        log "--- torch $dt $md D=$D B=$B ---"
        python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype "$dt" --mode "$md" --iters "$ITERS" 2>&1 | tee -a "$OUT"
      done
    done
  done
done

log ""
log "############ OP-4 DONE — raw at $OUT ############"
