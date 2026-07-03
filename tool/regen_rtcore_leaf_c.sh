#!/usr/bin/env bash
# tool/regen_rtcore_leaf_c.sh — deterministic, hexat-FREE regen of the generated
# artifact self/native/rtcore_leaf.c from its emitter SSOT
# self/native/rtcore_leaf_emit.hexa (zero-c leg-B, ING #29 — give the leaf seed a
# .hexa text-emitter SSOT so the .c becomes a regenerated/gitignored artifact,
# exactly like the runtime trio runtime_core.c←runtime_core_emit.hexa).
#
# WHY THIS EXISTS:
#   self/native/rtcore_leaf.c is the zero-c leg-B leaf-cluster seed (the 10
#   HexaVal value-ctor/reinterpret symbols externed away under
#   HEXA_RT_CORE_LEAF_NATIVE). tool/regen_rtcore_leaf_native_o.sh #include's it
#   into a 1-line TU and compiles it to build/rtcore_leaf_native.o. To shrink the
#   tracked-self/**/*.c surface by one, the .c is now a BUILD ARTIFACT
#   regenerated verbatim from the emitter SSOT before compile, and is gitignored.
#
# The regen is byte-DETERMINISTIC (the awk un-escape reproduces the emitter's own
# .c output VERBATIM), so an ALREADY-FRESH tree gets a SHA-identical file — this
# is byte-neutral (no perf change, no byteeq drift). A STALE/ABSENT tree gets
# (re)synthesized.
#
# This is the SAME un-escaper tool/regen_runtime_core_c.sh uses (factored here so
# the rtcore_leaf seed reuses it verbatim — DRY, reference-first: copy the working
# sibling, do not reinvent).
#
# Usage:  bash tool/regen_rtcore_leaf_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/native/rtcore_leaf_emit.hexa.
# Idempotent + NO-OP-SAFE: emitter absent → keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/rtcore_leaf_emit.hexa"
DST="$ROOT/self/native/rtcore_leaf.c"

# Deterministic, hexat-FREE un-escaper for a *_emit.hexa SSOT → its emitted .c.
# The emitter bodies are pure `    buf = buf + "<C-line>"` literals whose
# un-escaped (\n \t \" \\) content IS the .c text VERBATIM. Returns 3 if the
# emitter has no recognizable buf-literal lines.
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

[ -f "$EMITTER" ] || { echo "[regen_rtcore_leaf_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_rtcore_leaf_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -q 'HexaVal hexa_enum_str_v' "$atmp"; then
    # Only overwrite (and announce) when the content actually differs, so a fresh
    # warm tree is a true no-op and the message noise stays meaningful.
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_rtcore_leaf_c] rtcore_leaf.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_rtcore_leaf_c] rtcore_leaf.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_rtcore_leaf_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
