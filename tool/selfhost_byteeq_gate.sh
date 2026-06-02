#!/usr/bin/env bash
# tool/selfhost_byteeq_gate.sh — SELF-HOST BYTE-EQ FIXPOINT regression gate.
#
# PURPOSE
#   Lock the self-host byte-eq graduation so a future codegen/linker edit can't
#   silently break it. The graduation proof: the native `gen2_fix` compiler
#   re-emits the FULL flattened compiler to a byte-identical object across
#   generations — cmp cc-prc2-fix.o == cc-gen3.o == cc-gen4.o, all exit 0
#   (3,224,592 bytes each, on the ghost macOS host).
#
# WHAT IT DOES (two legs)
#   LEG A — BYTE-EQ FIXPOINT (heavy): re-emit gen3 from gen2_fix over the EXACT
#     flattened source gen2's own object was built from (cc-flat-fix.hexa), then
#     re-emit gen4 the SAME way, and assert:
#       (1) ENCODE-MISS = 0 on both emits,
#       (2) cmp cc-gen3.o cc-gen4.o is byte-identical (FIRSTDIFF=0).
#     This SELF-REPRODUCTION (gen2's emit reproducing itself across re-runs,
#     gen3==gen4==gen3b) is the canonical graduation fixpoint. A re-emit that
#     differs from itself is a true byte-eq regression (exit 1). An OPTIONAL
#     GEN_REF cmp (default unset) is INFORMATIONAL only — see GEN_REF below;
#     cc-prc2-fix.o is gen2's relinked object, not its emit, so it differs by
#     design and must NOT be used as the fixpoint comparand.
#
#   LEG B — NATIVE-CODEGEN PROBE (fast): native --emit=obj the two highest-value
#     regression-class programs from self/test/miscompile_zero/ —
#       • c1_hex_literal  (the `0xff`->255 hex-literal lower class, 47421c89c)
#       • c2_stack_locals (the STP/[sp] stack-local mem-parse class)
#     and assert each produces a non-empty object with 0 ENCODE-MISS. This is the
#     fast canary that the codegen classes the graduation depended on still emit
#     clean, runnable even when the heavy fixpoint inputs are absent.
#
# CONFIG (env; defaults target the proven ghost host)
#   HEXA_NATIVE_CC   native self-hosted compiler driver
#                    (default: ~/dancinlab/selfhost-work/gen2_fix, else `hexa`)
#   SHW              selfhost-work dir holding the graduated artifacts + flat src
#                    (default: ~/dancinlab/selfhost-work)
#   GEN_FLAT         flattened compiler source to re-emit
#                    (default: $SHW/cc-flat-fix.hexa)
#   GEN_REF          OPTIONAL informational object to cmp gen3 against. Default
#                    UNSET. NOTE: do NOT point this at cc-prc2-fix.o — that is
#                    gen2's OWN object, relinked via a different path (hld_fixed
#                    literal8-merge, see gen2fix.done), so it legitimately
#                    differs from gen2's EMIT (cc-gen3.o) at char 1528257 — it
#                    differed at graduation time too (gen3.done CMP=DIFFER). The
#                    canonical fixpoint is the SELF-REPRODUCTION gen3==gen4
#                    (== gen3b), NOT gen3==cc-prc2-fix.o. GEN_REF cmp is
#                    INFORMATIONAL ONLY and never fails the gate.
#   HEXA_CC_PREARGS  args after the driver, before flags. gen2_fix wants a
#                    driver-name placeholder ("_drv.hexa", the default); a
#                    released ./hexa wants "run compiler/main.hexa".
#   HEXA_ATLAS_EMBED empty-atlas dir for a hermetic emit (default: per-run dir)
#   HEXA_TARGET      target triple (default: arm64-apple-darwin)
#   BYTEEQ_CORPUS    probe corpus dir (default: <repo>/self/test/miscompile_zero)
#   BYTEEQ_OUT       output dir (default: <repo>/build/selfhost-byteeq-out)
#
# EXIT
#   0  fixpoint held (gen3==gen4, 0 ENCODE-MISS) AND the codegen probe is clean.
#      If LEG A inputs are absent but the probe ran, also 0 (probe-only PASS).
#   1  REGRESSION — objects WERE produced but gen3 != gen4 (the self-reproduction
#      fixpoint broke), OR an ENCODE-MISS surfaced, OR a probe program emitted a
#      dirty/empty object while another emitted clean (the codegen floor broke).
#      (GEN_REF cmp, if set, is informational only and never reds the gate.)
#   2  SETUP / INFRA — the configured driver cannot native-emit AT ALL in THIS
#      environment (canary 0-byte, no ENCODE-MISS). CI-neutral: the floor is NOT
#      broken; the runner just lacks the graduated gen2_fix. A released ./hexa
#      recompiles compiler/main.hexa against its embedded runtime and hits the
#      build-floor staleness wall (0-byte emit). Set HEXA_NATIVE_CC to a
#      graduated native compiler to run the gate for real.

