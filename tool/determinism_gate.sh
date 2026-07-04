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
#   SELFHOST_SLOT    graduated gen3 slot {gen3,hexa_ld,rt.o}. Auto-discovered
#                    at $HX_HOME/self/native/selfhost, $HOME/.hx/self/native/
#                    selfhost, or <repo>/build/selfhost — the DEFAULT promoted
#                    self-host path (tool/promote_selfhost.sh). When found it
#                    sets CC=gen3, the linker=hexa_ld, rt.o=slot/rt.o so the
#                    determinism floor is measured on the gen3 DEFAULT route.
#   HEXA_LD_RT       runtime object appended to each PHASE-2 link (default:
#                    slot/rt.o on the gen3 path; empty on the legacy bootstrap).
#   HEXA_NATIVE_CC   native self-hosted compiler driver — OVERRIDES the slot
#                    (default: slot/gen3, else gen2_fix in ~/dancinlab/
#                    selfhost-work, else `hexa` on PATH)
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
#   1  REGRESSION — objects/executables WERE produced but two runs of the same
#      input gave DIFFERENT bytes (true nondeterminism). The only red.
#   2  SETUP / INFRA — the configured driver cannot native-emit a single program
#      in THIS environment at all (both runs 0-byte with NO ENCODE-MISS).
#      CI-neutral: determinism is untestable here, NOT broken. A released
#      `./hexa` recompiles compiler/main.hexa against its embedded runtime and
#      hits the build-floor staleness wall (0-byte emit); only the graduated
#      self-host gen2 (ghost gen2_fix) native-emits cleanly. Up front a trivial
#      CANARY (c1_hex_literal) is emitted: if it will not emit, exit 2 at once.
#
# CLASSIFICATION RULE
#   Two runs that BOTH fail to produce an object (0-byte, no ENCODE-MISS) is an
#   INFRA error, NOT a nondeterminism regression. Only two PRODUCED outputs
#   that differ byte-for-byte (or a produce-then-fail asymmetry) is a red.

set -uo pipefail

# ── locate repo + corpus ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS="${DETERM_CORPUS:-$REPO/self/test/miscompile_zero}"

if [ ! -d "$CORPUS" ]; then
  echo "determinism-gate: SETUP ERROR — corpus dir not found: $CORPUS" >&2
  exit 2
fi

# ── locate the GRADUATED gen3 self-host slot (the DEFAULT promoted path) ──
# The promoted route (tool/promote_selfhost.sh) installs the graduated native
# compiler at $HX_HOME/self/native/selfhost/{gen3,hexa_ld,rt.o} — the SAME
# slot the promote-parity / byte-eq sister gates use. THIS is the default
# self-host compile route a user hits after promotion. We discover it first so
# the determinism floor is measured on the gen3 DEFAULT path (gen3 + hexa_ld
# + rt.o), not only the legacy gen2_fix/hld_fixed bootstrap. An explicit
# SELFHOST_SLOT (or HX_HOME) wins; HEXA_NATIVE_CC / HEXA_LD still override.
SLOT=""
for cand in \
  "${SELFHOST_SLOT:-}" \
  "${HX_HOME:-}/self/native/selfhost" \
  "$HOME/.hx/self/native/selfhost" \
  "$REPO/build/selfhost"; do
  [ -n "$cand" ] || continue
  if [ -x "$cand/gen3" ] && [ -x "$cand/hexa_ld" ] && [ -s "$cand/rt.o" ]; then
    SLOT="$cand"; break
  fi
done

# ── locate the native self-hosted compiler ───────────────────────────────
if [ -n "${HEXA_NATIVE_CC:-}" ]; then
  CC="$HEXA_NATIVE_CC"
elif [ -n "$SLOT" ]; then
  CC="$SLOT/gen3"                  # DEFAULT path: graduated gen3
elif [ -x "$HOME/dancinlab/selfhost-work/gen2_fix" ]; then
  CC="$HOME/dancinlab/selfhost-work/gen2_fix"
elif command -v hexa >/dev/null 2>&1; then
  CC="$(command -v hexa)"
