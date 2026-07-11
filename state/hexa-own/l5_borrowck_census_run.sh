#!/usr/bin/env bash
# state/hexa-own/l5_borrowck_census_run.sh
# ─────────────────────────────────────────────────────────────────────────
# HEXA-OWN L4/L5 Lane-B **B1** — whole-corpus borrow-check census harness.
#
# This is the FIRST-EVER recorded run of the borrow-check census over the
# self-host corpus (roadmap SSOT state/hexa-own/default_own_roadmap.md · gate
# B1: "0 HX3014 · 수치 캡처"; A2 census MODE exists (#4520) but has ZERO recorded
# runs). It produces the three numbers B1→B3 needs:
#   1. per-HX30xx borrow-check fire counts (+ total)   → is it O(dozens)? (>100 = 분류실패)
#   2. the `[borrowck-census] would-move` worklist file  → the move-by-default (A3) worklist
#   3. wall-clock cost ON vs OFF                          → first-ever borrowck cost number (delta%)
#
# WHAT IT COMPILES (the corpus): the freshly-built `./hexa` (which EMBEDS the
# patched compiler/lower/hir_to_mir.hexa census logic) compiles the self-host
# corpus via the released-hexa driver form `run compiler/main.hexa` + a native
# `--emit=obj --ignore-errors` sweep (empty-atlas branch, low RSS — see
# compiler/main.hexa:682). The census fires inside `lower_hir` while lowering
# each corpus file, so `--emit=obj` (frontend+codegen, no link) is enough and
# `--ignore-errors` keeps the sweep going through any per-file diagnostic so the
# WHOLE corpus is measured. Default corpus = compiler/main.hexa (pulls the whole
# import closure = the aprime_cc self-compile corpus); override with CORPUS="a b c".
#
# ── ENV CONTRACT (aiden/summer pool) ─────────────────────────────────────────
#   $1                 git ref/branch to test        (default: feat/l5-borrowck-census-b3prep)
#   CANON              canonical repo clone source    (default: $HOME/hexa-lang)
#   WORK               scratch root                   (default: $HOME/l5_bck_census)
#   TARGET             emit target triple             (default: x86_64-linux-gnu)
#   CC_TARGET          release_build TARGET           (default: linux-x86_64)
#   CC / LIBS          release_build toolchain        (default: gcc / "-lm -ldl")
#   CORPUS             space-sep .hexa corpus files   (default: compiler/main.hexa)
#   REPS               timing repetitions per band    (default: 3, median taken)
#   GH_TOKEN           github token (release_build edge-pull, if needed)
# Self-harvests the verdict to $WORK/CENSUS_RESULT.txt AND $HOME/CENSUS_RESULT.txt.
# Isolated worktree; single-SSH; FOREGROUND blocking. mini = git/gh only — RUN ON
# THE POOL (aiden/summer), never mini.
# ─────────────────────────────────────────────────────────────────────────
set -u

# ── env scrub (deterministic, no ambient borrowck/det leakage into the run) ──
unset HEXA_BORROWCK HEXA_BORROWCK_STRICT HEXA_BORROWCK_CENSUS HEXA_BORROWCK_WARN_DEFAULT
unset HEXA_MISSING_RETURN HEXA_UNREACHABLE_CODE HEXA_DET HEXA_MOVE_DEFAULT

REF="${1:-feat/l5-borrowck-census-b3prep}"
CANON="${CANON:-$HOME/hexa-lang}"
WORK="${WORK:-$HOME/l5_bck_census}"
TARGET="${TARGET:-x86_64-linux-gnu}"
CC_TARGET="${CC_TARGET:-linux-x86_64}"
CC="${CC:-gcc}"
LIBS="${LIBS:--lm -ldl}"
CORPUS="${CORPUS:-compiler/main.hexa}"
REPS="${REPS:-3}"
RESULT="$WORK/CENSUS_RESULT.txt"
WORKLIST="$WORK/borrowck_census_worklist.txt"

say() { echo "$@" | tee -a "$RESULT"; }

rm -rf "$WORK"; mkdir -p "$WORK"
: > "$RESULT"
say "=== HEXA-OWN Lane-B B1 borrow-check census — $(date -u +%FT%TZ) — $(hostname) ==="
say "  ref=$REF canon=$CANON target=$TARGET cc=$CC corpus=[$CORPUS] reps=$REPS"

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

