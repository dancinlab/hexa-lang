#!/usr/bin/env bash
# self/test/miscompile_class/run.sh — PRIMITIVE-level miscompile-class regression
# runner. STANDALONE — does NOT touch the CI gate scripts
# (tool/miscompile_zero_gate.sh / tool/determinism_gate.sh).
#
# For each targeted test in this dir it:
#   (1) native --emit=obj with the graduated self-hosted compiler,
#   (2) asserts the emit is CLEAN: 0 ENCODE-MISS and 0 spurious `udf` in the
#       disassembled object  (the historical miscompile signature — a cheap
#       byte/asm-level oracle on the emitted primitive),
#   (3) links the object with clang against the hexa runtime (self/runtime.c),
#   (4) RUNS it and asserts a REAL exit code of 0 (each test is a behavioral
#       assert; a wrong runtime value exits with a class-specific code).
# ANY dirty emit OR non-zero run exit -> the runner prints FAIL and exits 1.
# Real exit codes throughout — NO pipe-mask.
#
# This is the PRIMITIVE-level companion to the program-level corpus
# self/test/miscompile_zero/ (gated by tool/miscompile_zero_gate.sh). Where that
# gate proves whole programs emit clean, this runner additionally RUNS each
# class's isolated primitive and checks the runtime VALUE.
#
# CONFIG (env, defaults target the proven ghost host gen2_fix)
#   HEXA_NATIVE_CC   graduated native compiler (default: ~/dancinlab/selfhost-work/gen2_fix)
#   HEXA_CC_PREARGS  prearg slot before the emit flags (default: _drv.hexa)
#   HEXA_RUNTIME     runtime C source to link (default: <repo>/self/runtime.c)
#   HEXA_LIBSODIUM   -L dir for libsodium (default: /opt/homebrew/lib)
#   HEXA_TARGET      target triple (default: arm64-apple-darwin)
#   HEXA_ATLAS_EMBED hermetic empty-atlas dir (default: a scratch dir)
#   MCC_OUT          object/exe/log output dir (default: scratch under selfhost-work)
#
# EXIT  0 = every class test emits clean AND runs rc=0 (floor held)
#       1 = a class REGRESSED (dirty emit or wrong runtime value) — real finding
#       2 = SETUP/INFRA (no native compiler / cannot emit the canary at all)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORPUS="$SCRIPT_DIR"

# ── locate the graduated native compiler ──────────────────────────────────
if [ -n "${HEXA_NATIVE_CC:-}" ]; then
  CC="$HEXA_NATIVE_CC"
elif [ -x "$HOME/dancinlab/selfhost-work/gen2_fix" ]; then
  CC="$HOME/dancinlab/selfhost-work/gen2_fix"
else
  echo "miscompile-class: SETUP — no graduated native compiler." >&2
  echo "  set HEXA_NATIVE_CC=<path to gen2_fix>" >&2
  exit 2
fi

if [ -z "${HEXA_CC_PREARGS+set}" ]; then PREARGS=("_drv.hexa")
else PREARGS=(${HEXA_CC_PREARGS}); fi

RUNTIME="${HEXA_RUNTIME:-$REPO/self/runtime.c}"
LIBSODIUM="${HEXA_LIBSODIUM:-/opt/homebrew/lib}"
TARGET="${HEXA_TARGET:-arm64-apple-darwin}"
OUT="${MCC_OUT:-$HOME/dancinlab/selfhost-work/miscompile-class/out}"
mkdir -p "$OUT"

if [ -z "${HEXA_ATLAS_EMBED:-}" ]; then
  HEXA_ATLAS_EMBED="$OUT/noatlas"; mkdir -p "$HEXA_ATLAS_EMBED"
fi
export HEXA_ATLAS_EMBED

if command -v otool >/dev/null 2>&1; then DISASM="otool -tv"
elif command -v objdump >/dev/null 2>&1; then DISASM="objdump -d"
else echo "miscompile-class: SETUP — no disassembler" >&2; exit 2; fi

echo "── miscompile-class runner ───────────────────────────────────────"
echo "  compiler : $CC ${PREARGS[*]}"
echo "  runtime  : $RUNTIME"
echo "  target   : $TARGET"
echo "  corpus   : $CORPUS"
echo "  out      : $OUT"
echo "──────────────────────────────────────────────────────────────────"

fail=0
n=0
pass=0
for src in "$CORPUS"/m*.hexa; do
  [ -e "$src" ] || continue
  n=$((n + 1))
  b="$(basename "$src" .hexa)"
  obj="$OUT/$b.o"; exe="$OUT/$b"; elog="$OUT/$b.emit.log"; llog="$OUT/$b.link.log"
  rm -f "$obj" "$exe"

  # (1) emit
  "$CC" "${PREARGS[@]}" --emit=obj --target="$TARGET" --ignore-errors \
        -o "$obj" "$src" >"$elog" 2>&1
  erc=$?
  em=$(grep -c "ENCODE-MISS" "$elog" 2>/dev/null); em=${em:-0}
  if [ -s "$obj" ]; then sz=$(wc -c < "$obj" | tr -d ' '); else sz=0; fi

  if [ "$sz" -eq 0 ]; then
    if [ "$em" -eq 0 ]; then
      echo "  SETUP $b — 0-byte emit, no ENCODE-MISS (infra, not a regression)"
      echo "        ↳ $elog"; continue
    fi
    echo "  FAIL  $b — ENCODE-MISS=$em, no object"; fail=1; echo "        ↳ $elog"; continue
  fi

  # (2) asm/byte oracle: 0 ENCODE-MISS, 0 spurious udf
  udf=$($DISASM "$obj" 2>/dev/null | grep -ci '\budf\b'); udf=${udf:-0}
  if [ "$em" -ne 0 ] || [ "$udf" -ne 0 ]; then
    echo "  FAIL  $b — dirty emit (ENCODE-MISS=$em udf=$udf)"; fail=1
    echo "        ↳ $elog"; continue
  fi

  # (3) link
  clang -O2 -o "$exe" "$obj" "$RUNTIME" -L"$LIBSODIUM" -lsodium >"$llog" 2>&1
  lrc=$?
  if [ "$lrc" -ne 0 ] || [ ! -x "$exe" ]; then
    echo "  FAIL  $b — link failed (rc=$lrc)"; fail=1; echo "        ↳ $llog"; continue
  fi

  # (4) run + real exit code
  "$exe" >"$OUT/$b.run.out" 2>&1
  rrc=$?
  if [ "$rrc" -ne 0 ]; then
    echo "  FAIL  $b — RUN rc=$rrc (wrong runtime value -> CLASS REGRESSED)"; fail=1
    echo "        ↳ $OUT/$b.run.out"; continue
  fi

  printf "  PASS  %-26s emit-clean (sz=%s em=0 udf=0) · run rc=0\n" "$b" "$sz"
  pass=$((pass + 1))
done

echo "──────────────────────────────────────────────────────────────────"
if [ "$n" -eq 0 ]; then echo "miscompile-class: SETUP — empty corpus" >&2; exit 2; fi
if [ "$fail" -ne 0 ]; then
  echo "miscompile-class: FAIL — a miscompile CLASS regressed ($pass/$n passed)" >&2
  exit 1
fi
echo "miscompile-class: PASS — $pass/$n class tests emit clean AND run rc=0"
exit 0
