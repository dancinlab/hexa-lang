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
# zero-c #29: materialize self/native/timegm_native.c from its .hexa emitter SSOT
# (self/native/timegm_native_emit.hexa, built by tool/gen_c_text_emitter.hexa —
# same #3858 pattern as the 16 sibling self/native/*_emit.hexa). After gitignore+
# rm --cached, the .c is a regenerated artifact; the awk un-escape reproduces the
# prior tracked .c BYTE-FOR-BYTE (\n \t \" \\), so build/timegm_native.o is
# byte-identical => byteeq-neutral (and default-OFF, absent from default runtime.a).
EMITTER="$ROOT/self/native/timegm_native_emit.hexa"
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
    atmp="$(mktemp -t regen_timegm_native.XXXXXX)" || atmp=""
    if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
       && [ -s "$atmp" ] && grep -q 'hxlcl_timegm_secs' "$atmp"; then
        if [ ! -f "$SEED" ] || ! cmp -s "$atmp" "$SEED"; then cp -f "$atmp" "$SEED"; fi
        rm -f "$atmp"
        echo "[regen_timegm_native] timegm_native.c SYNTHESIZED from emitter SSOT (awk un-escape, hexat-free)"
    else
        rm -f "$atmp"; echo "[regen_timegm_native] emitter present but malformed — using in-tree .c if any" >&2
    fi
fi
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
