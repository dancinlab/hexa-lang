#!/bin/bash
# tool/build_aprime.sh — canonical aprime_cc build recipe.
#
# aprime_cc = the native arm64-asm hexa-lang compiler — the direct-asm
# codegen path (compiler/main.hexa
# transpiled by hexat → C → clang → a self-contained Mach-O that emits
# arm64 .s directly, no further hexat dependency at compile time).
#
# This script canonicalises the recipe formerly kept only at
# /tmp/arm64_feasible.sh so the build is reproducible from the repo.
#
# Usage:
#   tool/build_aprime.sh [-o OUT] [-r REPO] [-v HEXA_V2]
#
#   -o OUT       output binary path        (default: build/aprime_cc)
#   -r REPO      repo root to build from   (default: cwd; must hold compiler/)
#   -v HEXA_V2   hexat transpiler path    (default: <repo>/self/native/hexat)
#
# Exit codes:
#   0  aprime_cc built + smoke (exit(6*7)==42) PASS
#   1  build failed (flatten / transpile / clang)
#   2  smoke failed (binary built but exit code != 42)
#
# Pipeline (5 stages — mirrors n1 self-hosted-toolchain note):
#   1. flatten compiler/main.hexa import+use closure; stub embedded.gen.hexa
#      (empty ATLAS_* — avoids the O(n^2) array-literal transpile hang).
#   2. hexat transpile flat .hexa -> .c
#   3. tool/s4_flatc_post.py + sed fixups (sha256_hex/list_dir builtins,
#      runtime.h -> runtime.c inline so the single-TU build links).
#   4. clang -O1 -arch arm64 ap_post.c -> aprime_cc.
#   5. smoke: aprime_cc compiles `fn main(){exit(6*7)}`, link + run, $?==42.
set -u

OUT="build/aprime_cc"
REPO="$(pwd)"
HEXA_V2=""

while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUT="$2"; shift 2 ;;
        -r) REPO="$2"; shift 2 ;;
        -v) HEXA_V2="$2"; shift 2 ;;
        *) echo "build_aprime: unknown arg '$1'" >&2; exit 1 ;;
    esac
done

cd "$REPO" || { echo "build_aprime: bad repo '$REPO'" >&2; exit 1; }
[ -f compiler/main.hexa ] || { echo "build_aprime: no compiler/main.hexa under $REPO" >&2; exit 1; }
[ -z "$HEXA_V2" ] && HEXA_V2="$REPO/self/native/hexat"

# RT-NATIVE Z2a/leg B (default-on for arm64-darwin AND x86_64-linux): the native
# runtime_hi path (build/rt_hi_native.o from a frozen self/native/runtime_hi_*.s
# seed, instead of the hexat-transpiled runtime_hi_gen.c) drops runtime_hi_gen.c
# from `ls self/*.c`.
#   arm64-darwin → runtime_hi_native.s  (Mach-O; byte-id + runtime-verified)
#   x86_64-linux → runtime_hi_x86_64.s  (ELF; x86_64 codegen graduated —
#       F-X86-GEN3-GEN4-BYTEEQ + F-X86-WHOLECOMPILER-ASSEMBLES; seed cross-
#       assembles clean, all 14 rt_str_* = T symbols).
# linux-arm64 still has no seed → keeps the C path. Override HEXA_ZEROC_RT_HI=0
# to force the legacy C path on any platform.
case "$(uname -sm 2>/dev/null)" in
    "Darwin arm64")
        [ -f "$REPO/self/native/runtime_hi_native.s" ] \
            && export HEXA_ZEROC_RT_HI="${HEXA_ZEROC_RT_HI:-1}" ;;
    "Linux x86_64")
        [ -f "$REPO/self/native/runtime_hi_x86_64.s" ] \
            && export HEXA_ZEROC_RT_HI="${HEXA_ZEROC_RT_HI:-1}" ;;
esac

