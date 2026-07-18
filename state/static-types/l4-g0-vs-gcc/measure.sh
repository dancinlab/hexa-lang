#!/usr/bin/env bash
# state/static-types/l4-g0-vs-gcc/measure.sh — L4 G0: RE-BASELINE hexa vs gcc -O2.
#
# WHY: the only end-to-end investment map (state/codegen-quality-probe-verdict.md,
# geomean 8.6x vs gcc -O2, re-baseline 10.9x) predates ALL FOUR unbox levers, which
# are now default-ON. The map is stale. This re-measures the SAME 5 kernels with the
# CURRENT compiler and separates each lever's individual contribution.
#
# RUN DETACHED ON POOL (summer). Self-harvests to $HOME/l4_g0_RESULT.txt.
#
# ── INSTRUMENT DISCRIMINATION (lesson #7: a gate must go RED on a known-bad state) ──
# The ALLOFF config (all 4 levers OFF) IS the pre-lever codegen — i.e. the exact state
# that measured 8.6x. It is the harness's built-in KNOWN-SLOW control:
#   * if ALLOFF does NOT measure materially slower than ALLON, the instrument is BLIND
#     (stale aprime_cc / flags not read / wrong backend) → harness prints INSTRUMENT-BLIND
#     and the whole run is INVALID. A perf harness that cannot see the pre-lever build is
#     a lying gate.
#   * ALLOFF must also reproduce the historical ~8.6-10.9x band vs gcc. If it does not,
#     the reconstruction of the kernels is off and the delta is not comparable.
# ── ARTIFACT GATE (lesson #1: rc==0 is not success) ──
# every build step requires rc==0 AND the artifact to exist AND be non-empty, else FATAL.
# ── STALE GATE (lesson #3) ──
# aprime_cc mtime must be NEWER than the newest compiler/**.hexa source, else FATAL.
set -u
RESULT="$HOME/l4_g0_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"
WORK="${WORK:-$HOME/l4_g0}"
say() { echo "$@" | tee -a "$RESULT"; }
die() { say "FATAL: $*"; say "=== ABORTED $(date -u +%FT%TZ) ==="; exit 3; }

: > "$RESULT"
say "=== L4 G0 vs-gcc RE-BASELINE — $(date -u +%FT%TZ) — $(hostname) ==="
say "  gcc: $(gcc --version | head -1)"

# ── 0. quiesce ──
for w in $(seq 1 60); do
    L=$(awk '{print $1}' /proc/loadavg); Li=${L%.*}
    [ "${Li:-99}" -lt 3 ] && { say "  load=$L OK"; break; }
    [ "$w" = 60 ] && say "  ⚠ load stayed high (last=$L) — proceeding (30min cap)"
    sleep 30
done

# REUSE=1 keeps an already-built, already-stale-gated aprime_cc + worktree from a
# previous run of THIS script (the build is ~10min). The stale-gate below still runs
# on it, so a stale binary is still FATAL — reuse never bypasses the gate.
REUSE="${REUSE:-0}"
if [ "$REUSE" = 1 ] && [ -s "$WORK/aprime_cc" ]; then
    say "  REUSE=1 — keeping existing $WORK/aprime_cc (stale-gate still enforced below)"
else
    rm -rf "$WORK"
fi
mkdir -p "$WORK"
SRC="$WORK/src"
if [ ! -d "$SRC/.git" ] && [ ! -f "$SRC/.git" ]; then
    git -C "$CANON" worktree prune 2>/dev/null || true
    git -C "$CANON" fetch -f origin "main:refs/remotes/origin/main" >>"$WORK/git.log" 2>&1 || say "  (fetch warn)"
    git -C "$CANON" worktree add -f --detach "$SRC" origin/main >>"$WORK/git.log" 2>&1 \
        || git clone "$CANON" "$SRC" >>"$WORK/git.log" 2>&1 || die "no src worktree"
fi
say "  SRC sha=$(git -C "$SRC" rev-parse --short HEAD)"

