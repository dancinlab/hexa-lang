#!/usr/bin/env sh
# =============================================================================
# HEXA-0POD OP-69 — flame production step-path FMA-fused-matmul tripwire (LOCAL, 0-GPU)
# =============================================================================
# Purpose
#   Lock determinism-contract LAYER 3 (docs/flame-determinism-contract.md §1,
#   "cross-ISA invariant: matmul = inline ascending reduction, NOT FMA-fused"):
#   the flame CLMConvMoE PRODUCTION training step must NOT route any determinism-
#   path matmul through the raw FMA-fused C `farr_matmul` kernel (nor the thin
#   `t_matmul` wrapper around it). clang -O2 contracts `a*b+c` into a single
#   fused-multiply-add on arm64 (1 rounding) but emits a separate mul+add on x86
#   (2 roundings), so an ACCUMULATING farr_matmul returns DIFFERENT bytes per ISA
#   even on byte-identical fp64 inputs — F-OP29 measured exactly this (an 8x8.8x4
#   matmul gave arm64 ck 241449363 vs x86 ck 1401117690). A determinism-path
#   matmul must instead go through the `forge_dispatch_matmul` DISPATCHER seam
#   (which on a CUDA host is cuBLAS and whose CPU cross-ISA byte-eq is the
#   F-OP29-closed property) OR an inline ascending-order dot product.
#
#   The CLMConvMoE production trainer (clm_prod.hexa) already complies: its conv
#   GEMMs route through `forge_dispatch_matmul` (conv1d_via_forge /
#   conv1d_bwd_via_forge), NOT raw farr_matmul/t_matmul. This invariant is fully
#   DOCUMENTED (LAYER 3) and HELD in source, but enforced by NOTHING — a future
#   edit could wire a raw `farr_matmul(`/`t_matmul(` into the trainer (the
#   cache-friendly FMA-fused kernel is RIGHT THERE in tensor_lib) and silently
#   re-open the cross-ISA byte-divergence. This static tripwire is that gate.
#
# WHAT IT CHECKS
#   A purely-lexical grep over the CLMConvMoE PRODUCTION trainer source
#   (clm_prod.hexa + the production-reachable matmul-free libs) asserting ZERO
#   raw `farr_matmul(` / `t_matmul(` CALL-SITES. The `forge_dispatch_matmul*`
#   dispatcher seam is the COMPLIANT path and is NOT flagged (it is not the raw
#   FMA-fused kernel — it is the determinism-path dispatcher F-OP29 blesses).
#
# LOW BLAST RADIUS — this is NOT a repo-wide "no farr_matmul" ban:
#   * It scans ONLY the explicit FILES allow-list below (the CLMConvMoE production
#     trainer + its matmul-free production libs). It does NOT scan:
#       - nn_lib.hexa (the attention/SwiGLU/MLP DECODER architecture — a DIFFERENT
#         model the CLMConvMoE trainer never invokes; its farr_matmul use is the
#         anima-byte-eq decoder path, off the CLMConvMoE step);
#       - decoder_block_lib.hexa (the OP-29 2nd architecture — DELIBERATELY routes
#         _db_proj_batch_farr/_db_grad_accum_farr through farr_matmul to match
#         anima d5_proj_batch_g flame<->anima byte-eq; its cross-ISA layer is the
#         DOCUMENTED-DEFERRED case, not the CLMConvMoE flagship);
#       - tensor_lib.hexa (DEFINES t_matmul/farr_matmul — the primitive itself).
#   * It matches only WHOLE-WORD raw-kernel call-sites in code (comments and the
#     `forge_dispatch_matmul`/`forge_dispatch_matmul_batched`/`_t` dispatcher seam
#     are excluded), so it cannot false-positive on a doc mention or the seam.
#   * Verified to report 0 violations on the current clean tree (the production
#     trainer routes every matmul through forge_dispatch_matmul), so the gate
#     passes on main and fails ONLY if a raw FMA-fused matmul regresses onto the
#     trainer.
#
# Exit: 0 = trainer raw-FMA-matmul-free; 1 = a raw farr_matmul/t_matmul regressed;
#       2 = SETUP/INFRA (a guarded file is absent — neutral, never a false-fail).
# =============================================================================
set -eu

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

