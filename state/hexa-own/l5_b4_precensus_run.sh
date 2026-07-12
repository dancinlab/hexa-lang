#!/usr/bin/env bash
# state/hexa-own/l5_b4_precensus_run.sh
# ─────────────────────────────────────────────────────────────────────────
# HEXA-OWN L5 Lane-B **B4-PRECENSUS** — broad-corpus field-disjoint FP census.
#
# Cloned from state/hexa-own/l5_borrowck_census_run.sh (the B1 census). The B1
# run defaulted its corpus to `compiler/main.hexa` — the aprime_cc self-host
# closure, which is heavily `mut`-swept code written to pass the checker, so it
# fires ~0 (the B3 flip landed on "census fires=0", #4891). That number is
# FLIP-BIASED: it says nothing about how often the whole-local granularity
# ceiling (no place projection in MIR Operands — hir_to_mir.hexa:5704) turns a
# SAFE field-disjoint program into an HX3014 false positive. B4 (warn→error,
# roadmap wall #3) makes each such FP a build REFUSAL, so B4 must be gated on
# the field-disjoint FP count over a BROAD, non-self-host, adversarial corpus.
#
# This harness produces exactly that number:
#   1. per-HX30xx fire counts over the broad corpus (--error-format=short)
#   2. ADVERSARIAL split — every fire in state/hexa-own/l5_b4_adversarial/fd_*
#      is a CONFIRMED field-disjoint/place-projection FP (safe BY CONSTRUCTION);
#      controls_truepos.hexa proves the census is LIVE (must fire); controls_
#      clean.hexa must fire ZERO (a fire = a different precision defect)
#   3. REAL-corpus (stdlib+tests) HX3014 fires, source-anchored + heuristically
#      classified field-disjoint / place-projection-involved / whole-value
#   4. the would-move worklist (unchanged from B1) + OFF/ON wall cost (REPS>1)
#
# HONESTY (must appear in PR + CHANGELOG): PREREQ-X (the free-tree allocator
# default flip) is MEASURED-TERMINAL (arena-reclaim #4703/#4706 — 2-rung wall,
# do-not-retry). So B4 is a CORRECTNESS-LINT strengthening (a real logic-bug
# class: mutate-one-alias-then-read-the-other), NOT a memory-safety / GC-free
# gate — a borrow violation under the bump arena can never be use-after-free.
# The field-disjoint FP count is what decides whether B4-fatal is even viable.
#
# WHAT IT COMPILES: the freshly-built `./hexa` (EMBEDS the borrowck census +
# B3 warn band) is driven through the compiler/main.hexa driver, one corpus
# file per invocation, `--emit=obj --ignore-errors --error-format=short`
# (frontend+codegen, no link; a per-file diagnostic never truncates the sweep).
# The census fires inside `lower_hir`, so `--emit=obj` reaches it.
#
# ── ENV CONTRACT (aiden/summer pool) ─────────────────────────────────────────
#   $1                 git ref/branch to test        (default: feat/l5-b4-precensus-fd)
#   CANON              canonical repo clone source    (default: $HOME/hexa-lang)
#   WORK               scratch root                   (default: $HOME/l5_b4_precensus)
#   TARGET             emit target triple             (default: x86_64-linux-gnu)
#   CC_TARGET          release_build TARGET           (default: linux-x86_64)
#   CC / LIBS          release_build toolchain        (default: gcc / "-lm -ldl")
#   CORPUS             space-sep .hexa corpus files   (default: adversarial + tests + stdlib)
#   CORPUS_DIRS        dirs to auto-glob when CORPUS unset
#                                                      (default: "state/hexa-own/l5_b4_adversarial tests stdlib")
#   CORPUS_LIMIT       cap auto-globbed file count (0=all)  (default: 0)
#   REPS               timing repetitions per band    (default: 1 — census, not cost)
#   GH_TOKEN           github token (release_build edge-pull, if needed)
# Self-harvests the verdict to $WORK/B4_PRECENSUS_RESULT.txt AND $HOME/.
# Isolated worktree; single-SSH; FOREGROUND blocking. mini = git/gh only — RUN
# ON THE POOL (aiden/summer), never mini.
# ─────────────────────────────────────────────────────────────────────────
set -u

