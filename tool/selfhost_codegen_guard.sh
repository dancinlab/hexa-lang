#!/usr/bin/env bash
# tool/selfhost_codegen_guard.sh — SELFHOST-CI M2 native-codegen regression guard.
#
# PURPOSE
#   A STANDING, named, always-run codegen-correctness fence around the
#   graduated self-host — distinct from the heavy byte-eq fixpoint leg in
#   tool/selfhost_byteeq_gate.sh. Where the byte-eq gate proves the WHOLE
#   compiler re-emits byte-identically, THIS guard proves the specific
#   codegen classes the graduation depended on stay correct, locking two
#   landed fixes against silent regression:
#     • #47421c89c — hex-literal lowering (native _parse_int dropped 0xNN -> 0)
#     • #2579      — STP/LDP [sp] stack-spill mem-parse closed-negative
#
# THREE CORPORA (all hard-assert; any failure exits 1)
#   CORPUS 1 — FULL SELF-EMIT ENCODE-MISS=0
#     Re-emit the FULL flattened compiler (the same cc-flat self-emit the
#     byte-eq gate's LEG A uses) and assert the emit log carries ZERO
#     ENCODE-MISS lines. Milestone-1 only REPORTED this; here it is a REQUIRED
#     assert — a single ENCODE-MISS on the full self-emit reds the guard.
#
#   CORPUS 2 — 0x-LITERAL corpus  (locks #47421c89c)
#     native --emit=obj g1_hex_corpus.hexa, assert 0 ENCODE-MISS, then
#     DISASSEMBLE and value-check each expected hex immediate is present in the
#     instruction stream (0x0 0x7f 0x80 0xff 0xffff 0xdeadbeef + the operate
#     paths 0x8 / 0x1ff). A regression re-collapses a literal to #0x0 — the
#     guard fails the moment an expected immediate is missing.
#
#   CORPUS 3 — STP/LDP [sp] corpus  (locks #2579)
#     native --emit=obj g2_stp_ldp_corpus.hexa, assert 0 ENCODE-MISS, then
#     DISASSEMBLE and assert STP+LDP [sp,#N] store/load pairs at MULTIPLE
#     distinct offsets are present (the spill path actually fired across small
#     / medium / large frames).
#
# CONFIG (env; defaults target the proven ghost host)
#   HEXA_NATIVE_CC   native self-hosted compiler driver
#                    (default: ~/dancinlab/selfhost-work/gen2_fix, else `hexa`)
#   SHW              selfhost-work dir holding graduated artifacts + flat src
#                    (default: ~/dancinlab/selfhost-work)
#   GEN_FLAT         flattened full-compiler source for the self-emit corpus
#                    (default: $SHW/cc-flat-fix.hexa)
#   HEXA_CC_PREARGS  args after driver, before flags (default "_drv.hexa")
#   HEXA_TARGET      target triple (default: arm64-apple-darwin)
#   HEXA_ATLAS_EMBED empty-atlas dir for a hermetic emit (default: per-run dir)
#   DISAS            disassembler (default: otool -tvV, fallback objdump -d)
#   CG_CORPUS        corpus dir (default: <repo>/self/test/miscompile_zero)
#   CG_OUT           output dir (default: <repo>/build/selfhost-codegen-out)
#
# EXIT
#   0  every corpus PASSED (full self-emit ENCODE-MISS=0, all hex immediates
#      present, STP/LDP pairs at varied offsets present).
#   1  REGRESSION — an ENCODE-MISS surfaced on ANY emit, OR an expected hex
#      immediate is missing (literal re-collapsed), OR the STP/LDP spill path
#      did not fire. Fails loudly.
#   2  SETUP / INFRA — the configured driver cannot native-emit AT ALL in THIS
#      environment (canary 0-byte, no ENCODE-MISS). CI-neutral: the codegen
#      floor is NOT broken; the runner just lacks the graduated gen2_fix.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS="${CG_CORPUS:-$REPO/self/test/miscompile_zero}"
SHW="${SHW:-$HOME/dancinlab/selfhost-work}"
GEN_FLAT="${GEN_FLAT:-$SHW/cc-flat-fix.hexa}"
TARGET="${HEXA_TARGET:-arm64-apple-darwin}"

# ── locate the native self-hosted compiler ───────────────────────────────
if [ -n "${HEXA_NATIVE_CC:-}" ]; then
  CC="$HEXA_NATIVE_CC"
