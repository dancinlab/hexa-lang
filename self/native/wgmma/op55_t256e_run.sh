#!/usr/bin/env bash
# OP-55 on-pod driver: build wgmma_tf32_b14.cu (sm_90a) and run the MODE 8 baseline + the NEW
# MODE 10 (gemm_og17_b14_t256e, the 2-CTA/SM-preserving 128x256 single-pass tile) @D=4096 + D=2048.
# Captures -Xptxas -v (regs/spill/CTA-per-SM) VERBATIM + the bit-exact gate (rel_rms 0) + sweep.
set -u
SRC=wgmma_tf32_b14.cu
BIN=b14
echo "=================== BUILD (nvcc -O3 -arch=sm_90a, -Xptxas -v) ==================="
nvcc -O3 -arch=sm_90a -Xptxas -v -lcublas -lcuda "$SRC" -o "$BIN" 2>&1
echo "BUILD-RC=$?"
echo
echo "=================== ptxas -v: MODE 8 (gemm_og17_b14) vs MODE 10 (t256e) ==================="
nvcc -O3 -arch=sm_90a -Xptxas -v -lcublas -lcuda "$SRC" -o "$BIN" 2>&1 | \
  grep -E "gemm_og17_b14'|gemm_og17_b14_t256e|registers|spill|stack frame" || true
echo
for D in 4096 2048; do
  echo "########################### D=$D ###########################"
  echo "--- MODE 8 baseline (apples), 3 reps ---"
  for rep in 1 2 3; do ./$BIN $D 8 3 1; done
  for rep in 1 2 3; do ./$BIN $D 8 3 2; done
  echo "--- MODE 10 t256e (NEW 128x256, 2-CTA/SM-preserving), occupancy then 3 reps ---"
  for nst in 3 4; do for pdep in 1 2; do
    for rep in 1 2 3; do ./$BIN $D 10 $nst $pdep; done
  done; done
done
echo "=================== DONE ==================="
