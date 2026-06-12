#!/usr/bin/env sh
# =============================================================================
# HEXA-0POD OP-66 — flame production step-path libm-FREE tripwire (LOCAL, 0-GPU)
# =============================================================================
# Purpose
#   Lock determinism-contract LAYER 2 (docs/flame-determinism-contract.md §1):
#   the flame CLMConvMoE PRODUCTION training step must call NO libm transcendental
#   (exp / erf / cos / sin / tanh / log / sqrt / pow / atan / acos / asin). Every
#   such function on the step is hand-rolled (dt_exp / dt_erf / dt_ln / _moe_exp /
#   d5_cos / Newton sqrt) precisely because libm is NOT correctly-rounded and so
#   DIVERGES across arch/OS (glibc vs Darwin) — F-OP19 measured CE-bwd libm `exp`
#   differ 4/4096 grad elems by 1 ULP; F-OP19b the GELU `erf`; F-OP33 a libm `cos`
#   LR schedule (10/500 steps 1-4 ULP). A future edit could route a raw `exp(` /
#   `erf(` / `cos(` back into the step (the LEGACY clm_step.hexa smoke still uses
#   raw `exp`) and re-open the cross-platform byte-divergence with NO gate catching
#   it. This static tripwire is that gate.
#
# WHAT IT CHECKS
#   A purely-lexical grep over the PRODUCTION step-path source — clm_prod.hexa and
#   the SUBSET of each imported lib that the production CLMConvMoE step actually
#   reaches — asserting ZERO raw libm transcendental CALL-SITES. The deliberate
#   differential-oracle reference paths (functions named *_libm / _sel_exp /
#   _sel_erf whose PURPOSE is to demonstrate libm diverges vs the dt_ twin) are
#   EXEMPT by name — they are test scaffolding, never the production step.
#
# LOW BLAST RADIUS — this is NOT a repo-wide "no libm" ban:
#   * It scans ONLY the explicit FILES allow-list below (the production step-path).
#     The attention / RoPE / SwiGLU decoder path (nn_lib `nn_attn_*`, `_nn_sigmoid`,
#     `nn_rope_*`) legitimately uses libm and is a DIFFERENT architecture the
#     CLMConvMoE production trainer never calls — it is intentionally NOT scanned.
#   * It matches only WHOLE-WORD libm-builtin call-sites in code (comments and
#     the dt_/d5_/_moe_/Newton hand-rolled wrappers are excluded), so it cannot
#     false-positive on a doc mention or a deterministic twin.
#   * Verified to report 0 violations on the current clean tree (every production
#     step function uses a dt_/d5_/_moe_/Newton primitive), so the gate passes on
#     main and fails ONLY if a raw libm call regresses onto the step.
#
# Exit: 0 = production step-path libm-free; 1 = a raw libm call-site regressed;
#       2 = SETUP/INFRA (a guarded file is absent — neutral, never a false-fail).
# =============================================================================
set -eu

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

# --- Production step-path allow-list ----------------------------------------
# clm_prod.hexa (the production trainer) + the libs it imports. Each was
# confirmed raw-libm-free on the current tree (production-reachable surface).
FILES="
stdlib/flame/clm_prod.hexa
stdlib/flame/flame_math.hexa
stdlib/flame/gn_lib.hexa
stdlib/flame/optim_lib.hexa
stdlib/flame/conv_lib.hexa
stdlib/flame/moe_lib.hexa
stdlib/flame/quant_lib.hexa
stdlib/flame/tensor_lib.hexa
"
# nn_lib.hexa is scanned with a function-scope RESTRICTION (below): the CLMConvMoE
# production step reaches only nn_ce_loss_allpos / nn_embedding_* / nn_gelu_* /
# nn_groupnorm_* / nn_moe_router_* (all raw-libm-free); the attention/RoPE/SwiGLU
# functions (_nn_softmax_row, nn_attn_core_*, _nn_sigmoid, nn_rope_*, _nn_sqrt)
# legitimately use libm and are NOT on the CLMConvMoE step. We scan nn_lib's
# production-reachable functions explicitly.
NN_LIB="stdlib/flame/nn_lib.hexa"
NN_PROD_FNS="nn_ce_loss_allpos nn_embedding_fwd nn_embedding_bwd_scatter nn_gelu_fwd nn_gelu_bwd nn_groupnorm_fwd nn_groupnorm_bwd nn_moe_router_fwd nn_moe_router_bwd"

