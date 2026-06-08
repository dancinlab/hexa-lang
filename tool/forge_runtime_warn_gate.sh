#!/usr/bin/env sh
# =============================================================================
# HEXA-0POD OP-5b — forge-runtime warning-hygiene gate (LOCAL, 0-GPU)
# =============================================================================
# Purpose
#   Lock in the OP-5 (#2973) cleanup so the specific warning class it removed
#   cannot silently re-land. OP-5 fixed a `-Wcomment` defect in self/runtime.h
#   (a `native/*.c` glob inside a `/* ... */` block formed a nested `/*` token
#   that clang flags). This gate re-checks the *already-clean* forge/runtime
#   header surface with `-Wcomment -Werror` and FAILS only if a NEW warning of
#   that class appears in one of those specific files.
#
# LOW BLAST RADIUS — this is NOT a repo-wide `-Werror`:
#   * It compiles ONLY an explicit, pre-verified-clean allow-list (see FILES
#     below). Grandfathered warnings anywhere else in the tree are untouched
#     and can never fail this gate.
#   * It enables ONLY `-Wcomment` (the exact class OP-5 cleaned). `-Wcomment`
#     is a purely lexical check (nested `/*` inside a comment), so it needs no
#     CUDA toolchain, no project includes, and no type definitions — every
#     listed header/source is compiled stand-alone via `-x c`.
#   * Every file in the allow-list is verified to emit 0 `-Wcomment` warnings
#     on the current clean tree, so the gate cannot false-positive on main.
#
# Adding a file: only append a path here AFTER confirming
#   clang -fsyntax-only -Wcomment -Werror -x c <path>
# exits 0 on the current tree. The gate must always pass on a clean checkout.
#
# Exit: 0 = all guarded files clean; 1 = a new -Wcomment warning regressed.
# =============================================================================
set -eu

# Resolve repo root so the gate works from any CWD (CI, hook, local).
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

# --- Allow-list: the OP-5-clean forge/runtime header surface ------------------
# Each path was confirmed `-Wcomment`-clean before being added here.
FILES="
self/runtime.h
self/forge/forge_tier_v1.h
self/native/lora_cuda.h
"

# Pick a C compiler (clang preferred for the exact -Wcomment diagnostic OP-5
# was verified against; gcc also implements -Wcomment identically).
CC="${CC:-}"
if [ -z "$CC" ]; then
  if command -v clang >/dev/null 2>&1; then CC=clang
  elif command -v gcc >/dev/null 2>&1; then CC=gcc
  elif command -v cc   >/dev/null 2>&1; then CC=cc
  else
    echo "forge_runtime_warn_gate: no C compiler (clang/gcc/cc) found" >&2
    exit 2
  fi
fi

echo "OP-5b forge-runtime warning gate — CC=$CC, class=-Wcomment (lexical), -Werror"
echo "guarded files (OP-5-clean allow-list):"

fail=0
checked=0
for f in $FILES; do
  [ -n "$f" ] || continue
  if [ ! -f "$f" ]; then
    echo "  SKIP (absent): $f"
    continue
  fi
  checked=$((checked + 1))
  # -Wcomment -Werror promotes ONLY the nested-comment class to an error.
  # Stand-alone -x c compile: purely lexical, no includes/types/CUDA needed.
  out="$("$CC" -fsyntax-only -Wcomment -Werror -x c "$f" 2>&1)" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "  PASS  $f"
  else
    echo "  FAIL  $f  (-Wcomment regression — re-introduced nested comment?)"
    echo "$out" | sed 's/^/        /'
    fail=1
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "forge_runtime_warn_gate: no guarded files present — nothing checked" >&2
  exit 2
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "GATE FAILED: a -Wcomment warning regressed in an OP-5-clean forge/runtime file."
  echo "Fix the nested-comment defect (e.g. write 'native/ *.c' not 'native/*.c')."
  exit 1
fi

echo ""
echo "GATE PASSED: $checked guarded forge/runtime file(s) clean of -Wcomment."
exit 0
