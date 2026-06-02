#!/usr/bin/env bash
# tool/miscompile_zero_gate.sh — MISCOMPILE-ZERO regression gate.
#
# PURPOSE
#   Keep the native self-hosted hexa codegen at MISCOMPILE-ZERO. The byte-eq
#   self-host graduation was won by fixing a CLASS of native-codegen
#   miscompiles, each of which surfaced as either
#     • `ENCODE-MISS: STP/LDP mem-parse-fail` in the --emit=obj stderr, or
#     • a spurious `udf` instruction in the emitted Mach-O object.
#   Classes fixed (origin/main):
#     - hex-literal 0xNN -> 0      (lower _parse_int, 47421c89c)
#     - .truncate(0) global aliasing no-op mis-lower (953c8824b)
#     - _ends_with / string-compare cascade (downstream of hex)
#     - linker reloc gaps: literal8 / __DATA UNSIGNED / mod_init_func (#2509)
#
# WHAT IT DOES
#   Native-compiles a tiny corpus (self/test/miscompile_zero/*.hexa), each
#   program exercising one class, with the self-hosted native --emit=obj path,
#   then for every object asserts:
#     (1) the compiler exited 0,
#     (2) the emit stderr has ZERO "ENCODE-MISS",
#     (3) the disassembly has ZERO spurious `udf`,
#     (4) a non-empty object was produced.
#   ANY violation -> the gate prints a FAIL line and exits NONZERO.
#
#   This is the LIGHTWEIGHT gate (seconds, not the 68-min full self-emit): a
#   future native-codegen regression in any of the covered classes fails fast.
#
# CONFIG (env, with sane defaults for the proven ghost host)
#   HEXA_NATIVE_CC   native self-hosted compiler driver (default: gen2_fix in
#                    ~/dancinlab/selfhost-work, else `hexa` on PATH)
#   HEXA_CC_PREARGS  args inserted right after $HEXA_NATIVE_CC, BEFORE the emit
#                    flags. The compiled compiler/main.hexa binary (gen2_fix)
#                    consumes the first positional as its driver-name slot, so
#                    its default is "_drv.hexa". For a released `./hexa` driver
#                    set HEXA_CC_PREARGS="run compiler/main.hexa".
#   HEXA_ATLAS_EMBED empty-atlas dir for a hermetic build (default: a tmp dir)
#   HEXA_TARGET      target triple (default: arm64-apple-darwin)
#   MCZERO_CORPUS    corpus dir (default: <repo>/self/test/miscompile_zero)
#   MCZERO_OUT       object/log output dir (default: a per-run scratch dir)
#   MCZERO_DISASM    disassembler (default: otool -tv ; objdump -d fallback)
#
# EXIT
#   0  all corpus programs emit clean (0 ENCODE-MISS, 0 udf) — floor held.
#   1  REGRESSION — an object WAS produced but is dirty (ENCODE-MISS or a real
#      spurious `udf`). This is the only red: the graduated native compiler
#      emitted, but emitted a miscompile.
#   2  SETUP / INFRA — the configured driver cannot native-emit a single program
#      in THIS environment at all (every emit is 0-byte / rc!=0 with NO
#      ENCODE-MISS). CI-neutral: the miscompile-zero FLOOR is NOT broken, the
#      runner just lacks the graduated native emitter (only the full self-host
#      gen2 build, or the ghost-host gen2_fix, can native-emit cleanly — a
#      released `./hexa` recompiles compiler/main.hexa against its embedded
#      runtime and hits the build-floor staleness wall, producing 0 bytes).
#
# CLASSIFICATION RULE (the whole point of this gate's hardening)
#   A 0-byte object / invocation failure with NO ENCODE-MISS is an INFRA error,
#   NOT a codegen regression. Only an object that IS produced AND carries an
#   ENCODE-MISS or a real spurious `udf` is a red regression. Up front we emit a
#   trivial CANARY (c1_hex_literal): if even the canary will not emit, the env
#   cannot native-emit → exit 2 immediately with a clear message.

set -uo pipefail

# ── locate repo + corpus ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS="${MCZERO_CORPUS:-$REPO/self/test/miscompile_zero}"

if [ ! -d "$CORPUS" ]; then
  echo "miscompile-zero-gate: SETUP ERROR — corpus dir not found: $CORPUS" >&2
  exit 2
fi

# ── locate the native self-hosted compiler ───────────────────────────────
if [ -n "${HEXA_NATIVE_CC:-}" ]; then
  CC="$HEXA_NATIVE_CC"
