#!/usr/bin/env bash
# gpu_moe_conv_xover_run.sh — OG-FUSE-XOVER: d=6208/H200 PRODUCTION crossover.
#
# Sweeps d ∈ {4096, 6208, 8192} (E=30, K=3, T realistic) on a big-SM GPU
# (H200 132 SMs / H100 132/114 SMs) to locate the under-fill -> saturated
# boundary for the fused multi-expert Conv1d MoE kernel (tool/gpu_moe_conv_fuse.cu,
# PR #2859). The KEY question: does PRODUCTION d=6208 live in the UNDER-FILL
# regime (fused cure applies to the real 7B CLMConvMoE step) or SATURATED
# (cure moot for production)?
#
# GATE FIRST (g5): byte-exact max|Δ|=0 vs the 30-conv CPU op-by-op reference,
# run once at the small gate shape (shape-independent correctness). NO perf
# number is emitted before the gate passes (the binary enforces this).
#
# Everything prints to stdout INLINE so the rented pod is destroyable the second
# numbers land (no nohup file to lose).
set -u
ARCH="${ARCH:-sm_90}"     # H100/H200 = sm_90
E="${E:-30}"; T="${T:-256}"; K="${K:-3}"; DIL="${DIL:-1}"
DSWEEP="${DSWEEP:-4096 6208 8192}"   # production d=6208 in the middle

echo "=== nvidia-smi ==="
nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv

echo "=== build (nvcc -arch=$ARCH -O3) ==="
nvcc -arch="$ARCH" -O3 -o /tmp/moefuse /tmp/gpu_moe_conv_fuse.cu 2>&1 || { echo "BUILD-FAIL"; exit 3; }
echo "build OK"

# ── util MEAN/PEAK per path (sampled @50ms during ~2.5s sustained loop) ───────
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
        END { if(n>0) printf "[UTIL %-16s] mean=%.1f%% peak=%.0f%% (n=%d)\n", lbl, s/n, mx, n }
    ' /tmp/util.log
}

for D in $DSWEEP; do
    echo ""
    echo "########################################################################"
    echo "### SWEEP d=$D  (E=$E T=$T K=$K dil=$DIL)  ARCH=$ARCH"
    echo "########################################################################"
    echo "=== RUN (gate + perf) d=$D ==="
    /tmp/moefuse "$E" "$D" "$T" "$K" "$DIL"
    RC=$?
    echo "run rc=$RC (d=$D)"
    [ "$RC" != "0" ] && { echo "RUN-FAIL (gate or cross-check) d=$D"; exit "$RC"; }

    echo "=== UTIL capture d=$D (A=ModuleList-30 · B=grouped · C=FUSED) ==="
    for path in A B C; do
        util_capture "d${D}_path_$path" env MOEFUSE_ONLY="$path" /tmp/moefuse "$E" "$D" "$T" "$K" "$DIL"
    done
done

echo ""
echo "=== XOVER DONE — all d in {$DSWEEP} swept ==="
