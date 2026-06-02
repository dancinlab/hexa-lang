#!/usr/bin/env bash
# tool/determinism_gate.sh — MISCOMPILE-ZERO linker/compiler DETERMINISM gate.
#
# PURPOSE
#   Lock that the native hexa toolchain (native --emit=obj + the hexa_ld linker)
#   is BYTE-DETERMINISTic for fixed input, gated so nondeterminism can't regress.
#   Sister of tool/miscompile_zero_gate.sh: that gate proves emit is *clean*
#   (0 ENCODE-MISS / 0 udf); THIS gate proves emit + link are *reproducible*
#   (the same input bytes produce the same output bytes, twice).
#
# WHY
#   The byte-eq self-host graduation showed strong determinism (gen3 == gen3b;
#   stage3 == stage4). An OLD note flagged possible LINKER nondeterminism on a
#   compiler relink (gen2 != gen2b @byte ~1924664, a symtab/strtab tail). This
#   gate verifies that is resolved AND fails fast if any future change
#   reintroduces a wall-clock / random-UUID / unstable-sort / uninit-pad source.
#
#   Determinism caveat (NOT nondeterminism): both the per-module label hash
#   `__L<sha4>_` (= sha256(module path), path-derived) and the linker's
#   ad-hoc-codesign build-id string `<out-basename>-UUID...` are PURE FUNCTIONS
#   of fixed input (module path / output path). They are deterministic for a
#   fixed input. So the link half of this gate links each object twice with the
#   SAME output basename (in two separate dirs) — isolating the path-derived
#   build-id, so a TRUE nondeterminism (timestamp / random UUID / unstable sort)
#   is the only thing that can make the two outputs differ.
#
# WHAT IT DOES
#   Over a tiny corpus (self/test/miscompile_zero/*.hexa):
#     PHASE 1 — RE-EMIT: native --emit=obj each program TWICE; assert the two
#               objects are byte-identical (cmp).
#     PHASE 2 — RELINK : link each (first) object TWICE with hexa_ld, same
#               output basename in two dirs; assert the two executables are
#               byte-identical (cmp).
#   ANY byte diff (or nonzero compile/link rc) -> FAIL line + exit NONZERO.
#
# CONFIG (env, sane defaults for the proven ghost host)
#   HEXA_NATIVE_CC   native self-hosted compiler driver (default: gen2_fix in
#                    ~/dancinlab/selfhost-work, else `hexa` on PATH)
#   HEXA_CC_PREARGS  args after $HEXA_NATIVE_CC, before the emit flags. gen2_fix
#                    wants a driver-name placeholder ("_drv.hexa", the default);
#                    a released ./hexa driver wants "run compiler/main.hexa".
#   HEXA_LD          linker invocation. Either an executable (e.g. the built
#                    `hld_fixed`) OR a multi-word driver form that runs the
#                    hexa_ld source (e.g. "./hexa run tool/hexa_ld.hexa").
#                    Default: $HOME/dancinlab/selfhost-work/hld_fixed, else
#                    "<CC> <PREARGS> run tool/hexa_ld.hexa" is NOT assumed —
#                    if no hld_fixed and HEXA_LD unset, PHASE 2 is SKIPPED with
#                    a loud notice (emit determinism still gated).
#   HEXA_LD_MAIN     entry symbol for --lc-main (default: unset; corpus mains
#                    link via the default _main path).
#   HEXA_ATLAS_EMBED empty-atlas dir for a hermetic build (default: per-run dir)
#   HEXA_TARGET      target triple (default: arm64-apple-darwin)
#   DETERM_CORPUS    corpus dir (default: <repo>/self/test/miscompile_zero)
#   DETERM_OUT       output dir (default: <repo>/build/determinism-gate-out)
#
# EXIT
#   0  every program emits byte-identically twice AND links byte-identically
#      twice — determinism floor held.
#   1  one or more byte diffs (or compile/link failures) — determinism broke.
#   2  setup error (no compiler / no corpus).

