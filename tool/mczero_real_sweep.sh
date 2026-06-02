#!/usr/bin/env bash
# tool/mczero_real_sweep.sh — MISCOMPILE-ZERO real-program self-emit sweep.
#
# PURPOSE
#   The continuous-discovery lane of the MISCOMPILE-ZERO goal. Where
#   tool/miscompile_zero_gate.sh runs a tiny synthetic class corpus and the
#   82-sweep (#2535) covered a hand-picked feature-axis subset, THIS driver
#   sweeps the FULL real shipped program tree (example/*.hexa by default) with
#   the graduated self-hosted compiler (gen2_fix) native --emit=obj, hunting
#   for any NEW native-codegen miscompile beyond the already-clean corpora.
#
#   It is DRIVE + MEASURE + REPORT only — it never edits the production
#   compiler. A finding here is a real program that miscompiles; the agent
#   then isolates + root-causes + reports (no in-sweep fix).
#
# WHAT IT DOES  (per program, reusing the 82-sweep oracle methodology)
#   (1) gen2_fix --emit=obj           -> capture rc, objsize, ENCODE-MISS count,
#                                        spurious `udf` count (real, no pipe-mask)
#   (2) gen2_fix --emit=asm  vs  aprime oracle --emit=asm
#       -> byte-diff AFTER normalizing the benign per-module label hash
#          (__L<4hex>_ -> __L_); ANY surviving diff = a candidate finding.
#   A program is CLEAN iff: rc==0 AND objsize>0 AND ENCODE-MISS==0 AND udf==0
#   AND the normalized asm matches the oracle.
#
# CLASSIFICATION  (g63 honest — same rule as miscompile_zero_gate.sh)
#   - CLEAN     : emits + matches oracle.
#   - SKIP      : the program does NOT compile under EITHER compiler for an
#                 unrelated reason (gen2 rc!=0 AND objsize==0 AND ENCODE-MISS==0
#                 AND the oracle ALSO fails to emit it) — a missing-dep / not-a-
#                 standalone-program case, NOT a codegen finding. Logged with the
#                 reason. SKIPs are not findings.
#   - FINDING   : an object WAS produced (or an ENCODE-MISS surfaced) but is
#                 dirty (ENCODE-MISS / udf / rc!=0 with obj present), OR the
#                 normalized asm diverges from the oracle while the oracle is
#                 clean. This is the only red — a NEW miscompile to isolate.
#
# CONFIG (env; defaults target the proven ghost gen2_fix + aprime oracle)
#   HEXA_NATIVE_CC   graduated native compiler (default: ~/dancinlab/selfhost-work/gen2_fix)
#   HEXA_ORACLE_CC   C-built reference compiler (default: first of
#                    aprime_fixhex / aprime_fix / aprime_ghost under selfhost-work)
#   HEXA_CC_PREARGS  prearg slot before the emit flags (default: _drv.hexa)
#   HEXA_ORACLE_PREARGS prearg slot for the oracle (default: same as gen2)
#   HEXA_TARGET      target triple (default: arm64-apple-darwin)
#   HEXA_ATLAS_EMBED hermetic empty-atlas dir (default: a scratch dir)
#   MCZERO_TREE      program tree to sweep (default: <repo>/example)
#   MCZERO_GLOB      glob within the tree (default: *.hexa)
#   MCZERO_OUT       object/asm/log output dir (default: scratch under selfhost-work)
#   MCZERO_TSV       results TSV path (default: $MCZERO_OUT/results.tsv)
#
# EXIT  0 = sweep ran; NO finding (every compiled program clean). SKIPs OK.
#       1 = at least one FINDING (a real candidate miscompile) — see TSV/logs.
#       2 = SETUP/INFRA (no native compiler / oracle / canary will not emit).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
TREE="${MCZERO_TREE:-$REPO/example}"
GLOB="${MCZERO_GLOB:-*.hexa}"

