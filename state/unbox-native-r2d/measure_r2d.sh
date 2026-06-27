#!/usr/bin/env bash
# state/unbox-native-r2d/measure_r2d.sh — HEXA_UNBOX_ARRAY_NATIVE r2d gate harness.
#
# RUN DETACHED ON POOL (aiden), NOT mini. Self-harvests to $HOME/r2d_RESULT.txt
# (reboot-proof). Single-SSH; isolated $HOME/r2d_arru scratch (NOT /tmp).
#
# r2d = address-gen strength reduction. r2c (#4080, in main) landed native array-
# element load/store under HEXA_UNBOX_ARRAY_NATIVE=1 and measured 2.7× (vs gcc -O2
# roofline 26.9×). The honest 2.7× residual = ⓐ stride-16 HexaVal element traffic
# ⓑ per-iteration spill reload ⓒ kept bounds-check, PLUS the addr-gen `imul rax,16`.
# r2d attacks the ONE clean byteeq-safe per-statement lever: `imul rax,16` →
# `shl rax,4` (power-of-2 stride strength reduction, gcc -O2 reference-matched —
# gcc scales 2^k strides with shl/lea, NEVER imul; 3c→1c on the addr-gen dep chain).
# ⓐ(element-pack) needs the packed-typed-array runtime layout (broad, every consumer
# + boxed slow path) and ⓑⓒ(reg-hoist/bounds-elision) need a loop optimizer (MIR has
# blocks/preds/succs but NO induction/LICM infra) — both OUT of byteeq-safe scope;
# r2d measures the per-statement ceiling + the gcc gap so the wall is captured.
#
# OOM-SAFE: builds exactly ONE aprime at a time (verdict: 30G host double-aprime =
# OOM). Sequence — build BASELINE(main) aprime → harvest its ON .o/.s/run → DELETE
# it → build PATCHED(r2d) aprime → harvest ON+OFF. Never two aprimes resident.
#
#  Gate1  — OFF byteeq: patched flag-OFF .o == baseline .o (same-cwd). release-safe.
#  Gate2  — lever fired: patched ON asm has `shl ...,4` and NO `imul ...16` in arru
#           region; baseline ON asm has `imul ...16`. + bounds/spill component count.
#  Gate3a — patched ON/OFF ratio (native vs boxed; reproduces r2c ~0.37 = 2.7×).
#  Gate3b — patched ON / baseline ON (shl vs imul = the r2d lever delta; <1.0 = win).
#  Gate3c — patched ON / gcc -O2 (roofline gap; 26.9× = 1/0.037 was the r2c-pre gap).
#  Gate4  — output parity: patched ON == patched OFF == baseline ON (i64 bit-exact).
#  DISASM — objdump inner loop, hexa-ON vs gcc -O2, 1:1 component compare.
set -u
RESULT="$HOME/r2d_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"
WORK="${WORK:-$HOME/r2d_arru}"
BR="${BR:-perf/codegen-unbox-array-r2d}"
BASE="${BASE:-origin/main}"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== HEXA_UNBOX_ARRAY_NATIVE r2d measure — $(date -u +%FT%TZ) — $(hostname) ==="

say "--- waiting for load<6 (no-starve) ---"
for w in $(seq 1 120); do
    L=$(awk '{print $1}' /proc/loadavg); Li=${L%.*}
    if [ "${Li:-99}" -lt 6 ]; then say "  load=$L OK after ${w} probe(s)"; break; fi
    [ "$w" = 120 ] && say "  load stayed high (last=$L) — proceeding after 60min cap"
    sleep 30
done

build_aprime_at() { local out="$1" src="$2"
    ( cd "$src"; bash tool/build_aprime.sh -o "$out" -r "$src" ) >"$WORK/$(basename "$out").log" 2>&1; return $?; }

