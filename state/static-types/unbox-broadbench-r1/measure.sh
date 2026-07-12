#!/usr/bin/env bash
# state/static-types/unbox-broadbench-r1/measure.sh
#   HEXA_UNBOX_HIR_CALLTYPE broad no-regression bench (pre-global-default-ON gate).
#
# RUN DETACHED ON POOL (aiden/summer), NOT mini. Self-harvests to
# $HOME/l4_broadbench_RESULT.txt. Single-SSH discipline; isolated
# $HOME/l4_broadbench scratch (NOT /tmp). Adapted 1:1 from the r1 harness
# state/static-types/unbox-hir-calltype-r1/measure.sh + unbox-native-r{5,6}.
#
# ── WHY THIS ROUND ───────────────────────────────────────────────────────────
# HEXA_UNBOX_HIR_CALLTYPE is MERGED (#4875, default-OFF). r1 measured ONE kernel
# (k6_callres = array .len()*i) at 0.750× CPU (25% faster). A single-kernel win
# is NOT enough to justify the GLOBAL default-ON flip — we need BROAD data that
# the flip (a) never REGRESSES code it should not touch, and (b) fires across a
# variety of builtin-method call-results, hoistable AND non-hoistable, plus a
# real-workload proxy. This harness is that breadth grid.
#
# THE MEASURED VARIABLE = **HEXA_UNBOX_HIR_CALLTYPE** (OFF vs ON) on ONE aprime
# built from $BR (default origin/main — the flag already lives there). The
# native ALU gate HEXA_UNBOX_NATIVE is held ON (default) in BOTH arms so the
# ONLY delta is the call-result type stamp.
#
# ── KERNELS (state/static-types/unbox-broadbench-r1/*.hexa) ───────────────────
#   CONTROL (flip UNREACHABLE → OFF==ON asm MUST be byte-identical):
#     k1_sum      scalar reduce, no call operand
#     k2_branch   dense if/else + two `%`, no call operand
#     k3_arridx   xs[i%8]*i — array INDEX (not a method call)
#   TARGET · HOISTABLE (loop-invariant call-result → flip should FIRE):
#     k4_arrlen   xs.len()*i   (== r1 anchor)
#     k5_strlen   name.len()*i (string len path)
#     k6_idxof    hay.index_of(needle)+i
#   TARGET · NON-HOISTABLE (call arg depends on i → not liftable):
#     k7_byteat   name.byte_at(i%16)*i
#     k8_charcode name.char_code_at(i%5)+i
#   REAL-WORKLOAD PROXY:
#     k9_scan     lexer inner loop — src.len() hoisted + src.byte_at(i%L) per-step
#
# ── GATES (per kernel) ────────────────────────────────────────────────────────
#  G1 (control byteeq, BLOCKING) — for CONTROL kernels the OFF .o == ON .o
#     (proves the flip touches NOTHING outside builtin-method call-results;
#     this is the broad-regression safety proof). Full 3-target gen3≡gen4
#     byteeq stays the PR-CI job — this is the local probe.
#  G2 (lever)   — native asm `call hexa_add`/`hexa_mul` count OFF vs ON.
#     TARGET WIN = ON < OFF; CONTROL = OFF==ON.
#  G3 (ratio)   — link CPU runtime.a (-nostartfiles: runtime.a owns _start),
#     taskset median CPU, ratio ON/OFF (<1.0 = speedup; r1 k4≈0.750).
#  G4 (parity, BLOCKING) — program output identical OFF vs ON, ALL kernels.
#  G5 (smoke)   — hexa --version + hello + exit42 under the flag.
# A single CONTROL G1 FAIL or any G4 FAIL = flip is NOT flip-ready (broad
# regression / miscompile). The FLIP verdict wants: all CONTROL G1 PASS, all
# G4 PASS, and TARGET geomean ratio < 1.0 with no TARGET kernel > 1.02.
set -u
RESULT="$HOME/l4_broadbench_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"                 # canonical seed checkout (gitignored seeds)
WORK="${WORK:-$HOME/l4_broadbench}"               # isolated dir (NOT /tmp)
BR="${BR:-origin/main}"                           # flag is merged → main; override for a WIP branch
KDIR_REL="state/static-types/unbox-broadbench-r1" # committed kernel dir inside the checkout
FLAG="HEXA_UNBOX_HIR_CALLTYPE"
CONTROL="k1_sum k2_branch k3_arridx"
TARGET="k4_arrlen k5_strlen k6_idxof k7_byteat k8_charcode k9_scan k10_contains k11_tofloat"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== $FLAG BROAD no-regression bench (APRIME native) — $(date -u +%FT%TZ) — $(hostname) ==="
say "  BR=$BR  (flip lever measured OFF vs ON; HEXA_UNBOX_NATIVE held default-ON both arms)"

