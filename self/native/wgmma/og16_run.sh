#!/usr/bin/env bash
# og16_run.sh — OG16 on-pod driver: MATCH THE CANONICAL Layout_K_SW128_Atom so the
# descriptor-direct wgmma read of a SWIZZLE_128B-TMA tile is BIT-EXACT, making the W15
# 32KB decode-band removal USABLE (route a: global pre-permute).
#
# GATE DISCIPLINE (g5, MANDATORY ORDER):
#   1) MODE 2 oracle dump (the landed law, sanity).
#   2) MODE 10 route-(a) single-tile differential sweep -> rel_rms 0 GATE. If FLOOR O(1),
#      STOP — report the residual (canonical atom not matchable by this family); KEEP W10 70.7.
#   3) ONLY after single-tile rel_rms 0: full GEMM MODE 4 bit-exact gate, THEN perf.
#   4) ALWAYS measure the W10 frontier same-pod (apples) and NEVER regress below it.
# cuBLAS-TF32 = ROOFLINE. NO superiority claim. All output INLINE (vast-reclaim storm).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
NVCC=${NVCC:-nvcc}
echo "================= ENV ================="
$NVCC --version | tail -2
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader || true
echo

echo "================= BUILD og16 ================="
if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/og16 wgmma_tf32_og16.cu 2>&1; then
  echo "OG16-BUILD: OK"
else
  echo "OG16-BUILD: FAIL"; exit 1
fi
echo

echo "================= MODE 2 — raw SWIZZLE_128B landed-law oracle ================="
/tmp/og16 2048 2 2>&1 | head -20
echo

echo "================= GATE — MODE 10 route-(a) pre-permute single-tile sweep (rel_rms 0) ================="
/tmp/og16 2048 10; G=$?; echo "exit=$G"
echo

if [ "$G" -ne 0 ]; then
  echo "OG16 SINGLE-TILE GATE FAILED — route-(a) family floors O(1) (canonical atom not"
  echo "matchable by global pre-permute over our cuTensorMapEncodeTiled box)."
  echo "STOP per g5: no full GEMM, no perf number. W10 70.7 frontier KEPT (no regression)."
else
  echo "OG16 SINGLE-TILE GATE PASSED (rel_rms 0) — canonical atom MATCHED, band usable."
  echo "  (winning config: pm=gmma-INTER tsw=NONE swm=0 sbo=1024 boff=0)"
  echo "================= MODE 4 FULL GEMM — bit-exact gate + occupancy + perf ================="
  # MODE4 args: S 4 NST [SWM=0] [SBO=1024] [BOFF=0]  (defaults = winning route-a config)
  for S in 2048 4096; do for NST in 2 3 4; do echo "--- S=$S NST=$NST ---"; /tmp/og16 $S 4 $NST 2>&1; done; done
fi
echo

echo "================= APPLES — W10 frontier same-pod baseline (build + MODE4 @4096 NST2) ================="
if [ -f wgmma_tf32_w10.cu ]; then
  if $NVCC -O3 -arch=sm_90a -lcublas -lcuda -o /tmp/w10 wgmma_tf32_w10.cu 2>&1; then
    echo "W10-BUILD: OK"; /tmp/w10 4096 4 2 2>&1
  else echo "W10-BUILD: FAIL (apples skipped)"; fi
fi
echo "================= OG16 DONE ================="
