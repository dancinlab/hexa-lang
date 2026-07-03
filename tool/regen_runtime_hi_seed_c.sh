#!/usr/bin/env bash
# tool/regen_runtime_hi_seed_c.sh — deterministic, hexat-FREE regen of the
# generated seed artifact self/native/runtime_hi_seed.c from its emitter SSOT
# self/runtime_emit.hexa (RFC 061 ∅ campaign, zero-c r13, ING #35).
#
# This is the SAME awk un-escaper tool/regen_runtime_core_c.sh uses (the
# emitter bodies are pure `    buf = buf + "<C-line>"` literals whose
# un-escaped \n \t \" \\ content IS the .c text VERBATIM). Factored here so the
# r13 measure harness can regenerate the HI-tier seed .c from the committed
# emitter, hexat-free, byte-deterministically.
#
# The emitted .c is compiled (1-line TU pulling runtime.h) into the seed .o
# ONLY under the experimental drop path — the DEFAULT build never compiles it.
#
# Usage:  bash tool/regen_runtime_hi_seed_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/runtime_emit.hexa.
# Idempotent + NO-OP-SAFE: emitter absent → return 0, no change.
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/runtime_emit.hexa"
DST="$ROOT/self/native/runtime_hi_seed.c"

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

[ -f "$EMITTER" ] || { echo "[regen_runtime_hi_seed_c] SKIP — emitter absent ($EMITTER)"; exit 0; }
mkdir -p "$(dirname "$DST")"

atmp="$(mktemp -t regen_runtime_hi_seed_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -q 'HexaVal rt_isalnum' "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_runtime_hi_seed_c] runtime_hi_seed.c SYNTHESIZED from emitter SSOT ($(wc -l < "$DST") lines, hexat-free)"
    else
        echo "[regen_runtime_hi_seed_c] runtime_hi_seed.c already fresh (byte-identical) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_runtime_hi_seed_c] SKIP — emitter has no recognizable buf-literal lines" >&2
exit 0