[ -d "$TREE" ] || { echo "mczero-real-sweep: SETUP — tree not found: $TREE" >&2; exit 2; }

# ── locate the graduated native compiler ──────────────────────────────────
if [ -n "${HEXA_NATIVE_CC:-}" ]; then CC="$HEXA_NATIVE_CC"
elif [ -x "$HOME/dancinlab/selfhost-work/gen2_fix" ]; then CC="$HOME/dancinlab/selfhost-work/gen2_fix"
else echo "mczero-real-sweep: SETUP — no graduated native compiler (set HEXA_NATIVE_CC)" >&2; exit 2; fi

# ── locate the C-built oracle ─────────────────────────────────────────────
if [ -n "${HEXA_ORACLE_CC:-}" ]; then ORACLE="$HEXA_ORACLE_CC"
else
  ORACLE=""
  for c in aprime_fixhex aprime_fix aprime_ghost; do
    if [ -x "$HOME/dancinlab/selfhost-work/$c" ]; then ORACLE="$HOME/dancinlab/selfhost-work/$c"; break; fi
  done
  [ -n "$ORACLE" ] || { echo "mczero-real-sweep: SETUP — no aprime oracle (set HEXA_ORACLE_CC)" >&2; exit 2; }
fi

if [ -z "${HEXA_CC_PREARGS+set}" ]; then PREARGS=("_drv.hexa")
else PREARGS=(${HEXA_CC_PREARGS}); fi
if [ -z "${HEXA_ORACLE_PREARGS+set}" ]; then OPREARGS=("${PREARGS[@]}")
else OPREARGS=(${HEXA_ORACLE_PREARGS}); fi

TARGET="${HEXA_TARGET:-arm64-apple-darwin}"
OUT="${MCZERO_OUT:-$HOME/dancinlab/selfhost-work/mczero-real-sweep/out}"
mkdir -p "$OUT"
TSV="${MCZERO_TSV:-$OUT/results.tsv}"

if [ -z "${HEXA_ATLAS_EMBED:-}" ]; then HEXA_ATLAS_EMBED="$OUT/noatlas"; mkdir -p "$HEXA_ATLAS_EMBED"; fi
export HEXA_ATLAS_EMBED

if command -v otool >/dev/null 2>&1; then DISASM="otool -tv"
elif command -v objdump >/dev/null 2>&1; then DISASM="objdump -d"
else echo "mczero-real-sweep: SETUP — no disassembler (otool/objdump)" >&2; exit 2; fi
disasm() { $DISASM "$1" 2>/dev/null; }

# normalize the benign per-module 4-hex label hash (__L<hex>_ -> __L_) so the
# only documented benign difference does not register as a divergence.
norm_asm() { sed -E 's/__L[0-9a-f]+_/__L_/g' "$1"; }

echo "── mczero real-program self-emit sweep ───────────────────────────"
echo "  compiler : $CC ${PREARGS[*]}"
echo "  oracle   : $ORACLE ${OPREARGS[*]}"
echo "  target   : $TARGET"
echo "  tree     : $TREE/$GLOB"
echo "  out      : $OUT"
echo "  disasm   : $DISASM"
echo "──────────────────────────────────────────────────────────────────"
echo "  gen2 sha : $(shasum -a 256 "$CC" 2>/dev/null | cut -d' ' -f1)"
echo "  orcl sha : $(shasum -a 256 "$ORACLE" 2>/dev/null | cut -d' ' -f1)"
echo "──────────────────────────────────────────────────────────────────"

printf "prog\trc\tobjsize\tencode_miss\tudf\toracle_rc\tasm_diff\tstatus\n" > "$TSV"