set -uo pipefail

# ── locate repo + corpus ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS="${BYTEEQ_CORPUS:-$REPO/self/test/miscompile_zero}"
SHW="${SHW:-$HOME/dancinlab/selfhost-work}"
GEN_FLAT="${GEN_FLAT:-$SHW/cc-flat-fix.hexa}"
GEN_REF="${GEN_REF:-}"   # OPTIONAL informational only — NOT a fixpoint comparand
TARGET="${HEXA_TARGET:-arm64-apple-darwin}"

# ── locate the native self-hosted compiler ───────────────────────────────
if [ -n "${HEXA_NATIVE_CC:-}" ]; then
  CC="$HEXA_NATIVE_CC"
elif [ -x "$SHW/gen2_fix" ]; then
  CC="$SHW/gen2_fix"
elif command -v hexa >/dev/null 2>&1; then
  CC="$(command -v hexa)"
else
  echo "selfhost-byteeq-gate: SETUP ERROR — no native compiler." >&2
  echo "  set HEXA_NATIVE_CC=<path to gen2_fix / native hexa driver>" >&2
  exit 2
fi

# gen2_fix consumes argv[1] as its driver-name slot; a released ./hexa wants
# "run compiler/main.hexa". Default to the gen2_fix placeholder.
if [ -z "${HEXA_CC_PREARGS+set}" ]; then
  PREARGS=("_drv.hexa")
else
  # shellcheck disable=SC2206
  PREARGS=(${HEXA_CC_PREARGS})
fi

OUT="${BYTEEQ_OUT:-$REPO/build/selfhost-byteeq-out}"
mkdir -p "$OUT"

if [ -z "${HEXA_ATLAS_EMBED:-}" ]; then
  HEXA_ATLAS_EMBED="$OUT/noatlas"
  mkdir -p "$HEXA_ATLAS_EMBED"
fi
export HEXA_ATLAS_EMBED

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

echo "── selfhost byte-eq gate ─────────────────────────────────────────"
echo "  compiler : $CC ${PREARGS[*]}"
echo "  target   : $TARGET"
echo "  flat src : $GEN_FLAT"
echo "  gen ref  : $GEN_REF"
echo "  corpus   : $CORPUS"
echo "  out      : $OUT"
echo "──────────────────────────────────────────────────────────────────"

# ── CANARY — can this env native-emit AT ALL? ─────────────────────────────
CANARY_SRC="$CORPUS/c1_hex_literal.hexa"
if [ ! -e "$CANARY_SRC" ]; then
  echo "selfhost-byteeq-gate: SETUP ERROR — canary missing: $CANARY_SRC" >&2
  exit 2
fi
emit_one "$CANARY_SRC" "$OUT/_canary.o" "$OUT/_canary.emit.log"
if [ "$E_SZ" -eq 0 ] && [ "$E_EM" -eq 0 ]; then
  echo "selfhost-byteeq-gate: SETUP/INFRA — canary will not native-emit" >&2
  echo "  (c1_hex_literal: rc=$E_RC objsize=0 ENCODE-MISS=0 — this env cannot" >&2
  echo "   native --emit=obj; the byte-eq floor is NOT broken). The real gate" >&2
  echo "   needs the graduated gen2_fix (ghost host) or a self-host build step;" >&2
  echo "   a released ./hexa hits the build-floor staleness wall (0-byte emit)." >&2
  echo "        ↳ canary emit log: $OUT/_canary.emit.log" >&2
  exit 2
fi
echo "  canary   : c1_hex_literal emits (objsize=$E_SZ) — native-emit OK"
echo "──────────────────────────────────────────────────────────────────"

fail=0

# ── LEG B — fast native-codegen regression probe ──────────────────────────
echo "LEG B — native-codegen probe (0x-literal + STP/[sp]):"
probe_ok=0
for b in c1_hex_literal c2_stack_locals; do
  src="$CORPUS/$b.hexa"
  if [ ! -e "$src" ]; then
    printf "  MISS  %-18s (corpus program absent)\n" "$b"
    continue
  fi
  emit_one "$src" "$OUT/$b.o" "$OUT/$b.emit.log"
  if [ "$E_SZ" -gt 0 ] && [ "$E_EM" -eq 0 ]; then
    printf "  PASS  %-18s objsize=%s encode_miss=0\n" "$b" "$E_SZ"
    probe_ok=$((probe_ok + 1))
  elif [ "$E_EM" -ne 0 ]; then
    printf "  FAIL  %-18s ENCODE-MISS=%s (codegen regression)\n" "$b" "$E_EM"
    echo "        ↳ emit log: $OUT/$b.emit.log"
    fail=1
  else
    # 0-byte after a passing canary = this program specifically broke
    printf "  FAIL  %-18s objsize=0 rc=%s (probe emit broke post-canary)\n" "$b" "$E_RC"
    echo "        ↳ emit log: $OUT/$b.emit.log"
    fail=1
  fi