# ── WARM-TREE SEEDING (measured root-cause, not a guess) ─────────────────────
# A clean worktree makes build_aprime take the "[0/5] regen from SSOT" path, which
# restores the FROZEN bootstrap hexat (151c52c8). MEASURED: that frozen hexat CANNOT
# transpile current main's compiler source — it dies `index 7 out of bounds (len 2)`
# during stage-2 transpile, on BOTH a fresh worktree AND the canon checkout. Every
# working build host therefore carries a SELF-HOSTED hexat. We seed one here.
# Validity: build_aprime's own staleness rule is "hexat is stale iff any self/ or
# compiler/lex .hexa is newer". `git log --since=2026-07-12 -- compiler/lex` = EMPTY,
# so this hexat still lexes current source; it is the same warm-tree seed the other
# L4 measurements (l4_broadbench, l4_calltype) were taken with.
GOOD_HEXAT="${GOOD_HEXAT:-$HOME/good_hexat}"
for f in self/runtime.c self/native/hexa_cc.c; do
    [ -e "$CANON/$f" ] && [ ! -e "$SRC/$f" ] && { mkdir -p "$SRC/$(dirname "$f")"; cp "$CANON/$f" "$SRC/$f"; }
done
[ -d "$CANON/self/native" ] && cp -rn "$CANON/self/native/." "$SRC/self/native/" 2>/dev/null || true
mkdir -p "$SRC/build"
[ -s "$GOOD_HEXAT" ] || die "no known-good hexat at $GOOD_HEXAT (frozen seed cannot transpile main)"
cp "$GOOD_HEXAT" "$SRC/build/hexat"; chmod +x "$SRC/build/hexat"
# mtime must be NEWER than every checked-out source, else stage-0 nukes it and
# regens the broken frozen one. touch AFTER the copy.
sleep 1; touch "$SRC/build/hexat" "$SRC/self/runtime.c"
say "  seeded warm-tree hexat: $(stat -c%s "$SRC/build/hexat")B (self-hosted, not frozen)"

# ── 1. FRESH aprime_cc + ARTIFACT + STALE gate (lessons #1 + #3) ──
say ""
AP="$WORK/aprime_cc"
if [ "$REUSE" = 1 ] && [ -s "$AP" ]; then
    say "--- aprime_cc: REUSED from previous run ($(stat -c%s "$AP")B) ---"
else
    say "--- building aprime_cc from origin/main (fresh) ---"
    ( cd "$SRC" && bash tool/build_aprime.sh -o "$AP" -r "$SRC" ) >"$WORK/aprime.log" 2>&1
    RC=$?
    [ -s "$AP" ] || die "aprime_cc MISSING/EMPTY after build (rc=$RC) — see $WORK/aprime.log"
    say "  aprime_cc rc=$RC size=$(stat -c%s "$AP")B"
fi
# STALE gate: binary must be newer than newest compiler source
NEWEST_SRC=$(find "$SRC/compiler" -name '*.hexa' -printf '%T@\n' | sort -rn | head -1 | cut -d. -f1)
AP_MT=$(stat -c %Y "$AP")
say "  stale-gate: aprime_mtime=$AP_MT newest_compiler_src=$NEWEST_SRC"
[ "$AP_MT" -gt "$NEWEST_SRC" ] || die "aprime_cc is STALE (older than compiler sources) — lesson #3"
say "  stale-gate: PASS (aprime_cc is fresh)"

# runtime.a (CPU)
RT=""
for c in "$SRC/build/runtime.a" "$CANON/build/runtime.a.cpubak" "$CANON/build/runtime.a"; do
    [ -s "$c" ] && { RT="$c"; break; }
done
[ -n "$RT" ] || die "no runtime.a"
say "  runtime.a=$RT ($(stat -c%s "$RT")B)"

# ── 2. kernels: the 5 probe kernels (.hexa) + gcc -O2 reference (.c) ──
# k1/k4 are the EXACT sources of record (state/unbox-native-r5/measure_r5b.sh).
# k2/k3/k5 are reconstructed from the verdict's spec + the recorded gcc asm
# (the originals were never committed). BOTH sides are re-measured in this run, so
# every ratio is self-contained; parity vs the C output is gated per kernel.
K="$WORK/k"; mkdir -p "$K"

