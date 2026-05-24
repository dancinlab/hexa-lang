#!/usr/bin/env bash
# RFC 067 PWGMMA-SCAFFOLD measurement on ubu-2 (RTX 5070 sm_120).
# Build host, regenerate PTX, fire once, dump result.json + fire.log.
set -euo pipefail

DIR="/tmp/wgmma_scaffold"
cd "$DIR"

echo "=== ENV ==="
nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader
nvcc --version | tail -1
ptxas --version | tail -1
echo

echo "=== GEN PTX ==="
python3 gen_wgmma_scaffold_ptx.py wgmma_scaffold.ptx
echo

echo "=== PTXAS sm_90a verify ==="
ptxas -arch=sm_90a wgmma_scaffold.ptx -o wgmma_scaffold.cubin -v 2>&1 | tee ptxas_info.log
echo

echo "=== BUILD HOST ==="
nvcc -O2 -arch=sm_90a -o host host.c -lcuda -lm 2>&1 | tee compile.log
echo

echo "=== FIRE ==="
./host wgmma_scaffold.ptx 2>&1 | tee fire.log
RC=${PIPESTATUS[0]}
echo "host exit: $RC"
exit $RC
