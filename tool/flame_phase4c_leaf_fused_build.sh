#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# tool/flame_phase4c_leaf_fused_build.sh — Phase 4-C-2c byte-eq harness build
#
# Builds tool/flame_phase4c_leaf_fused_test.c which runs:
#   1. Paired primitive (fwd then bwd back-to-back) → reference
#   2. Fused primitive (the unit-under-test) → fresh output
#   3. max|Δ| diff on Bc, dX_out, Bg → F-RFC048-FUSED-FWD-BWD-EQ verdict
#   4. N-iter wall micro-bench (paired vs fused)
#
# Concats:
#   - tool/flame_phase4c_leaf_fused_test.c              (test driver + mocks)
#   - tool/flame_phase4b3_matmul_primitives.c           (Path B matmul/grad_accum)
#   - tool/flame_phase4b3_block_fwd_primitive.c         (fwd primitive body)
#   - tool/flame_phase4b3_block_bwd_primitive.c         (bwd primitive body)
#   - tool/flame_phase4c_block_fused_primitive.c        (FUSED — UUT)
#
# The fwd/bwd/fused primitive files have #ifdef FLAME_BLOCK_*_PRIM_STANDALONE
# blocks with redundant typedef stubs — strip them via sed since we provide
# the mocks via the test driver header.
#
# Build out: build/leaf_fused_test
# Run:       ./build/leaf_fused_test
# Falsifier: F-RFC048-FUSED-FWD-BWD-EQ in stdout
# ════════════════════════════════════════════════════════════════════════

set -e

mkdir -p build/artifacts

OUT=build/leaf_fused_test
CONCAT=build/artifacts/leaf_fused_test_concat.c

# Strip the `#ifdef FLAME_BLOCK_PRIM_STANDALONE ... #endif` block from a file.
# Robust line-range strip: emit content between matching #ifdef/#endif.
strip_standalone_block() {
    local src="$1"
    local guard="$2"
    # awk: print lines except when inside `#ifdef <guard> ... #endif` block.
    awk -v g="$guard" '
        BEGIN { skip = 0; depth = 0 }
        {
            # Match `#ifdef <guard>` exactly
            if (skip == 0 && $0 ~ "^[[:space:]]*#ifdef[[:space:]]+" g "[[:space:]]*$") {
                skip = 1; depth = 1; next
            }
            if (skip == 1) {
                if ($0 ~ "^[[:space:]]*#if(def|ndef)?") depth++
                if ($0 ~ "^[[:space:]]*#endif") {
                    depth--
                    if (depth == 0) { skip = 0; next }
                }
                next
            }
            print
        }
    ' "$src"
}

# Strip the `#ifndef FLAME_BLOCK_*_STANDALONE ... #endif` (extern decls block)
# We DO want the externs (they declare _db_proj_batch_farr / _db_grad_accum_farr
# as prototypes for the never-called branch). But the typedef block must go.

{
    cat tool/flame_phase4c_leaf_fused_test.c
    echo ""
    echo "// ── matmul primitives ─────────────────────────────────────"
    cat tool/flame_phase4b3_matmul_primitives.c
    echo ""
    echo "// ── fwd primitive ─────────────────────────────────────────"
    strip_standalone_block tool/flame_phase4b3_block_fwd_primitive.c FLAME_BLOCK_PRIM_STANDALONE
    echo ""
    echo "// ── bwd primitive ─────────────────────────────────────────"
    strip_standalone_block tool/flame_phase4b3_block_bwd_primitive.c FLAME_BLOCK_BWD_PRIM_STANDALONE
    echo ""
    echo "// ── fused primitive (UUT) ─────────────────────────────────"
    strip_standalone_block tool/flame_phase4c_block_fused_primitive.c FLAME_BLOCK_FUSED_PRIM_STANDALONE
} > "$CONCAT"

# The fwd/bwd primitive's `#ifndef FLAME_BLOCK_*_STANDALONE` block declares
# the extern _db_proj_batch_farr / _db_grad_accum_farr prototypes. We need
# them OFF (no decl) because in our test harness those externs are not
# called. The #ifndef stays in our concat'd file with the guard undefined,
# so the extern decl WILL be emitted — that's fine (prototype-only, never
# linked since never called).

clang -O2 -Wno-deprecated-non-prototype -Wno-incompatible-pointer-types \
    "$CONCAT" -lm -o "$OUT" 2>&1 | head -30

if [ -x "$OUT" ]; then
    echo ""
    echo "✓ Built: $OUT  ($(wc -l < "$CONCAT" | tr -d ' ') lines concat)"
    echo "  Run:   ./$OUT"
else
    echo ""
    echo "✗ Build FAILED — see clang output above"
    exit 2
fi