cat > "$K/k1_sum.hexa" <<'EOF'
fn main() {
    let M = 1000000007
    let mut s = 0
    let N = 200000000
    for i in 0..N {
        s = (s + i * 1009) % M
    }
    println(s)
}
EOF
cat > "$K/k1_sum.c" <<'EOF'
#include <stdio.h>
int main(void) {
    long long M = 1000000007, s = 0, N = 200000000;
    for (long long i = 0; i < N; i++) s = (s + i * 1009) % M;
    printf("%lld\n", s);
    return 0;
}
EOF

cat > "$K/k2_collatz.hexa" <<'EOF'
fn main() {
    let mut total = 0
    let N = 3000000
    for i in 1..N {
        let mut n = i
        let mut steps = 0
        while n != 1 {
            if n % 2 == 0 { n = n / 2 } else { n = 3 * n + 1 }
            steps = steps + 1
        }
        total = total + steps
    }
    println(total)
}
EOF
cat > "$K/k2_collatz.c" <<'EOF'
#include <stdio.h>
int main(void) {
    long long total = 0, N = 3000000;
    for (long long i = 1; i < N; i++) {
        long long n = i, steps = 0;
        while (n != 1) {
            if (n % 2 == 0) n = n / 2; else n = 3 * n + 1;
            steps = steps + 1;
        }
        total = total + steps;
    }
    printf("%lld\n", total);
    return 0;
}
EOF

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

cat > "$K/k4_branch.hexa" <<'EOF'
fn main() {
    let mut acc = 0
    let N = 100000000
    for i in 0..N {
        if i % 3 == 0 { acc = acc + i % 5 } else { acc = acc - i % 5 }
    }
    println(acc)
}
EOF
cat > "$K/k4_branch.c" <<'EOF'
#include <stdio.h>
int main(void) {
    long long acc = 0, N = 100000000;
    for (long long i = 0; i < N; i++) {
        if (i % 3 == 0) acc = acc + i % 5; else acc = acc - i % 5;
    }
    printf("%lld\n", acc);
    return 0;
}
EOF

cat > "$K/k5_fncall.hexa" <<'EOF'
fn f(x) -> int {
    return (x * 1009 + 7) % 1000000007
}
fn main() {
    let M = 1000000007
    let mut s = 0
    let N = 100000000
    for i in 0..N {
        s = (s + f(i)) % M
    }
    println(s)
}
EOF
cat > "$K/k5_fncall.c" <<'EOF'
#include <stdio.h>
static long long f(long long x) { return (x * 1009 + 7) % 1000000007; }
int main(void) {
    long long M = 1000000007, s = 0, N = 100000000;
    for (long long i = 0; i < N; i++) s = (s + f(i)) % M;
    printf("%lld\n", s);
    return 0;
}
EOF

KERNELS="k1_sum k2_collatz k3_arrmap k4_branch k5_fncall"

# ── 3. gcc -O2 reference (artifact-gated) ──
say ""
say "--- gcc -O2 reference build + run ---"
declare -A GCC_MED GCC_OUT
med5() { # $1=binary → median-of-5 CPU (user+sys) seconds
    local b="$1" vals=() t
    for r in 1 2 3 4 5; do
        t=$( { /usr/bin/time -v taskset -c 3 "$b" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s+0}' )
        vals+=("$t")
    done
    printf '%s\n' "${vals[@]}" | sort -n | sed -n '3p'
}
for kn in $KERNELS; do
    gcc -O2 "$K/$kn.c" -o "$K/$kn.gcc" 2>"$K/$kn.gcc.log" || die "gcc build $kn"
    [ -s "$K/$kn.gcc" ] || die "gcc artifact missing $kn"
    GCC_OUT[$kn]=$("$K/$kn.gcc")
    GCC_MED[$kn]=$(med5 "$K/$kn.gcc")
    say "  [$kn] gcc -O2: out=${GCC_OUT[$kn]} median_cpu_s=${GCC_MED[$kn]}"
done

# ── 4. hexa configs: ALLON (shipped default) · ALLOFF (pre-lever control) · 4x single-OFF ──
# lever env vars (all default-ON, read as `!= "0"`):
#   HEXA_UNBOX_NATIVE        compiler/codegen/x86_64_linux.hexa:1603
#   HEXA_UNBOX_ARRAY_NATIVE  compiler/codegen/x86_64_linux.hexa:1722
#   HEXA_PACK_ARRAY          compiler/codegen/x86_64_linux.hexa:1762
#   HEXA_UNBOX_HIR_CALLTYPE  compiler/lower/ast_to_hir.hexa:144
CFGS="ALLON ALLOFF noUNBOX noARRAY noPACK noCALLTYPE"
cfg_env() { # echo the env assignments for a config
    case "$1" in
        ALLON)      echo "";;
        ALLOFF)     echo "HEXA_UNBOX_NATIVE=0 HEXA_UNBOX_ARRAY_NATIVE=0 HEXA_PACK_ARRAY=0 HEXA_UNBOX_HIR_CALLTYPE=0";;
        noUNBOX)    echo "HEXA_UNBOX_NATIVE=0";;
        noARRAY)    echo "HEXA_UNBOX_ARRAY_NATIVE=0";;
        noPACK)     echo "HEXA_PACK_ARRAY=0";;
        noCALLTYPE) echo "HEXA_UNBOX_HIR_CALLTYPE=0";;
    esac
}

