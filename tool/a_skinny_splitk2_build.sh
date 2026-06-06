#!/usr/bin/env bash
# a_skinny_splitk2_build.sh — on the GPU pod: extract the split-K family
# (betascale + scalar splitk + two-pass splitk2 + float4 vec) from the shipped
# .cu, build the A-SKINNY two-pass driver, run cuBLAS vs scalar-split-K vs
# two-pass on the 5 real R=16 LoRA skinny GEMMs + a square reference.
set -e
cd "$(dirname "$0")/.."   # repo root (tool/ is one level down)
CU=self/native/hxqwen14b_cuda.cu
OUT=tool/avec_kernels_extracted.cuh

# Extract from "#define HXSK 16" through the line before the BF16 banner — this
# range now contains betascale + splitk + splitk2_partial + splitk2_reduce + vec.
python3 - "$CU" > "$OUT" <<'PY'
import sys
src=open(sys.argv[1]).read()
start=src.index('#define HXSK 16')
anchor=src.index('_hx_k_sgemm_cm_splitk_vec(int tA')
tail=src[anchor:]
end_rel=tail.index('// HEXA-FUSION C1 — BF16 own-GEMM')
end=anchor+end_rel
print(src[start:end])
PY

echo "=== extracted $(wc -l < "$OUT") lines ==="
grep -c '__global__' "$OUT" | sed 's/^/kernels: /'
for k in _hx_k_sgemm_cm_splitk2_partial _hx_k_sgemm_cm_splitk2_reduce; do
  grep -q "$k" "$OUT" && echo "$k present: YES" || { echo "$k MISSING"; exit 2; }
done

CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
echo "compute_cap=$CC"
ARCH=90; if [ "$CC" -lt 90 ]; then ARCH=$CC; fi
echo "building with -arch=sm_${ARCH}"

nvcc -O3 -arch=sm_${ARCH} -lcublas tool/a_skinny_splitk2_driver.cu -o tool/a_skinny_splitk2_driver \
  -I tool 2>&1 | tee tool/a_skinny_splitk2_build.log

echo "=== RUN (200 iters) ==="
./tool/a_skinny_splitk2_driver 200