# ── env scrub (deterministic; no ambient borrowck/det leakage into the run) ──
unset HEXA_BORROWCK HEXA_BORROWCK_STRICT HEXA_BORROWCK_CENSUS HEXA_BORROWCK_WARN_DEFAULT
unset HEXA_MISSING_RETURN HEXA_UNREACHABLE_CODE HEXA_DET HEXA_MOVE_DEFAULT

REF="${1:-feat/l5-b4-precensus-fd}"
CANON="${CANON:-$HOME/hexa-lang}"
WORK="${WORK:-$HOME/l5_b4_precensus}"
TARGET="${TARGET:-x86_64-linux-gnu}"
CC_TARGET="${CC_TARGET:-linux-x86_64}"
CC="${CC:-gcc}"
LIBS="${LIBS:--lm -ldl}"
CORPUS_DIRS="${CORPUS_DIRS:-state/hexa-own/l5_b4_adversarial tests stdlib}"
CORPUS_LIMIT="${CORPUS_LIMIT:-0}"
CORPUS="${CORPUS:-}"          # empty ⇒ auto-glob from CORPUS_DIRS after clone
REPS="${REPS:-1}"
ADV_PREFIX="state/hexa-own/l5_b4_adversarial/"
RESULT="$WORK/B4_PRECENSUS_RESULT.txt"
WORKLIST="$WORK/borrowck_census_worklist.txt"

say() { echo "$@" | tee -a "$RESULT"; }

rm -rf "$WORK"; mkdir -p "$WORK"
: > "$RESULT"
say "=== HEXA-OWN L5 Lane-B B4-PRECENSUS field-disjoint FP census — $(date -u +%FT%TZ) — $(hostname) ==="
say "  ref=$REF canon=$CANON target=$TARGET cc=$CC reps=$REPS"
say "  corpus_dirs=[$CORPUS_DIRS] corpus_limit=$CORPUS_LIMIT corpus_override=[${CORPUS:-<auto>}]"

# ── wait for a quiet host (no-starve; matches the state/ pool harness idiom) ──
say "--- waiting for load<6 (no-starve) ---"
for w in $(seq 1 80); do
    L=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0); Li=${L%.*}
    if [ "${Li:-99}" -lt 6 ]; then say "  load=$L OK after ${w} probe(s)"; break; fi
    [ "$w" = 80 ] && say "  load stayed high (last=$L) — proceeding after cap"
    sleep 30
done

# ── clone the ref into an isolated worktree ──────────────────────────────────
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }
git -C "$CANON" worktree prune 2>>"$WORK/git.log" || true
git -C "$CANON" fetch -f origin "$REF:refs/remotes/origin/$REF" 2>>"$WORK/git.log" || say "  (fetch $REF warn)"
SRC="$WORK/src"
git -C "$CANON" worktree add -f --detach "$SRC" "origin/$REF" 2>>"$WORK/git.log" \
    || git -C "$CANON" worktree add -f --detach "$SRC" "$REF" 2>>"$WORK/git.log" \
    || git clone -b "$REF" "$CANON" "$SRC" 2>>"$WORK/git.log" \
    || { say "FATAL clone $REF"; exit 3; }
say "  SRC=$SRC sha=$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"

