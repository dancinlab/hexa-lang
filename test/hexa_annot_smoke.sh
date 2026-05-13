#!/usr/bin/env bash
# hexa_annot_smoke.sh — smoke test for tool/hexa_annot/ (the 28-tool wave 1
# absorption of nexus bin/hexa-* annotation extractors).
#
# Per-tool checks:
#   1. <tool> --help              -> non-zero exit (usage path) AND emits usage text
#                                    (original scripts use exit 1 or 2 inconsistently;
#                                     we accept any non-zero as "usage path")
#   2. <tool> <fixture>           -> exit 0 AND stdout is valid JSON starting with
#                                    {"version":"0.1","source":"grep-mvp",
#
# Roll-up: prints X/28 PASS and exits 0 on full pass, non-zero on any failure.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANNOT_DIR="${ROOT}/tool/hexa_annot"
FIXTURE="${ROOT}/test/fixtures/annot_sample.hexa"
RULES_FIXTURE="${ROOT}/test/fixtures/annot_rules.json"

if [ ! -d "$ANNOT_DIR" ]; then
    echo "ERROR: annot dir not found: $ANNOT_DIR" >&2
    exit 1
fi
if [ ! -f "$FIXTURE" ]; then
    echo "ERROR: fixture not found: $FIXTURE" >&2
    exit 1
fi

TOOLS=(
    hexa-pure-check
    hexa-memo-check
    hexa-catalog
    hexa-readme
    hexa-doc
    hexa-codegen-hints
    hexa-distill
    hexa-effect-map
    hexa-intent-map
    hexa-meta-map
    hexa-phi-map
    hexa-struct-layout
    hexa-self-aware
    hexa-cognitive
    hexa-freedom
    hexa-infer
    hexa-learn
    hexa-safety
    hexa-antivirus
    hexa-serve
    hexa-tenant
    hexa-eval-run
    hexa-n6-list
    hexa-test-list
    hexa-schema
    hexa-law-link
    hexa-harness
    hexa-rule
    hexa-gate-register
)

# Wave-1 ports exactly 29 hexa-* scripts from nexus/bin (the user-facing brief
# said "28" but the actual nexus dir + inventory table both enumerate 29).
EXPECTED=29
if [ "${#TOOLS[@]}" -ne "$EXPECTED" ]; then
    echo "ERROR: TOOLS array has ${#TOOLS[@]} entries, expected $EXPECTED" >&2
    exit 1
fi

PASS=0
FAIL=0
FAIL_NAMES=()

# Per-tool extra args + expected stdout format. Implemented as case statements
# (associative arrays require bash 4+, but /usr/bin/env bash on macOS picks bash 3.2).
extra_args_for() {
    case "$1" in
        hexa-readme)   echo "--mode json" ;;
        hexa-law-link) echo "--rules ${RULES_FIXTURE}" ;;
        *) echo "" ;;
    esac
}
stdout_fmt_for() {
    # Default = json. hexa-doc emits markdown by default; hexa-readme emits
    # markdown unless we pass --mode json (handled in extra_args).
    case "$1" in
        hexa-doc) echo "markdown" ;;
        *) echo "json" ;;
    esac
}

# Match either compact JSON `{"version":"0.1",...}` or pretty-printed
# `{\n  "version": "0.1",\n  ...}` (struct-layout / schema / n6-list / gate-register
# use python-pretty json.dump). Both must include version 0.1 and source grep-mvp.
is_valid_grep_mvp_json() {
    local s="$1"
    case "$s" in
        '{"version":"0.1","source":"grep-mvp"'*)
            return 0
            ;;
        '{'*'"version"'*'"0.1"'*'"source"'*'"grep-mvp"'*)
            # Pretty-print form: strip whitespace then compare.
            local compact
            compact=$(printf '%s' "$s" | tr -d ' \t\n\r')
            case "$compact" in
                '{"version":"0.1","source":"grep-mvp"'*) return 0 ;;
            esac
            ;;
    esac
    return 1
}

check_one() {
    local tool="$1"
    local bin="${ANNOT_DIR}/${tool}"
    local status="PASS"
    local reason=""

    if [ ! -x "$bin" ]; then
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$tool: missing/not-executable")
        printf '  [FAIL] %-22s  not-executable\n' "$tool"
        return
    fi

    # 1) -h must emit non-empty usage text (regardless of exit code).
    # Some scripts exit 0 (gate-register), some exit 1, some exit 2.
    local help_out
    help_out=$("$bin" -h 2>&1 >/dev/null)
    if [ -z "$help_out" ]; then
        # try --help fallback
        help_out=$("$bin" --help 2>&1 >/dev/null)
    fi
    if [ -z "$help_out" ]; then
        status="FAIL"
        reason="no usage text emitted on -h/--help"
    fi

    # 2) Run against the fixture; expect exit 0 and well-formed output.
    if [ "$status" = "PASS" ]; then
        local extras fmt
        extras="$(extra_args_for "$tool")"
        fmt="$(stdout_fmt_for "$tool")"
        local out rc
        # Word-split extras safely.
        # shellcheck disable=SC2086
        out=$("$bin" $extras "$FIXTURE" 2>/dev/null)
        rc=$?
        if [ "$rc" -ne 0 ]; then
            status="FAIL"
            reason="fixture_rc=$rc"
        elif [ "$fmt" = "json" ]; then
            if ! is_valid_grep_mvp_json "$out"; then
                status="FAIL"
                reason="bad-json-prefix: $(printf '%s' "$out" | head -c 80)"
            fi
        elif [ "$fmt" = "markdown" ]; then
            if [ -z "$out" ]; then
                status="FAIL"
                reason="empty markdown output"
            fi
        fi
    fi

    if [ "$status" = "PASS" ]; then
        PASS=$((PASS + 1))
        printf '  [PASS] %-22s\n' "$tool"
    else
        FAIL=$((FAIL + 1))
        FAIL_NAMES+=("$tool: $reason")
        printf '  [FAIL] %-22s  %s\n' "$tool" "$reason"
    fi
}

echo "hexa_annot smoke — running ${#TOOLS[@]} tools against fixture"
echo "  dir:     $ANNOT_DIR"
echo "  fixture: $FIXTURE"
echo

for t in "${TOOLS[@]}"; do
    check_one "$t"
done

echo
echo "Result: ${PASS}/${EXPECTED} PASS"
if [ "$FAIL" -gt 0 ]; then
    echo "Failures:"
    for f in "${FAIL_NAMES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi
exit 0
