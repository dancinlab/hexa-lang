#!/usr/bin/env bash
# llm_own_gemm_gate.sh — HEXA-FUSION ③ CI regression gate for the LLM (hxqwen14b)
# WMMA2 own-GEMM vs cuBLAS oracle.
# ============================================================================
# Builds the standalone LoRA fwd+bwd driver (which #includes the shipped
# self/native/hxqwen14b_cuda.cu so the EXACT shipped WMMA2 kernel is exercised),
# runs ONE process that computes y/dA/dB/dx under cuBLAS (HEXA_OWN_GEMM unset)
# AND under our WMMA2 own-GEMM (HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1), and
# fails (nonzero exit) if any output's rel-RMS exceeds the TF32 tolerance.
#
# This catches a future regression that breaks WMMA2 correctness (e.g. a wrong
# K-frag stride, a transpose bug, a bad epilogue) before it ships.
#
# REQUIRES: an NVIDIA GPU + nvcc + cuBLAS (CUDA toolkit). NO-OP-SKIP (exit 0 with
# a SKIP message) on a host with no GPU/nvcc so a CPU-only CI lane is not broken;
# a GPU CI lane should treat a SKIP as "gate not run" and ensure a GPU runner.
#
# CI INVOCATION:
#   bash tool/hexa-fusion/llm_own_gemm_gate.sh                 # default shapes + 3e-3 tol
#   HEXA_GATE_TOL=1e-3 bash tool/hexa-fusion/llm_own_gemm_gate.sh
#   GATE_M=512 GATE_K=2048 GATE_N=2048 GATE_R=16 bash .../llm_own_gemm_gate.sh
# Exit 0 = PASS, 1 = FAIL (regression), 0+SKIP = no GPU/nvcc available.
# ============================================================================
set -o pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/self/native/hxqwen14b_llmstep_driver.cu"
CU="$ROOT/self/native/hxqwen14b_cuda.cu"
ARCH="${HEXA_GATE_ARCH:-compute_90}"   # PTX target; sm_90 JITs to Blackwell too
M="${GATE_M:-256}"; K="${GATE_K:-1024}"; N="${GATE_N:-1024}"; R="${GATE_R:-16}"

if ! command -v nvcc >/dev/null 2>&1; then
  echo "[gate] SKIP: nvcc not found (no CUDA toolkit) — gate requires a GPU CI runner."
  exit 0
fi
if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi -L >/dev/null 2>&1; then
  echo "[gate] SKIP: no NVIDIA GPU visible — gate requires a GPU CI runner."
  exit 0
fi

BIN="$(mktemp -d)/llm_gate"
echo "[gate] building $SRC (arch=$ARCH) ..."
if ! nvcc -O3 -arch="$ARCH" -DHXQWEN14B_CUDA -Xcompiler -fPIC "$SRC" \
        -lcuda -lcudart -lcublas -lm -o "$BIN" 2>&1 | grep -v "declared but never"; then
  echo "[gate] BUILD FAILED"; exit 1
fi
[ -x "$BIN" ] || { echo "[gate] BUILD FAILED (no binary)"; exit 1; }

echo "[gate] running WMMA2-vs-cuBLAS rel-RMS compare (M=$M K=$K N=$N R=$R, tol=${HEXA_GATE_TOL:-3e-3}) ..."
"$BIN" gate "$M" "$K" "$N" "$R"
rc=$?
rm -rf "$(dirname "$BIN")"
if [ "$rc" -eq 0 ]; then echo "[gate] RESULT: PASS"; else echo "[gate] RESULT: FAIL (own-GEMM rel-RMS regression)"; fi
exit "$rc"
