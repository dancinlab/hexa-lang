#!/usr/bin/env bash
# own_tf32_mma_gate.sh — census r3 verify gate for the own TF32 mma.sync GEMM
# that replaces the forge runtime's last cuBLAS dependency (cublasGemmEx).
# ============================================================================
# Builds tool/own_tf32_mma_verify.cu (a byte-copy of the emitted
# _hx_k_gemm_tf32_mma kernel in self/cuda/runtime_cuda_emit.hexa) for the host
# GPU arch and checks, per square GEMM size:
#   (1) own-TF32 vs FP64 ref rel-RMS == cublasGemmEx-TF32 vs FP64 ref rel-RMS
#       (within TF32 tol) — the own kernel is AS accurate as the cuBLAS oracle.
#   (2) own-TF32 vs cublasGemmEx-TF32 agreement rel-RMS <= TF32_AGREE_TOL
#       (both are valid TF32 GEMMs; tiny accum-order delta).
# This is a CORRECTNESS gate (NOT byte-eq — TF32 is lossy ~10-bit mantissa).
# Speed is REPORTED (own/cublas ratio) but NOT gated: on consumer Blackwell
# (sm_120, no wgmma) the naive 1-warp WMMA kernel is ~8-19x slower than cuBLAS
# (the measured consumer mma.sync ceiling — see census r3 verdict); the own
# kernel exists to make the forge GEMM cuBLAS-INDEPENDENT, not to beat cuBLAS.
#
# REQUIRES an NVIDIA GPU + nvcc + cuBLAS. NO-OP-SKIP (exit 0) on a no-GPU host
# so a CPU-only CI lane is not broken (mirrors own_gemm_perf_gate.sh).
#
# CI INVOCATION:  bash tool/hexa-fusion/own_tf32_mma_gate.sh
#   HEXA_GATE_ARCH=sm_120 bash .../own_tf32_mma_gate.sh   # override arch
#   TF32_AGREE_TOL=1e-4   bash .../own_tf32_mma_gate.sh   # override agree tol
# Exit 0 = PASS (or SKIP no-GPU), 1 = FAIL.
# ============================================================================
set -o pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/tool/own_tf32_mma_verify.cu"
ARCH="${HEXA_GATE_ARCH:-sm_120}"
AGREE_TOL="${TF32_AGREE_TOL:-1e-4}"

if ! command -v nvcc >/dev/null 2>&1; then
  echo "[own-tf32-gate] SKIP: nvcc not found — gate requires a GPU CI runner."; exit 0
fi
if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi -L >/dev/null 2>&1; then
  echo "[own-tf32-gate] SKIP: no NVIDIA GPU visible — gate requires a GPU CI runner."; exit 0
fi
[ -f "$SRC" ] || { echo "[own-tf32-gate] FAIL: missing $SRC"; exit 1; }

BIN="$(mktemp -d)/own_tf32"
echo "[own-tf32-gate] building $SRC (arch=$ARCH) ..."
if ! nvcc -O3 -arch="$ARCH" "$SRC" -lcublas -lcudart -o "$BIN" 2>&1; then
  echo "[own-tf32-gate] BUILD FAILED"; rm -rf "$(dirname "$BIN")"; exit 1
fi
OUT="$("$BIN" 2>&1)"; echo "$OUT"
rm -rf "$(dirname "$BIN")"

echo "$OUT" | grep -q "OWN-TF32-MMA-VERIFY DONE" || { echo "[own-tf32-gate] FAIL: run did not complete"; exit 1; }

# Parse each "own/cublas=X.XXXe-NN" agreement and assert <= AGREE_TOL.
FAIL=0
while IFS= read -r line; do
  case "$line" in
    d=*) AG="$(printf '%s\n' "$line" | sed -nE 's/.*own\/cublas=([0-9.eE+-]+).*/\1/p')"
         awk -v a="$AG" -v t="$AGREE_TOL" 'BEGIN{exit !(a+0 <= t+0)}' \
           || { echo "[own-tf32-gate] FAIL: own-vs-cublas agreement $AG > $AGREE_TOL ($line)"; FAIL=1; } ;;
  esac
done <<< "$OUT"

[ "$FAIL" -eq 0 ] && { echo "[own-tf32-gate] PASS: own-TF32 mma.sync agrees with cublasGemmEx-TF32 within $AGREE_TOL"; exit 0; }
exit 1
