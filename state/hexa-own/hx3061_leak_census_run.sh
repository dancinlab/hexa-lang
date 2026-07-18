#!/usr/bin/env bash
# state/hexa-own/hx3061_leak_census_run.sh
# ─────────────────────────────────────────────────────────────────────────
# HEXA-OWN L5 R2 — HX3061 handle-LEAK whole-corpus census harness.
#
# DUAL of the HX3060 use-after-free census (state/hexa-own/l5_borrowck_census_run.sh).
# HX3061 fires when a runtime `farr_*` handle is PRODUCED and then NEVER FREED on
# some path out of the function. It ships opt-in (HEXA_BORROWCK_LEAK=1, default-OFF)
# precisely because the round-2 checker does NOT yet model escapes via struct-field /
# global store / @own-param pass (see catalog.hexa HX3061 KNOWN FALSE-POSITIVES) — so
# the first census is EXPECTED to be FP-HIGH. This harness produces the numbers the
# default-ON flip is gated on (opt-in → opt-out, mirroring HX3060 R4 #4975):
#   1. per-file HX3061 fire counts (+ raw total + distinct fire-source files)
#   2. a TRIAGE split: REAL leak vs FP-escape (struct-field / global / return / @own)
#   3. a FP-escape worklist that feeds the round-3 escape-widening precision rung
#
# ★INSTRUMENT — CRITICAL (do NOT regress to the HX3060-v1/v2 traps):
# The census compiler is the FROM-SOURCE aprime_cc built by tool/build_aprime.sh
# (single-TU, HEXA_HAS_HEXA_RT_STDLIB inline), driven with `--emit=asm`. The
# borrowck lane fires in hir_to_mir during lowering, so `--emit=asm` (frontend +
# codegen, NO link) is enough and the whole `runtime.a` multi-def wall that killed
# the release_build / `hexa run compiler/main.hexa` approach never applies.
# (SSOT: project_hexa_l5_census_instrument_needs_fromsource_compiler — the RESOLVED
# instrument is build_aprime.sh, NOT release_build; and NOT the installed ~/.hx/bin
# binary, which pre-dates the borrowck lane.)
#
# ── ENV CONTRACT (aiden/summer pool — heavy build; mini = git/read only) ─────
#   REF        git ref to census (default: origin/main — REQUIRES #4978 merged;
#              until then pass REF=<the HX3061 branch> so the checker is present)
#   CANON      canonical repo clone     (default: $HOME/hexa-lang)
#   WORK       scratch root             (default: $HOME/hx3061_census)
#   TARGET     emit target triple       (default: x86_64-linux-gnu — EXACT match;
#              `linux-x86_64` / `aarch64-*` are rejected exit(2), build_aprime.sh:186)
#   CC / AR    build_aprime toolchain   (default: clang / ar)
#   CORPUS_DIRS  space-sep census roots (default: "stdlib compiler ../anima")
#   PERFILE_TIMEOUT  per-file compile cap seconds (default: 90)
# Self-harvests to $WORK/HX3061_CENSUS_RESULT.txt AND $HOME/HX3061_CENSUS_RESULT.txt.
# ─────────────────────────────────────────────────────────────────────────
set -u

# ── env scrub (no ambient borrowck leakage into the run) ─────────────────────
unset HEXA_BORROWCK HEXA_BORROWCK_STRICT HEXA_BORROWCK_CENSUS HEXA_BORROWCK_WARN_DEFAULT
unset HEXA_BORROWCK_HANDLE HEXA_BORROWCK_LEAK HEXA_DET HEXA_MOVE_DEFAULT

REF="${REF:-origin/main}"
CANON="${CANON:-$HOME/hexa-lang}"
WORK="${WORK:-$HOME/hx3061_census}"
TARGET="${TARGET:-x86_64-linux-gnu}"
export CC="${CC:-clang}"
export AR="${AR:-ar}"
CORPUS_DIRS="${CORPUS_DIRS:-stdlib compiler ../anima}"
PERFILE_TIMEOUT="${PERFILE_TIMEOUT:-90}"
RESULT="$WORK/HX3061_CENSUS_RESULT.txt"
FIRES="$WORK/hx3061_fires.txt"       # raw diag lines (compiler stderr, NOT source)
REAL_WL="$WORK/hx3061_real_leaks.txt"
FP_WL="$WORK/hx3061_fp_escapes.txt"

