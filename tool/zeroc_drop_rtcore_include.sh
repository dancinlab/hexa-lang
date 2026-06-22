#!/usr/bin/env bash
# tool/zeroc_drop_rtcore_include.sh — RFC061 ∅ campaign, r7.
#   POST-RESTORE drop-guard for the FROZEN `#include "runtime_core.c"` line.
#
# GOAL (top-level `ls self/*.c` 3→1)
# ──────────────────────────────────
# The three top-level generated self/*.c are:
#     self/runtime.c          (FROZEN blob 151c52c8 — restore_frozen_seeds)
#     self/runtime_core.c     (emitter SSOT self/runtime_core_emit.hexa)
#     self/runtime_hi_gen.c   (emitter self/runtime_hi_gen_emit.hexa; #include'd
#                              ONLY from runtime_core.c at runtime_core.c:~9089)
# Because runtime_hi_gen.c is reached ONLY through runtime_core.c, dropping the
# single line `#include "runtime_core.c"` in runtime.c removes BOTH generated
# files from the compile (3→1: only runtime.c remains). The build then has to
# supply every body runtime_core.c used to compile-in from native seed objects.
#
# WHY A POST-RESTORE PATCH (not an emitter edit)
# ──────────────────────────────────────────────
# The `#include "runtime_core.c"` line lives in the FROZEN runtime.c blob
# (151c52c8), which restore_frozen_seeds re-injects verbatim every build. We
# MUST NOT edit the frozen blob. So — exactly like tool/zeroc_selfemit_unstatic_linux.sh
# does for the linux-branch static defs — this script runs AFTER
# restore_frozen_seeds and BEFORE the C compile, and wraps the include line in
#     #ifndef HEXA_ZEROC_DROP_RTCORE_INCLUDE
#     #include "runtime_core.c"
#     #endif
# patching the RESTORED working copy of self/runtime.c, never the blob.
#
# NEW FLAG NAME (deliberate): HEXA_ZEROC_DROP_RTCORE_INCLUDE.
#   NOT HEXA_ZEROC_DROP_RTCORE — that one already exists for a DIFFERENT purpose
#   (the #3811 HexaVal-ABI header disentangle inside runtime_core.c). This flag
#   controls the WHOLE-FILE include drop. Default OFF.
#
# BYTE-NEUTRALITY (the merge gate)
# ────────────────────────────────
# The guard is `#ifndef HEXA_ZEROC_DROP_RTCORE_INCLUDE`. On the DEFAULT build
# (flag undefined) the include line is emitted UNCHANGED — the three guard
# tokens (#ifndef / #endif) are preprocessor-only and vanish from `clang -E -P`
# output, so the preprocessed runtime.c is byte-identical to the un-patched
# frozen copy. Proof recipe (run with the flag OFF):
#     clang -E -P ... self/runtime.c   (patched)  | sha256sum
#     clang -E -P ... self/runtime.c   (frozen)   | sha256sum   # must match
# (tool/zeroc_flip_measure.sh PROBE-C automates this byte-neutral check.)
#
# Idempotent: re-running is a no-op (marker present). Exit 0 on success.
#
# Usage:  bash tool/zeroc_drop_rtcore_include.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/runtime.c (restored).
set -u

ROOT="${1:-$PWD}"
RT="$ROOT/self/runtime.c"
[ -f "$RT" ] || { echo "[drop_rtcore_include] SKIP — self/runtime.c absent ($RT)"; exit 0; }

MARK='ZEROC_DROP_RTCORE_INCLUDE_GUARD'
if grep -q "$MARK" "$RT" 2>/dev/null; then
    echo "[drop_rtcore_include] already patched (marker present) — no-op"
    exit 0
fi

if ! grep -q '^#include "runtime_core.c"$' "$RT" 2>/dev/null; then
    echo "[drop_rtcore_include] SKIP — no '#include \"runtime_core.c\"' line found" >&2
    exit 0
fi

tmp="$(mktemp -t drop_rtcore_include.XXXXXX)" \
    || { echo "[drop_rtcore_include] mktemp failed" >&2; exit 1; }

# Wrap the SINGLE literal include line. perl keeps it deterministic + exact.
perl -pe '
  if ($_ eq "#include \"runtime_core.c\"\n") {
    $_ = "#ifndef HEXA_ZEROC_DROP_RTCORE_INCLUDE  /* ZEROC_DROP_RTCORE_INCLUDE_GUARD */\n"
       . "#include \"runtime_core.c\"\n"
       . "#endif  /* HEXA_ZEROC_DROP_RTCORE_INCLUDE */\n";
  }
' "$RT" > "$tmp" || { echo "[drop_rtcore_include] perl failed" >&2; rm -f "$tmp"; exit 1; }

if [ -s "$tmp" ] && grep -q "$MARK" "$tmp"; then
    cp -f "$tmp" "$RT"
    rm -f "$tmp"
    echo "[drop_rtcore_include] self/runtime.c patched (include guarded under HEXA_ZEROC_DROP_RTCORE_INCLUDE, non-frozen)"
    exit 0
fi
rm -f "$tmp"
echo "[drop_rtcore_include] FAILED — marker not present after patch" >&2
exit 1