else
  echo "determinism-gate: SETUP ERROR — no native compiler." >&2
  echo "  set HEXA_NATIVE_CC=<path to gen3 slot / gen2_fix / native hexa>" >&2
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
# On the gen3 DEFAULT path the link is `hexa_ld -o out prog.o rt.o --lc-main
# _main` (the same form the promote-parity gate uses). HEXA_LD_RT is the
# runtime object appended to every link; HEXA_LD_MAIN defaults to _main on the
# slot path so the relink matches the real promoted link route. An explicit
# HEXA_LD wins; otherwise the discovered slot's hexa_ld+rt.o are used, then the
# legacy hld_fixed bootstrap.
LD_WORDS=()
LD_MODE="none"
LD_RT="${HEXA_LD_RT:-}"
if [ -n "${HEXA_LD:-}" ]; then
  # shellcheck disable=SC2206
  LD_WORDS=(${HEXA_LD})
  LD_MODE="env"
elif [ -n "$SLOT" ]; then
  LD_WORDS=("$SLOT/hexa_ld")
  LD_MODE="gen3-slot"
  [ -n "$LD_RT" ] || LD_RT="$SLOT/rt.o"          # default rt.o for the slot
  [ -n "${HEXA_LD_MAIN:-}" ] || HEXA_LD_MAIN="_main"
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
  [ -n "$LD_RT" ] && echo "  rt.o     : $LD_RT"
fi
[ -n "$SLOT" ] && echo "  slot     : $SLOT  (gen3 DEFAULT promoted path)"
echo "  target   : $TARGET"
echo "  corpus   : $CORPUS"
echo "  out      : $OUT"
echo "──────────────────────────────────────────────────────────────────"

sha() { shasum -a256 "$1" 2>/dev/null | cut -d' ' -f1; }

# emit_obj SRC OUTOBJ LOG → sets E_RC / E_SZ / E_EM (rc, byte-size, ENCODE-MISS)
emit_obj() {
  local src="$1" obj="$2" log="$3"
  rm -f "$obj"
  "$CC" "${PREARGS[@]}" --emit=obj --target="$TARGET" --ignore-errors \
        -o "$obj" "$src" >"$log" 2>&1
  E_RC=$?
  E_EM=$(grep -c "ENCODE-MISS" "$log" 2>/dev/null); E_EM=${E_EM:-0}
  if [ -s "$obj" ]; then E_SZ=$(wc -c < "$obj" | tr -d ' '); else E_SZ=0; fi
}

fail=0          # 1 => produced outputs DIFFER (true nondeterminism — red)
setuperr=0      # count of programs that could not emit at all (infra)
n=0

# ── CANARY — can this env native-emit AT ALL? ─────────────────────────────
# (See tool/miscompile_zero_gate.sh for the full rationale.) If the simplest
# corpus program will not produce a non-empty object with no ENCODE-MISS, the
# configured driver cannot native-emit here → SETUP/INFRA (exit 2), NOT a
# nondeterminism regression. Guards against a released `./hexa`'s
# `run compiler/main.hexa` recompile hitting the build-floor staleness wall.
CANARY_SRC="$CORPUS/c1_hex_literal.hexa"
if [ -e "$CANARY_SRC" ]; then
  emit_obj "$CANARY_SRC" "$OUT/emit/_canary.o" "$OUT/emit/_canary.log"
  if [ "$E_SZ" -eq 0 ] && [ "$E_EM" -eq 0 ]; then
    echo "determinism-gate: SETUP/INFRA — canary will not native-emit" >&2
    echo "  (c1_hex_literal: rc=$E_RC objsize=0 ENCODE-MISS=0 — the compiler" >&2
    echo "   cannot native --emit=obj in THIS environment; determinism is" >&2
    echo "   untestable, NOT broken). The real determinism gate needs the" >&2
    echo "   graduated self-host gen2 (ghost gen2_fix) or a self-host build" >&2
    echo "   step; a released ./hexa recompiles compiler/main.hexa against its" >&2
    echo "   embedded runtime and hits the build-floor staleness wall (0-byte" >&2
    echo "   emit). Set HEXA_NATIVE_CC to a graduated native compiler." >&2
    echo "        ↳ canary emit log: $OUT/emit/_canary.log" >&2
    exit 2
  fi
fi

