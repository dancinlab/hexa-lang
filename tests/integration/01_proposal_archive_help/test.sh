#!/usr/bin/env bash
# 01_proposal_archive_help — `proposal_archive.hexa --help` exits 0 and prints usage.
# Guards hxa-20260424-006 (args.len()→void silent-fail) for the --help parser path.
#
# proposal_archive.hexa was absorbed into hexa-lang; accept either:
#   $HEXA_ROOT/tool/proposal_archive.hexa            (explicit env)
#   /Users/ghost/core/hexa-lang/tool/proposal_archive.hexa  (canonical post-absorption)
# If neither present, SKIP (rc=77) — test is still informative but not blocking.

set -u
HEXA_ROOT="${HEXA_ROOT:-/Users/ghost/core/hexa-lang}"
SCRIPT="$HEXA_ROOT/tool/proposal_archive.hexa"
if [ ! -f "$SCRIPT" ]; then
    echo "SKIP: proposal_archive.hexa not found at $SCRIPT (not yet ported)"
    exit 77
fi

out="$("$HEXA_BIN" "$SCRIPT" --help 2>&1)"
rc=$?
if [ $rc -ne 0 ]; then
    echo "FAIL: --help exited rc=$rc"
    echo "$out"
    exit 1
fi
case "$out" in
    *"usage:"*"proposal_archive"*)
        echo "PASS: --help emitted usage banner"
        exit 0
        ;;
esac
echo "FAIL: expected 'usage:' and 'proposal_archive' in output, got:"
echo "$out"
exit 1
