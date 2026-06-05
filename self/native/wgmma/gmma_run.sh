#!/usr/bin/env bash
# gmma_run.sh — build wgmma_tf32_gmma.cu and drive W1(build)->W2(single-tile)->W3(full)
# all INLINE (harvest in the same SSH command — vast reclaim storm safe).
set +e
cd "$(dirname "$0")"
ARCH=sm_90a
NVCC=$(command -v nvcc || echo /usr/local/cuda/bin/nvcc)
echo "=== nvcc: $NVCC ==="; $NVCC --version | tail -2
echo "=== GPU ==="; nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader

echo "=== W1: build wgmma_tf32_gmma (arch=$ARCH) ==="
$NVCC -arch=$ARCH -O3 -o /tmp/gmma wgmma_tf32_gmma.cu 2>&1 | tail -20
if [ ! -x /tmp/gmma ]; then echo "W1_BUILD=FAIL"; exit 1; fi
echo "W1_BUILD=OK"

# candidate LBO/SBO (bytes) around the CUTLASS INTER K-major (128,256) point
CANDS="16 32 64 128 256 512 1024"
echo "=== W2: single-tile (mode=1) — principled INTER first ==="
echo "-- principled ALO=0 BLO=0 lA=128 sA=256 lB=128 sB=256 --"
/tmp/gmma 1 0 0 128 256 128 256

echo "=== W2 sweep: ALO/BLO x (LBO,SBO) grid (single-tile, mode=1) ==="
BEST=9; BESTLINE=""
for ALO in 0 1; do for BLO in 0 1; do
  for lB in $CANDS; do for sB in $CANDS; do
    # keep A at the principled point to shrink the grid; A is symmetric/simpler
    OUT=$(/tmp/gmma 1 $ALO $BLO 128 256 $lB $sB 2>/dev/null)
    RR=$(echo "$OUT" | grep -oE 'rel_rms=[0-9.eE+-]+' | head -1 | cut -d= -f2)
    [ -z "$RR" ] && continue
    # track best
    awk -v r="$RR" -v b="$BEST" 'BEGIN{exit !(r<b)}' && { BEST=$RR; BESTLINE="ALO=$ALO BLO=$BLO lB=$lB sB=$sB -> $RR"; }
    case "$OUT" in *PASS*) echo "W2_HIT: $OUT";; esac
  done; done
done; done
echo "W2_BEST: $BESTLINE  (best rel_rms=$BEST)"
# also sweep A descriptor at the best B point would go here if needed

echo "=== W2/W3: full random GEMM (mode=0) at principled + best ==="
echo "-- principled full: "; /tmp/gmma 0 0 0 128 256 128 256
# parse BESTLINE for a full-GEMM retry
if [ -n "$BESTLINE" ]; then
  ba=$(echo "$BESTLINE"|grep -oE 'ALO=[0-9]+'|cut -d= -f2)
  bb=$(echo "$BESTLINE"|grep -oE 'BLO=[0-9]+'|cut -d= -f2)
  bl=$(echo "$BESTLINE"|grep -oE 'lB=[0-9]+'|cut -d= -f2)
  bs=$(echo "$BESTLINE"|grep -oE 'sB=[0-9]+'|cut -d= -f2)
  echo "-- best-config full: ALO=$ba BLO=$bb lB=$bl sB=$bs"; /tmp/gmma 0 $ba $bb 128 256 $bl $bs
fi
echo "=== DONE ==="
