#!/usr/bin/env bash
# absorbed from ~/core/anima/README.md §Philosophy (MIT, dancinlab 2026-05-14)
#
# _principle_extract.sh — backend extractor for the hexa-principle annotator.
#
# Walks one file (.hexa or .md) and emits TSV rows of recognised 8-principle
# PHILOSOPHY markers + Law citations. The wrapper (hexa-principle) bundles
# the rows into the final JSON envelope.
#
# Output TSV columns (tab-separated):
#   <name>\t<strength>\t<lineno>\t<form>
#
# Where:
#   <name>     — canonical principle name (e.g. "NO SYSTEM PROMPT") OR
#                "LAW <n>" for a Law citation.
#   <strength> — EMPIRICAL | POLICY | DESIGN | LAW
#   <lineno>   — 1-based source line.
#   <form>     — annotation | docstring | table | law_ref
#
# Recognised patterns (per the 2026-05-14 anima-absorption-plan Wave 3.1):
#   (1) `@principle("<name>")` or `@principle(name="<name>")` — annotation form.
#   (2) Exact 8-principle string literal in any line (`NO SYSTEM PROMPT`, ...).
#       Strings starting `NO ` are matched against the canonical TSV table.
#   (3) Markdown table row whose 2nd column is a backtick-wrapped principle.
#   (4) `Law <n>` citation (e.g. "Law 22 structure>feature") — emits LAW row.

set -eu

if [ $# -lt 1 ]; then
    echo "usage: _principle_extract.sh <file.hexa|file.md>" >&2
    exit 1
fi

FILE="$1"
if [ ! -f "$FILE" ]; then
    echo "error: not a file: $FILE" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TSV="${SCRIPT_DIR}/_principles.tsv"
if [ ! -f "$TSV" ]; then
    echo "error: principle TSV not found: $TSV" >&2
    exit 1
fi

# Awk pass — load the canonical 8-principle table (stripping comments) and
# walk the source file in a single pass, emitting one TSV row per match.
awk -v tsv="$TSV" '
BEGIN {
    n_pr = 0
    while ((getline line < tsv) > 0) {
        if (line == "" || substr(line, 1, 1) == "#") continue
        # name<TAB>strength
        idx = index(line, "\t")
        if (idx == 0) continue
        nm = substr(line, 1, idx - 1)
        st = substr(line, idx + 1)
        # trim trailing CR/whitespace
        sub(/[ \t\r]+$/, "", nm)
        sub(/^[ \t]+/, "", st)
        sub(/[ \t\r]+$/, "", st)
        names[++n_pr] = nm
        strength[nm] = st
    }
    close(tsv)
}
function emit(nm, st, ln, form) {
    print nm "\t" st "\t" ln "\t" form
}
{
    line = $0
    # (1) @principle(...) annotation — handle both `"<name>"` and
    # `name="<name>"` positional / keyword forms. Extract first
    # double-quoted token after the opening paren.
    if (match(line, /@principle\(/)) {
        rest = substr(line, RSTART + RLENGTH)
        # Look for a name=... form first
        if (match(rest, /name[ \t]*=[ \t]*"[^"]*"/)) {
            tok = substr(rest, RSTART, RLENGTH)
            sub(/^name[ \t]*=[ \t]*"/, "", tok)
            sub(/"$/, "", tok)
            if (tok in strength) emit(tok, strength[tok], NR, "annotation")
            else emit(tok, "UNKNOWN", NR, "annotation")
        } else if (match(rest, /"[^"]*"/)) {
            tok = substr(rest, RSTART + 1, RLENGTH - 2)
            if (tok in strength) emit(tok, strength[tok], NR, "annotation")
            else emit(tok, "UNKNOWN", NR, "annotation")
        }
    }
    # (2/3) Plain-text or markdown-table match of canonical principle names.
    # Skip the annotation form (already emitted above) — avoid double-count
    # when an @principle line also literally contains the name.
    if (!match(line, /@principle\(/)) {
        # Heuristic: leading "|" + "`" suggests a markdown table row.
        tline = line
        sub(/^[ \t]+/, "", tline)
        is_table = (substr(tline, 1, 1) == "|" && index(tline, "`") > 0)
        form = is_table ? "table" : "docstring"
        # Walk all 8 canonical names; emit one row per name occurring in line.
        # Multiple distinct names on the same line are all recorded (each
        # emits its own row); same name multiple times on one line is folded
        # to a single emit (refs aggregate at the JSON layer per-line).
        for (pi = 1; pi <= n_pr; pi++) {
            cnm = names[pi]
            if (index(line, cnm) > 0) {
                emit(cnm, strength[cnm], NR, form)
            }
        }
    }
    # (4) Law <n> citation. Accept "Law 22", "Law 60 phase transition", etc.
    # Bound to word-boundary to avoid matching "Lawful", "Lawn", etc.
    s = line
    while (match(s, /(^|[^A-Za-z])Law[ \t]+[0-9]+/)) {
        m_start = RSTART
        m_len   = RLENGTH
        seg = substr(s, m_start, m_len)
        # Strip leading non-letter (or BOL).
        sub(/^[^A-Za-z]/, "", seg)
        # seg now looks like "Law 22". Extract the number — note this
        # clobbers RSTART/RLENGTH, so we used the saved m_start/m_len above.
        if (match(seg, /[0-9]+/)) {
            num = substr(seg, RSTART, RLENGTH)
            emit("LAW " num, "LAW", NR, "law_ref")
        }
        s = substr(s, m_start + m_len)
    }
}
' "$FILE"
