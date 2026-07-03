#!/usr/bin/env bash
# tool/regen_rtcore_arena_globals_native_o.sh — ZERO-C leg-B (ING #35, r9).
#
# The drop-ON seed object for the whole-file `#include "runtime_core.c"` DROP.
# When HEXA_ZEROC_DROP_RTCORE_INCLUDE is set, runtime_core.c is NO LONGER
# textually concatenated into runtime.c — so the frozen runtime.c HI-tier body
# loses every CORE-tier DEFINITION it used to compile-in (the arena/stats/strbuf
# bodies + the file-scope globals __hexa_arena / __hexa_val_region_returns_enabled
# / array_store / join / _hx_stats_*). This seed re-supplies those definitions as
# a SEPARATE relocatable object so the drop-ON runtime.o can LINK.
#
# It is produced by compiling runtime_core.c THROUGH the runtime.c system-header
# + hxlcl_* prelude (runtime.c lines 1 .. the guarded `#include` line) — exactly
# the textual context runtime_core.c saw under the default concatenation — with
# -DHEXA_ZEROC_DROP_RTCORE_INCLUDE so the HX_RTCORE_LOCAL / _INLINE macros expand
# to EXTERNAL linkage (the static→external promotion). The promoted symbols then
# export from this .o (nm: __hexa_arena=B, hexa_strbuf_alloc=T, …) and bind the
# drop-ON runtime.o's cross-tier relocs.
#
# Usage:  bash tool/regen_rtcore_arena_globals_native_o.sh [OUT_O]
#   OUT_O defaults to build/rtcore_arena_globals_native.o · CC/ARCH_FLAG honored.
#   Requires self/runtime.c RESTORED + DROP-GUARD-PATCHED (so the guard line
#   marks the prelude/core boundary) and self/runtime_core.c REGEN'd.
set -uo pipefail
ROOT="$PWD"
RT="$ROOT/self/runtime.c"
CORE="$ROOT/self/runtime_core.c"
OUT="${1:-$ROOT/build/rtcore_arena_globals_native.o}"
CC="${CC:-clang}"
[ -f "$RT" ]   || { echo "regen_rtcore_arena_globals: missing $RT (restore_frozen_seeds first)" >&2; exit 1; }
[ -f "$CORE" ] || { echo "regen_rtcore_arena_globals: missing $CORE (regen_runtime_core_c first)" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

# Locate the guarded include line — the prelude/core boundary.
INC="$(grep -n 'ZEROC_DROP_RTCORE_INCLUDE_GUARD' "$RT" 2>/dev/null | head -1 | cut -d: -f1)"
if [ -z "$INC" ]; then
    # not yet drop-guard-patched — fall back to the bare include line.
    INC="$(grep -n '^#include "runtime_core.c"$' "$RT" 2>/dev/null | head -1 | cut -d: -f1)"
fi
[ -n "$INC" ] || { echo "regen_rtcore_arena_globals: no runtime_core.c include boundary in $RT" >&2; exit 2; }

PRELUDE="$(mktemp /tmp/rtcore_prelude.XXXXXX.h)"
TU="$(mktemp /tmp/rtcore_seed_tu.XXXXXX.c)"
trap 'rm -f "$PRELUDE" "$TU"' EXIT
# Prelude = runtime.c head up to (not including) the include boundary — the
# system #includes + the hxlcl_* libc-wrapper macros + base forward decls.
head -n "$((INC-1))" "$RT" > "$PRELUDE"
printf '#include "%s"\n#include "runtime_core.c"\n' "$PRELUDE" > "$TU"

EXTRA=""
[ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
"$CC" -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE \
    -I "$ROOT/self" -I "$ROOT" "$TU" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_rtcore_arena_globals: compile failed (no $OUT)" >&2; exit 3; }

# Verify the 2 promoted file-scope globals export as EXTERNAL (B/D), not absent.
G="$(nm "$OUT" 2>/dev/null | grep -cE ' [BDbd] (__hexa_arena|__hexa_val_region_returns_enabled)$')"
echo "regen_rtcore_arena_globals: $OUT — $G/2 promoted globals exported external"
[ "$G" = "2" ] || { echo "regen_rtcore_arena_globals: expected 2 external globals, got $G" >&2; exit 4; }
