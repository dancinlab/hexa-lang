#!/usr/bin/env bash
# absorbed from ~/core/anima/README.md §Philosophy (MIT, dancinlab 2026-05-14)
#
# hexa_principle_smoke.sh — smoke test for tool/hexa_annot/hexa-principle.
#
# Verifies:
#   1. --help exits non-zero and prints usage.
#   2. Annotation form `@principle("<name>")` resolves to canonical strength.
#   3. Bare docstring mention of all 8 principles resolves correctly.
#   4. Markdown-table-row form is tagged `"table"`.
#   5. Two principles on the same line emit two rows.
#   6. `Law <n>` citation produces a `law_refs[]` entry (de-duped per position).
#   7. The strength tag for each of the 8 principles matches the README map.
#
# Roll-up: prints "PASS X/X" and exits 0 on full pass, exits 1 on any failure.
# No shared-state writes; uses /tmp fixtures only.

set -u

TOOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANNOT="${TOOL_ROOT}/tool/hexa_annot/hexa-principle"
FIXTURE="/tmp/_principle_fixture.md"

if [ ! -x "$ANNOT" ]; then
    echo "FAIL: annotator not executable: $ANNOT" >&2
    exit 1
fi

# Expected canonical mapping (must match _principles.tsv).
EXPECT_MAP=(
    "NO SYSTEM PROMPT|EMPIRICAL"
    "NO IDENTITY RULES|POLICY"
    "NO PERSONA INJECTION|EMPIRICAL"
    "NO ASSISTANT FRAMING|POLICY"
    "NO SPEAK|DESIGN"
    "NO FINE-TUNED ETHICS|POLICY"
    "NO PERPLEXITY VERDICT|EMPIRICAL"
    "NO TRAIN/INFER SPLIT|DESIGN"
)

# --- inline fixture ------------------------------------------------------
cat > "$FIXTURE" <<'EOF'
# Smoke fixture for hexa-principle

The agent honors NO SYSTEM PROMPT and NO IDENTITY RULES on the same line.

@principle("NO PERSONA INJECTION")

| 4 | `NO ASSISTANT FRAMING` | foo | bar |

NO SPEAK() is the design choice — Law 22 structure>feature applies.

NO FINE-TUNED ETHICS — policy boundary.

NO PERPLEXITY VERDICT proven 2026-05-09.

NO TRAIN/INFER SPLIT — `REBORN.tape §0.5` (Law 60 phase transition).
EOF

PASS=0
FAIL=0
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
pass() { PASS=$((PASS + 1)); }

# --- T1: --help exits non-zero -------------------------------------------
if "$ANNOT" --help >/dev/null 2>&1; then
    fail "T1: --help should exit non-zero"
else
    pass
fi

# --- T2..T7: run extractor + inspect JSON --------------------------------
OUT=$("$ANNOT" "$FIXTURE" 2>&1)
RC=$?
if [ $RC -ne 0 ]; then
    echo "FAIL: annotator exit $RC" >&2
    echo "$OUT" >&2
    exit 1
fi

# T2: All 8 canonical principles present with correct strength.
all_ok=1
for entry in "${EXPECT_MAP[@]}"; do
    nm="${entry%%|*}"
    st="${entry##*|}"
    # Match {"name":"<nm>","strength":"<st>"... in the JSON blob.
    if ! printf '%s' "$OUT" | grep -q "\"name\":\"$nm\",\"strength\":\"$st\""; then
        fail "T2: missing or wrong-strength entry for [$nm → $st]"
        all_ok=0
    fi
done
[ $all_ok -eq 1 ] && pass

# T3: summary.principles == 8.
if printf '%s' "$OUT" | grep -q '"principles":8'; then
    pass
else
    fail "T3: summary.principles != 8"
fi

# T4: Annotation form recorded — NO PERSONA INJECTION should have "annotation" form.
if printf '%s' "$OUT" | grep -q '"name":"NO PERSONA INJECTION","strength":"EMPIRICAL","refs":\[[0-9]*\],"forms":\["annotation"\]'; then
    pass
else
    fail "T4: NO PERSONA INJECTION not tagged as annotation form"
fi

# T5: Markdown-table form recorded — NO ASSISTANT FRAMING.
if printf '%s' "$OUT" | grep -q '"name":"NO ASSISTANT FRAMING".*"forms":\["table"\]'; then
    pass
else
    fail "T5: NO ASSISTANT FRAMING not tagged as table form"
fi

# T6: Same-line co-occurrence — NO SYSTEM PROMPT + NO IDENTITY RULES share line.
line_sys=$(printf '%s' "$OUT" | sed -n 's/.*"name":"NO SYSTEM PROMPT","strength":"EMPIRICAL","refs":\[\([0-9]*\)\].*/\1/p')
line_id=$(printf '%s'  "$OUT" | sed -n 's/.*"name":"NO IDENTITY RULES","strength":"POLICY","refs":\[\([0-9]*\)\].*/\1/p')
if [ -n "$line_sys" ] && [ "$line_sys" = "$line_id" ]; then
    pass
else
    fail "T6: same-line co-occurrence not detected (sys=$line_sys id=$line_id)"
fi

# T7: Law citations — should see law=22 and law=60.
if printf '%s' "$OUT" | grep -q '"law":22' && printf '%s' "$OUT" | grep -q '"law":60'; then
    pass
else
    fail "T7: Law 22 and/or Law 60 not detected"
fi

# T8: law_refs summary count >= 2 (one per distinct citation position).
if printf '%s' "$OUT" | grep -qE '"law_refs":[2-9]'; then
    pass
else
    fail "T8: summary.law_refs < 2"
fi

# --- roll-up -------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo "PASS $PASS/$TOTAL"
[ "$FAIL" -eq 0 ] || { echo "smoke FAIL ($FAIL of $TOTAL)" >&2; exit 1; }
rm -f "$FIXTURE"
exit 0
