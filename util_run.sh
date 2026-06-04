#!/usr/bin/env bash
set -uo pipefail
CU=self/native/hxqwen14b_cuda.cu
echo "=== env ==="; nvidia-smi --query-gpu=name --format=csv,noheader | head -1
# extract the 3 kernels + HXG_* defines (same range as build_and_measure.sh)
python3 - "$CU" > gemm_kernels_extracted.cuh <<'PY'
import sys
src=open(sys.argv[1]).read()
print(src[src.index('#define HXTILE 16'):src.index('// Host launcher for the own-GEMM kernel')])
PY
CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader|head -1|tr -d '.'); A=90; [ "$CC" -lt 90 ] && A=$CC
nvcc -O3 -arch=sm_${A} -lcublas util_loop.cu -o util_loop 2>&1 | tail -3
sample(){  # $1=label  — sample util while util_loop $2 runs
  ./util_loop "$2" 15 & P=$!
  S=""; while kill -0 $P 2>/dev/null; do u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits|head -1); S="$S $u"; sleep 0.2; done
  wait $P
  echo "$S" | tr ' ' '\n' | grep -E '^[0-9]+$' | awk '{s+=$1;n++; if($1>mx)mx=$1} END{printf "  %s util: MEAN %.1f%%  PEAK %d%%  (n=%d)\n","'"$1"'",s/n,mx,n}'
}
echo "=== util sustained-loop @2048^3 (15s each) ==="
sample "cuBLAS-TF32" cublas
sample "WMMA2(own)"  wmma2
echo "=== DONE ==="
