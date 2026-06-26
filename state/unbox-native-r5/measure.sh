#!/usr/bin/env bash
# state/unbox-native-r5/measure.sh — HEXA_UNBOX_NATIVE (r5) gate harness.
#
# RUN DETACHED ON POOL (aiden/summer), NOT mini. Self-harvests to
# $HOME/r5_native_RESULT.txt (reboot-proof). Single-SSH discipline; isolated
# $HOME/r5_native scratch (NOT /tmp).
#
# ── WHAT R5 IS (vs the R1 NEGATIVE) ──────────────────────────────────────────
# R1 (HEXA_UNBOX_INFER) patched self/codegen.hexa = the gen2 C-transpile codegen.
# MEASURED NEGATIVE: the probe's 2.9–23× gap was on the APRIME NATIVE backend
# (compiler/codegen/x86_64_linux.hexa, `--emit=obj`), which never reads
# self/codegen.hexa → flag inert, aprime asm OFF==ON byte-identical (memory
# project_hexa_codegen_two_backend_path_mismatch). R5 patches the CORRECT
# backend: compiler/codegen/x86_64_linux.hexa _STMT_BINOP. So here OFF==ON on
# the NATIVE path is EXPECTED ONLY for Gate-1 (flag OFF); with the flag ON the
# lever (hexa_add/hexa_mul call-count) MUST drop — that is the whole point.
#
# Gates:
#  1 (OFF byteeq) — patched aprime, flag OFF: native .o byte-identical to the
#                   origin/main-baseline aprime .o for the SAME kernel. BLOCKING
#                   ship gate (proves OFF-path emit unchanged). Full 3-target
#                   gen3≡gen4 byteeq is the PR-CI job; this is the local probe.
#  2 (lever)      — aprime native asm `call hexa_add_slow`/`hexa_mul` count
#                   OFF vs ON. WIN = ON < OFF on the accumulator path.
#  3 (win)        — link CPU runtime.a, taskset median CPU, ratio ON/OFF + vs
#                   the 2.86× gcc-O2 baseline of record.
#  4 (parity)     — program output identical OFF vs ON (+ vs baseline build).
#  5 (smoke)      — hexa --version + hello + exit42 under the flag.
set -u
RESULT="$HOME/r5_native_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"        # canonical seed checkout (gitignored seeds)
WORK="${WORK:-$HOME/r5_native}"          # isolated dir (NOT /tmp)
BR="${BR:-perf/codegen-unbox-native-r5}"
BASE="${BASE:-origin/main}"              # OFF-byteeq baseline ref
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== HEXA_UNBOX_NATIVE r5 measure (APRIME native backend) — $(date -u +%FT%TZ) — $(hostname) ==="

# ── 0. wait for load<6 (no-starve), cap ~40min ──
say "--- waiting for load<6 (no-starve) ---"
for w in $(seq 1 80); do
    L=$(awk '{print $1}' /proc/loadavg); Li=${L%.*}
    if [ "${Li:-99}" -lt 6 ]; then say "  load=$L OK after ${w} probe(s)"; break; fi
    [ "$w" = 80 ] && say "  load stayed high (last=$L) — proceeding after 40min cap"
    sleep 30
done

