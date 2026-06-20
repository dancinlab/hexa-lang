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

REPO_URL="git@github.com:dancinlab/hexa-lang.git"
BRANCH="sh-val-core-add-native"
WT="$HOME/scratch-valadd-$$"   # unique per-run (collision guard, sh-str-scan lesson)

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

# ── 2) build aprime_cc (native compiler) ────────────────────────────────
# hexat (C-transpile bootstrap) is required. Prefer a recent dist checkout's
# hexat; fall back to the repo's self/native/hexat.
HEXAT=""
for c in "$WT/self/native/hexat" "$HOME/.hx/dist/linux-x86_64/hexat" "$(command -v hexat 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { HEXAT="$c"; break; }
done
log "hexat=$HEXAT"

export HEXA_RT_ALLOC_NATIVE=0   # dodge stage-5 smoke arena multiple-def (brcond memory)
if [ -n "$HEXAT" ]; then
    bash tool/build_aprime.sh -o build/aprime_cc -v "$HEXAT" 2>&1 | tail -25
else
    bash tool/build_aprime.sh -o build/aprime_cc 2>&1 | tail -25
fi
APRIME="$WT/build/aprime_cc"
[ -x "$APRIME" ] || { log "aprime_cc not built"; exit 2; }
ev "aprime_cc built: $($APRIME --version 2>/dev/null | head -1 || echo '(no --version)')"

# ── 3) regen the 3 valop seeds ──────────────────────────────────────────
APRIME="$APRIME" CC="${CC:-clang}" bash tool/regen_valop_core_native_s.sh all 2>&1 | tail -20
# assert all 3 seeds now export rt_add_native (.globl)
ALLOK=1
for s in self/native/valop_core_x86_64.s self/native/valop_core_arm64.s self/native/valop_core_arm64-linux.s; do
    n=$(grep -cE '^[[:space:]]*\.globl[[:space:]]+_?rt_add_native$' "$s" 2>/dev/null || echo 0)
    ev "seed $s .globl rt_add_native = $n"
    [ "$n" -ge 1 ] || ALLOK=0
done
[ "$ALLOK" = 1 ] || { log "a seed is missing rt_add_native"; exit 3; }

# ── 4) focused micro-byteeq (x86_64 native add vs C add oracle) ──────────
TMP="$(mktemp -d)"
"$APRIME" scripts/scratch/rt_native/_drv.hexa --emit=obj --target=x86_64-linux-gnu \
    -o "$TMP/valop_core.o" stdlib/runtime/valop_core.hexa 2>&1 | tail -5
ev "valop_core.o syms:"
nm "$TMP/valop_core.o" 2>/dev/null | grep -E ' T _?rt_(truthy|sub|mul|add)_native$' | sed 's/^/[EVIDENCE]   /'
# build the gate WITHOUT HEXA_HAS_HEXA_RT_STDLIB → pure-C #else wrappers, compare
# the native seed fns DIRECTLY (PART A/B/C/E) against the C oracle (self-contained).
GATE_BIN="$TMP/vgate"
if clang -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_RT_VALOP_NATIVE=1 -I self \
        scripts/scratch/rt_native/valop_core_gate.c self/runtime.c "$TMP/valop_core.o" \
        -lm -o "$GATE_BIN" 2>"$TMP/cc.err"; then
    "$GATE_BIN"; rc=$?
    ev "valop_core_gate (native rt_add_native vs C add oracle) exit=$rc (25=full pass)"
    [ "$rc" = 25 ] || { log "GATE FAIL rc=$rc"; cat "$TMP/cc.err" | tail; exit 4; }
else
    log "gate compile failed:"; tail -30 "$TMP/cc.err"
    exit 4
fi

# ── 5) commit regenerated seeds back to the branch ──────────────────────
if ! git diff --quiet self/native/valop_core_x86_64.s self/native/valop_core_arm64.s self/native/valop_core_arm64-linux.s; then
    git add self/native/valop_core_x86_64.s self/native/valop_core_arm64.s self/native/valop_core_arm64-linux.s
    git -c user.name=nbcorr-agent -c user.email=nerve011235@gmail.com commit -q -m "feat(self-host valop): regen valop_core_*.s seeds with rt_add_native (4-sym)

Regenerated on $(uname -sm) from stdlib/runtime/valop_core.hexa via the fixed
aprime_cc; each seed now exports rt_truthy/sub/mul/add_native (4 globl). Focused
micro-byteeq (valop_core_gate.c, native rt_add_native vs C add oracle) = exit 25
full pass, byte-identical incl int64 wrap + bit-identical double + inf/NaN.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
    git push origin "$BRANCH" 2>&1 | tail -3
    ev "seeds committed + pushed: $(git rev-parse --short HEAD)"
else
    ev "seeds byte-IDENTICAL to committed (no regen diff) — already current"
fi

log "DONE — lane green"
