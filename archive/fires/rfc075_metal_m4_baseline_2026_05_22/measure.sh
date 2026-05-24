#!/usr/bin/env bash
# measure.sh — RFC 075 Apple M4 baseline driver.
# Runs on mini. Expects vec_add.metal + host_vec_add.swift +
# simdgroup_matmul_64x64_tg.metal + host_simdgroup_matmul_64x64.swift in cwd.

set -euo pipefail

echo "=== Apple M4 baseline fire ==="
date -u +"%Y-%m-%dT%H:%M:%SZ"
sysctl machdep.cpu.brand_string
sysctl hw.ncpu
xcrun --sdk macosx --show-sdk-version
xcrun --sdk macosx metal --version 2>&1 | head -5 || true

# ─── compile Metal kernels ──────────────────────────────────────────────
echo ""
echo "--- Compiling vec_add ---"
xcrun --sdk macosx metal -c vec_add.metal -o vec_add.air
xcrun --sdk macosx metallib vec_add.air -o vec_add.metallib
ls -l vec_add.air vec_add.metallib

echo ""
echo "--- Compiling simdgroup_matmul_64x64 ---"
xcrun --sdk macosx metal -c simdgroup_matmul_64x64_tg.metal -o simdgroup_matmul_64x64_tg.air
xcrun --sdk macosx metallib simdgroup_matmul_64x64_tg.air -o simdgroup_matmul_64x64_tg.metallib
ls -l simdgroup_matmul_64x64_tg.air simdgroup_matmul_64x64_tg.metallib

# ─── compile Swift hosts ────────────────────────────────────────────────
echo ""
echo "--- Compiling Swift hosts ---"
xcrun --sdk macosx swiftc -O host_vec_add.swift -o host_vec_add
xcrun --sdk macosx swiftc -O host_simdgroup_matmul_64x64.swift -o host_64x64
ls -l host_vec_add host_64x64

# ─── fire vec_add ───────────────────────────────────────────────────────
echo ""
echo "=== Firing vec_add (FP32 bandwidth) ==="
./host_vec_add ./vec_add.metallib
mv -f result.json result_vec_add.json

# ─── fire simdgroup_matmul_64x64 ────────────────────────────────────────
echo ""
echo "=== Firing simdgroup_matmul_64x64 (FP16 MMA + FP32 accum) ==="
./host_64x64 ./simdgroup_matmul_64x64_tg.metallib
mv -f result.json result_matmul.json

echo ""
echo "=== Done ==="
date -u +"%Y-%m-%dT%H:%M:%SZ"