# ── resolve the corpus (auto-glob if no override) ────────────────────────────
if [ -z "$CORPUS" ]; then
    # adversarial FIRST (so a truncated LIMIT run still measures the FP proof),
    # then the broad real corpus dirs. Sorted for deterministic ordering.
    ADV_FILES=$(cd "$SRC" && find $ADV_PREFIX -name '*.hexa' 2>/dev/null | sort)
    REAL_DIRS=""
    for d in $CORPUS_DIRS; do [ "$d" = "${ADV_PREFIX%/}" ] || REAL_DIRS="$REAL_DIRS $d"; done
    REAL_FILES=$(cd "$SRC" && find $REAL_DIRS -name '*.hexa' 2>/dev/null | sort)
    if [ "$CORPUS_LIMIT" -gt 0 ] 2>/dev/null; then
        REAL_FILES=$(printf '%s\n' "$REAL_FILES" | head -n "$CORPUS_LIMIT")
    fi
    CORPUS=$(printf '%s\n%s\n' "$ADV_FILES" "$REAL_FILES" | awk 'NF')
fi
CORPUS_N=$(printf '%s\n' "$CORPUS" | awk 'NF' | wc -l | tr -d ' ')
ADV_N=$(printf '%s\n' "$CORPUS" | awk 'NF' | grep -cF "$ADV_PREFIX" || true)
say "  corpus resolved: $CORPUS_N files ($ADV_N adversarial, $((CORPUS_N-ADV_N)) real)"
if [ "$ADV_N" = 0 ]; then
    say "FATAL: 0 adversarial files in corpus — the FP proof depends on them. Check $ADV_PREFIX exists in $REF."
    exit 5
fi

# ── build ./hexa (embeds the borrowck census + B3 warn band) ─────────────────
say "--- building ./hexa (release_build TARGET=$CC_TARGET CC=$CC) ---"
( cd "$SRC" && TARGET="$CC_TARGET" CC="$CC" LIBS="$LIBS" GH_TOKEN="${GH_TOKEN:-}" \
      bash tool/release_build ) >"$WORK/release_build.log" 2>&1
RB_RC=$?
HEXA="$SRC/hexa"
if [ ! -x "$HEXA" ] || [ "$RB_RC" != 0 ]; then
    say "FATAL: ./hexa not built (release_build rc=$RB_RC) — tail:"
    tail -40 "$WORK/release_build.log" | sed 's/^/    /' | tee -a "$RESULT"
    exit 4
fi
say "  ./hexa built rc=$RB_RC ($(wc -c < "$HEXA" | tr -d ' ')B)"

# ── the corpus compile driver ────────────────────────────────────────────────
# --error-format=short → one grep/awk-friendly line per diagnostic:
#   FILE:LINE:COL HX30NN <severity>: <message>
# so a fire's file:line:col + the message (name/other + "at line N") is parseable.
NOATLAS="$WORK/noatlas"; mkdir -p "$NOATLAS"
compile_corpus() { # $1=diag-log ; census env comes from the CALLER's exported vars
    local log="$1"; local rc_any=0; local n=0
    : > "$log"
    printf '%s\n' "$CORPUS" | awk 'NF' | while IFS= read -r src; do
        [ -e "$SRC/$src" ] || { echo "[census-harness] MISSING corpus file: $src" >>"$log"; continue; }
        n=$((n+1))
        ( cd "$SRC" && HEXA_ATLAS_EMBED="$NOATLAS" \
            "$HEXA" run compiler/main.hexa \
                --emit=obj --target="$TARGET" --ignore-errors --error-format=short \
                -o "$WORK/census_obj.o" "$src" ) >>"$log" 2>&1 || rc_any=1
    done
    return $rc_any
}

# ── BAND: OFF (all borrowck env unset) — timed baseline ──────────────────────
say "--- BAND OFF (borrowck unset) — corpus compile ×$REPS ---"
OFF_TIMES=()
for r in $(seq 1 "$REPS"); do
    unset HEXA_BORROWCK HEXA_BORROWCK_CENSUS HEXA_BORROWCK_STRICT HEXA_BORROWCK_WARN_DEFAULT
    t0=$(date +%s.%N)
    compile_corpus "$WORK/off_r$r.log"
    t1=$(date +%s.%N)
    dt=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')
    OFF_TIMES+=("$dt"); say "  OFF rep$r wall=${dt}s"
done

