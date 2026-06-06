#!/usr/bin/env bash
# w13_run.sh — W13 on-pod driver for F-FUSION-SM90-WGMMA-W13 (deep async decode ring).
# RESUMES from W10 (gemm_w10, 70.7 TFLOP/s @4096, 2 CTA/SM, bit-exact). W13 RINGS the gmma
# decode scratch NSTG-deep so decode(N+1) overlaps wgmma(N) — software-pipelining the
# decode<->MMA dependency W12 (#2851) root-caused as the real wall (NOT occupancy).
#
# GATE DISCIPLINE (g5, MANDATORY ORDER — bit-exact BEFORE any perf number):
#   1) MODE 0 single-tile COMPOSED-DECODE probe -> rel_rms 0 GATE (the W10 decode law, kept).
#   2) MODE 1 single-tile COMPOSED wgmma probe  -> rel_rms 0 GATE.
#   3) MODE 6 FULL GEMM at each (NST,NSTG): the kernel itself gates rel_rms<=3e-3 BEFORE perf;
#      it also prints OCCUPANCY CTA/SM (cudaOccupancyMaxActiveBlocksPerMultiprocessor) so the
#      2-CTA/SM-held question is answered VERBATIM. cuBLAS-TF32 = ROOFLINE, no superiority claim.
# W10 FRONTIER TO BEAT (do NOT regress): own 70.7 TFLOP/s @S=4096, 6.09x off cuBLAS, 2 CTA/SM.
# All output INLINE (vast-reclaim storm). pod DESTROYED the second numbers captured (leak 0).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD w13 ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/w13 wgmma_tf32_w13.cu 2>&1; then
  echo "W13-BUILD: OK"
else
  echo "W13-BUILD: FAIL"; exit 1
fi
echo

echo "================= GATE 1 — MODE 0 composed-decode single-tile probe (rel_rms 0) ================="
/tmp/w13 2048 0; G0=$?; echo "exit=$G0"
echo
echo "================= GATE 2 — MODE 1 composed-wgmma single-tile probe (rel_rms 0) ================="
/tmp/w13 2048 1; G1=$?; echo "exit=$G1"
echo
if [ "$G0" -ne 0 ] || [ "$G1" -ne 0 ]; then
  echo "W13 SINGLE-TILE GATE FAILED (g0=$G0 g1=$G1) — STOP per g5: no full GEMM, no perf."
  echo "W10 70.7 frontier KEPT (no regression)."; exit 2
fi
echo "W13 SINGLE-TILE GATES PASSED — proceeding to full-GEMM bit-exact gate + occupancy + perf."
echo

# The W13 .cu is a SUPERSET of W10 (gemm_w10 MODE 4 is present in the same binary), so the
# apples-on-THIS-pod 70.7 baseline is just MODE 4 of the SAME /tmp/w13 binary (same nvcc invoke).
echo "================= APPLES BASELINE — W10 gemm_w10 MODE4 NST=2 @4096 (same binary, same pod) ================="
/tmp/w13 4096 4 2
echo

echo "================= W13 MODE 6 — NSTG SWEEP (occupancy + bit-exact gate + perf) ================="
# NST = swizzled-tile ring (keep 2, the W10 value). NSTG = the NEW gmma decode ring depth.
# Sweep NSTG 1(==W10-shape baseline in this kernel) ->2 ->3 ->4, at S=4096 (the frontier point),
# plus a 2048 + 8192 confirm on the best NSTG.
for NSTG in 1 2 3 4; do
  echo "--- W13 S=4096 NST=2 NSTG=$NSTG ---"
  /tmp/w13 4096 6 2 $NSTG
  echo
done
echo "--- W13 confirm @2048 + @8192 on NSTG=2 (and NSTG=3) ---"
/tmp/w13 2048 6 2 2; echo
/tmp/w13 8192 6 2 2; echo
/tmp/w13 4096 6 2 3 >/dev/null 2>&1 && /tmp/w13 8192 6 2 3
echo
echo "================= W13 DONE — capture the OCCUPANCY + own GFLOP/s lines above. ================="
