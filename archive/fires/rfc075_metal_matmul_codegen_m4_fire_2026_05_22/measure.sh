#!/bin/bash
# measure.sh — RFC 075 P3++ codegen-emitted matmul MSL fire on Apple M4 (mini).
#
# Step 1: compile the VERBATIM codegen output (matmul_codegen.metal) — expected
#         to FAIL (documents the codegen compile bug).
# Step 2: compile the 1-token-patched variant (matmul_codegen_fixed.metal) ->
#         .air -> .metallib.
# Step 3: build + run the Swift host -> numeric-eq + GFLOPS.
#
# Run on mini:  ./measure.sh [DIM]   (DIM default 256)
set -u
DIM="${1:-256}"
echo "=== RFC 075 P3++ codegen matmul fire — Apple M4 (mini) — DIM=$DIM ==="

echo "--- step 1: compile VERBATIM codegen output (expect FAIL) ---"
xcrun --sdk macosx metal -c matmul_codegen.metal -o matmul_codegen.air 2>&1
echo "verbatim_codegen_compile_exit=$?"

echo "--- step 2: compile 1-token-patched codegen output ---"
xcrun --sdk macosx metal -c matmul_codegen_fixed.metal -o matmul_codegen_fixed.air 2>&1
rc=$?
echo "patched_codegen_compile_exit=$rc"
if [ $rc -ne 0 ]; then echo "ABORT: patched variant did not compile"; exit 1; fi
xcrun --sdk macosx metallib matmul_codegen_fixed.air -o matmul_codegen_fixed.metallib 2>&1
echo "metallib_exit=$?"

echo "--- step 3: build + run Swift host ---"
xcrun --sdk macosx swiftc -O host_matmul.swift -o host_matmul 2>&1
echo "swiftc_exit=$?"
./host_matmul ./matmul_codegen_fixed.metallib "$DIM"
echo "host_exit=$?"