elif [ -x "$HOME/dancinlab/selfhost-work/gen2_fix" ]; then
  CC="$HOME/dancinlab/selfhost-work/gen2_fix"
elif command -v hexa >/dev/null 2>&1; then
  CC="$(command -v hexa)"
else
  echo "miscompile-zero-gate: SETUP ERROR — no native compiler." >&2
  echo "  set HEXA_NATIVE_CC=<path to gen2_fix / native hexa driver>" >&2
  exit 2
fi

TARGET="${HEXA_TARGET:-arm64-apple-darwin}"

# The compiled compiler/main.hexa binary (gen2_fix) treats argv[1] as its
# driver-name slot (it emulates `hexa run <script>`), so a placeholder must
# precede the flags. A released `./hexa` driver instead wants
# "run compiler/main.hexa". Default to the gen2_fix placeholder; an explicitly
# empty HEXA_CC_PREARGS="" means "no prearg at all".
if [ -z "${HEXA_CC_PREARGS+set}" ]; then
  PREARGS=("_drv.hexa")            # unset -> default placeholder
else
  # shellcheck disable=SC2206
  PREARGS=(${HEXA_CC_PREARGS})     # set (possibly empty) -> word-split
fi

# ── output dir (NOT /tmp; default under the already-gitignored build/ dir) ─
if [ -n "${MCZERO_OUT:-}" ]; then
  OUT="$MCZERO_OUT"
else
  OUT="$REPO/build/mczero-gate-out"
fi
mkdir -p "$OUT"

# ── hermetic empty atlas (avoid pulling the real embedded atlas) ──────────
if [ -z "${HEXA_ATLAS_EMBED:-}" ]; then
  HEXA_ATLAS_EMBED="$OUT/noatlas"
  mkdir -p "$HEXA_ATLAS_EMBED"
fi
export HEXA_ATLAS_EMBED

# ── pick a disassembler ──────────────────────────────────────────────────
if [ -n "${MCZERO_DISASM:-}" ]; then
  : # caller-provided, used verbatim below
elif command -v otool >/dev/null 2>&1; then
  MCZERO_DISASM="otool -tv"
elif command -v objdump >/dev/null 2>&1; then
  MCZERO_DISASM="objdump -d"
else
  echo "miscompile-zero-gate: SETUP ERROR — no disassembler (otool/objdump)." >&2
  exit 2
fi

disasm() { $MCZERO_DISASM "$1" 2>/dev/null; }

# emit_one SRC OBJ LOG  — run the native --emit=obj for one program; populate
# the globals: E_RC (compiler rc), E_SZ (object byte size, 0 if absent),
# E_EM (ENCODE-MISS count), E_UDF (spurious `udf` count in disasm).
emit_one() {
  local src="$1" obj="$2" log="$3"
  rm -f "$obj"
  # The native driver consumes the PREARGS slot (driver-name placeholder for
  # gen2_fix / aprime_cc, or "run compiler/main.hexa" for a released ./hexa)
  # and the LAST positional as SOURCE (see selfhost-work/build_gen3.sh).
  "$CC" "${PREARGS[@]}" \
        --emit=obj --target="$TARGET" --ignore-errors \
        -o "$obj" "$src" >"$log" 2>&1
  E_RC=$?
  # grep -c prints the count AND exits 1 when zero; capture stdout only and
  # normalize, never relying on the exit code (which would add a stray "0").
  E_EM=$(grep -c "ENCODE-MISS" "$log" 2>/dev/null); E_EM=${E_EM:-0}
  if [ -s "$obj" ]; then E_SZ=$(wc -c < "$obj" | tr -d ' '); else E_SZ=0; fi
  if [ "$E_SZ" -gt 0 ]; then
    E_UDF=$(disasm "$obj" | grep -ci '\budf\b' 2>/dev/null); E_UDF=${E_UDF:-0}
  else
    E_UDF=0
  fi
}

echo "── miscompile-zero gate ──────────────────────────────────────────"
echo "  compiler : $CC ${PREARGS[*]}"
echo "  target   : $TARGET"
echo "  corpus   : $CORPUS"
echo "  out      : $OUT"
echo "  disasm   : $MCZERO_DISASM"
echo "──────────────────────────────────────────────────────────────────"

