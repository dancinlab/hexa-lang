#!/usr/bin/env bash
# state/static-types/unbox-hir-calltype-r1/measure.sh — HEXA_UNBOX_HIR_CALLTYPE gate harness.
#
# RUN DETACHED ON POOL (aiden/summer), NOT mini. Self-harvests to
# $HOME/l4_calltype_RESULT.txt. Single-SSH discipline; isolated $HOME/l4_calltype
# scratch (NOT /tmp). Adapted 1:1 from state/unbox-native-r{5,6}/measure*.sh.
#
# ── WHAT THIS ROUND IS ───────────────────────────────────────────────────────
# The native unbox ALU path (compiler/codegen/x86_64_linux.hexa _STMT_BINOP) is
# ALREADY default-ON. It FAILS to fire when an operand's type came from a call
# because ast_to_hir leaves builtin-method-call RESULTS typed "?" (MIR type_id
# 0). HEXA_UNBOX_HIR_CALLTYPE=1 stamps the monomorphic primitive result from a
# mirror of the checker's builtin-method-ret table, so type_id 1 flows through
# → the existing lever fires on the call-result operand.
#
# THE MEASURED VARIABLE IS **HEXA_UNBOX_HIR_CALLTYPE** (OFF vs ON). The native
# ALU gate HEXA_UNBOX_NATIVE is held ON (default) in BOTH arms so the ONLY delta
# is the call-result type stamp. k1_sum (no call operand) is the CONTROL — its
# OFF==ON asm must stay byte-identical (the stamp cannot reach a call-less loop).
#
# Gates:
#  1 (OFF byteeq, BLOCKING) — patched flag-OFF .o == baseline (origin/main) .o
#     for the SAME kernel (proves OFF-path emit unchanged; full 3-target
#     gen3≡gen4 byteeq is the PR-CI job — this is the local probe).
#  2 (lever) — k6 native asm `call hexa_add`/`hexa_mul` count OFF vs ON.
#     WIN = ON < OFF (the call-result operand now unboxes). k1 = control (OFF==ON).
#  3 (win)   — link CPU runtime.a, taskset median CPU, ratio ON/OFF.
#  4 (parity, BLOCKING) — k6 + k1 program output identical OFF vs ON.
#  5 (smoke) — hexa --version + hello + exit42 under the flag.
set -u
RESULT="$HOME/l4_calltype_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"        # canonical seed checkout (gitignored seeds)
WORK="${WORK:-$HOME/l4_calltype}"        # isolated dir (NOT /tmp)
BR="${BR:-feat/l4-unbox-hir-calltype}"
BASE="${BASE:-origin/main}"              # OFF-byteeq baseline ref
FLAG="HEXA_UNBOX_HIR_CALLTYPE"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== $FLAG measure (APRIME native backend) — $(date -u +%FT%TZ) — $(hostname) ==="

# ── 0. wait for load<6 (no-starve), cap ~40min ──
say "--- waiting for load<6 (no-starve) ---"
for w in $(seq 1 80); do
    L=$(awk '{print $1}' /proc/loadavg); Li=${L%.*}
    if [ "${Li:-99}" -lt 6 ]; then say "  load=$L OK after ${w} probe(s)"; break; fi
    [ "$w" = 80 ] && say "  load stayed high (last=$L) — proceeding after 40min cap"
    sleep 30
done

build_aprime_at() { # $1=outbin $2=srcdir
    local out="$1" src="$2"
    ( cd "$src"; bash tool/build_aprime.sh -o "$out" -r "$src" ) >"$WORK/$(basename "$out").log" 2>&1
    return $?
}
prep_seeds() { # $1=srcdir — copy gitignored seeds from CANON
    local src="$1"
    for f in self/runtime.c self/native/hexat self/native/hexa_cc.c; do
        [ -e "$CANON/$f" ] && [ ! -e "$src/$f" ] && { mkdir -p "$src/$(dirname "$f")"; cp -a "$CANON/$f" "$src/$f" 2>/dev/null; }
    done
    [ -d "$CANON/self/native" ] && cp -an "$CANON/self/native/." "$src/self/native/" 2>/dev/null || true
    [ -d "$CANON/build" ] && mkdir -p "$src/build" && cp -an "$CANON/build/hexat" "$src/build/" 2>/dev/null || true
}

# ── 1. isolated worktrees: patched branch + baseline ──
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

