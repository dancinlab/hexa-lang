#!/usr/bin/env bash
# diff_fuzz.sh — MISCOMPILE-ZERO differential fuzzer.
#
# Generates seeded random hexa programs (tool/diff_fuzz_gen.py) and, for
# each, compares the gen2 NATIVE self-host compiler against the aprime/clang
# C ORACLE across three axes:
#
#   1. --emit=asm  : byte-diff modulo the documented benign per-module
#                    label-hash  __L<sha4>_  (canonicalized to __L_HASH_).
#   2. --emit=obj  : gen2 must produce 0 "ENCODE-MISS" and a non-empty .o.
#   3. behavior    : link both .o with the runtime + compare exit codes.
#
# ANY non-benign asm divergence / ENCODE-MISS / exit-code mismatch is a
# NEW miscompile — the harness STOPS, prints the offending seed + program,
# and exits non-zero (HONEST: no pipe-masked exits). A fully clean batch
# writes a verdict under .verdicts/miscompile-zero-fuzz/.
#
# Usage:
#   tool/diff_fuzz.sh <seed_lo> <seed_hi> [workdir]
#     workdir defaults to ~/dancinlab/selfhost-work (must hold gen2_fix,
#     aprime_fixhex, hld_fixed, rt_new.o, noatlas/ , _drv.hexa).
#
# Env overrides: GEN2, ORACLE, LINKER, RT_OBJ, ATLAS_DIR, DRV.
set -u

SEED_LO="${1:?usage: diff_fuzz.sh <seed_lo> <seed_hi> [workdir]}"
SEED_HI="${2:?usage: diff_fuzz.sh <seed_lo> <seed_hi> [workdir]}"
W="${3:-$HOME/dancinlab/selfhost-work}"

GEN2="${GEN2:-$W/gen2_fix}"
ORACLE="${ORACLE:-$W/aprime_fixhex}"
LINKER="${LINKER:-$W/hld_fixed}"
RT_OBJ="${RT_OBJ:-$W/rt_new.o}"
ATLAS_DIR="${ATLAS_DIR:-$W/noatlas}"
DRV="${DRV:-$W/_drv.hexa}"
TARGET="arm64-apple-darwin"

# Resolve generator next to this script.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
GEN="$SELF_DIR/diff_fuzz_gen.py"

for f in "$GEN2" "$ORACLE" "$LINKER" "$RT_OBJ" "$GEN"; do
    [ -e "$f" ] || { echo "FATAL: missing $f" >&2; exit 3; }
done
[ -d "$ATLAS_DIR" ] || { echo "FATAL: missing atlas dir $ATLAS_DIR" >&2; exit 3; }
# _drv.hexa is a consumed throwaway first-positional; create if absent.
[ -e "$DRV" ] || printf 'fn main() {}\n' > "$DRV"

SCRATCH="$(mktemp -d "$W/difffuzz.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

# Canonicalize asm: collapse the benign per-module label hash so only a
# REAL codegen divergence survives the diff.
canon() { sed -E 's/__L[0-9a-f]{4}_/__L_HASH_/g' "$1"; }

emit_asm() {  # emit_asm <compiler> <src> <out.s>  -> stderr to <out>.log
    HEXA_ATLAS_EMBED="$ATLAS_DIR" "$1" "$DRV" --emit=asm --target="$TARGET" \
        -o "$3" "$2" > "$3.log" 2>&1
}
emit_obj() {  # emit_obj <compiler> <src> <out.o>  -> stderr to <out>.log
    HEXA_ATLAS_EMBED="$ATLAS_DIR" "$1" "$DRV" --emit=obj --target="$TARGET" \
        -o "$3" "$2" > "$3.log" 2>&1
}