say() { echo "$@" | tee -a "$RESULT"; }

rm -rf "$WORK"; mkdir -p "$WORK"; : > "$RESULT"
say "=== HEXA-OWN L5 R2 HX3061 handle-LEAK census — $(date -u +%FT%TZ) — $(hostname) ==="
say "  ref=$REF target=$TARGET cc=$CC corpus_dirs=[$CORPUS_DIRS]"

# ── SECTION 1 (first_edit): clean-env + build the from-source aprime_cc ───────
# clean-env is MANDATORY: a stale pool build/ state crashes build_aprime.sh
# transpile ("index N out of bounds"), host-specifically (SSOT: census 6th-attempt
# breakthrough). Wipe the generated artifacts + hexa-cache before building.
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }
git -C "$CANON" fetch -f origin "+refs/heads/*:refs/remotes/origin/*" 2>>"$WORK/git.log" || true
git -C "$CANON" checkout -f "$REF" 2>>"$WORK/git.log" \
    || { say "FATAL checkout $REF (is #4978 merged? else pass REF=<HX3061 branch>)"; exit 3; }
say "  SRC sha=$(git -C "$CANON" rev-parse --short HEAD 2>/dev/null)"

# ★checker-present assertion — a checkout LACKING HX3061 silently yields 0 fires
# (absent lane, NOT a clean corpus). Refuse to census unless HX3061 is wired.
grep -q '"HX3061"' compiler/diag/catalog.hexa 2>/dev/null \
    && grep -q 'HEXA_BORROWCK_LEAK' compiler/lower/hir_to_mir.hexa 2>/dev/null \
    || { say "FATAL: HX3061 lane absent at $REF (no catalog DiagSpec / no HEXA_BORROWCK_LEAK gate) — #4978 not merged"; exit 3; }

