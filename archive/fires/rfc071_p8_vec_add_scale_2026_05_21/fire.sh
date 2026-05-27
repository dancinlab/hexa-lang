#!/bin/bash
# RFC 071 P8 N63 — fire driver script
#
# Usage:
#   ./fire.sh
#
# Prereqs:
#   - ubu-2 reachable (Wireguard 10.142.0.2 OR LAN 192.168.50.60 OR
#     tailscale 100.72.76.118) with CUDA toolkit + RTX 5070 + gcc
#   - PTX + host C already in this directory
#
# Outputs:
#   - fire.log: stderr (ptxas info, JIT log, per-shape progress)
#   - result.json: structured per-shape table + overall PASS/FAIL
#
# Idempotent: re-running re-uploads + re-fires from scratch.

set -e
ARTIFACT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$ARTIFACT_DIR"

PTX="vec_add.sm_80.ptx"
HOST_C="host_vec_add_scale.c"
REMOTE_PTX="/tmp/rfc071_n63_vec_add.ptx"
REMOTE_HOST_BIN="/tmp/host_vec_add_scale"

# 1. Verify local files
for f in "$PTX" "$HOST_C"; do
    [ -f "$f" ] || { echo "missing $f" >&2; exit 2; }
done

# 2. scp to ubu-2 (try LAN first, then VPN, then tailscale)
HOSTS=("ubu-2" "ubu-2-ts" "ubu2-d")
PICKED=""
for h in "${HOSTS[@]}"; do
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$h" 'echo ok' >/dev/null 2>&1; then
        PICKED="$h"
        echo "[fire] reachable via $h" >&2
        break
    fi
done
[ -n "$PICKED" ] || { echo "[fire] OFFLINE: no route to ubu-2" >&2; exit 3; }

# 3. Upload artifacts
scp "$PTX"    "$PICKED:$REMOTE_PTX"
scp "$HOST_C" "$PICKED:/tmp/host_vec_add_scale.c"

# 4. Build host binary on ubu-2 + fire
ssh "$PICKED" bash -s <<'REMOTE_EOF' > result.json 2> fire.log
set -e
cd /tmp
echo "remote-host: $(hostname)" >&2
echo "gcc: $(gcc --version | head -1)" >&2
echo "CUDA: $(ls /usr/local/cuda* 2>/dev/null | head -3 || echo 'no /usr/local/cuda*')" >&2

# Locate cuda.h + libcuda
CUDA_INC=""
CUDA_LIB=""
for d in /usr/local/cuda/include /usr/include /opt/cuda/include; do
    [ -f "$d/cuda.h" ] && CUDA_INC="-I$d" && break
done
for d in /usr/local/cuda/lib64 /usr/lib/x86_64-linux-gnu /opt/cuda/lib64; do
    [ -f "$d/libcuda.so" ] || [ -f "$d/stubs/libcuda.so" ] && CUDA_LIB="-L$d -L$d/stubs" && break
done
echo "CUDA_INC=$CUDA_INC" >&2
echo "CUDA_LIB=$CUDA_LIB" >&2

gcc $CUDA_INC /tmp/host_vec_add_scale.c -o /tmp/host_vec_add_scale $CUDA_LIB -lcuda -lm 2>&1 | tee /tmp/build.log >&2
[ -x /tmp/host_vec_add_scale ] || { echo '{"status":"FAIL","phase":"build"}'; exit 4; }
ls -la /tmp/host_vec_add_scale /tmp/rfc071_n63_vec_add.ptx >&2

# Fire — stdout JSON, stderr diagnostics
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv,noheader >&2 || true
/tmp/host_vec_add_scale
REMOTE_EOF

RC=$?
echo "[fire] rc=$RC" >&2
echo "[fire] result.json written to $ARTIFACT_DIR/result.json"
echo "[fire] fire.log    written to $ARTIFACT_DIR/fire.log"
exit $RC
