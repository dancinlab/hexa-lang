#!/usr/bin/env bash
# tool/regen_zeroc_stdlib_runtime_rt_o.sh — ZERO-C leg-B (ING #35, r11).
# Transpile the hexa-source stdlib runtime modules that DEFINE the remaining
# rt_* CORE prims the drop-ON link needs — ctype.hexa (rt_format/rt_str_char_at),
# io.hexa (rt_print/eprint), math.hexa (rt_sqrt/log10/log2/tan/tanh/pow_float/…)
# — via the in-tree hexa→C transpiler (build/hexat_<arch>, the math_core_native.o
# precedent), then compile each to a native .o with runtime.h + runtime_core_decls.h
# in scope (so HX_STRLEN expands). Emits build/zeroc_rt_{ctype,io,math}.o.
# These are hexa-SOURCE bodies (self-host-canonical), NOT hand C. Default build
# never invokes this. CC honored; requires build/hexat_<arch> (build_aprime warm).
set -uo pipefail
ROOT="$PWD"
OUTDIR="${1:-$ROOT/build}"
case "$(uname -m)" in x86_64) A=x86_64;; aarch64|arm64) A=arm64;; *) A="$(uname -m)";; esac
HEXAT="$ROOT/build/hexat_${A}"; [ -x "$HEXAT" ] || HEXAT="$ROOT/build/hexat_linux"
[ -x "$HEXAT" ] || { echo "regen_zeroc_stdlib_runtime_rt: no hexat transpiler ($HEXAT)" >&2; exit 1; }
mkdir -p "$OUTDIR"
TMP="$(mktemp -d /tmp/zeroc_stdrt.XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
OK=0
for m in ctype io math; do
    "$HEXAT" "$ROOT/stdlib/runtime/$m.hexa" "$TMP/$m.c" >/dev/null 2>&1 || { echo "  transpile FAIL $m" >&2; continue; }
    tail -n +2 "$TMP/$m.c" > "$TMP/${m}_body.c"   # drop hexat's bare runtime.h include
    printf '#include "runtime.h"\n#include "runtime_core_decls.h"\n#include "%s_body.c"\n' "$m" > "$TMP/${m}_tu.c"
    ${CC:-clang} -c -O2 -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-everything \
        -I "$ROOT/self" -I "$ROOT" -I "$TMP" "$TMP/${m}_tu.c" -o "$OUTDIR/zeroc_rt_${m}.o" 2>"$TMP/${m}.err" \
        && { echo "  ok zeroc_rt_${m}.o"; OK=$((OK+1)); } \
        || { echo "  compile FAIL zeroc_rt_${m}.o"; grep -iE 'error:' "$TMP/${m}.err" | head -3 | sed 's/^/    /'; }
done
echo "regen_zeroc_stdlib_runtime_rt: $OK/3 modules → $OUTDIR/zeroc_rt_{ctype,io,math}.o"
[ "$OK" = "3" ] || exit 2