# --- CLMConvMoE production trainer step-path allow-list -----------------------
# clm_prod.hexa (the production trainer) + the production-reachable libs that are
# matmul-free (their GEMMs, if any, route through forge_dispatch_matmul). Each was
# confirmed raw-farr_matmul/t_matmul-free on the current tree.
#
#   EXCLUDED by design (see header LOW BLAST RADIUS):
#     - stdlib/flame/tensor_lib.hexa  (DEFINES t_matmul/farr_matmul — primitive)
#     - stdlib/flame/conv_lib.hexa    (nn_conv1d_* use t_matmul, but the trainer
#                                      uses its OWN inlined conv1d_via_forge that
#                                      routes through forge_dispatch_matmul — the
#                                      nn_conv1d_* path is NOT on the CLMConvMoE
#                                      production step)
#     - stdlib/flame/nn_lib.hexa      (attention/SwiGLU/MLP decoder architecture)
#     - stdlib/flame/decoder_block_lib.hexa (OP-29 2nd arch — deferred cross-ISA)
FILES="
stdlib/flame/clm_prod.hexa
stdlib/flame/flame_math.hexa
stdlib/flame/gn_lib.hexa
stdlib/flame/optim_lib.hexa
stdlib/flame/moe_lib.hexa
stdlib/flame/quant_lib.hexa
"

# The raw FMA-fused C matmul kernel + its thin wrapper, forbidden on the trainer.
FMA_RE='(^|[^a-zA-Z0-9_])(farr_matmul|t_matmul)[[:space:]]*\('
# The COMPLIANT determinism-path dispatcher seam to EXCLUDE (NOT the raw kernel):
# forge_dispatch_matmul / forge_dispatch_matmul_t / forge_dispatch_matmul_batched.
ALLOW_RE='forge_dispatch_matmul'

echo "OP-69 flame trainer step-path FMA-fused-matmul gate — CLMConvMoE determinism LAYER 3"
echo "forbidden on the trainer step: raw FMA-fused farr_matmul( / t_matmul("
echo "compliant: forge_dispatch_matmul dispatcher seam (cross-ISA F-OP29) / inline ascending dot"

fail=0
checked=0

# scan_file: grep raw-kernel call-sites, drop full-line // comments, drop the seam.
scan_file() {
  f="$1"
  grep -nE "$FMA_RE" "$f" 2>/dev/null \
    | grep -vE '^[0-9]+:[[:space:]]*//' \
    | grep -vE "$ALLOW_RE" || true
}

for f in $FILES; do
  [ -n "$f" ] || continue
  if [ ! -f "$f" ]; then
    echo "  SKIP (absent): $f"
    continue
  fi
  checked=$((checked + 1))
  hits="$(scan_file "$f")"
  if [ -z "$hits" ]; then
    echo "  PASS  $f"
  else
    echo "  FAIL  $f  (raw FMA-fused matmul on the production trainer step-path)"
    echo "$hits" | sed 's/^/        /'
    fail=1
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "flame_steppath_fma_gate: no guarded files present — nothing checked" >&2
  exit 2
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "GATE FAILED: a raw FMA-fused matmul regressed onto the flame CLMConvMoE production trainer."
  echo "FIX: route it through the determinism-path dispatcher seam forge_dispatch_matmul(...) —"
  echo "     cuBLAS on a CUDA host, cross-ISA-folded on CPU (F-OP29) — or an inline ascending-order"
  echo "     dot product. The raw farr_matmul/t_matmul C kernel is FMA-fused under clang -O2: it"
  echo "     gives a single fma on arm64 (1 rounding) but mul+add on x86 (2 roundings) -> divergent"
  echo "     bytes per ISA on an accumulating matmul -> breaks machine-independent byte-eq."
  echo "     See docs/flame-determinism-contract.md §1 (cross-ISA invariant, LAYER 3)."
  exit 1
fi

echo ""
echo "GATE PASSED: $checked guarded flame trainer step-path file(s) raw-FMA-matmul-free."
exit 0
