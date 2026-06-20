#!/usr/bin/env bash
# dispatch_valop_add_regen.sh — build-host driver for the sh-val-core EXTEND r1
# (rt_add_native) lane. Run on a build host (aiden/summer, x86_64 + qemu-aarch64).
#
# Does, in an ISOLATED unique worktree (no shared-main checkout race):
#   1) checkout the sh-val-core-add-native branch
#   2) build the native compiler (aprime_cc) via tool/build_aprime.sh
#   3) regen the 3 valop_core_*.s seeds from stdlib/runtime/valop_core.hexa
#      (must now export 4 syms incl rt_add_native)
#   4) focused micro-byteeq: compile valop_core_gate.c against the freshly-emitted
#      valop_core.o (native rt_add_native) + standalone runtime.c (C add oracle),
#      assert exit 25 (full pass) — captures native==C byte-Δ for the add prim
#   5) if all green, commit the regenerated seeds back to the branch + push
#
# Evidence is printed to stdout with [EVIDENCE] markers. Exit 0 = lane green.
set -uo pipefail

REPO_URL="https://github.com/dancinlab/hexa-lang.git"   # aiden has no SSH key
BRANCH="sh-val-core-add-native"
WT="$HOME/scratch-valadd-$$"   # unique per-run (collision guard, sh-str-scan lesson)
# A prebuilt native compiler (aprime_cc) may already exist from a prior valop
# lane; reusing it skips the ~6min self-emit build. The compiler only LOWERS the
# leaf intrinsics — it needs no knowledge of rt_add_native, so an older aprime_cc
# emits the new source correctly. Override with APRIME_PREBUILT=.
APRIME_PREBUILT="${APRIME_PREBUILT:-$HOME/scratch-valcore/build/aprime_cc}"

log() { printf '[valadd] %s\n' "$*"; }
ev()  { printf '[EVIDENCE] %s\n' "$*"; }

cleanup() { :; }   # keep the worktree on failure for inspection
trap cleanup EXIT

# ── 1) isolated checkout ────────────────────────────────────────────────
rm -rf "$WT"
git clone --no-checkout "$REPO_URL" "$WT" >/dev/null 2>&1 || { log "clone failed"; exit 1; }
cd "$WT" || exit 1
git fetch origin "$BRANCH" >/dev/null 2>&1
git checkout "$BRANCH" >/dev/null 2>&1 || { log "checkout $BRANCH failed"; exit 1; }
ev "HEAD=$(git rev-parse --short HEAD) branch=$BRANCH"

# ── 2) native compiler (aprime_cc) — reuse prebuilt, else build ──────────
export HEXA_RT_ALLOC_NATIVE=0   # dodge stage-5 smoke arena multiple-def (brcond memory)
APRIME=""
if [ -x "$APRIME_PREBUILT" ]; then
    APRIME="$APRIME_PREBUILT"
    ev "reusing prebuilt aprime_cc: $APRIME"
else
    HEXAT=""
    for c in "$WT/self/native/hexat" "$HOME/hexa-lang/build/hexat" "$HOME/.hx/dist/linux-x86_64/hexat" "$(command -v hexat 2>/dev/null)"; do
        [ -n "$c" ] && [ -x "$c" ] && { HEXAT="$c"; break; }
    done
    log "no prebuilt; building aprime_cc (hexat=$HEXAT)"
    if [ -n "$HEXAT" ]; then bash tool/build_aprime.sh -o build/aprime_cc -v "$HEXAT" 2>&1 | tail -25
    else                    bash tool/build_aprime.sh -o build/aprime_cc 2>&1 | tail -25; fi
    APRIME="$WT/build/aprime_cc"
fi
[ -x "$APRIME" ] || { log "aprime_cc unavailable"; exit 2; }

# ── 3) regen the 3 valop seeds ──────────────────────────────────────────
APRIME="$APRIME" CC="${CC:-clang}" bash tool/regen_valop_core_native_s.sh all 2>&1 | tail -20
# assert all 3 seeds now export rt_add_native (.globl)
ALLOK=1
for s in self/native/valop_core_x86_64.s self/native/valop_core_arm64.s self/native/valop_core_arm64-linux.s; do
    n=$(grep -E '^[[:space:]]*\.globl[[:space:]]+_?rt_add_native$' "$s" 2>/dev/null | wc -l | tr -d ' ')
    ev "seed $s .globl rt_add_native = $n"
    [ "$n" -ge 1 ] || ALLOK=0
done
[ "$ALLOK" = 1 ] || { log "a seed is missing rt_add_native"; exit 3; }