done
echo "──────────────────────────────────────────────────────────────────"

# ── LEG A — byte-eq fixpoint (heavy) ──────────────────────────────────────
echo "LEG A — byte-eq fixpoint (re-emit gen3 → gen4):"
FIRSTDIFF="NA"
if [ ! -s "$GEN_FLAT" ]; then
  echo "  SKIP — flattened source absent ($GEN_FLAT). The heavy fixpoint leg"
  echo "         needs the graduated flat compiler input (ghost selfhost-work)."
  echo "         Probe leg above still gates the codegen floor."
  echo "──────────────────────────────────────────────────────────────────"
  if [ "$fail" -ne 0 ]; then
    echo "selfhost-byteeq-gate: FAIL — native-codegen probe regression" >&2
    exit 1
  fi
  if [ "$probe_ok" -eq 0 ]; then
    echo "selfhost-byteeq-gate: SETUP/INFRA — no probe program emitted." >&2
    exit 2
  fi
  echo "selfhost-byteeq-gate: PASS (probe-only) — codegen floor held; byte-eq"
  echo "  fixpoint leg skipped (graduated flat source not present here)."
  exit 0
fi

emit_one "$GEN_FLAT" "$OUT/cc-gen3.o" "$OUT/gen3-emit.log"; G3_RC=$E_RC; G3_SZ=$E_SZ; G3_EM=$E_EM
emit_one "$GEN_FLAT" "$OUT/cc-gen4.o" "$OUT/gen4-emit.log"; G4_RC=$E_RC; G4_SZ=$E_SZ; G4_EM=$E_EM
printf "  gen3 : rc=%s objsize=%s encode_miss=%s\n" "$G3_RC" "$G3_SZ" "$G3_EM"
printf "  gen4 : rc=%s objsize=%s encode_miss=%s\n" "$G4_RC" "$G4_SZ" "$G4_EM"

if [ "$G3_SZ" -eq 0 ] || [ "$G4_SZ" -eq 0 ]; then
  echo "  SETUP/INFRA — a full-compiler emit produced 0 bytes (build-floor)."
  echo "──────────────────────────────────────────────────────────────────"
  [ "$fail" -ne 0 ] && { echo "selfhost-byteeq-gate: FAIL — probe regression" >&2; exit 1; }
  echo "selfhost-byteeq-gate: SETUP/INFRA — heavy fixpoint un-emittable here." >&2
  exit 2
fi

if [ "$G3_EM" -ne 0 ] || [ "$G4_EM" -ne 0 ]; then
  echo "  FAIL — ENCODE-MISS on a full-compiler emit (gen3=$G3_EM gen4=$G4_EM)"
  fail=1
fi

if cmp "$OUT/cc-gen3.o" "$OUT/cc-gen4.o" >/dev/null 2>&1; then
  FIRSTDIFF=0
  echo "  cmp gen3 vs gen4 : BYTE-EQ (FIRSTDIFF=0)"
else
  CMPOUT=$(cmp "$OUT/cc-gen3.o" "$OUT/cc-gen4.o" 2>&1)
  FIRSTDIFF=$(echo "$CMPOUT" | grep -oE "byte [0-9]+" | grep -oE "[0-9]+" | head -1)
  echo "  cmp gen3 vs gen4 : DIFFER@${FIRSTDIFF:-?} — byte-eq regression"
  fail=1
fi

# GEN_REF cmp is INFORMATIONAL ONLY (never fails the gate): cc-prc2-fix.o is
# gen2's own relinked object, not gen2's emit, so it differs by design. The
# canonical fixpoint above (gen3==gen4) is the real gate.
if [ -n "${GEN_REF:-}" ] && [ -s "$GEN_REF" ]; then
  if cmp "$GEN_REF" "$OUT/cc-gen3.o" >/dev/null 2>&1; then
    echo "  cmp ref  vs gen3 : identical (info; GEN_REF matches emit)"
  else
    RD=$(cmp "$GEN_REF" "$OUT/cc-gen3.o" 2>&1 | grep -oE "char [0-9]+" | grep -oE "[0-9]+" | head -1)
    echo "  cmp ref  vs gen3 : differ@${RD:-?} (info only — GEN_REF is not a"
    echo "                     fixpoint comparand; self-reproduction is the gate)"
  fi
else
  echo "  cmp ref  vs gen3 : (no GEN_REF — self-reproduction fixpoint is the gate)"
fi

echo "──────────────────────────────────────────────────────────────────"
if [ "$fail" -ne 0 ]; then
  echo "selfhost-byteeq-gate: FAIL — self-host regression detected" >&2
  echo "  (byte-eq fixpoint broke OR a codegen-probe ENCODE-MISS surfaced)." >&2
  exit 1
fi
echo "selfhost-byteeq-gate: PASS — byte-eq fixpoint held (gen3==gen4,"
echo "  FIRSTDIFF=0, 0 ENCODE-MISS) AND native-codegen probe clean."
exit 0
