#!/usr/bin/env bash
# avec_build_and_measure.sh — on the GPU pod: extract the split-K + float4-vec
# GEMM kernels from the shipped .cu, build the standalone A-VEC driver, run the
# cuBLAS vs scalar-split-K vs float4-vec A/B on dA/dB/square.
set -e
cd "$(dirname "$0")/.."   # repo root (tool/ is one level down)
CU=self/native/hxqwen14b_cuda.cu
OUT=tool/avec_kernels_extracted.cuh

# Extract from "#define HXSK 16" (just above betascale) through the END of
# _hx_k_sgemm_cm_splitk_vec (the line before the next "═" banner after it).
python3 - "$CU" > "$OUT" <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXSK 16')
# end = the banner line that immediately follows _hx_k_sgemm_cm_splitk_vec's closing brace.
anchor=src.index('_hx_k_sgemm_cm_splitk_vec(int tA')   # the __global__ def
# end = the banner immediately AFTER the vec kernel (the BF16 own-GEMM section);
# we extract ONLY betascale + splitk + splitk_vec (no bf16/wmma2 deps).
tail=src[anchor:]
end_rel=tail.index('// HEXA-FUSION C1 — BF16 own-GEMM')
end=anchor+end_rel
print(src[start:end])
PY

echo "=== extracted $(wc -l < "$OUT") lines ==="
grep -c '__global__' "$OUT" | sed 's/^/kernels: /'
grep -q '_hx_k_sgemm_cm_splitk_vec' "$OUT" && echo "vec kernel present: YES" || { echo "vec kernel MISSING"; exit 2; }

CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
echo "compute_cap=$CC"
ARCH=90; if [ "$CC" -lt 90 ]; then ARCH=$CC; fi
echo "building with -arch=sm_${ARCH}"

nvcc -O3 -arch=sm_${ARCH} -lcublas tool/avec_float4_driver.cu -o tool/avec_float4_driver \
  -I tool 2>&1 | tee tool/avec_build.log

echo "=== RUN (50 iters) ==="
./tool/avec_float4_driver 50
