#!/usr/bin/env bash
# tool/regen_runtime_cuda_c.sh — deterministic, hexat-FREE regen of the generated
# artifact self/cuda/runtime_cuda.c from its emitter SSOT
# self/cuda/runtime_cuda_emit.hexa.
#
# WHY THIS EXISTS (zero-c ING #29 final6, runtime_cuda graduation):
#   self/cuda/runtime_cuda.c is the DETERMINISTIC output of its emitter SSOT
#   self/cuda/runtime_cuda_emit.hexa. The emitter was rebuilt by
#   tool/gen_c_text_emitter.hexa into the `    buf = buf + "<C-line>"` per-line
#   literal form (the SAME form runtime_core_emit.hexa uses), so the .c can now
#   be reproduced by a pure awk un-escape WITHOUT any hexa runner — closing the
#   "a hexa RUNNER is REQUIRED for the cuda emitter" dependency that
#   resolve_cuda_runtime_seed (tool/stage_resolve_runtime_a) had to work around.
#
#   IMPORTANT — RELEASE INTEGRITY (#3701): self/cuda/runtime_cuda.c stays
#   CHECKED IN (NOT gitignored). It is the PRIMARY, stale-runner-immune build
#   seed for the -cuda release job: resolve_cuda_runtime_seed runs at Stage 0b,
#   BEFORE build/hexat exists, so the only emit-runner would be a stale edge
#   binary whose native-run fast-path can SIGSEGV before writing the 333KB file
#   → the -cuda asset silently never ships (v0.245.x had no hexa-*-cuda.tar.gz).
#   Committing the deterministic emitter output is what fixed that. This script
#   is the hexat-free REGEN you run after editing the emitter, then commit — it
#   does NOT change the committed-seed discipline.
#
# The un-escaper is byte-DETERMINISTIC: an ALREADY-FRESH tree gets a
# SHA-identical file (byte-neutral, no perf change, no nvcc-input change — the
# generated .c is still the same CUDA C for nvcc under -DHEXA_CUDA). A STALE
# tree gets corrected.
#
# This is the SAME un-escaper tool/regen_runtime_core_c.sh uses (factored here
# for the cuda emitter — reference-first: copy the working sibling verbatim).
#
# Usage:  bash tool/regen_runtime_cuda_c.sh [REPO_ROOT]
#   REPO_ROOT defaults to $PWD; must contain self/cuda/runtime_cuda_emit.hexa.
# Idempotent + NO-OP-SAFE: emitter absent → keep in-tree .c (return 0, no change).
set -u

ROOT="${1:-$PWD}"
EMITTER="$ROOT/self/cuda/runtime_cuda_emit.hexa"
DST="$ROOT/self/cuda/runtime_cuda.c"

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

[ -f "$EMITTER" ] || { echo "[regen_runtime_cuda_c] SKIP — emitter absent ($EMITTER)"; exit 0; }

atmp="$(mktemp -t regen_runtime_cuda_c.XXXXXX)" || atmp=""
if [ -n "$atmp" ] && _unescape_emit_to_c "$EMITTER" > "$atmp" 2>/dev/null \
   && [ -s "$atmp" ] && grep -qF 'anima RFC 040 Phase A real-cuBLAS impl' "$atmp"; then
    if [ ! -f "$DST" ] || ! cmp -s "$atmp" "$DST"; then
        cp -f "$atmp" "$DST"
        echo "[regen_runtime_cuda_c] runtime_cuda.c SYNTHESIZED from emitter SSOT (awk un-escape, $(wc -l < "$DST") lines, hexat-free) — was stale/absent"
    else
        echo "[regen_runtime_cuda_c] runtime_cuda.c already fresh (byte-identical to emitter SSOT) — no-op"
    fi
    rm -f "$atmp"
    exit 0
fi
rm -f "$atmp"
echo "[regen_runtime_cuda_c] SKIP — emitter has no recognizable buf-literal lines (in-tree .c kept)" >&2
exit 0
