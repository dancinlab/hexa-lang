#!/usr/bin/env bash
# L4 RUNG-1 — array elem-type inference: byteeq(OFF) + k3_arrmap perf + ceiling control.
set -u
W=$HOME/l4r1
R=$HOME/l4r1_RESULT.txt
AP_MAIN=$W/aprime_main
AP_INF=$W/aprime_infer
SRC=${SRC:-$HOME/hexa-lang}
RT=${RT:-$HOME/l4r1/runtime.a}
K=$W/k; mkdir -p "$K"
say(){ echo "$@" | tee -a "$R"; }
die(){ say "FATAL: $*"; exit 3; }
: > "$R"
say "=== L4 RUNG-1 RESULT — $(date -u +%FT%TZ) — $(hostname) ==="
for f in "$AP_MAIN" "$AP_INF" "$RT"; do [ -s "$f" ] || die "missing artifact $f"; done
say "  aprime_main=$(stat -c%s $AP_MAIN)B  aprime_infer=$(stat -c%s $AP_INF)B  runtime.a=$(stat -c%s $RT)B"
say "  gcc: $(gcc --version | head -1)"

# quiesce
for w in $(seq 1 40); do
  L=$(awk '{print $1}' /proc/loadavg); Li=${L%.*}
  [ "${Li:-99}" -lt 3 ] && { say "  load=$L OK"; break; }
  sleep 30
done

# ── kernels ──
cat > "$K/k3_arrmap.hexa" <<'EOF'
fn main() {
    let M = 1000000007
    let N = 100000
    let P = 2000
    let mut a = []
    for i in 0..N {
        a.push(i)
    }
    for p in 0..P {
        for i in 0..N {
            a[i] = (a[i] * 2 + 1) % M
        }
    }
    let mut s = 0
    for i in 0..N {
        s = (s + a[i]) % M
    }
    println(s)
}
EOF
# CEILING CONTROL — identical body, element type ANNOTATED. This is the state the
# discriminative experiment measured at 5.25x vs gcc; inference should reach it.
sed 's/let mut a = \[\]/let mut a: [i64] = []/' "$K/k3_arrmap.hexa" > "$K/k3_annot.hexa"
grep -q 'a: \[i64\]' "$K/k3_annot.hexa" || die "ceiling-control sed did not apply"
cat > "$K/k3_arrmap.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    long long M = 1000000007, N = 100000, P = 2000;
    long long *a = malloc(sizeof(long long) * N);
    for (long long i = 0; i < N; i++) a[i] = i;
    for (long long p = 0; p < P; p++)
        for (long long i = 0; i < N; i++) a[i] = (a[i] * 2 + 1) % M;
    long long s = 0;
    for (long long i = 0; i < N; i++) s = (s + a[i]) % M;
    printf("%lld\n", s);
    return 0;
}
EOF

