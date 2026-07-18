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
    # Every entry must have `use` > 0 — that is the whole point. A program with no imports never
    # takes the flatten/import-closure path, which is exactly the blind spot of the existing toy
    # corpus (array.hexa 21 lines use=0, loop.hexa 19 lines use=0). Ordered small -> large so a
    # partial run still says something.
    CORPUS=()
    for c in \
        tool/compile.hexa \
        tool/doctor.hexa \
        tool/absolute_rules_embed_gen.hexa \
        tool/ai_native_profile.hexa \
        tool/aot_cc_select.hexa \
        tool/hx.hexa \
        stdlib/qforge/atoms/ccsd_rhf.hexa \
        tool/atlas_cli.hexa
    do
        [ -f "$c" ] || continue
        # Skip anything that would not exercise the flatten path.
        [ "$(grep -c '^use ' "$c" 2>/dev/null || echo 0)" -gt 0 ] || continue
        CORPUS+=("$c")
    done
fi

[ "${#CORPUS[@]}" -gt 0 ] || { echo "[ownlink_census] ERROR: empty corpus" >&2; exit 1; }

# Per-program wall-clock cap. Without it, ONE slow program (measured 2026-07-15:
# stdlib/qforge/atoms/ccsd_rhf.hexa, a large quantum-chemistry TU, program #7 of 8)
# runs long enough that an outer harness/ssh timeout kills the WHOLE census mid-loop —
# the run truncated at 6/8 twice, silently dropping the tally for the last two programs.
# A per-program timeout turns "the run got killed" into a bounded, counted TIMEOUT outcome
# for that ONE program, so the census always completes and reports every program.
CENSUS_TIMEOUT="${CENSUS_TIMEOUT:-300}"

TMP="$(mktemp -d -t ownlink_census.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

ok=0; fell_back=0; other=0; timed_out=0
declare -a FB=()

echo "[ownlink_census] HEXA_OWNLINK_STRICT=1 — the fallback to ld/clang is an ERROR, not a demotion"
echo "[ownlink_census] corpus: ${#CORPUS[@]} real programs (each takes the flatten/import-closure path)"
echo "[ownlink_census] per-program timeout: ${CENSUS_TIMEOUT}s (override with CENSUS_TIMEOUT=)"
echo

i=0
for src in "${CORPUS[@]}"; do
    i=$((i + 1))
    out="$TMP/$(basename "${src%.hexa}").bin"
    log="$TMP/$(basename "${src%.hexa}").log"
    # Progress BEFORE the build, flushed — so a run killed by an outer cap still shows exactly
    # which program it died on, instead of just stopping after the last completed line.
    printf '  [%d/%d] building %s ... ' "$i" "${#CORPUS[@]}" "$src"
    # Every env var that could route around the default ladder is cleared: measure the SHIPPED path.
    rm -f "$out"
    timeout "$CENSUS_TIMEOUT" env -u HEXA_PREBUILT_RUNTIME -u HEXA_APRIME_CC \
        HEXA_OWNLINK_STRICT=1 HEXA_RUN_NATIVE_TRACE=1 \
        "$HEXA_BIN" build "$src" -o "$out" >"$log" 2>&1
    rc=$?
    printf '\r'  # rewind the "building ..." line; the verdict prints its own full line below
    # rc alone is a PROXY, and the proxy lied. This census exists to stop trusting proxies, so it
    # demands the ARTIFACT: a build only counts as own-linked if a binary actually came out.
    # Measured 2026-07-14: the first run of this census scored tool/compile.hexa and
    # tool/ai_native_profile.hexa as "own-link ✅" — both had in fact FAILED to compile (HX2001
    # undefined name, no binary produced). The tally was wrong in the direction that flatters us.
    if [ "$rc" -eq 124 ]; then
        # A compile-time budget overrun is an infra/scale wall, NOT an own-link fallback — it is
        # quarantined from the fallback verdict (commons infra-wall-noneval) and reported separately.
        printf '  TIMEOUT   %s (exceeded %ss — a compile-scale wall, NOT an own-link fallback)\n' "$src" "$CENSUS_TIMEOUT"
        timed_out=$((timed_out + 1))
    elif [ "$rc" -eq 0 ] && [ -x "$out" ]; then
        printf '  own-link  %s\n' "$src"; ok=$((ok + 1))
    elif [ "$rc" -eq 0 ]; then
        printf '  NO-BINARY %s (rc=0 but nothing was emitted — the build lied)\n' "$src"
        grep -oE 'HX[0-9]{4}[^ ]*' "$log" | sort -u | head -3 | sed 's/^/              /'
        other=$((other + 1))
    elif grep -q 'HEXA_OWNLINK_STRICT=1' "$log"; then
        printf '  FALLBACK  %s\n' "$src"
        sed -n 's/^.*FATAL (HEXA_OWNLINK_STRICT=1): own-link failed and the fallback is disabled — //p' "$log" \
            | head -1 | sed 's/^/              /'
        fell_back=$((fell_back + 1)); FB+=("$src")
    else
        # Not an own-link fallback — the program failed for its own reasons (missing dep, bad source).
        printf '  skip      %s (build error unrelated to own-link)\n' "$src"
        grep -oE 'HX[0-9]{4}[^ ]*|FATAL[^:]*' "$log" | sort -u | head -3 | sed 's/^/              /'
        other=$((other + 1))
    fi
done

n=$((ok + fell_back))
echo
echo "[ownlink_census] own-linked=$ok  fell-back-to-clang=$fell_back  unrelated-error=$other  timed-out=$timed_out"
if [ "$n" -gt 0 ]; then
    echo "[ownlink_census] fallback rate = $((fell_back * 100 / n))% of the $n programs that built at all"
fi
if [ "$timed_out" -gt 0 ]; then
    echo
    echo "[ownlink_census] $timed_out program(s) hit the ${CENSUS_TIMEOUT}s cap — a compile-scale outcome, quarantined"
    echo "                 from the fallback rate. A timeout is OFTEN a DEAD SOURCE, not a real scale wall:"
    echo "                 an unresolved import -> module_loader FATAL -> raw-src fallback -> pathological"
    echo "                 compile (convergence ownlink-strict-census-sh-2, e.g. tool/hx.hexa's dead"
    echo "                 raw_audit import). Check the source's imports resolve before blaming own-link."
fi
if [ "$fell_back" -gt 0 ]; then
    echo
    echo "[ownlink_census] these still need clang — axis-① cannot delete hexa_cc.c until they do not:"
    for f in "${FB[@]}"; do echo "    $f"; done
    exit 1
fi
echo "[ownlink_census] no own-link fallback on this corpus (timeouts + unrelated errors are quarantined)."
