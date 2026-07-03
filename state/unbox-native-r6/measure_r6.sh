#!/usr/bin/env bash
# state/unbox-native-r6/measure_r6.sh — HEXA_UNBOX_NATIVE r6 const-prop harness.
#
# r6 EXTENDS r5b: an IMMUTABLE single-assignment `let M = <int literal>` divisor is
# const-prop'd so the r5b magic-reciprocal gate fires for `% M` (named const) — the
# `% M` that r5b left as a `call hexa_mod` (k1 ON hexa_mod=1, magic absent). FOREGROUND
# blocking run. Self-harvests to $HOME/r6_RESULT.txt. Single-SSH; isolated $HOME scratch.
#
# Gates:
#  1 (OFF byteeq, BLOCKING) — patched flag-OFF .o == origin/main baseline .o (same cwd).
#  2 (lever) — k1 ON hexa_mod count 0 (was 1 in r5b) + magic movabs constant present.
#  3 (ratio) — taskset median CPU ON/OFF, vs the r5b 0.426 (k1) baseline.
#  4 (parity, BLOCKING) — k1 output OFF==ON; SOUNDNESS k5 (reassigned `let mut` divisor)
#                         stays BOXED (hexa_mod>0, no magic) AND parity-correct.
#  5 (smoke) — hexa --version + hello + exit42 under the flag.
#  6 (magic ref-match) — k1 ON imul magic == gcc -O2 (0x89705F3112A28FE5 for % 1000000007).
set -u
RESULT="$HOME/r6_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"
WORK="${WORK:-$HOME/r6_native}"
BR="${BR:-perf/codegen-unbox-constprop-r6}"
BASE="${BASE:-origin/main}"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== HEXA_UNBOX_NATIVE r6 measure (let-literal const-prop → % M magic) — $(date -u +%FT%TZ) — $(hostname) ==="

say "--- waiting for load<6 (no-starve) ---"
for w in $(seq 1 80); do
    L=$(awk '{print $1}' /proc/loadavg); Li=${L%.*}
    if [ "${Li:-99}" -lt 6 ]; then say "  load=$L OK after ${w} probe(s)"; break; fi
    [ "$w" = 80 ] && say "  load stayed high (last=$L) — proceeding after 40min cap"
    sleep 30
done

build_aprime_at() { local out="$1" src="$2"
    ( cd "$src"; bash tool/build_aprime.sh -o "$out" -r "$src" ) >"$WORK/$(basename "$out").log" 2>&1; return $?; }
prep_seeds() { local src="$1"
    for f in self/runtime.c self/native/hexat self/native/hexa_cc.c; do
        [ -e "$CANON/$f" ] && [ ! -e "$src/$f" ] && { mkdir -p "$src/$(dirname "$f")"; cp -a "$CANON/$f" "$src/$f" 2>/dev/null; }
    done
    [ -d "$CANON/self/native" ] && cp -an "$CANON/self/native/." "$src/self/native/" 2>/dev/null || true
    [ -d "$CANON/build" ] && mkdir -p "$src/build" && cp -an "$CANON/build/hexat" "$src/build/" 2>/dev/null || true; }

rm -rf "$WORK"; mkdir -p "$WORK"
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }
git -C "$CANON" worktree prune 2>>"$WORK/git.log" || true
git -C "$CANON" fetch -f origin "$BR:refs/remotes/origin/$BR" 2>>"$WORK/git.log" || say "  (fetch BR warn)"
git -C "$CANON" fetch -f origin "main:refs/remotes/origin/main" 2>>"$WORK/git.log" || say "  (fetch main warn)"
git -C "$CANON" worktree add -f --detach "$WORK/src"  "origin/$BR"  2>>"$WORK/git.log" \
    || git clone -b "$BR" "$CANON" "$WORK/src" 2>>"$WORK/git.log" || { say "FATAL clone BR"; exit 3; }
git -C "$CANON" worktree add -f --detach "$WORK/base" "$BASE"       2>>"$WORK/git.log" \
    || git clone "$CANON" "$WORK/base" 2>>"$WORK/git.log" || say "  (base worktree warn — Gate1 may skip)"
