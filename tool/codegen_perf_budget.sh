#!/usr/bin/env bash
# tool/codegen_perf_budget.sh — MISCOMPILE-ZERO codegen PERF-STABILITY budget.
#
# PURPOSE
#   Correctness of the graduated native codegen is locked by the existing gates
#   (miscompile-zero #2534, determinism #2538, class tests #2548, diff-fuzz
#   #2557). This tool adds the PERF axis: it records the native compiler's emit
#   cost — per-program --emit=obj wall-time (real, median of N runs) and object
#   byte-size — as a tracked BASELINE, so a future codegen change that regresses
#   emit perf (much slower, or much fatter objects) is caught as a budget break,
#   complementing the correctness gates.
#
#   This is NOT a correctness gate. It does NOT inspect for ENCODE-MISS / udf
#   (the miscompile-zero gate owns that). It measures cost only.
#
# CORPUS
#   Reuses the stable miscompile_zero corpus (self/test/miscompile_zero/c1..c10)
#   as the representative fixed set — small, diverse (hex/struct/closure/match/
#   recursion/strings/try-catch), already pinned for the correctness gates, and
#   READ-ONLY here (never modified).
#
# MODES
#   baseline   measure the corpus → write a machine-readable baseline TSV
#              (program<TAB>obj_bytes<TAB>wall_ms_median) + a human header.
#   check      re-measure the corpus → diff vs the committed baseline TSV;
#              FAIL (exit 1) if obj_bytes grows > SIZE_PCT% OR
#              wall_ms_median regresses > WALL_PCT% for ANY program.
#   (default: check if a baseline TSV exists, else baseline.)
#
# CONFIG (env, defaults mirror tool/miscompile_zero_gate.sh for the ghost host)
#   HEXA_NATIVE_CC   native self-hosted compiler driver (default: gen2_fix in
#                    ~/dancinlab/selfhost-work, else `hexa` on PATH).
#   HEXA_CC_PREARGS  args inserted after $HEXA_NATIVE_CC, BEFORE the emit flags.
#                    gen2_fix consumes argv[1] as its driver-name slot, so the
#                    default is "_drv.hexa". For a released ./hexa driver set
#                    HEXA_CC_PREARGS="run compiler/main.hexa".
#   HEXA_ATLAS_EMBED empty-atlas dir for a hermetic build (default: under OUT).
#   HEXA_TARGET      target triple (default: arm64-apple-darwin).
#   PERF_CORPUS      corpus dir (default: <repo>/self/test/miscompile_zero).
#   PERF_OUT         object/log output dir (default: <repo>/build/perf-budget-out).
#   PERF_BASELINE    baseline TSV path (default: <repo>/tool/codegen_perf_baseline.tsv).
#   PERF_RUNS        timed runs per program; median taken (default: 5, min 1).
#   PERF_WARMUP      untimed warmup runs per program before timing (default: 1).
#   PERF_SIZE_PCT    obj-size regression budget, percent (default: 5).
#   PERF_WALL_PCT    wall-time regression budget, percent (default: 50, CI-noisy).
#
# EXIT
#   0  baseline mode: baseline written.  check mode: within budget (no program
#      regressed beyond SIZE_PCT / WALL_PCT) — perf floor held.
#   1  check mode ONLY: a REGRESSION — some program's object grew > SIZE_PCT% or
#      its median wall grew > WALL_PCT%. The codegen perf budget broke.
#   2  SETUP / INFRA — the configured driver cannot native-emit in THIS env
#      (canary 0-byte), or (check mode) the committed baseline is missing /
#      malformed. CI-neutral, mirrors the miscompile-zero gate: the perf floor
#      is NOT broken, the runner just lacks the graduated native emitter.
#
# CLASSIFICATION RULE (mirrors miscompile_zero_gate.sh)
#   A 0-byte object / invocation failure means this env cannot native-emit →
#   INFRA (exit 2), NEVER a perf regression. Only a real, measured size/wall
#   growth beyond budget vs a committed baseline is the red (exit 1).
#   No pipe-mask: every rc is captured and honored. No /tmp: scratch under build/.

set -uo pipefail

# ── locate repo + corpus ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS="${PERF_CORPUS:-$REPO/self/test/miscompile_zero}"

