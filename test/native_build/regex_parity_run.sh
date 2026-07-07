#!/usr/bin/env bash
# test/native_build/regex_parity_run.sh — zero-c #29 regex OFF(libc)-vs-ON(native NFA)
# parity gate. POOL ONLY (aiden/summer/ghost — NOT mini: needs a full hexa build).
#
# Pipeline (mirrors the strtod-tail oracle recipe):
#   0) libc step-0 probe (per-host truth: D3 backref, lookaround, \d\w\s, {n,m}, icase-range)
#   1) oracle  -> corpus.txt + golden.txt  (golden IS the verbatim OFF-body port)
#   2) driver built OFF (HEXA_REGEX_NATIVE=0) -> off_ledger  (must == golden: fidelity check)
#   3) driver built ON  (native seed present) -> on_ledger
#   4) diff on vs off; any diff whose TAG is NOT an allowlisted D-class = PARITY FAIL;
#      gate 3c: every allowlisted D-class MUST actually appear in the diff (stale-allowlist RED).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WT="${WT:-$(git -C "$HERE" rev-parse --show-toplevel)}"
cd "$WT"
ALLOW="$HERE/regex_intentional_divergence.txt"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
CC="${CC:-cc}"
HEXA="${HEXA:-hexa}"

case "$(hostname)" in
  *mini*) echo "REFUSE: mini is git/gh only — run this on aiden/summer/ghost"; exit 2 ;;
esac
command -v "$HEXA" >/dev/null || { echo "REFUSE: no hexa binary on PATH (pool build host required)"; exit 2; }

# ── 0) libc step-0 probe (informational per-host truth; sets D3 expectation) ──
cat > "$WORK/probe.c" <<'PROBE'
#include <stdio.h>
#include <regex.h>
static int ok(const char*p,int fl){regex_t r;int c=regcomp(&r,p,fl);if(c==0)regfree(&r);return c==0;}
static int mtc(const char*p,const char*s){regex_t r;if(regcomp(&r,p,REG_EXTENDED))return -1;int m=regexec(&r,s,0,0,0)==0;regfree(&r);return m;}
int main(void){
  printf("backref_compile=%d\n", ok("(a)\\1", REG_EXTENDED));       /* D3: glibc=1 accepts, bsd=0 */
  printf("backref_match_aa=%d\n", mtc("(a)\\1","aa"));
  printf("lookahead_reject=%d\n", !ok("(?=a)", REG_EXTENDED));      /* C9: expect 1 (rejected) */
  printf("bsd_d_is_literal=%d\n", mtc("\\d","d"));                  /* C7: ERE \\d=literal 'd' -> 1 */
  printf("interval_alt_longest=%d\n", mtc("^(a|ab){1,2}$","aab"));  /* D1: POSIX-longest -> 1 */
  printf("icase_range_block=%d\n", ({regex_t r; int m=-1; if(!regcomp(&r,"[;-Z]",REG_EXTENDED|REG_ICASE)){m=regexec(&r,"^",0,0,0)==0;regfree(&r);} m;}));
  printf("empty_pat_ok=%d\n", ok("", REG_EXTENDED));                /* excluded from corpus */
  return 0;
}
PROBE
echo "== step-0 libc probe ($(hostname)) =="
"$CC" -O2 "$WORK/probe.c" -o "$WORK/probe" && "$WORK/probe" | tee "$WORK/probe.txt"
BACKREF_OK=$(grep '^backref_compile=' "$WORK/probe.txt" | cut -d= -f2)
echo "   -> D3 backref acceptance on this host = $BACKREF_OK (1=glibc diverges, 0=bsd agrees)"

# ── 1) oracle -> corpus.txt + golden.txt ──
"$CC" -O2 "$HERE/regex_parity_oracle.c" -o "$WORK/oracle"
"$WORK/oracle" "$WORK/corpus.txt" "$WORK/golden.txt"

