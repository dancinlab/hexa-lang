#!/usr/bin/env bash
# w15_run.sh — W15 on-pod driver: DESCRIPTOR-DIRECT wgmma own-GEMM (research #2854).
# Feeds wgmma straight from the SWIZZLE_128B-TMA tile via the corrected GMMA descriptor
# (layout_type_=1, SBO=1024B, base_offset_=phase) — DELETES the W10 32KB software decode band.
#
# GATE DISCIPLINE (g5, MANDATORY ORDER):
#   1) MODE 0 single-tile DESCRIPTOR-DIRECT differential (the W11 re-run) -> rel_rms 0 GATE.
#      If 1.392 still, ITERATE the 3 fields (swm/sbo/boff) against research values, INLINE.
#   2) ONLY after single-tile rel_rms 0: full GEMM MODE 4 bit-exact gate, THEN perf.
# cuBLAS-TF32 = ROOFLINE. NO superiority claim. All output INLINE (vast-reclaim storm).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD w15 ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/w15 wgmma_tf32_w15.cu 2>&1; then
  echo "W15-BUILD: OK"
else
  echo "W15-BUILD: FAIL"; exit 1
fi
echo

echo "================= VALIDATION ORACLE — MODE 2 raw swizzle dump ================="
/tmp/w15 2048 2 2>&1 | head -24
echo

echo "================= GATE — MODE 0 DESCRIPTOR-DIRECT single-tile (research default) ================="
# research #2854: layout_type_=1 (swm), SBO=1024, base_offset_ phase. Default args in-binary.
/tmp/w15 2048 0; G0=$?; echo "exit=$G0"
echo

if [ "$G0" -ne 0 ]; then
  echo "================= ITERATE the 3 fields (swm BUG1 / sbo BUG2 / boff BUG3), INLINE ================="
  # args: S MODE LBO SBO BOFF SWM
  for SWM in 1 2 3; do
   for SBO in 1024 512 256 128 2048; do
    for BOFF in 0 1 2 3 4 5 6 7; do
     for LBO in 128 16 256 1024; do
      OUT=$(/tmp/w15 2048 0 $LBO $SBO $BOFF $SWM 2>&1)
      echo "$OUT" | grep -qE "rel_rms=0.000e\+00|PASS" && { echo "HIT: $OUT"; }
      RR=$(echo "$OUT" | grep -oE "rel_rms=[0-9.e+-]+" | head -1)
      echo "swm=$SWM sbo=$SBO boff=$BOFF lbo=$LBO -> $RR"
     done
    done
   done
  done
  echo "ITERATE-DONE. If no rel_rms 0 above, the residual descriptor mismatch is reported (g5)."
fi
echo

# Re-test the default GATE after iterate to capture the BEST config exit.
/tmp/w15 2048 0 >/tmp/g0.out 2>&1; G0=$?
BEST=$(cat /tmp/g0.out)
echo "GATE result: $BEST (exit=$G0)"
if [ "$G0" -ne 0 ]; then
  echo "W15 SINGLE-TILE GATE FAILED — descriptor-direct still mismatches."
  echo "STOP per g5: no full GEMM, no perf number. W10 70.7 frontier KEPT (no regression)."
  echo "Report the residual rel_rms + the swept fields above (research may have a gap)."
  exit 2
fi
echo "W15 SINGLE-TILE GATE PASSED (rel_rms 0) — descriptor VIEWS the swizzled tile in place."
echo

echo "================= MODE 4 FULL GEMM — bit-exact gate + occupancy + perf ================="
for S in 2048 4096 8192; do
  for NST in 3 4 2; do
    echo "--- S=$S NST=$NST ---"
    /tmp/w15 $S 4 $NST 2>&1
  done
done
echo
echo "================= APPLES — W10 frontier same-pod baseline (build + MODE4) ================="
if [ -f wgmma_tf32_w10.cu ]; then
  if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/w10 wgmma_tf32_w10.cu 2>&1; then
    echo "W10-BUILD: OK"
    /tmp/w10 4096 4 2 2>&1   # W10 MODE4 NST=2 @4096 = the 70.7 frontier
  else
    echo "W10-BUILD: FAIL (apples skipped)"
  fi
fi
echo "================= W15 DONE ================="
