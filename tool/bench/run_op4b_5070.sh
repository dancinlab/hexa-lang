#!/usr/bin/env bash
# run_op4b_5070.sh — HEXA-0POD OP-4b driver: CUDA-graph-captured flame FUSED step on the
# FREE consumer GPU aiden (RTX 5070, sm_120). Attacks the small-B launch-overhead floor
# OP-4 found (B=1: TF32 1.78x->8.96x, BF16 up to 14.66x @D=2048 vs torch.compile) by
# replaying the whole fused per-step DAG as ONE cudaGraphLaunch.
#
# For each cell it builds flame_bench_step_graph_fused.cu and reports:
#   - eager fused ms/step (== OP-4's flame_ms lane, un-captured)
#   - graph-captured fused ms/step
#   - graph/eager speedup (did graph cut the floor?)
#   - GATE g5: max|delta(W')| graph-vs-eager == 0 + run-to-run determinism == 0
# The OP-4 verdict supplies the torch.compile baseline per cell (recomputing the new
# graph/torch_compile ratio is done in the verdict; this driver produces the flame side).
#
# Focus: the worst SMALL-B cells. B=1, D={768,1536,2048}, dtype={TF32,BF16}. FP64 B=1
# included for completeness (OP-4 found it near-parity/compute-bound — graph won't move it).
#
# Run ON aiden via: sidecar pool on aiden "bash - < run_op4b_5070.sh".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="${T:-256}"; ITERS="${ITERS:-50}"
DSWEEP="${DSWEEP:-768 1536 2048}"
BSWEEP="${BSWEEP:-1}"
ARCH="${ARCH:-sm_120}"

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE"
SRC="$HERE/flame_bench_step_graph_fused.cu"

OUT="${OUT:-/tmp/op4b_5070_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "######## HEXA-0POD OP-4b — CUDA-graph-captured flame FUSED step on RTX 5070 (sm_120) ########"
log "T=$T iters=$ITERS arch=$ARCH D={$DSWEEP} B={$BSWEEP} dtype={TF32,BF16,FP64}"
log "==== nvidia-smi ===="; nvidia-smi | tee -a "$OUT"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

log "==== build graph-fused lanes ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32             -o /tmp/flame_tf32_gf "$SRC" -lcublas || { log "BUILD FAIL tf32-gf"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DLANE_BF16 -o /tmp/flame_bf16_gf "$SRC" -lcublas || { log "BUILD FAIL bf16-gf"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=2                        -o /tmp/flame_fp64_gf "$SRC" -lcublas || { log "BUILD FAIL fp64-gf"; exit 1; }
log "build OK"

# Exclusivity guard for timed loops: shared GPU (parallel OP-1b agent may hit aiden).
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
    log "--- flame TF32 GRAPH-FUSED ---"; /tmp/flame_tf32_gf "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    wait_gpu
    log "--- flame BF16 GRAPH-FUSED ---"; /tmp/flame_bf16_gf "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    wait_gpu
    log "--- flame FP64 GRAPH-FUSED ---"; /tmp/flame_fp64_gf "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
  done
done

log ""
log "######## OP-4b DONE — raw at $OUT ########"
