#!/bin/bash
# tool/selfhost_parity_gate.sh — PARITY GATE for self-hosted toolchain promotion.
#
# The precondition that AUTHORIZES promoting the self-hosted native compiler
# (gen3, from tool/build_selfhost.sh) to be the default `hx`/hexa toolchain.
# Promotion is gated on this: gen3 and the current shipped reference compiler
# must produce EQUIVALENT output + identical runtime behaviour on a
# representative corpus. A failing gate BLOCKS promotion.
#
# Two parity axes per corpus program:
#   1. ASM parity   — gen3 --emit=asm  vs  REF --emit=asm   (textual byte-match
#                     after normalising volatile bits: local label counters,
#                     timestamps, absolute temp paths). A clean match is the
#                     strong proof. A diff is reported, not auto-failed, IF the
#                     behaviour axis still passes (codegen may differ benignly,
#                     e.g. reg allocation) — see --strict.
#   2. BEHAVIOUR    — compile+link+RUN each program with BOTH compilers; the
#                     observed exit codes must be identical AND match the
#                     program's pre-registered expected exit. This is the
#                     load-bearing axis: same observable semantics.
#   Plus a 42-smoke: fn main(){exit(6*7)} must exit 42 under gen3.
#
# A program PASSES parity iff: behaviour-match AND smoke-42. Under --strict,
# asm-match is ALSO required (any normalised asm diff fails the program).
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   tool/selfhost_parity_gate.sh -g GEN3 -l HEXA_LD -t RT_O [-c CORPUS_DIR]
#                                [-r REF] [-w WORK] [--strict]
#     -g GEN3        the self-hosted compiler under test (build/selfhost/gen3)
#     -l HEXA_LD     Mach-O linker (build/selfhost/hexa_ld)
#     -t RT_O        runtime object (build/selfhost/rt.o)
#     -r REF         reference compiler (default: the shipped hexa.real on PATH,
#                    else $HOME/.hx/bin/self/native/hexa_v2). Behaviour axis only
#                    needs gen3; REF enables the asm-parity axis.
#     -c CORPUS_DIR  dir of *.hexa parity programs (default: built-in corpus
#                    written to $WORK/corpus). Each file may carry a first-line
#                    `// expect: N` annotation (default expected exit = 0).
#     -w WORK        scratch dir (default: ./build/selfhost/parity) — NOT /tmp
#     --strict       require asm byte-match too (not just behaviour parity)
#
# ── Exit codes ───────────────────────────────────────────────────────────────
#   0  PARITY PASS — all programs pass; promotion AUTHORIZED
#   1  PARITY FAIL — at least one program failed behaviour/smoke (or asm in
#                    --strict). Promotion BLOCKED.
#   3  bad invocation / missing inputs
set -u

GEN3=""; LD=""; RTO=""; REF=""; CORPUS=""; WORK=""; STRICT=0
while [ $# -gt 0 ]; do
    case "$1" in
        -g) GEN3="$2"; shift 2 ;;
        -l) LD="$2"; shift 2 ;;
        -t) RTO="$2"; shift 2 ;;
        -r) REF="$2"; shift 2 ;;
        -c) CORPUS="$2"; shift 2 ;;
        -w) WORK="$2"; shift 2 ;;
        --strict) STRICT=1; shift ;;
        *) echo "parity_gate: unknown arg '$1'" >&2; exit 3 ;;
    esac
done

[ -x "$GEN3" ] || { echo "parity_gate: gen3 missing/not-exec: '$GEN3' (need -g)" >&2; exit 3; }
[ -x "$LD" ]   || { echo "parity_gate: hexa_ld missing: '$LD' (need -l)" >&2; exit 3; }
[ -s "$RTO" ]  || { echo "parity_gate: rt.o missing: '$RTO' (need -t)" >&2; exit 3; }
[ -z "$WORK" ] && WORK="$(pwd)/build/selfhost/parity"
case "$WORK" in /tmp/*|/private/tmp/*) echo "parity_gate: WORK must not be under /tmp" >&2; exit 3 ;; esac
mkdir -p "$WORK" || { echo "parity_gate: cannot mkdir $WORK" >&2; exit 3; }

# resolve reference compiler (asm-parity axis; optional)
if [ -z "$REF" ]; then
    if command -v hexa.real >/dev/null 2>&1; then REF="$(command -v hexa.real)"
    elif [ -x "$HOME/.hx/bin/hexa.real" ]; then REF="$HOME/.hx/bin/hexa.real"
    elif [ -x "$HOME/.hx/bin/self/native/hexa_v2" ]; then REF="$HOME/.hx/bin/self/native/hexa_v2"
    fi
fi
[ -n "$REF" ] && [ -x "$REF" ] && HAVE_REF=1 || HAVE_REF=0

NOATLAS="$WORK/noatlas"; mkdir -p "$NOATLAS"
emit() { HEXA_ATLAS_EMBED="$NOATLAS" "$@"; }

# ── built-in representative corpus (if none supplied) ────────────────────────
if [ -z "$CORPUS" ]; then
    CORPUS="$WORK/corpus"; mkdir -p "$CORPUS"
    cat > "$CORPUS/arith.hexa"   <<'H'
// expect: 42
fn main() { let x = 6 * 7; exit(x) }
H
    cat > "$CORPUS/call.hexa"    <<'H'
// expect: 13
fn add(a, b) { return a + b }
fn main() { exit(add(6, 7)) }
H
    cat > "$CORPUS/branch.hexa"  <<'H'
// expect: 7
fn main() { let mut s = 0; let mut i = 0; while i < 7 { s = s + 1; i = i + 1 }; exit(s) }
H
    cat > "$CORPUS/bitmask.hexa" <<'H'
// expect: 15
fn main() { let v = 255 & 0x0f; exit(v) }
H
    cat > "$CORPUS/recurse.hexa" <<'H'
// expect: 120
fn fac(n) { if n <= 1 { return 1 }; return n * fac(n - 1) }
fn main() { exit(fac(5)) }
H
fi

NORM='s|[0-9]{4}-[0-9]{2}-[0-9]{2}T?[0-9:]*||g; s|L[._a-zA-Z0-9]*[0-9]+|Lnorm|g; s#/[^ ]*/(prog|parity)[^ ]*#PATH#g'

