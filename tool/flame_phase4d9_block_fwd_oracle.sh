#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4d9_block_fwd_oracle.sh — build + run the WHOLE-BLOCK
# fwd GPU-path byte-eq ORACLE (tool/flame_phase4d9_block_fwd_oracle.c).
#
# WHY
#   tool/flame_phase4d7_gpu_path_oracle covers ONE primitive. The Phase
#   4-D-9 device-chain conversion rewrites the ENTIRE block fwd
#   (RMSNorm/RoPE/attention/SwiGLU/residual) — without a CHEAP block-level
#   byte-eq oracle that rewrite is verifiable only by the 600 s / $0.17
#   d768 fire (the trap that burned 15 fires). This is that cheap gate at
#   BLOCK scope: d=384·nh6·nkv2·h512·T16, a config that crosses the block
#   dim-gate (d>256 → _gpu chain) AND every cuBLAS gate (d²=147456>8192).
#
# THE ASSEMBLY (generalises the d7 oracle's single-file awk-splice to TWO)
#   The oracle is built like the Phase 4-B-3 leaf tests + the d7 oracle:
#   ONE translation unit, no runtime.c. tool/flame_phase4d9_block_fwd_
#   oracle.c provides the farr-table shim + the forge surface shims + the
#   CPU/GPU compare main(). This script splices the TWO REAL primitives
#   (no fork) at the marker line, in the SAME order as the trainer's a2
#   build (tool/flame_phase4d7_a2_build.sh:132 `cat PRIM_MATMUL PRIM_FWD`):
#     1. tool/flame_phase4d6_matmul_primitives.c   (FIRST — the projection
#        primitive the block calls 7×; must be in scope for the block fwd)
#     2. tool/flame_phase4d7_block_fwd_primitive.c (the _cpu reference +
#        _gpu candidate + the dim-gated dispatch)
#   FLAME_BLOCK_PRIM_STANDALONE is NOT defined (matching the trainer build,
#   which concats after #include "runtime.c") — so the GPU body lives.
#
# MODES (identical contract to flame_phase4d7_gpu_path_oracle.sh)
#   (default, no-CUDA, $0 Mac/CI)
#       candidate = flame_block_generic_fwd_primitive_cpu
#       reference = flame_block_generic_fwd_primitive_cpu
#       → SAME function both sides → must be max|Δ|=0.0 STRICT. Proves the
#       harness wiring + the reference. This is the $0 gate. (It does NOT
#       exercise the GPU path — that needs nvcc; the forge no-CUDA helpers
#       use libm exp/sqrt vs the _cpu body's deterministic flame_g7, so a
#       no-CUDA _gpu run would measure the wrong gap.)
#   --cuda  (cheap GPU fire — $-cents, sub-second compute)
#       candidate = flame_block_generic_fwd_primitive_gpu (forge Phase B
#       kernels + cuBLAS) vs the _cpu reference → max|Δ| ≤ TOL_BLOCK 1e-8.
#       This is the BLOCK-level byte-eq gate that REPLACES the 600 s d768
#       fire for verifying the fwd device-chain conversion. On a no-CUDA
#       Mac --cuda does ONLY the SYNTACTIC `clang -c -DHEXA_CUDA` check
#       (the GPU branch compiles) — the numeric run needs a GPU host.
#
# USAGE
#   tool/flame_phase4d9_block_fwd_oracle.sh           # no-CUDA, build+run
#   tool/flame_phase4d9_block_fwd_oracle.sh --cuda    # GPU mode
#                                                     #   GPU host: build+run
#                                                     #   Mac: syntactic only
# ════════════════════════════════════════════════════════════════════════
set -e

CUDA=0
[ "$1" = "--cuda" ] && CUDA=1

ORACLE_C="tool/flame_phase4d9_block_fwd_oracle.c"
PRIM_MATMUL="tool/flame_phase4d6_matmul_primitives.c"   # spliced FIRST
PRIM_FWD="tool/flame_phase4d7_block_fwd_primitive.c"     # spliced SECOND
MARKER='//@FLAME_ORACLE_SPLICE_MARKER@'

mkdir -p build/artifacts
ASSEMBLED="build/artifacts/flame_phase4d9_block_fwd_oracle_assembled.c"

