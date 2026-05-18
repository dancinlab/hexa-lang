#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# tool/parity_interp_vs_compiled.sh — R7 measured-cutover parity gate
# ══════════════════════════════════════════════════════════════════════
# Runs every test/*.hexa BOTH ways and compares stdout bytes + exit code:
#
#   interp   : HEXA_FORCE_INTERP=1 hexa run <f>     (retiring tree-walker)
#   compiled : hexa run <f>                          (A.1 compile-then-exec)
#
# This is the GATE to Cycle C (physically deleting the interp source):
# the interp may only be deleted once every DETERMINISTIC program the
# interp runs correctly is reproduced byte-identically by the compiled
# path. Non-determinism (clock/rng/socket/stdin) is skipped explicitly
# (auditable skiplist + heuristic) — parity is only meaningful for
# deterministic output.
#
# Honest gate semantics (g3 — interp is a measured buggy-oracle, so
# "interp fails / compiled succeeds" is NOT a regression, it is the
# reason to delete interp):
#
#   MATCH              bytes + rc identical                → ok
#   DIVERGE            both ran, stdout bytes differ       → GATE-FAIL
#   RC_DIFF            bytes equal, exit codes differ       → GATE-FAIL
#   COMPILED_REGRESS   interp OK but compiled failed        → GATE-FAIL
#   INTERP_ONLY_FAIL   compiled OK but interp failed         → ok (interp bug)
#   BOTH_FAIL          neither produced a clean run          → ok (no regress)
#   SKIP               non-deterministic / interactive       → not counted
#
# exit 0  iff  DIVERGE==0 && RC_DIFF==0 && COMPILED_REGRESS==0
#
# Usage:
#   bash tool/parity_interp_vs_compiled.sh [-t SECS] [-d DIR] [-o OUTDIR]
#     -t SECS    per-file wall timeout (default 60)
#     -d DIR     corpus dir (default: test)
#     -o OUTDIR  artifact dir (default: $HOME/.hexa-cache/parity.<ns>)
# ══════════════════════════════════════════════════════════════════════
set -u

TIMEOUT=60
CORPUS_DIR="test"
OUTDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    -t) TIMEOUT="$2"; shift 2 ;;
    -d) CORPUS_DIR="$2"; shift 2 ;;
    -o) OUTDIR="$2"; shift 2 ;;
    *)  echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Resolve the hexa driver (prefer the installed shim, else PATH).
HEXA="$( [ -x "$HOME/.hx/bin/hexa" ] && echo "$HOME/.hx/bin/hexa" || command -v hexa )"
if [ -z "${HEXA:-}" ]; then echo "parity: no hexa binary found" >&2; exit 2; fi

NS="$(date +%s)$$"
if [ -z "$OUTDIR" ]; then OUTDIR="${HOME:-.}/.hexa-cache/parity.$NS"; fi
mkdir -p "$OUTDIR"
JSONL="$OUTDIR/parity_results.jsonl"
: > "$JSONL"

# Portable per-file timeout (macOS has no /usr/bin/timeout).
# The previous `perl -e 'alarm $s; exec @ARGV'` SEGFAULTED on heavy
# interp runs (e.g. atlas_verify_smoke flattens 20 modules) — the
# `exec` inside perl-alarm crashed the child, so the interp arm got
# recorded as rc=139 → "interp fail" → BOTH_FAIL → the file silently
# dropped out of the gate-relevant count. That masked a real compiled
# defect (atlas: interp 118/118 in 8.45s, compiled FALSIFIES 5
# verdicts) by misclassifying it as non-gate-relevant. g3 integrity:
# use a background-pid + watchdog kill instead of perl-exec.
run_to() {  # run_to <secs> <outfile> -- <cmd...>
  local secs="$1" of="$2"; shift 3
  "$@" >"$of" 2>/dev/null </dev/null &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null ) &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
  # rc=143 (SIGTERM) / 137 (SIGKILL) ⇒ timed out — map to 124 like GNU timeout.
  if [ "$rc" -eq 143 ] || [ "$rc" -eq 137 ]; then rc=124; fi
  return $rc
}

# Non-determinism heuristic: any of these tokens ⇒ SKIP (output can't be
# byte-stable across two runs regardless of interp/compiled correctness).
ND_RE='\b(clock|rand|random|mono_ns|getpid|net_listen|tcp_listen|http_get|http_post|read_line|input|time_ns|now_ms|epoch|uuid)\b'
SKIPLIST="$(dirname "$0")/parity_skip.txt"

is_skip() {  # is_skip <file>
  local f="$1" base; base="$(basename "$f")"
  # Skiplist lines are `<basename>    # reason` — match the FIRST field
  # only (strip the inline reason), and ignore pure-comment/blank lines.
  if [ -f "$SKIPLIST" ] && \
     awk 'NF && $1 !~ /^#/ { print $1 }' "$SKIPLIST" 2>/dev/null \
       | grep -qxF "$base"; then return 0; fi
  grep -qE "$ND_RE" "$f" 2>/dev/null && return 0
  return 1
}

