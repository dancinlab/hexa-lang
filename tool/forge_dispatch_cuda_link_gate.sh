#!/usr/bin/env sh
# =============================================================================
# ING #33 — forge_dispatch CUDA-link regression gate (LOCAL, build-free, 0-GPU)
# =============================================================================
# Purpose
#   Lock in the #3806 + #3807 fix so the forge_dispatch CUDA-link bug CLASS
#   cannot silently re-land. The bug: forge_dispatch_* host dispatchers in
#   tool/restore_frozen_seeds (the frozen-seed SSOT that produces self/runtime.c)
#   were wrapped in `#ifndef HEXA_CUDA`, on the false assumption that a GPU-side
#   fusion_dispatch.c would supply them under -DHEXA_CUDA. That file was never
#   wired into self/cuda/ or the release pipeline, so a CUDA-variant runtime.a
#   exported only the always-defined seam (matmul/ffn) and ANY -DHEXA_CUDA link
#   of a TU calling one of the guarded dispatchers failed with `undefined
#   reference to forge_dispatch_<name>` (anima hit groupnorm_gelu first).
#
#   #3806/#3807 flipped every forge_dispatch host heredoc from
#   `#ifndef HEXA_CUDA` to `#if 1` and prefixed each definition with
#   `HEXA_FORGE_HOST_WEAK` (= __attribute__((weak)) under -DHEXA_CUDA, empty
#   otherwise) so a future strong GPU override still wins, collision-safe. The
#   summer sweep proved 66/66 forge_dispatch symbols export under CUDA with 0
#   undefined — but that was a one-time manual measurement. This gate makes the
#   invariant MECHANICAL.
#
# Two static invariants over tool/restore_frozen_seeds (the SSOT):
#   A. ZERO bare negative HEXA_CUDA guards — no `#ifndef HEXA_CUDA` (nor
#      `#if !defined(HEXA_CUDA)`) preprocessor directive may exist. The whole
#      family is `#if 1` now; re-adding a negative guard = the exact regression.
#      (Positive `#ifdef HEXA_CUDA` for GPU extern decls INSIDE a host body is
#      fine and not checked — it ADDS the GPU path, it does not vanish the host.)
#   B. EVERY forge_dispatch host DEFINITION carries HEXA_FORGE_HOST_WEAK — a
#      definition header at column 0 of the form `HexaVal [hexa_]forge_dispatch_…(`
#      (i.e. missing the weak prefix) is a regression.
#
# LOW BLAST RADIUS — purely lexical scan of ONE text file. No compiler, no CUDA
#   toolchain, no build. Passes on the current clean tree (Check A = 0, Check B
#   = 0), so it introduces no false-positive CI break.
#
# Exit: 0 = invariants hold; 1 = a forge_dispatch CUDA-link regression re-landed.
# =============================================================================
set -eu

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

SSOT="tool/restore_frozen_seeds"

if [ ! -f "$SSOT" ]; then
  echo "forge_dispatch_cuda_link_gate: SSOT absent: $SSOT" >&2
  exit 2
fi

echo "ING #33 forge_dispatch CUDA-link gate — SSOT=$SSOT (build-free static scan)"

fail=0

# --- Check A: no bare negative HEXA_CUDA guard --------------------------------
neg_ifndef="$(grep -nE '^[[:space:]]*#ifndef[[:space:]]+HEXA_CUDA([[:space:]].*)?$' "$SSOT" || true)"
neg_ifdef="$(grep -nE '^[[:space:]]*#if[[:space:]]+!defined[[:space:]]*\([[:space:]]*HEXA_CUDA[[:space:]]*\)' "$SSOT" || true)"
neg_all="$(printf '%s\n%s\n' "$neg_ifndef" "$neg_ifdef" | grep -v '^$' || true)"
neg_count="$(printf '%s\n' "$neg_all" | grep -c . || true)"

if [ "$neg_count" -ne 0 ]; then
  echo "  FAIL  Check A — $neg_count bare negative HEXA_CUDA guard(s) found:"
  printf '%s\n' "$neg_all" | sed 's/^/        /'
  echo '        A "#ifndef HEXA_CUDA" makes the host forge_dispatch body vanish under'
  echo '        -DHEXA_CUDA -> undefined-reference link failure. Use "#if 1" instead'
  echo '        (the #3806 fix); the host CPU body is the correct always-defined seam.'
  fail=1
else
  echo "  PASS  Check A — 0 bare negative HEXA_CUDA guards (#ifndef / #if !defined)"
fi

# --- Check B: every forge_dispatch definition carries HEXA_FORGE_HOST_WEAK ----
# A regressed definition header starts at column 0 with the return type, i.e.
# `HexaVal forge_dispatch_…(` or `HexaVal hexa_forge_dispatch_…(`, with NO
# HEXA_FORGE_HOST_WEAK prefix. (Correct defs are `HEXA_FORGE_HOST_WEAK HexaVal …`.)
missing_weak="$(grep -nE '^HexaVal[[:space:]]+(hexa_)?forge_dispatch_[A-Za-z0-9_]+[[:space:]]*\(' "$SSOT" || true)"
missing_count="$(printf '%s\n' "$missing_weak" | grep -c . || true)"

# Sanity floor: the family must still be present (catches an accidental wipe).
weak_defs="$(grep -cE '^HEXA_FORGE_HOST_WEAK[[:space:]]+HexaVal[[:space:]]+(hexa_)?forge_dispatch_' "$SSOT" || true)"

if [ "$missing_count" -ne 0 ]; then
  echo "  FAIL  Check B — $missing_count forge_dispatch definition(s) missing HEXA_FORGE_HOST_WEAK:"
  printf '%s\n' "$missing_weak" | sed 's/^/        /'
  echo "        Prefix the definition with HEXA_FORGE_HOST_WEAK so a future strong GPU"
  echo "        override (fusion_dispatch.c) wins collision-safe under -DHEXA_CUDA."
  fail=1
else
  echo "  PASS  Check B — all forge_dispatch defs carry HEXA_FORGE_HOST_WEAK ($weak_defs defs)"
fi

if [ "$weak_defs" -eq 0 ]; then
  echo "  FAIL  sanity — 0 HEXA_FORGE_HOST_WEAK forge_dispatch definitions found"
  echo "        (the host fallback family was wiped — expected >0)."
  fail=1
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "GATE FAILED: a forge_dispatch CUDA-link regression re-landed in $SSOT."
  echo "Root cause class: ING #33 (#3806/#3807). A -DHEXA_CUDA link of any TU calling"
  echo "the affected dispatcher will fail with 'undefined reference to forge_dispatch_*'."
  exit 1
fi

echo "GATE PASSED: forge_dispatch host family is CUDA-link-safe ($weak_defs weak defs, 0 negative guards)."
exit 0