set -uo pipefail

# ── locate repo + corpus ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS="${DETERM_CORPUS:-$REPO/self/test/miscompile_zero}"

if [ ! -d "$CORPUS" ]; then
  echo "determinism-gate: SETUP ERROR — corpus dir not found: $CORPUS" >&2
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
  echo "determinism-gate: SETUP ERROR — no native compiler." >&2
  echo "  set HEXA_NATIVE_CC=<path to gen2_fix / native hexa driver>" >&2
  exit 2
fi

TARGET="${HEXA_TARGET:-arm64-apple-darwin}"

# Driver-name placeholder slot (see tool/miscompile_zero_gate.sh for rationale).
if [ -z "${HEXA_CC_PREARGS+set}" ]; then
  PREARGS=("_drv.hexa")            # unset -> default placeholder (gen2_fix)
else
  # shellcheck disable=SC2206
  PREARGS=(${HEXA_CC_PREARGS})     # set (possibly empty) -> word-split
fi

# ── locate the linker (optional; PHASE 2 skipped if absent) ──────────────
LD_WORDS=()
LD_MODE="none"
if [ -n "${HEXA_LD:-}" ]; then
  # shellcheck disable=SC2206
  LD_WORDS=(${HEXA_LD})
  LD_MODE="env"
elif [ -x "$HOME/dancinlab/selfhost-work/hld_fixed" ]; then
  LD_WORDS=("$HOME/dancinlab/selfhost-work/hld_fixed")
  LD_MODE="hld_fixed"
fi

# ── output dir (NOT /tmp; under the already-gitignored build/ dir) ────────
OUT="${DETERM_OUT:-$REPO/build/determinism-gate-out}"
mkdir -p "$OUT/emit" "$OUT/relink"

# ── hermetic empty atlas ─────────────────────────────────────────────────
if [ -z "${HEXA_ATLAS_EMBED:-}" ]; then
  HEXA_ATLAS_EMBED="$OUT/noatlas"
  mkdir -p "$HEXA_ATLAS_EMBED"
fi
export HEXA_ATLAS_EMBED

echo "── determinism gate ──────────────────────────────────────────────"
echo "  compiler : $CC ${PREARGS[*]}"
if [ "$LD_MODE" = "none" ]; then
  echo "  linker   : (none — set HEXA_LD or build hld_fixed; PHASE 2 SKIPPED)"
else
  echo "  linker   : ${LD_WORDS[*]}  [$LD_MODE]"
fi
echo "  target   : $TARGET"
echo "  corpus   : $CORPUS"
echo "  out      : $OUT"
echo "──────────────────────────────────────────────────────────────────"

sha() { shasum -a256 "$1" 2>/dev/null | cut -d' ' -f1; }

fail=0
n=0

