#!/usr/bin/env bash
# tool/regen_hxqwen14b_p1d_hxlcl_c.sh — deterministic, hexat-FREE regen of the
# generated artifact self/native/hxqwen14b_p1d_hxlcl.c from its emitter SSOT
# self/native/hxqwen14b_p1d_hxlcl_emit.hexa.
#
# WHY (selfhost zero-c · ING #29 · final-6 recursive emitter-gen):
#   hxqwen14b_p1d_hxlcl.c is the standalone Phase-1d LoRA correctness driver
#   syscall-wrapper .c. Like the runtime trio (runtime.c / runtime_core.c /
#   runtime_hi_gen.c) it is now SOURCED from a .hexa text-emitter so the .c is
#   a GENERATED, .gitignore'd artifact and the emitter is the SSOT. This file
#   is NOT referenced by any build script (a pure optional standalone driver),
#   so there is no compile wire — this regen exists for the clean-checkout SSOT
#   round-trip + as the canonical regenerator if the .c is ever needed.
#
# The regen is byte-DETERMINISTIC: the awk un-escape reproduces the emitter's
# own .c output VERBATIM (cmp exit 0 vs the committed .c), so an already-fresh
# tree gets a SHA-identical file — byte-neutral, no perf/byteeq drift.
#
# This is the SAME un-escaper tool/regen_runtime_core_c.sh uses (copied verbatim
# — reference-first: reuse the working sibling, do not reinvent).
#
# Usage:  bash tool/regen_hxqwen14b_p1d_hxlcl_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain the emitter under self/native/.
# Idempotent + NO-OP-SAFE: emitter absent -> keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/hxqwen14b_p1d_hxlcl_emit.hexa"
DST="$ROOT/self/native/hxqwen14b_p1d_hxlcl.c"

# Deterministic, hexat-FREE un-escaper for a *_emit.hexa SSOT -> its emitted .c.
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

[ -f "$EMITTER" ] || { echo "[regen_hxqwen14b_p1d_hxlcl] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_hxqwen14b_p1d_hxlcl.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -qF "hxlcl_open_sys" "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_hxqwen14b_p1d_hxlcl] hxqwen14b_p1d_hxlcl.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_hxqwen14b_p1d_hxlcl] hxqwen14b_p1d_hxlcl.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_hxqwen14b_p1d_hxlcl] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
