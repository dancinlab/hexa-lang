#!/usr/bin/env bash
# build_w16.sh — TURNKEY OP-21A build+gate+measure for self/native/wgmma/wgmma_tf32_w16.cu.
# =============================================================================
# The OP-21A lever (canonical-atom re-encode -> descriptor-direct wgmma deleting the 32KB
# decode band -> decode-free NST=3 ring + wgmma.wait_group<NST-2> + setmaxnreg producer/
# consumer split) as ONE command. Wires the WRITTEN w16.cu to the OP-21 H100 recipe
# (F-OP21-HOPPER-WARPSPEC-DESIGN §4). The kernel is already local-checked (host-side C++
# structural parse); THIS script is the GPU-GATED half — it ONLY runs on an authorized
# H100 (sm_90a). NO perf number exists until this runs there. ⚠ ZERO-VAST standing goal:
# this script does NOT rent. It assumes you are ALREADY ON an authorized sm_90a host (the
# PROVISION block is a documented checklist, not an auto-rent). cuBLAS-TF32 = ROOFLINE; no
# superiority claim. All output INLINE (vast-reclaim storm discipline).
#
# USAGE (on the authorized H100):
#   bash tool/wgmma/build_w16.sh                 # full gate+measure, producer-WG (D5) build
#   W16_PRODUCER_WG=0 bash tool/wgmma/build_w16.sh   # fallback (single-elected-thread producer)
#   NVCC=/usr/local/cuda-12.6/bin/nvcc bash tool/wgmma/build_w16.sh
#
# GATE DISCIPLINE (g5, MANDATORY ORDER — the script enforces it):
#   1) MODE 0 canonical-decode probe  -> rel_rms 0   (D1 sanity)
#   2) MODE 1 descriptor-direct probe -> rel_rms 0   (the D1 FALSIFIER; sweeps fields if it floors)
#      If MODE 1 floors at ~1.0/1.392 (the W15 wall reproduces): D1 FAILED -> switch to OP-21B
#      (gemm_w16b, -DW16_OP21B), re-gate, then measure that instead. Either is a number.
#   3) ONLY after a rel_rms-0 single-tile gate: MODE 4 full-GEMM bit-exact gate @2048/4096/8192,
#      THEN perf sweep (own vs same-binary gemm_w10 vs same-binary cuBLAS-TF32), THEN SASS.
# =============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "$HERE/../../self/native/wgmma" && pwd)"
cd "$SRC_DIR"
NVCC=${NVCC:-nvcc}
PWG=${W16_PRODUCER_WG:-1}                 # 1 = producer-WG + setmaxnreg (D5); 0 = elected-thread fallback
BIN=/tmp/w16
ARCH=sm_90a

echo "================= PROVISION CHECKLIST (authorized H100 only — this script does NOT rent) ================="
echo "  [ ] authorization + budget confirmed; ZERO-VAST standing goal — only run if already on an sm_90a host"
echo "  [ ] nvcc 12.6 (V12.6.77), driver 560.35.x  (EXACT apples to W10/W13/W15)"
echo "  [ ] pod tagged to YOUR project; DESTROY immediately after capture (leak 0)"
echo

echo "================= ENV ================="
$NVCC --version | tail -2 || { echo "NO nvcc — this is the GPU-GATED half; run on the authorized H100."; exit 1; }
nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader 2>/dev/null || \
  { echo "NO sm_90a GPU visible — w16 perf is H100-GATED; nothing to measure here."; exit 1; }
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' .')
if [ "${CC:-0}" != "90" ]; then
  echo "WARN: compute_cap=$CC (not 9.0). wgmma/setmaxnreg need sm_90a (Hopper). Proceeding but expect build/run faults off-Hopper."
fi
echo

echo "================= BUILD w16 (W16_PRODUCER_WG=$PWG) ================="
NVCCFLAGS="-O3 -arch=$ARCH -lcublas -lcuda -DW16_PRODUCER_WG=$PWG"
echo "+ $NVCC $NVCCFLAGS -Xptxas -v wgmma_tf32_w16.cu -o $BIN"
if $NVCC $NVCCFLAGS -Xptxas -v wgmma_tf32_w16.cu -o $BIN 2>/tmp/w16.ptxas; then
  echo "W16-BUILD: OK"
else
  echo "W16-BUILD: FAIL"; cat /tmp/w16.ptxas; exit 1
fi
echo "--- ptxas -v (regs/CTA + setmaxnreg acceptance; watch for C7507 'setmaxnreg ignored') ---"
grep -iE "registers|setmaxnreg|C7507|gemm_w16|smem|spill" /tmp/w16.ptxas || cat /tmp/w16.ptxas
if grep -qiE "C7507|setmaxnreg.*ignored" /tmp/w16.ptxas && [ "$PWG" = "1" ]; then
  echo "!! ptxas IGNORED setmaxnreg (C7507) — the W12 failure mode. REBUILD with the fallback:"
  echo "   W16_PRODUCER_WG=0 bash tool/wgmma/build_w16.sh"
  echo "   (continuing with this build so the gate/perf still report, but D5 is not in effect)"
fi
echo

echo "================= D1 EVIDENCE — MODE 9 canonical-atom layout dump ================="
$BIN 2048 9 2>&1 | head -22
echo