say "--- SECTION 1: clean-env + build_aprime.sh (from-source aprime_cc) ---"
rm -f build/hexat build/aprime_cc build/runtime.a build/*.o
rm -rf "$HOME/.hexa-cache"
git clean -fdx build/ 2>>"$WORK/git.log" || true
CC="$CC" AR="$AR" bash tool/build_aprime.sh -o build/aprime_cc >"$WORK/build_aprime.log" 2>&1
BA_RC=$?
APRIME="$CANON/build/aprime_cc"
if [ ! -x "$APRIME" ] || [ "$BA_RC" != 0 ] || ! grep -q 'build_aprime.*OK' "$WORK/build_aprime.log"; then
    say "FATAL: aprime_cc not built (rc=$BA_RC) — tail:"
    tail -40 "$WORK/build_aprime.log" | sed 's/^/    /' | tee -a "$RESULT"; exit 4
fi
say "  aprime_cc built rc=$BA_RC ($(wc -c < "$APRIME" | tr -d ' ')B)"

# census invocation — flags FIRST, source .hexa LAST (raw[1]=.hexa is mis-read as a
# launcher and SKIPPED → false 0 fires; compiler/main.hexa:110-130). Count HX3061
# from the COMPILER STDERR only, never from source text (source comments carrying
# the string 'HX3061' are the grep-noise trap that faked HX3060 counts).
census_one() { # $1=srcfile ; emits diag lines on stdout ; env HEXA_BORROWCK_LEAK from caller
    local f="$1"
    timeout "$PERFILE_TIMEOUT" env HEXA_BORROWCK_LEAK=1 \
        "$APRIME" --emit=asm --target="$TARGET" -o /dev/null "$f" 2>&1 \
        | grep -E 'HX3061'
}

# ── SECTION 2: GATE-D self-check (prove the instrument before trusting corpus) ─
# leak_simple → exactly 1 · leak_conditional → >=1 · clean_freed / clean_returned → 0.
# (Mirrors the HX3060 GATE-D uaf_aba=2 / double_free=2 / clean=0 sign-of-life.)
say "--- SECTION 2: GATE-D fixture self-check ---"
FX=test/borrowck/handle_leak
g_simple=$(census_one "$FX/leak_simple.hexa"      | grep -c HX3061)
g_cond=$(census_one   "$FX/leak_conditional.hexa" | grep -c HX3061)
g_freed=$(census_one  "$FX/clean_freed.hexa"      | grep -c HX3061)
g_ret=$(census_one    "$FX/clean_returned.hexa"   | grep -c HX3061)
say "  leak_simple=$g_simple (exp>=1) · leak_conditional=$g_cond (exp>=1) · clean_freed=$g_freed (exp 0) · clean_returned=$g_ret (exp 0)"
if [ "$g_simple" -lt 1 ] || [ "$g_cond" -lt 1 ] || [ "$g_freed" != 0 ] || [ "$g_ret" != 0 ]; then
    say "FATAL: GATE-D FAILED — instrument mis-fires; corpus numbers untrustworthy. ABORT."; exit 5
fi
say "  GATE-D PASS — instrument validated."

# ── SECTION 3: enumerate the corpus (files that MINT a farr_* handle) ─────────
# Producer table (hir_to_mir.hexa:898): farr_zeros farr_copy farr_int_zeros
# farr_int_copy farr32_zeros. Only files containing a producer call can leak, so
# restrict the sweep (cuts cost; a producer-free file can never fire HX3061).
say "--- SECTION 3: corpus enumeration ---"
PRODUCERS='farr_zeros|farr_copy|farr_int_zeros|farr_int_copy|farr32_zeros'
CORPUS_LIST="$WORK/corpus.txt"; : > "$CORPUS_LIST"
for d in $CORPUS_DIRS; do
    [ -d "$d" ] || { say "  (skip missing dir $d)"; continue; }
    grep -rlE "\b($PRODUCERS)\b" "$d" --include='*.hexa' 2>/dev/null >> "$CORPUS_LIST"
done
sort -u "$CORPUS_LIST" -o "$CORPUS_LIST"
NFILES=$(wc -l < "$CORPUS_LIST" | tr -d ' ')
say "  corpus = $NFILES .hexa files minting a farr_* producer"

# ── SECTION 4: per-file census sweep ─────────────────────────────────────────
say "--- SECTION 4: per-file HX3061 sweep (timeout ${PERFILE_TIMEOUT}s) ---"
: > "$FIRES"
PERFILE="$WORK/perfile_counts.txt"; : > "$PERFILE"
i=0
while IFS= read -r f; do
    i=$((i+1))
    out=$(census_one "$f")
    rc=$?
    [ "$rc" = 124 ] && say "  [TIMEOUT] $f"
    c=$(printf '%s\n' "$out" | grep -c 'HX3061')
    if [ "$c" -gt 0 ]; then
        printf '%s\t%s\n' "$c" "$f" >> "$PERFILE"
        # tag each raw diag line with its source file for triage (Section 5)
        printf '%s\n' "$out" | grep 'HX3061' | sed "s#^#$f\t#" >> "$FIRES"
    fi
    [ $((i % 25)) = 0 ] && say "  ...$i/$NFILES scanned"
done < "$CORPUS_LIST"
TOTAL=$(grep -c 'HX3061' "$FIRES" 2>/dev/null || echo 0)
DISTINCT=$(sort -u "$PERFILE" 2>/dev/null | wc -l | tr -d ' ')

# ── SECTION 5: triage — REAL leak vs FP-escape ───────────────────────────────
# Each fire is anchored at the producer BIRTH span; the diag names the handle
# ({name}) and its born_line. Round-2 KNOWN-FP escapes (catalog HX3061): the handle
# leaves the function via a path the whole-local lane does not model —
#   (a) struct-field / global store:   <name> assigned into  X.field = <name>  /  G = <name>
#   (b) container store:               push(<name>)  /  [.. <name> ..]  aggregate
#   (c) ownership transfer to callee:  matmul(<name>) / from_bf16(<name>) / any @own sink
# A fire whose handle name shows NONE of these downstream in the same fn = candidate
# REAL leak. (return / reassign-overwrite are already KILLs, so they never fire.)
# This is a heuristic PRE-FILTER; the REAL worklist is hand-audited, the FP worklist
# feeds round-3 escape-widening. Extract {name}+{born_line} from the diag text.
say "--- SECTION 5: triage (REAL leak vs FP-escape) ---"
: > "$REAL_WL"; : > "$FP_WL"
ESCAPE_RE='(\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*NAME\b|(^|[^.])\b[A-Z][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*NAME\b|push\([[:space:]]*NAME\b|(matmul|from_bf16|sink|into_owned)\([^)]*\bNAME\b)'
while IFS=$'\t' read -r src diagline; do
    # parse handle name (`{name}`) + birth line from the HX3061 diag text
    name=$(printf '%s' "$diagline" | grep -oE "handle [\`']?[A-Za-z_][A-Za-z0-9_]*" | head -1 | grep -oE '[A-Za-z_][A-Za-z0-9_]*$')
    bl=$(printf '%s' "$diagline" | grep -oE 'line [0-9]+' | head -1 | grep -oE '[0-9]+')
    [ -z "$name" ] && { printf 'UNPARSED\t%s\t%s\n' "$src" "$diagline" >> "$FP_WL"; continue; }
    # scan the source file (from birth line to +60) for a downstream escape of `name`
    re=${ESCAPE_RE//NAME/$name}
    body=$(sed -n "${bl:-1},\$p" "$src" 2>/dev/null | head -60)
    if printf '%s\n' "$body" | grep -qE "$re"; then
        printf '%s\t%s@L%s\tFP-escape\n' "$src" "$name" "${bl:-?}" >> "$FP_WL"
    else
        printf '%s\t%s@L%s\tREAL?\n' "$src" "$name" "${bl:-?}" >> "$REAL_WL"
    fi
done < "$FIRES"
N_REAL=$(wc -l < "$REAL_WL" | tr -d ' ')
N_FP=$(wc -l < "$FP_WL" | tr -d ' ')

# ── SECTION 6: verdict ───────────────────────────────────────────────────────
say ""
say "════════════════════════════════════════════════════════════════════"
say "HX3061_CENSUS_VERDICT — L5 R2 handle-LEAK"
say "════════════════════════════════════════════════════════════════════"
say "REF                       = $REF ($(git -C "$CANON" rev-parse --short HEAD 2>/dev/null))"
say "CORPUS_FILES              = $NFILES  (producer-bearing .hexa)"
say "HX3061_TOTAL_FIRES        = $TOTAL"
say "HX3061_DISTINCT_FILES     = $DISTINCT"
say "TRIAGE_REAL_LEAK_CAND     = $N_REAL   ($REAL_WL — hand-audit)"
say "TRIAGE_FP_ESCAPE          = $N_FP     ($FP_WL — feeds round-3 escape-widening)"
say "PER_FILE (top 25):"
sort -rn "$PERFILE" 2>/dev/null | head -25 | sed 's/^/    /' | tee -a "$RESULT"
say "────────────────────────────────────────────────────────────────────"
say "FLIP GATE (HX3061 opt-in → opt-out, mirror HX3060 R4 #4975):"
say "  * FP-escape count must be 0 (all escapes modeled by round-3 widening)."
say "  * THEN clean corpus emits 0 HX3061 ⇒ default-ON flip is byteeq-neutral"
say "    (lane observe-only · MIR untouched · diag-only). Flip = hir_to_mir.hexa"
say "    _bck_leak_lane gate  env(\"HEXA_BORROWCK_LEAK\")==\"1\"  →  !=\"0\"."
say "  * PRE-widening this census is EXPECTED FP-HIGH — do NOT write the flip PR"
say "    until round-3 escape-widening lands + re-census drives FP-escape → 0."
say "════════════════════════════════════════════════════════════════════"
cp "$RESULT" "$HOME/HX3061_CENSUS_RESULT.txt" 2>/dev/null || true
say "=== DONE — verdict $RESULT · real=$REAL_WL · fp=$FP_WL (copies in \$HOME) ==="
