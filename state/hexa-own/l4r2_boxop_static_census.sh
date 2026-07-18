#!/usr/bin/env bash
# L4 round-2 boxing STATIC census — measure-first for the next unboxing lever.
# Read-only grep buckets over the compiler source (no build). Complements the two
# DYNAMIC env-gated counters (HEXA_CALLTYPE_CENSUS producer @ ast_to_hir.hexa,
# HEXA_BOXOP_CENSUS consumer @ x86_64_linux.hexa) whose live numbers need an aiden
# from-source compile of real code. Run from repo root: bash state/hexa-own/l4r2_boxop_static_census.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
AST=compiler/lower/ast_to_hir.hexa
X86=compiler/codegen/x86_64_linux.hexa
CHK=compiler/check/types.hexa

echo "== L4 round-2 boxing static census =="
echo "-- (a) UNSTAMPED-builtin residual: mirrored prim-stamp arms vs checker full table --"
# the HIR-side mirrored primitive-return table (_hir_builtin_method_ret_prim arms)
mirrored=$(grep -cE '"[a-z_0-9]+"[[:space:]]*->' "$AST" 2>/dev/null)
# the authoritative checker table (_types_builtin_method_ret arms)
checker=$(awk '/_types_builtin_method_ret/{f=1} f&&/->/{c++} f&&/^fn /&&!/_types_builtin_method_ret/{if(seen)exit} /_types_builtin_method_ret/{seen=1} END{print c+0}' "$CHK" 2>/dev/null)
echo "   mirrored HIR prim-stamp arms (approx grep): $mirrored"
echo "   checker _types_builtin_method_ret arms   : ${checker:-N/A}"
echo "   → DELTA (checker - mirrored) = residual UNSTAMPED-builtin bucket (container/string/element-return)"

echo "-- (b) boxed-operand box sites (consumer) --"
box_sites=$(grep -c '_x86_hv_box_arg' "$X86" 2>/dev/null)
echo "   _x86_hv_box_arg call sites: $box_sites"

echo "-- (c) boxed arith/cmp dispatch labels --"
dispatch=$(grep -cE 'hexa_add|hexa_sub|hexa_mul|_x86_hv_arith_sym|_x86_hv_cmp_sym' "$X86" 2>/dev/null)
echo "   boxed arith/cmp dispatch refs: $dispatch"

echo ""
echo "== dynamic census (needs aiden from-source compiler on real corpus) =="
echo "   producer: HEXA_CALLTYPE_CENSUS=1 <compiler> <src>  2>&1 | grep '\\[CALLTYPE\\]' | sort | uniq -c"
echo "   consumer: HEXA_BOXOP_CENSUS=1    <compiler> <src>  2>&1 | grep '\\[BOXOP\\]'    | sort | uniq -c"
echo "   → the UNSTAMPED + BOXED tallies pick the next lever (measure-first · no lever before numbers)."
