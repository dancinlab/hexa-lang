#!/usr/bin/env bash
# state/unbox-native-r2/measure.sh — HEXA_UNBOX_ARRAY_NATIVE (r2) gate harness.
#
# RUN DETACHED ON POOL (summer/aiden), NOT mini. Self-harvests to
# $HOME/r2_arru_RESULT.txt (reboot-proof). Single-SSH discipline; isolated
# $HOME/r2_arru scratch (NOT /tmp).
#
# ── WHAT R2 IS ───────────────────────────────────────────────────────────────
# R1 (HEXA_UNBOX_NATIVE) unboxed scalar BINOPs on the APRIME NATIVE backend
# (compiler/codegen/x86_64_linux.hexa _STMT_BINOP). k1_sum was %-bound → ratio
# 1.0 (honest negative). R2 unboxes ARRAY INDEXING (op="index"/"index_set") on
# the SAME native backend: a provably-typed-prim-array container + provably-int
# index skips `call hexa_index_get/set` (box+tag-dispatch+VALSTRUCT-unwrap+bounds)
# and emits a native bounds-checked element load/store. probe k3_arrmap = 23.23×
# gap and is NOT %-bound → ratio < 1.0 (real speedup) EXPECTED.
#
# Gates:
#  1 (OFF byteeq) — patched aprime, flag OFF: native .o byte-identical to the
#                   origin/main-baseline aprime .o for the SAME kernel, SAME cwd
#                   (DWARF DW_AT_comp_dir artifact avoidance). BLOCKING ship gate.
#  2 (lever)      — aprime native asm `call hexa_index_get`/`hexa_index_set`
#                   count OFF vs ON. WIN = ON < OFF on the array-access path.
#  3 (win)        — link CPU runtime.a, taskset median CPU, ratio ON/OFF. R2
#                   EXPECTS ratio < 1.0 (real speedup, not %-bound like R1).
#  4 (parity)     — program output identical OFF vs ON (int array = bit-exact).
#  5 (smoke)      — hexa --version + hello + exit42 under the flag.
set -u
RESULT="$HOME/r2_arru_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"        # canonical seed checkout (gitignored seeds)
WORK="${WORK:-$HOME/r2_arru}"            # isolated dir (NOT /tmp)
BR="${BR:-perf/codegen-unbox-array-r2}"
BASE="${BASE:-origin/main}"              # OFF-byteeq baseline ref
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== HEXA_UNBOX_ARRAY_NATIVE r2 measure (APRIME native backend) — $(date -u +%FT%TZ) — $(hostname) ==="

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
say "--- building patched aprime_cc (r2 array-unbox backend) ---"
build_aprime_at "$WORK/aprime_cc" "$SRC" && say "  patched build EXIT=0" || { say "  patched build EXIT=$?"; tail -25 "$WORK/aprime_cc.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"; [ -x "$AP" ] || { say "FATAL: patched aprime_cc not built"; exit 4; }

say "--- building baseline aprime_cc ($BASE) ---"
if [ -d "$BSRC" ]; then
    build_aprime_at "$WORK/aprime_base" "$BSRC" && say "  baseline build EXIT=0" || { say "  baseline build EXIT=$?"; tail -25 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }
fi
APB="$WORK/aprime_base"; [ -x "$APB" ] || say "  (baseline aprime missing — Gate1 baseline cmp will skip)"

# ── CPU runtime.a ──
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

# ── kernel: k3_arrmap (the 23.23× array-index slice) ──
# Pre-sized typed [i64] array, tight read+write loop over provably-int idx.
# `xs: [i64]` makes the container type_id 101; `i`/`j` are i64 locals (type_id 1).
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
say "  kernel = $KERN (k3_arrmap, N=4096 REP=2e5)"

emit_native() { # $1=compiler $2=flag $3=outbase $4=srcdir
    local cc="$1" f="$2" out="$3" src="$4"
    ( cd "$src"
      if [ "$f" = 1 ]; then export HEXA_UNBOX_ARRAY_NATIVE=1; else unset HEXA_UNBOX_ARRAY_NATIVE; fi
      "$cc" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      "$cc" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" )
}

# ── Gate 1 — OFF-path byteeq (BLOCKING, SAME-CWD) ──
say "--- Gate1 OFF byteeq (same-cwd: patched flag-OFF .o == baseline .o) ---"
CMPDIR="$WORK/cmp"; rm -rf "$CMPDIR"; mkdir -p "$CMPDIR"
cp "$KERN" "$CMPDIR/k.hexa"
( cd "$CMPDIR"; unset HEXA_UNBOX_ARRAY_NATIVE
  "$AP"  _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$CMPDIR/p_off.o" "$CMPDIR/k.hexa" >"$CMPDIR/p.o.log" 2>&1 || echo "p emit rc=$?" )
( cd "$CMPDIR"; unset HEXA_UNBOX_ARRAY_NATIVE
  "$AP"  _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$CMPDIR/p_off.s" "$CMPDIR/k.hexa" >"$CMPDIR/p.s.log" 2>&1 || true )
if [ -x "$APB" ]; then
  ( cd "$CMPDIR"; unset HEXA_UNBOX_ARRAY_NATIVE
    "$APB" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o "$CMPDIR/b_off.o" "$CMPDIR/k.hexa" >"$CMPDIR/b.o.log" 2>&1 || echo "b emit rc=$?" )
fi
emit_native "$AP" 0 "$WORK/p_off" "$SRC"
if [ -f "$CMPDIR/p_off.o" ] && [ -f "$CMPDIR/b_off.o" ]; then
    PSHA=$(sha256sum "$CMPDIR/p_off.o" | cut -c1-16); BSHA=$(sha256sum "$CMPDIR/b_off.o" | cut -c1-16)
    if cmp -s "$CMPDIR/p_off.o" "$CMPDIR/b_off.o"; then
        say "  Gate1 OFF-BYTEEQ=PASS  patched-OFF .o == baseline .o  sha=$PSHA (same-cwd, OFF-path inert CONFIRMED)"
    else
        say "  Gate1 OFF-BYTEEQ=FAIL  patched-OFF .o != baseline .o (SHIP-BLOCK)  patched=$PSHA baseline=$BSHA"
        objcopy -O binary --only-section=.text "$CMPDIR/p_off.o" "$CMPDIR/pt.bin" 2>/dev/null
        objcopy -O binary --only-section=.text "$CMPDIR/b_off.o" "$CMPDIR/bt.bin" 2>/dev/null
        if cmp -s "$CMPDIR/pt.bin" "$CMPDIR/bt.bin"; then
            say "    .text IDENTICAL — residual is non-code ELF metadata (DWARF/comp_dir); cmp -l offsets:"
            cmp -l "$CMPDIR/p_off.o" "$CMPDIR/b_off.o" 2>/dev/null | head -20 | sed 's/^/      /' | tee -a "$RESULT"
        else
            say "    .text DIFFERS — real codegen leak when OFF; .s diff head:"
            "$APB" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o "$CMPDIR/b_off.s" "$CMPDIR/k.hexa" >/dev/null 2>&1 || true
            diff "$CMPDIR/b_off.s" "$CMPDIR/p_off.s" 2>/dev/null | head -40 | sed 's/^/      /' | tee -a "$RESULT"
        fi
    fi
else
    say "  Gate1 same-cwd .o missing — see $CMPDIR/*.log (degraded)"
fi

# ── Gate 2 — lever: native index-call-count OFF vs ON ──
say "--- Gate2 lever (native asm hexa_index_* call-count OFF vs ON) ---"
emit_native "$AP" 1 "$WORK/p_on" "$SRC"
for tag in off on; do
    s="$WORK/p_$tag.s"
    if [ -f "$s" ]; then
        ig=$(grep -cE '\bcall\b.*hexa_index_get' "$s" 2>/dev/null || echo NA)
        is=$(grep -cE '\bcall\b.*hexa_index_set' "$s" 2>/dev/null || echo NA)
        say "  patched $tag: hexa_index_get=$ig hexa_index_set=$is ($s)"
    else say "  patched $tag: no .s (see $s.log)"; tail -8 "$s.log" 2>/dev/null | sed 's/^/      /' | tee -a "$RESULT"; fi
done
if [ -f "$WORK/p_off.s" ] && [ -f "$WORK/p_on.s" ]; then
    if cmp -s "$WORK/p_off.s" "$WORK/p_on.s"; then
        say "  ⚠ patched asm OFF==ON byte-identical — flag had NO EFFECT (k3 nodes not marked typed-array/provably-int? type_id not reaching backend? see report)"
    else
        say "  patched asm OFF!=ON (flag LIVE on native path) — arru fast-path emitted. diff head:"; diff "$WORK/p_off.s" "$WORK/p_on.s" | head -50 | sed 's/^/    /' | tee -a "$RESULT"
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
if [ "${OUT_off:-x}" = "${OUT_on:-y}" ]; then say "  Gate4 PARITY=OK (${OUT_off:-?})"; else say "  Gate4 PARITY=FAIL off=${OUT_off:-?} on=${OUT_on:-?} (SOUNDNESS BLOCK)"; fi
say "  Gate3 ratio ON/OFF (cpu) = $(awk -v a="${MED_on:-0}" -v b="${MED_off:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')   [R2 expects <1.0 real speedup; probe gap 23.23×]"

# ── Gate 5 — ship smoke ──
say "--- Gate5 ship smoke (HEXA_UNBOX_ARRAY_NATIVE=1) ---"
HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
if [ -x "$HX" ]; then
    say "  version: $(HEXA_UNBOX_ARRAY_NATIVE=1 "$HX" --version 2>&1 | head -1)"
    printf 'fn main(){println("hello")}\n' > "$WORK/hello.hexa"; printf 'fn main(){exit(42)}\n' > "$WORK/e42.hexa"
    ( cd "$WORK"; HEXA_UNBOX_ARRAY_NATIVE=1 "$HX" run hello.hexa >h.out 2>h.err; say "  hello rc=$? out=$(cat h.out 2>/dev/null)" )
    ( cd "$WORK"; HEXA_UNBOX_ARRAY_NATIVE=1 "$HX" run e42.hexa >/dev/null 2>e.err; say "  exit42 rc=$?" )
else say "  hexa not found ($HX)"; fi
say "=== DONE — artifacts under $WORK ==="