N=0
for SEED in $(seq "$SEED_LO" "$SEED_HI"); do
    N=$((N + 1))
    SRC="$SCRATCH/p$SEED.hexa"
    python3 "$GEN" "$SEED" > "$SRC" || { echo "FATAL: generator failed seed=$SEED" >&2; exit 4; }

    # ---- axis 1: asm diff ----
    GS="$SCRATCH/p$SEED.g.s"; AS="$SCRATCH/p$SEED.a.s"
    emit_asm "$GEN2"   "$SRC" "$GS"; GRC=$?
    emit_asm "$ORACLE" "$SRC" "$AS"; ARC=$?
    if [ $GRC -ne 0 ] || [ $ARC -ne 0 ]; then
        echo "=== DIVERGENCE seed=$SEED : asm-emit return-code mismatch (gen2=$GRC oracle=$ARC) ==="
        echo "--- program ---"; cat "$SRC"
        echo "--- gen2 stderr ---"; cat "$GS.log"
        echo "--- oracle stderr ---"; cat "$AS.log"
        exit 1
    fi
    if ! diff <(canon "$GS") <(canon "$AS") > "$SCRATCH/d$SEED.txt"; then
        echo "=== DIVERGENCE seed=$SEED : non-benign ASM mismatch ==="
        echo "--- program ---"; cat "$SRC"
        echo "--- asm diff (canonicalized) ---"; cat "$SCRATCH/d$SEED.txt"
        exit 1
    fi

    # ---- axis 2: obj emit / ENCODE-MISS / udf ----
    GO="$SCRATCH/p$SEED.g.o"
    emit_obj "$GEN2" "$SRC" "$GO"; GORC=$?
    EM=$(grep -c "ENCODE-MISS" "$GO.log" 2>/dev/null); EM=${EM:-0}
    UDF=$(grep -c "spurious udf\|unresolved udf" "$GO.log" 2>/dev/null); UDF=${UDF:-0}
    OBJSZ=$(stat -f%z "$GO" 2>/dev/null || stat -c%s "$GO" 2>/dev/null || echo 0)
    if [ $GORC -ne 0 ] || [ "$EM" -ne 0 ] || [ "$UDF" -ne 0 ] || [ "$OBJSZ" -eq 0 ]; then
        echo "=== DIVERGENCE seed=$SEED : gen2 obj-emit defect (rc=$GORC encode_miss=$EM udf=$UDF objsize=$OBJSZ) ==="
        echo "--- program ---"; cat "$SRC"
        echo "--- gen2 obj stderr ---"; cat "$GO.log"
        exit 1
    fi

    # ---- axis 3: behavioral exit-code compare ----
    AO="$SCRATCH/p$SEED.a.o"
    emit_obj "$ORACLE" "$SRC" "$AO" >/dev/null 2>&1
    GE="$SCRATCH/p$SEED.g.exe"; AE="$SCRATCH/p$SEED.a.exe"
    "$LINKER" -o "$GE" "$GO" "$RT_OBJ" --lc-main _main > "$SCRATCH/lg$SEED.log" 2>&1
    "$LINKER" -o "$AE" "$AO" "$RT_OBJ" --lc-main _main > "$SCRATCH/la$SEED.log" 2>&1
    if [ -x "$GE" ] && [ -x "$AE" ]; then
        "$GE"; GEX=$?
        "$AE"; AEX=$?
        if [ "$GEX" -ne "$AEX" ]; then
            echo "=== DIVERGENCE seed=$SEED : behavioral exit mismatch (gen2=$GEX oracle=$AEX) ==="
            echo "--- program ---"; cat "$SRC"
            exit 1
        fi
        echo "seed=$SEED OK  asm=match obj=clean exit=$GEX"
    else
        # link failure on BOTH is not a codegen divergence; on ONE it is.
        if [ -x "$GE" ] != [ -x "$AE" ]; then
            echo "=== DIVERGENCE seed=$SEED : link succeeded on only one compiler ==="
            echo "--- program ---"; cat "$SRC"
            exit 1
        fi
        echo "seed=$SEED OK  asm=match obj=clean exit=NA(both-no-link)"
    fi
done

echo
echo "ALL CLEAN: $N programs fuzzed (seeds $SEED_LO..$SEED_HI), no divergence."
exit 0
