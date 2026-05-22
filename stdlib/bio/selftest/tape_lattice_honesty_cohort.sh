#!/usr/bin/env bash
# selftest/tape_lattice_honesty_cohort.sh — cohort-wide tape-lint gate.
#
# Iterates every root `*.tape` (excluding `.log.tape` siblings + the
# governance `AGENTS.tape`) and runs `tape_lattice_honesty_lint.py` on
# each. Exit 0 iff every tape PASSes (or SKIPs honestly per the linter's
# is-domain-tape rule). Exit 1 on any FAIL.
#
# Promoted into `selftest/run_all.sh` as a hard gate 2026-05-16 once the
# cohort honesty rewrite reached 65/65 PASS (Pilot+6 batches; see
# TAPE-AUDIT.md §F). The contract enforced is documented in the linter
# module docstring + AGENTS.tape `@D g_meta_mode_optin`.
#
# SCOPE BOUNDARY (intentional, user decision 2026-05-16): this gate
# scans ROOT `*.tape` ONLY. Subdirectory tapes (e.g. `LVAD/*.tape`) are
# separate subprojects with their own lifecycle and are deliberately
# OUT of the honesty-cohort scope — do NOT "fix" this by recursing into
# subdirs. The honesty cohort = the root domain/meta SSOT set.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
LINT="$HERE/tape_lattice_honesty_lint.py"

pass=0
fail=0
skip=0
fail_tapes=()

for f in "$REPO_ROOT"/*.tape; do
  case "$(basename "$f")" in
    *.log.tape|AGENTS.tape) continue ;;
  esac
  v=$(python3 "$LINT" "$f" --json 2>&1 \
        | python3 -c "import sys,json
try:
  print(json.loads(sys.stdin.readline())['verdict'])
except Exception:
  print('ERR')")
  case "$v" in
    PASS) pass=$((pass + 1)) ;;
    SKIP) skip=$((skip + 1)) ;;
    *)    fail=$((fail + 1)); fail_tapes+=("$(basename "$f"): $v") ;;
  esac
done

echo "  tape-lint cohort: PASS=$pass SKIP=$skip FAIL=$fail"
if [ "$fail" -ne 0 ]; then
  echo "  failed tapes:"
  for t in "${fail_tapes[@]}"; do echo "    - $t"; done
  echo "  hint: python3 selftest/tape_lattice_honesty_lint.py <PATH> --json"
  exit 1
fi
exit 0
