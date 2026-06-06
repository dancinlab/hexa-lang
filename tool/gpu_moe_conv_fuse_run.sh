#!/usr/bin/env bash
# gpu_moe_conv_fuse_run.sh — build + gate + perf + util harvest, all INLINE.
# Captures nvidia-smi util (MEAN/PEAK) per path by sampling during a long-run
# variant of each kernel. Self-contained: prints everything to stdout so the
# rented pod can be destroyed immediately (no nohup data to lose).
set -u
ARCH="${ARCH:-sm_80}"
E="${E:-30}"; D="${D:-2048}"; T="${T:-256}"; K="${K:-3}"; DIL="${DIL:-1}"

echo "=== nvidia-smi ==="
nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv

echo "=== build (nvcc -arch=$ARCH -O3) ==="
nvcc -arch="$ARCH" -O3 -o /tmp/moefuse /tmp/gpu_moe_conv_fuse.cu 2>&1 || { echo "BUILD-FAIL"; exit 3; }
echo "build OK"

echo "=== RUN (gate + perf) E=$E d=$D T=$T K=$K dil=$DIL ==="
/tmp/moefuse "$E" "$D" "$T" "$K" "$DIL"
RC=$?
echo "run rc=$RC"
[ "$RC" != "0" ] && { echo "RUN-FAIL (gate or cross-check)"; exit "$RC"; }

# ── util MEAN/PEAK per path ──────────────────────────────────────────────────
# Re-run each path in a tight loop (a "util_<path>" mode in the binary) while a
# background nvidia-smi sampler records utilization.gpu at 50ms. Done INLINE.
util_capture() {
    local label="$1"; shift
    rm -f /tmp/util.log
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -lms 50 > /tmp/util.log 2>/dev/null &
    local smipid=$!
    "$@" >/tmp/util_run.log 2>&1
    sleep 0.3
    kill "$smipid" 2>/dev/null; wait "$smipid" 2>/dev/null
    # mean + peak over samples > 0 (ignore idle tail)
    awk -v lbl="$label" '
        { v=$1+0; n++; s+=v; if(v>mx)mx=v }
        END { if(n>0) printf "[UTIL %-12s] mean=%.1f%% peak=%.0f%% (n=%d samples)\n", lbl, s/n, mx, n }
    ' /tmp/util.log
}

echo "=== UTIL capture (sampled @50ms during a ~2.5s sustained loop of each path) ==="
# A = ModuleList-30 (under-fill baseline) · B = grouped (regression) · C = FUSED (cure)
for path in A B C; do
    util_capture "path_$path" env MOEFUSE_ONLY="$path" /tmp/moefuse "$E" "$D" "$T" "$K" "$DIL"
done

echo "=== DONE ==="