# ── BAND: ON (HEXA_BORROWCK=1 HEXA_BORROWCK_CENSUS=1) — census capture + timed ─
say "--- BAND ON (HEXA_BORROWCK=1 HEXA_BORROWCK_CENSUS=1) — corpus compile ×$REPS ---"
ON_TIMES=()
CENSUS_LOG="$WORK/on_census.log"
for r in $(seq 1 "$REPS"); do
    export HEXA_BORROWCK=1 HEXA_BORROWCK_CENSUS=1
    unset HEXA_BORROWCK_STRICT HEXA_BORROWCK_WARN_DEFAULT
    t0=$(date +%s.%N)
    compile_corpus "$WORK/on_r$r.log"
    t1=$(date +%s.%N)
    dt=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')
    ON_TIMES+=("$dt"); say "  ON  rep$r wall=${dt}s"
    [ "$r" = 1 ] && cp "$WORK/on_r1.log" "$CENSUS_LOG"
done
unset HEXA_BORROWCK HEXA_BORROWCK_CENSUS

median() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$0} END{print (NR%2)?a[int(NR/2)+1]:a[NR/2]}'; }
OFF_MED=$(median "${OFF_TIMES[@]}")
ON_MED=$(median "${ON_TIMES[@]}")
DELTA=$(awk -v on="$ON_MED" -v off="$OFF_MED" 'BEGIN{if(off>0)printf "%.1f",(on-off)/off*100; else print "NA"}')

# ── would-move worklist (unchanged from B1) ──────────────────────────────────
grep -F "[borrowck-census] would-move" "$CENSUS_LOG" 2>/dev/null | sort -u > "$WORKLIST"
WL_COUNT=$(wc -l < "$WORKLIST" | tr -d ' ')

# ── per-HX30xx fire counts (short-format lines: "FILE:LINE:COL HX30NN ...") ──
CODES_TMP="$WORK/hx_codes.txt"
grep -oE 'HX30[0-9][0-9]' "$CENSUS_LOG" 2>/dev/null | sort | uniq -c | sort -rn > "$CODES_TMP" || true
TOTAL_FIRES=$(awk '{s+=$1} END{print s+0}' "$CODES_TMP")

# ── extract every diagnostic fire line (short format) ────────────────────────
# A short-format diag line begins with FILE:LINE:COL then " HX30NN <sev>:".
FIRES="$WORK/fires.txt"
grep -E '^[^ ]+:[0-9]+:[0-9]+ HX30[0-9][0-9] ' "$CENSUS_LOG" 2>/dev/null | sort -u > "$FIRES" || true

# ── ADVERSARIAL split — confirmed FP / true-pos liveness / clean-must-be-zero ─
ADV_FD="$WORK/adv_fd_fires.txt"       # fd_*.hexa  → CONFIRMED field-disjoint FP
ADV_TP="$WORK/adv_tp_fires.txt"       # controls_truepos.hexa → expected TP (liveness)
ADV_CL="$WORK/adv_clean_fires.txt"    # controls_clean.hexa   → MUST be 0
grep -F "$ADV_PREFIX" "$FIRES" | grep -E "${ADV_PREFIX}fd_" > "$ADV_FD" 2>/dev/null || true
grep -F "${ADV_PREFIX}controls_truepos" "$FIRES" > "$ADV_TP" 2>/dev/null || true
grep -F "${ADV_PREFIX}controls_clean"   "$FIRES" > "$ADV_CL" 2>/dev/null || true
ADV_FD_N=$(wc -l < "$ADV_FD" | tr -d ' ')
ADV_TP_N=$(wc -l < "$ADV_TP" | tr -d ' ')
ADV_CL_N=$(wc -l < "$ADV_CL" | tr -d ' ')