# ── stage 0: regen (clean-checkout self-build) ─────────────────────
# Make this recipe self-contained on a fresh `.c=0` checkout. The two
# inputs the pipeline assumes — the amalgam self/runtime.c (stage-3 inline
# + stage-5 smoke link) and the transpiler hexat (stage-2 / HEXA_V2) — are
# GENERATED, .gitignore'd artifacts (absent on a clean clone). STAGE-0
# regenerates them from tracked sources using the SAME mechanism the
# release/nobaseline CI verifies (BUILDFLOOR M7):
#   restore_frozen_seeds -> stage_resolve_runtime_a (runtime_core.c emitter
#   regen + SSOT reconcile + build runtime.a) -> stage_prebuild_hexat.
# IDEMPOTENT: skip entirely when both artifacts are already fresh, so a
# warm tree (or a re-run) is a no-op and the recipe stays byte-stable.
if [ -x "$HEXA_V2" ] && [ -f self/runtime.c ]; then
    echo "  [0/5] regen: SKIP — hexat + self/runtime.c already present (warm tree)"
else
    echo "  [0/5] regen: clean checkout — restoring seeds + building hexat from SSOT"
    # STAGE-0 toolchain env (mirrors release CI Stage 0b contract).
    export CC="${CC:-clang}"
    export LIBS="${LIBS:--lm}"
    export CFLAGS_COMMON="${CFLAGS_COMMON:--O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs}"
    # 0a: restore frozen bootstrap seeds (self/runtime.c + #include fragments
    #     + self/native/hexa_cc.c) into the working tree (uncommitted).
    bash tool/restore_frozen_seeds || { echo "build_aprime: STAGE-0 restore_frozen_seeds failed" >&2; exit 1; }
    # 0b: resolve build/runtime.a — regenerates self/runtime_core.c from its
    #     emitter SSOT (self/runtime_core_emit.hexa) + reconciles runtime.c
    #     SSOT dups, then compiles runtime.a from source (seeds-present path).
    bash tool/stage_resolve_runtime_a || { echo "build_aprime: STAGE-0 stage_resolve_runtime_a failed" >&2; exit 1; }
    # 0c: build build/hexat (self-hosted transpiler) from hexa_cc.c + runtime.a.
    HEXA_PREBUILT_RUNTIME="$REPO/build/runtime.a" bash tool/stage_prebuild_hexat \
        || { echo "build_aprime: STAGE-0 stage_prebuild_hexat failed" >&2; exit 1; }
    # 0d: point HEXA_V2 at the STAGE-0-built transpiler. Prefer the canonical
    #     build/hexat (already covered by the `build/` .gitignore) over the
    #     default self/native/hexat path so STAGE-0 leaves NO un-ignored,
    #     committable binary artifact in the tree. Only fall back to the
    #     self/native/hexat default if the caller pre-placed a binary there.
    if [ ! -x "$HEXA_V2" ] && [ -x build/hexat ]; then
        HEXA_V2="$REPO/build/hexat"
    fi
    echo "  [0/5] regen: runtime.c=$( [ -f self/runtime.c ] && wc -l < self/runtime.c || echo MISSING )L · hexat=$( [ -x "$HEXA_V2" ] && wc -c < "$HEXA_V2" || echo MISSING )B"
fi

[ -x "$HEXA_V2" ] || { echo "build_aprime: hexat missing/not-executable: $HEXA_V2" >&2; exit 1; }

# ── platform arch flag ─────────────────────────────────────────────
# `-arch arm64` is an Apple-clang extension; on Linux clang it errors with
# `unsupported option -arch for target x86_64-pc-linux-gnu` (handoff 4565ac05).
# On Darwin keep the explicit -arch (we cross from any host to arm64 Mach-O);
# on Linux omit it entirely so host clang picks the native arch — matching
# the arch-clean cflags the rest of the toolchain uses (os_clang_cflags).
# The emit-target for the stage-5 smoke is likewise platform-derived.
if [ "$(uname -s)" = "Darwin" ]; then
    ARCH_FLAG="-arch arm64"
    SMOKE_TARGET="arm64-apple-darwin"
    # Apple ld dead-strip spelling (GNU ld rejects `-dead_strip`).
    DEAD_STRIP="-Wl,-dead_strip"
