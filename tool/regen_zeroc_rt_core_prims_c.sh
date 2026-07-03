#!/usr/bin/env bash
# tool/regen_zeroc_rt_core_prims_c.sh — ZERO-C recursive (ING #29).
# Deterministic, hexat-FREE regen of the generated artifact
# self/native/zeroc_rt_core_prims.c from its emitter SSOT
# self/native/zeroc_rt_core_prims_emit.hexa.
#
# WHY THIS EXISTS:
#   self/native/zeroc_rt_core_prims.c is the self-contained numeric/coercion
#   rt_* CORE prims seed the zero-c drop-ON executable link needs. It is now a
#   GENERATED, .gitignore'd artifact (last emitter-less self-tree .c to gain a
#   .hexa SSOT). The emitter <base>_emit.hexa is the source of truth; this
#   script reproduces the .c byte-deterministically from it before any build
#   step compiles it (regen_zeroc_rt_core_prims_o.sh).
#
#   The awk un-escaper is the SAME one tool/regen_runtime_core_c.sh uses (the
#   emitter bodies are pure `    buf = buf + "<C-line>"` literals whose
#   un-escaped \n \t \" \\ content IS the .c text VERBATIM). Reference-first:
#   copy the working sibling, do not reinvent.
#
# Usage:  bash tool/regen_zeroc_rt_core_prims_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain the emitter SSOT.
# Idempotent + NO-OP-SAFE: emitter absent -> keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/zeroc_rt_core_prims_emit.hexa"
DST="$ROOT/self/native/zeroc_rt_core_prims.c"

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

[ -f "$EMITTER" ] || { echo "[regen_zeroc_rt_core_prims_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_zeroc_rt_core_prims_c.XXXXXX)" || atmp=""
# Unique sentinel: a function only this .c defines (grep -qF, fixed-string).
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -qF "rt_format_float_sci" "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_zeroc_rt_core_prims_c] zeroc_rt_core_prims.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_zeroc_rt_core_prims_c] zeroc_rt_core_prims.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_zeroc_rt_core_prims_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
