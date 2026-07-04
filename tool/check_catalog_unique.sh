#!/usr/bin/env bash
# ── catalog HXxxxx diagnostic-code UNIQUENESS check ──────────────────────────
#
# Every DiagSpec in compiler/diag/catalog.hexa carries a stable `code: "HXxxxx"`
# — the diagnostic's user-facing identity. Two DiagSpecs MUST NEVER share a
# code: a duplicate makes the code ambiguous (two different diagnostics answer
# to the same HXxxxx) and the diag registry's code→spec lookup is silently
# wrong.
#
# ROOT-CAUSE it prevents (convergence catalog-hexa-1):
#   Parallel opt-in-diagnostic PRs each pick "the next free HXxxxx" against
#   their OWN branch-time main, so when two land close together they register
#   TWO different diagnostics under the SAME code, at DIFFERENT line numbers.
#   `git merge-tree` sees no textual overlap → conflict=0 → auto-merge silently
#   lands the duplicate. The byteeq gate CANNOT catch it (these diagnostics are
#   opt-in default-OFF, so the DEFAULT emit stays byte-identical). This is the
#   dedicated uniqueness check that the byte-eq gates structurally can't be.
#   Observed twice: HX3020 (#4085 vs #4557), HX3019 (#4085 vs #4555).
#
# ROBUSTNESS
#   Only actual DiagSpec `code:` FIELDS are parsed — the pattern is anchored to
#   leading whitespace + a trailing comma (`^[[:space:]]*code: "HX....",`), so
#   an HX code merely MENTIONED inside an `explain:`/`template:` string or a
#   `//` comment does not count. (Verified: on catalog.hexa every match of the
#   loose pattern is already a real field; the anchor is belt-and-suspenders.)
#
# USAGE
#   bash tool/check_catalog_unique.sh [path/to/catalog.hexa]
#   exit 0 = all codes unique · exit 1 = duplicate code(s) found (BLOCKING).
#
# Pure grep/sort — no build, runs in milliseconds on a free runner.
set -euo pipefail

CATALOG="${1:-compiler/diag/catalog.hexa}"

if [ ! -f "$CATALOG" ]; then
  echo "🚫 FAIL — catalog not found: $CATALOG" >&2
  exit 1
fi

# Field-anchored extraction: leading indent, `code: "HXnnnn",`.
codes="$(grep -oE '^[[:space:]]*code: "HX[0-9]+",' "$CATALOG" | grep -oE 'HX[0-9]+' || true)"

if [ -z "$codes" ]; then
  echo "🚫 FAIL — no DiagSpec code fields found in $CATALOG (parser pattern broke?)" >&2
  exit 1
fi

dups="$(printf '%s\n' "$codes" | sort | uniq -d)"

if [ -n "$dups" ]; then
  echo "🚫 FAIL — duplicate diagnostic code(s) in $CATALOG:"
  echo "------------------------------------------------------------"
  while IFS= read -r code; do
    [ -z "$code" ] && continue
    n="$(printf '%s\n' "$codes" | grep -cxF "$code")"
    echo "  $code — defined $n times, at line(s):"
    grep -nE "^[[:space:]]*code: \"$code\"," "$CATALOG" | sed 's/^/      /'
  done <<< "$dups"
  echo "------------------------------------------------------------"
  echo "Two DiagSpecs share a code (convergence catalog-hexa-1): parallel"
  echo "opt-in-diagnostic PRs each numbered against their own branch-time main."
  echo "Fix: the LATER-landed diagnostic takes a fresh unused HX code (preserve"
  echo "any referenced Rust E-code; move only the internal HX number)."
  echo "Local mirror: bash tool/check_catalog_unique.sh"
  exit 1
fi

echo "✅ PASS — all $(printf '%s\n' "$codes" | wc -l | tr -d ' ') diagnostic codes in $CATALOG are unique"