else
    ARCH_FLAG=""
    # GNU ld equivalent of Apple `-dead_strip`; pairs with
    # -ffunction-sections/-fdata-sections to drop unused code on Linux.
    DEAD_STRIP="-Wl,--gc-sections"
    # aprime_cc's --emit=asm matches target triples by EXACT string equality
    # (compiler/main.hexa codegen dispatch); its Linux triples are
    # `arm64-linux-gnu` / `x86_64-linux-gnu` — NOT the LLVM `aarch64-` /
    # `-unknown-` spellings, which it rejects with exit(2).
    case "$(uname -m)" in
        arm64|aarch64) SMOKE_TARGET="arm64-linux-gnu"  ;;
        *)             SMOKE_TARGET="x86_64-linux-gnu" ;;
    esac
fi

TMP="$(mktemp -d -t aprime_build.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FLAT="$TMP/ap_flat.hexa"
APC="$TMP/ap.c"
APPOST="$TMP/ap_post.c"

echo "=== build_aprime: repo=$REPO  hexat=$HEXA_V2 ==="
echo "HEAD: $(git log --oneline -1 2>/dev/null || echo '(not a git repo)')"

# ── stage 1: flatten ───────────────────────────────────────────────
REPO="$REPO" FLAT="$FLAT" python3 - <<'PY'
import re, os
repo = os.environ["REPO"]; flat = os.environ["FLAT"]
os.chdir(repo)
seen=[]; sset=set()
STUB=('pub let ATLAS_HASH: string = "fixture"\n'
      'pub let ATLAS_SOURCE_COUNT: i64 = 0\n'
      'pub let ATLAS_GENERATED_AT: string = "fixture"\n'
      + ''.join(f'pub let ATLAS_{k}_NODES: [AtlasNode] = []\n' for k in "PCLEFRSXQ"))
def walk(f):
    f=os.path.normpath(f)
    if f in sset or not os.path.exists(f): return
    sset.add(f); d=os.path.dirname(f)
    txt=open(f,encoding="utf-8",errors="replace").read(); deps=[]
    for m in re.finditer(r'^\s*import\s+"([^"]+)"',txt,re.M):
        deps.append(os.path.normpath(os.path.join(d,m.group(1))))
    for m in re.finditer(r'^\s*use\s+"([^"]+)"',txt,re.M):
        p=m.group(1)
        if not p.endswith(".hexa"): p+=".hexa"
        for c in [p,os.path.join(d,p),os.path.join(d,os.path.basename(p))]:
            if os.path.exists(os.path.normpath(c)): deps.append(os.path.normpath(c)); break
    for x in deps: walk(x)
    seen.append(f)
walk("compiler/main.hexa")
out=[]
for f in seen:
    if f.endswith("embedded.gen.hexa"): out.append("// STUB\n"+STUB); continue
    t=open(f,encoding="utf-8",errors="replace").read()
    t=re.sub(r'^\s*(import|use)\s+"[^"]*".*$','',t,flags=re.M)
    out.append("// ==== "+f+" ====\n"+t)
open(flat,"w").write("\n".join(out))
print("  [1/5] flatten:",len(seen),"files",("\n".join(out)).count(chr(10))+1,"lines")
PY
[ -f "$FLAT" ] || { echo "build_aprime: flatten failed" >&2; exit 1; }

# ── stage 2: transpile ─────────────────────────────────────────────
"$HEXA_V2" "$FLAT" "$APC" 2>&1 | tail -1
[ -f "$APC" ] || { echo "build_aprime: transpile failed (no $APC)" >&2; exit 1; }
echo "  [2/5] transpile: $(wc -l < "$APC") lines C"

# ── stage 3: post-process ──────────────────────────────────────────
# s4_flatc_post.py rewrites its input in-place. Pass a per-build path
# (FLATC) explicitly so concurrent build_aprime.sh runs don't collide
# on the legacy shared /tmp/flat4.c.
FLATC="$TMP/flat4.c"
cp "$APC" "$FLATC"
python3 tool/s4_flatc_post.py "$FLATC" 2>&1 | tail -1
sed -E -e 's/hexa_call1\(sha256_hex,[ ]*([^)]*)\)/hexa_sha256(\1)/g' \
       -e 's/hexa_call1\(list_dir,[ ]*[^)]*\)/hexa_array_new()/g' \
       "$FLATC" > "$APPOST"
