set -u
# tool/regen_rtcore_strarr-read_c.sh — RFC061 M5 r11: regenerate
# self/native/rtcore_strarr-read.c byte-identically from its emitter SSOT
# self/native/rtcore_strarr-read_emit.hexa via a deterministic hexat-FREE awk
# un-escape (\n \t \" \\). The emitter is the tracked SSOT; the .c is a
# gitignored build artifact. A warm tree (matching .c) is a true no-op.
ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/rtcore_strarr-read_emit.hexa"
DST="$ROOT/self/native/rtcore_strarr-read.c"

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

[ -f "$EMITTER" ] || { echo "[regen_rtcore_strarr-read_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_rtcore_strarr-read_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -qF 'HexaVal hexa_str_byte_at(HexaVal s, HexaVal idx) {' "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_rtcore_strarr-read_c] rtcore_strarr-read.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_rtcore_strarr-read_c] rtcore_strarr-read.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_rtcore_strarr-read_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