# ── helper: build an aprime_cc from a given ref into $1 (out) using $2 (src) ──
build_aprime_at() { # $1=outbin $2=srcdir
    local out="$1" src="$2"
    ( cd "$src"
      bash tool/build_aprime.sh -o "$out" -r "$src" ) >"$WORK/$(basename "$out").log" 2>&1
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
git -C "$CANON" fetch origin "$BR" 2>>"$WORK/git.log" || say "  (fetch BR warn)"
git -C "$CANON" fetch origin main 2>>"$WORK/git.log" || say "  (fetch main warn)"
git -C "$CANON" worktree add --detach "$WORK/src"  "origin/$BR"  2>>"$WORK/git.log" \
    || git clone -b "$BR" "$CANON" "$WORK/src" 2>>"$WORK/git.log" || { say "FATAL clone BR"; exit 3; }
git -C "$CANON" worktree add --detach "$WORK/base" "$BASE"       2>>"$WORK/git.log" \
    || git clone "$CANON" "$WORK/base" 2>>"$WORK/git.log" || say "  (base worktree warn — Gate1 may skip)"
SRC="$WORK/src"; BSRC="$WORK/base"
say "  SRC=$SRC  sha=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"
say "  BASE=$BSRC sha=$(git -C "$BSRC" rev-parse --short HEAD 2>/dev/null)"
prep_seeds "$SRC"; prep_seeds "$BSRC"

# ── 2. build patched + baseline aprime_cc (linux-safe: no -arch) ──
say "--- building patched aprime_cc (r5 native backend) ---"
build_aprime_at "$WORK/aprime_cc" "$SRC" && say "  patched build EXIT=0" || { say "  patched build EXIT=$?"; tail -25 "$WORK/aprime_cc.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"; [ -x "$AP" ] || { say "FATAL: patched aprime_cc not built"; exit 4; }

say "--- building baseline aprime_cc ($BASE) ---"
if [ -d "$BSRC" ]; then
    build_aprime_at "$WORK/aprime_base" "$BSRC" && say "  baseline build EXIT=0" || { say "  baseline build EXIT=$?"; tail -25 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }
fi
APB="$WORK/aprime_base"; [ -x "$APB" ] || say "  (baseline aprime missing — Gate1 baseline cmp will skip)"

# ── CPU runtime.a (r1b fix: the PATCHED build emits a CPU runtime.a at
# $SRC/build/runtime.a (~1MB) — prefer it. The default ~/.hx/bin runtime.a may be
# CUDA-linked (cudaMalloc/__popcountdi2 undef under bare ld), so CUDA-tagged
# archives are de-prioritized but NOT outright rejected when they are the only
# candidate (a real undef shows loudly at the gcc-as-linker step, not silently). ──
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
say "  runtime.a = ${RT:-NONE} ($( [ -n "$RT" ] && stat -c%s "$RT" 2>/dev/null || echo 0) bytes)"

# ── kernel: k1_sum (the 2.86× scalar slice) ──
KERN="$WORK/k1_sum.hexa"
printf 'fn main() {\n    let M = 1000000007\n    let mut s = 0\n    let N = 200000000\n    for i in 0..N {\n        s = (s + i * 1009) %% M\n    }\n    println(s)\n}\n' | sed 's/%%/%/' > "$KERN"
say "  kernel = $KERN (k1_sum, N=2e8)"

emit_native() { # $1=compiler $2=flag $3=outbase $4=srcdir
    local cc="$1" f="$2" out="$3" src="$4"
    ( cd "$src"
      if [ "$f" = 1 ]; then export HEXA_UNBOX_NATIVE=1; else unset HEXA_UNBOX_NATIVE; fi
      "$cc" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      if [ "$f" = 1 ]; then export HEXA_UNBOX_NATIVE=1; else unset HEXA_UNBOX_NATIVE; fi
      "$cc" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" )
}

# ── Gate 1 — OFF-path byteeq (BLOCKING) ──
say "--- Gate1 OFF byteeq (patched flag-OFF .o == baseline .o) ---"
emit_native "$AP" 0 "$WORK/p_off" "$SRC"
[ -x "$APB" ] && emit_native "$APB" 0 "$WORK/b_off" "$BSRC"
if [ -f "$WORK/p_off.o" ] && [ -f "$WORK/b_off.o" ]; then
    if cmp -s "$WORK/p_off.o" "$WORK/b_off.o"; then
        say "  Gate1 OFF-BYTEEQ=PASS  patched-OFF .o == baseline .o  sha=$(sha256sum "$WORK/p_off.o" | cut -c1-16)"
    else
        say "  Gate1 OFF-BYTEEQ=FAIL  patched-OFF .o != baseline .o (OFF-path NOT byte-identical — SHIP-BLOCK)"
        say "    patched sha=$(sha256sum "$WORK/p_off.o" | cut -c1-16) baseline sha=$(sha256sum "$WORK/b_off.o" | cut -c1-16)"
        # r1b root-cause: dump the .s diff (patched-OFF vs baseline-OFF) so the
        # EXACT instruction delta is captured — proves whether it is k1_sum LIR
        # (my patch leaks) or a benign emitter-determinism factor (label/order).
        if [ -f "$WORK/p_off.s" ] && [ -f "$WORK/b_off.s" ]; then
            if cmp -s "$WORK/p_off.s" "$WORK/b_off.s"; then
                say "    NOTE: .s IDENTICAL but .o differs → non-text delta (reloc/symtab/timestamp/order), NOT k1_sum codegen"
            else
                say "    .s DIFFERS (k1_sum codegen changed when OFF) — diff head:"
                diff "$WORK/b_off.s" "$WORK/p_off.s" | head -40 | sed 's/^/      /' | tee -a "$RESULT"
            fi
        fi
        # also: does baseline emit a .o at all (sanity) + objdump section sizes
        say "    objdump -h sizes (baseline | patched-OFF):"
        objdump -h "$WORK/b_off.o" 2>/dev/null | awk '/\.text|\.data|\.rodata|\.rela/{print "      base "$2" "$3}' | tee -a "$RESULT"
        objdump -h "$WORK/p_off.o" 2>/dev/null | awk '/\.text|\.data|\.rodata|\.rela/{print "      patc "$2" "$3}' | tee -a "$RESULT"
    fi
else
    # fallback: patched OFF asm vs patched ON asm SHOULD differ (proves flag live);
    # and patched-OFF asm self-consistency. Baseline .o missing → degraded gate.
    say "  Gate1 baseline .o missing — degraded (cannot prove OFF==baseline). See logs."
fi

# ── Gate 2 — lever: native call-count OFF vs ON ──
say "--- Gate2 lever (native asm hexa_* call-count OFF vs ON) ---"
emit_native "$AP" 1 "$WORK/p_on" "$SRC"
for tag in off on; do
    s="$WORK/p_$tag.s"
    if [ -f "$s" ]; then
        add=$(grep -cE '\bcall\b.*hexa_add' "$s" 2>/dev/null || echo NA)
        mul=$(grep -cE '\bcall\b.*hexa_mul' "$s" 2>/dev/null || echo NA)
        mod=$(grep -cE '\bcall\b.*hexa_mod' "$s" 2>/dev/null || echo NA)
        cmpc=$(grep -cE '\bcall\b.*hexa_cmp' "$s" 2>/dev/null || echo NA)
        say "  patched $tag: hexa_add=$add hexa_mul=$mul hexa_mod=$mod hexa_cmp=$cmpc ($s)"
    else say "  patched $tag: no .s (see $s.log)"; tail -8 "$s.log" 2>/dev/null | sed 's/^/      /' | tee -a "$RESULT"; fi
done
if [ -f "$WORK/p_off.s" ] && [ -f "$WORK/p_on.s" ]; then
    if cmp -s "$WORK/p_off.s" "$WORK/p_on.s"; then
        say "  ⚠ patched asm OFF==ON byte-identical — flag had NO EFFECT (k1_sum nodes not marked provably-int? see report)"
    else
        say "  patched asm OFF!=ON (flag LIVE on native path):"; diff "$WORK/p_off.s" "$WORK/p_on.s" | head -40 | sed 's/^/    /' | tee -a "$RESULT"
    fi
fi

# ── Gate 3+4 — runtime ratio + parity ──
say "--- Gate3+4 runtime ratio + parity ---"
link_run() { local tag="$1" o="$WORK/p_$tag.o" b="$WORK/p_$tag.bin"
    [ -f "$o" ] || { say "  $tag: no .o"; return; }
    [ -n "$RT" ] || { say "  $tag: no runtime.a → skip link"; return; }
    gcc -O2 "$o" "$RT" -lm -o "$b" 2>"$b.ld.log" || { say "  $tag: gcc link FAIL"; tail -6 "$b.ld.log" | sed 's/^/      /' | tee -a "$RESULT"; return; }
    local out vals=() t med; out=$("$b" 2>/dev/null)
    for r in 1 2 3 4 5; do t=$( { /usr/bin/time -v taskset -c 3 "$b" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s+0}'); vals+=("$t"); done
    med=$(printf '%s\n' "${vals[@]}" | sort -n | sed -n '3p')
    say "  patched $tag: output=$out median_cpu_s=$med"; eval "OUT_$tag=\$out"; eval "MED_$tag=\$med"; }
link_run off; link_run on
if [ "${OUT_off:-x}" = "${OUT_on:-y}" ]; then say "  Gate4 PARITY=OK (${OUT_off:-?})"; else say "  Gate4 PARITY=FAIL off=${OUT_off:-?} on=${OUT_on:-?}"; fi
say "  Gate3 ratio ON/OFF (cpu) = $(awk -v a="${MED_on:-0}" -v b="${MED_off:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')   [baseline of record: hexa 1.26s vs gcc-O2 0.44s = 2.86×]"

# ── Gate 5 — ship smoke ──
say "--- Gate5 ship smoke (HEXA_UNBOX_NATIVE=1) ---"
HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
if [ -x "$HX" ]; then
    say "  version: $(HEXA_UNBOX_NATIVE=1 "$HX" --version 2>&1 | head -1)"
    printf 'fn main(){println("hello")}\n' > "$WORK/hello.hexa"; printf 'fn main(){exit(42)}\n' > "$WORK/e42.hexa"
    ( cd "$WORK"; HEXA_UNBOX_NATIVE=1 "$HX" run hello.hexa >h.out 2>h.err; say "  hello rc=$? out=$(cat h.out 2>/dev/null)" )
    ( cd "$WORK"; HEXA_UNBOX_NATIVE=1 "$HX" run e42.hexa >/dev/null 2>e.err; say "  exit42 rc=$?" )
else say "  hexa not found ($HX)"; fi
say "=== DONE — artifacts under $WORK ==="