# single-TU build: inline runtime.c (so static-inline helpers resolve).
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' "$APPOST"
rm -f "$APPOST.bak"
# RUNTIME.md step-2 cycle 1: signal runtime.c that hexa-source stdlib/
# runtime/* fns are present in this TU, so it should skip the C
# fallback definitions of rt_isalnum/rt_isalpha (cycle 59 → cycle-step2
# hexa-port). Prepend the macro definition above runtime.c #include.
sed -i.bak3 '1i\
#define HEXA_HAS_HEXA_RT_STDLIB 1
' "$APPOST"
rm -f "$APPOST.bak3"
# TEMP: remove once B2 emitter fix lands.
# B2 rt_fs gate bug: with HEXA_HAS_HEXA_RT_STDLIB set (above) the inlined
# runtime.c hits a `#else` branch that externs rt_fs_append_atomic/stat/
# rotate_if_over away, but builtin-init still takes their address → clang
# "Undefined symbols". The proper fix puts the failure-default bodies in
# the runtime_core.c emitter SSOT (self/runtime_core_emit.hexa); until that
# lands, the STAGE-0-regenerated runtime_core.c lacks them. Append the 3
# failure-default stubs (byte-equivalent to the !HEXA_HAS_HEXA_RT_STDLIB
# bodies) ONLY when runtime_core.c does not already define them — so a tree
# that already carries the B2 fix is a no-op (no double-definition).
if ! grep -q 'HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) {' self/runtime_core.c 2>/dev/null; then
    cat >> "$APPOST" <<'RTFS'
/* TEMP B2 link-fill (remove once self/runtime_core_emit.hexa emits these). */
#ifndef HEXA_RT_SELFEMIT
HexaVal rt_fs_append_atomic(HexaVal path, HexaVal data) { (void)path; (void)data; return hexa_int(-1); }
HexaVal rt_fs_stat(HexaVal path) { (void)path; return hexa_void(); }
HexaVal rt_fs_rotate_if_over(HexaVal path, HexaVal max_bytes, HexaVal keep) { (void)path; (void)max_bytes; (void)keep; return hexa_int(0); }
#endif
RTFS
    echo "  [3/5] rt_fs link-fill: appended 3 B2 failure-default stubs (TEMP)"
fi
echo "  [3/5] post-process: s4_flatc_post + builtin sed + runtime.c inline"

# ── ZERO-C Z2a (gated, non-default) ────────────────────────────────
# Prove runtime_hi_gen.c (1 of 3 self/*.c) is eliminable: supply rt_str_*
# from a NATIVE-compiled object (build/rt_hi_native.o, from self/runtime_hi.hexa
# via the native compiler) linked separately, instead of the hexat-transpiled
# runtime_hi_gen.c #include. Default path (HEXA_ZEROC_RT_HI unset) is unchanged.
# Restored after the build so the warm artifact is not left mutated.
ZEROC_RT_HI_OBJ=""
ZEROC_RT_HI_RESTORE=""
if [ "${HEXA_ZEROC_RT_HI:-0}" = "1" ]; then
    # Assemble build/rt_hi_native.o from the arch-matched frozen native .s seed
    # if absent (breaks the bootstrap chicken-egg the same way self/runtime.c is
    # a seed). arm64-darwin → runtime_hi_native.s (Mach-O) · x86_64-linux →
    # runtime_hi_x86_64.s (ELF).
    case "$(uname -sm 2>/dev/null)" in
        "Linux x86_64") RT_HI_SEED="$REPO/self/native/runtime_hi_x86_64.s" ;;
        *)              RT_HI_SEED="$REPO/self/native/runtime_hi_native.s"  ;;
    esac
    if [ ! -f "$REPO/build/rt_hi_native.o" ] && [ -f "$RT_HI_SEED" ]; then
        grep -vE '^// ' "$RT_HI_SEED" > "$TMP/rt_hi_seed.s" 2>/dev/null || cp "$RT_HI_SEED" "$TMP/rt_hi_seed.s"
        ${CC:-clang} -c $ARCH_FLAG "$TMP/rt_hi_seed.s" -o "$REPO/build/rt_hi_native.o" 2>/dev/null \
            && echo "  [3/5] ZERO-C Z2a: assembled build/rt_hi_native.o from frozen .s seed ($RT_HI_SEED)"
    fi
    if [ ! -f "$REPO/build/rt_hi_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_HI=1 but build/rt_hi_native.o missing (no seed)" >&2; exit 1
    fi
    cp self/runtime_core.c "$TMP/runtime_core.c.preZ2a"
    ZEROC_RT_HI_RESTORE="$TMP/runtime_core.c.preZ2a"
    sed -i.zbak 's|#include "runtime_hi_gen.c"|/* ZERO-C Z2a: rt_str_* supplied by native build/rt_hi_native.o */|' self/runtime_core.c
    rm -f self/runtime_core.c.zbak
    ZEROC_RT_HI_OBJ="$REPO/build/rt_hi_native.o"
    echo "  [3/5] ZERO-C Z2a: runtime_hi_gen.c #include removed; linking native rt_hi_native.o"
fi

# ── RT-NATIVE ARRAY-R4: native array-core element object ───────────
# runtime_core.c's hexa_array_get/set now delegate UNCONDITIONALLY to
# rt_array_{get,set}_native (the C `#else HX_ARR_ITEMS` fallback was dropped for
# the genuine runtime_core.c byte-decrease), so this single-TU compile of
# runtime.c MUST link the native array seed object. Assemble it from the
# arch-matched frozen .s seed (the array twin of the rt_hi Z2a object above).
ARRAY_CORE_OBJ=""
case "$(uname -sm 2>/dev/null)" in
    "Linux x86_64")                 ARRAY_SEED="$REPO/self/native/array_core_x86_64.s" ;;
    "Linux aarch64"|"Linux arm64")  ARRAY_SEED="$REPO/self/native/array_core_arm64-linux.s" ;;
    *)                              ARRAY_SEED="$REPO/self/native/array_core_arm64.s" ;;