# ── 2. build patched + baseline aprime_cc (linux-safe: no -arch) ──
say "--- building patched aprime_cc ($BR) ---"
build_aprime_at "$WORK/aprime_cc" "$SRC" && say "  patched build EXIT=0" || { say "  patched build EXIT=$?"; tail -25 "$WORK/aprime_cc.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"; [ -x "$AP" ] || { say "FATAL: patched aprime_cc not built"; exit 4; }
say "--- building baseline aprime_cc ($BASE) ---"
[ -d "$BSRC" ] && { build_aprime_at "$WORK/aprime_base" "$BSRC" && say "  baseline build EXIT=0" || { say "  baseline build EXIT=$?"; tail -25 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }; }
APB="$WORK/aprime_base"; [ -x "$APB" ] || say "  (baseline aprime missing — Gate1 baseline cmp will skip)"

# ── CPU runtime.a (prefer the patched build's CPU runtime.a; de-prio CUDA-tagged) ──
say "--- locating CPU runtime.a ---"
RT=""; RT_FALLBACK=""
for cand in "$SRC/build/runtime.a" "$CANON/runtime.a.cpubak" "$SRC/runtime.a.cpubak" \
            "$CANON/build/selfhost/runtime.a" "$SRC/build/selfhost/runtime.a" \
            "$SRC/build/runtime.a.cpubak" "$HOME/.hx/bin/build/runtime.a"; do
    [ -f "$cand" ] || continue
    if ar t "$cand" 2>/dev/null | grep -qi cuda; then
        say "  (de-prio CUDA-tagged rt: $cand)"; [ -z "$RT_FALLBACK" ] && RT_FALLBACK="$cand"; continue
    fi
    RT="$cand"; break
done
[ -z "$RT" ] && [ -n "$RT_FALLBACK" ] && { RT="$RT_FALLBACK"; say "  (no CPU-only rt; falling back to CUDA-tagged $RT — undef will show at link)"; }
say "  runtime.a = ${RT:-NONE}"

# ── kernels: k6_callres (the call-result target) + k1_sum (call-less CONTROL) ──
K6="$WORK/k6_callres.hexa"; cp "$SRC/state/static-types/unbox-hir-calltype-r1/k6_callres.hexa" "$K6" 2>/dev/null \
    || printf 'fn main() {\n    let xs: [i64] = [3, 1, 4, 1, 5, 9, 2, 6]\n    let mut s = 0\n    let N = 100000000\n    for i in 0..N {\n        s = s + xs.len() * i\n    }\n    println(s)\n}\n' > "$K6"
K1="$WORK/k1_sum.hexa"
printf 'fn main() {\n    let M = 1000000007\n    let mut s = 0\n    let N = 200000000\n    for i in 0..N {\n        s = (s + i * 1009) %% M\n    }\n    println(s)\n}\n' | sed 's/%%/%/' > "$K1"
say "  kernels: k6_callres(xs.len()*i target) + k1_sum(call-less control)"

# ── emit: the ONLY toggled var is $FLAG; HEXA_UNBOX_NATIVE held ON (default) ──
emit_one() { # $1=cc $2=flag(0/1) $3=outbase $4=kernel
    local cc="$1" f="$2" out="$3" k="$4"
    ( cd "$(dirname "$k")"
      unset HEXA_UNBOX_NATIVE                 # default-ON — native ALU path live in BOTH arms
      if [ "$f" = 1 ]; then export HEXA_UNBOX_HIR_CALLTYPE=1; else unset HEXA_UNBOX_HIR_CALLTYPE; fi
      "$cc" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$k" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      if [ "$f" = 1 ]; then export HEXA_UNBOX_HIR_CALLTYPE=1; else unset HEXA_UNBOX_HIR_CALLTYPE; fi
      "$cc" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$k" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" )
}

# ── Gate 1 — OFF-path byteeq (BLOCKING): same neutral cwd, both OFF builds ──
say "--- Gate1 OFF byteeq (patched flag-OFF .o == baseline .o) ---"
for KN in k6 k1; do
  K="$K6"; [ "$KN" = k1 ] && K="$K1"
  CMP="$WORK/cmp_$KN"; rm -rf "$CMP"; mkdir -p "$CMP"; cp "$K" "$CMP/k.hexa"
  ( cd "$CMP"; unset HEXA_UNBOX_NATIVE HEXA_UNBOX_HIR_CALLTYPE
    "$AP"  _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$CMP/p_off.o" "$CMP/k.hexa" >"$CMP/p.o.log" 2>&1 || echo "p emit rc=$?" )
  if [ -x "$APB" ]; then ( cd "$CMP"; unset HEXA_UNBOX_NATIVE HEXA_UNBOX_HIR_CALLTYPE
    "$APB" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$CMP/b_off.o" "$CMP/k.hexa" >"$CMP/b.o.log" 2>&1 || echo "b emit rc=$?" ); fi
  if [ -f "$CMP/p_off.o" ] && [ -f "$CMP/b_off.o" ]; then
    if cmp -s "$CMP/p_off.o" "$CMP/b_off.o"; then say "  [$KN] Gate1 OFF-BYTEEQ=PASS (OFF-path inert CONFIRMED)"
    else say "  [$KN] Gate1 OFF-BYTEEQ=FAIL (SHIP-BLOCK)"; cmp -l "$CMP/p_off.o" "$CMP/b_off.o" 2>/dev/null | head -12 | sed 's/^/      /' | tee -a "$RESULT"; fi
  else say "  [$KN] Gate1 .o missing (degraded) — see $CMP/*.log"; fi
done

# ── Gate 2 — lever: native call-count OFF vs ON ──
say "--- Gate2 lever (native asm hexa_* call-count OFF vs ON; k6=target k1=control) ---"
for KN in k6 k1; do
  K="$K6"; [ "$KN" = k1 ] && K="$K1"
  emit_one "$AP" 0 "$WORK/${KN}_off" "$K"; emit_one "$AP" 1 "$WORK/${KN}_on" "$K"
  for tag in off on; do
    s="$WORK/${KN}_${tag}.s"
    if [ -f "$s" ]; then
      add=$(grep -cE '\bcall\b.*hexa_add' "$s" 2>/dev/null || echo NA)
      mul=$(grep -cE '\bcall\b.*hexa_mul' "$s" 2>/dev/null || echo NA)
      say "  [$KN] $tag: hexa_add=$add hexa_mul=$mul ($s)"
    else say "  [$KN] $tag: no .s (see $s.log)"; tail -6 "$s.log" 2>/dev/null | sed 's/^/      /' | tee -a "$RESULT"; fi
  done
  if [ -f "$WORK/${KN}_off.s" ] && [ -f "$WORK/${KN}_on.s" ]; then
    if cmp -s "$WORK/${KN}_off.s" "$WORK/${KN}_on.s"; then
      say "  [$KN] asm OFF==ON byte-identical$([ "$KN" = k1 ] && echo ' (control — EXPECTED)' || echo ' (⚠ flag had NO EFFECT on k6 — check field-callee stamp)')"
    else say "  [$KN] asm OFF!=ON (flag LIVE):"; diff "$WORK/${KN}_off.s" "$WORK/${KN}_on.s" | head -30 | sed 's/^/    /' | tee -a "$RESULT"; fi
  fi
done

# ── Gate 3+4 — runtime ratio + parity ──
say "--- Gate3+4 runtime ratio + parity ---"
link_run() { local kn="$1" tag="$2"; local o="$WORK/${kn}_${tag}.o" b="$WORK/${kn}_${tag}.bin"
    [ -f "$o" ] || { say "  [$kn] $tag: no .o"; return; }
    [ -n "$RT" ] || { say "  [$kn] $tag: no runtime.a → skip link"; return; }
    # -nostartfiles: runtime.a carries its own own-start `_start`; without this the
    # default Scrt1.o `_start` collides (multiple definition). Use runtime.a's entry.
    gcc -O2 -nostartfiles "$o" "$RT" -lm -o "$b" 2>"$b.ld.log" || { say "  [$kn] $tag: gcc link FAIL"; tail -6 "$b.ld.log" | sed 's/^/      /' | tee -a "$RESULT"; return; }
    local out vals=() t med; out=$("$b" 2>/dev/null)
    for r in 1 2 3 4 5; do t=$( { /usr/bin/time -v taskset -c 3 "$b" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s+0}'); vals+=("$t"); done
    med=$(printf '%s\n' "${vals[@]}" | sort -n | sed -n '3p')
    say "  [$kn] $tag: output=$out median_cpu_s=$med"; eval "OUT_${kn}_${tag}=\$out"; eval "MED_${kn}_${tag}=\$med"; }
for KN in k6 k1; do
  link_run "$KN" off; link_run "$KN" on
  oo="OUT_${KN}_off"; on="OUT_${KN}_on"; mo="MED_${KN}_off"; mn="MED_${KN}_on"
  if [ "${!oo:-x}" = "${!on:-y}" ]; then say "  [$KN] Gate4 PARITY=OK (${!oo:-?})"; else say "  [$KN] Gate4 PARITY=FAIL off=${!oo:-?} on=${!on:-?}"; fi
  say "  [$KN] Gate3 ratio ON/OFF (cpu) = $(awk -v a="${!mn:-0}" -v b="${!mo:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')"
done

# ── Gate 5 — ship smoke ──
say "--- Gate5 ship smoke ($FLAG=1) ---"
HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
if [ -x "$HX" ]; then
    say "  version: $(HEXA_UNBOX_HIR_CALLTYPE=1 "$HX" --version 2>&1 | head -1)"
    printf 'fn main(){println("hello")}\n' > "$WORK/hello.hexa"; printf 'fn main(){exit(42)}\n' > "$WORK/e42.hexa"
    ( cd "$WORK"; HEXA_UNBOX_HIR_CALLTYPE=1 "$HX" run hello.hexa >h.out 2>h.err; say "  hello rc=$? out=$(cat h.out 2>/dev/null)" )
    ( cd "$WORK"; HEXA_UNBOX_HIR_CALLTYPE=1 "$HX" run e42.hexa >/dev/null 2>e.err; say "  exit42 rc=$?" )
else say "  hexa not found ($HX)"; fi
say "=== DONE — artifacts under $WORK ==="
