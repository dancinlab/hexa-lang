#!/usr/bin/env bash
# run_own_tf32_production_path.sh — census r3 (7->0) PRODUCTION-PATH measurement on aiden.
#
# 1) emit runtime_cuda.c byte-identically from the edited runtime_cuda_emit.hexa
#    (tool/emit_runtime_cuda_via_python.py — no hexa binary needed),
# 2) build the harness that #includes the EMITTED runtime + calls the production
#    static fns _hx_cuda_gemm_tf32_own_dev / _hx_cuda_gemm_tf32_dev,
# 3) measure own/cuBLAS ratio + rel-RMS at d=512/1024/2048/4096.
#
# Run: bash tool/run_own_tf32_production_path.sh   (on aiden, sm_120, CUDA 13.0)
set -euo pipefail
export PATH=/usr/local/cuda-13.0/bin:$PATH
cd "$(git rev-parse --show-toplevel)"

OUT=/tmp/owntf_prod_$$
RC=$OUT.runtime_cuda.c
HARNESS=$OUT.harness.cu
BIN=$OUT.bin

echo "[1/3] emit runtime_cuda.c from runtime_cuda_emit.hexa"
python3 tool/emit_runtime_cuda_via_python.py self/cuda/runtime_cuda_emit.hexa "$RC"
echo "  new syms: $(grep -c '_hx_k_gemm_tf32_owngemm\|_hx_cuda_gemm_tf32_own_dev\|HEXA_TF32_OWN' "$RC")"

echo "[2/3] build harness (#include emitted runtime, sm_120)"
# substitute the emitted runtime path into the harness include
sed "s|\"OWNTF_RUNTIME_C\"|\"$RC\"|" tool/own_tf32_production_path.cu > "$HARNESS"

nvcc -O3 -arch=sm_120 -DHEXA_CUDA -x cu "$HARNESS" -o "$BIN" \
     -lcudart -lcublas -lcuda 2>&1 | tail -30

echo "[3/3] measure (HEXA_TF32_FASTMODE/OWN are honored inside the production dispatch)"
# The own dispatcher is called directly; HEXA_CUDA_ASYNC default off = default stream.
HEXA_TF32_FASTMODE=1 HEXA_TF32_OWN=1 "$BIN"
