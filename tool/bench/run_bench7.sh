#!/usr/bin/env bash
# run_bench7.sh — HEXA-BENCH BENCH-7 driver (run ON a real H100, sm_90a Hopper, vast).
#
# FULL-REGIME frontier map toward the user goal "모두 이길때까지" (beat torch in EVERY
# regime). Sweeps shape D x batch x dtype/lane and records flame vs torch ms/step +
# WIN/LOSE per cell, so we can pin EXACTLY which cells flame still loses + the crossover
# D where each lane flips win->lose.
#
#   shapes : D in {768,1536,2048,4096}  (T=256; the D->D GEMM grows ~D^2 => glue-bound -> GEMM-bound)
#   batch  : B in {1,8}                 (small + filled)
#   lanes  : FP64 (flame naive vs torch fp64 — flame's structural win, no TC FP64 in torch)
#            TF32-cuBLAS  (flame calls cuBLAS-TF32 + no-Python glue  vs torch tf32)
#            TF32-OG10    (flame OWN-GEMM W10 wgmma sm_90a           vs torch tf32)  [6.09x off cuBLAS]
#            BF16-cuBLAS  (flame cuBLAS-BF16 + no-Python glue        vs torch bf16)
#   torch  : eager + compile, matched dtype/shape. ratio = flame_ms / torch_compile_ms.
#
# KEY SEPARATION: does the flame-cuBLAS lane (same GEMM as torch + no-Python glue) WIN at
# ALL D — incl large GEMM-bound D — or does inductor's GEMM algo-selection retake the lead?
# If flame-cuBLAS wins everywhere => 'beat all' is ACHIEVABLE (own-GEMM is a no-LLVM-purity
# axis, not a speed loss). flame-OWN-GEMM is EXPECTED to lose at large GEMM-bound D.
#
# Emits all [CFG]/[DETERMINISM]/[GATE]/[RESULT] lines verbatim for the verdict; a tiny awk
# at the end folds them into the WIN/LOSE matrix. GATE g5: determinism max|delta|=0 per cell.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="${T:-256}"; ITERS="${ITERS:-50}"
DSWEEP="${DSWEEP:-768 1536 2048 4096}"
BSWEEP="${BSWEEP:-1 8}"
ARCH="${ARCH:-sm_90a}"     # H100 = Hopper sm_90a (wgmma.mma_async requires the 'a' variant)

CUDA_ROOT="${CUDA_ROOT:-/usr/local/cuda}"
export PATH="$CUDA_ROOT/bin:$CUDA_ROOT/nvvm/bin:$PATH"
CUINC="$CUDA_ROOT/targets/x86_64-linux/include"
CULIB="$CUDA_ROOT/targets/x86_64-linux/lib"
NVCC_FLAGS="-arch=$ARCH -O3 -I$CUINC -L$CULIB -I$HERE -I$HERE/wgmma"

OUT="${OUT:-/tmp/bench7_raw.log}"
: > "$OUT"
log(){ echo "$@" | tee -a "$OUT"; }

log "############ HEXA-BENCH BENCH-7  T=$T iters=$ITERS  arch=$ARCH  D={$DSWEEP} B={$BSWEEP} ############"
log "==== nvidia-smi ===="; nvidia-smi | tee -a "$OUT"
log "==== nvcc ===="; nvcc --version | tail -2 | tee -a "$OUT"

# ---------- build the 5 binaries (4 lanes; TF32 needs naive-ref baked in already) ----------
log "==== OG10 (W10 TF32-wgmma) sm_90a ISA CHECK ===="
if nvcc $NVCC_FLAGS -DW10_NO_MAIN -lcuda -lcublas -c -o /tmp/og10_isa.o "$HERE/og10_gemm_wrap.cu" 2>/tmp/og10_isa.err; then
  log "OG10 sm_90a COMPILE: OK"; OG10_OK=1
else log "OG10 sm_90a COMPILE: FAIL"; head -8 /tmp/og10_isa.err | tee -a "$OUT"; OG10_OK=0; fi

log "==== build flame lanes ===="
nvcc $NVCC_FLAGS -DBENCH_PREC=2 -DGEMM_BACKEND=0 -o /tmp/flame_fp64        "$HERE/flame_bench_step_og.cu"                          || { log "BUILD FAIL fp64"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=1 -o /tmp/flame_cublas_tf32 "$HERE/flame_bench_step_og.cu" -lcublas      || { log "BUILD FAIL cublas-tf32"; exit 1; }
nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=4 -o /tmp/flame_cublas_bf16 "$HERE/flame_bench_step_og.cu" -lcublas      || { log "BUILD FAIL cublas-bf16"; exit 1; }
if [ "$OG10_OK" = "1" ]; then
  nvcc $NVCC_FLAGS -DBENCH_PREC=1 -DUSE_TF32 -DGEMM_BACKEND=2 -o /tmp/flame_og10_tf32 "$HERE/flame_bench_step_og.cu" "$HERE/og10_gemm_wrap.cu" -lcuda -lcublas \
     && log "build OK (OG10)" || { log "BUILD FAIL og10"; OG10_OK=0; }
fi

# ---------- the sweep ----------
for D in $DSWEEP; do
  for B in $BSWEEP; do
    log ""
    log "================= D=$D  B=$B  T=$T ================="

    log "--- flame FP64 (naive) D=$D B=$B ---";           /tmp/flame_fp64        "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    log "--- flame TF32-cuBLAS  D=$D B=$B ---";            /tmp/flame_cublas_tf32 "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    if [ "$OG10_OK" = "1" ]; then
      log "--- flame TF32-OG10    D=$D B=$B ---";          /tmp/flame_og10_tf32   "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"
    else log "--- flame TF32-OG10 SKIPPED (ISA) ---"; fi
    log "--- flame BF16-cuBLAS  D=$D B=$B ---";            /tmp/flame_cublas_bf16 "$D" "$T" "$B" "$ITERS" 2>&1 | tee -a "$OUT"

    for dt in fp64 tf32 bf16; do
      for md in eager compile; do
        log "--- torch $dt $md D=$D B=$B ---"
        python3 "$HERE/torch_bench_step.py" --D "$D" --T "$T" --B "$B" --dtype "$dt" --mode "$md" --iters "$ITERS" 2>&1 | tee -a "$OUT"
      done
    done
  done
done

log ""
log "############ BENCH-7 DONE — raw at $OUT ############"
