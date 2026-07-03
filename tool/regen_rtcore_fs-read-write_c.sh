#!/usr/bin/env bash
# tool/regen_rtcore_fs-read-write_c.sh — deterministic, hexat-FREE regen of the
# generated artifact self/native/rtcore_fs-read-write.c from its emitter SSOT
# self/native/rtcore_fs-read-write_emit.hexa.
#
# WHY THIS EXISTS (zero-c leg-B, recursive zero-c ING #29):
#   self/native/rtcore_fs-read-write.c is a zero-c leg-B native seed (9 stdio
#   binary file-I/O HexaVal wrappers extracted from runtime_core.c). It used to
#   be a hand-assembled git-TRACKED .c. To make it ONE FEWER tracked self/**/*.c,
#   it gets a .hexa text-emitter SSOT (exactly like the runtime trio:
#   runtime_core.c <- runtime_core_emit.hexa). The .c becomes a GENERATED,
#   .gitignore'd artifact regenerated from the emitter on the build path.
#
# THE MECHANISM: the emitter bodies are pure `    buf = buf + "<C-line>"`
# literals whose un-escaped (\n \t \" \\) content IS the .c text VERBATIM. This
# is the SAME un-escaper tool/regen_runtime_core_c.sh uses (factored here so
# tool/regen_rtcore_fs-read-write_native_o.sh regenerates the .c from the emitter
# before compiling — DRY, reference-first: copy the working sibling, do not
# reinvent). The regen is byte-DETERMINISTIC (an ALREADY-FRESH tree gets a
# SHA-identical file — byte-neutral, no perf/byteeq drift).
#
# Usage:  bash tool/regen_rtcore_fs-read-write_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain
#   self/native/rtcore_fs-read-write_emit.hexa.
# Idempotent + NO-OP-SAFE: emitter absent -> keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/rtcore_fs-read-write_emit.hexa"
DST="$ROOT/self/native/rtcore_fs-read-write.c"

# Deterministic, hexat-FREE un-escaper for a *_emit.hexa SSOT -> its emitted .c.
# Returns 3 if the emitter has no recognizable buf-literal lines.
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

[ -f "$EMITTER" ] || { echo "[regen_rtcore_fs-read-write_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_rtcore_fs_rw_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -q 'HexaVal rt_read_file(HexaVal path)' "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_rtcore_fs-read-write_c] rtcore_fs-read-write.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_rtcore_fs-read-write_c] rtcore_fs-read-write.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_rtcore_fs-read-write_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
