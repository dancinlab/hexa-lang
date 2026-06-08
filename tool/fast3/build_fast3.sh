#!/usr/bin/env bash
# build_fast3.sh — HEXA-FLAME-FAST FAST-3 batch sweep (the decisive 3-combo test).
# Compiles TF32 and BF16 variants of the FAST-2 fused megakernel wrapped in a B sweep,
# captures ptxas budget, runs each. env HEXA_FLAME_FAST gates the opt-in fast lane.
set -u
SRC="$(dirname "$0")/fast3_batch_sweep.cu"
ARCH="${ARCH:-sm_90}"
D="${1:-1536}"; T="${2:-512}"; ITERS="${3:-50}"
echo "=== HEXA_FLAME_FAST=${HEXA_FLAME_FAST:-1} (opt-in fast lane) ==="
echo "=== ptxas per-kernel register/smem budget (fused_step) ==="
for P in 1 2; do
  NM=$([ "$P" = 1 ] && echo tf32 || echo bf16)
  nvcc -arch=$ARCH -rdc=true -O3 -DFUSE_PREC=$P -Xptxas -v \
       -o /tmp/fast3_$NM "$SRC" 2> /tmp/fast3_${NM}_ptxas.txt
  if [ $? -ne 0 ]; then echo "BUILD FAIL ($NM):"; cat /tmp/fast3_${NM}_ptxas.txt; exit 1; fi
  grep -iE "fused_step|Used .* registers" /tmp/fast3_${NM}_ptxas.txt | sed "s/^/  [$NM] /"
done
echo "============================================================"
for P in 1 2; do
  NM=$([ "$P" = 1 ] && echo tf32 || echo bf16)
  echo "### RUN $NM ###"
  /tmp/fast3_$NM "$D" "$T" "$ITERS"
  echo
done