# The libm transcendental builtins forbidden on the step.
LIBM_RE='(^|[^a-zA-Z0-9_])(exp|erf|cos|sin|tanh|log|sqrt|pow|atan|acos|asin)[[:space:]]*\('
# Deterministic / hand-rolled wrappers + deliberate differential references to EXCLUDE.
ALLOW_RE='dt_exp|dt_erf|dt_ln|dt_sqrt|d5_cos|d5_sin|d5_pi|_moe_exp|_gn_sqrt|_adamw_sqrt|_nn_sqrt|_ce_grad_libm|_sel_exp|_sel_erf'

echo "OP-66 flame step-path libm-free gate — production CLMConvMoE determinism LAYER 2"
echo "forbidden on step: libm exp/erf/cos/sin/tanh/log/sqrt/pow/atan/acos/asin"

fail=0
checked=0

# scan_file: grep libm call-sites, drop full-line // comments, drop allow-list.
scan_file() {
  f="$1"
  grep -nE "$LIBM_RE" "$f" 2>/dev/null \
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
    echo "  FAIL  $f  (raw libm transcendental on the production step-path)"
    echo "$hits" | sed 's/^/        /'
    fail=1
  fi
done

# nn_lib: scan ONLY the production-reachable functions. Extract each function
# body (brace-balanced) and check it for raw libm call-sites.
if [ -f "$NN_LIB" ]; then
  checked=$((checked + 1))
  nn_hits=""
  for fn in $NN_PROD_FNS; do
    body="$(awk -v F="$fn" '
      $0 ~ ("(pub )?fn "F"\\(") { inb=1; depth=0; seen=0 }
      inb { print NR": "$0 }
      inb { d=gsub(/\{/,"{"); depth+=d; if(d>0) seen=1 }
      inb { depth-=gsub(/\}/,"}"); if(seen && depth<=0) inb=0 }
    ' "$NN_LIB")"
    fh="$(printf '%s\n' "$body" \
      | grep -nE "$LIBM_RE" 2>/dev/null \
      | grep -vE "$ALLOW_RE" || true)"
    if [ -n "$fh" ]; then
      nn_hits="${nn_hits}
  [$fn]
$(printf '%s\n' "$fh" | sed 's/^/        /')"
    fi
  done
  if [ -z "$nn_hits" ]; then
    echo "  PASS  $NN_LIB  (production-reachable fns only)"
  else
    echo "  FAIL  $NN_LIB  (raw libm in a production-reachable function)"
    printf '%s\n' "$nn_hits"
    fail=1
  fi
else
  echo "  SKIP (absent): $NN_LIB"
fi

if [ "$checked" -eq 0 ]; then
  echo "flame_steppath_libm_gate: no guarded files present — nothing checked" >&2
  exit 2
fi

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "GATE FAILED: a raw libm transcendental regressed onto the flame production step-path."
  echo "FIX: route it through the deterministic twin — dt_exp / dt_erf / dt_ln /"
  echo "     _moe_exp / d5_cos / Newton sqrt (see docs/flame-determinism-contract.md §1)."
  echo "     libm is not correctly-rounded -> diverges glibc vs Darwin -> breaks byte-eq."
  exit 1
fi

echo ""
echo "GATE PASSED: $checked guarded flame step-path file(s) libm-transcendental-free."
exit 0
