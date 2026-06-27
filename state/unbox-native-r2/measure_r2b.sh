#!/usr/bin/env bash
# state/unbox-native-r2/measure_r2b.sh — HEXA_UNBOX_ARRAY_NATIVE r2b gate harness.
#
# RUN DETACHED ON POOL (aiden), NOT mini. Self-harvests to $HOME/r2b_RESULT.txt
# (reboot-proof). Single-SSH; isolated $HOME/r2b_arru scratch (NOT /tmp).
#
# r2b = index-provenance threading. r2-pre measured the flag INERT (codegen guard
# never saw typed-prim-array ∧ int-idx joint signal). This run:
#  PROBE  — HEXA_ARRU_DEBUG=1 dumps cont.type_id + idx.provint at each index site
#           (does the container reach codegen as type_id 101..104?).
#  Gate1  — OFF byteeq: patched flag-OFF .o == baseline origin/main .o (same cwd).
#  Gate2  — lever: aprime native asm `call hexa_index_get/set` count OFF vs ON
#           + coupled spill count (re-baseline 32/36). WIN = ON << OFF.
#  Gate3  — runtime ratio ON/OFF, taskset median-5. WIN expects <1.0 (k3 26.9× gap).
#  Gate4  — output parity OFF==ON (int array = bit-exact).
#  Gate5  — ship smoke (hexa --version + hello + exit42).
set -u
RESULT="$HOME/r2b_RESULT.txt"
CANON="${CANON:-$HOME/hexa-lang}"
WORK="${WORK:-$HOME/r2b_arru}"
BR="${BR:-perf/codegen-unbox-array-r2b}"
BASE="${BASE:-origin/main}"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== HEXA_UNBOX_ARRAY_NATIVE r2b measure — $(date -u +%FT%TZ) — $(hostname) ==="

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