SRC="$WORK/src"; BSRC="$WORK/base"
say "  SRC=$SRC  sha=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"
say "  BASE=$BSRC sha=$(git -C "$BSRC" rev-parse --short HEAD 2>/dev/null)"
prep_seeds "$SRC"; prep_seeds "$BSRC"

say "--- building patched aprime_cc (r6) ---"
build_aprime_at "$WORK/aprime_cc" "$SRC" && say "  patched build EXIT=0" || { say "  patched build EXIT=$?"; tail -30 "$WORK/aprime_cc.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"; [ -x "$AP" ] || { say "FATAL: patched aprime_cc not built (hexa syntax/type error in r6 helpers — see log above)"; exit 4; }

say "--- building baseline aprime_cc ($BASE) ---"
[ -d "$BSRC" ] && { build_aprime_at "$WORK/aprime_base" "$BSRC" && say "  baseline build EXIT=0" || { say "  baseline build EXIT=$?"; tail -25 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }; }
APB="$WORK/aprime_base"; [ -x "$APB" ] || say "  (baseline aprime missing — Gate1 baseline cmp skips)"

say "--- locating CPU runtime.a ---"
RT=""; RT_FALLBACK=""
for cand in "$SRC/build/runtime.a" "$CANON/runtime.a.cpubak" "$SRC/runtime.a.cpubak" \
            "$CANON/build/selfhost/runtime.a" "$SRC/build/selfhost/runtime.a" \
            "$SRC/build/runtime.a.cpubak" "$HOME/.hx/bin/build/runtime.a"; do
    [ -f "$cand" ] || continue
    if ar t "$cand" 2>/dev/null | grep -qi cuda; then [ -z "$RT_FALLBACK" ] && RT_FALLBACK="$cand"; continue; fi
    RT="$cand"; break
done
[ -z "$RT" ] && [ -n "$RT_FALLBACK" ] && RT="$RT_FALLBACK"
say "  runtime.a = ${RT:-NONE}"

# ── kernels: k1 (% M named const) is the r6 target; k4 (% 3,% 5 literals) regression;
#    k5 (% D where D is REASSIGNED let mut) is the SOUNDNESS kernel — must stay BOXED ──
K1="$WORK/k1_sum.hexa"
printf 'fn main() {\n    let M = 1000000007\n    let mut s = 0\n    let N = 200000000\n    for i in 0..N {\n        s = (s + i * 1009) %% M\n    }\n    println(s)\n}\n' | sed 's/%%/%/' > "$K1"
K4="$WORK/k4_branch.hexa"
printf 'fn main() {\n    let mut acc = 0\n    let N = 100000000\n    for i in 0..N {\n        if i %% 3 == 0 { acc = acc + i %% 5 } else { acc = acc - i %% 5 }\n    }\n    println(acc)\n}\n' | sed 's/%%/%/' > "$K4"
K5="$WORK/k5_reassign.hexa"
# D is `let mut` and reassigned inside the loop → NOT immutable → const-prop MUST skip
# it → `% D` stays a boxed call hexa_mod (variable divisor, div-zero firewall). Parity
# must still be correct.
printf 'fn main() {\n    let mut D = 7\n    let mut acc = 0\n    let N = 50000000\n    for i in 0..N {\n        acc = (acc + i) %% D\n        D = 7 + (i %% 2)\n    }\n    println(acc)\n}\n' | sed 's/%%/%/' > "$K5"
say "  kernels: k1(% M named const) + k4(% 3,% 5 lit) + k5(% D reassigned=soundness)"

emit_one() { # $1=cc $2=flag(0/1) $3=outbase $4=src $5=kernel
    local cc="$1" f="$2" out="$3" src="$4" k="$5"
    ( cd "$src"
      if [ "$f" = 1 ]; then export HEXA_UNBOX_NATIVE=1; else unset HEXA_UNBOX_NATIVE; fi
      "$cc" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$k" >"$out.s.log" 2>&1 || echo "asm rc=$? f=$f"
      "$cc" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$k" >"$out.o.log" 2>&1 || echo "obj rc=$? f=$f" ); }

# ── Gate 1 — OFF-path byteeq (BLOCKING), same-cwd ──
say "--- Gate1 OFF byteeq (same-cwd: patched flag-OFF .o == baseline .o) ---"
for KN in k1 k4 k5; do
  K="$K1"; [ "$KN" = k4 ] && K="$K4"; [ "$KN" = k5 ] && K="$K5"
  CMP="$WORK/cmp_$KN"; rm -rf "$CMP"; mkdir -p "$CMP"; cp "$K" "$CMP/k.hexa"
  ( cd "$CMP"; unset HEXA_UNBOX_NATIVE; "$AP"  _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$CMP/p_off.o" "$CMP/k.hexa" >"$CMP/p.log" 2>&1 || echo "p rc=$?" )
  if [ -x "$APB" ]; then ( cd "$CMP"; unset HEXA_UNBOX_NATIVE; "$APB" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$CMP/b_off.o" "$CMP/k.hexa" >"$CMP/b.log" 2>&1 || echo "b rc=$?" ); fi
  if [ -f "$CMP/p_off.o" ] && [ -f "$CMP/b_off.o" ]; then
    PSHA=$(sha256sum "$CMP/p_off.o" | cut -c1-16); BSHA=$(sha256sum "$CMP/b_off.o" | cut -c1-16)
    if cmp -s "$CMP/p_off.o" "$CMP/b_off.o"; then say "  Gate1[$KN] OFF-BYTEEQ=PASS sha=$PSHA"
    else
      say "  Gate1[$KN] OFF-BYTEEQ=FAIL patched=$PSHA baseline=$BSHA (SHIP-BLOCK)"
      objcopy -O binary --only-section=.text "$CMP/p_off.o" "$CMP/pt.bin" 2>/dev/null
      objcopy -O binary --only-section=.text "$CMP/b_off.o" "$CMP/bt.bin" 2>/dev/null
      cmp -s "$CMP/pt.bin" "$CMP/bt.bin" && say "    .text IDENTICAL — residual = ELF metadata (likely DWARF, benign)" || say "    .text DIFFERS — real OFF-path codegen leak"
    fi
  else say "  Gate1[$KN] .o missing (degraded; see $CMP/*.log)"; fi
done

# ── Gate 2 — lever: call-count + spill, OFF vs ON ──
say "--- Gate2 lever (hexa_mod/div/add/mul/cmp call-count + tag-slot spill, OFF vs ON) ---"
for KN in k1 k4 k5; do
  K="$K1"; [ "$KN" = k4 ] && K="$K4"; [ "$KN" = k5 ] && K="$K5"
  emit_one "$AP" 0 "$WORK/${KN}_off" "$SRC" "$K"
  emit_one "$AP" 1 "$WORK/${KN}_on"  "$SRC" "$K"
  for tag in off on; do
    s="$WORK/${KN}_${tag}.s"
    if [ -f "$s" ]; then
      mod=$(grep -cE '\bcall\b.*hexa_mod' "$s" 2>/dev/null|tr -d '\n'); div=$(grep -cE '\bcall\b.*hexa_div' "$s" 2>/dev/null|tr -d '\n')
      add=$(grep -cE '\bcall\b.*hexa_add' "$s" 2>/dev/null|tr -d '\n'); mul=$(grep -cE '\bcall\b.*hexa_mul' "$s" 2>/dev/null|tr -d '\n')
      cmpc=$(grep -cE '\bcall\b.*hexa_cmp' "$s" 2>/dev/null|tr -d '\n')
      magic=$(grep -cE '\-8543223828751151131|0x89705[fF]3112[aA]28[fF][eE]5' "$s" 2>/dev/null|tr -d '\n')
      say "  [$KN] $tag: hexa_mod=$mod hexa_div=$div hexa_add=$add hexa_mul=$mul hexa_cmp=$cmpc magic_const=$magic"
    else say "  [$KN] $tag: NO .s — emit failed:"; tail -10 "$s.log" 2>/dev/null | sed 's/^/      /' | tee -a "$RESULT"; fi
  done
done

# ── Gate 6 — magic ref-match: ON k1 carries gcc's magic constant ──
say "--- Gate6 magic reference-match (ON k1 asm — the r6 closer) ---"
S1ON="$WORK/k1_on.s"
if [ -f "$S1ON" ]; then
  if grep -qE '\-8543223828751151131|0x89705[fF]3112[aA]28[fF][eE]5|9903520244958400485' "$S1ON"; then
     say "  ✅ magic constant PRESENT in ON k1 asm (matches gcc/clang -O2 movabs imm) — const-prop FIRED"
  else say "  ⚠ magic constant NOT found in ON k1 asm — const-prop did NOT fire (residual: where did it break?)"; fi
  grep -nE 'imul|sar|movabs|mov r11, -854|1000000007' "$S1ON" 2>/dev/null | head -12 | sed 's/^/    /' | tee -a "$RESULT"
  if command -v objdump >/dev/null && [ -f "$WORK/k1_on.o" ]; then
    say "  --- objdump ON k1 (magicdiv window) ---"
    objdump -d "$WORK/k1_on.o" 2>/dev/null | grep -iE 'imul|sar|shr|movabs|0x89705f31|3b9aca07' | head -10 | sed 's/^/    /' | tee -a "$RESULT"
  fi
else say "  no ON k1 .s"; fi

# ── Gate 3+4 — ratio + parity ──
say "--- Gate3+4 runtime ratio + parity ---"
link_run() { # $1=kn $2=tag
  local kn="$1" tag="$2" o="$WORK/${1}_${2}.o" b="$WORK/${1}_${2}.bin"
  [ -f "$o" ] || { say "  [$kn] $tag: no .o"; return; }
  [ -n "$RT" ] || { say "  [$kn] $tag: no runtime.a"; return; }
  gcc -O2 "$o" "$RT" -lm -o "$b" 2>"$b.ld.log" || { say "  [$kn] $tag: link FAIL"; tail -6 "$b.ld.log"|sed 's/^/      /'|tee -a "$RESULT"; return; }
  local out vals=() t med; out=$("$b" 2>/dev/null)
  for r in 1 2 3 4 5; do t=$( { /usr/bin/time -v taskset -c 3 "$b" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s+0}'); vals+=("$t"); done
  med=$(printf '%s\n' "${vals[@]}"|sort -n|sed -n '3p')
  say "  [$kn] $tag: output=$out median_cpu_s=$med"; eval "OUT_${kn}_${tag}=\$out"; eval "MED_${kn}_${tag}=\$med"; }
for KN in k1 k4 k5; do
  link_run "$KN" off; link_run "$KN" on
  oo="OUT_${KN}_off"; on="OUT_${KN}_on"; mo="MED_${KN}_off"; mn="MED_${KN}_on"
  if [ "${!oo:-x}" = "${!on:-y}" ]; then say "  [$KN] Gate4 PARITY=OK (${!oo:-?})"; else say "  [$KN] Gate4 PARITY=FAIL off=${!oo:-?} on=${!on:-?}"; fi
  say "  [$KN] Gate3 ratio ON/OFF = $(awk -v a="${!mn:-0}" -v b="${!mo:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')  (<1.0 = magicdiv speedup; r5b k1=0.426)"
done

# ── Gate 5 — smoke ──
say "--- Gate5 ship smoke (HEXA_UNBOX_NATIVE=1) ---"
HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
if [ -x "$HX" ]; then
  say "  version: $(HEXA_UNBOX_NATIVE=1 "$HX" --version 2>&1 | head -1)"
  printf 'fn main(){println("hello")}\n' > "$WORK/hello.hexa"; printf 'fn main(){exit(42)}\n' > "$WORK/e42.hexa"
  ( cd "$WORK"; HEXA_UNBOX_NATIVE=1 "$HX" run hello.hexa >h.out 2>h.err; say "  hello rc=$? out=$(cat h.out 2>/dev/null)" )
  ( cd "$WORK"; HEXA_UNBOX_NATIVE=1 "$HX" run e42.hexa >/dev/null 2>e.err; say "  exit42 rc=$?" )
else say "  hexa not found ($HX)"; fi
say "=== DONE — artifacts under $WORK ==="