declare -A HX_MED HX_OUT HX_CALLS
say ""
say "--- hexa native-emit: 6 configs x 5 kernels ---"
for cfg in $CFGS; do
    ENVS=$(cfg_env "$cfg")
    say "  == config $cfg  [${ENVS:-<shipped defaults>}] =="
    for kn in $KERNELS; do
        base="$WORK/${kn}_${cfg}"
        # aprime_cc argv: <drv-slot> <flags> SOURCE  — argv[1] is a consumed slot and
        # the SOURCE must be the LAST positional. Passing the kernel as argv[1] makes it
        # die `missing SOURCE.hexa` (measured). Mirrors state/static-types/
        # unbox-broadbench-r1/measure.sh:140.
        ( cd "$K" && env $ENVS "$AP" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$base.s" "$K/$kn.hexa" ) >"$base.s.log" 2>&1
        ( cd "$K" && env $ENVS "$AP" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$base.o" "$K/$kn.hexa" ) >"$base.o.log" 2>&1
        # ARTIFACT gate (lesson #1): rc alone is a liar; require the .o to exist non-empty
        if [ ! -s "$base.o" ]; then
            say "    [$kn] EMIT-FAIL (no .o artifact) — see $base.o.log"
            tail -5 "$base.o.log" | sed 's/^/        /' | tee -a "$RESULT"
            HX_MED[$kn/$cfg]=NA; HX_OUT[$kn/$cfg]=EMITFAIL; HX_CALLS[$kn/$cfg]=NA
            continue
        fi
        gcc -O2 -nostartfiles "$base.o" "$RT" -lm -o "$base.bin" 2>"$base.ld.log"
        if [ ! -s "$base.bin" ]; then
            say "    [$kn] LINK-FAIL"; tail -5 "$base.ld.log" | sed 's/^/        /' | tee -a "$RESULT"
            HX_MED[$kn/$cfg]=NA; HX_OUT[$kn/$cfg]=LINKFAIL; HX_CALLS[$kn/$cfg]=NA
            continue
        fi
        # boxed-call census on the real native asm
        c=$(grep -cE '\bcall\b.*hexa_(add|sub|mul|div|mod|cmp|eq|truthy|index_get|index_set)' "$base.s" 2>/dev/null || echo 0)
        HX_CALLS[$kn/$cfg]=$c
        HX_OUT[$kn/$cfg]=$("$base.bin" 2>/dev/null)
        HX_MED[$kn/$cfg]=$(med5 "$base.bin")
        p=FAIL; [ "${HX_OUT[$kn/$cfg]}" = "${GCC_OUT[$kn]}" ] && p=OK
        r=$(awk -v a="${HX_MED[$kn/$cfg]}" -v b="${GCC_MED[$kn]}" 'BEGIN{if(b>0)printf "%.2f",a/b; else print "NA"}')
        say "    [$kn] out=${HX_OUT[$kn/$cfg]} cpu=${HX_MED[$kn/$cfg]}s vs_gcc=${r}x boxedcalls=$c parity=$p"
    done
done

# ── 5. SUMMARY: geomean vs gcc per config + per-lever delta ──
geo_of() { # $1=cfg → geomean ratio vs gcc over kernels with a valid median
    local cfg="$1" prod=1 n=0 r
    for kn in $KERNELS; do
        m="${HX_MED[$kn/$cfg]}"
        [ "$m" = NA ] && continue
        r=$(awk -v a="$m" -v b="${GCC_MED[$kn]}" 'BEGIN{if(b>0)printf "%.6f",a/b; else print 0}')
        awk -v x="$r" 'BEGIN{exit !(x+0>0)}' || continue
        prod=$(awk -v p="$prod" -v x="$r" 'BEGIN{printf "%.8f",p*x}'); n=$((n+1))
    done
    awk -v p="$prod" -v n="$n" 'BEGIN{if(n>0)printf "%.2f",exp(log(p)/n); else print "NA"}'
}
say ""
say "=== SUMMARY — ratio vs gcc -O2 (lower = closer to gcc) ==="
say "$(printf '%-12s %8s %8s %8s %8s %8s %8s %8s' KERNEL gcc_s ALLON ALLOFF noUNBOX noARRAY noPACK noCALLTYPE)"
for kn in $KERNELS; do
    line=$(printf '%-12s %8s' "$kn" "${GCC_MED[$kn]}")
    for cfg in $CFGS; do
        m="${HX_MED[$kn/$cfg]}"
        if [ "$m" = NA ]; then line="$line $(printf '%8s' NA)"
        else line="$line $(printf '%8s' "$(awk -v a="$m" -v b="${GCC_MED[$kn]}" 'BEGIN{printf "%.2fx",a/b}')")"; fi
    done
    say "$line"
done
say ""
for cfg in $CFGS; do say "  geomean vs gcc [$cfg] = $(geo_of "$cfg")x"; done
GEO_ON=$(geo_of ALLON); GEO_OFF=$(geo_of ALLOFF)

say ""
say "=== boxed-call census (whole-fn `call hexa_{add,sub,mul,div,mod,cmp,eq,truthy,index_*}`) ==="
say "$(printf '%-12s %8s %8s %8s %8s %8s %8s' KERNEL ALLON ALLOFF noUNBOX noARRAY noPACK noCALLTYPE)"
for kn in $KERNELS; do
    line=$(printf '%-12s' "$kn")
    for cfg in $CFGS; do line="$line $(printf '%8s' "${HX_CALLS[$kn/$cfg]}")"; done
    say "$line"
done

# ── 6. ★ INSTRUMENT DISCRIMINATION PROOF (lesson #7) ──
say ""
say "=== ★ INSTRUMENT DISCRIMINATION (known-slow control = ALLOFF = the pre-lever codegen) ==="
if [ "$GEO_ON" = NA ] || [ "$GEO_OFF" = NA ]; then
    say "  INSTRUMENT-BLIND: a geomean is NA — run INVALID"
elif awk -v on="$GEO_ON" -v off="$GEO_OFF" 'BEGIN{exit !(off > on*1.20)}'; then
    say "  RED-ON-KNOWN-SLOW = PROVEN: ALLOFF=${GEO_OFF}x is >=1.2x WORSE than ALLON=${GEO_ON}x."
    say "  → the harness SEES the pre-lever codegen as slow. It is not blind. Numbers are trustworthy."
    say "  speedup delivered by the 4 levers (geomean) = $(awk -v on="$GEO_ON" -v off="$GEO_OFF" 'BEGIN{printf "%.2fx",off/on}')"
else
    say "  ⚠⚠ INSTRUMENT-BLIND: ALLOFF=${GEO_OFF}x is NOT materially worse than ALLON=${GEO_ON}x."
    say "  → either aprime_cc is stale, the flags are not being read, or the wrong backend is measured."
    say "  → ALL NUMBERS IN THIS RUN ARE INVALID (lesson #7). Do not draw a conclusion."
fi
say ""
say "  historical baseline of record: 8.6x (2026-06-26) / 10.9x (2026-06-27 re-baseline)"
say "  ALLOFF (pre-lever control) here = ${GEO_OFF}x  → reproduces the historical band? (sanity)"
say "  ALLON  (shipped default)   here = ${GEO_ON}x  → THE NEW MAP"
say ""
say "=== DONE $(date -u +%FT%TZ) — artifacts under $WORK ==="
