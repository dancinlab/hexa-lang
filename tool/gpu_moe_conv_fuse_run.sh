#!/usr/bin/env bash
# gpu_moe_conv_fuse_run.sh — build + gate + perf + util harvest, all INLINE.
# OG-FUSE-PROD-KERNEL: adds path (E) GEMM-conv weight-reuse kernel (BM-fold weight
# reuse) + path (F) cuBLAS strided-batched GEMM roofline (built with -lcublas).
# Captures nvidia-smi util (MEAN/PEAK) per path. Self-contained: prints everything
# to stdout so the rented pod can be destroyed immediately (no nohup data to lose).
set -u
ARCH="${ARCH:-sm_90}"
E="${E:-30}"; K="${K:-3}"; DIL="${DIL:-1}"; T="${T:-256}"
# OG-FUSE-PROD-PERF2: d=6208 is the measured 7B wall — the wide-tile sweep target.
# Override with DSWEEP. Skip the slow naive paths (B grouped, C naive-fused, D tiled)
# in the perf timing — the byte-eq gate already ran them; we only need A/E/F/H timed
# for the wide-tile arithmetic-intensity ratio vs cuBLAS roofline.
DSWEEP="${DSWEEP:-6208}"
export MOEFUSE_SKIP="${MOEFUSE_SKIP:-BCD}"

echo "=== nvidia-smi ==="
nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv

echo "=== build (nvcc -arch=$ARCH -O3 -lcublas -DUSE_CUBLAS) ==="
nvcc -arch="$ARCH" -O3 -DUSE_CUBLAS -o /tmp/moefuse /tmp/gpu_moe_conv_fuse.cu -lcublas 2>&1 \
  || { echo "CUBLAS-BUILD-FAIL — retry without cuBLAS"; \
       nvcc -arch="$ARCH" -O3 -o /tmp/moefuse /tmp/gpu_moe_conv_fuse.cu 2>&1 \
       || { echo "BUILD-FAIL"; exit 3; }; }
echo "build OK"

run_shape() {
  local D="$1"
  echo ""
  echo "########################################################################"
  echo "### SHAPE d=$D  (E=$E T=$T K=$K dil=$DIL) ###"
  echo "########################################################################"
  echo "=== RUN (gate + perf) ==="
  /tmp/moefuse "$E" "$D" "$T" "$K" "$DIL"
  RC=$?
  echo "run rc=$RC"
  [ "$RC" != "0" ] && { echo "RUN-FAIL (gate or cross-check) d=$D"; return "$RC"; }

  # ── util MEAN/PEAK per path ──────────────────────────────────────────────────
  util_capture() {
      local label="$1"; shift
      rm -f /tmp/util.log
      nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -lms 50 > /tmp/util.log 2>/dev/null &
      local smipid=$!
      "$@" >/tmp/util_run.log 2>&1
      sleep 0.3
      kill "$smipid" 2>/dev/null; wait "$smipid" 2>/dev/null
      awk -v lbl="$label" '
          { v=$1+0; n++; s+=v; if(v>mx)mx=v }
          END { if(n>0) printf "[UTIL %-12s] mean=%.1f%% peak=%.0f%% (n=%d samples)\n", lbl, s/n, mx, n }
      ' /tmp/util.log
  }
  echo "=== UTIL capture (sampled @50ms during a ~2.5s sustained loop of each path) ==="
  # A = ModuleList-30 · B = grouped · C = FUSED naive · D = TILED-FUSED · E = GEMM-CONV (PROD)
  for path in A D E; do
      util_capture "path_${path}_d${D}" env MOEFUSE_ONLY="$path" /tmp/moefuse "$E" "$D" "$T" "$K" "$DIL"
  done
  return 0
}

OVERALL=0
for D in $DSWEEP; do
  run_shape "$D" || OVERALL=$?
done

echo ""
echo "=== ALL SHAPES DONE (overall rc=$OVERALL) ==="
exit "$OVERALL"