# ── 0. wait for load<6 (no-starve), cap ~40min ──
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

# ── 1. isolated worktree of $BR ──
rm -rf "$WORK"; mkdir -p "$WORK"
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }
git -C "$CANON" worktree prune 2>>"$WORK/git.log" || true
BRREF="${BR#origin/}"
git -C "$CANON" fetch -f origin "$BRREF:refs/remotes/origin/$BRREF" 2>>"$WORK/git.log" || say "  (fetch BR warn)"
git -C "$CANON" worktree add -f --detach "$WORK/src" "$BR" 2>>"$WORK/git.log" \
    || git clone -b "$BRREF" "$CANON" "$WORK/src" 2>>"$WORK/git.log" || { say "FATAL clone BR"; exit 3; }
SRC="$WORK/src"
say "  SRC=$SRC sha=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"
prep_seeds "$SRC"

# ── 2. build aprime_cc (linux-safe: no -arch) ──
say "--- building aprime_cc ($BR) ---"
build_aprime_at "$WORK/aprime_cc" "$SRC" && say "  build EXIT=0" || { say "  build EXIT=$?"; tail -25 "$WORK/aprime_cc.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"; [ -x "$AP" ] || { say "FATAL: aprime_cc not built"; exit 4; }

# ── CPU runtime.a (prefer patched CPU rt; de-prio CUDA-tagged) ──
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

# ── 3. stage kernels from the committed dir (printf fallback for the simple ones) ──
KSRC="$SRC/$KDIR_REL"
stage_k() { # $1=name
    local n="$1" dst="$WORK/$1.hexa"
    if [ -f "$KSRC/$n.hexa" ]; then cp "$KSRC/$n.hexa" "$dst"; return; fi
    say "  (kernel $n.hexa missing in checkout — using printf fallback)"
    case "$n" in
      k1_sum)   printf 'fn main() {\n    let M = 1000000007\n    let mut s = 0\n    let N = 200000000\n    for i in 0..N {\n        s = (s + i * 1009) %% M\n    }\n    println(s)\n}\n' | sed 's/%%/%/' > "$dst" ;;
      k4_arrlen)printf 'fn main() {\n    let xs: [i64] = [3, 1, 4, 1, 5, 9, 2, 6]\n    let mut s = 0\n    let N = 100000000\n    for i in 0..N {\n        s = s + xs.len() * i\n    }\n    println(s)\n}\n' > "$dst" ;;
      *) say "  (no fallback for $n — skipping)"; return 1 ;;
    esac
}
for k in $CONTROL $TARGET; do stage_k "$k"; done

