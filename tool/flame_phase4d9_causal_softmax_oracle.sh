#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4d9_causal_softmax_oracle.sh — build + run the
# causal-softmax byte-eq ORACLE (tool/flame_phase4d9_causal_softmax_
# oracle.c) for flame Phase 4-D-9 §4 gap #1.
#
# WHY
#   The forge softmax kernel softmaxes the FULL row; the attention block
#   needs a per-row CAUSAL-prefix softmax (j∈[0,i+1)) using flame_g7_dt_
#   exp (deterministic poly exp, NOT libm exp). This harness byte-eq-
#   checks the NEW additive forge kernel (the 14th — the 12 verified +
#   RFC 058 13th UNTOUCHED) at a cheap config. Same cheap-fire pattern as
#   tool/flame_phase4d7_gpu_path_oracle.sh.
#
# THE ASSEMBLY
#   The oracle is ONE translation unit (no runtime.c) like the Phase
#   4-B-3 leaf tests. Unlike flame_phase4d7 it needs NO splice — the
#   .c calls the runtime_cuda.c wrapper directly. no-CUDA: the .c is
#   self-contained (CPU-vs-CPU self-check). --cuda: it is linked against
#   self/cuda/runtime_cuda.c so the candidate is the real forge kernel.
#
# MODES
#   (default, no-CUDA, $0 Mac/CI)
#       CPU candidate (independent eval) vs CPU reference → must be
#       max|Δ|=0.0 STRICT. Proves the harness wiring + the reference.
#   --cuda  (cheap GPU fire — $-cents, sub-second compute)
#       real _hx_cuda_farr_causal_softmax_rows_gpu kernel vs CPU
#       reference → max|Δ| ≤ TOL 1e-12 (per-row reduction reorder only;
#       _hx_dt_exp_dev == flame_g7_dt_exp so no exp-algorithm gap).
#       On a no-CUDA Mac --cuda only does the SYNTACTIC `clang -c`
#       check (the GPU branch compiles); the numeric run needs a GPU.
#
# USAGE
#   tool/flame_phase4d9_causal_softmax_oracle.sh            # no-CUDA
#   tool/flame_phase4d9_causal_softmax_oracle.sh --cuda     # GPU mode
#                                                  #   GPU host: build+run
#                                                  #   Mac: syntactic only
# ════════════════════════════════════════════════════════════════════════
set -e

CUDA=0
[ "$1" = "--cuda" ] && CUDA=1

ORACLE_C="tool/flame_phase4d9_causal_softmax_oracle.c"

if [ ! -f "$ORACLE_C" ]; then
    echo "FATAL: missing $ORACLE_C"
    exit 2
fi

mkdir -p build/artifacts

echo "═══ flame Phase 4-D-9 causal-softmax byte-eq oracle ═══"
echo "  oracle : $ORACLE_C"

if [ "$CUDA" -eq 1 ]; then
    # GPU mode. On a CUDA host nvcc compiles + links runtime_cuda; on a
    # no-CUDA Mac fall back to a syntactic compile-check of the GPU branch.
    if command -v nvcc >/dev/null 2>&1; then
        OUT="build/flame_phase4d9_causal_softmax_oracle_cuda"
        echo "  mode   : --cuda  (GPU host — build + run)"
        nvcc -O2 -DHEXA_CUDA -x cu "$ORACLE_C" \
             self/cuda/runtime_cuda.c -lcublas -lm -o "$OUT"
        echo "  built  : $OUT"
        echo ""
        "$OUT"
        exit $?
    else
        echo "  mode   : --cuda  (no nvcc — SYNTACTIC compile-check only)"
        OBJ="build/artifacts/flame_phase4d9_causal_softmax_oracle_cuda.o"
        clang -O2 -DHEXA_CUDA -c "$ORACLE_C" -I self -I self/cuda -o "$OBJ"
        echo "  built .o : $OBJ  (GPU branch compiles clean)"
        echo ""
        echo "SYNTACTIC-PASS  GPU branch compiles under -DHEXA_CUDA."
        echo "                Numeric run needs a GPU host — see"
        echo "                PHASE4D9_CAUSAL_SOFTMAX_ORACLE.md 'How to run'."
        exit 0
    fi
else
    OUT="build/flame_phase4d9_causal_softmax_oracle"
    echo "  mode   : no-CUDA  (CPU candidate vs CPU reference — \$0 gate)"
    clang -O2 "$ORACLE_C" -lm -o "$OUT"
    echo "  built  : $OUT"
    echo ""
    "$OUT"
    exit $?
fi