# CRITICAL #3714 guard: the arm64 seeds must contain ZERO `bl hexa_truthy`. A
# pre-#3714 aprime_cc lowers `if <bool-HexaVal>` (br_cond) via `bl hexa_truthy`,
# which recurses infinitely once the seed is default-ON → SIGSEGV on arm64
# self-host (the exact failure this guard prevents). x86_64 always inlined, so
# only arm64 is at risk. The compiler MUST be #3714-fixed (cbz inline).
for s in self/native/valop_core_arm64.s self/native/valop_core_arm64-linux.s; do
    # NB: `grep -c … || echo 0` is buggy (grep -c exits 1 on zero matches → prints
    # "0\n0"); count via grep|wc -l so a true 0 stays a clean single "0".
    nbl=$(grep -E 'bl[[:space:]]+_?hexa_truthy' "$s" 2>/dev/null | wc -l | tr -d ' ')
    ev "seed $s bl hexa_truthy = $nbl (MUST be 0 — #3714 recursion guard)"
    [ "$nbl" = 0 ] || { log "REGRESSION: $s has $nbl bl hexa_truthy → stale pre-#3714 compiler. ABORT (would SIGSEGV arm64 self-host)."; exit 5; }
done

# ── 4) focused micro-byteeq (x86_64 native add vs C add oracle) ──────────
# runtime.c is GENERATED (not checked in). Source it (+ runtime.h) from the
# prebuilt worktree's already-emitted copy; the gate (no HEXA_HAS_HEXA_RT_STDLIB)
# only needs the constructors + #else scalar bodies, so a runtime.c from any
# valop lane works — we compare the NEW seed's rt_add_native DIRECTLY (PART E)
# vs the C oracle in the gate itself.
PREBUILT_WT="$(dirname "$(dirname "$APRIME_PREBUILT")")"   # …/scratch-valcore
RT_C=""; RT_INC=""
for d in "$PREBUILT_WT/self" "$WT/self"; do
    [ -f "$d/runtime.c" ] && [ -f "$d/runtime.h" ] && { RT_C="$d/runtime.c"; RT_INC="$d"; break; }
done
[ -n "$RT_C" ] || { log "no generated runtime.c found (prebuilt=$PREBUILT_WT)"; exit 4; }
ev "runtime.c=$RT_C"

TMP="$(mktemp -d)"
"$APRIME" scripts/scratch/rt_native/_drv.hexa --emit=obj --target=x86_64-linux-gnu \
    -o "$TMP/valop_core.o" stdlib/runtime/valop_core.hexa 2>&1 | tail -5
ev "valop_core.o syms:"
nm "$TMP/valop_core.o" 2>/dev/null | grep -E ' T _?rt_(truthy|sub|mul|add)_native$' | sed 's/^/[EVIDENCE]   /'
# build the gate WITHOUT HEXA_HAS_HEXA_RT_STDLIB → pure-C #else wrappers, compare
# the native seed fns DIRECTLY (PART A/B/C/E) against the C oracle (self-contained).
GATE_BIN="$TMP/vgate"
if clang -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_VALOP_NATIVE=1 -I "$RT_INC" \
        scripts/scratch/rt_native/valop_core_gate.c "$RT_C" "$TMP/valop_core.o" \
        -lm -o "$GATE_BIN" 2>"$TMP/cc.err"; then
    "$GATE_BIN"; rc=$?
    ev "valop_core_gate (native rt_add_native vs C add oracle) exit=$rc (25=full pass)"
    [ "$rc" = 25 ] || { log "GATE FAIL rc=$rc"; cat "$TMP/cc.err" | tail; exit 4; }
else
    log "gate compile failed:"; tail -30 "$TMP/cc.err"
    exit 4
fi

# ── 5) ship regenerated seeds back via base64 (mini commits+pushes) ─────
# aiden has no push auth; emit each seed base64 between sentinels so the parent
# (mini, with push auth) can reconstruct + commit. pool flattens multiline so
# base64 is the safe channel.
if git diff --quiet self/native/valop_core_x86_64.s self/native/valop_core_arm64.s self/native/valop_core_arm64-linux.s; then
    ev "SEEDS_UNCHANGED — regenerated seeds byte-identical to committed (no diff)"
else
    ev "SEEDS_CHANGED — shipping regenerated seeds base64:"
    for s in self/native/valop_core_x86_64.s self/native/valop_core_arm64.s self/native/valop_core_arm64-linux.s; do
        echo "===SEED_B64_BEGIN $s==="
        base64 "$s"
        echo "===SEED_B64_END $s==="
    done
fi

log "DONE — lane green"