# ── PHASE 1 — RE-EMIT determinism ────────────────────────────────────────
echo "== PHASE 1 — re-emit (native --emit=obj twice, byte-identical) =="
for src in "$CORPUS"/*.hexa; do
  [ -e "$src" ] || continue
  n=$((n + 1))
  b="$(basename "$src" .hexa)"
  oA="$OUT/emit/$b.A.o"; oB="$OUT/emit/$b.B.o"
  lA="$OUT/emit/$b.A.log"; lB="$OUT/emit/$b.B.log"
  rm -f "$oA" "$oB"

  "$CC" "${PREARGS[@]}" --emit=obj --target="$TARGET" --ignore-errors \
        -o "$oA" "$src" >"$lA" 2>&1; rcA=$?
  "$CC" "${PREARGS[@]}" --emit=obj --target="$TARGET" --ignore-errors \
        -o "$oB" "$src" >"$lB" 2>&1; rcB=$?

  sz=0; [ -s "$oA" ] && sz=$(wc -c < "$oA" | tr -d ' ')
  if [ "$rcA" -eq 0 ] && [ "$rcB" -eq 0 ] && [ -s "$oA" ] && cmp -s "$oA" "$oB"; then
    printf "  PASS  %-22s rcA=%s rcB=%s sz=%s sha=%s\n" \
           "$b" "$rcA" "$rcB" "$sz" "$(sha "$oA" | cut -c1-12)"
  else
    printf "  FAIL  %-22s rcA=%s rcB=%s sz=%s\n" "$b" "$rcA" "$rcB" "$sz"
    echo "        ↳ shaA=$(sha "$oA")  shaB=$(sha "$oB")"
    cmp "$oA" "$oB" 2>&1 | head -1 | sed 's/^/        ↳ /'
    echo "        ↳ logs: $lA  $lB"
    fail=1
  fi
done

# ── PHASE 2 — RELINK determinism ─────────────────────────────────────────
if [ "$LD_MODE" = "none" ]; then
  echo "== PHASE 2 — relink: SKIPPED (no linker; emit determinism still gated) =="
else
  echo "== PHASE 2 — relink (hexa_ld twice, same basename, byte-identical) =="
  MAIN_ARGS=()
  if [ -n "${HEXA_LD_MAIN:-}" ]; then MAIN_ARGS=(--lc-main "$HEXA_LD_MAIN"); fi
  for src in "$CORPUS"/*.hexa; do
    [ -e "$src" ] || continue
    b="$(basename "$src" .hexa)"
    obj="$OUT/emit/$b.A.o"
    [ -s "$obj" ] || continue        # only relink what emitted in phase 1
    d1="$OUT/relink/$b.1"; d2="$OUT/relink/$b.2"
    rm -rf "$d1" "$d2"; mkdir -p "$d1" "$d2"
    # SAME output basename in two dirs -> path-derived build-id identical,
    # so only a TRUE nondeterminism can make the bytes differ.
    # (${MAIN_ARGS[@]+...} guards the empty-array expansion under `set -u`.)
    "${LD_WORDS[@]}" ${MAIN_ARGS[@]+"${MAIN_ARGS[@]}"} -o "$d1/out" "$obj" 2>"$d1/log"; r1=$?
    "${LD_WORDS[@]}" ${MAIN_ARGS[@]+"${MAIN_ARGS[@]}"} -o "$d2/out" "$obj" 2>"$d2/log"; r2=$?
    sz=0; [ -s "$d1/out" ] && sz=$(wc -c < "$d1/out" | tr -d ' ')
    if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ -s "$d1/out" ] && cmp -s "$d1/out" "$d2/out"; then
      printf "  PASS  %-22s r1=%s r2=%s sz=%s sha=%s\n" \
             "$b" "$r1" "$r2" "$sz" "$(sha "$d1/out" | cut -c1-12)"
    else
      printf "  FAIL  %-22s r1=%s r2=%s sz=%s\n" "$b" "$r1" "$r2" "$sz"
      echo "        ↳ sha1=$(sha "$d1/out")  sha2=$(sha "$d2/out")"
      cmp "$d1/out" "$d2/out" 2>&1 | head -1 | sed 's/^/        ↳ /'
      echo "        ↳ logs: $d1/log  $d2/log"
      fail=1
    fi
  done
fi

echo "──────────────────────────────────────────────────────────────────"
if [ "$n" -eq 0 ]; then
  echo "determinism-gate: SETUP ERROR — corpus is empty ($CORPUS)." >&2
  exit 2
fi
if [ "$fail" -ne 0 ]; then
  echo "determinism-gate: FAIL — toolchain nondeterminism detected" >&2
  echo "  (an emit or relink produced different bytes for the same input)." >&2
  exit 1
fi
echo "determinism-gate: PASS — $n/$n programs re-emit AND relink byte-identically"
echo "  (toolchain byte-determinism floor held)."
exit 0