esac
if [ ! -f "$REPO/build/array_core_native.o" ] && [ -f "$ARRAY_SEED" ]; then
    grep -vE '^// ' "$ARRAY_SEED" > "$TMP/array_seed.s" 2>/dev/null || cp "$ARRAY_SEED" "$TMP/array_seed.s"
    ${CC:-clang} -c $ARCH_FLAG "$TMP/array_seed.s" -o "$REPO/build/array_core_native.o" 2>/dev/null \
        && echo "  [3/5] RT-NATIVE ARRAY-R4: assembled build/array_core_native.o from $ARRAY_SEED"
fi
if [ ! -f "$REPO/build/array_core_native.o" ]; then
    echo "build_aprime: ARRAY-R4 build/array_core_native.o missing (no seed for $(uname -m)); runtime_core.c hexa_array_get/set will be undefined" >&2; exit 1
fi
ARRAY_CORE_OBJ="$REPO/build/array_core_native.o"

# ── RT-NATIVE MAP-R3: native map-core probe object ───────────
# runtime_core.c's hexa_map_get probe now delegate UNCONDITIONALLY to
# rt_array_{get,set}_native (the C `#else HX_ARR_ITEMS` fallback was dropped for
# the genuine runtime_core.c byte-decrease), so this single-TU compile of
# runtime.c MUST link the native array seed object. Assemble it from the
# arch-matched frozen .s seed (the array twin of the rt_hi Z2a object above).
MAP_CORE_OBJ=""
case "$(uname -sm 2>/dev/null)" in
    "Linux x86_64")                 MAP_SEED="$REPO/self/native/map_core_x86_64.s" ;;
    "Linux aarch64"|"Linux arm64")  MAP_SEED="$REPO/self/native/map_core_arm64-linux.s" ;;
    *)                              MAP_SEED="$REPO/self/native/map_core_arm64.s" ;;
esac
if [ ! -f "$REPO/build/map_core_native.o" ] && [ -f "$MAP_SEED" ]; then
    grep -vE '^// ' "$MAP_SEED" > "$TMP/map_seed.s" 2>/dev/null || cp "$MAP_SEED" "$TMP/map_seed.s"
    ${CC:-clang} -c $ARCH_FLAG "$TMP/map_seed.s" -o "$REPO/build/map_core_native.o" 2>/dev/null \
        && echo "  [3/5] RT-NATIVE MAP-R3: assembled build/map_core_native.o from $MAP_SEED"
