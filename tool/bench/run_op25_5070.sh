#!/usr/bin/env bash
# run_op25_5070.sh — HEXA-0POD OP-25 driver: deterministic BF16 fast-mode probe on the FREE
# consumer GPU aiden (RTX 5070, sm_120). ZERO vast.
#
# Builds flame_bench_step_bf16fast.cu in two cublas-math variants:
#   default  : CUBLAS_DEFAULT_MATH on the BF16 handle (heuristic BF16 tensor-op)
#   pedantic : -DPEDANTIC -> CUBLAS_PEDANTIC_MATH (deterministic, no split-K heuristics)
# and runs both across D={768,1536} x B={1,8}. Each run reports, in ONE process (3 lanes):
#   GATE-A  BF16 self-byte-eq run-to-run (max|delta(W')|==0)
#   GATE-B  rel-RMS(BF16 W' vs FP64 W') <= 1e-2 (W14 cross-precision tolerance)
#   REF     rel-RMS(TF32 W' vs FP64 W') (so the BF16-vs-TF32 accuracy gap is reported)
#   SPEED   BF16/TF32/FP64 ms/step, FP64/BF16 + TF32/BF16 ratios (is BF16 faster than TF32?)
#
# Run ON aiden via: sidecar pool on aiden "bash - < run_op25_5070.sh"
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="${T:-256}"; ITERS="${ITERS:-50}"
DSWEEP="${DSWEEP:-768 1536}"
BSWEEP="${BSWEEP:-1 8}"
ARCH="${ARCH:-sm_120}"

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE"
SRC="$HERE/flame_bench_step_bf16fast.cu"

OUT="${OUT:-/tmp/op25_5070_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "############ HEXA-0POD OP-25 — deterministic BF16 fast-mode on RTX 5070 (sm_120) ############"
log "T=$T iters=$ITERS arch=$ARCH D={$DSWEEP} B={$BSWEEP}  BF16 vs TF32 vs FP64 in-process"
log "==== nvidia-smi ===="; nvidia-smi | tee -a "$OUT"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

log "==== build BF16-DEFAULT + BF16-PEDANTIC ===="
nvcc $NVCC_FLAGS            -o /tmp/flame_bf16_default  "$SRC" -lcublas || { log "BUILD FAIL default"; exit 1; }
nvcc $NVCC_FLAGS -DPEDANTIC -o /tmp/flame_bf16_pedantic "$SRC" -lcublas || { log "BUILD FAIL pedantic"; exit 1; }
log "build OK"

# Idle-guard with HARD BACKOFF (STORM): 30->480s doubling, 8 tries, before each timed run.
wait_gpu(){
  local s=30
  for try in $(seq 1 8); do
    read u m < <(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits | head -1 | tr -d ',')
    if [ "${u:-100}" -lt 5 ] && [ "${m:-99999}" -lt 800 ]; then return 0; fi
    log "  [wait_gpu] util=${u}% mem=${m}MiB busy — sleep ${s}s (try $try/8)"; sleep "$s"
    s=$(( s*2 )); [ "$s" -gt 480 ] && s=480
  done
  log "  [wait_gpu] WARN GPU still busy after 8 tries — proceeding (best-effort)"; return 0
}

for VARIANT in default pedantic; do
  BIN="/tmp/flame_bf16_$VARIANT"
  log ""
  log "######## VARIANT = $VARIANT ($BIN) ########"
  for D in $DSWEEP; do
    for B in $BSWEEP; do
      log ""
      log "================= $VARIANT  D=$D  B=$B  T=$T ================="
      wait_gpu
      "$BIN" "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    done
  done
done

log ""
log "############ OP-25 DONE — raw at $OUT ############"
log "==== RESULT lines ===="; grep '\[RESULT\]' "$OUT" | tee -a "$OUT"
