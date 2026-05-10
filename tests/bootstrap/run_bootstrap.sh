#!/bin/sh
# tests/bootstrap/run_bootstrap.sh - stage 2/3 bootstrap harness driver.
#
# Runs (in order):
#   1) tests/bootstrap/stage_2_smoke.hexa        (stage 1 -> stage 2)
#   2) tests/bootstrap/stage_3_fixed_point.hexa  (stage 2 -> stage 3, hash check)
#
# Each stage may report DEFERRED (stage 1 not yet available) - that is a
# legitimate state while A2 is in flight. CI must NOT fail on DEFERRED.
#
# Exit codes:
#   0   FIXED_POINT_PASS       both stages PASS, sha256 equal
#   0   DEFERRED               stage 1 (or stage 2) not yet on disk
#   0   STAGE_2_PASS_ONLY      stage 2 PASS but stage 3 DEFERRED
#   1   FAIL                   any non-deferred step returned non-zero
#
# POSIX sh only - no bashisms. Tested on dash, bash, zsh.

set -u

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
FIND_LOCAL="$REPO_ROOT/tool/find_local_hexa.sh"

if [ ! -x "$FIND_LOCAL" ]; then
    printf 'run_bootstrap: missing %s\n' "$FIND_LOCAL" >&2
    exit 1
fi

HEXA_BIN=$("$FIND_LOCAL") || {
    printf 'run_bootstrap: tool/find_local_hexa.sh found no local interpreter\n' >&2
    printf 'run_bootstrap: marking DEFERRED (no host)\n' >&2
    echo "DEFERRED"
    exit 0
}

printf '[run_bootstrap] hexa interp = %s\n' "$HEXA_BIN"

run_stage() {
    label=$1
    src=$2
    printf '\n========== %s ==========\n' "$label"
    out=$( ( cd "$REPO_ROOT" && "$HEXA_BIN" run "$src" ) 2>&1 )
    rc=$?
    printf '%s\n' "$out"
    printf '[run_bootstrap] %s exit=%d\n' "$label" "$rc"
    return $rc
}

# --- stage 2 smoke ---
run_stage "stage_2_smoke" "tests/bootstrap/stage_2_smoke.hexa"
rc2=$?

# DEFERRED detection: stage_2_smoke prints "deferred" on its own when the
# stage 1 binary is missing. We treat exit 0 + presence of /tmp/hexa_stage_2
# as PASS, exit 0 without it as DEFERRED.
if [ $rc2 -ne 0 ]; then
    echo "FAIL"
    echo "[run_bootstrap] stage_2_smoke failed (exit $rc2)"
    exit 1
fi

if [ ! -f /tmp/hexa_stage_2 ]; then
    echo "DEFERRED"
    echo "[run_bootstrap] stage 1 binary not yet available - bootstrap deferred"
    exit 0
fi

# --- stage 3 fixed point ---
run_stage "stage_3_fixed_point" "tests/bootstrap/stage_3_fixed_point.hexa"
rc3=$?

if [ $rc3 -eq 0 ]; then
    if [ -f /tmp/hexa_stage_3 ]; then
        echo "FIXED_POINT_PASS"
        exit 0
    else
        echo "STAGE_2_PASS_ONLY"
        echo "[run_bootstrap] stage 2 PASS but stage 3 deferred"
        exit 0
    fi
fi

echo "FAIL"
echo "[run_bootstrap] stage_3_fixed_point failed (exit $rc3)"
exit 1
