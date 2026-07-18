#!/usr/bin/env bash
# symcensus_lint.sh — axis-③ codegen↔runtime symbol-census lint (guard C-1, PRIMARY)
# ─────────────────────────────────────────────────────────────────────────────
# The whack-a-mole root cause: three surfaces name the builtin set independently —
#   ① checker gates   compiler/check/types.hexa::_is_builtin_method       (methods)
#                     compiler/check/bind.hexa::_bind_builtin_names        (free fns)
#   ② codegen mapping compiler/codegen/arm64_darwin.hexa::_builtin_runtime_sym
#   ③ C-ABI leaves    compiler/codegen/x86_64_linux.hexa::_is_cabi
# When a name passes the checker gate (①) but is absent from the codegen mapping
# (②), the mapping fallthrough emits a BARE symbol; hexa_ld's dyn-census then
# misfiles it as a libc-floor UND and routes it dynamic → ld.so failure / SIGBUS
# at run time. This lint proves, from source alone (NO build, NO runtime.a — so it
# runs on cloud-CI checkout instantly), the set assertion:
#
#     (whitelist ∪ bind_gate) − (mapped ∪ _is_cabi ∪ special-op ∪ exemption) = ∅
#
# Any residual (a checker-gate builtin with neither a mapping nor an exemption
# entry) fails the lint. Adding a new builtin to a checker gate but forgetting the
# codegen mapping now turns the PR RED at the source of the desync.
#
# special-op = codegen-inline intrinsics (never runtime-linked symbols):
#   __hx_* __builtin_va_* __arr_* __map_* __str_* __fd_* __raw_* __vs_* target_is_*
#   plus the literal scope names true/false/nil/void (bind.hexa emits KwTrue/KwFalse).
# exemption  = tool/symcensus_exempt.txt (the shrinking Rung-B outstanding set).
#
# Usage:
#   tool/symcensus_lint.sh                 # assert ∅ (exit 1 on residual)
#   tool/symcensus_lint.sh --list-residual # print the residual set, exit 0 (regen aid)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TYPES="$ROOT/compiler/check/types.hexa"
BIND="$ROOT/compiler/check/bind.hexa"
MAP="$ROOT/compiler/codegen/arm64_darwin.hexa"
CABI="$ROOT/compiler/codegen/x86_64_linux.hexa"
EXEMPT="$ROOT/tool/symcensus_exempt.txt"

for f in "$TYPES" "$BIND" "$MAP" "$CABI"; do
  [ -f "$f" ] || { echo "symcensus-lint: FATAL — missing source $f" >&2; exit 2; }
done

MODE="${1:-assert}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ── Extract each surface by NAME (not line number — drift-proof). Each function
#    body ends at the first column-0 `}` after its header. ──
# ① whitelist: _is_builtin_method match arms  ("name" -> true,)
awk '/^fn _is_builtin_method\(/{f=1} f{print} f&&/^}$/{exit}' "$TYPES" \
  | grep -oE '"[a-zA-Z_0-9]+"' | tr -d '"' | sort -u > "$tmp/whitelist"
# ① bind gate: _bind_builtin_names list entries
awk '/^fn _bind_builtin_names\(/{f=1} f{print} f&&/^}$/{exit}' "$BIND" \
  | grep -oE '"[a-zA-Z_0-9]+"' | tr -d '"' | sort -u > "$tmp/bindgate"
# ② codegen mapping keys: _builtin_runtime_sym  (name == "X")
awk '/^pub fn _builtin_runtime_sym\(/{f=1} f{print} f&&/^}$/{exit}' "$MAP" \
  | grep -oE 'name == "[a-zA-Z_0-9]+"' | sed 's/.*"\(.*\)"/\1/' | sort -u > "$tmp/mapped"
# ③ C-ABI leaves: _is_cabi  (fname == "X")
awk '/^pub fn _is_cabi\(/{f=1} f{print} f&&/^}$/{exit}' "$CABI" \
  | grep -oE 'fname == "[a-zA-Z_0-9]+"' | sed 's/.*"\(.*\)"/\1/' | sort -u > "$tmp/cabi"

