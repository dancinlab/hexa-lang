#!/usr/bin/env bash
# tool/regen_gmtime_native_o.sh — ING #29 libc-free re-architecture ladder, R1 (axis-②).
#
# Assemble build/gmtime_native.o from the C SSOT self/native/gmtime_native.c —
# the hexa-native (Howard Hinnant civil-from-days port) `gmtime_r` override that
# drops the STANDALONE runtime_core.c's sole RAW libc gmtime_r reference
# (self/runtime_core.c:544, emitted by self/runtime_core_emit.hexa:580, compiled
# via the sysheaders shim's raw <time.h>) when the experimental drop-ON /
# -lc-removal path links it. #3798 fmod→rt_fmod / timegm_native.c (#4352) delegate
# pattern: this does NOT touch the immutable frozen blob (which already routes its
# own 4 gmtime_r sites through the in-blob hxlcl_gmtime_r).
#
# DEFAULT-OFF: this seed object is produced ONLY on explicit request and is never
# part of the default release link — the default build never compiles
# self/native/gmtime_native.c, so runtime.a stays byte-identical and libc gmtime_r
# is used unchanged. Opt-in: set HEXA_RT_GMTIME_NATIVE=1 and link build/gmtime_native.o
# ahead of libc so the standalone runtime_core.c's raw `gmtime_r(&now,&tmv)` resolves
# to the native body.
#
# Verifies (nm) that the override symbol `gmtime_r` is exported (strong T) so the
# linker prefers it over the libc definition.
set -uo pipefail
ROOT="$PWD"
SEED="$ROOT/self/native/gmtime_native.c"
OUT="${1:-$ROOT/build/gmtime_native.o}"
# zero-c #29: materialize self/native/gmtime_native.c from its .hexa emitter SSOT
# (self/native/gmtime_native_emit.hexa, built by tool/gen_c_text_emitter.hexa —
# same #3858 pattern as the sibling self/native/*_emit.hexa). After gitignore+
# rm --cached, the .c is a regenerated artifact; the awk un-escape reproduces the
# prior tracked .c BYTE-FOR-BYTE (\n \t \" \\), so build/gmtime_native.o is
# byte-identical => byteeq-neutral (and default-OFF, absent from default runtime.a).
EMITTER="$ROOT/self/native/gmtime_native_emit.hexa"
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
    atmp="$(mktemp -t regen_gmtime_native.XXXXXX)" || atmp=""
    if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
       && [ -s "$atmp" ] && grep -q 'hxlcl_gmtime_r_compute' "$atmp"; then
        if [ ! -f "$SEED" ] || ! cmp -s "$atmp" "$SEED"; then cp -f "$atmp" "$SEED"; fi
        rm -f "$atmp"
        echo "[regen_gmtime_native] gmtime_native.c SYNTHESIZED from emitter SSOT (awk un-escape, hexat-free)"
    else
        rm -f "$atmp"; echo "[regen_gmtime_native] emitter present but malformed — using in-tree .c if any" >&2
    fi
fi
[ -f "$SEED" ] || { echo "regen_gmtime_native: missing $SEED" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
${CC:-clang} -c -O2 ${ARCH_FLAG:-} -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_GMTIME_NATIVE $EXTRA \
    -I "$ROOT/self" -I "$ROOT" "$SEED" -o "$OUT" 2>&1 | grep -iE 'error:' | head -8
[ -f "$OUT" ] || { echo "regen_gmtime_native: compile failed (no $OUT)" >&2; exit 2; }
# The strong override `gmtime_r` (+ the pure compute hxlcl_gmtime_r_compute) must export.
G="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?gmtime_r$')"
S="$(nm -g "$OUT" 2>/dev/null | grep -cE ' T _?hxlcl_gmtime_r_compute$')"
echo "regen_gmtime_native: $OUT — gmtime_r override exported=$G  hxlcl_gmtime_r_compute exported=$S"
[ "$G" = "1" ] || { echo "regen_gmtime_native: expected gmtime_r override exported, got $G" >&2; exit 3; }
[ "$S" = "1" ] || { echo "regen_gmtime_native: expected hxlcl_gmtime_r_compute exported, got $S" >&2; exit 4; }