fi
if [ ! -f "$REPO/build/map_core_native.o" ]; then
    echo "build_aprime: MAP-R3 build/map_core_native.o missing (no seed for $(uname -m)); runtime_core.c hexa_map_get probe will be undefined" >&2; exit 1
fi
MAP_CORE_OBJ="$REPO/build/map_core_native.o"

# ── RT-NATIVE Route B ALLOC-RB: native linked-block arena (DEFAULT-ON) ───
# As of measure-8 (2026-06-18) the C arena body is DROPPED from runtime_core_emit.hexa
# and the native HexaArenaBlock-chain arena (self/rt/alloc.hexa → build/
# alloc_syscall_native.o) is the sole arena — auto-on like the array/map seeds. The
# whole-runtime byteeq/faithful/RSS measurement (measure-6/7) confirmed the 16-byte
# mark struct-return ABI + the heapify↔envelope wiring (__hx_arena_lo/hi →
# hexa_arena_env_lo/hi). Set HEXA_RT_ALLOC_NATIVE=0 to revert (build then fails to
# resolve hexa_arena_* — revert is via git, not a live C fallback).
ALLOC_CORE_OBJ=""
ALLOC_DEF=""
if [ "${HEXA_RT_ALLOC_NATIVE:-1}" != "0" ]; then
    case "$(uname -sm 2>/dev/null)" in
        "Linux x86_64")                 ALLOC_SEED="$REPO/self/native/alloc_syscall_x86_64.s" ;;
        "Linux aarch64"|"Linux arm64")  ALLOC_SEED="$REPO/self/native/alloc_syscall_arm64-linux.s" ;;
        *)                              ALLOC_SEED="$REPO/self/native/alloc_syscall_arm64.s" ;;
    esac
    if [ ! -f "$REPO/build/alloc_syscall_native.o" ] && [ -f "$ALLOC_SEED" ]; then
        grep -vE '^// ' "$ALLOC_SEED" > "$TMP/alloc_seed.s" 2>/dev/null || cp "$ALLOC_SEED" "$TMP/alloc_seed.s"
        ${CC:-clang} -c $ARCH_FLAG "$TMP/alloc_seed.s" -o "$REPO/build/alloc_syscall_native.o" 2>/dev/null \
            && echo "  [3/5] RT-NATIVE ALLOC-RB: assembled build/alloc_syscall_native.o from $ALLOC_SEED"
    fi
    if [ ! -f "$REPO/build/alloc_syscall_native.o" ]; then
        echo "build_aprime: HEXA_RT_ALLOC_NATIVE=1 but build/alloc_syscall_native.o missing (no seed for $(uname -m))" >&2; exit 1
    fi
    ALLOC_CORE_OBJ="$REPO/build/alloc_syscall_native.o"
    ALLOC_DEF="-DHEXA_RT_ALLOC_NATIVE=1"
    echo "  [3/5] RT-NATIVE ALLOC-RB: HEXA_RT_ALLOC_NATIVE=1 — native arena path (C arena #else dropped)"
fi

