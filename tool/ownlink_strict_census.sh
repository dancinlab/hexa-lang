#!/usr/bin/env bash
# ownlink_strict_census.sh — how often does own-link actually fall back to clang?
#
# `hexa build` / `hexa run` default to own-emit + own-link on linux-x86_64 (#4882/#4902), and the
# gates are green — but those gates compile FIVE toy programs of under 21 lines with ZERO `use`
# statements. A real program goes through the import-closure flatten first, and own-link has never
# once been measured on one. Meanwhile the ladder falls back SILENTLY: own-link fails -> tier-B ld
# -> C-transpile delegate -> clang. Nobody counts it. So "own-link is default-ON and green" does not
# yet mean "clang is gone", and axis-① (delete hexa_cc.c) needs exactly that proof.
#
# HEXA_OWNLINK_STRICT=1 makes the fallback an ERROR instead of a silent demotion, so a corpus run
# yields the real number rather than a comfortable zero.
#
#   bash tool/ownlink_strict_census.sh [corpus-file ...]      # defaults to the corpus below
#
# Exit 0 = every program own-linked. Exit 1 = at least one fell back (the count is the point).
set -uo pipefail

HX="${HX_ROOT:-$(cd "$(dirname "$0")/.."; pwd)}"
cd "$HX"

HEXA_BIN="${HEXA_BIN:-./hexa}"
[ -x "$HEXA_BIN" ] || { echo "[ownlink_census] ERROR: no $HEXA_BIN — build it first (tool/release_build)" >&2; exit 1; }

# Real programs, not fixtures: each one takes the import-closure/flatten path the toy corpus skips.
if [ "$#" -gt 0 ]; then
    CORPUS=("$@")
else
    CORPUS=()
    for c in \
        tool/hexa_diag.hexa \
        tool/doctor.hexa \
        tool/atlas_cli.hexa \
        tool/roadmap_cli.hexa \
        tool/hx.hexa \
        stdlib/qforge/atoms/ccsd_rhf.hexa \
        tool/stdlib_guard_lint.hexa \
        tool/bounded_loop_lint.hexa \
        tool/no_hardcode_lint.hexa \
        tool/total_fn_lint.hexa
    do
        [ -f "$c" ] && CORPUS+=("$c")
    done
fi

[ "${#CORPUS[@]}" -gt 0 ] || { echo "[ownlink_census] ERROR: empty corpus" >&2; exit 1; }

TMP="$(mktemp -d -t ownlink_census.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

ok=0; fell_back=0; other=0
declare -a FB=()

echo "[ownlink_census] HEXA_OWNLINK_STRICT=1 — the fallback to ld/clang is an ERROR, not a demotion"
echo "[ownlink_census] corpus: ${#CORPUS[@]} real programs (each takes the flatten/import-closure path)"
echo

for src in "${CORPUS[@]}"; do
    out="$TMP/$(basename "${src%.hexa}").bin"
    log="$TMP/$(basename "${src%.hexa}").log"
    # Every env var that could route around the default ladder is cleared: measure the SHIPPED path.
    if env -u HEXA_PREBUILT_RUNTIME -u HEXA_APRIME_CC \
           HEXA_OWNLINK_STRICT=1 HEXA_RUN_NATIVE_TRACE=1 \
           "$HEXA_BIN" build "$src" -o "$out" >"$log" 2>&1; then
        printf '  own-link  %s\n' "$src"; ok=$((ok + 1))
    elif grep -q 'HEXA_OWNLINK_STRICT=1' "$log"; then
        printf '  FALLBACK  %s\n' "$src"
        sed -n 's/^.*FATAL (HEXA_OWNLINK_STRICT=1): own-link failed and the fallback is disabled — //p' "$log" \
            | head -1 | sed 's/^/              /'
        fell_back=$((fell_back + 1)); FB+=("$src")
    else
        # Not an own-link fallback — the program failed for its own reasons (missing dep, bad source).
        printf '  skip      %s (build error unrelated to own-link)\n' "$src"; other=$((other + 1))
    fi
done

n=$((ok + fell_back))
echo
echo "[ownlink_census] own-linked=$ok  fell-back-to-clang=$fell_back  unrelated-error=$other"
if [ "$n" -gt 0 ]; then
    echo "[ownlink_census] fallback rate = $((fell_back * 100 / n))% of the $n programs that built at all"
fi
if [ "$fell_back" -gt 0 ]; then
    echo
    echo "[ownlink_census] these still need clang — axis-① cannot delete hexa_cc.c until they do not:"
    for f in "${FB[@]}"; do echo "    $f"; done
    exit 1
fi
echo "[ownlink_census] no fallback on this corpus."