if [ ! -d "$CORPUS" ]; then
  echo "perf-budget: SETUP ERROR — corpus dir not found: $CORPUS" >&2
  exit 2
fi

# ── mode ─────────────────────────────────────────────────────────────────
BASELINE="${PERF_BASELINE:-$REPO/tool/codegen_perf_baseline.tsv}"
MODE="${1:-}"
if [ -z "$MODE" ]; then
  if [ -s "$BASELINE" ]; then MODE="check"; else MODE="baseline"; fi
fi
case "$MODE" in
  baseline|check) ;;
  *) echo "perf-budget: usage: $0 [baseline|check]" >&2; exit 2 ;;
esac

# ── locate the native self-hosted compiler (mirror miscompile_zero_gate) ──
if [ -n "${HEXA_NATIVE_CC:-}" ]; then
  CC="$HEXA_NATIVE_CC"
elif [ -x "$HOME/dancinlab/selfhost-work/gen2_fix" ]; then
  CC="$HOME/dancinlab/selfhost-work/gen2_fix"
elif command -v hexa >/dev/null 2>&1; then
  CC="$(command -v hexa)"
else
  echo "perf-budget: SETUP ERROR — no native compiler." >&2
  echo "  set HEXA_NATIVE_CC=<path to gen2_fix / native hexa driver>" >&2
  exit 2
fi

TARGET="${HEXA_TARGET:-arm64-apple-darwin}"

if [ -z "${HEXA_CC_PREARGS+set}" ]; then
  PREARGS=("_drv.hexa")            # unset -> default gen2_fix placeholder
else
  # shellcheck disable=SC2206
  PREARGS=(${HEXA_CC_PREARGS})     # set (possibly empty) -> word-split
fi

RUNS="${PERF_RUNS:-5}";       [ "$RUNS"   -ge 1 ] 2>/dev/null || RUNS=5
WARMUP="${PERF_WARMUP:-1}";   [ "$WARMUP" -ge 0 ] 2>/dev/null || WARMUP=1
SIZE_PCT="${PERF_SIZE_PCT:-5}"
WALL_PCT="${PERF_WALL_PCT:-50}"

# ── output dir (NOT /tmp; default under the already-gitignored build/ dir) ─
OUT="${PERF_OUT:-$REPO/build/perf-budget-out}"
mkdir -p "$OUT"

# ── hermetic empty atlas (avoid pulling the real embedded atlas) ──────────
if [ -z "${HEXA_ATLAS_EMBED:-}" ]; then
  HEXA_ATLAS_EMBED="$OUT/noatlas"
  mkdir -p "$HEXA_ATLAS_EMBED"
fi
export HEXA_ATLAS_EMBED

# ── millisecond clock (portable: prefer date %N, fall back to perl/python) ─
now_ms() {
  local t
  t=$(date +%s%N 2>/dev/null)
  if [ -n "$t" ] && [ "${t%N}" = "$t" ]; then
    echo $(( t / 1000000 )); return
  fi
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%d", time()*1000'; return
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time;print(int(time.time()*1000))'; return
  fi
  echo $(( $(date +%s) * 1000 ))
}

# emit_one SRC OBJ LOG — single native --emit=obj; sets E_RC, E_SZ.
emit_one() {
  local src="$1" obj="$2" log="$3"
  rm -f "$obj"
  "$CC" "${PREARGS[@]}" \
        --emit=obj --target="$TARGET" --ignore-errors \
        -o "$obj" "$src" >"$log" 2>&1
  E_RC=$?
  if [ -s "$obj" ]; then E_SZ=$(wc -c < "$obj" | tr -d ' '); else E_SZ=0; fi
}