# Sanity: the extractions must be non-degenerate (guards against an awk/format
# drift that would silently make the union empty and the lint vacuously GREEN).
for s in whitelist bindgate mapped cabi; do
  n="$(wc -l < "$tmp/$s")"
  if [ "$n" -lt 10 ]; then
    echo "symcensus-lint: FATAL — extraction '$s' degenerate ($n names); parser drift?" >&2
    exit 2
  fi
done

# gate_union = checker-gate names to account for
sort -u "$tmp/whitelist" "$tmp/bindgate" > "$tmp/gate_union"

# covered = mapped ∪ _is_cabi
sort -u "$tmp/mapped" "$tmp/cabi" > "$tmp/covered"

# residual = gate_union − covered − special-op − exemption
grep -vxF -f "$tmp/covered" "$tmp/gate_union" \
  | grep -vE '^(__hx_|__builtin_va_|__arr_|__map_|__str_|__fd_|__raw_|__vs_|target_is_)' \
  | grep -vE '^(true|false|nil|void)$' > "$tmp/after_special" || true

if [ -f "$EXEMPT" ]; then
  grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$EXEMPT" | tr -d ' \t' | sort -u > "$tmp/exempt"
else
  : > "$tmp/exempt"
fi
grep -vxF -f "$tmp/exempt" "$tmp/after_special" > "$tmp/residual" || true

if [ "$MODE" = "--list-residual" ]; then
  echo "# symcensus residual (gate_union − mapped − _is_cabi − special-op − exemption)"
  echo "# whitelist=$(wc -l <"$tmp/whitelist") bindgate=$(wc -l <"$tmp/bindgate") mapped=$(wc -l <"$tmp/mapped") cabi=$(wc -l <"$tmp/cabi") exempt=$(wc -l <"$tmp/exempt")"
  cat "$tmp/residual"
  exit 0
fi

# ── Also flag STALE exemptions: an exemption entry that is now mapped/covered is
#    dead weight (part-2 landed the mapping but left the exemption). Advisory. ──
stale="$(grep -vxF -f "$tmp/after_special" "$tmp/exempt" || true)"

RESN="$(grep -cE '.' "$tmp/residual" 2>/dev/null || true)"
RESN="${RESN:-0}"
if [ "$RESN" -ne 0 ]; then
  echo "❌ symcensus-lint FAIL — $RESN checker-gate builtin(s) with NO codegen mapping and NO exemption:"
  sed 's/^/    /' "$tmp/residual"
  echo ""
  echo "  root cause: a name passes _is_builtin_method / _bind_builtin_names but is"
  echo "  absent from _builtin_runtime_sym → the mapping fallthrough emits a BARE"
  echo "  symbol → hexa_ld routes it to libc.so.6 (dyn-census) → run-time SIGBUS/rc127."
  echo "  fix: add each to _builtin_runtime_sym (arm64_darwin.hexa) with its runtime"
  echo "  target (nm-verified in build/runtime.a), OR — if it is a codegen-inline"
  echo "  intrinsic / interp-only / CUDA-gated leaf — add it to tool/symcensus_exempt.txt."
  exit 1
fi

echo "✅ symcensus-lint GREEN — (whitelist ∪ bind_gate) − (mapped ∪ _is_cabi ∪ special-op ∪ exemption) = ∅"
echo "   whitelist=$(wc -l <"$tmp/whitelist") bindgate=$(wc -l <"$tmp/bindgate") mapped=$(wc -l <"$tmp/mapped") _is_cabi=$(wc -l <"$tmp/cabi") exempt=$(wc -l <"$tmp/exempt")"
if [ -n "$stale" ]; then
  echo "⚠️  advisory — $(printf '%s\n' "$stale" | grep -c .) STALE exemption(s) now mapped/covered (prune from tool/symcensus_exempt.txt):"
  printf '%s\n' "$stale" | sed 's/^/    /'
fi
exit 0
