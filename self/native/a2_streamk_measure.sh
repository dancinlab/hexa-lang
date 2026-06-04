#!/usr/bin/env bash
# A2 stream-K on-pod build + measure. NOT committed to history beyond convenience.
# Builds the llmstep driver (which #include's hxqwen14b_cuda.cu with the new
# stream-K kernel) and runs: gate (correctness HARD GATE), pergemm (per-GEMM ms),
# util (steps/s). Three arms compared: cuBLAS / WMMA2+splitK / WMMA2+streamK.
set -uo pipefail
cd "$(dirname "$0")"
NVCC=$(command -v nvcc)
echo "=== nvcc: $NVCC ==="; nvcc --version | tail -2
echo "=== GPU ==="; nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

ARCH="${ARCH:-compute_90}"
echo "=== build (arch=$ARCH) ==="
nvcc -O3 -arch=$ARCH -o /tmp/llmstep hxqwen14b_llmstep_driver.cu -lcublas 2>&1 | tail -20
[ -x /tmp/llmstep ] || { echo "BUILD FAILED"; exit 3; }
echo "BUILD OK"

run(){ echo; echo "##### $* #####"; "$@"; }

echo
echo "================ §1 CORRECTNESS HARD GATE (stream-K vs cuBLAS oracle) ================"
# gate own-arm forces WMMA2; ambient STREAMK routes the skinny dA/dB through stream-K.
# Worst case M8192 K8192 N4096 R16 (dA/dB hit k=8192 -> G=16).
echo "--- stream-K gate (HEXA_OWN_GEMM_STREAMK=1) M8192 K8192 N4096 R16 ---"
HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_STREAMK=1 /tmp/llmstep gate 8192 8192 4096 16
echo "--- stream-K gate M512 K4096 N4096 R16 (k=4096 -> G=8) ---"
HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_STREAMK=1 /tmp/llmstep gate 512 4096 4096 16
echo "--- (ref) split-K gate same shape M8192 K8192 N4096 R16 ---"
HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_SPLITK=1 /tmp/llmstep gate 8192 8192 4096 16

echo
echo "================ §1b CONVERGENCE (30 real LoRA SGD steps) ================"
echo "--- cuBLAS ---"
/tmp/llmstep conv 256 4096 512 16 30 2>/dev/null | grep -E "step0|step15|step29|CE"
echo "--- stream-K ---"
HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_STREAMK=1 /tmp/llmstep conv 256 4096 512 16 30 2>/dev/null | grep -E "step0|step15|step29|CE"

echo
echo "================ §2 PER-GEMM (M8192 K4096 N4096 R16, 200 it) ================"
echo "--- cuBLAS ---"
/tmp/llmstep pergemm 8192 4096 4096 16 200 2>&1 | grep -E "GEMM\[|SUM|PERGEMM"
echo "--- WMMA2+splitK (current main) ---"
HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_SPLITK=1 /tmp/llmstep pergemm 8192 4096 4096 16 200 2>&1 | grep -E "GEMM\[|SUM|FIRED"
echo "--- WMMA2+streamK (THIS WORK) ---"
HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_STREAMK=1 /tmp/llmstep pergemm 8192 4096 4096 16 200 2>&1 | grep -E "GEMM\[|SUM|FIRED"

echo
echo "================ §2b G-SWEEP stream-K dA (M8192 K8192 N4096 -> dA k=8192) ================"
for G in 2 6 8 12 16 24 32; do
  printf "G=%-3s " $G
  HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_STREAMK=1 HEXA_OWN_GEMM_STREAMK_G=$G \
    /tmp/llmstep pergemm 8192 8192 4096 16 200 2>/dev/null | grep "bwd_dA" | awk '{print $5" ms"}'
done

echo
echo "================ §3 STEPS/SEC (util, 12s) ================"
for MK in "8192 4096" "16384 4096"; do
  set -- $MK; M=$1; KN=$2
  echo "----- M=$M K=N=$KN R16 -----"
  printf "cuBLAS              "; /tmp/llmstep util $M $KN $KN 16 12 2>/dev/null | grep UTIL-RUN
  printf "WMMA2 (no splitk)   "; HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 /tmp/llmstep util $M $KN $KN 16 12 2>/dev/null | grep UTIL-RUN
  printf "WMMA2+splitK        "; HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_SPLITK=1 /tmp/llmstep util $M $KN $KN 16 12 2>/dev/null | grep UTIL-RUN
  printf "WMMA2+streamK       "; HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_STREAMK=1 /tmp/llmstep util $M $KN $KN 16 12 2>/dev/null | grep UTIL-RUN
done

echo
echo "================ FIRED PROBE CHECK ================"
HEXA_OWN_GEMM=1 HEXA_OWN_GEMM_WMMA2=1 HEXA_OWN_GEMM_STREAMK=1 /tmp/llmstep pergemm 8192 8192 4096 16 5 2>&1 | grep "STREAMK-FIRED" || echo "WARN: STREAMK-FIRED not seen"
echo "=== DONE ==="
