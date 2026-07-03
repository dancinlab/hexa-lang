#!/usr/bin/env bash
# tool/regen_rtcore_map-query-fold_c.sh — deterministic, hexat-FREE regen of the
# generated artifact self/native/rtcore_map-query-fold.c from its emitter SSOT
# self/native/rtcore_map-query-fold_emit.hexa.
#
# WHY THIS EXISTS (zero-c leg-B, ING #29 — one fewer tracked self/**/*.c):
#   self/native/rtcore_map-query-fold.c is the hand-assembled map-query-fold seed
#   (8 unguarded map query HexaVal symbols, link de-risk). Per the B9.C .c-text
#   FOUNDATION pattern (runtime_core.c <- runtime_core_emit.hexa), the .c is now a
#   GENERATED, .gitignore'd BUILD ARTIFACT and the *_emit.hexa is the SSOT. The
#   seed .o build (tool/regen_rtcore_map-query-fold_native_o.sh) regenerates the
#   .c from this emitter FIRST, then compiles it — so the tracked .c can be
#   untracked (one fewer self/**/*.c).
#
# THE GUARANTEE: the regen is byte-DETERMINISTIC (the awk un-escape reproduces
# the emitter's own .c output VERBATIM — proven cmp exit 0 / SHA-identical at
# land), so the compiled seed .o is byte-IDENTICAL ⇒ build byte-NEUTRAL (no
# perf change, no byteeq drift). A stale/absent .c gets resynthesized.
#
# This is the SAME un-escaper tool/regen_runtime_core_c.sh uses for runtime_core.c
# (copied verbatim — DRY, reference-first: reuse the working sibling, do not
# reinvent). Only the EMITTER/DST paths + the sentinel grep differ.
#
# Usage:  bash tool/regen_rtcore_map-query-fold_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/native/rtcore_map-query-fold_emit.hexa.
# Idempotent + NO-OP-SAFE: emitter absent -> keep in-tree .c (return 0, no change).
set -u
ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/rtcore_map-query-fold_emit.hexa"
DST="$ROOT/self/native/rtcore_map-query-fold.c"

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

[ -f "$EMITTER" ] || { echo "[regen_rtcore_map-query-fold_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_rtcore_mqf_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -q 'hexa_map_to_array' "$atmp"; then
    # Only overwrite (and announce) when the content actually differs, so a fresh
    # warm tree is a true no-op and the message noise stays meaningful.
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_rtcore_map-query-fold_c] rtcore_map-query-fold.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_rtcore_map-query-fold_c] rtcore_map-query-fold.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_rtcore_map-query-fold_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