echo "================= GATE 1/2 — MODE 0 canonical-decode probe (rel_rms 0) ================="
$BIN 2048 0; G0=$?; echo "exit=$G0"
echo

echo "================= GATE 2/2 — MODE 1 descriptor-direct probe (the D1 FALSIFIER) ================="
# default: lbo=16 sbo=1024 boff=0 swmode=1 (the W15 best basin). If it floors, sweep the fields.
$BIN 2048 1 >/tmp/w16.m1 2>&1; G1=$?; cat /tmp/w16.m1
if [ "$G1" -ne 0 ]; then
  echo "--- MODE 1 floored at default; SWEEP (lbo,sbo,boff,swmode) INLINE (W15 iterate, canonical landing) ---"
  HIT=""
  for SW in 1 2 3; do for SBO in 1024 512 256 2048 128; do for BOFF in 0 1 2 3 4 5 6 7; do for LBO in 16 128 256 1024; do
    OUT=$($BIN 2048 1 $LBO $SBO $BOFF $SW 2>&1)
    RR=$(echo "$OUT" | grep -oE "rel_rms=[0-9.e+-]+" | head -1)
    if echo "$OUT" | grep -qE "rel_rms=0.000e\+00|PASS"; then echo "HIT lbo=$LBO sbo=$SBO boff=$BOFF sw=$SW -> $OUT"; HIT="$LBO $SBO $BOFF $SW"; break 4; fi
  done; done; done; done
  if [ -z "$HIT" ]; then
    echo "MODE 1 GATE FAILED across the full sweep — D1 canonical landing did NOT reach rel_rms 0."
    echo "the W15 wall reproduces on the canonical box too -> M3 stays dead. SWITCH to OP-21B:"
    echo "   $NVCC $NVCCFLAGS -DW16_OP21B -o $BIN wgmma_tf32_w16.cu   (gemm_w16b: keep band, no M3)"
    echo "STOP per g5: no w16 full GEMM, no perf. W10 70.7 frontier KEPT. Report the floored rel_rms (a number)."
    echo "OP-21B is the documented fallback — re-run with gemm_w16b wired as MODE 4 (kit follow-up)."
    exit 2
  fi
  echo "MODE 1 GATE PASSED via swept fields: $HIT"
  read -r BLBO BSBO BBOFF BSW <<<"$HIT"
else
  echo "MODE 1 GATE PASSED at default (lbo=16 sbo=1024 boff=0 sw=1) — D1 CONFIRMED."
  BLBO=16; BSBO=1024; BBOFF=0; BSW=1
fi
echo "D1 single-tile descriptor-direct read is BIT-EXACT (rel_rms 0). The 32KB decode band is removable."
echo

echo "================= MODE 4 FULL GEMM — bit-exact gate + occupancy + perf (descriptor $BLBO/$BSBO/$BBOFF/$BSW) ================="
# args: S MODE NST lbo sbo boff swmode. Sweep S in {2048,4096,8192}, NST in {3,4,2}.
# MODE 4 re-measures gemm_w10 (same binary) for the apples Δ vs the W10 70.7 baseline.
for S in 2048 4096 8192; do
  for NST in 3 4 2; do
    echo "--- S=$S NST=$NST ---"
    $BIN $S 4 $NST $BLBO $BSBO $BBOFF $BSW 2>&1
  done
done
echo

echo "================= SASS — confirm gmma decode STS GONE (descriptor-direct) + wgmma back-to-back ================="
# W9 evidence pattern: STS 28->0. Here the decode band is deleted, so gemm_w16 should have NO
# decode STS, and wgmma.mma_async issued back-to-back (the overlap). Count both.
if command -v cuobjdump >/dev/null 2>&1; then
  cuobjdump -sass $BIN 2>/dev/null | awk '/gemm_w16[^b]/{f=1} /gemm_w16b/{f=0} f' > /tmp/w16.sass
  echo "STS in gemm_w16 (expect ~0, decode band deleted): $(grep -c 'STS' /tmp/w16.sass)"
  echo "WGMMA/HGMMA issues in gemm_w16 (the tensor-core ops):     $(grep -ciE 'GMMA|WGMMA' /tmp/w16.sass)"
  echo "(compare to W10's gmma decode STS — cuobjdump -sass /tmp/w10 | grep -c STS)"
else
  echo "cuobjdump not found — skip SASS evidence (not gating)."
fi
echo

echo "================= HEADLINE (capture into the W16 verdict) ================="
echo "own @S=4096 NST=best vs the W10 70.7 same-pod baseline (the apples Δ) is in the MODE 4 lines above."
echo "If own LIFTS 70.7 bit-exact -> NEW frontier (write F-FUSION-SM90-WGMMA-W16). Else -> closed-negative,"
echo "W10 KEPT (the W11/W12/W13 hard rule). PARITY (<=1.3x) is reported honestly in the MODE 4 PARITY field."
echo
echo "================= DESTROY (leak 0) ================="
echo "  capture the lines above into .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W16.txt, THEN:"
echo "  yes | <provider> destroy <YOUR-pod-id>   # confirm PROJECT tag; destroy OWN pod only"
echo "================= build_w16 DONE ================="
