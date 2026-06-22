#!/usr/bin/env bash
# tool/regen_zeroc_hxlcl_delegate_o.sh — ZERO-C leg-B (ING #35, r11).
# Assemble build/zeroc_hxlcl_delegate.o from the C SSOT
# self/native/zeroc_hxlcl_delegate.c — the 17 EXTERNAL hxlcl_* delegates
# (math 5 → external rt_* cores, libc 12 → real libc) the drop-ON executable
# link needs (the frozen-static hxlcl_* bodies are post-include-boundary and
# invisible to the arena-globals seed TU). #3798 fmod→rt_fmod delegate pattern,
# does NOT touch the frozen blob. Default build never compiles this (byte-id OFF).
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/zeroc_hxlcl_delegate.c"
OUT="${1:-$ROOT/build/zeroc_hxlcl_delegate.o}"
[ -f "$SEED" ] || { echo "regen_zeroc_hxlcl_delegate: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
TU="$(mktemp /tmp/zeroc_hxlcl_tu.XXXXXX.c)"; trap 'rm -f "$TU"' EXIT
printf '#include "runtime.h"\n#include "native/zeroc_hxlcl_delegate.c"\n' > "$TU"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_zeroc_hxlcl_delegate: compile failed (no $OUT)" >&2; exit 2; }
N="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?hxlcl_(cos|sin|exp|log|fmod|atoll|atof|time|atexit|signal|getrusage|gmtime_r|strftime|execvp|popen|pclose|write)$')"
echo "regen_zeroc_hxlcl_delegate: $OUT — $N/17 hxlcl_* delegates exported"
[ "$N" = "17" ] || { echo "regen_zeroc_hxlcl_delegate: expected 17, got $N" >&2; exit 3; }