# ── PHASE 1 — RE-EMIT determinism ────────────────────────────────────────
echo "== PHASE 1 — re-emit (native --emit=obj twice, byte-identical) =="
for src in "$CORPUS"/*.hexa; do
  [ -e "$src" ] || continue
  n=$((n + 1))
  b="$(basename "$src" .hexa)"
  oA="$OUT/emit/$b.A.o"; oB="$OUT/emit/$b.B.o"
  lA="$OUT/emit/$b.A.log"; lB="$OUT/emit/$b.B.log"

  emit_obj "$src" "$oA" "$lA"; rcA=$E_RC; szA=$E_SZ; emA=$E_EM
  emit_obj "$src" "$oB" "$lB"; rcB=$E_RC; szB=$E_SZ; emB=$E_EM

  sz="$szA"
  if [ "$szA" -eq 0 ] && [ "$szB" -eq 0 ] && [ "$emA" -eq 0 ] && [ "$emB" -eq 0 ]; then
    # Neither run produced an object and no ENCODE-MISS → infra, not a diff.
    printf "  SETUP %-22s rcA=%s rcB=%s sz=0 (no emit, no ENCODE-MISS — infra)\n" \
           "$b" "$rcA" "$rcB"
    echo "        ↳ logs: $lA  $lB"
    setuperr=$((setuperr + 1))
    continue
  fi

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
  # Runtime object appended to each link (gen3 DEFAULT path: rt.o). Empty for
  # the legacy hld_fixed bootstrap where the corpus links standalone.
  RT_ARGS=()
  if [ -n "$LD_RT" ] && [ -s "$LD_RT" ]; then RT_ARGS=("$LD_RT"); fi
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
    "${LD_WORDS[@]}" -o "$d1/out" "$obj" ${RT_ARGS[@]+"${RT_ARGS[@]}"} ${MAIN_ARGS[@]+"${MAIN_ARGS[@]}"} 2>"$d1/log"; r1=$?
    "${LD_WORDS[@]}" -o "$d2/out" "$obj" ${RT_ARGS[@]+"${RT_ARGS[@]}"} ${MAIN_ARGS[@]+"${MAIN_ARGS[@]}"} 2>"$d2/log"; r2=$?
    sz=0; [ -s "$d1/out" ] && sz=$(wc -c < "$d1/out" | tr -d ' ')
    if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ -s "$d1/out" ] && cmp -s "$d1/out" "$d2/out"; then
      printf "  PASS  %-22s r1=%s r2=%s sz=%s sha=%s\n" \
             "$b" "$r1" "$r2" "$sz" "$(sha "$d1/out" | cut -c1-12)"
    elif [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && [ ! -s "$d1/out" ] && [ ! -s "$d2/out" ]; then
      # BOTH relink runs failed to PRODUCE output (same nonzero rc, no out file):
      # a DETERMINISTIC link failure — the oracle cannot relink this program at
      # all. That is INFRA (stale/incompatible slot), NOT nondeterminism: two
      # runs did not produce DIFFERENT bytes, they produced NO comparable bytes.
      # Route to setuperr (exit-2 NEUTRAL), matching this gate's own model
      # (only two PRODUCED outputs that differ are the red — see header).
      printf "  INFRA %-22s r1=%s r2=%s (relink produced no output — oracle cannot link '%s')\n" "$b" "$r1" "$r2" "$b"
      echo "        ↳ stale/incompatible oracle: both relink runs exit nonzero with no output — NEUTRAL, not a determinism regression." >&2
      echo "        ↳ logs: $d1/log  $d2/log" >&2
      setuperr=$((setuperr + 1))
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
  echo "  (two runs produced DIFFERENT bytes for the same input)." >&2
  exit 1
fi
if [ "$setuperr" -ne 0 ]; then
  echo "determinism-gate: SETUP/INFRA — $setuperr/$n programs could not be" >&2
  echo "  native-emitted (0-byte, no ENCODE-MISS) OR could not be relinked by the" >&2
  echo "  oracle (both runs no output — stale/incompatible slot). Determinism is" >&2
  echo "  untestable here, NOT broken. CI-neutral (exit 2)." >&2
  exit 2
fi
echo "determinism-gate: PASS — $n/$n programs re-emit AND relink byte-identically"
echo "  (toolchain byte-determinism floor held)."
exit 0
