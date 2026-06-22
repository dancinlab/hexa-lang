#!/usr/bin/env bash
# tool/zeroc_flip_measure.sh — RFC061 ∅ campaign: REPRODUCIBLE-FROM-TREE flip
#                              undefined-symbol measurement + classification.
#
# WHY THIS EXISTS (the PRIORITY-0 honesty gap it closes)
# ──────────────────────────────────────────────────────
# The zero-c whole-runtime "flip" (drop the pure-C runtime_core.c bodies, supply
# everything from native seed objects, leave only the irreducible externals
# undefined) was measured TWICE on EPHEMERAL aiden scaffolds with CONTRADICTORY
# results that NEITHER regenerated from a clean tree:
#     r2 →  124 undefined,  svc = 0   (raw-svc already resolved in-tree)
#     r3 →  104 undefined,  svc = 91  (raw-svc irreducible)
# Both needed UN-COMMITTED seed-wiring on the box, so the number could not be
# reproduced or audited. This script commits the WHOLE seed-wiring scaffold so
# anyone can regenerate the count from a clean checkout — and it captures the
# real wall the naive flip hits.
#
# WHAT IT MEASURES (all from a clean tree, no ephemeral edits)
# ────────────────────────────────────────────────────────────
#   1. restore_frozen_seeds            → self/runtime.c (frozen blob 151c52c8)
#   2. regen runtime_core.c            → from self/runtime_core_emit.hexa (SSOT,
#                                          carries the #3811 DROP_RTCORE flag)
#   3. build EVERY native seed object  → build/*.o (all landed clusters)
#   4. PROBE-A "default flip" link      → runtime.c compiled with every cluster
#        body EXTERNED to its seed (-DHEXA_RT_CORE_*_NATIVE) + the #3811
#        HEXA_ZEROC_DROP_RTCORE include-drop, then nm -u → the reproducible
#        undefined set + a per-class breakdown (svc / libm / crt / frozen_static
#        / wrapper_missing / other).
#   5. PROBE-B "SELFEMIT whole-runtime flip" → the same TU with the BROAD
#        -DHEXA_RT_SELFEMIT master flip. This is the r2/r3 "whole-runtime flip".
#        It USED TO FAIL TO COMPILE from a clean tree — the frozen runtime.c
#        linux branch leaves the hxlcl_* libc-wrapper DEFINITIONS unconditionally
#        `static` (the darwin branch #ifndef-guards them; the SELFEMIT port was
#        never applied to linux), conflicting with the non-static externs
#        SELFEMIT introduces (17 `static declaration follows non-static`). r5
#        (stage 2b, tool/zeroc_selfemit_unstatic_linux.sh) UNBLOCKS it via a
#        NON-FROZEN post-restore patch that wraps those 17 defs in
#        `#ifndef HEXA_RT_SELFEMIT`, mirroring the darwin branch — so PROBE-B now
#        COMPILES and yields the REAL reproducible SELFEMIT undefined count
#        (settles the r2=124 / r3=104 contradiction). Byte-neutral on default.
#
# MEASURE-ONLY: this script never mutates the default build, never stages, never
# links a shipping binary. It writes only to /tmp + build/*.o (gitignored seed
# objects). It is safe to run on any host with clang + binutils.
#
# Usage:  bash tool/zeroc_flip_measure.sh            (run at repo root)
#         OUT_DIR=/tmp/zflip bash tool/zeroc_flip_measure.sh
#
# Exit 0 always when the measurement completes (the SELFEMIT wall is data, not
# a failure). Exit 1 only if the tree/toolchain is unusable.
set -uo pipefail

ROOT="${ROOT:-$PWD}"
OUT_DIR="${OUT_DIR:-/tmp/zeroc_flip}"
CC="${CC:-clang}"
mkdir -p "$OUT_DIR"
cd "$ROOT" || { echo "zflip: bad ROOT '$ROOT'" >&2; exit 1; }
[ -f self/runtime_core_emit.hexa ] || { echo "zflip: run at repo root (no self/runtime_core_emit.hexa)" >&2; exit 1; }

