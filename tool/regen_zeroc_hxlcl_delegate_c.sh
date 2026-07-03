#!/usr/bin/env bash
# tool/regen_zeroc_hxlcl_delegate_c.sh — deterministic, hexat-FREE regen of the
# generated artifact self/native/zeroc_hxlcl_delegate.c from its emitter SSOT
# self/native/zeroc_hxlcl_delegate_emit.hexa (ZERO-C recursive, ING #29).
#
# WHY THIS EXISTS (recursive zero-c — the self-tree .c becomes a generated artifact):
#   self/native/zeroc_hxlcl_delegate.c is the 17 EXTERNAL hxlcl_* delegate seed
#   (+ r23 mem/str + r25 syscall statics) consumed by
#   tool/regen_zeroc_hxlcl_delegate_o.sh. To make the whole self-tree .c surface
#   emitter-generated (like the runtime trio + rtcore seeds), the hand-written .c
#   is recast as a .c-text emitter (gen_c_text_emitter.hexa) and the .c becomes a
#   .gitignore-d, regenerated artifact. This un-escaper reproduces the emitter's
#   own .c output VERBATIM (byte-DETERMINISTIC) so an already-fresh tree gets a
#   SHA-identical file — byte-NEUTRAL (no .o change, no byteeq drift). A
#   stale/absent .c gets (re)synthesized.
#
#   SAME un-escaper as tool/regen_runtime_core_c.sh (factored verbatim — DRY,
#   reference-first: copy the working sibling, do not reinvent).
#
# Usage:  bash tool/regen_zeroc_hxlcl_delegate_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/native/zeroc_hxlcl_delegate_emit.hexa.
# Idempotent + NO-OP-SAFE: emitter absent -> keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/native/zeroc_hxlcl_delegate_emit.hexa"
DST="$ROOT/self/native/zeroc_hxlcl_delegate.c"

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

[ -f "$EMITTER" ] || { echo "[regen_zeroc_hxlcl_delegate_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_zeroc_hxlcl_delegate_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -qF "hxlcl_fmod(double x, double y)" "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_zeroc_hxlcl_delegate_c] zeroc_hxlcl_delegate.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_zeroc_hxlcl_delegate_c] zeroc_hxlcl_delegate.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_zeroc_hxlcl_delegate_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
