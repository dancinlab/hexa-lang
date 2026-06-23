#!/usr/bin/env bash
# tool/regen_hxqwen14b_p1d_cmp_c.sh — deterministic, hexat-FREE regen of the
# generated artifact self/native/hxqwen14b_p1d_cmp.c from its emitter SSOT
# self/native/hxqwen14b_p1d_cmp_emit.hexa.
#
# WHY (selfhost zero-c final6, ING #29):
#   hxqwen14b_p1d_cmp.c is a small hand-written bench/oracle .c (compares two
#   p1d_driver dumps: oracle vs own GEMM). It was the last git-tracked self-tree
#   .c with no emitter SSOT. gen_c_text_emitter.hexa now mechanically produced a
#   byte-verbatim emitter for it, so the .c becomes a .gitignore'd BUILD
#   ARTIFACT regenerated from the emitter (the same .c-text FOUNDATION pattern as
#   the runtime trio + rtcore seeds). The regen is byte-DETERMINISTIC (the awk
#   un-escape reproduces the emitter's own .c output VERBATIM), so an
#   already-fresh tree gets a SHA-identical file (byte-neutral, no perf change).
#
#   NOTE: this .c is NOT referenced by any build script (pure bench/optional —
#   compiled standalone with `cc -O2 hxqwen14b_p1d_cmp.c -lm`), so there is no
#   build wire — this script just keeps the artifact synthesizable from its SSOT.
#
# This is the SAME un-escaper tool/regen_runtime_core_c.sh uses (copied verbatim,
# reference-first — DRY).
#
# Usage:  bash tool/regen_hxqwen14b_p1d_cmp_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain the emitter SSOT.
# Idempotent + NO-OP-SAFE: emitter absent -> keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/hxqwen14b_p1d_cmp_emit.hexa"
DST="$ROOT/self/native/hxqwen14b_p1d_cmp.c"

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

[ -f "$EMITTER" ] || { echo "[regen_hxqwen14b_p1d_cmp_c] SKIP — emitter absent ($EMITTER)"; exit 0; }
mkdir -p "$(dirname "$DST")"

atmp="$(mktemp -t regen_hxqwen14b_p1d_cmp_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -qF "p1d_driver dumps (oracle vs own GEMM)" "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_hxqwen14b_p1d_cmp_c] hxqwen14b_p1d_cmp.c SYNTHESIZED from emitter SSOT ($(wc -l < "$DST") lines, hexat-free)"
    else
        echo "[regen_hxqwen14b_p1d_cmp_c] hxqwen14b_p1d_cmp.c already fresh (byte-identical) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_hxqwen14b_p1d_cmp_c] SKIP — emitter has no recognizable buf-literal lines" >&2
exit 0