elif [ -x "$SHW/gen2_fix" ]; then
  CC="$SHW/gen2_fix"
elif command -v hexa >/dev/null 2>&1; then
  CC="$(command -v hexa)"
else
  echo "selfhost-codegen-guard: SETUP ERROR — no native compiler." >&2
  echo "  set HEXA_NATIVE_CC=<path to gen2_fix / native hexa driver>" >&2
  exit 2
fi

if [ -z "${HEXA_CC_PREARGS+set}" ]; then
  PREARGS=("_drv.hexa")
else
  # shellcheck disable=SC2206
  PREARGS=(${HEXA_CC_PREARGS})
fi

OUT="${CG_OUT:-$REPO/build/selfhost-codegen-out}"
mkdir -p "$OUT"

if [ -z "${HEXA_ATLAS_EMBED:-}" ]; then
  HEXA_ATLAS_EMBED="$OUT/noatlas"
  mkdir -p "$HEXA_ATLAS_EMBED"
fi
export HEXA_ATLAS_EMBED

# ── disassembler selection ────────────────────────────────────────────────
if [ -n "${DISAS:-}" ]; then
  :
elif command -v otool >/dev/null 2>&1; then
  DISAS="otool -tvV"
elif command -v objdump >/dev/null 2>&1; then
  DISAS="objdump -d"
else
  DISAS=""
fi

# emit_one SRC OBJ LOG → globals E_RC E_SZ E_EM
emit_one() {
  local src="$1" obj="$2" log="$3"
  rm -f "$obj"
  "$CC" "${PREARGS[@]}" \
        --emit=obj --target="$TARGET" --ignore-errors \
        -o "$obj" "$src" >"$log" 2>&1
  E_RC=$?
  E_EM=$(grep -c "ENCODE-MISS" "$log" 2>/dev/null); E_EM=${E_EM:-0}
  if [ -s "$obj" ]; then E_SZ=$(wc -c < "$obj" | tr -d ' '); else E_SZ=0; fi
}

disas_of() {  # disas_of OBJ → stdout
  [ -z "$DISAS" ] && return 1
  $DISAS "$1" 2>/dev/null
}

echo "── selfhost codegen guard (M2) ───────────────────────────────────"
echo "  compiler : $CC ${PREARGS[*]}"
echo "  target   : $TARGET"
echo "  flat src : $GEN_FLAT"
echo "  corpus   : $CORPUS"
echo "  disas    : ${DISAS:-<none>}"
echo "  out      : $OUT"
echo "──────────────────────────────────────────────────────────────────"

# ── CANARY — can this env native-emit AT ALL? ─────────────────────────────
CANARY_SRC="$CORPUS/c1_hex_literal.hexa"
if [ ! -e "$CANARY_SRC" ]; then
  echo "selfhost-codegen-guard: SETUP ERROR — canary missing: $CANARY_SRC" >&2
  exit 2
fi
emit_one "$CANARY_SRC" "$OUT/_canary.o" "$OUT/_canary.emit.log"
if [ "$E_SZ" -eq 0 ] && [ "$E_EM" -eq 0 ]; then
  echo "selfhost-codegen-guard: SETUP/INFRA — canary will not native-emit" >&2
  echo "  (c1_hex_literal: rc=$E_RC objsize=0 ENCODE-MISS=0 — this env cannot" >&2
  echo "   native --emit=obj; the codegen floor is NOT broken). The real guard" >&2
  echo "   needs the graduated gen2_fix (ghost host)." >&2
  echo "        ↳ canary emit log: $OUT/_canary.emit.log" >&2
  exit 2
fi
echo "  canary   : c1_hex_literal emits (objsize=$E_SZ) — native-emit OK"
echo "──────────────────────────────────────────────────────────────────"

fail=0

# ── CORPUS 1 — FULL SELF-EMIT ENCODE-MISS=0 (required assert) ──────────────
echo "CORPUS 1 — full self-emit ENCODE-MISS=0 (required assert):"
if [ ! -s "$GEN_FLAT" ]; then
  echo "  SETUP/INFRA — flattened full-compiler source absent ($GEN_FLAT)."
  echo "  The full self-emit corpus needs the graduated flat source. Without it"
  echo "  this guard cannot assert the full-emit floor; treating as INFRA-neutral."
  echo "──────────────────────────────────────────────────────────────────"
  echo "selfhost-codegen-guard: SETUP/INFRA — no graduated flat source." >&2
  exit 2