case "$(uname -m)" in
    x86_64)        ARCH=x86_64 ; ARCH_FLAG="" ;;
    aarch64|arm64) ARCH=arm64  ; ARCH_FLAG="" ;;
    *)             ARCH="$(uname -m)" ; ARCH_FLAG="" ;;
esac
export ARCH_FLAG CC

echo "════════════════════════════════════════════════════════════════"
echo " zeroc_flip_measure — RFC061 ∅ reproducible flip undefined dump"
echo "   host $(uname -srm)   commit $(git rev-parse --short HEAD 2>/dev/null)"
echo "════════════════════════════════════════════════════════════════"

# ── stage 1: restore frozen runtime seeds (self/runtime.c, blob 151c52c8) ──
echo "[1/5] restore_frozen_seeds (self/runtime.c <- frozen blob)…"
bash tool/restore_frozen_seeds >/dev/null 2>&1 \
    || { echo "zflip: restore_frozen_seeds failed" >&2; exit 1; }
[ -f self/runtime.c ] || { echo "zflip: self/runtime.c not restored" >&2; exit 1; }

# ── stage 2: regenerate runtime_core.c from the emitter SSOT ────────────────
# This is the #3811 emitter — the regenerated runtime_core.c carries the
# #ifndef HEXA_ZEROC_DROP_RTCORE / #include "runtime_hexaval_abi.h" disentangle.
echo "[2/5] regen runtime_core.c from emitter SSOT…"
bash tool/regen_runtime_core_c.sh >/dev/null 2>&1 \
    || { echo "zflip: regen_runtime_core_c failed" >&2; exit 1; }
DROP_PRESENT=$(grep -c 'HEXA_ZEROC_DROP_RTCORE' self/runtime_core.c 2>/dev/null || echo 0)
ABI_INC=$(grep -c 'runtime_hexaval_abi.h' self/runtime_core.c 2>/dev/null || echo 0)
echo "      DROP_RTCORE flag sites: $DROP_PRESENT   abi #include: $ABI_INC"

# ── stage 2b: non-frozen SELFEMIT static-conflict patch (PROBE-B unblock) ───
# The frozen runtime.c linux branch leaves the hxlcl_* libc-wrapper DEFINITIONS
# unconditionally `static` (the darwin branch #ifndef-guards them; the linux
# port was never applied) — so under SELFEMIT the extern forward-decls conflict
# with those static defs ("static declaration follows non-static"). This patch
# wraps the linux-branch defs in `#ifndef HEXA_RT_SELFEMIT` AFTER restore, never
# touching the frozen blob. It is byte-neutral on the default (non-SELFEMIT)
# build (the guard is transparent when SELFEMIT is undefined — proven: the
# default .o is byte-identical patched vs frozen).
echo "[2b]  non-frozen SELFEMIT linux-branch static-drop patch (PROBE-B unblock)…"
UNSTATIC_N=0
if [ -f tool/zeroc_selfemit_unstatic_linux.sh ]; then
    bash tool/zeroc_selfemit_unstatic_linux.sh >/dev/null 2>&1 || true
    UNSTATIC_N=$(grep -c 'ZEROC_SELFEMIT_LINUX_UNSTATIC' self/runtime.c 2>/dev/null || echo 0)
    echo "      linux-branch defs guarded: $UNSTATIC_N (expect 17 on linux, 0 on darwin)"
else
    echo "      WARN: tool/zeroc_selfemit_unstatic_linux.sh absent — PROBE-B will hit the wall"
fi

# ── stage 3: build EVERY landed native seed object ─────────────────────────
echo "[3/5] build all native seed objects (build/*.o)…"
build_clusters() {
    local s out scr
    for s in leaf arith math math2 map-query-fold collection-mutate \
             array-typed-leaf fs-read-write arith-coerce-format runtime-misc; do
        out="build/rtcore_${s//-/_}_native.o"
        scr="tool/regen_rtcore_${s}_native_o.sh"
        [ -f "$scr" ] || { echo "      NOSCR $scr"; continue; }
        bash "$scr" "$out" >/dev/null 2>&1 \
            && echo "      ok  $out" || echo "      FAIL $out"
    done
}
# arch-suffixed .s seeds → build/<name>_native.o (assemble if absent)
build_asm_seed() {
    local name="$1" out="build/${1}_native.o" seed="self/native/${1}_${ARCH}.s"
    [ -f "$out" ] && { echo "      have $out"; return; }
    [ -f "$seed" ] || { echo "      no-seed $seed"; return; }
    $CC -c $ARCH_FLAG "$seed" -o "$out" 2>/dev/null \
        && echo "      asm $out" || echo "      FAIL-asm $out"
}
build_clusters
for n in array_core map_core alloc_syscall valop_core num_core num_float_core \
         intern_core fs_core str_core runtime_hi; do
    build_asm_seed "$n"
