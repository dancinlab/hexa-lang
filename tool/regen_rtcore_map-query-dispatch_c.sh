#!/usr/bin/env bash
# tool/regen_rtcore_map-query-dispatch_c.sh — deterministic, hexat-FREE regen of the generated
# artifact self/native/rtcore_map-query-dispatch.c from its emitter SSOT
# self/native/rtcore_map-query-dispatch_emit.hexa.
#
# WHY THIS EXISTS (zero-c leg-B recursive, ING #29):
#   self/native/rtcore_map-query-dispatch.c is the hand-assembled zero-c leg-B
#   "map-query-dispatch" native seed (9 map query/projection dispatcher HexaVal
#   wrappers). It has a .hexa text-emitter SSOT
#   (self/native/rtcore_map-query-dispatch_emit.hexa) and the .c becomes a
#   regenerated, .gitignore'd artifact — EXACTLY like the runtime trio
#   (runtime_core.c<-runtime_core_emit.hexa) and the rtcore_valop-dispatch sibling.
#
#   tool/regen_rtcore_map-query-dispatch_native_o.sh calls THIS script first to
#   synthesize the .c from the emitter, then compiles it into
#   build/rtcore_map-query-dispatch_native.o. The regen is byte-DETERMINISTIC (the
#   awk un-escape reproduces the emitter's own .c output verbatim), so the build is
#   byte-neutral (no perf change, no byteeq drift).
#
# This is the SAME un-escaper tool/regen_runtime_core_c.sh uses (copied here so
# the rtcore_map-query-dispatch seed reuses it verbatim — DRY, reference-first).
#
# Usage:  bash tool/regen_rtcore_map-query-dispatch_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/native/rtcore_map-query-dispatch_emit.hexa.
# Idempotent + NO-OP-SAFE: emitter absent -> keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/rtcore_map-query-dispatch_emit.hexa"
DST="$ROOT/self/native/rtcore_map-query-dispatch.c"

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

[ -f "$EMITTER" ] || { echo "[regen_rtcore_map-query-dispatch_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_rtcore_map-query-dispatch_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -q 'HexaVal hexa_map_all' "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_rtcore_map-query-dispatch_c] rtcore_map-query-dispatch.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_rtcore_map-query-dispatch_c] rtcore_map-query-dispatch.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_rtcore_map-query-dispatch_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