n=0; clean=0; skip=0; finding=0
for src in "$TREE"/$GLOB; do
  [ -e "$src" ] || continue
  n=$((n + 1))
  b="$(basename "$src" .hexa)"
  rel="${src#$REPO/}"
  obj="$OUT/$b.o"; log="$OUT/$b.emit.log"
  gasm="$OUT/$b.gen2.s"; oasm="$OUT/$b.oracle.s"
  olog="$OUT/$b.oracle.log"
  rm -f "$obj" "$gasm" "$oasm"

  # (1) gen2 native --emit=obj
  "$CC" "${PREARGS[@]}" --emit=obj --target="$TARGET" --ignore-errors -o "$obj" "$src" >"$log" 2>&1
  rc=$?
  em=$(grep -c "ENCODE-MISS" "$log" 2>/dev/null); em=${em:-0}
  if [ -s "$obj" ]; then sz=$(wc -c < "$obj" | tr -d ' '); else sz=0; fi
  if [ "$sz" -gt 0 ]; then udf=$(disasm "$obj" | grep -ci '\budf\b' 2>/dev/null); udf=${udf:-0}; else udf=0; fi

  # (2) asm oracle compare
  "$CC"     "${PREARGS[@]}"  --emit=asm --target="$TARGET" --ignore-errors -o "$gasm" "$src" >/dev/null 2>&1
  "$ORACLE" "${OPREARGS[@]}" --emit=asm --target="$TARGET" --ignore-errors -o "$oasm" "$src" >"$olog" 2>&1
  orc=$?
  asm_diff="n/a"
  if [ -s "$gasm" ] && [ -s "$oasm" ]; then
    if diff -q <(norm_asm "$gasm") <(norm_asm "$oasm") >/dev/null 2>&1; then asm_diff="match"; else asm_diff="DIVERGE"; fi
  fi

  # classify
  status=""
  if [ "$sz" -eq 0 ] && [ "$em" -eq 0 ]; then
    # gen2 produced nothing, no ENCODE-MISS. SKIP only if oracle ALSO can't emit.
    if [ ! -s "$oasm" ]; then
      status="SKIP"; skip=$((skip + 1))
    else
      # gen2 fails to emit a program the oracle CAN -> that itself is a finding
      status="FINDING(gen2-no-emit)"; finding=$((finding + 1))
    fi
  else
    bad=0; why=""
    [ "$em"  -ne 0 ] && { bad=1; why="$why ENCODE-MISS=$em"; }
    [ "$udf" -ne 0 ] && { bad=1; why="$why udf=$udf"; }
    [ "$rc"  -ne 0 ] && [ "$sz" -gt 0 ] && { bad=1; why="$why rc=$rc(obj-present)"; }
    # asm divergence is a finding only when the oracle emitted clean (orc==0) too
    if [ "$asm_diff" = "DIVERGE" ] && [ "$orc" -eq 0 ]; then bad=1; why="$why asm-DIVERGE"; fi
    if [ "$bad" -eq 0 ]; then status="CLEAN"; clean=$((clean + 1));
    else status="FINDING:$why"; finding=$((finding + 1)); fi
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$rel" "$rc" "$sz" "$em" "$udf" "$orc" "$asm_diff" "$status" >> "$TSV"
  case "$status" in
    CLEAN)        printf "  CLEAN  %-34s rc=%s sz=%s em=%s udf=%s asm=%s\n" "$b" "$rc" "$sz" "$em" "$udf" "$asm_diff" ;;
    SKIP)         printf "  SKIP   %-34s rc=%s sz=0 (oracle also no-emit — unrelated dep)\n" "$b" "$rc" ;;
    FINDING*)     printf "  >>FIND %-34s %s\n" "$b" "$status"; echo "         emit-log: $log"; echo "         oracle-log: $olog" ;;
  esac
done

echo "──────────────────────────────────────────────────────────────────"
echo "  swept=$n  clean=$clean  skip=$skip  finding=$finding"
echo "  TSV: $TSV"
if [ "$finding" -ne 0 ]; then
  echo "mczero-real-sweep: FINDING(S) — $finding real-program candidate miscompile(s)" >&2
  exit 1
fi
echo "mczero-real-sweep: CLEAN — $clean/$((n-skip)) compiled programs clean ($skip skipped, unrelated)"
exit 0