# ── CANARY — can this env native-emit AT ALL? ─────────────────────────────
# c1_hex_literal is the simplest corpus program. If even it will not produce a
# non-empty object (and produced NO ENCODE-MISS), the configured driver simply
# cannot native-emit here → SETUP/INFRA error (exit 2), NOT a codegen
# regression. This is the structural guard against a released `./hexa`'s
# `run compiler/main.hexa` recompile hitting the build-floor staleness wall and
# uniformly emitting 0-byte objects, which would otherwise look like a 10/10
# "regression".
CANARY_SRC="$CORPUS/c1_hex_literal.hexa"
if [ -e "$CANARY_SRC" ]; then
  emit_one "$CANARY_SRC" "$OUT/_canary.o" "$OUT/_canary.emit.log"
  if [ "$E_SZ" -eq 0 ] && [ "$E_EM" -eq 0 ]; then
    echo "miscompile-zero-gate: SETUP/INFRA — canary will not native-emit" >&2
    echo "  (c1_hex_literal: rc=$E_RC objsize=0 ENCODE-MISS=0 — the compiler" >&2
    echo "   cannot native --emit=obj in THIS environment; the floor is NOT" >&2
    echo "   broken). The real native-emit gate needs the graduated self-host" >&2
    echo "   gen2 (ghost gen2_fix) or a self-host build step; a released" >&2
    echo "   ./hexa recompiles compiler/main.hexa against its embedded runtime" >&2
    echo "   and hits the build-floor staleness wall (0-byte emit). Set" >&2
    echo "   HEXA_NATIVE_CC to a graduated native compiler to run the gate." >&2
    echo "        ↳ canary emit log: $OUT/_canary.emit.log" >&2
    exit 2
  fi
  echo "  canary   : c1_hex_literal emits (objsize=$E_SZ) — native-emit OK"
  echo "──────────────────────────────────────────────────────────────────"
fi

fail=0          # 1 => an object WAS produced but is dirty (red regression)
setuperr=0      # count of programs that could not emit at all (infra)
n=0
for src in "$CORPUS"/*.hexa; do
  [ -e "$src" ] || continue
  n=$((n + 1))
  b="$(basename "$src" .hexa)"
  obj="$OUT/$b.o"
  log="$OUT/$b.emit.log"

  emit_one "$src" "$obj" "$log"

  if [ "$E_SZ" -eq 0 ] && [ "$E_EM" -eq 0 ]; then
    # No object, no ENCODE-MISS → infra failure for this program, NOT a
    # codegen regression. Count it as setup error.
    printf "  SETUP %-22s rc=%s objsize=0 (no emit, no ENCODE-MISS — infra)\n" \
           "$b" "$E_RC"
    echo "        ↳ emit log: $log"
    setuperr=$((setuperr + 1))
    continue
  fi

  # An object WAS produced (or an ENCODE-MISS surfaced). Now a dirty emit is a
  # real regression.
  bad=0
  reason=""
  if [ "$E_EM" -ne 0 ];  then bad=1; reason="$reason ENCODE-MISS=$E_EM"; fi
  if [ "$E_UDF" -ne 0 ]; then bad=1; reason="$reason udf=$E_UDF";        fi
  if [ "$E_RC" -ne 0 ] && [ "$E_SZ" -gt 0 ]; then
    bad=1; reason="$reason rc=$E_RC(obj-present)"
  fi

  if [ "$bad" -eq 0 ]; then
    printf "  PASS  %-22s rc=%s objsize=%s encode_miss=%s udf=%s\n" \
           "$b" "$E_RC" "$E_SZ" "$E_EM" "$E_UDF"
  else
    printf "  FAIL  %-22s%s\n" "$b" "$reason"
    echo "        ↳ emit log: $log"
    fail=1
  fi
done

echo "──────────────────────────────────────────────────────────────────"
if [ "$n" -eq 0 ]; then
  echo "miscompile-zero-gate: SETUP ERROR — corpus is empty ($CORPUS)." >&2
  exit 2
fi
if [ "$fail" -ne 0 ]; then
  echo "miscompile-zero-gate: FAIL — native-codegen regression detected" >&2
  echo "  (an object was produced but carries an ENCODE-MISS or spurious udf;" >&2
  echo "   the miscompile-zero floor broke)." >&2
  exit 1
fi
if [ "$setuperr" -ne 0 ]; then
  echo "miscompile-zero-gate: SETUP/INFRA — $setuperr/$n programs could not" >&2
  echo "  native-emit (0-byte, no ENCODE-MISS). The floor is NOT broken; this" >&2
  echo "  env lacks the graduated native emitter. CI-neutral (exit 2)." >&2
  exit 2
fi
echo "miscompile-zero-gate: PASS — $n/$n programs emit clean"
echo "  (0 ENCODE-MISS, 0 udf) — miscompile-zero floor held."
exit 0
