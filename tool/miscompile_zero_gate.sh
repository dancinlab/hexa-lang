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
#   1  one or more regressions detected (details printed).
#   2  setup error (no compiler / no corpus).

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

echo "── miscompile-zero gate ──────────────────────────────────────────"
echo "  compiler : $CC"
echo "  target   : $TARGET"
echo "  corpus   : $CORPUS"
echo "  out      : $OUT"
echo "  disasm   : $MCZERO_DISASM"
echo "──────────────────────────────────────────────────────────────────"

fail=0
n=0
for src in "$CORPUS"/*.hexa; do
  [ -e "$src" ] || continue
  n=$((n + 1))
  b="$(basename "$src" .hexa)"
  obj="$OUT/$b.o"
  log="$OUT/$b.emit.log"
  rm -f "$obj"

  # The native driver consumes the PREARGS slot (driver-name placeholder for
  # gen2_fix, or "run compiler/main.hexa" for a released ./hexa) and the LAST
  # positional as SOURCE (see selfhost-work/build_gen3.sh).
  "$CC" "${PREARGS[@]}" \
        --emit=obj --target="$TARGET" --ignore-errors \
        -o "$obj" "$src" >"$log" 2>&1
  rc=$?

  # grep -c prints the count AND exits 1 when zero; capture stdout only and
  # normalize, never relying on the exit code (which would add a stray "0").
  em=$(grep -c "ENCODE-MISS" "$log" 2>/dev/null); em=${em:-0}
  if [ -s "$obj" ]; then
    sz=$(wc -c < "$obj" | tr -d ' ')
  else
    sz=0
  fi
  udf=$(disasm "$obj" | grep -ci '\budf\b' 2>/dev/null); udf=${udf:-0}

  bad=0
  reason=""
  if [ "$rc" -ne 0 ];   then bad=1; reason="$reason rc=$rc";          fi
  if [ "$em" -ne 0 ];   then bad=1; reason="$reason ENCODE-MISS=$em"; fi
  if [ "$sz" -eq 0 ];   then bad=1; reason="$reason objsize=0";       fi
  if [ "$udf" -ne 0 ];  then bad=1; reason="$reason udf=$udf";        fi

  if [ "$bad" -eq 0 ]; then
    printf "  PASS  %-22s rc=%s objsize=%s encode_miss=%s udf=%s\n" \
           "$b" "$rc" "$sz" "$em" "$udf"
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
  echo "  (an ENCODE-MISS or spurious udf returned; the floor broke)." >&2
  exit 1
fi
echo "miscompile-zero-gate: PASS — $n/$n programs emit clean"
echo "  (0 ENCODE-MISS, 0 udf) — miscompile-zero floor held."
exit 0