done
# runtime_hi has the bare name runtime_hi_native.s on some trees:
[ -f build/runtime_hi_native.o ] || \
    { [ -f self/native/runtime_hi_native.s ] && \
      $CC -c $ARCH_FLAG self/native/runtime_hi_native.s -o build/runtime_hi_native.o 2>/dev/null \
      && echo "      asm build/runtime_hi_native.o"; }

# the cluster -D extern flags (extern every seeded body out of the inline .c)
CLUSTER_DEFS="\
-DHEXA_RT_CORE_LEAF_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 \
-DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 \
-DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 \
-DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 \
-DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1"

CFLAGS="-c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self -I ."
[ "$(uname -s)" = "Darwin" ] && CFLAGS="$CFLAGS -D_DARWIN_C_SOURCE"

# ── stage 4: PROBE-A — reproducible "default flip" link + undefined dump ────
echo "[4/5] PROBE-A: runtime.c with all cluster bodies externed to seeds +"
echo "             #3811 DROP_RTCORE; nm -u → reproducible undefined set"
RTA="$OUT_DIR/rt_flipA.o"
A_ERR="$($CC $CFLAGS -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
        self/runtime.c -o "$RTA" 2>&1 | grep -iE 'error:' | head -5)"
if [ -n "$A_ERR" ] || [ ! -f "$RTA" ]; then
    echo "      PROBE-A FAILED TO COMPILE (unexpected — default flip should build):"
    echo "$A_ERR" | sed 's/^/        /'
    echo "FLIP_A_COMPILES=NO"
else
    nm -u "$RTA" 2>/dev/null | awk '{print $NF}' | sort -u > "$OUT_DIR/undef_A.txt"
    A_TOTAL=$(wc -l < "$OUT_DIR/undef_A.txt" | tr -d ' ')
    echo "      PROBE-A OK — runtime.o undefined (unique): $A_TOTAL"
    echo "FLIP_A_COMPILES=YES"
    echo "REAL_UNDEFINED_TOTAL=$A_TOTAL"
fi

# ── stage 5: PROBE-B — SELFEMIT whole-runtime flip (the r2/r3 path) ─────────
# WAS expected to FAIL on a clean tree (the frozen linux-branch static-conflict
# wall). r5 UNBLOCKED it via the non-frozen stage-2b patch (#zeroc r5) that
# guards the 17 linux-branch hxlcl_* defs under #ifndef HEXA_RT_SELFEMIT. With
# that patch applied, PROBE-B COMPILES and we capture the REAL reproducible
# SELFEMIT undefined set (settles the r2=124 / r3=104 contradiction).
echo "[5/5] PROBE-B: SELFEMIT whole-runtime flip (r2/r3 path · r5 patch unblocks)"
RTB="$OUT_DIR/rt_flipB.o"
B_ERR="$($CC $CFLAGS -DHEXA_RT_SELFEMIT -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS \
        self/runtime.c -o "$RTB" 2>&1 | grep -iE 'error:' | head -8)"
if [ -n "$B_ERR" ] || [ ! -f "$RTB" ]; then
    STATIC_WALL=$(echo "$B_ERR" | grep -c "static declaration of 'hxlcl_")
    echo "      PROBE-B DOES NOT COMPILE (linux-branch static wall — patch missing?):"
    echo "$B_ERR" | sed 's/^/        /'
    echo "FLIP_B_COMPILES=NO  frozen_static_conflicts=$STATIC_WALL"
