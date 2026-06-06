#!/usr/bin/env bash
# og19_run.sh — OG19 on-pod driver: close the OG18 FP16 own-GEMM gap (1.64x off cuBLAS-FP16)
# toward cuBLAS-FP16 PARITY (<=1.3x) by exploiting OG17's relaxed-wait_group ping-pong pipeline
# (MODE 6, gemm_og18_f16_pipe) in the REGIME where OG17 actually crossed parity for TF32.
#
# KEY INSIGHT (from the OG17 + OG18 verdicts):
#   * OG17 TF32 PARITY (1.24x) landed at S=2048 NST=3 with the relaxed pipe (MODE 6) — NOT at
#     S=4096 (where OG17 was only 1.55-1.60x, the same regime FP16 sits in).
#   * OG18 ran MODE 6 ONLY at S=4096 (1.64x) — it NEVER ran the relaxed pipe at S=2048, the
#     exact spot OG17 found parity. That is the single unexplored data point.
#   * The band is gone (OG16/OG18 canonical atom), so a DEEPER async ring (NST=4) is now SMEM-
#     viable; OG18 stopped at NST=3. Sweep NST=2/3/4 for the pipe in both regimes.
#
# OG19 LEVER = OG17 relaxed wait_group 1 ping-pong (already ported as MODE 6 = gemm_og18_f16_pipe,
# next slab's wgmma ISSUE overlaps this slab's tensor-core drain, mbarrier ring data-safe, NO
# smem growth so 2 CTA/SM held) DRIVEN across the OG17 parity regime (S=2048) + deeper NST ring.
#
# GATE (g5): rel_rms <= 1e-2 vs SAME-DTYPE cuBLAS-FP16 FIRST (single-tile then full), THEN perf.
# cuBLAS-FP16 = ROOFLINE (~2x TF32, ~825 @4096 / ~635 @2048). parity-SEEKING (<=1.3x), NO
# superiority claim. FP16 2x roofline makes parity harder than TF32 — report honestly.
# Do NOT regress below OG18 504.3 / 1.64x. All output INLINE (vast-reclaim storm).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD og18 kernel (OG19 reuses the OG18 canonical-atom binary) ========="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/og19 wgmma_f16_og18.cu 2>&1; then
  echo "OG19-BUILD: OK"
else
  echo "OG19-BUILD: FAIL"; exit 1
fi
echo

echo "================= GATE — MODE 10 route-(a) f16 single-tile sweep (rel_rms <= 1e-2) ======="
/tmp/og19 2048 10; G=$?; echo "exit=$G"
echo
if [ "$G" -ne 0 ]; then
  echo "OG19 SINGLE-TILE GATE FAILED — f16 route-(a) atom floors. STOP per g5 (no perf)."
  echo "OG18 504.3/1.64x FP16 frontier KEPT."
  exit 0
fi
# Winning descriptor config (OG18 verdict: swm=0 sbo=256 boff=0); re-derive defensively.
CFG=$(/tmp/og19 2048 10 2>/dev/null | grep SWEEP-DONE | sed -E 's/.*@ swm=([0-9]+) sbo=([0-9]+) boff=([0-9]+).*/\1 \2 \3/')
SWM=$(echo $CFG | awk '{print $1}'); SBO=$(echo $CFG | awk '{print $2}'); BOFF=$(echo $CFG | awk '{print $3}')
SWM=${SWM:-0}; SBO=${SBO:-256}; BOFF=${BOFF:-0}
echo "OG19 USING swm=$SWM sbo=$SBO boff=$BOFF"
echo

echo "================= OG19 CORE — MODE 6 RELAXED PIPE across OG17 parity regime + NST ring ==="
echo "  (S=2048 = OG17's TF32 parity sweet spot, NEVER run with the f16 pipe in OG18)"
for S in 2048 4096; do
  for NST in 2 3 4; do
    echo "--- MODE 6 (relaxed pipe) S=$S NST=$NST ---"
    /tmp/og19 $S 6 $NST $SWM $SBO $BOFF 2>&1
  done
done
echo

echo "================= OG19 — MODE 5 (128x256 tile) NST ring @ both regimes (OG18 summit lever)"
for S in 2048 4096; do
  for NST in 2 3 4; do
    echo "--- MODE 5 (128x256) S=$S NST=$NST ---"
    /tmp/og19 $S 5 $NST $SWM $SBO $BOFF 2>&1
  done
done
echo

echo "================= OG19 — MODE 4 (128x128 baseline) same-pod apples @ S=2048 ============="
for NST in 2 3; do echo "--- MODE 4 S=2048 NST=$NST ---"; /tmp/og19 2048 4 $NST $SWM $SBO $BOFF 2>&1; done
echo

echo "================= OG19 DONE — best ratio across the grid is the OG19 FP16 summit ========="