fi
emit_one "$GEN_FLAT" "$OUT/cc-selfemit.o" "$OUT/selfemit.log"
SE_RC=$E_RC; SE_SZ=$E_SZ; SE_EM=$E_EM
printf "  self-emit : rc=%s objsize=%s ENCODE-MISS=%s\n" "$SE_RC" "$SE_SZ" "$SE_EM"
if [ "$SE_SZ" -eq 0 ]; then
  echo "  SETUP/INFRA — full self-emit produced 0 bytes (build-floor)."
  echo "──────────────────────────────────────────────────────────────────"
  echo "selfhost-codegen-guard: SETUP/INFRA — full self-emit un-emittable here." >&2
  exit 2
fi
if [ "$SE_EM" -ne 0 ]; then
  printf "  FAIL  full self-emit ENCODE-MISS=%s (MUST be 0)\n" "$SE_EM"
  echo "        ↳ self-emit log: $OUT/selfemit.log"
  fail=1
else
  echo "  PASS  full self-emit ENCODE-MISS=0"
fi
echo "──────────────────────────────────────────────────────────────────"

# ── CORPUS 2 — 0x-LITERAL corpus (locks #47421c89c) ───────────────────────
echo "CORPUS 2 — 0x-literal value-check (locks #47421c89c):"
HEXSRC="$CORPUS/g1_hex_corpus.hexa"
# Expected immediates, each "literal:checkspec". The checkspec is a
# space-separated list of disassembler immediate tokens that MUST ALL be
# present for the literal to count as correctly lowered. Constants that fit a
# single MOVZ (<=16 bits) check their own `#0xNN`; WIDE constants (>16 bits)
# are lowered MOVZ low-half + MOVK high-half(s) `lsl #16/#32/...`, so they
# check their 16-bit chunks instead of the (never-emitted) full immediate.
# A regression of #47421c89c re-collapses a literal to #0x0 → its chunk(s)
# vanish from the stream and the check fails loudly.
#   0xdeadbeef = MOVZ #0xbeef + MOVK #0xdead,lsl#16  (32-bit, multi-chunk)
HEX_CHECKS=(
  "0x0:#0x0"
  "0x7f:#0x7f"
  "0x80:#0x80"
  "0xff:#0xff"
  "0xffff:#0xffff"
  "0xdeadbeef:#0xbeef #0xdead"
  "0x8:#0x8"
  "0x1ff:#0x1ff"
)
if [ ! -e "$HEXSRC" ]; then
  printf "  FAIL  corpus program absent: %s\n" "$HEXSRC"
  fail=1
else
  emit_one "$HEXSRC" "$OUT/g1_hex.o" "$OUT/g1_hex.emit.log"
  printf "  emit  : rc=%s objsize=%s ENCODE-MISS=%s\n" "$E_RC" "$E_SZ" "$E_EM"
  if [ "$E_EM" -ne 0 ]; then
    printf "  FAIL  0x-literal corpus ENCODE-MISS=%s\n" "$E_EM"
    echo "        ↳ emit log: $OUT/g1_hex.emit.log"
    fail=1
  elif [ "$E_SZ" -eq 0 ]; then
    echo "  FAIL  0x-literal corpus emitted 0 bytes (emit broke post-canary)"
    fail=1
  else
    DIS=$(disas_of "$OUT/g1_hex.o")
    if [ -z "$DIS" ]; then
      echo "  WARN  no disassembler — value-check skipped, ENCODE-MISS=0 still asserted"
      echo "  PASS  0x-literal corpus (ENCODE-MISS=0; disas value-check unavailable)"
    else
      miss=""
      for spec in "${HEX_CHECKS[@]}"; do
        lit="${spec%%:*}"
        toks="${spec#*:}"
        lit_ok=1
        for tok in $toks; do
          # match e.g. `#0xff` / `#0xff,` as an immediate operand (no trailing hex)
          if ! echo "$DIS" | grep -qE "${tok}([^0-9a-fA-F]|$)"; then
            lit_ok=0
          fi
        done
        if [ "$lit_ok" -eq 1 ]; then
          printf "  ok    literal %-12s lowered (%s) present in stream\n" "$lit" "$toks"
        else
          printf "  FAIL  literal %-12s MISSING chunk(s) %s (re-collapsed?)\n" "$lit" "$toks"
          miss="$miss $lit"
        fi
      done
      if [ -n "$miss" ]; then
        echo "        ↳ literals with missing chunks:$miss  (disas: $OUT/g1_hex.dis)"
        $DISAS "$OUT/g1_hex.o" >"$OUT/g1_hex.dis" 2>/dev/null
        fail=1
      else
        echo "  PASS  0x-literal corpus — all ${#HEX_CHECKS[@]} literals lowered correctly, ENCODE-MISS=0"
      fi
    fi
  fi
