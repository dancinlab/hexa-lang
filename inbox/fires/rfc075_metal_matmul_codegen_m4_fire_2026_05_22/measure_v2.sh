#!/usr/bin/env bash
# measure_v2.sh — N166 full-tile codegen matmul fire on Apple M4 (mini).
# Compiles the post-fix codegen-emitted MSL (matmul_codegen_v2.metal),
# builds the full-tile Swift host, and fires M=N=K=256 and 512.
set -euo pipefail
cd "$(dirname "$0")"

echo "=== host ==="
hostname; uname -m
xcrun --sdk macosx metal --version 2>&1 | head -1 || true

echo "=== compile codegen-emitted MSL (matmul_codegen_v2.metal) ==="
xcrun --sdk macosx metal -c matmul_codegen_v2.metal -o matmul_codegen_v2.air
xcrun --sdk macosx metallib matmul_codegen_v2.metallib matmul_codegen_v2.air \
  || xcrun --sdk macosx metallib -o matmul_codegen_v2.metallib matmul_codegen_v2.air
echo "MSL_COMPILE_OK matmul_codegen_v2.metallib"

echo "=== build Swift host ==="
xcrun --sdk macosx swiftc -O host_matmul_v2.swift -o host_matmul_v2
echo "HOST_BUILD_OK"

for DIM in 256 512; do
  echo "=== fire DIM=$DIM ==="
  ./host_matmul_v2 ./matmul_codegen_v2.metallib "$DIM" | tee "result_v2_${DIM}.run"
  cp -f result.json "result_v2_${DIM}.json"
done
echo "=== DONE ==="
