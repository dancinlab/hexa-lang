#!/bin/bash
# RT-NATIVE Z2c: compile eq_port.hexa with aprime_eq, link runtime, run,
# capture exit code (= native-vs-C match count). Mirrors build_aprime.sh
# stage-5 smoke pipeline.
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO" || exit 1
OUT="${1:-build/aprime_eq}"
SRC="scripts/scratch/rt_native/eq_port.hexa"
TMP="$(mktemp -d)"
SMS="$TMP/eq.s"; SMO="$TMP/eq.o"; RTO="$TMP/rt.o"; SMB="$TMP/eq"

ARCH_FLAG="-arch arm64"
SMOKE_TARGET="arm64-apple-darwin"
ZEROC_RT_HI_OBJ=""
if [ "$(uname -sm 2>/dev/null)" = "Darwin arm64" ] && [ -f build/rt_hi_native.o ]; then
    ZEROC_RT_HI_OBJ="$REPO/build/rt_hi_native.o"
fi

echo "=== emit asm (aprime_eq) ==="
"$OUT" _drv.hexa --emit=asm --target="$SMOKE_TARGET" -o "$SMS" "$SRC" 2>&1 | tail -2

echo "=== check native .s uses __hx_tag inline (no hexa_eq C call) ==="
echo -n "  bl _hexa_eq occurrences: "; grep -c "_hexa_eq" "$SMS" 2>/dev/null || echo 0
echo -n "  __hx_tag / tag-read inline markers: "; grep -c "__hx_tag\|tag-read\|v.tag\|TAG_INT" "$SMS" 2>/dev/null || echo 0

EXTRA_DEFS=""
[ "$(uname -s)" = "Darwin" ] && EXTRA_DEFS="-D_DARWIN_C_SOURCE"
clang -c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE $EXTRA_DEFS -Wno-trigraphs -I self -I . \
    self/runtime.c -o "$RTO" 2>&1 | grep -iE 'error:|undefined|ld:|fatal' | head -3
clang $ARCH_FLAG "$SMS" -c -o "$SMO" 2>&1 | grep -iE 'error:|undefined|ld:|fatal' | head -3
clang $ARCH_FLAG "$SMO" "$RTO" $ZEROC_RT_HI_OBJ -o "$SMB" -lm 2>&1 | grep -iE 'undefined|error:' | head -5

if [ ! -x "$SMB" ]; then echo "LINK FAILED"; exit 2; fi
echo "=== run ==="
"$SMB"; RC=$?
echo "EXIT_CODE(match_count) = $RC"