# ── emit: ONLY toggled var is $FLAG; HEXA_UNBOX_NATIVE held default-ON ──
emit_one() { # $1=cc $2=flag(0/1) $3=outbase $4=kernel-hexa
    local cc="$1" f="$2" out="$3" k="$4"
    ( cd "$(dirname "$k")"
      unset HEXA_UNBOX_NATIVE                       # default-ON both arms
      # OFF arm = explicit =0 (NOT unset): post-#4897 the flag defaults ON
      # (env!="0"), so `unset` would leave the OFF arm ON → OFF==ON on every
      # kernel (contaminated delta, observed 2026-07-13). Explicit 0 disables.
      if [ "$f" = 1 ]; then export HEXA_UNBOX_HIR_CALLTYPE=1; else export HEXA_UNBOX_HIR_CALLTYPE=0; fi
      "$cc" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$k" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      "$cc" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$k" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" )
}

# per-kernel state carried into the summary
declare -A ADD_OFF ADD_ON MUL_OFF MUL_ON ASM_EQ RATIO PARITY G1

# ── G1 + G2 — emit both arms, control byteeq, call-count ──
say ""
say "--- G1 control-byteeq + G2 lever (hexa_add/hexa_mul call-count OFF vs ON) ---"
kind_of() { case " $CONTROL " in *" $1 "*) echo CONTROL;; *) echo TARGET;; esac; }
for KN in $CONTROL $TARGET; do
  K="$WORK/$KN.hexa"; [ -f "$K" ] || { say "  [$KN] no kernel — skip"; continue; }
  KIND=$(kind_of "$KN")
  emit_one "$AP" 0 "$WORK/${KN}_off" "$K"
  emit_one "$AP" 1 "$WORK/${KN}_on"  "$K"
  for tag in off on; do
    s="$WORK/${KN}_${tag}.s"
    if [ -f "$s" ]; then
      add=$(grep -cE '\bcall\b.*hexa_add' "$s" 2>/dev/null | tr -d '\n')
      mul=$(grep -cE '\bcall\b.*hexa_mul' "$s" 2>/dev/null | tr -d '\n')
      mod=$(grep -cE '\bcall\b.*hexa_mod' "$s" 2>/dev/null | tr -d '\n')
      say "  [$KN/$KIND] $tag: hexa_add=$add hexa_mul=$mul hexa_mod=$mod"
      if [ "$tag" = off ]; then ADD_OFF[$KN]=$add; MUL_OFF[$KN]=$mul; else ADD_ON[$KN]=$add; MUL_ON[$KN]=$mul; fi
    else say "  [$KN/$KIND] $tag: NO .s — emit failed:"; tail -6 "$s.log" 2>/dev/null | sed 's/^/      /' | tee -a "$RESULT"; fi
  done
  # asm byte-diff + control G1 (OFF .o == ON .o)
  if [ -f "$WORK/${KN}_off.s" ] && [ -f "$WORK/${KN}_on.s" ]; then
    if cmp -s "$WORK/${KN}_off.s" "$WORK/${KN}_on.s"; then ASM_EQ[$KN]=EQ; else ASM_EQ[$KN]=DIFF; fi
  else ASM_EQ[$KN]="?"; fi
  if [ "$KIND" = CONTROL ]; then
    if [ -f "$WORK/${KN}_off.o" ] && [ -f "$WORK/${KN}_on.o" ]; then
      if cmp -s "$WORK/${KN}_off.o" "$WORK/${KN}_on.o"; then G1[$KN]=PASS; say "  [$KN] G1 CONTROL-BYTEEQ=PASS (flip inert here — CONFIRMED)"
      else G1[$KN]=FAIL; say "  [$KN] G1 CONTROL-BYTEEQ=FAIL (FLIP LEAKED into control — SHIP-BLOCK)"; cmp -l "$WORK/${KN}_off.o" "$WORK/${KN}_on.o" 2>/dev/null | head -10 | sed 's/^/      /' | tee -a "$RESULT"; fi
    else G1[$KN]="?"; say "  [$KN] G1 .o missing (degraded)"; fi
  else
    if [ "${ASM_EQ[$KN]}" = DIFF ]; then say "  [$KN] asm OFF!=ON (flip LIVE on target — expected)"; else say "  [$KN] ⚠ asm OFF==ON (flip had NO effect on this target — coverage gap, see kernel note)"; fi
  fi
done

