#!/usr/bin/env bash
# headless_foreign_path_smoke.sh — env -i regression for the headless
# foreign-path fix (slug: headless-foreign-path-fix).
#
# REGRESSION GUARDED
#   tool/bench_runner.hexa used to exec a hardcoded foreign-host launcher
#   (`/Users/ghost/.hx/bin/hexa run ...`) and write to a foreign-host
#   output root (`/Users/ghost/core/hexa-lang/...`) when its env var was
#   empty. Under a headless shell (`env -i`, no $HOME/$HEXA_LANG/$HX_HOME)
#   every bench then exec'd a nonexistent binary → ok=0/fail=1, and the
#   run/verify path broke on CI and non-author hosts.
#
# WHAT THIS ASSERTS (all under `env -i`, ONLY PATH preserved)
#   1. bench_runner runs the 3 qforge bench families (davidson / fft_poisson
#      / h_apply) and reports rc=0 with at least one ok bench (not all-fail).
#   2. `hexa verify --expr` recomputes headless (calc_dispatch resolves) rc=0.
#   3. ZERO `/Users/ghost` literal appears in ANY stdout or generated
#      artifact (grep-guard) — the foreign fallback never fires.
#
# Roll-up: prints PASS/FAIL per check; exits 0 only on full pass.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve a real `hexa` launcher for the *outer* invocation only. The
# point under test is bench_runner's OWN resolution, so we pass the binary
# explicitly and run the child under `env -i` to strip every env var.
HEXA_BIN=""
if command -v hexa >/dev/null 2>&1; then
    HEXA_BIN="$(command -v hexa)"
elif [ -x "${HX_HOME:-}/bin/hexa" ]; then
    HEXA_BIN="${HX_HOME}/bin/hexa"
elif [ -x "${HOME:-}/.hx/bin/hexa" ]; then
    HEXA_BIN="${HOME}/.hx/bin/hexa"
fi
if [ -z "$HEXA_BIN" ]; then
    echo "ERROR: no hexa launcher found (PATH / \$HX_HOME / \$HOME/.hx)" >&2
    exit 1
fi

# `env -i` wipes PATH too; the child still needs PATH so bench_runner can
# resolve `hexa` via `command -v`. We preserve ONLY PATH (this mirrors a
# CI runner: a PATH, but no HOME/HEXA_LANG/HX_HOME).
HEADLESS_PATH="$PATH"

WORKDIR="$(mktemp -d -t headless_fpath.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0
FAIL=0
FAIL_NAMES=()

note_pass() { PASS=$((PASS + 1)); printf '  [PASS] %s\n' "$1"; }
note_fail() { FAIL=$((FAIL + 1)); FAIL_NAMES+=("$1"); printf '  [FAIL] %s\n' "$1"; }

echo "headless foreign-path smoke (env -i, no HOME/HEXA_LANG/HX_HOME)"
echo "  root:     $ROOT"
echo "  hexa:     $HEXA_BIN"
echo

# ── Check 1: bench_runner on the 3 qforge bench families ──────────────
# One representative size per family keeps wall-clock bounded; the resolver
# path is identical across sizes.
BENCHES=(davidson_n128.hexa fft_poisson_nz256.hexa h_apply_n256.hexa)

for bench in "${BENCHES[@]}"; do
    out_jsonl="$WORKDIR/${bench%.hexa}.jsonl"
    log="$WORKDIR/${bench%.hexa}.log"
    ( cd "$ROOT" && env -i PATH="$HEADLESS_PATH" \
        "$HEXA_BIN" run tool/bench_runner.hexa -- \
        --target bench/qforge --pattern "$bench" \
        --warmup 0 --iters 1 --output "$out_jsonl" ) > "$log" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        note_fail "bench_runner $bench — rc=$rc (expected 0); see $log"
        continue
    fi
    # Must record at least one ok bench (regression: foreign exec → ok=0/fail=1).
    if grep -q '"ok": 0' "$out_jsonl" 2>/dev/null && ! grep -q '"ok": 1' "$out_jsonl" 2>/dev/null; then
        note_fail "bench_runner $bench — all benches failed (ok=0); foreign-exec regression?"
        continue
    fi
    if [ ! -s "$out_jsonl" ]; then
        note_fail "bench_runner $bench — no output jsonl produced"
        continue
    fi
    note_pass "bench_runner $bench — rc=0, ok bench recorded"
done

# ── Check 2: hexa verify recompute headless (calc_dispatch resolution) ─
vlog="$WORKDIR/verify.log"
( cd "$ROOT" && env -i PATH="$HEADLESS_PATH" \
    "$HEXA_BIN" verify --expr chsh_tsirelson 2.8284271247461903 ) > "$vlog" 2>&1
vrc=$?
if [ "$vrc" -eq 0 ] && grep -q 'SUPPORTED' "$vlog"; then
    note_pass "hexa verify --expr chsh_tsirelson — rc=0, recompute (calc_dispatch resolved headless)"
else
    note_fail "hexa verify --expr — rc=$vrc (expected 0 + SUPPORTED tier); see $vlog"
fi

# ── Check 3: grep-guard — zero /Users/ghost in any stdout or artifact ──
ghosts="$(grep -rl '/Users/ghost' "$WORKDIR" 2>/dev/null || true)"
if [ -z "$ghosts" ]; then
    note_pass "grep-guard — no /Users/ghost literal in any output/artifact"
else
    note_fail "grep-guard — /Users/ghost leaked into: $ghosts"
fi

echo
echo "Result: ${PASS} PASS / ${FAIL} FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Failures:"
    for f in "${FAIL_NAMES[@]}"; do echo "  - $f"; done
    exit 1
fi
echo "ALL PASS — headless run/verify path is foreign-path-free"
exit 0
