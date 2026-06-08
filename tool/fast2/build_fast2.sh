#!/usr/bin/env bash
# build_fast2.sh — HEXA-FLAME-FAST FAST-2 fused whole-step megakernel.
# Compiles the TF32 and BF16 variants (-rdc=true for cooperative grid.sync),
# captures ptxas -v register/smem budget, runs each on the GPU.
# env HEXA_FLAME_FAST gates the fast lane (opt-in; FP64 byte-exact stays default).
set -u
SRC="$(dirname "$0")/fast2_fused_step.cu"
ARCH="${ARCH:-sm_90}"
D="${1:-1536}"; T="${2:-512}"; ITERS="${3:-50}"
echo "=== HEXA_FLAME_FAST=${HEXA_FLAME_FAST:-1} (opt-in fast lane) ==="
echo "=== ptxas per-kernel register/smem budget (fused_step) ==="
for P in 1 2; do
  NM=$([ "$P" = 1 ] && echo tf32 || echo bf16)
  nvcc -arch=$ARCH -rdc=true -O3 -DFUSE_PREC=$P -Xptxas -v \
       -o /tmp/fast2_$NM "$SRC" 2> /tmp/fast2_${NM}_ptxas.txt
  if [ $? -ne 0 ]; then echo "BUILD FAIL ($NM):"; cat /tmp/fast2_${NM}_ptxas.txt; exit 1; fi
  grep -E "fused_step|registers|smem" /tmp/fast2_${NM}_ptxas.txt | grep -iE "fused_step|Used .* registers" | sed "s/^/  [$NM] /"
done
echo "============================================================"
for P in 1 2; do
  NM=$([ "$P" = 1 ] && echo tf32 || echo bf16)
  echo "### RUN $NM ###"
  /tmp/fast2_$NM "$D" "$T" "$ITERS"
  echo
done
