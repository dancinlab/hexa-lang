#!/usr/bin/env bash
# RFC 075 ROCm P4 silicon-fire — pod-side runner
# Executed inside the RunPod MI300X pod (image: runpod/pytorch:2.4.0-py3.10-rocm6.1.0-ubuntu22.04)
#
# Stdout/stderr captured to fire.log by the caller (scp / runpodctl exec).

set -e
set -o pipefail

echo "=== rocminfo (truncated) ==="
which rocminfo && rocminfo | head -80 || echo "rocminfo not found"

echo
echo "=== hipcc --version ==="
which hipcc && hipcc --version || { echo "hipcc not found"; exit 3; }

echo
echo "=== rocm-smi ==="
which rocm-smi && rocm-smi || echo "rocm-smi not found"

echo
echo "=== compile vec_add.cpp ==="
cd /workspace
hipcc -O2 vec_add.cpp -o vec_add
ls -la vec_add

echo
echo "=== fire vec_add ==="
./vec_add
echo "exit=$?"

echo
echo "=== done ==="