med5(){ local b="$1" vals=() t
  for r in 1 2 3 4 5; do
    t=$( { /usr/bin/time -v taskset -c 3 "$b" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s+0}' )
    vals+=("$t")
  done
  printf '%s\n' "${vals[@]}" | sort -n | sed -n '3p'
}

# build+run one (binary, env, src) → sets OUT/MED/CALLS
build_run(){ # $1=tag $2=aprime $3=src.hexa $4=env-assignments
  local tag="$1"
  local ap="$2"
  local src="$3"
  local envs="$4"
  local base="$W/$tag"
  ( cd "$K" && env $envs "$ap" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$base.s" "$src" ) >"$base.s.log" 2>&1
  ( cd "$K" && env $envs "$ap" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$base.o" "$src" ) >"$base.o.log" 2>&1
  [ -s "$base.o" ] || { say "    [$tag] EMIT-FAIL"; tail -5 "$base.o.log" | sed 's/^/        /' | tee -a "$R"; return 1; }
  gcc -O2 -nostartfiles "$base.o" "$RT" -lm -o "$base.bin" 2>"$base.ld.log"
  [ -s "$base.bin" ] || { say "    [$tag] LINK-FAIL"; tail -5 "$base.ld.log" | sed 's/^/        /' | tee -a "$R"; return 1; }
  T_OUT=$("$base.bin" 2>/dev/null)
  T_MED=$(med5 "$base.bin")
  T_CALLS=$(grep -cE '\bcall\b.*hexa_(add|sub|mul|div|mod|cmp|eq|truthy|index_get|index_set)' "$base.s" 2>/dev/null || echo 0)
  return 0
}

# ── 1. gcc -O2 reference ──
say ""
say "--- gcc -O2 reference ---"
gcc -O2 "$K/k3_arrmap.c" -o "$K/k3.gcc" || die "gcc build"
GOUT=$("$K/k3.gcc"); GMED=$(med5 "$K/k3.gcc")
say "  [gcc -O2] out=$GOUT median_cpu_s=$GMED"

# ── 2. the 3 hexa configs ──
say ""
say "--- k3_arrmap: idiomatic (let mut a = []) + ceiling control (annotated) ---"
declare -A M_MED M_OUT M_CALLS
run_cfg(){ # $1=label $2=aprime $3=src $4=envs
  if build_run "$1" "$2" "$3" "$4"; then
    M_MED[$1]=$T_MED; M_OUT[$1]=$T_OUT; M_CALLS[$1]=$T_CALLS
    local p=FAIL; [ "$T_OUT" = "$GOUT" ] && p=OK
    local r=$(awk -v a="$T_MED" -v b="$GMED" 'BEGIN{if(b>0)printf "%.2f",a/b; else print "NA"}')
    say "  [$1] out=$T_OUT cpu=${T_MED}s vs_gcc=${r}x boxedcalls=$T_CALLS parity=$p"
  else
    M_MED[$1]=NA; M_OUT[$1]=FAIL; M_CALLS[$1]=NA
  fi
}
run_cfg INFER_OFF "$AP_INF" "$K/k3_arrmap.hexa" ""
run_cfg INFER_ON  "$AP_INF" "$K/k3_arrmap.hexa" "HEXA_ARRAY_ELEM_INFER=1"
run_cfg ANNOTATED "$AP_INF" "$K/k3_annot.hexa"  ""

# ── 3. inference census (does it actually fire, and on what) ──
say ""
say "--- inference census (HEXA_ARRAY_ELEM_INFER_DEBUG=1) ---"
( cd "$K" && env HEXA_ARRAY_ELEM_INFER=1 HEXA_ARRAY_ELEM_INFER_DEBUG=1 "$AP_INF" _drv.hexa \
    --emit=asm --target=x86_64-linux-gnu -o /dev/null "$K/k3_arrmap.hexa" ) 2>&1 | grep '\[aei\]' | sed 's/^/  /' | tee -a "$R"
say "  (OFF-path census — must be EMPTY:)"
CENS_OFF=$( ( cd "$K" && env HEXA_ARRAY_ELEM_INFER_DEBUG=1 "$AP_INF" _drv.hexa \
    --emit=asm --target=x86_64-linux-gnu -o /dev/null "$K/k3_arrmap.hexa" ) 2>&1 | grep -c '\[aei\]' || true )
say "  OFF-path [aei] lines = $CENS_OFF  (expect 0 — the prepass must not run when the flag is unset)"

# ── 4. BYTEEQ of the DEFAULT (flag-unset) path: aprime_main vs aprime_infer ──
say ""
say "--- byteeq: default path (HEXA_ARRAY_ELEM_INFER unset) — aprime_main vs aprime_infer ---"
CORPUS=$(ls "$SRC"/stdlib/*.hexa "$SRC"/stdlib/**/*.hexa 2>/dev/null | head -40)
CORPUS="$CORPUS $K/k3_arrmap.hexa $K/k3_annot.hexa"
NEQ=0; NDIFF=0; NSKIP=0
for f in $CORPUS; do
  b=$(basename "$f" .hexa)
  ( cd "$K" && "$AP_MAIN" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$W/be_main.s" "$f" ) >/dev/null 2>&1
  ( cd "$K" && "$AP_INF"  _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$W/be_inf.s"  "$f" ) >/dev/null 2>&1
  if [ ! -s "$W/be_main.s" ] || [ ! -s "$W/be_inf.s" ]; then NSKIP=$((NSKIP+1)); continue; fi
  if cmp -s "$W/be_main.s" "$W/be_inf.s"; then NEQ=$((NEQ+1)); else NDIFF=$((NDIFF+1)); say "  BYTE-DIFF: $b"; fi
done
say "  byteeq corpus: identical=$NEQ  DIFFERENT=$NDIFF  skipped(no-emit both)=$NSKIP"
[ "$NDIFF" = 0 ] && say "  ✅ DEFAULT PATH BYTE-IDENTICAL to origin/main" || say "  ❌ DEFAULT PATH DIVERGED — release-integrity violation"

# ── 5. ★ DISCRIMINATION (lesson: a gate must go RED on the known-slow state) ──
say ""
say "=== ★ DISCRIMINATION — known-slow control = INFER_OFF (today's shipped state) ==="
ON=${M_MED[INFER_ON]}; OFF=${M_MED[INFER_OFF]}; AN=${M_MED[ANNOTATED]}
if [ "$ON" = NA ] || [ "$OFF" = NA ]; then
  say "  INSTRUMENT-BLIND: a median is NA — run INVALID"
elif awk -v on="$ON" -v off="$OFF" 'BEGIN{exit !(off > on*1.20)}'; then
  say "  RED-ON-KNOWN-SLOW = PROVEN: INFER_OFF=${OFF}s is >=1.2x slower than INFER_ON=${ON}s"
  say "  speedup from inference = $(awk -v on="$ON" -v off="$OFF" 'BEGIN{printf "%.2fx",off/on}')"
else
  say "  ⚠⚠ INSTRUMENT-BLIND / NO EFFECT: INFER_OFF=${OFF}s vs INFER_ON=${ON}s — inference did not fire"
fi
say ""
say "  vs-gcc  INFER_OFF  = $(awk -v a="$OFF" -v b="$GMED" 'BEGIN{if(a=="NA"||b<=0){print "NA"}else printf "%.2fx",a/b}')   (today's shipped idiomatic path)"
say "  vs-gcc  INFER_ON   = $(awk -v a="$ON"  -v b="$GMED" 'BEGIN{if(a=="NA"||b<=0){print "NA"}else printf "%.2fx",a/b}')   (this change)"
say "  vs-gcc  ANNOTATED  = $(awk -v a="$AN"  -v b="$GMED" 'BEGIN{if(a=="NA"||b<=0){print "NA"}else printf "%.2fx",a/b}')   (CEILING — the hand-annotated upper bound)"
say ""
say "=== DONE $(date -u +%FT%TZ) ==="
