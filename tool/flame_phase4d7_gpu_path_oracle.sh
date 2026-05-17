#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4d7_gpu_path_oracle.sh — build + run the d768 GPU-path
# byte-eq ORACLE (tool/flame_phase4d7_gpu_path_oracle.c).
#
# WHY
#   The d768 GPU-resident path had no byte-eq oracle (only d=32 did) — the
#   RFC 058 regression was caught only at the 13th paid d768 fire. This
#   harness byte-checks the SAME GPU-path code at a CHEAP mid-size config
#   (d_out=d_in=96, M·K=9216 > the 8192 GPU dim-gate). See the .c header.
#
# THE ASSEMBLY
#   The oracle is built like the Phase 4-B-3 leaf tests: ONE translation
#   unit, no runtime.c. tool/flame_phase4d7_gpu_path_oracle.c provides the
#   farr-table shim + the CPU reference + main(); this script splices the
#   REAL tool/flame_phase4d6_matmul_primitives.c (the code the d768 trainer
#   compiles — no fork) in at the marker line so main() calls the genuine
#   flame_proj_batch_generic_primitive.
#
# MODES
#   (default, no-CUDA, $0 Mac/CI)
#       CPU-primitive  vs  CPU-reference  → must be max|Δ|=0.0 STRICT.
#       Proves the harness wiring + the reference. This is the $0 gate.
#   --cuda  (cheap GPU fire — $-cents, sub-second compute)
#       GPU cuBLAS Dgemm (+ transpose-scatter kernel once revived) vs
#       CPU-reference → max|Δ| ≤ TOL_OP 3e-11. This is the d768 GPU-path
#       byte-eq gate that REPLACES the 600 s d768 fire for verification.
#       On a no-CUDA Mac --cuda only does the SYNTACTIC `clang -c` check
#       (the GPU branch compiles); the numeric run needs a GPU host.
#
# USAGE
#   tool/flame_phase4d7_gpu_path_oracle.sh            # no-CUDA, build+run
#   tool/flame_phase4d7_gpu_path_oracle.sh --cuda     # GPU mode
#                                                     #   GPU host: build+run
#                                                     #   Mac: syntactic only
# ════════════════════════════════════════════════════════════════════════
set -e

CUDA=0
[ "$1" = "--cuda" ] && CUDA=1

ORACLE_C="tool/flame_phase4d7_gpu_path_oracle.c"
PRIM_C="tool/flame_phase4d6_matmul_primitives.c"
MARKER='//@FLAME_ORACLE_SPLICE_MARKER@'

mkdir -p build/artifacts
ASSEMBLED="build/artifacts/flame_phase4d7_gpu_path_oracle_assembled.c"

if [ ! -f "$ORACLE_C" ] || [ ! -f "$PRIM_C" ]; then
    echo "FATAL: missing $ORACLE_C or $PRIM_C"
    exit 2
fi

# Splice: everything in the oracle .c UP TO the marker, then the real
# matmul-primitives file, then everything AFTER the marker (the CPU
# reference + main). awk keeps it a single deterministic pass.
awk -v prim="$PRIM_C" -v marker="$MARKER" '
    $0 ~ marker && !done {
        print
        print "// ─── splice: " prim " ───"
        while ((getline line < prim) > 0) print line
        close(prim)
        done=1
        next
    }
    { print }
' "$ORACLE_C" > "$ASSEMBLED"

echo "═══ flame d768 GPU-path byte-eq oracle ═══"
echo "  assembled : $ASSEMBLED"

if [ "$CUDA" -eq 1 ]; then
    # GPU mode. On a CUDA host nvcc compiles + links runtime_cuda; on a
    # no-CUDA Mac fall back to a syntactic compile-check of the GPU branch.
    if command -v nvcc >/dev/null 2>&1; then
        OUT="build/flame_phase4d7_gpu_path_oracle_cuda"
        echo "  mode      : --cuda  (GPU host — build + run)"
        nvcc -O2 -DHEXA_CUDA -x cu "$ASSEMBLED" \
             self/cuda/runtime_cuda.c -lcublas -lm -o "$OUT"
        echo "  built     : $OUT"
        echo ""
        "$OUT"
        exit $?
    else
        echo "  mode      : --cuda  (no nvcc — SYNTACTIC compile-check only)"
        OBJ="build/artifacts/flame_phase4d7_gpu_path_oracle_cuda.o"
        clang -O2 -DHEXA_CUDA -c "$ASSEMBLED" -I self -I self/cuda -o "$OBJ"
        echo "  built .o  : $OBJ  (GPU branch compiles clean)"
        echo ""
        echo "SYNTACTIC-PASS  GPU branch compiles under -DHEXA_CUDA."
        echo "                Numeric run needs a GPU host — see"
        echo "                PHASE4D7_GPU_PATH_ORACLE.md 'How to run'."
        exit 0
    fi
else
    OUT="build/flame_phase4d7_gpu_path_oracle"
    echo "  mode      : no-CUDA  (CPU primitive vs CPU reference — \$0 gate)"
    clang -O2 "$ASSEMBLED" -lm -o "$OUT"
    echo "  built     : $OUT"
    echo ""
    "$OUT"
    exit $?
fi
