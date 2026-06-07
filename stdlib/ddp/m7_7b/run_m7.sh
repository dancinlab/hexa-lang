#!/usr/bin/env bash
# DDP-M7 on-pod build + run. PRODUCTION-scale DDP byte-eq.
# Usage: ./run_m7.sh            (auto: FP64 largest-fit + fp32 7B-target legs)
set -euo pipefail
ARCH="${ARCH:-sm_90}"          # H100=sm_90; override e.g. ARCH=sm_86 for 3090/A40
TARGET="${HEXA_DDP_NPARAM_TARGET:-7000000000}"
NG="${DDP_NUM_GPUS:-$(nvidia-smi -L | wc -l)}"
echo "=== DDP-M7 build (arch=$ARCH, N=$NG GPUs, target=$TARGET params) ==="
nvidia-smi --query-gpu=index,name,memory.total --format=csv

echo "--- compiling FP64 leg ---"
nvcc -O2 -arch=$ARCH -DM7_REAL=double -o ddp_train_m7_f64 ddp_train_m7.cu
echo "--- compiling fp32 leg ---"
nvcc -O2 -arch=$ARCH -DM7_REAL=float  -o ddp_train_m7_f32 ddp_train_m7.cu

echo
echo "######################## LEG A: FP64 (largest-fitting, true max|Δ|=0) ########################"
DDP_NUM_GPUS=$NG HEXA_DDP_NPARAM_TARGET=$TARGET ./ddp_train_m7_f64

echo
echo "######################## LEG B: fp32 (push to 7B target, max|Δ|=0 via matched order) ########################"
DDP_NUM_GPUS=$NG HEXA_DDP_NPARAM_TARGET=$TARGET ./ddp_train_m7_f32