# ── REAL-corpus HX3014 heuristic field-disjoint classification ───────────────
# Diag has NO field/index info (whole-local: name/other are locals, not places),
# so real-corpus classification is source-anchored + HEURISTIC: for each HX3014
# fire read `$SRC/FILE` at the read-site line and at the write-site line ("at
# line N" in the message), test each for a place projection (`.field` / `[idx]`)
# and compare the trailing projection tokens:
#   FD_HEURISTIC  = both sites projected AND projected tokens DIFFER (likely FP)
#   PP_INVOLVED   = ≥1 site projected but not clearly disjoint (candidate)
#   WHOLE         = neither site projected (whole-value alias — likely a true
#                   hazard or a benign whole handle-copy)
REAL_HX3014="$WORK/real_hx3014.txt"
grep -vF "$ADV_PREFIX" "$FIRES" | grep -F ' HX3014 ' > "$REAL_HX3014" 2>/dev/null || true
REAL_HX3014_N=$(wc -l < "$REAL_HX3014" | tr -d ' ')

CLASS_TMP="$WORK/real_hx3014_classified.txt"
: > "$CLASS_TMP"
FD_HEUR=0; PP_INV=0; WHOLE=0
while IFS= read -r fl; do
    [ -n "$fl" ] || continue
    loc=$(printf '%s' "$fl" | awk '{print $1}')
    file=$(printf '%s' "$loc" | awk -F: '{print $1}')
    rline=$(printf '%s' "$loc" | awk -F: '{print $2}')
    wline=$(printf '%s' "$fl" | sed -nE 's/.*at line ([0-9]+).*/\1/p')
    rsrc=""; wsrc=""
    [ -n "$file" ] && [ -n "$rline" ] && rsrc=$(sed -n "${rline}p" "$SRC/$file" 2>/dev/null)
    [ -n "$file" ] && [ -n "$wline" ] && wsrc=$(sed -n "${wline}p" "$SRC/$file" 2>/dev/null)
    # projection tokens: field names after '.' and index brackets
    rproj=$(printf '%s' "$rsrc" | grep -oE '\.[A-Za-z_][A-Za-z0-9_]*|\[[^]]*\]' | tr '\n' ',' )
    wproj=$(printf '%s' "$wsrc" | grep -oE '\.[A-Za-z_][A-Za-z0-9_]*|\[[^]]*\]' | tr '\n' ',' )
    if [ -n "$rproj" ] && [ -n "$wproj" ]; then
        if [ "$rproj" != "$wproj" ]; then cls="FD_HEURISTIC"; FD_HEUR=$((FD_HEUR+1))
        else cls="PP_INVOLVED"; PP_INV=$((PP_INV+1)); fi
    elif [ -n "$rproj" ] || [ -n "$wproj" ]; then
        cls="PP_INVOLVED"; PP_INV=$((PP_INV+1))
    else
        cls="WHOLE"; WHOLE=$((WHOLE+1))
    fi
    printf '%-13s %s  [read:%s | write@%s:%s]\n' "$cls" "$loc" "${rproj:-<none>}" "${wline:-?}" "${wproj:-<none>}" >>"$CLASS_TMP"
done < "$REAL_HX3014"

# B4-gating count = adversarial confirmed FP + real heuristic field-disjoint.
B4_GATE_CONFIRMED=$ADV_FD_N
B4_GATE_TOTAL=$((ADV_FD_N + FD_HEUR))