# ── RT-NATIVE STR (sh-construct-str + sh-str-scan lanes): native public-string scan/compare ─
# Assemble the arch-matched str_core seed + define HEXA_RT_STR_EQ_NATIVE,
# HEXA_RT_STR_STARTS_WITH_NATIVE and HEXA_RT_STR_ENDS_WITH_NATIVE so hexa_str_eq's
# + rt_str_starts_with's + rt_str_ends_with's distinct-pointer compares delegate to
# rt_str_eq_native / rt_str_starts_with_native / rt_str_ends_with_native (raw-mem
# __hx_ptr_load8 NUL-stop walks). byte-identical to the C strcmp/strncmp bodies.
# The C `#else` is RETAINED — if the seed is missing for $(uname -m) we simply do
# NOT define the macros and the C path ships unchanged (#3583 fallback lesson,
# unlike array/map this is NOT a hard fail). One seed .o carries all three symbols,
# so it is assembled + linked once. Set HEXA_RT_STR_EQ_NATIVE=0 /
# HEXA_RT_STR_STARTS_WITH_NATIVE=0 / HEXA_RT_STR_ENDS_WITH_NATIVE=0 to force the C
# path per-prim even when a seed exists.
STR_CORE_OBJ=""
STR_DEF=""
if [ "${HEXA_RT_STR_EQ_NATIVE:-1}" != "0" ] || [ "${HEXA_RT_STR_STARTS_WITH_NATIVE:-1}" != "0" ] || [ "${HEXA_RT_STR_ENDS_WITH_NATIVE:-1}" != "0" ]; then
    case "$(uname -sm 2>/dev/null)" in
        "Linux x86_64")                 STR_SEED="$REPO/self/native/str_core_x86_64.s" ;;
        "Linux aarch64"|"Linux arm64")  STR_SEED="$REPO/self/native/str_core_arm64-linux.s" ;;
        *)                              STR_SEED="$REPO/self/native/str_core_arm64.s" ;;
    esac
    if [ ! -f "$REPO/build/str_core_native.o" ] && [ -f "$STR_SEED" ]; then
        grep -vE '^// ' "$STR_SEED" > "$TMP/str_seed.s" 2>/dev/null || cp "$STR_SEED" "$TMP/str_seed.s"
        ${CC:-clang} -c $ARCH_FLAG "$TMP/str_seed.s" -o "$REPO/build/str_core_native.o" 2>/dev/null \
            && echo "  [3/5] RT-NATIVE STR: assembled build/str_core_native.o from $STR_SEED"
    fi
    if [ -f "$REPO/build/str_core_native.o" ]; then
        STR_CORE_OBJ="$REPO/build/str_core_native.o"
        [ "${HEXA_RT_STR_EQ_NATIVE:-1}" != "0" ] && STR_DEF="$STR_DEF -DHEXA_RT_STR_EQ_NATIVE=1"
        [ "${HEXA_RT_STR_STARTS_WITH_NATIVE:-1}" != "0" ] && STR_DEF="$STR_DEF -DHEXA_RT_STR_STARTS_WITH_NATIVE=1"
        [ "${HEXA_RT_STR_ENDS_WITH_NATIVE:-1}" != "0" ] && STR_DEF="$STR_DEF -DHEXA_RT_STR_ENDS_WITH_NATIVE=1"
        echo "  [3/5] RT-NATIVE STR: defs [$STR_DEF] — native string scan/compare path"
    else
        echo "  [3/5] RT-NATIVE STR: no seed for $(uname -m) — C strcmp/strncmp #else path (no-seed fallback)" >&2
    fi
fi

# -- HEXA_RT_PRINT_NATIVE (leg-B prerequisite, OPT-IN default-OFF) ------------
# When HEXA_RT_PRINT_NATIVE=1 the restored substrate self/runtime.c gets its
# Linux hxlcl_write swapped for a raw `syscall` body (tool/restore_frozen_seeds
# injection, gated by the SAME env). Pass -DHEXA_RT_PRINT_NATIVE so the injected
# #ifdef selects the raw-syscall arm; unset (default) leaves the libc write()
# #else -> the compiler binary is byte-identical to baseline. Affects the
# compiler's OWN on-path print leaf (rt_print/eprintln -> __fd_write_bytes ->
# hxlcl_write), so it is the byteeq-relevant flip (#18 on-path fragility test).
PRINT_DEF=""
if [ "${HEXA_RT_PRINT_NATIVE:-0}" != "0" ]; then
    PRINT_DEF="-DHEXA_RT_PRINT_NATIVE=1"
    echo "  [3/5] RT-NATIVE PRINT: HEXA_RT_PRINT_NATIVE=1 — x86_64 raw-syscall hxlcl_write (libc write dropped on print leaf)"
fi