# ── G3 + G4 — link (-nostartfiles), median CPU ratio, parity ──
say ""
say "--- G3 ratio + G4 parity ---"
link_run() { local kn="$1" tag="$2"; local o="$WORK/${kn}_${tag}.o" b="$WORK/${kn}_${tag}.bin"
    [ -f "$o" ] || { say "  [$kn] $tag: no .o"; return; }
    [ -n "$RT" ] || { say "  [$kn] $tag: no runtime.a → skip link"; return; }
    # -nostartfiles: runtime.a carries its own own-start `_start`; the default
    # Scrt1.o `_start` otherwise collides (multiple definition). (l4-nostart fix.)
    gcc -O2 -nostartfiles "$o" "$RT" -lm -o "$b" 2>"$b.ld.log" || { say "  [$kn] $tag: gcc link FAIL"; tail -6 "$b.ld.log" | sed 's/^/      /' | tee -a "$RESULT"; return; }
    local out vals=() t med; out=$("$b" 2>/dev/null)
    for r in 1 2 3 4 5; do t=$( { /usr/bin/time -v taskset -c 3 "$b" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s+0}'); vals+=("$t"); done
    med=$(printf '%s\n' "${vals[@]}" | sort -n | sed -n '3p')
    say "  [$kn] $tag: output=$out median_cpu_s=$med"; eval "OUT_${kn}_${tag}=\$out"; eval "MED_${kn}_${tag}=\$med"; }
for KN in $CONTROL $TARGET; do
  [ -f "$WORK/$KN.hexa" ] || continue
  link_run "$KN" off; link_run "$KN" on
  oo="OUT_${KN}_off"; on="OUT_${KN}_on"; mo="MED_${KN}_off"; mn="MED_${KN}_on"
  if [ "${!oo:-x}" = "${!on:-y}" ]; then PARITY[$KN]=OK; say "  [$KN] G4 PARITY=OK (${!oo:-?})"; else PARITY[$KN]=FAIL; say "  [$KN] G4 PARITY=FAIL off=${!oo:-?} on=${!on:-?}"; fi
  r=$(awk -v a="${!mn:-0}" -v b="${!mo:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')
  RATIO[$KN]=$r; say "  [$KN] G3 ratio ON/OFF (cpu) = $r"
done

# ── G5 — ship smoke ──
say ""
say "--- G5 ship smoke ($FLAG=1) ---"
HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
if [ -x "$HX" ]; then
    say "  version: $(HEXA_UNBOX_HIR_CALLTYPE=1 "$HX" --version 2>&1 | head -1)"
    printf 'fn main(){println("hello")}\n' > "$WORK/hello.hexa"; printf 'fn main(){exit(42)}\n' > "$WORK/e42.hexa"
    ( cd "$WORK"; HEXA_UNBOX_HIR_CALLTYPE=1 "$HX" run hello.hexa >h.out 2>h.err; say "  hello rc=$? out=$(cat h.out 2>/dev/null)" )
    ( cd "$WORK"; HEXA_UNBOX_HIR_CALLTYPE=1 "$HX" run e42.hexa >/dev/null 2>e.err; say "  exit42 rc=$?" )
else say "  hexa not found ($HX)"; fi

# ── SUMMARY table + FLIP verdict ──
say ""
say "=== SUMMARY (kind | add off→on | mul off→on | asm | ratio ON/OFF | parity | G1) ==="
say "$(printf '%-12s %-8s %-12s %-12s %-6s %-8s %-8s %s' KERNEL KIND add mul asm ratio parity ctrl-byteeq)"
tgt_prod=1; tgt_n=0; tgt_worst=0; ctrl_bad=0; parity_bad=0
for KN in $CONTROL $TARGET; do
  [ -f "$WORK/$KN.hexa" ] || continue
  KIND=$(kind_of "$KN")
  a="${ADD_OFF[$KN]:-?}→${ADD_ON[$KN]:-?}"; m="${MUL_OFF[$KN]:-?}→${MUL_ON[$KN]:-?}"
  r="${RATIO[$KN]:-NA}"; p="${PARITY[$KN]:-?}"; g1="${G1[$KN]:-n/a}"; ae="${ASM_EQ[$KN]:-?}"
  say "$(printf '%-12s %-8s %-12s %-12s %-6s %-8s %-8s %s' "$KN" "$KIND" "$a" "$m" "$ae" "$r" "$p" "$g1")"
  [ "$p" = FAIL ] && parity_bad=$((parity_bad+1))
  [ "$KIND" = CONTROL ] && [ "$g1" = FAIL ] && ctrl_bad=$((ctrl_bad+1))
  if [ "$KIND" = TARGET ] && awk -v x="$r" 'BEGIN{exit !(x+0>0)}' 2>/dev/null; then
    tgt_prod=$(awk -v p="$tgt_prod" -v x="$r" 'BEGIN{printf "%.6f",p*x}'); tgt_n=$((tgt_n+1))
    awk -v x="$r" -v w="$tgt_worst" 'BEGIN{exit !(x>w)}' && tgt_worst=$r
  fi
done
GEO=$(awk -v p="$tgt_prod" -v n="$tgt_n" 'BEGIN{if(n>0)printf "%.3f",exp(log(p)/n); else print "NA"}')
say ""
say "  TARGET geomean ratio ON/OFF = $GEO   worst TARGET ratio = ${tgt_worst:-NA}"
say "  CONTROL byteeq failures = $ctrl_bad   parity failures = $parity_bad"
VERDICT="FLIP-NOT-READY"
if [ "$ctrl_bad" = 0 ] && [ "$parity_bad" = 0 ] \
   && awk -v g="$GEO" 'BEGIN{exit !(g!="NA" && g+0<1.0)}' \
   && awk -v w="$tgt_worst" 'BEGIN{exit !(w+0<=1.02 && w+0>0)}'; then VERDICT="FLIP-READY (local probe; PR-CI byteeq 3-target is the ship gate)"; fi
say "  ⇒ VERDICT: $VERDICT"
say "=== DONE — artifacts under $WORK ==="