# ── verdict block ────────────────────────────────────────────────────────────
say ""
say "════════════════════════════════════════════════════════════════════"
say "B4_PRECENSUS_VERDICT — L5 Lane-B field-disjoint FP census (B4 warn→error gate)"
say "════════════════════════════════════════════════════════════════════"
say "B4_REF                     = $REF ($(git -C "$SRC" rev-parse --short HEAD 2>/dev/null))"
say "B4_CORPUS_FILES            = $CORPUS_N  ($ADV_N adversarial + $((CORPUS_N-ADV_N)) real)"
say "B4_HX30XX_TOTAL_FIRES      = $TOTAL_FIRES"
say "B4_WOULD_MOVE_SITES        = $WL_COUNT   (worklist: $WORKLIST)"
say "B4_PER_CODE_FIRES:"
if [ -s "$CODES_TMP" ]; then sed 's/^/    /' "$CODES_TMP" | tee -a "$RESULT"; else say "    (none — 0 fires)"; fi
say "────────────────────────────────────────────────────────────────────"
say "ADVERSARIAL (state/hexa-own/l5_b4_adversarial/ — ground truth):"
say "  ADV_FD_CONFIRMED_FP      = $ADV_FD_N   (fd_*.hexa — SAFE by construction; each fire = a field/element-disjoint FP)"
say "  ADV_TP_LIVENESS          = $ADV_TP_N   (controls_truepos.hexa — MUST be >0, else census is DEAD/inert)"
say "  ADV_CLEAN_OVERFIRE       = $ADV_CL_N   (controls_clean.hexa — MUST be 0, else a NON-FD precision defect)"
if [ -s "$ADV_FD" ]; then say "  --- confirmed-FP fire sites ---"; sed 's/^/    /' "$ADV_FD" | tee -a "$RESULT"; fi
if [ -s "$ADV_CL" ]; then say "  ⚠ CLEAN control fired (unexpected):"; sed 's/^/    /' "$ADV_CL" | tee -a "$RESULT"; fi
say "────────────────────────────────────────────────────────────────────"
say "REAL corpus HX3014 fires    = $REAL_HX3014_N  (source-anchored heuristic classification):"
say "  FD_HEURISTIC (likely FP)  = $FD_HEUR   (both sites projected, disjoint tokens)"
say "  PP_INVOLVED  (candidate)  = $PP_INV"
say "  WHOLE        (true/benign)= $WHOLE"
if [ -s "$CLASS_TMP" ]; then sed 's/^/    /' "$CLASS_TMP" | tee -a "$RESULT"; fi
say "────────────────────────────────────────────────────────────────────"
say "B4_GATE_FIELD_DISJOINT_CONFIRMED = $B4_GATE_CONFIRMED   (adversarial, by construction)"
say "B4_GATE_FIELD_DISJOINT_TOTAL     = $B4_GATE_TOTAL   (+ real-corpus heuristic FD)"
say "B4_COST_OFF_MED_S          = $OFF_MED"
say "B4_COST_ON_MED_S           = $ON_MED"
say "B4_COST_DELTA_PCT          = ${DELTA}%"
say "────────────────────────────────────────────────────────────────────"
say "HONESTY: PREREQ-X (free-tree allocator flip) is MEASURED-TERMINAL"
say "  (arena-reclaim #4703/#4706, do-not-retry). B4 is a CORRECTNESS-LINT"
say "  strengthening (real logic-bug class), NOT memory-safety/GC-free: a"
say "  borrow violation under the bump arena is never use-after-free."
say ""
say "B4 TRIAGE (manual, after this run):"
say "  * ADV_TP_LIVENESS > 0 ?        → else DEAD census (stale hexat / borrowck off) — INVALIDATE run"
say "  * ADV_CLEAN_OVERFIRE == 0 ?    → else a non-FD precision regression to fix FIRST"
say "  * B4_GATE_FIELD_DISJOINT_* = the FP count B4-fatal would REFUSE-BUILD on."
say "    NON-ZERO ⇒ B4 warn→error is UNSAFE until place-projection lands (roadmap"
say "    A4 'place projection (field-disjoint)=별도 schema-add') — keep B4 at WARN."
say "  * If B4_GATE==0 across a broad+adversarial corpus AND the adversarial FDs"
say "    genuinely fire (census live), the ceiling is a non-issue in practice →"
say "    B4-fatal viable behind @grace waivers (separate PR, byteeq 3-target)."
say "════════════════════════════════════════════════════════════════════"

cp "$RESULT" "$HOME/B4_PRECENSUS_RESULT.txt" 2>/dev/null || true
cp "$WORKLIST" "$HOME/borrowck_census_worklist.txt" 2>/dev/null || true
cp "$CLASS_TMP" "$HOME/b4_real_hx3014_classified.txt" 2>/dev/null || true
say "=== DONE — verdict $RESULT (copies in \$HOME) ==="
