#!/usr/bin/env bash
# run_op25_drift_5070.sh — HEXA-0POD OP-25 BF16 N-step trajectory drift vs FP64 on aiden 5070.
# Builds flame_traj_drift_bf16_op25.cu (default + pedantic) and runs a short N-step drift check
# (does BF16 loss still track FP64, or does the e-3 per-step error accumulate/peel?).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="${T:-256}"; NSTEPS="${NSTEPS:-50}"
DSWEEP="${DSWEEP:-768}"
BSWEEP="${BSWEEP:-1}"
ARCH="${ARCH:-sm_120}"

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE"
SRC="$HERE/flame_traj_drift_bf16_op25.cu"

OUT="${OUT:-/tmp/op25_drift_5070_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "############ HEXA-0POD OP-25 DRIFT — BF16 vs FP64 N-step trajectory on RTX 5070 ############"
log "T=$T Nsteps=$NSTEPS arch=$ARCH D={$DSWEEP} B={$BSWEEP}"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

log "==== build DRIFT default + pedantic ===="
nvcc $NVCC_FLAGS            -o /tmp/flame_traj_op25_default  "$SRC" -lcublas || { log "BUILD FAIL default"; exit 1; }
nvcc $NVCC_FLAGS -DPEDANTIC -o /tmp/flame_traj_op25_pedantic "$SRC" -lcublas || { log "BUILD FAIL pedantic"; exit 1; }
log "build OK"

wait_gpu(){
  local s=30
  for try in $(seq 1 8); do
    read u m < <(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits | head -1 | tr -d ',')
    if [ "${u:-100}" -lt 5 ] && [ "${m:-99999}" -lt 800 ]; then return 0; fi
    log "  [wait_gpu] util=${u}% mem=${m}MiB busy — sleep ${s}s (try $try/8)"; sleep "$s"
    s=$(( s*2 )); [ "$s" -gt 480 ] && s=480
  done
  log "  [wait_gpu] WARN GPU still busy after 8 tries — proceeding"; return 0
}

for VARIANT in default pedantic; do
  BIN="/tmp/flame_traj_op25_$VARIANT"
  for D in $DSWEEP; do
    for B in $BSWEEP; do
      log ""
      log "================= DRIFT $VARIANT  D=$D  B=$B  T=$T  Nsteps=$NSTEPS ================="
      wait_gpu
      "$BIN" "$D" "$T" "$B" "$NSTEPS" 2>&1 | tee -a "$OUT"
    done
  done
done

log ""
log "############ OP-25 DRIFT DONE — raw at $OUT ############"
log "==== RESULT lines ===="; grep '\[RESULT\]' "$OUT" | tee -a "$OUT"
