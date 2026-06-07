#!/usr/bin/env bash
# FF-BWDFUSE build + gate + bwd-glue perf driver. Detects sm_XX, builds, runs.
set -euo pipefail
SRC="${1:-gpu_moe_conv_bwd_fuse.cu}"
ARCH="${ARCH:-}"
if [ -z "$ARCH" ]; then
  CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.')
  ARCH="sm_${CC:-90}"
fi
echo "# building $SRC for $ARCH"
nvcc -arch="$ARCH" -O3 -o gpu_moe_conv_bwd_fuse "$SRC"
echo "# === GATE shape (default) ==="
./gpu_moe_conv_bwd_fuse "$@"