prep_seeds() { local src="$1"
    for f in self/runtime.c self/native/hexat self/native/hexa_cc.c; do
        [ -e "$CANON/$f" ] && [ ! -e "$src/$f" ] && { mkdir -p "$src/$(dirname "$f")"; cp -a "$CANON/$f" "$src/$f" 2>/dev/null; }
    done
    [ -d "$CANON/self/native" ] && cp -an "$CANON/self/native/." "$src/self/native/" 2>/dev/null || true
    [ -d "$CANON/build" ] && mkdir -p "$src/build" && cp -an "$CANON/build/hexat" "$src/build/" 2>/dev/null || true
}

rm -rf "$WORK"; mkdir -p "$WORK"
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }
git -C "$CANON" worktree prune 2>>"$WORK/git.log" || true
git -C "$CANON" fetch -f origin "$BR:refs/remotes/origin/$BR" 2>>"$WORK/git.log" || say "  (fetch BR warn)"
git -C "$CANON" fetch -f origin "main:refs/remotes/origin/main" 2>>"$WORK/git.log" || say "  (fetch main warn)"
git -C "$CANON" worktree add -f --detach "$WORK/src"  "origin/$BR"  2>>"$WORK/git.log" \
    || git clone -b "$BR" "$CANON" "$WORK/src" 2>>"$WORK/git.log" || { say "FATAL clone BR"; exit 3; }
git -C "$CANON" worktree add -f --detach "$WORK/base" "$BASE"       2>>"$WORK/git.log" \
    || git clone "$CANON" "$WORK/base" 2>>"$WORK/git.log" || say "  (base worktree warn)"
SRC="$WORK/src"; BSRC="$WORK/base"
say "  SRC=$SRC  sha=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"
say "  BASE=$BSRC sha=$(git -C "$BSRC" rev-parse --short HEAD 2>/dev/null)"
prep_seeds "$SRC"; prep_seeds "$BSRC"

# ── locate CPU-only runtime.a (aiden default is CUDA-linked) ──
say "--- locating CPU runtime.a ---"
RT=""; RT_FALLBACK=""
for cand in "$SRC/build/runtime.a" "$CANON/runtime.a.cpubak" "$SRC/runtime.a.cpubak" \
            "$CANON/build/selfhost/runtime.a" "$SRC/build/selfhost/runtime.a" \
            "$SRC/build/runtime.a.cpubak" "$HOME/.hx/bin/build/runtime.a"; do
    [ -f "$cand" ] || continue
    if ar t "$cand" 2>/dev/null | grep -qi cuda; then [ -z "$RT_FALLBACK" ] && RT_FALLBACK="$cand"; continue; fi
    RT="$cand"; break
done
[ -z "$RT" ] && [ -n "$RT_FALLBACK" ] && { RT="$RT_FALLBACK"; say "  (no CPU-only rt; CUDA-tagged fallback $RT)"; }
say "  runtime.a = ${RT:-NONE} ($( [ -n "$RT" ] && stat -c%s "$RT" 2>/dev/null || echo 0) bytes)"

# ── kernel: k3_arrmap (same as r2b; the 26.9× array-index slice) ──
KERN="$WORK/k3_arrmap.hexa"
cat > "$KERN" <<'EOF'
fn main() {
    let N = 4096
    let mut xs: [i64] = []
    let mut i = 0
    while i < N {
        xs.push(i * 2 + 1)
        i = i + 1
    }
    let REP = 200000
    let mut acc = 0
    let mut r = 0
    while r < REP {
        let mut j = 0
        while j < N {
            let v = xs[j]
            xs[j] = v + acc
            acc = acc + xs[j]
            j = j + 1
        }
        r = r + 1
    }
    println(acc)
}
EOF
say "  kernel = $KERN (k3_arrmap, N=4096 REP=2e5 = 819M element-ops)"

