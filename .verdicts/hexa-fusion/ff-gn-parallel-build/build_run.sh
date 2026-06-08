#!/usr/bin/env bash
# FF-GN-PARALLEL reproducer — build + run the fixed-order parallel-tree GN gate on a CUDA pod.
# Usage: scp gn_tree.cu to the pod, then: bash build_run.sh [iters]
set -euo pipefail
ITERS="${1:-100}"
nvcc -O3 -arch=sm_90 -o gn_tree gn_tree.cu
./gn_tree "$ITERS"
# Expected (H100 sm_90, FP64, T=512 C=1536 G=1):
#   GATE1 DETERMINISM  : fwd Y / bwd DX run-to-run max|delta|=0 bitdiff=0  -> DETERMINISTIC PASS
#   GATE2 REBASELINE   : fwd 2.55e-14 / bwd 1.27e-14 vs single-thread seq oracle (machine-eps)
#   GATE3 SPEEDUP      : fwd ~3600x, bwd_dx ~6800x, GN total ~4900x (seq ~94/118 ms -> tree ~0.03/0.02 ms)
