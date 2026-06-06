#!/usr/bin/env bash
# og18_run.sh — OG18 on-pod driver: port the OG16 canonical-atom + OG17 relaxed-pipeline PARITY
# recipe (TF32 6.09x->1.24x) to FP16/BF16, to close the OG14/W14 FP16 gap (11.5x off cuBLAS-FP16).
#
# OG18 = OG14's f16 8x8 gmma atom (gmma_phys16) + OG16 route-(a) global pre-lay + NO-swizzle TMA
# (descriptor-direct, NO in-kernel decode band — the OG14 defect) + OG17 relaxed wait_group 1.
#
# GATE (g5 — OG14/W14 contract, NOT bit-exact-vs-FP64): rel_rms <= 1e-2 vs SAME-DTYPE cuBLAS-FP16
# (cublasGemmEx CUDA_R_16F in, CUBLAS_COMPUTE_32F). cuBLAS-FP16 = ROOFLINE (~2x TF32),
# parity-SEEKING (<=1.3x), NO superiority claim. single-tile FIRST then full GEMM.
#
# GATE DISCIPLINE (mandatory order):
#   1) MODE 10 route-(a) f16 single-tile differential sweep -> rel_rms <= 1e-2 GATE. If FLOOR,
#      STOP — report residual (f16 canonical atom not matchable band-free). OG14 71-76 KEPT.
#   2) ONLY after single-tile: MODE 4 f16 128x128 full GEMM bit-gate THEN perf.
#   3) MODE 6 f16 relaxed-pipe (OG17 lever) + MODE 5 f16 128x256 tile (OG17 lever).
#   4) MODE 7 bf16 if budget. ALWAYS report ratio vs cuBLAS-FP16 (11.5x -> ?).
# All output INLINE (vast-reclaim storm). cuBLAS-FP16 = roofline.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD og18 ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/og18 wgmma_f16_og18.cu 2>&1; then
  echo "OG18-BUILD: OK"
else
  echo "OG18-BUILD: FAIL"; exit 1
fi
echo

echo "================= GATE — MODE 10 route-(a) f16 single-tile sweep (rel_rms <= 1e-2) ================="
/tmp/og18 2048 10; G=$?; echo "exit=$G"
echo

if [ "$G" -ne 0 ]; then
  echo "OG18 SINGLE-TILE GATE FAILED — f16 route-(a) family floors (canonical f16 atom not"
  echo "matchable band-free by global pre-lay over our cuTensorMapEncodeTiled box)."
  echo "STOP per g5: no full GEMM, no perf number. OG14 71-76 TFLOP/s FP16 frontier KEPT."
  echo "(harvest the best rel_rms + the exact FP16-specific blocker for the verdict.)"
else
  echo "OG18 SINGLE-TILE GATE PASSED (rel_rms <= 1e-2) — f16 canonical atom MATCHED, band-free."
  echo "  (winning swm/sbo/boff printed above; passed to full GEMM via argv.)"
  # parse the winning config from the NEWBEST line (best at end of sweep).
  CFG=$(/tmp/og18 2048 10 2>/dev/null | grep SWEEP-DONE | sed -E 's/.*@ swm=([0-9]+) sbo=([0-9]+) boff=([0-9]+).*/\1 \2 \3/')
  SWM=$(echo $CFG | awk '{print $1}'); SBO=$(echo $CFG | awk '{print $2}'); BOFF=$(echo $CFG | awk '{print $3}')
  SWM=${SWM:-0}; SBO=${SBO:-128}; BOFF=${BOFF:-0}
  echo "USING swm=$SWM sbo=$SBO boff=$BOFF"
  echo
  echo "================= MODE 4 — f16 128x128 FULL GEMM (band-free) gate + occupancy + perf ====="
  for S in 2048 4096; do for NST in 2 3; do echo "--- S=$S NST=$NST ---"; /tmp/og18 $S 4 $NST $SWM $SBO $BOFF 2>&1; done; done
  echo
  echo "================= MODE 6 — f16 128x128 + RELAXED wait_group 1 pipeline (OG17 lever) ======"
  for S in 4096; do for NST in 2 3; do echo "--- S=$S NST=$NST ---"; /tmp/og18 $S 6 $NST $SWM $SBO $BOFF 2>&1; done; done
  echo
  echo "================= MODE 5 — f16 128x256 OUTPUT TILE (OG17 lever 1) ========================"
  for S in 4096; do for NST in 2 3; do echo "--- S=$S NST=$NST ---"; /tmp/og18 $S 5 $NST $SWM $SBO $BOFF 2>&1; done; done
  echo
  echo "================= MODE 7 — bf16 128x128 FULL GEMM gate + perf ============================"
  for S in 4096; do echo "--- S=$S NST=3 ---"; /tmp/og18 $S 7 3 $SWM $SBO $BOFF 2>&1; done
fi
echo

echo "================= APPLES — OG14/W14 FP16 frontier same-pod baseline (MODE4 @4096 NST3) ===="
if [ -f wgmma_f16_w14.cu ]; then
  if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/w14 wgmma_f16_w14.cu 2>&1; then
    echo "W14-BUILD: OK"; /tmp/w14 4096 4 3 2>&1
  else echo "W14-BUILD: FAIL (apples skipped)"; fi
fi
echo "================= OG18 DONE ================="