# ── gcc -O2 reference (roofline; -fwrapv = defined i64 wrap == hexa) ──
CK="$WORK/k3.c"
cat > "$CK" <<'EOF'
#include <stdio.h>
int main(void){
    long N=4096; static long xs[4096];
    for(long i=0;i<N;i++) xs[i]=i*2+1;
    long REP=200000, acc=0;
    for(long r=0;r<REP;r++)
        for(long j=0;j<N;j++){ long v=xs[j]; xs[j]=v+acc; acc=acc+xs[j]; }
    printf("%ld\n",acc); return 0;
}
EOF
GBIN="$WORK/k3_gcc"; gcc -O2 -fwrapv "$CK" -o "$GBIN" 2>"$WORK/gcc.log" && say "  gcc -O2 ref built" || say "  gcc ref build FAIL"

med5() { local bin="$1"; local vals=() t; for r in 1 2 3 4 5; do
        t=$( { /usr/bin/time -v taskset -c 3 "$bin" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s+0}'); vals+=("$t"); done
    printf '%s\n' "${vals[@]}" | sort -n | sed -n '3p'; }

emit_on()  { local cc="$1" out="$2" src="$3"; ( cd "$src"; export HEXA_UNBOX_ARRAY_NATIVE=1
        "$cc" --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$?"
        "$cc" --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$?" ); }
emit_off() { local cc="$1" out="$2" src="$3"; ( cd "$src"; unset HEXA_UNBOX_ARRAY_NATIVE
        "$cc" --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$?"
        "$cc" --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$?" ); }
link_run() { local o="$1" b="$2"
    [ -f "$o" ] || { echo "NOLINK:no-o"; return; }
    [ -n "$RT" ] || { echo "NOLINK:no-rt"; return; }
    gcc -O2 "$o" "$RT" -lm -o "$b" 2>"$b.ld.log" || { echo "NOLINK:ld-fail"; return; }
    local out; out=$("$b" 2>/dev/null); local med; med=$(med5 "$b")
    echo "OUT=$out MED=$med"; }

# ══ PHASE 1 — BASELINE (origin/main, imul path) ══
say "--- PHASE1: build BASELINE aprime ($BASE) ---"
build_aprime_at "$WORK/aprime_base" "$BSRC" && say "  baseline build EXIT=0" || { say "  baseline build EXIT=$?"; tail -25 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }
APB="$WORK/aprime_base"
if [ -x "$APB" ]; then
    emit_on  "$APB" "$WORK/base_on"  "$BSRC"
    emit_off "$APB" "$WORK/base_off" "$BSRC"   # for Gate1 byteeq baseline
    BRES=$(link_run "$WORK/base_on.o" "$WORK/base_on.bin"); say "  baseline ON: $BRES"
    BOUT=$(echo "$BRES" | sed -n 's/.*OUT=\([^ ]*\).*/\1/p'); BMED=$(echo "$BRES" | sed -n 's/.*MED=\([^ ]*\).*/\1/p')
    # asm component snapshot (imul expected)
    say "  baseline ON asm: imul16=$(grep -cE 'imul.*(16|\$16|, 16)' "$WORK/base_on.s" 2>/dev/null) shl4=$(grep -cE 'shl.*4\b' "$WORK/base_on.s" 2>/dev/null) idxget_call=$(grep -cE 'call.*hexa_index_get' "$WORK/base_on.s" 2>/dev/null) idxset_call=$(grep -cE 'call.*hexa_index_set' "$WORK/base_on.s" 2>/dev/null)"
    cp "$WORK/base_off.o" "$WORK/base_off.keep.o" 2>/dev/null
else say "  FATAL baseline aprime missing — Gate3b lever-isolation will skip"; fi
# free baseline aprime + worktree BEFORE building patched (OOM-safe single-resident)
say "  freeing baseline aprime+worktree (OOM-safe) ..."
rm -f "$APB"; rm -rf "$BSRC"; git -C "$CANON" worktree prune 2>/dev/null || true

# ══ PHASE 2 — PATCHED (r2d, shl path) ══
say "--- PHASE2: build PATCHED aprime ($BR) ---"
build_aprime_at "$WORK/aprime_pat" "$SRC" && say "  patched build EXIT=0" || { say "  patched build EXIT=$?"; tail -25 "$WORK/aprime_pat.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_pat"; [ -x "$AP" ] || { say "FATAL: patched aprime not built"; exit 4; }
emit_on  "$AP" "$WORK/pat_on"  "$SRC"
emit_off "$AP" "$WORK/pat_off" "$SRC"
PRES_ON=$(link_run "$WORK/pat_on.o"  "$WORK/pat_on.bin");  say "  patched ON : $PRES_ON"
PRES_OFF=$(link_run "$WORK/pat_off.o" "$WORK/pat_off.bin"); say "  patched OFF: $PRES_OFF"
POUT_ON=$(echo "$PRES_ON" | sed -n 's/.*OUT=\([^ ]*\).*/\1/p'); PMED_ON=$(echo "$PRES_ON" | sed -n 's/.*MED=\([^ ]*\).*/\1/p')
POUT_OFF=$(echo "$PRES_OFF" | sed -n 's/.*OUT=\([^ ]*\).*/\1/p'); PMED_OFF=$(echo "$PRES_OFF" | sed -n 's/.*MED=\([^ ]*\).*/\1/p')

# ── Gate1 — OFF-path byteeq (same-cwd) ──
say "--- Gate1 OFF byteeq (patched flag-OFF .o == baseline .o, same-cwd) ---"
CMP="$WORK/cmp"; rm -rf "$CMP"; mkdir -p "$CMP"; cp "$KERN" "$CMP/k.hexa"
( cd "$CMP"; unset HEXA_UNBOX_ARRAY_NATIVE; "$AP" --emit=obj --target=x86_64-linux-gnu -o "$CMP/p_off.o" "$CMP/k.hexa" >"$CMP/p.log" 2>&1 || echo rc=$? )
if [ -f "$WORK/base_off.keep.o" ] && [ -f "$CMP/p_off.o" ]; then
    # baseline OFF .o was emitted in BSRC cwd; re-emit baseline-equivalent not possible (binary freed).
    # Compare patched-OFF vs patched-OFF-from-SRC-cwd is trivially eq; the cross-binary OFF byteeq
    # (patched-OFF == baseline-OFF) is the release-safety claim — relies on the OFF path being
    # flag-gated identical source. We compare .text of patched-OFF vs baseline-OFF (different cwd →
    # DWARF comp_dir differs; .text is the codegen claim).
    objcopy -O binary --only-section=.text "$CMP/p_off.o" "$CMP/pt.bin" 2>/dev/null
    objcopy -O binary --only-section=.text "$WORK/base_off.keep.o" "$CMP/bt.bin" 2>/dev/null
    if cmp -s "$CMP/pt.bin" "$CMP/bt.bin"; then say "  Gate1 OFF .text IDENTICAL (patched-OFF == baseline-OFF) — release-safe"
    else say "  Gate1 OFF .text DIFFERS — real OFF-path leak (BLOCK):"; fi
else say "  Gate1 degraded (missing .o; see logs) — NOTE: 3-target OFF byteeq lands via CI"; fi

# ── Gate2 — lever fired ──
say "--- Gate2 lever (patched ON: shl present, imul16 absent in arru region) ---"
for tag in on off; do s="$WORK/pat_$tag.s"; [ -f "$s" ] || { say "  patched $tag: no .s"; continue; }
    say "  patched $tag asm: imul16=$(grep -cE 'imul.*(16|\$16|, 16)' "$s") shl4=$(grep -cE 'shl.*(4\b|\$4)' "$s") idxget_call=$(grep -cE 'call.*hexa_index_get' "$s") idxset_call=$(grep -cE 'call.*hexa_index_set' "$s") arru_lbl=$(grep -cE '\.Larru' "$s") rbp_spill=$(grep -cE '\[rbp|rbp -|rbp\+' "$s")"
done
if [ -f "$WORK/pat_on.s" ] && [ -f "$WORK/base_on.s" ]; then
    say "  ARRU region diff (baseline imul -> patched shl), context:"; diff <(grep -iE 'arru|imul|shl' "$WORK/base_on.s") <(grep -iE 'arru|imul|shl' "$WORK/pat_on.s") | head -30 | sed 's/^/    /' | tee -a "$RESULT"
fi

# ── Gate4 — parity ──
say "--- Gate4 parity (patched ON == patched OFF == baseline ON) ---"
say "  outputs: patchedON=$POUT_ON patchedOFF=$POUT_OFF baselineON=${BOUT:-NA} gcc=$($GBIN 2>/dev/null || echo NA)"
if [ "$POUT_ON" = "$POUT_OFF" ] && { [ -z "${BOUT:-}" ] || [ "$POUT_ON" = "$BOUT" ]; }; then say "  Gate4 PARITY=OK"; else say "  Gate4 PARITY=FAIL (SOUNDNESS BLOCK)"; fi

# ── Gate3 — ratios ──
say "--- Gate3 ratios (median-5 cpu-s, taskset -c 3) ---"
GMED=$(med5 "$GBIN" 2>/dev/null)
say "  median_cpu_s: patchedON=$PMED_ON patchedOFF=$PMED_OFF baselineON=${BMED:-NA} gcc-O2=$GMED"
ratio() { awk -v a="$1" -v b="$2" 'BEGIN{if(b>0)printf "%.4f",a/b; else print "NA"}'; }
say "  Gate3a native/boxed  = patchedON/patchedOFF = $(ratio "${PMED_ON:-0}" "${PMED_OFF:-0}")  [r2c reproduce ~0.37 = 2.7x]"
say "  Gate3b LEVER shl/imul= patchedON/baselineON = $(ratio "${PMED_ON:-0}" "${BMED:-0}")       [<1.0 = r2d win over r2c]"
say "  Gate3c roofline gap  = patchedON/gcc-O2     = $(ratio "${PMED_ON:-0}" "${GMED:-0}")        [1.0 = parity; was 26.9x]"

# ── DISASM — inner-loop component compare (hexa ON vs gcc -O2) ──
say "--- DISASM inner-loop component compare ---"
if [ -f "$WORK/pat_on.bin" ]; then
    say "  [hexa ON inner loop — expect: per-access mov reloads + cmp/jae bounds + shl 4 + stride-16 mov +8]"
    objdump -d --no-show-raw-insn "$WORK/pat_on.bin" 2>/dev/null | grep -iE 'shl|imul|cmp|jae|jb |mov .*0x8\(|mov .*0x10' | head -25 | sed 's/^/    /' | tee -a "$RESULT"
fi
if [ -x "$GBIN" ]; then
    say "  [gcc -O2 inner loop — expect: reg-resident pointer walk, NO bounds, stride-8, lea/add]"
    objdump -d --no-show-raw-insn "$GBIN" 2>/dev/null | sed -n '/<main>:/,/ret/p' | grep -iE 'mov|add|lea|imul|shl|cmp|jne|jl ' | head -30 | sed 's/^/    /' | tee -a "$RESULT"
fi

# ── ship smoke ──
say "--- ship smoke (HEXA_UNBOX_ARRAY_NATIVE=1) ---"
HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
if [ -x "$HX" ]; then
    printf 'fn main(){println("hello")}\n' > "$WORK/hello.hexa"; printf 'fn main(){exit(42)}\n' > "$WORK/e42.hexa"
    ( cd "$WORK"; HEXA_UNBOX_ARRAY_NATIVE=1 "$HX" run hello.hexa >h.out 2>h.err; say "  hello rc=$? out=$(cat h.out 2>/dev/null)" )
    ( cd "$WORK"; HEXA_UNBOX_ARRAY_NATIVE=1 "$HX" run e42.hexa >/dev/null 2>e.err; say "  exit42 rc=$?" )
else say "  hexa not found ($HX)"; fi
say "=== DONE — artifacts under $WORK ==="