say "--- building patched aprime_cc (r2b) ---"
build_aprime_at "$WORK/aprime_cc" "$SRC" && say "  patched build EXIT=0" || { say "  patched build EXIT=$?"; tail -30 "$WORK/aprime_cc.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"; [ -x "$AP" ] || { say "FATAL: patched aprime_cc not built"; exit 4; }

say "--- building baseline aprime_cc ($BASE) ---"
[ -d "$BSRC" ] && { build_aprime_at "$WORK/aprime_base" "$BSRC" && say "  baseline build EXIT=0" || { say "  baseline build EXIT=$?"; tail -20 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }; }
APB="$WORK/aprime_base"; [ -x "$APB" ] || say "  (baseline aprime missing — Gate1 baseline cmp will skip)"

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

# ── kernel: k3_arrmap (the 26.9× array-index slice) ──
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

emit_native() { local cc="$1" f="$2" out="$3" src="$4"
    ( cd "$src"
      if [ "$f" = 1 ]; then export HEXA_UNBOX_ARRAY_NATIVE=1; else unset HEXA_UNBOX_ARRAY_NATIVE; fi
      "$cc" --emit=asm --target=x86_64-linux-gnu -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      "$cc" --emit=obj --target=x86_64-linux-gnu -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" )
}

# ── PROBE — provenance trace (where does the joint signal break?) ──
say "--- PROBE HEXA_ARRU_DEBUG (cont.type_id + idx.provint at index sites) ---"
( cd "$SRC"; HEXA_ARRU_DEBUG=1 HEXA_UNBOX_ARRAY_NATIVE=1 "$AP" --emit=asm --target=x86_64-linux-gnu -o "$WORK/probe.s" "$KERN" ) 2>"$WORK/probe.dbg" >/dev/null || true
grep '\[ARRU\]' "$WORK/probe.dbg" 2>/dev/null | sort | uniq -c | sed 's/^/  /' | tee -a "$RESULT"
[ -s "$WORK/probe.dbg" ] || say "  (no ARRU probe output — eprintln/gate?)"

# ── Gate 1 — OFF-path byteeq (BLOCKING, SAME-CWD) ──
say "--- Gate1 OFF byteeq (same-cwd: patched flag-OFF .o == baseline .o) ---"
CMPDIR="$WORK/cmp"; rm -rf "$CMPDIR"; mkdir -p "$CMPDIR"; cp "$KERN" "$CMPDIR/k.hexa"
( cd "$CMPDIR"; unset HEXA_UNBOX_ARRAY_NATIVE; "$AP" --emit=obj --target=x86_64-linux-gnu -o "$CMPDIR/p_off.o" "$CMPDIR/k.hexa" >"$CMPDIR/p.o.log" 2>&1 || echo "p emit rc=$?" )
if [ -x "$APB" ]; then ( cd "$CMPDIR"; unset HEXA_UNBOX_ARRAY_NATIVE; "$APB" --emit=obj --target=x86_64-linux-gnu -o "$CMPDIR/b_off.o" "$CMPDIR/k.hexa" >"$CMPDIR/b.o.log" 2>&1 || echo "b emit rc=$?" ); fi
emit_native "$AP" 0 "$WORK/p_off" "$SRC"
if [ -f "$CMPDIR/p_off.o" ] && [ -f "$CMPDIR/b_off.o" ]; then
    PSHA=$(sha256sum "$CMPDIR/p_off.o" | cut -c1-16); BSHA=$(sha256sum "$CMPDIR/b_off.o" | cut -c1-16)
    if cmp -s "$CMPDIR/p_off.o" "$CMPDIR/b_off.o"; then
        say "  Gate1 OFF-BYTEEQ=PASS  patched-OFF .o == baseline .o  sha=$PSHA (release-safe)"
    else
        say "  Gate1 OFF-BYTEEQ=FAIL  patched=$PSHA baseline=$BSHA"
        objcopy -O binary --only-section=.text "$CMPDIR/p_off.o" "$CMPDIR/pt.bin" 2>/dev/null
        objcopy -O binary --only-section=.text "$CMPDIR/b_off.o" "$CMPDIR/bt.bin" 2>/dev/null
        if cmp -s "$CMPDIR/pt.bin" "$CMPDIR/bt.bin"; then
            say "    .text IDENTICAL — residual = non-code ELF metadata (DWARF/comp_dir)"
        else
            say "    .text DIFFERS — real OFF-path codegen leak:"
            "$APB" --emit=asm --target=x86_64-linux-gnu -o "$CMPDIR/b_off.s" "$CMPDIR/k.hexa" >/dev/null 2>&1 || true
            "$AP"  --emit=asm --target=x86_64-linux-gnu -o "$CMPDIR/p_off.s" "$CMPDIR/k.hexa" >/dev/null 2>&1 || true
            diff "$CMPDIR/b_off.s" "$CMPDIR/p_off.s" 2>/dev/null | head -40 | sed 's/^/      /' | tee -a "$RESULT"
        fi
    fi
else say "  Gate1 .o missing (degraded) — see $CMPDIR/*.log"; fi

# ── Gate 2 — lever: index-call-count + spill OFF vs ON ──
say "--- Gate2 lever (hexa_index_* call-count + spill OFF vs ON) ---"
emit_native "$AP" 1 "$WORK/p_on" "$SRC"
for tag in off on; do
    s="$WORK/p_$tag.s"
    if [ -f "$s" ]; then
        ig=$(grep -cE '\bcall\b.*hexa_index_get' "$s" 2>/dev/null || echo NA)
        is=$(grep -cE '\bcall\b.*hexa_index_set' "$s" 2>/dev/null || echo NA)
        sp=$(grep -cE 'rbp - [0-9]+\]|rbp\+|\[rbp' "$s" 2>/dev/null || echo NA)
        say "  patched $tag: hexa_index_get=$ig hexa_index_set=$is rbp-spill-refs=$sp ($s)"
    else say "  patched $tag: no .s (see $s.log)"; tail -8 "$s.log" 2>/dev/null | sed 's/^/      /' | tee -a "$RESULT"; fi
done
if [ -f "$WORK/p_off.s" ] && [ -f "$WORK/p_on.s" ]; then
    if cmp -s "$WORK/p_off.s" "$WORK/p_on.s"; then
        say "  ⚠ patched asm OFF==ON byte-identical — flag had NO EFFECT (threading still broken — see PROBE)"
    else
        say "  patched asm OFF!=ON (arru fast-path LIVE). diff head:"; diff "$WORK/p_off.s" "$WORK/p_on.s" | head -60 | sed 's/^/    /' | tee -a "$RESULT"
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
say "  Gate3 ratio ON/OFF (cpu) = $(awk -v a="${MED_on:-0}" -v b="${MED_off:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')   [r2b expects <1.0; probe gap 26.9×]"

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
