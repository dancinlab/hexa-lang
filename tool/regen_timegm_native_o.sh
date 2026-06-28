#!/usr/bin/env bash
# tool/regen_timegm_native_o.sh — ING #29 libc-free re-architecture ladder, R1.
#
# Assemble build/timegm_native.o from the C SSOT self/native/timegm_native.c —
# the hexa-native (musl __tm_to_secs port) `timegm` override that drops the
# runtime substrate's sole RAW libc timegm reference (self/runtime.c:12312,
# frozen blob 151c52c8) when the experimental drop-ON / -lc-removal path links
# it. #3798 fmod→rt_fmod / zeroc_hxlcl_delegate.c delegate pattern: this does
# NOT touch the immutable frozen blob.
#
# DEFAULT-OFF: this seed object is produced ONLY on explicit request and is never
# part of the default release link — the default build never compiles
# self/native/timegm_native.c, so runtime.a stays byte-identical and libc timegm
# is used unchanged. Opt-in: set HEXA_RT_TIMEGM_NATIVE=1 and link build/timegm_native.o
# ahead of libc so the frozen blob's raw `timegm(&g)` resolves to the native body.
#
# Verifies (nm) that the override symbol `timegm` is exported (strong T) so the
# linker prefers it over the libc definition.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/timegm_native.c"
OUT="${1:-$ROOT/build/timegm_native.o}"
[ -f "$SEED" ] || { echo "regen_timegm_native: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_TIMEGM_NATIVE $EXTRA \
    -I "$ROOT/self" -I "$ROOT" "$SEED" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_timegm_native: compile failed (no $OUT)" >&2; exit 2; }
# The strong override `timegm` (+ the pure compute hxlcl_timegm_secs) must export.
T="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?timegm$')"
S="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?hxlcl_timegm_secs$')"
echo "regen_timegm_native: $OUT — timegm override exported=$T  hxlcl_timegm_secs exported=$S"
[ "$T" = "1" ] || { echo "regen_timegm_native: expected timegm override exported, got $T" >&2; exit 3; }
[ "$S" = "1" ] || { echo "regen_timegm_native: expected hxlcl_timegm_secs exported, got $S" >&2; exit 4; }