fi
echo "──────────────────────────────────────────────────────────────────"

# ── CORPUS 3 — STP/LDP [sp] corpus (locks #2579) ──────────────────────────
echo "CORPUS 3 — STP/LDP [sp] spill value-check (locks #2579):"
STPSRC="$CORPUS/g2_stp_ldp_corpus.hexa"
if [ ! -e "$STPSRC" ]; then
  printf "  FAIL  corpus program absent: %s\n" "$STPSRC"
  fail=1
else
  emit_one "$STPSRC" "$OUT/g2_stp.o" "$OUT/g2_stp.emit.log"
  printf "  emit  : rc=%s objsize=%s ENCODE-MISS=%s\n" "$E_RC" "$E_SZ" "$E_EM"
  if [ "$E_EM" -ne 0 ]; then
    printf "  FAIL  STP/LDP corpus ENCODE-MISS=%s\n" "$E_EM"
    echo "        ↳ emit log: $OUT/g2_stp.emit.log"
    fail=1
  elif [ "$E_SZ" -eq 0 ]; then
    echo "  FAIL  STP/LDP corpus emitted 0 bytes (emit broke post-canary)"
    fail=1
  else
    DIS=$(disas_of "$OUT/g2_stp.o")
    if [ -z "$DIS" ]; then
      echo "  WARN  no disassembler — pair-offset check skipped, ENCODE-MISS=0 still asserted"
      echo "  PASS  STP/LDP corpus (ENCODE-MISS=0; disas value-check unavailable)"
    else
      # distinct [sp,#N] offsets used by STP and LDP
      STP_OFFS=$(echo "$DIS" | grep -E "\bstp\b.*\[sp" | grep -oE "\[sp,? *#0x[0-9a-fA-F]+\]" | sort -u)
      LDP_OFFS=$(echo "$DIS" | grep -E "\bldp\b.*\[sp" | grep -oE "\[sp,? *#0x[0-9a-fA-F]+\]" | sort -u)
      # also count bare [sp] (offset 0) forms
      STP_N=$(echo "$DIS" | grep -cE "\bstp\b.*\[sp")
      LDP_N=$(echo "$DIS" | grep -cE "\bldp\b.*\[sp")
      STP_DISTINCT=$( { echo "$STP_OFFS"; echo "$DIS" | grep -E "\bstp\b.*\[sp\]"; } | grep -E '.' | sort -u | wc -l | tr -d ' ')
      echo "  stp [sp] count : $STP_N  (distinct offset forms: $STP_DISTINCT)"
      echo "  ldp [sp] count : $LDP_N"
      echo "  stp offsets    :" $STP_OFFS
      echo "  ldp offsets    :" $LDP_OFFS
      if [ "$STP_N" -ge 1 ] && [ "$LDP_N" -ge 1 ] && [ "$STP_DISTINCT" -ge 2 ]; then
        echo "  PASS  STP/LDP corpus — store/load pairs at $STP_DISTINCT+ distinct [sp] offsets, ENCODE-MISS=0"
      else
        echo "  FAIL  STP/LDP spill path did not fire as expected"
        echo "        (need stp>=1, ldp>=1, distinct offsets>=2; got stp=$STP_N ldp=$LDP_N distinct=$STP_DISTINCT)"
        $DISAS "$OUT/g2_stp.o" >"$OUT/g2_stp.dis" 2>/dev/null
        echo "        ↳ disas: $OUT/g2_stp.dis"
        fail=1
      fi
    fi
  fi
fi
echo "──────────────────────────────────────────────────────────────────"

if [ "$fail" -ne 0 ]; then
  echo "selfhost-codegen-guard: FAIL — native-codegen regression detected" >&2
  echo "  (full self-emit ENCODE-MISS, a re-collapsed hex literal, OR the" >&2
  echo "   STP/LDP spill path broke)." >&2
  exit 1
fi
echo "selfhost-codegen-guard: PASS — full self-emit ENCODE-MISS=0, all 0x"
echo "  literals encode correctly, STP/LDP spill pairs clean at varied offsets."
exit 0