# median_of LIST...  — integer median of the passed values (sorted middle).
median_of() {
  local sorted mid n
  # shellcheck disable=SC2207
  sorted=($(printf '%s\n' "$@" | sort -n))
  n=${#sorted[@]}
  mid=$(( n / 2 ))
  if [ $(( n % 2 )) -eq 1 ]; then
    echo "${sorted[$mid]}"
  else
    echo $(( ( sorted[mid-1] + sorted[mid] ) / 2 ))
  fi
}

echo "── codegen perf budget ($MODE) ───────────────────────────────────"
echo "  compiler : $CC ${PREARGS[*]}"
echo "  target   : $TARGET"
echo "  corpus   : $CORPUS"
echo "  out      : $OUT"
echo "  runs     : $RUNS (warmup $WARMUP)   budget: size +${SIZE_PCT}% wall +${WALL_PCT}%"
echo "  baseline : $BASELINE"
echo "──────────────────────────────────────────────────────────────────"

# ── CANARY — can this env native-emit AT ALL? (mirror miscompile_zero_gate) ─
CANARY_SRC="$CORPUS/c1_hex_literal.hexa"
if [ -e "$CANARY_SRC" ]; then
  emit_one "$CANARY_SRC" "$OUT/_canary.o" "$OUT/_canary.emit.log"
  if [ "$E_SZ" -eq 0 ]; then
    echo "perf-budget: SETUP/INFRA — canary will not native-emit" >&2
    echo "  (c1_hex_literal: rc=$E_RC objsize=0 — the compiler cannot native" >&2
    echo "   --emit=obj in THIS environment; the perf floor is NOT broken)." >&2
    echo "   Set HEXA_NATIVE_CC to a graduated native compiler (ghost gen2_fix)." >&2
    echo "        ↳ canary emit log: $OUT/_canary.emit.log" >&2
    exit 2
  fi
  echo "  canary   : c1_hex_literal emits (objsize=$E_SZ) — native-emit OK"
  echo "──────────────────────────────────────────────────────────────────"
fi

# ── validate committed baseline (check mode) ─────────────────────────────
# NOTE: associative arrays (declare -A) need bash 4+; the ghost macOS host runs
# bash 3.2, so baseline rows are looked up per-program via a grep on the TSV
# (base_lookup, below) instead — keeping this harness bash-3.2 portable like
# tool/miscompile_zero_gate.sh.
if [ "$MODE" = "check" ]; then
  if [ ! -s "$BASELINE" ]; then
    echo "perf-budget: SETUP/INFRA — baseline missing/empty: $BASELINE" >&2
    echo "  Run '$0 baseline' on a graduated native host and commit the TSV." >&2
    exit 2
  fi
  base_rows=$(grep -cv -e '^#' -e '^[[:space:]]*$' "$BASELINE" 2>/dev/null)
  base_rows=${base_rows:-0}
  if [ "$base_rows" -eq 0 ]; then
    echo "perf-budget: SETUP/INFRA — baseline malformed (no rows): $BASELINE" >&2
    exit 2
  fi
fi

# base_lookup PROG  — read one baseline row; sets B_SZ / B_WALL (empty if absent).
base_lookup() {
  local prog="$1" line
  B_SZ=""; B_WALL=""
  line=$(grep -E "^${prog}	" "$BASELINE" 2>/dev/null | head -1)
  [ -n "$line" ] || return 0
  B_SZ=$(printf '%s' "$line" | cut -f2)
  B_WALL=$(printf '%s' "$line" | cut -f3)
}

# ── measure the corpus ───────────────────────────────────────────────────
TSV_OUT="$OUT/measured.tsv"
{
  echo "# codegen_perf_baseline — native --emit=obj cost, MISCOMPILE-ZERO perf axis"
  echo "# compiler=$(basename "$CC") target=$TARGET runs=$RUNS warmup=$WARMUP"
  echo "# columns: program<TAB>obj_bytes<TAB>wall_ms_median"
} > "$TSV_OUT"

fail=0
setuperr=0
n=0
for src in "$CORPUS"/*.hexa; do
  [ -e "$src" ] || continue
  n=$((n + 1))
  b="$(basename "$src" .hexa)"
  obj="$OUT/$b.o"
  log="$OUT/$b.emit.log"

  # warmup (untimed) — stabilize fs cache / dyld
  w=0
  while [ "$w" -lt "$WARMUP" ]; do emit_one "$src" "$obj" "$log"; w=$((w + 1)); done

  # timed runs
  times=()
  r=0
  last_sz=0
  while [ "$r" -lt "$RUNS" ]; do
    t0=$(now_ms)
    emit_one "$src" "$obj" "$log"
    t1=$(now_ms)
    times+=( $(( t1 - t0 )) )
    last_sz=$E_SZ
    r=$((r + 1))
  done

  if [ "$last_sz" -eq 0 ]; then
    printf "  SETUP %-22s objsize=0 (no emit — infra)\n" "$b"
    echo "        ↳ emit log: $log"
    setuperr=$((setuperr + 1))
    continue
  fi

  wall=$(median_of "${times[@]}")
  printf '%s\t%s\t%s\n' "$b" "$last_sz" "$wall" >> "$TSV_OUT"

  if [ "$MODE" = "baseline" ]; then
    printf "  MEAS  %-22s objsize=%-8s wall_ms_median=%s\n" "$b" "$last_sz" "$wall"
    continue
  fi

  # ── check mode: diff vs committed baseline ─────────────────────────────
  base_lookup "$b"
  bsz="$B_SZ"
  bwall="$B_WALL"
  if [ -z "$bsz" ]; then
    printf "  NEW   %-22s objsize=%-8s wall_ms_median=%s (not in baseline — skip)\n" \
           "$b" "$last_sz" "$wall"
    continue
  fi

  # size budget: fail if last_sz > bsz * (100 + SIZE_PCT) / 100
  sz_cap=$(( bsz * (100 + SIZE_PCT) / 100 ))
  # wall budget: fail if wall > bwall * (100 + WALL_PCT) / 100. Guard a 0-ms
  # baseline (clock granularity) with a +1ms floor so the cap is meaningful.
  wall_cap=$(( bwall * (100 + WALL_PCT) / 100 ))
  [ "$wall_cap" -lt $(( bwall + 1 )) ] && wall_cap=$(( bwall + 1 ))

  bad=0; reason=""
  if [ "$last_sz" -gt "$sz_cap" ]; then
    bad=1; reason="$reason size=$last_sz>cap$sz_cap(base$bsz +${SIZE_PCT}%)"
  fi
  if [ "$wall" -gt "$wall_cap" ]; then
    bad=1; reason="$reason wall=${wall}ms>cap${wall_cap}ms(base${bwall} +${WALL_PCT}%)"
  fi

  if [ "$bad" -eq 0 ]; then
    printf "  PASS  %-22s objsize=%-8s(base %-8s) wall=%-4sms(base %sms)\n" \
           "$b" "$last_sz" "$bsz" "$wall" "$bwall"
  else
    printf "  FAIL  %-22s%s\n" "$b" "$reason"
    fail=1
  fi
done

echo "──────────────────────────────────────────────────────────────────"
if [ "$n" -eq 0 ]; then
  echo "perf-budget: SETUP ERROR — corpus is empty ($CORPUS)." >&2
  exit 2
fi

# Any program that could not emit at all is infra, never a perf regression.
if [ "$setuperr" -ne 0 ] && [ "$fail" -eq 0 ]; then
  echo "perf-budget: SETUP/INFRA — $setuperr/$n programs could not native-emit" >&2
  echo "  (0-byte). The perf floor is NOT broken; this env lacks the graduated" >&2
  echo "  native emitter. CI-neutral (exit 2)." >&2
  exit 2
fi

if [ "$MODE" = "baseline" ]; then
  if [ "$setuperr" -ne 0 ]; then
    echo "perf-budget: SETUP/INFRA — $setuperr/$n could not emit; baseline partial." >&2
    exit 2
  fi
  cp "$TSV_OUT" "$BASELINE"
  echo "perf-budget: BASELINE written — $((n - setuperr))/$n programs measured"
  echo "  → $BASELINE"
  exit 0
fi

# check mode terminal
if [ "$fail" -ne 0 ]; then
  echo "perf-budget: FAIL — codegen emit-perf regression beyond budget" >&2
  echo "  (a program's object grew > ${SIZE_PCT}% or median wall grew > ${WALL_PCT}%" >&2
  echo "   vs the committed baseline). The perf floor broke." >&2
  exit 1
fi
echo "perf-budget: PASS — all measured programs within budget"
echo "  (≤ +${SIZE_PCT}% obj-size, ≤ +${WALL_PCT}% wall vs baseline) — perf floor held."
exit 0
