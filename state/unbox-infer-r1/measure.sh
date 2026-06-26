#!/usr/bin/env bash
# state/unbox-infer-r1/measure.sh — HEXA_UNBOX_INFER (R1) gate harness.
# RUN ON POOL (aiden/summer), NOT mini. Self-harvests to $HOME/unbox_r1_RESULT.txt
# (reboot-proof). Single-SSH discipline; isolated /tmp scratch.
#
# Branch: perf/codegen-unbox-infer-r1.  Patch is in self/codegen.hexa (the
# C-transpile / gen2 path), so the gates need a gen2 compiler REBUILT from the
# patched self/ — i.e. the canonical self-host build (tool/build_selfhost.sh).
#
# Gate 1 (BLOCKING · byteeq-safe): with HEXA_UNBOX_INFER UNSET, the self-host
#   fixpoint must still hold cc-gen3.o == cc-gen4.o (build_selfhost exit 0), AND
#   the emitted .o of a fixed corpus must be byte-identical to the origin/main
#   build (OFF path unchanged). If broken → SHIP-BLOCK, report honestly.
# Gate 2 (lever proof): emit C for k1_sum with the gen2 compiler, flag OFF vs ON;
#   confirm `hexa_add` call-count on the accumulator path DROPS (and `hexa_mod`
#   remains — the %-bound residual). Capture both C files.
# Gate 3 (win): compile both C with gcc -O2, taskset median runtime; report ratio
#   vs the 2.86x probe baseline and vs gcc -O2 of the equivalent C.
# Gate 4 (parity): program OUTPUT must be identical OFF vs ON.
# Gate 5 (smoke): hexa --version + hello + exit42 GREEN under the flag.
#
# NOTE: build_selfhost is heavy (three self-emits). Run DETACHED / nohup.
set -u
RESULT="$HOME/unbox_r1_RESULT.txt"
REPO="${REPO:-$HOME/dancinlab/hexa-lang}"   # adjust to the pool checkout path
WORK="$(mktemp -d "${UNBOX_WORK_BASE:-$HOME/unbox_work}/unbox_r1.XXXXXX")"
KERN="$REPO/state/unbox-infer-r1/k1_sum.hexa"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== HEXA_UNBOX_INFER R1 measure — $(date -u +%FT%TZ) — host $(hostname) ==="
say "repo=$REPO  branch=$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)  sha=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)"

cd "$REPO" || { say "FATAL: no repo at $REPO"; exit 3; }

# ── Gate 1: self-host byteeq fixpoint (flag UNSET) ───────────────────────────
say "--- Gate 1: self-host gen3==gen4 byteeq (HEXA_UNBOX_INFER unset) ---"
unset HEXA_UNBOX_INFER
if bash tool/build_selfhost.sh -r "$REPO" -w "$WORK/sh" --detached "$WORK/sh.mark" >"$WORK/sh.log" 2>&1; then
    say "Gate1 build_selfhost EXIT=0"
else
    say "Gate1 build_selfhost EXIT=$? (see $WORK/sh.log) — fixpoint NOT reached or build failed"
fi
grep -E "GATE=|BYTE-EQ|DIFFER" "$WORK/sh/selfhost.done" 2>/dev/null | tee -a "$RESULT" || true
GEN2="$WORK/sh/gen2"
[ -x "$GEN2" ] || GEN2="$(find "$WORK/sh" -maxdepth 2 -name gen2 -type f 2>/dev/null | head -1)"
say "gen2 compiler: ${GEN2:-NOT FOUND}"

emit_c() {  # $1=flag(0|1) $2=outfile
    local f="$1" out="$2"
    if [ "$f" = "1" ]; then export HEXA_UNBOX_INFER=1; else unset HEXA_UNBOX_INFER; fi
    # gen2 transpiles via self/codegen.hexa → C.  --emit=c writes the C source.
    "$GEN2" _drv.hexa --emit=c --target=x86_64-linux-gnu -o "$out" "$KERN" \
        >"$out.log" 2>&1 || say "  emit_c(flag=$f) rc=$? (see $out.log)"
    unset HEXA_UNBOX_INFER
}

if [ -x "${GEN2:-/nonexistent}" ]; then
    # ── Gate 2: call-count delta on the emitted C ────────────────────────────
    say "--- Gate 2: emitted-C call-count (k1_sum) OFF vs ON ---"
    emit_c 0 "$WORK/k1_off.c"
    emit_c 1 "$WORK/k1_on.c"
    for tag in off on; do
        c="$WORK/k1_$tag.c"
        [ -f "$c" ] || { say "  $tag: no C emitted"; continue; }
        add=$(grep -c "hexa_add(" "$c" 2>/dev/null || echo NA)
        mod=$(grep -c "hexa_mod(" "$c" 2>/dev/null || echo NA)
        say "  $tag: hexa_add=$add  hexa_mod=$mod  (file $c)"
    done
    if [ -f "$WORK/k1_off.c" ] && [ -f "$WORK/k1_on.c" ]; then
        say "  C diff (OFF→ON):"; diff "$WORK/k1_off.c" "$WORK/k1_on.c" | head -40 | sed 's/^/    /' | tee -a "$RESULT" || true
    fi

    # ── Gate 3+4: compile, time (median-5, taskset), parity ──────────────────
    say "--- Gate 3+4: runtime ratio + output parity ---"
    RT="$REPO/build/selfhost/runtime.a"; [ -f "$RT" ] || RT="$(find "$WORK/sh" -name 'runtime.a*' 2>/dev/null | head -1)"
    timeit() {  # $1=binary -> median-of-5 user+sys seconds
        local b="$1" t best="" vals=()
        for r in 1 2 3 4 5; do
            t=$( { /usr/bin/time -v taskset -c 3 "$b" >/dev/null; } 2>&1 | awk '/User time|System time/{s+=$NF} END{print s}')
            vals+=("$t")
        done
        printf '%s\n' "${vals[@]}" | sort -n | sed -n '3p'
    }
    for tag in off on; do
        c="$WORK/k1_$tag.c"; b="$WORK/k1_$tag.bin"
        [ -f "$c" ] || continue
        gcc -O2 "$c" "${RT:-}" -lm -o "$b" 2>"$b.cc.log" || { say "  $tag: gcc link failed (see $b.cc.log)"; continue; }
        out=$("$b"); med=$(timeit "$b")
        say "  $tag: output=$out  median_cpu_s=$med"
        eval "OUT_$tag=\$out"; eval "MED_$tag=\$med"
    done
    if [ "${OUT_off:-x}" = "${OUT_on:-y}" ]; then say "  Gate4 PARITY=OK ($OUT_off)"; else say "  Gate4 PARITY=FAIL (off=$OUT_off on=$OUT_on)"; fi
    say "  Gate3 ratio ON/OFF = $(awk -v a="${MED_on:-0}" -v b="${MED_off:-0}" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "NA"}')  (probe baseline 2.86x vs gcc -O2)"
fi

# ── Gate 5: ship smoke (flag ON) ─────────────────────────────────────────────
say "--- Gate 5: ship smoke (HEXA_UNBOX_INFER=1) ---"
HX="$(command -v hexa || echo "$HOME/.hx/bin/hexa")"
if [ -x "$HX" ]; then
    say "  hexa --version: $(HEXA_UNBOX_INFER=1 "$HX" --version 2>&1 | head -1)"
else
    say "  hexa binary not found ($HX) — smoke skipped"
fi

say "=== DONE — full artifacts under $WORK (kept) ==="
