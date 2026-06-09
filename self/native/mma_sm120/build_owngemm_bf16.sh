#!/usr/bin/env bash
# build_owngemm_bf16.sh — build + run the sm_120 BF16 own-GEMM gate/perf/det on aiden.
# HEXA-0POD OP-3 / OP-3b. mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32, fp32 accum.
# OP-3b adds the .v2 (float2) vectorized C-store epilogue (the ONE bit-exact-positive
# lever from OP-1b) and a BYTE-IDENTITY cmp vs a -DEPILOGUE_SCALAR (OP-3 baseline) twin.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(dirname "$0")"
# .v2 epilogue binary (OP-3b)
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN "$D/owngemm_sm120_bf16.cu" -lcublas -o /tmp/owngemm_sm120_bf16
# scalar-store baseline binary (OP-3) for the byte-identity proof
nvcc -arch=sm_120 $INC -O3 -DOWNGEMM_MAIN -DEPILOGUE_SCALAR "$D/owngemm_sm120_bf16.cu" -lcublas -o /tmp/owngemm_sm120_bf16_scalar

echo "=== gate @ D=768 (rel-RMS vs FP64) ==="
/tmp/owngemm_sm120_bf16 768 0
echo "=== determinism @ D=1024 ==="
/tmp/owngemm_sm120_bf16 1024 2

echo "=== BYTE-IDENTITY: .v2 epilogue vs OP-3 scalar baseline (rel-RMS vs OP-3 = 0) ==="
for S in 1024 2048; do
  /tmp/owngemm_sm120_bf16        $S 3 /tmp/dump_v2_$S.bin     >/dev/null
  /tmp/owngemm_sm120_bf16_scalar $S 3 /tmp/dump_scalar_$S.bin >/dev/null
  if cmp -s /tmp/dump_v2_$S.bin /tmp/dump_scalar_$S.bin; then
    echo "  S=$S  .v2 vs OP-3-scalar: BYTE-IDENTICAL (cmp clean) — rel-RMS vs OP-3 = 0"
  else
    echo "  S=$S  .v2 vs OP-3-scalar: DIFFER ($(cmp -l /tmp/dump_v2_$S.bin /tmp/dump_scalar_$S.bin | wc -l) bytes) — FAIL"
  fi
done

echo "=== perf: .v2 epilogue (OP-3b) vs cuBLAS-BF16 ==="
for S in 1024 2048; do /tmp/owngemm_sm120_bf16 $S 1; done
echo "=== perf: OP-3 scalar baseline vs cuBLAS-BF16 (delta = .v2 lift) ==="
for S in 1024 2048; do /tmp/owngemm_sm120_bf16_scalar $S 1; done