build_ledger() {  # $1 = ON|OFF -> echoes ledger path
  local mode="$1" out="$WORK/ledger_$1.txt" bin="$WORK/driver_$1"
  rm -rf "$HOME/.hexa-cache" 2>/dev/null || true
  if [ "$mode" = OFF ]; then
    HEXA_REGEX_NATIVE=0 "$HEXA" build "$HERE/regex_parity_corpus.hexa" -o "$bin" >&2
  else
    # native default-ON: the resolver assembles the frozen git-tracked seed itself
    # (stage_resolve_runtime_a: seed map + 6-symbol contract + assemble). Fail loud if
    # the native seed is not present (a stale-seed OFF-fallback would silently pass).
    "$HEXA" build "$HERE/regex_parity_corpus.hexa" -o "$bin" 2> "$WORK/on_build.log" || { cat "$WORK/on_build.log" >&2; exit 1; }
    if ! grep -qE 'HEXA_REGEX_NATIVE=1|regex_rt_native\.o' "$WORK/on_build.log"; then
      echo "WARN: ON build did not report native regex seed assembly — verify HEXA_REGEX_NATIVE seed present" >&2
    fi
  fi
  REGEX_CORPUS="$WORK/corpus.txt" "$bin" > "$out"
  echo "$out"
}

OFF_LEDGER="$(build_ledger OFF)"
ON_LEDGER="$(build_ledger ON)"

# ── 2) fidelity: golden (oracle port) must equal the real OFF runtime ledger ──
if ! diff -u "$WORK/golden.txt" "$OFF_LEDGER" > "$WORK/fidelity.diff"; then
  echo "FAIL: oracle golden != OFF runtime ledger (the C port drifted from the OFF bodies):"
  head -40 "$WORK/fidelity.diff"
  exit 1
fi
echo "PASS: oracle golden == OFF runtime ledger (verbatim-port fidelity)"

# ── 3) ON vs OFF; classify diffs by TAG ──
paste "$OFF_LEDGER" "$ON_LEDGER" > "$WORK/paired.txt" || true
FAIL=0
declare -A D_SEEN
: > "$WORK/unexpected.txt"
# a diff row = off_result != on_result for the same IDX
diff <(cut -f1-4 "$OFF_LEDGER") <(cut -f1-4 "$ON_LEDGER") > "$WORK/onoff.diff" || true
# extract the TAG of each differing row (column 2) from the OFF side
awk -F'\t' 'NR==FNR{off[$1]=$4; tag[$1]=$2; next}{ if($1 in off && off[$1]!=$4){ print $2 } }' \
    "$OFF_LEDGER" "$ON_LEDGER" | sort > "$WORK/diff_tags.txt"

while read -r tag; do
  [ -z "$tag" ] && continue
  case "$tag" in
    D1|D2|D3) D_SEEN[$tag]=1 ;;
    *) echo "$tag" >> "$WORK/unexpected.txt"; FAIL=1 ;;
  esac
done < "$WORK/diff_tags.txt"

echo "== parity classification =="
if [ "$FAIL" = 1 ]; then
  echo "FAIL: ON!=OFF on non-allowlisted (C-class) rows:"
  sort "$WORK/unexpected.txt" | uniq -c
fi

# gate 3c: every allowlisted D-class must ACTUALLY diverge (else stale allowlist = RED).
# D3 is per-host: only required to diverge where the step-0 probe says backref is accepted.
for D in D1 D2; do
  if [ -z "${D_SEEN[$D]:-}" ]; then echo "FAIL(3c): allowlisted $D never diverged (stale allowlist)"; FAIL=1; fi
done
if [ "$BACKREF_OK" = 1 ]; then
  if [ -z "${D_SEEN[D3]:-}" ]; then echo "FAIL(3c): host accepts backref but D3 never diverged"; FAIL=1; fi
else
  echo "note: host rejects backref (bsd/darwin) — D3 agrees on both sides (accounted)"
fi

[ "$FAIL" = 0 ] && echo "GATE GREEN: C-classes parity-clean; D-classes {${!D_SEEN[*]}} diverge as allowlisted"
exit "$FAIL"
