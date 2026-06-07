#!/usr/bin/env bash
# DDP-M8/M9/M10 multi-step DDP correctness — build + run on a 2-GPU node.
#   M8  : K-step W + optimizer-state (SGD-momentum + Adam m,v) byte-eq.
#   M10 : per-step loss-curve byte-eq over the K-step run.
#   M9  : bf16/fp16 same-dtype 1-GPU vs N-GPU reproducibility (rel-RMS).
# Reuses the M4/M5b ring all-reduce harness + right-nested reduce tree.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# detect SM arch from the first GPU (default sm_86 for Ampere consumer).
ARCH="${HEXA_ARCH:-}"
if [ -z "$ARCH" ]; then
  CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.' || true)
  if [ -n "${CC:-}" ]; then ARCH="sm_${CC}"; else ARCH="sm_86"; fi
fi
echo "== building ddp_m8_m10 (arch=$ARCH) =="
nvcc -O2 -arch="$ARCH" -o ddp_m8_m10 ddp_train_m8_m10.cu

export DDP_NUM_GPUS="${DDP_NUM_GPUS:-2}"
export HEXA_DDP_K="${HEXA_DDP_K:-10}"
export HEXA_DDP_H="${HEXA_DDP_H:-128}"
echo "== running: N=$DDP_NUM_GPUS K=$HEXA_DDP_K H=$HEXA_DDP_H =="
./ddp_m8_m10