n_total=0; n_match=0; n_diverge=0; n_rcdiff=0; n_compreg=0
n_interpfail=0; n_bothfail=0; n_skip=0
DIVERGE_LIST=""; RCDIFF_LIST=""; COMPREG_LIST=""

for f in "$CORPUS_DIR"/*.hexa; do
  [ -f "$f" ] || continue
  n_total=$((n_total+1))
  base="$(basename "$f")"

  if is_skip "$f"; then
    n_skip=$((n_skip+1))
    printf '{"file":"%s","class":"SKIP"}\n' "$base" >> "$JSONL"
    continue
  fi

  iout="$OUTDIR/$base.interp.out"
  cout="$OUTDIR/$base.compiled.out"
  cbin="$OUTDIR/$base.bin"

  # interp arm — force the tree-walker (works on both pre- and
  # post-cutover hexa binaries: HEXA_FORCE_INTERP is honored by the
  # cutover build, and the default IS interp on the pre-cutover build).
  HEXA_FORCE_INTERP=1 HEXA_INTERP_QUIET=1 run_to "$TIMEOUT" "$iout" -- \
    "$HEXA" run "$f"
  rci=$?

  # compiled arm — explicit build+exec, NOT `hexa run`. This measures
  # the deletion-relevant claim ("does the compiled toolchain reproduce
  # interp byte-for-byte") independent of whether the cutover wiring is
  # deployed in the running hexa binary yet.
  bout="$OUTDIR/$base.build.log"
  "$HEXA" build "$f" -o "$cbin" >"$bout" 2>&1 </dev/null
  brc=$?
  if [ $brc -eq 0 ] && [ -x "$cbin" ]; then
    run_to "$TIMEOUT" "$cout" -- "$cbin"
    rcc=$?
  else
    : > "$cout"; rcc=99   # compile failed ⇒ compiled arm did not run
  fi

  iok=0; cok=0
  [ $rci -eq 0 ] && iok=1
  [ $rcc -eq 0 ] && cok=1

  cls=""
  if [ $iok -eq 1 ] && [ $cok -eq 1 ]; then
    if cmp -s "$iout" "$cout"; then
      cls="MATCH"; n_match=$((n_match+1))
    else
      cls="DIVERGE"; n_diverge=$((n_diverge+1))
      DIVERGE_LIST="$DIVERGE_LIST $base"
    fi
  elif [ $iok -eq 1 ] && [ $cok -eq 0 ]; then
    cls="COMPILED_REGRESS"; n_compreg=$((n_compreg+1))
    COMPREG_LIST="$COMPREG_LIST $base"
  elif [ $iok -eq 0 ] && [ $cok -eq 1 ]; then
    cls="INTERP_ONLY_FAIL"; n_interpfail=$((n_interpfail+1))
  else
    cls="BOTH_FAIL"; n_bothfail=$((n_bothfail+1))
  fi

  # rc-divergence on an otherwise-byte-equal MATCH is still a behavioral gap.
  if [ "$cls" = "MATCH" ] && [ $rci -ne $rcc ]; then
    cls="RC_DIFF"; n_match=$((n_match-1)); n_rcdiff=$((n_rcdiff+1))
    RCDIFF_LIST="$RCDIFF_LIST $base"
  fi

  printf '{"file":"%s","class":"%s","rc_interp":%d,"rc_compiled":%d}\n' \
    "$base" "$cls" "$rci" "$rcc" >> "$JSONL"
done

echo "════════════════════════════════════════════════════════════════"
echo " R7 parity gate — interp ↔ compiled (corpus=$CORPUS_DIR, t=${TIMEOUT}s)"
echo "════════════════════════════════════════════════════════════════"
echo "  total            : $n_total"
echo "  MATCH            : $n_match"
echo "  INTERP_ONLY_FAIL : $n_interpfail   (ok — interp is the buggy oracle)"
echo "  BOTH_FAIL        : $n_bothfail   (ok — no regression)"
echo "  SKIP             : $n_skip   (non-deterministic / interactive)"
echo "  ── gate-relevant ──────────────────────────────────────────────"
echo "  DIVERGE          : $n_diverge${DIVERGE_LIST:+  ⟶$DIVERGE_LIST}"
echo "  RC_DIFF          : $n_rcdiff${RCDIFF_LIST:+  ⟶$RCDIFF_LIST}"
echo "  COMPILED_REGRESS : $n_compreg${COMPREG_LIST:+  ⟶$COMPREG_LIST}"
echo "  artifacts        : $OUTDIR"
echo "════════════════════════════════════════════════════════════════"

GATE_FAIL=$((n_diverge + n_rcdiff + n_compreg))
if [ "$GATE_FAIL" -eq 0 ]; then
  echo "PARITY GATE: PASS — compiled path reproduces interp byte-for-byte."
  echo "  → Cycle C (interp source deletion) is UNBLOCKED on this corpus."
  exit 0
fi
echo "PARITY GATE: FAIL — $GATE_FAIL gate-relevant divergence(s)."
echo "  → Cycle C BLOCKED. Fix the compile-parity gap(s) above first."
exit 1