for f in "$ORACLE_C" "$PRIM_MATMUL" "$PRIM_FWD"; do
    if [ ! -f "$f" ]; then
        echo "FATAL: missing $f"
        exit 2
    fi
done

# Splice: everything in the oracle .c UP TO the marker, then the two real
# primitive files in a2-build order (matmul FIRST, then block fwd), then
# everything AFTER the marker (the generators + main). awk keeps it a
# single deterministic pass — generalises the d7 oracle's one-file splice.
awk -v p1="$PRIM_MATMUL" -v p2="$PRIM_FWD" -v marker="$MARKER" '
    $0 ~ marker && !done {
        print
        print "// ─── splice 1/2 (a2 order: FIRST): " p1 " ───"
        while ((getline line < p1) > 0) print line
        close(p1)
        print "// ─── splice 2/2 (a2 order: SECOND): " p2 " ───"
        while ((getline line < p2) > 0) print line
        close(p2)
        done=1
        next
    }
    { print }
' "$ORACLE_C" > "$ASSEMBLED"

echo "═══ flame WHOLE-BLOCK fwd GPU-path byte-eq oracle ═══"
echo "  assembled : $ASSEMBLED  ($(wc -l < "$ASSEMBLED" | tr -d ' ') lines)"
echo "  spliced   : $PRIM_MATMUL  →  $PRIM_FWD  (a2 concat order)"

if [ "$CUDA" -eq 1 ]; then
    # GPU mode. On a CUDA host nvcc compiles + links runtime_cuda; on a
    # no-CUDA Mac fall back to a syntactic compile-check of the GPU branch.
    if command -v nvcc >/dev/null 2>&1; then
        OUT="build/flame_phase4d9_block_fwd_oracle_cuda"
        echo "  mode      : --cuda  (GPU host — build + run)"
        nvcc -O2 -DHEXA_CUDA -x cu "$ASSEMBLED" \
             self/cuda/runtime_cuda.c -lcublas -lm -o "$OUT"
        echo "  built     : $OUT"
        echo ""
        "$OUT"
        exit $?
    else
        echo "  mode      : --cuda  (no nvcc — SYNTACTIC compile-check only)"
        # nvcc builds via `-x cu` which ALWAYS parses as C++. The strongest
        # $0 syntactic proxy is therefore a C++ parse of the assembled TU
        # (clang++ -x c++): it is the ONLY no-GPU check that exercises the
        # C-linkage contract (a missing `extern "C"` → MANGLED _hx_cuda_*
        # call site, the fire that cost a --cuda link 2026-05-18). A plain
        # `clang -c` (C mode) cannot catch that. We do BOTH: the C parse
        # (matches the no-CUDA TU shape) and the C++ parse (matches the
        # nvcc front-end). Either failing => not SYNTACTIC-PASS.
        OBJ_C="build/artifacts/flame_phase4d9_block_fwd_oracle_cuda_c.o"
        OBJ_CXX="build/artifacts/flame_phase4d9_block_fwd_oracle_cuda_cxx.o"
        clang   -O2 -DHEXA_CUDA -c "$ASSEMBLED" \
                -I self -I self/cuda -o "$OBJ_C"
        echo "  built .o  : $OBJ_C  (C parse — GPU branch compiles clean)"
        clang++ -O2 -DHEXA_CUDA -x c++ -std=c++14 -c "$ASSEMBLED" \
                -I self -I self/cuda -o "$OBJ_CXX"
        echo "  built .o  : $OBJ_CXX  (C++ parse — the nvcc front-end;"
        echo "              proves the extern \"C\" linkage contract holds)"
        echo ""
        echo "SYNTACTIC-PASS  GPU branch compiles under -DHEXA_CUDA in"
        echo "                BOTH the C and the C++ (nvcc front-end)"
        echo "                parses. Numeric run needs a GPU host — see"
        echo "                PHASE4D9_BLOCK_FWD_ORACLE.md 'How to run'."
        exit 0
    fi
else
    OUT="build/flame_phase4d9_block_fwd_oracle"
    echo "  mode      : no-CUDA  (CPU block vs CPU block — \$0 gate)"
    clang -O2 "$ASSEMBLED" -lm -o "$OUT"
    echo "  built     : $OUT"
    echo ""
    "$OUT"
    exit $?
fi