# ── stage 4: clang ─────────────────────────────────────────────────
mkdir -p "$(dirname "$OUT")"
# Cycle 43: -dead_strip + -ffunction-sections + -Oz shrinks aprime_cc
# 55% (2.24 MB → 1.00 MB) and removes 323 unused runtime fns + 36
# unused libc externs (509 T → 186 · 173 U → 137). S3 fixpoint
# preserved — same md5 655d6d1fc7da8db4572bf49d03dbcdf8 on falsifier.
# Cycle 46-50 (RUNTIME.md Phase 1 Tier-A.1 + Tier-A.2/A.6 partial):
# hxlcl_* helpers + textual #define override + selected disable flags
# eliminate 24+ libc symbols (137 → ~113 externs).
# -fno-builtin-{bzero,memcpy} : libcall-recognition residuals
# -D_FORTIFY_SOURCE=0          : ___memcpy_chk etc fortified wrappers
# -fno-stack-protector         : ___stack_chk_fail/_guard
# These flags are link-equivalent — no source change required.
CL_ERR="$(clang -Oz $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs \
    -ffunction-sections -fdata-sections $DEAD_STRIP \
    -fno-builtin-bzero -fno-builtin-memcpy -fno-builtin-strlen \
    -D_FORTIFY_SOURCE=0 -fno-stack-protector $ALLOC_DEF $STR_DEF $PRINT_DEF \
    -I self -I . "$APPOST" $ZEROC_RT_HI_OBJ $ARRAY_CORE_OBJ $MAP_CORE_OBJ $ALLOC_CORE_OBJ $STR_CORE_OBJ -o "$OUT" -lm 2>&1 | grep -iE 'error:|undefined' | head -5)"
# ZERO-C Z2a: restore the warm runtime_core.c artifact ONLY when runtime_hi_gen.c
# still exists (legacy gated test). When the file is permanently gone (default
# Z2a path) keep the `#include` removed — restoring it would make the stage-5
# smoke's `self/runtime.c` compile (+ any later runtime build) fail on the
# missing file. runtime_core.c is a gitignored generated artifact, so leaving it
# in the include-removed state is correct.
if [ -n "$ZEROC_RT_HI_RESTORE" ] && [ -f self/runtime_hi_gen.c ]; then
    cp "$ZEROC_RT_HI_RESTORE" self/runtime_core.c
fi
if [ -n "$CL_ERR" ] || [ ! -x "$OUT" ]; then
    echo "build_aprime: clang failed" >&2
    [ -n "$CL_ERR" ] && echo "$CL_ERR" >&2
    exit 1
fi
echo "  [4/5] clang: $OUT ($(ls -la "$OUT" | awk '{print $5}') B, $(file -b "$OUT"))"

# ── stage 5: smoke (exit(6*7) == 42) ───────────────────────────────
SMK="$TMP/prog.hexa"; SMS="$TMP/prog.s"; SMO="$TMP/prog.o"
RTO="$TMP/rt_arm64.o"; SMB="$TMP/prog"
printf 'fn main() {\n  let x = 6 * 7\n  exit(x)\n}\n' > "$SMK"
"$OUT" _drv.hexa --emit=asm --target="$SMOKE_TARGET" -o "$SMS" "$SMK" 2>&1 | tail -1
EXTRA_DEFS=""
if [ "$(uname -s)" = "Darwin" ]; then
    EXTRA_DEFS="-D_DARWIN_C_SOURCE"
fi
clang -c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE $EXTRA_DEFS $ALLOC_DEF -Wno-trigraphs -I self -I . \
    self/runtime.c -o "$RTO" 2>&1 | grep -iE 'error:|undefined|ld:|fatal|cannot find' | head -3
clang $ARCH_FLAG "$SMS" -c -o "$SMO" 2>&1 | grep -iE 'error:|undefined|ld:|fatal|cannot find' | head -3
clang $ARCH_FLAG "$SMO" "$RTO" $ZEROC_RT_HI_OBJ $ARRAY_CORE_OBJ $MAP_CORE_OBJ $ALLOC_CORE_OBJ -o "$SMB" -lm 2>&1 | grep -iE 'undefined|error:' | head -5
if [ ! -x "$SMB" ]; then
    echo "build_aprime: smoke link failed" >&2
    exit 2
fi
"$SMB"; RC=$?
if [ "$RC" = "42" ]; then
    echo "  [5/5] smoke: exit($((6*7)))==42 PASS — aprime_cc OK"
    echo "build_aprime: OK -> $OUT"
    exit 0
else
    echo "build_aprime: smoke FAIL — exit code $RC (expected 42)" >&2
    exit 2
fi
