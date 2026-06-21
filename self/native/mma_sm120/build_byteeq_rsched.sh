#!/usr/bin/env bash
# build_byteeq_rsched.sh — Round A: build baseline + r-sched variant into one
# byte-eq harness on aiden, prove bitdiff==0 + run2run==0, and report off-ratio.
set -eu
export PATH=/usr/local/cuda/bin:/usr/local/cuda/nvvm/bin:$PATH
INC=-I/usr/local/cuda/targets/x86_64-linux/include
D="$(cd "$(dirname "$0")" && pwd)"
cd "$D"

# Compile each variant as an object, renaming its two entry symbols so they
# coexist. Baseline -> owngemm_base/gemm_base ; rsched -> owngemm_var/gemm_var.
nvcc -arch=sm_120 $INC -O3 -dc owngemm_sm120.cu \
     -Downgemm_sm120=owngemm_base -Dgemm_sm120=gemm_base -o /tmp/base.o
nvcc -arch=sm_120 $INC -O3 -dc owngemm_sm120_rsched.cu \
     -Downgemm_sm120=owngemm_var -Dgemm_sm120=gemm_var -o /tmp/var.o
nvcc -arch=sm_120 $INC -O3 -dc byteeq_harness.cu -o /tmp/he.o
nvcc -arch=sm_120 /tmp/he.o /tmp/base.o /tmp/var.o -lcublas -o /tmp/byteeq_rsched

echo "=== ROUND A r-sched: byte-eq + off-ratio sweep ==="
for S in 512 1024 1536 2048 3072; do /tmp/byteeq_rsched $S 1; done
