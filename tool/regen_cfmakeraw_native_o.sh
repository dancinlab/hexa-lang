#!/usr/bin/env bash
# tool/regen_cfmakeraw_native_o.sh — ING #29 libc-free re-architecture ladder (axis-②).
#
# Assemble build/cfmakeraw_native.o from the C SSOT self/native/cfmakeraw_native.c —
# the hexa-native (glibc/musl symbolic-flag-clear port) `cfmakeraw` override that
# drops the runtime.c's sole RAW libc cfmakeraw reference (self/runtime.c term_raw_enter,
# emitted by self/runtime_emit.hexa:3423) when the experimental drop-ON / -lc-removal
# path links it. #3798 fmod→rt_fmod / timegm_native.c (#4352) / gmtime_native.c (#4874)
# delegate pattern: this does NOT touch the immutable frozen blob (raw cfmakeraw site).
#
# DEFAULT-OFF: this seed object is produced ONLY on explicit request and is never
# part of the default release link — the default build never compiles
# self/native/cfmakeraw_native.c, so runtime.a stays byte-identical and libc cfmakeraw
# is used unchanged. Opt-in: set HEXA_RT_CFMAKERAW_NATIVE=1 and link
# build/cfmakeraw_native.o ahead of libc so the runtime.c raw `cfmakeraw(&raw)` resolves
# to the native body.
#
# Verifies (nm) that the override symbol `cfmakeraw` is exported (strong T) so the
# linker prefers it over the libc definition.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/cfmakeraw_native.c"
OUT="${1:-$ROOT/build/cfmakeraw_native.o}"
# zero-c #29: materialize self/native/cfmakeraw_native.c from its .hexa emitter SSOT
# (self/native/cfmakeraw_native_emit.hexa, built by tool/gen_c_text_emitter.hexa —
# same #3858 pattern as the sibling self/native/*_emit.hexa). After gitignore+
# rm --cached, the .c is a regenerated artifact; the awk un-escape reproduces the
# prior tracked .c BYTE-FOR-BYTE (\n \t \" \\), so build/cfmakeraw_native.o is
# byte-identical => byteeq-neutral (and default-OFF, absent from default runtime.a).
EMITTER="$ROOT/self/native/cfmakeraw_native_emit.hexa"
_unescape_emit_to_c() {
    awk '
      BEGIN { saw = 0 }
      {
        line = $0
        pfx = "    buf = buf + \""
        if (substr(line, 1, length(pfx)) != pfx) next
        body = substr(line, length(pfx) + 1)
        if (substr(body, length(body), 1) != "\"") next
        body = substr(body, 1, length(body) - 1)
        saw = 1
        out = ""; n = length(body); i = 1
        while (i <= n) {
          c = substr(body, i, 1)
          if (c == "\\" && i < n) {
            d = substr(body, i+1, 1)
            if (d == "n")  { out = out "\n"; i += 2; continue }
            if (d == "t")  { out = out "\t"; i += 2; continue }
            if (d == "\"") { out = out "\""; i += 2; continue }
            if (d == "\\") { out = out "\\"; i += 2; continue }
            out = out "\\"; i += 1; continue
          }
          out = out c; i += 1
        }
        printf "%s", out
      }
      END { if (!saw) exit 3 }
    ' "$1"
}
if [ -f "$EMITTER" ]; then
    atmp="$(mktemp -t regen_cfmakeraw_native.XXXXXX)" || atmp=""
    if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
       && [ -s "$atmp" ] && grep -q 'hxlcl_cfmakeraw_compute' "$atmp"; then
        if [ ! -f "$SEED" ] || ! cmp -s "$atmp" "$SEED"; then cp -f "$atmp" "$SEED"; fi
        rm -f "$atmp"
        echo "[regen_cfmakeraw_native] cfmakeraw_native.c SYNTHESIZED from emitter SSOT (awk un-escape, hexat-free)"
    else
        rm -f "$atmp"; echo "[regen_cfmakeraw_native] emitter present but malformed — using in-tree .c if any" >&2
    fi
fi
[ -f "$SEED" ] || { echo "regen_cfmakeraw_native: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_CFMAKERAW_NATIVE $EXTRA \
    -I "$ROOT/self" -I "$ROOT" "$SEED" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_cfmakeraw_native: compile failed (no $OUT)" >&2; exit 2; }
# The strong override `cfmakeraw` (+ the pure compute hxlcl_cfmakeraw_compute) must export.
G="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?cfmakeraw$')"
S="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?hxlcl_cfmakeraw_compute$')"
echo "regen_cfmakeraw_native: $OUT — cfmakeraw override exported=$G  hxlcl_cfmakeraw_compute exported=$S"
[ "$G" = "1" ] || { echo "regen_cfmakeraw_native: expected cfmakeraw override exported, got $G" >&2; exit 3; }
[ "$S" = "1" ] || { echo "regen_cfmakeraw_native: expected hxlcl_cfmakeraw_compute exported, got $S" >&2; exit 4; }
