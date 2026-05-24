#!/usr/bin/env bash
# measure.sh — N138 Apple M4 4-simdgroup 64x64 driver.
# Runs on mini. Expects simdgroup_matmul_4sg_64x64.metal + host_4sg.swift in cwd.

set -euo pipefail

echo "=== Apple M4 4-simdgroup 64x64 fire (N138) ==="
date -u +"%Y-%m-%dT%H:%M:%SZ"
sysctl machdep.cpu.brand_string
sysctl hw.ncpu
xcrun --sdk macosx --show-sdk-version
xcrun --sdk macosx metal --version 2>&1 | head -5 || true

echo ""
echo "--- Compiling simdgroup_matmul_4sg_64x64 ---"
xcrun --sdk macosx metal -c simdgroup_matmul_4sg_64x64.metal -o simdgroup_matmul_4sg_64x64.air
xcrun --sdk macosx metallib simdgroup_matmul_4sg_64x64.air -o simdgroup_matmul_4sg_64x64.metallib
ls -l simdgroup_matmul_4sg_64x64.air simdgroup_matmul_4sg_64x64.metallib

echo ""
echo "--- Compiling Swift host ---"
xcrun --sdk macosx swiftc -O host_4sg.swift -o host_4sg
ls -l host_4sg

echo ""
echo "=== Firing simdgroup_matmul_4sg_64x64 (FP16 MMA + FP32 accum) ==="
./host_4sg ./simdgroup_matmul_4sg_64x64.metallib

echo ""
echo "=== Done ==="
date -u +"%Y-%m-%dT%H:%M:%SZ"