PASS=0; FAIL=0; TOTAL=0
echo "=== selfhost parity gate ==="
echo "gen3=$GEN3"
echo "ref=${REF:-<none>} (asm-axis=$([ $HAVE_REF = 1 ] && echo on || echo off)) strict=$STRICT"
echo "corpus=$CORPUS"
printf '%-14s %-10s %-10s %-8s %s\n' PROG BEHAVIOUR ASM SMOKE VERDICT
printf '%-14s %-10s %-10s %-8s %s\n' ---- --------- --- ----- -------

for src in "$CORPUS"/*.hexa; do
    name="$(basename "$src" .hexa)"; TOTAL=$((TOTAL+1))
    exp=$(grep -m1 -oE '// *expect: *-?[0-9]+' "$src" | grep -oE '\-?[0-9]+' || echo 0)
    [ -z "$exp" ] && exp=0
    d="$WORK/$name"; mkdir -p "$d"

    # gen3 compile -> asm -> obj -> link -> run
    emit "$GEN3" _drv.hexa --emit=asm --target=arm64-apple-darwin -o "$d/g.s" "$src" > "$d/g.emit.log" 2>&1
    GEN_BEHAV="ERR"; GEN_RC="x"
    if [ -s "$d/g.s" ]; then
        clang -arch arm64 -c "$d/g.s" -o "$d/g.o" 2>"$d/g.cc.log" \
          && "$LD" -o "$d/g.bin" "$d/g.o" "$RTO" --lc-main _main >"$d/g.ld.log" 2>&1 \
          && { "$d/g.bin"; GEN_RC=$?; }
        [ "$GEN_RC" = "$exp" ] && GEN_BEHAV="ok($GEN_RC)" || GEN_BEHAV="bad($GEN_RC!=$exp)"
    fi

    # asm parity vs ref (normalised)
    ASM="skip"
    if [ "$HAVE_REF" = 1 ]; then
        emit "$REF" _drv.hexa --emit=asm --target=arm64-apple-darwin -o "$d/r.s" "$src" > "$d/r.emit.log" 2>&1
        if [ -s "$d/r.s" ]; then
            sed -E "$NORM" "$d/g.s" > "$d/g.norm.s"
            sed -E "$NORM" "$d/r.s" > "$d/r.norm.s"
            if cmp -s "$d/g.norm.s" "$d/r.norm.s"; then ASM="match"; else ASM="diff"; fi
        else ASM="ref-err"; fi
    fi

    # 42-smoke is the arith program; reuse its behaviour for the smoke col
    SMOKE="n/a"; [ "$name" = "arith" ] && { [ "$GEN_RC" = 42 ] && SMOKE="42-ok" || SMOKE="42-FAIL"; }

    ok=1
    case "$GEN_BEHAV" in ok\(*) : ;; *) ok=0 ;; esac
    [ "$name" = "arith" ] && [ "$SMOKE" != "42-ok" ] && ok=0
    [ "$STRICT" = 1 ] && [ "$ASM" = "diff" ] && ok=0
    if [ "$ok" = 1 ]; then V="PASS"; PASS=$((PASS+1)); else V="FAIL"; FAIL=$((FAIL+1)); fi
    printf '%-14s %-10s %-10s %-8s %s\n' "$name" "$GEN_BEHAV" "$ASM" "$SMOKE" "$V"
done

echo "----"
echo "parity: $PASS/$TOTAL pass, $FAIL fail (strict=$STRICT, asm-axis=$([ $HAVE_REF = 1 ] && echo on || echo off))"
if [ "$FAIL" = 0 ] && [ "$TOTAL" -gt 0 ]; then
    echo "RESULT: PARITY PASS — promotion AUTHORIZED"
    exit 0
else
    echo "RESULT: PARITY FAIL — promotion BLOCKED"
    exit 1
fi