else
    nm -u "$RTB" 2>/dev/null | awk '{print $NF}' | sort -u > "$OUT_DIR/undef_B.txt"
    B_TOTAL=$(wc -l < "$OUT_DIR/undef_B.txt" | tr -d ' ')
    B_HXLCL=$(grep -cE '^_?hxlcl_' "$OUT_DIR/undef_B.txt" 2>/dev/null | tr -d ' ')
    echo "      PROBE-B OK — undefined (unique): $B_TOTAL   (hxlcl_ externs: $B_HXLCL)"
    echo "FLIP_B_COMPILES=YES"
    echo "SELFEMIT_UNDEFINED_TOTAL=$B_TOTAL"
fi

# ── classify the reproducible PROBE-A undefined set ────────────────────────
U="$OUT_DIR/undef_A.txt"
if [ -f "$U" ]; then
    echo "──────────── UNDEFINED CLASSIFICATION (PROBE-A, reproducible) ────────────"
    LIBM_RE='^(sin|cos|tan|tanh|sinh|cosh|exp|expf|log|logf|log2|log10|sqrt|sqrtf|pow|floor|ceil|round|llround|lround|atan|atan2|asin|acos|erf|erfc|lgamma|tgamma|j0|j1|fabs|fmod|cbrt|hypot|trunc)$'
    # svc = raw-svc / @syscall-EMITTER symbols (NOT libc syscall wrappers).
    # In-tree raw-svc seeds emit the `svc`/`syscall` machine instruction inline
    # and export NO undefined emitter symbol; a real svc gap would surface as an
    # undefined __hx_syscall* / __raw_sys* / raw_svc* / @syscall_* symbol.
    SVC_RE='(^__hx_syscall|^__raw_sys|^raw_svc|@syscall|^hexa_syscall|^__svc_)'
    # CRT / libc startup + libc non-syscall helpers (resolved by -lc).
    CRT_RE='^(memcpy|memset|memmove|qsort|rand|srand|_exit|environ|longjmp|setjmp|__libc_calloc|__libc_free|__libc_start_main|mallopt|sysconf|strtod|strtol|__isoc23_sscanf|sscanf|snprintf|vsnprintf|fprintf|fgets|fputs|fwrite|fread|fopen|fclose|getenv|abort|__stack_chk_fail|__assert_fail)$'
    # frozen-static = the hxlcl_* libc wrappers that live STATIC in the frozen
    # runtime.c blob (the SELFEMIT wall). They never appear undefined in PROBE-A
    # (they are static-defined there); counted only if they leak as undefined.
    FROZEN_RE='^hxlcl_'
    # wrapper_missing = hexa_*/rt_* runtime symbols a seed object should supply
    # but did not (a real seed-coverage gap, resolvable by linking the seed .o).
    WRAP_RE='^(hexa_|rt_|__hx_|__map_|hxqwen)'

    cnt() { grep -cE "$1" "$U" 2>/dev/null | tr -d ' '; }
    SVC=$(cnt "$SVC_RE")
    LIBM=$(cnt "$LIBM_RE")
    CRT=$(cnt "$CRT_RE")
    FROZEN=$(cnt "$FROZEN_RE")
    WRAP=$(cnt "$WRAP_RE")
    TOTAL=$(wc -l < "$U" | tr -d ' ')
    OTHER=$(( TOTAL - SVC - LIBM - CRT - FROZEN - WRAP ))
    [ "$OTHER" -lt 0 ] && OTHER=0
    echo "  total unique undefined : $TOTAL"
    echo "  svc  (raw-svc emitter) : $SVC"
    echo "  libm (transcendental)  : $LIBM"
    echo "  crt  (libc startup)    : $CRT"
    echo "  frozen_static (hxlcl_) : $FROZEN"
    echo "  wrapper_missing        : $WRAP"
    echo "  other (libc/posix/net) : $OTHER"
    echo "  --- svc class members (should be EMPTY if raw-svc resolved in-tree) ---"
    grep -E "$SVC_RE" "$U" | sed 's/^/    /' || true
    echo "  --- full dump at: $U ---"
fi
echo "════════════════════════════════════════════════════════════════"
echo "DONE. Artifacts in $OUT_DIR (undef_A.txt = the reproducible dump)."
exit 0
