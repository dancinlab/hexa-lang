#!/usr/bin/env bash
# run_op24_5070.sh — HEXA-0POD OP-24 dispatch-unit verify driver (aiden RTX 5070, FREE).
# Idle-guards the GPU, builds op24_tf32_livewire_dispatch.cu, sweeps shapes mirroring
# OP-20 (D={768,1536} x B={1,8} -> M=B*T rows, K=N=D), reports the 3 gates + speedup.
set -u
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=/usr/local/cuda/targets/x86_64-linux/include
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/op24_tf32_livewire_dispatch.cu"
BIN=/tmp/op24disp

echo "=== nvcc / driver ==="
nvcc --version | tail -2
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

# idle-guard: wait until util<5% and mem<800MiB (exclusive card) before timed runs.
echo "=== idle-guard ==="
for try in $(seq 1 60); do
  read u m < <(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits | head -1 | tr ',' ' ')
  if [ "${u:-100}" -lt 5 ] && [ "${m:-9999}" -lt 800 ]; then echo "idle (util=$u mem=${m}MiB) after $try checks"; break; fi
  echo "busy util=$u mem=${m}MiB; waiting ($try)"; sleep 5
done

echo "=== build ==="
nvcc -arch=sm_120 -O3 -I"$INC" -o "$BIN" "$SRC" -lcublas || { echo "BUILD-FAIL"; exit 1; }
echo "build OK"

T=256
echo "=== sweep (M=B*T, K=N=D; mirrors OP-20 D={768,1536} B={1,8}) ==="
for D in 768 1536; do
  for B in 1 8; do
    M=$((B*T))
    "$BIN" "$M" "$D" "$D" 50
  done
done
echo "=== done ==="
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader
rm -f "$BIN"