# ── build ./hexa (embeds the patched census + B3 mechanism) ──────────────────
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
# Released ./hexa is driven through the compiler/main.hexa driver (the proven
# selfhost_byteeq_gate.sh form). --emit=obj (empty-atlas, low RSS) + --ignore-errors
# so a per-file diagnostic never truncates the corpus sweep. Env-controlled census.
NOATLAS="$WORK/noatlas"; mkdir -p "$NOATLAS"
compile_corpus() { # $1=stderr-log ; census env comes from the CALLER's exported vars
    local log="$1"; local rc_any=0; local n=0
    : > "$log"
    for src in $CORPUS; do
        [ -e "$SRC/$src" ] || { echo "[census-harness] MISSING corpus file: $src" >>"$log"; continue; }
        n=$((n+1))
        ( cd "$SRC" && HEXA_ATLAS_EMBED="$NOATLAS" \
            "$HEXA" run compiler/main.hexa \
                --emit=obj --target="$TARGET" --ignore-errors \
                -o "$WORK/census_$n.o" "$src" ) >>"$log" 2>&1 || rc_any=1
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

# ── extract the would-move worklist ──────────────────────────────────────────
grep -F "[borrowck-census] would-move" "$CENSUS_LOG" 2>/dev/null | sort -u > "$WORKLIST"
WL_COUNT=$(wc -l < "$WORKLIST" | tr -d ' ')

# ── per-HX30xx borrow-check fire counts (from the ON census log) ─────────────
# The census run has _bck_on true (census implies ON) so every borrow-check
# HX30xx diagnostic also fires — count them per code. Codes are rendered as
# `HX30NN` in the diag stream; dedup nothing (raw fire count is the census metric).
CODES_TMP="$WORK/hx_codes.txt"
grep -oE 'HX30[0-9][0-9]' "$CENSUS_LOG" 2>/dev/null | sort | uniq -c | sort -rn > "$CODES_TMP" || true
TOTAL_FIRES=$(awk '{s+=$1} END{print s+0}' "$CODES_TMP")

# ── CENSUS_* verdict block ───────────────────────────────────────────────────
say ""
say "════════════════════════════════════════════════════════════════════"
say "CENSUS_VERDICT — Lane-B B1 first-ever borrow-check census"
say "════════════════════════════════════════════════════════════════════"
say "CENSUS_REF                = $REF ($(git -C "$SRC" rev-parse --short HEAD 2>/dev/null))"
say "CENSUS_CORPUS             = [$CORPUS]"
say "CENSUS_WORKLIST_FILE      = $WORKLIST"
say "CENSUS_WOULD_MOVE_SITES   = $WL_COUNT   (move-by-default A3 worklist size)"
say "CENSUS_HX30XX_TOTAL_FIRES = $TOTAL_FIRES   (B1 gate: O(dozens) expected; >100 ⇒ 분류실패)"
say "CENSUS_PER_CODE_FIRES:"
if [ -s "$CODES_TMP" ]; then sed 's/^/    /' "$CODES_TMP" | tee -a "$RESULT"; else say "    (none — 0 borrow-check fires)"; fi
say "CENSUS_COST_OFF_MED_S     = $OFF_MED"
say "CENSUS_COST_ON_MED_S      = $ON_MED"
say "CENSUS_COST_DELTA_PCT     = ${DELTA}%   (B3 gate target: < ~5%)"
say "────────────────────────────────────────────────────────────────────"
say "B1 TRIAGE (manual, after this run):"
say "  * HX3014 count == 0 ?           → roadmap B1 gate '0 HX3014'"
say "  * total fires O(dozens), <100 ? → else 분류실패 (precision defect, not corpus)"
say "  * each fired code FP-audited=0 ? → those codes fill _bck_warn_allowlist (B3)"
say "  * cost delta < ~5% ?            → B3 default-ON viable"
say "GO ⇒ populate compiler/lower/hir_to_mir.hexa::_bck_warn_allowlist with the"
say "     FP=0 codes + flip HEXA_BORROWCK_WARN_DEFAULT default (SEPARATE PR, byteeq 3-target)."
say "════════════════════════════════════════════════════════════════════"

cp "$RESULT" "$HOME/CENSUS_RESULT.txt" 2>/dev/null || true
cp "$WORKLIST" "$HOME/borrowck_census_worklist.txt" 2>/dev/null || true
say "=== DONE — verdict $RESULT · worklist $WORKLIST (copies in \$HOME) ==="
