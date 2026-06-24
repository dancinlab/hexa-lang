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
    # zero-c leg-B r2a — alloc multiple-definition wall (warm-tree stale .c).
    # STAGE-0 is skipped on a warm tree, so a STALE self/runtime_core.c (a
    # .gitignore'd GENERATED artifact left from a pre-#3583 emitter, where the C
    # arena body was emitted UNCONDITIONALLY before the `#ifdef
    # HEXA_RT_ALLOC_NATIVE / #else` guard) would survive into the single-TU
    # compile below. With HEXA_RT_ALLOC_NATIVE=1 that leaves the C
    # `hexa_arena_alloc` body in the TU WHILE the native seed
    # alloc_syscall_native.o ALSO defines it → `multiple definition of
    # hexa_arena_alloc` link fail (alloc is the ONLY seed that shares the public
    # symbol name; array/map/str seeds delegate to a distinct rt_*_native symbol
    # so a stale sibling .c never clashes). Regenerate runtime_core.c from the
    # emitter SSOT here too — the awk un-escape is byte-DETERMINISTIC, so an
    # already-fresh tree gets a SHA-identical file (byte-neutral, no perf/byteeq
    # drift) and a stale tree is corrected. Same un-escaper STAGE-0 uses.
    bash tool/regen_runtime_core_c.sh "$REPO" 2>&1 | sed 's/^/  [0\/5] /'
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
    # @convergence state=ossified id=build-aprime-stale-native-seed-o value="warm-tree 의 build/*_native.o 가 seed.s 갱신 후에도 [ ! -f .o ] 가드로 재생성 skip → 옛 심볼셋(예: leg-B Z2a 가 rt_str_trim C body RETIRE 했으나 stale rt_hi_native.o 는 trim 그룹 누락)으로 link → undefined _rt_str_trim. alloc-stale warm-tree 수렴이 rt_hi 에서 재발." threshold="seed.s -nt .o 면 재assemble (5 native-seed 가드 rt_hi/array/map/alloc/str 전부)"
    if { [ ! -f "$REPO/build/rt_hi_native.o" ] || [ "$RT_HI_SEED" -nt "$REPO/build/rt_hi_native.o" ]; } && [ -f "$RT_HI_SEED" ]; then
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
if { [ ! -f "$REPO/build/array_core_native.o" ] || [ "$ARRAY_SEED" -nt "$REPO/build/array_core_native.o" ]; } && [ -f "$ARRAY_SEED" ]; then
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
if { [ ! -f "$REPO/build/map_core_native.o" ] || [ "$MAP_SEED" -nt "$REPO/build/map_core_native.o" ]; } && [ -f "$MAP_SEED" ]; then
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
    if { [ ! -f "$REPO/build/alloc_syscall_native.o" ] || [ "$ALLOC_SEED" -nt "$REPO/build/alloc_syscall_native.o" ]; } && [ -f "$ALLOC_SEED" ]; then
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
    if { [ ! -f "$REPO/build/str_core_native.o" ] || [ "$STR_SEED" -nt "$REPO/build/str_core_native.o" ]; } && [ -f "$STR_SEED" ]; then
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

# -- HEXA_ZEROC_RT_CORE_LEAF (leg-B r4 leaf-cluster link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_LEAF=1, the 10 HexaVal value-ctors (hexa_int/float/
# bool/void/float_to_bits/bits_to_float/float_to_bits/bits_to_float/enum_str/
# enum_str_v) are LINKED from a standalone object (build/rtcore_leaf_native.o,
# assembled from self/native/rtcore_leaf.c) instead of compiled inline in
# runtime_core.c. -DHEXA_RT_CORE_LEAF_NATIVE externs them out of the inline
# runtime_core.c (the narrow ctor-only guard, NOT the broad HEXA_RT_SELFEMIT).
# Default (unset): byte-IDENTICAL — the seed is not built/linked and the inline
# #else aggregate-literals are compiled verbatim. This DE-RISKS the standalone
# runtime_core.c link path (separate .o + extern + the HexaVal 16-byte struct-
# return ABI) that the full r5 redesign needs; it does NOT drop the .c file
# (all-or-nothing: 250 symbols, this links 10). Revert is via env, not a live C
# fallback flip (the inline bodies stay present, just #if'd out when ON).
RTCORE_LEAF_OBJ=""
RTCORE_LEAF_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_LEAF:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_leaf_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_leaf_native_o.sh "$REPO/build/rtcore_leaf_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_LEAF=1 but rtcore_leaf_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_leaf_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_LEAF=1 but build/rtcore_leaf_native.o missing" >&2; exit 1
    fi
    RTCORE_LEAF_OBJ="$REPO/build/rtcore_leaf_native.o"
    RTCORE_LEAF_DEF="-DHEXA_RT_CORE_LEAF_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-LEAF: HEXA_ZEROC_RT_CORE_LEAF=1 — 10 HexaVal ctors linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_ARITH (leg-B r5 clean-6 + r6 +__raw_fmod arith link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_ARITH=1, the 7 seed-portable __raw_* / __map_raw_*
# arith wrappers (__raw_idiv/__raw_imod/__raw_d2i/__raw_code_is/__raw_add_f/
# __map_raw_len + r6 __raw_fmod) are LINKED from a standalone object
# (build/rtcore_arith_native.o, assembled from self/native/rtcore_arith.c) instead
# of compiled inline in runtime_core.c. -DHEXA_RT_CORE_ARITH_NATIVE externs them
# out of the inline runtime_core.c (the narrow arith-only guard, NOT the broad
# HEXA_RT_SELFEMIT). Every callee of the 7 is external-linkage or a macro (the
# seed-portability rule); r6 __raw_fmod routes through the EXTERNAL rt_fmod (the
# frozen-static hxlcl_fmod is a 1-line delegate to it). __raw_cmp3 (frozen-static
# hxlcl_strcmp, no external delegate) stays EXCLUDED inline-C — measured r6 wall.
# Default (unset): byte-IDENTICAL — the seed is not built/linked and the inline
# #else bodies are compiled verbatim. Extends the r4 leaf-cluster de-risk to the
# next seed-portable runtime_core.c symbol class; does NOT drop the .c file
# (all-or-nothing). Revert is via env.
RTCORE_ARITH_OBJ=""
RTCORE_ARITH_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_ARITH:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_arith_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_arith_native_o.sh "$REPO/build/rtcore_arith_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_ARITH=1 but rtcore_arith_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_arith_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_ARITH=1 but build/rtcore_arith_native.o missing" >&2; exit 1
    fi
    RTCORE_ARITH_OBJ="$REPO/build/rtcore_arith_native.o"
    RTCORE_ARITH_DEF="-DHEXA_RT_CORE_ARITH_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-ARITH: HEXA_ZEROC_RT_CORE_ARITH=1 — 7 __raw_* arith wrappers (r6 +__raw_fmod) linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_MATH (leg-B r7 clean-4 transcendental link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_MATH=1, the 4 seed-portable transcendental wrappers
# (hexa_sin/hexa_cos/hexa_exp/hexa_log) are LINKED from a standalone object
# (build/rtcore_math_native.o, assembled from self/native/rtcore_math.c) instead of
# compiled inline in runtime_core.c. -DHEXA_RT_CORE_MATH_NATIVE externs them out of
# the inline runtime_core.c (the narrow math-only guard, NOT the broad
# HEXA_RT_SELFEMIT). These 4 are emitted UNCONDITIONALLY inline (no #else arm) as
# hexa_float(hxlcl_sin/cos/exp/log(...)); each hxlcl_* is a frozen-static 1-line
# delegate to the EXTERNAL rt_sin/cos/exp/log, so the seed routes through rt_*
# directly (the r6 external-delegate route) — bit-identical, seed-portable. The
# #else-armed math fns (hexa_sqrt/pow/floor/…) are NOT included (deferred — they
# are seed-portable but live inside a #if/#else, a wider surface). Default (unset):
# byte-IDENTICAL — the seed is not built/linked and the inline #else hxlcl_* bodies
# are compiled verbatim. Does NOT drop the .c file (all-or-nothing). Revert via env.
RTCORE_MATH_OBJ=""
RTCORE_MATH_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_MATH:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_math_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_math_native_o.sh "$REPO/build/rtcore_math_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_MATH=1 but rtcore_math_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_math_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_MATH=1 but build/rtcore_math_native.o missing" >&2; exit 1
    fi
    RTCORE_MATH_OBJ="$REPO/build/rtcore_math_native.o"
    RTCORE_MATH_DEF="-DHEXA_RT_CORE_MATH_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-MATH: HEXA_ZEROC_RT_CORE_MATH=1 — 4 transcendental wrappers (sin/cos/exp/log) linked from native seed .o"
fi
# -- HEXA_ZEROC_RT_CORE_MATH2 (leg-B r8 else-math link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_MATH2=1, the 12 seed-portable #else-armed math wrappers
# (hexa_sqrt/pow/floor/ceil/u_floor/abs/tan/log10/round/tanh/log2/to_float) are
# LINKED from a standalone object (build/rtcore_math2_native.o, assembled from
# self/native/rtcore_math2.c) instead of compiled inline in runtime_core.c.
# -DHEXA_RT_CORE_MATH2_NATIVE externs them out of the inline runtime_core.c (the
# narrow math2-only guard, NOT the broad HEXA_RT_SELFEMIT). Each lives inside a
# `#ifndef HEXA_HAS_HEXA_RT_STDLIB / #else / #endif` pair; in the shipping build
# the #else arm already delegates to an EXTERNAL rt_* core, so the seed copies that
# delegate verbatim and a 3rd #if level externs the hexa_* definition out of the
# shipping arm (the #ifndef standalone arm is untouched). Default (unset):
# byte-IDENTICAL — the seed is not built/linked and the inline #else delegate
# bodies are compiled verbatim (cpp-proven). Does NOT drop the .c file
# (all-or-nothing). Revert via env.
RTCORE_MATH2_OBJ=""
RTCORE_MATH2_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_MATH2:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_math2_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_math2_native_o.sh "$REPO/build/rtcore_math2_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_MATH2=1 but rtcore_math2_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_math2_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_MATH2=1 but build/rtcore_math2_native.o missing" >&2; exit 1
    fi
    RTCORE_MATH2_OBJ="$REPO/build/rtcore_math2_native.o"
    RTCORE_MATH2_DEF="-DHEXA_RT_CORE_MATH2_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-MATH2: HEXA_ZEROC_RT_CORE_MATH2=1 — 12 #else-armed math wrappers (sqrt/pow/floor/ceil/u_floor/abs/tan/log10/round/tanh/log2/to_float) linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_VALOP_DISPATCH (leg-B r9 valop-dispatch link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_VALOP_DISPATCH=1, the 9 scalar arith/compare DISPATCHER
# wrappers (hexa_add_slow/sub/mul/div/mod/cmp_lt/cmp_gt/cmp_le/cmp_ge) are LINKED
# from a standalone object (build/rtcore_valop-dispatch_native.o, assembled from
# self/native/rtcore_valop-dispatch.c) instead of compiled inline in runtime_core.c.
# -DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE externs them out of the inline runtime_core.c
# (the narrow valop-dispatch guard, NOT the broad HEXA_RT_SELFEMIT). Each dispatcher
# sits ABOVE the already-default-ON valop_core_*.s scalar leaves (rt_*_native) and the
# hexa-source fallbacks (rt_* in numeric.hexa) — every callee is external-linkage or a
# macro, no frozen-static. The new outer #if/#else in runtime_core_emit.hexa externs
# the dispatcher out of the shipping arm while keeping the whole HEXA_HAS_HEXA_RT_STDLIB
# +standalone block verbatim under #else. Default (unset): byte-IDENTICAL — the seed is
# not built/linked and the inline shipping-arm bodies are compiled verbatim (cpp-proven).
# Does NOT drop the .c file (all-or-nothing). Revert via env.
RTCORE_VALOP_DISPATCH_OBJ=""
RTCORE_VALOP_DISPATCH_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_VALOP_DISPATCH:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_valop-dispatch_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_valop-dispatch_native_o.sh "$REPO/build/rtcore_valop-dispatch_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_VALOP_DISPATCH=1 but rtcore_valop-dispatch_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_valop-dispatch_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_VALOP_DISPATCH=1 but build/rtcore_valop-dispatch_native.o missing" >&2; exit 1
    fi
    RTCORE_VALOP_DISPATCH_OBJ="$REPO/build/rtcore_valop-dispatch_native.o"
    RTCORE_VALOP_DISPATCH_DEF="-DHEXA_RT_CORE_VALOP_DISPATCH_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-VALOP-DISPATCH: HEXA_ZEROC_RT_CORE_VALOP_DISPATCH=1 — 9 scalar arith/compare dispatchers (add_slow/sub/mul/div/mod/cmp_lt/gt/le/ge) linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_MAP_QUERY_DISPATCH (leg-B r10 map-query-dispatch link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_MAP_QUERY_DISPATCH=1, the 9 map query/projection DISPATCHER
# wrappers (hexa_map_keys/values/contains_key/entries/map_values/filter_keys/count/any/all)
# are LINKED from a standalone object (build/rtcore_map-query-dispatch_native.o, assembled
# from self/native/rtcore_map-query-dispatch.c) instead of compiled inline in runtime_core.c.
# -DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE externs them out of the inline runtime_core.c
# (the narrow map-query-dispatch guard, NOT the broad HEXA_RT_SELFEMIT). Each dispatcher
# NULL-table-guards then delegates to the rt_map_* hexa-source body (or supplies the empty
# ctor map) — every callee is external-linkage or a macro, no frozen-static. The new outer
# #if/#else in runtime_core_emit.hexa externs the dispatcher out of the shipping arm while
# keeping the whole HEXA_HAS_HEXA_RT_STDLIB + standalone block verbatim under #else.
# Default (unset): byte-IDENTICAL — the seed is not built/linked and the inline shipping-arm
# bodies are compiled verbatim (cpp-proven). Does NOT drop the .c file. Revert via env.
RTCORE_MAP_QUERY_DISPATCH_OBJ=""
RTCORE_MAP_QUERY_DISPATCH_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_MAP_QUERY_DISPATCH:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_map-query-dispatch_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_map-query-dispatch_native_o.sh "$REPO/build/rtcore_map-query-dispatch_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_MAP_QUERY_DISPATCH=1 but rtcore_map-query-dispatch_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_map-query-dispatch_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_MAP_QUERY_DISPATCH=1 but build/rtcore_map-query-dispatch_native.o missing" >&2; exit 1
    fi
    RTCORE_MAP_QUERY_DISPATCH_OBJ="$REPO/build/rtcore_map-query-dispatch_native.o"
    RTCORE_MAP_QUERY_DISPATCH_DEF="-DHEXA_RT_CORE_MAP_QUERY_DISPATCH_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-MAP-QUERY-DISPATCH: HEXA_ZEROC_RT_CORE_MAP_QUERY_DISPATCH=1 — 9 map query/projection dispatchers (keys/values/contains_key/entries/map_values/filter_keys/count/any/all) linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_MAP_QUERY_FOLD (leg-B map-query link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_MAP_QUERY_FOLD=1, the 8 UNGUARDED map-query symbols
# (__map_has_cstr_v/__map_get_cstr_v/__map_order_key_at/__map_order_val_at/
# __map_set_cstr_v/__map_remove_cstr_v/hexa_map_get_v/hexa_map_to_array) are LINKED
# from a standalone object (build/rtcore_map_query_fold_native.o, assembled from
# self/native/rtcore_map-query-fold.c) instead of compiled inline in
# runtime_core.c. -DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE externs them out of the
# inline runtime_core.c (the narrow map-query guard, NOT the broad HEXA_RT_SELFEMIT).
# Every immediate callee is external-linkage or a macro; all 8 are unguarded single-
# body fns (no HEXA_HAS_HEXA_RT_STDLIB dependence), so the -DNATIVE extern is
# collision-safe on BOTH the aprime link AND the stage-5 standalone smoke link. The
# 11 dual-arm cluster fns + __map_ptr_eq (static inline) are EXCLUDED. Default
# (unset): byte-IDENTICAL — the seed is not built/linked and the inline bodies are
# compiled verbatim. Revert is via env.
RTCORE_MAP_QUERY_FOLD_OBJ=""
RTCORE_MAP_QUERY_FOLD_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_MAP_QUERY_FOLD:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_map_query_fold_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_map-query-fold_native_o.sh "$REPO/build/rtcore_map_query_fold_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_MAP_QUERY_FOLD=1 but rtcore_map_query_fold_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_map_query_fold_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_MAP_QUERY_FOLD=1 but build/rtcore_map_query_fold_native.o missing" >&2; exit 1
    fi
    RTCORE_MAP_QUERY_FOLD_OBJ="$REPO/build/rtcore_map_query_fold_native.o"
    RTCORE_MAP_QUERY_FOLD_DEF="-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-MAP-QUERY-FOLD: HEXA_ZEROC_RT_CORE_MAP_QUERY_FOLD=1 — 8 map-query wrappers linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_COLLECTION_MUTATE (leg-B r7 collection-mutate link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_COLLECTION_MUTATE=1, the 13 seed-portable map/array
# mutate+query symbols (hexa_map_from_array/invert/merge/remove/remove_impl/set/
# set_v + hexa_array_contains/last/pop/set/shift/truncate) are LINKED from a
# standalone object (build/rtcore_collection-mutate_native.o, assembled from
# self/native/rtcore_collection-mutate.c) instead of compiled inline in
# runtime_core.c. -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE externs them out of the
# inline runtime_core.c (the narrow collection-mutate guard, NOT the broad
# HEXA_RT_SELFEMIT). Every callee is external-linkage, a macro, or a seed-supplied
# rt_array_*_native (the array_core .s seed, linked in both aprime + smoke);
# hexa_array_sort is EXCLUDED (static qsort comparator hexa_sort_cmp + seed-absent
# rt_array_sort_float), stays inline-C. Default (unset): byte-IDENTICAL — the seed
# is not built/linked and the inline bodies are compiled verbatim. Revert is via env.
RTCORE_COLLECTION_MUTATE_OBJ=""
RTCORE_COLLECTION_MUTATE_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_COLLECTION_MUTATE:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_collection-mutate_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_collection-mutate_native_o.sh "$REPO/build/rtcore_collection-mutate_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_COLLECTION_MUTATE=1 but rtcore_collection-mutate_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_collection-mutate_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_COLLECTION_MUTATE=1 but build/rtcore_collection-mutate_native.o missing" >&2; exit 1
    fi
    RTCORE_COLLECTION_MUTATE_OBJ="$REPO/build/rtcore_collection-mutate_native.o"
    RTCORE_COLLECTION_MUTATE_DEF="-DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-COLLECTION-MUTATE: HEXA_ZEROC_RT_CORE_COLLECTION_MUTATE=1 — 13 map/array mutate wrappers linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_ARRAY_TYPED_LEAF (leg-B array-typed-leaf link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_ARRAY_TYPED_LEAF=1, the 10 seed-portable typed-array LEAF
# ctors/accessors + zero-fill builders (hexa_arr_i64_new/_push/_len/_box,
# hexa_arr_f64_new/_push/_len/_box, hexa_arr_zeros_leaf, hexa_arr_zeros_leaf_int)
# are LINKED from a standalone object (build/rtcore_array_typed_leaf_native.o,
# assembled from self/native/rtcore_array-typed-leaf.c) instead of compiled inline
# in runtime_core.c. -DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE externs them out of the
# inline runtime_core.c (the narrow array-typed-leaf-only guard, NOT the broad
# HEXA_RT_SELFEMIT). These 10 are emitted UNCONDITIONALLY inline (no #else arm) and
# every callee is external-linkage (malloc/calloc/realloc/fprintf/exit/hexa_int/
# hexa_float/hexa_throw/hexa_str/__hx_to_double) or a macro (HX_SET_ARR_*/HX_IS_INT/
# HX_INT), so the cluster is directly seed-portable (no external-delegate route).
# The arena fns (hexa_arena_mark/reset/rewind) are NOT included — under the shipping
# HEXA_RT_ALLOC_NATIVE build they are already externed to the native alloc syscall
# seed (no inline body to extern out). Default (unset): byte-IDENTICAL — the seed is
# not built/linked and the inline #else bodies are compiled verbatim. Does NOT drop
# the .c file (all-or-nothing). Revert via env.
RTCORE_ATL_OBJ=""
RTCORE_ATL_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_ARRAY_TYPED_LEAF:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_array_typed_leaf_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_array-typed-leaf_native_o.sh "$REPO/build/rtcore_array_typed_leaf_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_ARRAY_TYPED_LEAF=1 but rtcore_array_typed_leaf_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_array_typed_leaf_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_ARRAY_TYPED_LEAF=1 but build/rtcore_array_typed_leaf_native.o missing" >&2; exit 1
    fi
    RTCORE_ATL_OBJ="$REPO/build/rtcore_array_typed_leaf_native.o"
    RTCORE_ATL_DEF="-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-ARRAY-TYPED-LEAF: HEXA_ZEROC_RT_CORE_ARRAY_TYPED_LEAF=1 — 10 typed-array leaf ctors/accessors linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_FS_READ_WRITE (leg-B fs-read-write link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_FS_READ_WRITE=1, the 9 stdio-based binary file-I/O
# HexaVal wrappers (rt_read_file/rt_write_bytes/rt_write_bytes_v/
# rt_read_file_bytes/rt_read_bytes_at/rt_read_f32_at/rt_read_f32_array_at/
# rt_write_bytes_append/rt_write_bytes_append_v) are LINKED from a standalone
# object (build/rtcore_fs-read-write_native.o, assembled from
# self/native/rtcore_fs-read-write.c) instead of compiled inline in
# runtime_core.c. -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE externs them out of the
# inline runtime_core.c (the narrow fs-read-write guard, NOT the broad
# HEXA_RT_SELFEMIT). Every callee of the 9 is external-linkage or a macro (the
# seed-portability rule); rt_fs_append_atomic/rt_fs_stat/rt_fs_rotate_if_over are
# EXCLUDED (config-conditional definers — they stay inline-C). Default (unset):
# byte-IDENTICAL — the seed is not built/linked and the inline bodies compile
# verbatim. Revert is via env.
RTCORE_FS_RW_OBJ=""
RTCORE_FS_RW_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_FS_READ_WRITE:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_fs-read-write_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_fs-read-write_native_o.sh "$REPO/build/rtcore_fs-read-write_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_FS_READ_WRITE=1 but rtcore_fs-read-write_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_fs-read-write_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_FS_READ_WRITE=1 but build/rtcore_fs-read-write_native.o missing" >&2; exit 1
    fi
    RTCORE_FS_RW_OBJ="$REPO/build/rtcore_fs-read-write_native.o"
    RTCORE_FS_RW_DEF="-DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-FS-READ-WRITE: HEXA_ZEROC_RT_CORE_FS_READ_WRITE=1 — 9 fs-read-write wrappers linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT (leg-B arith-coerce-format link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT=1, the 10 seed-portable numeric/
# coercion/format wrappers (hexa_concat_many/hexa_fma/hexa_len/hexa_null_coal/
# hexa_to_int/hexa_format/hexa_format_float/hexa_format_float_sci/hexa_print/
# hexa_str_char_at) are LINKED from a standalone object
# (build/rtcore_arith-coerce-format_native.o, assembled from
# self/native/rtcore_arith-coerce-format.c) instead of compiled inline in
# runtime_core.c. -DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE externs them out of
# the inline runtime_core.c (the narrow cluster-only guard, NOT the broad
# HEXA_RT_SELFEMIT). Every callee of the 10 is external-linkage or a macro (the
# seed-portability rule); hexa_add_slow/sub/mul/div/truthy (VALOP-lane inner
# guard) and hexa_str_byte_at/char_code_at (HX_STRLEN→static-inline) are
# EXCLUDED. Default (unset): byte-IDENTICAL — the seed is not built/linked and
# the inline bodies are compiled verbatim. Revert is via env.
RTCORE_ACF_OBJ=""
RTCORE_ACF_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_arith-coerce-format_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_arith-coerce-format_native_o.sh "$REPO/build/rtcore_arith-coerce-format_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT=1 but rtcore_arith-coerce-format_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_arith-coerce-format_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT=1 but build/rtcore_arith-coerce-format_native.o missing" >&2; exit 1
    fi
    RTCORE_ACF_OBJ="$REPO/build/rtcore_arith-coerce-format_native.o"
    RTCORE_ACF_DEF="-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-ARITH-COERCE-FORMAT: HEXA_ZEROC_RT_CORE_ARITH_COERCE_FORMAT=1 — 10 numeric/coercion/format wrappers linked from native seed .o"
fi

# -- HEXA_ZEROC_RT_CORE_RUNTIME_MISC (leg-B r8 runtime-misc link de-risk, OPT-IN OFF) --
# When HEXA_ZEROC_RT_CORE_RUNTIME_MISC=1, the 11 seed-portable runtime-misc
# symbols (__vs_ptr_eq / hexa_fnv1a_str / hexa_index_get / hexa_index_set /
# hexa_iter_get / hexa_await_unwrap / hexa_valstruct_int / hexa_val_free_tree /
# hexa_mkdir / __hexa_try_pop / __hexa_try_cleanup) are LINKED from a standalone
# object (build/rtcore_runtime-misc_native.o, assembled from
# self/native/rtcore_runtime-misc.c) instead of compiled inline in runtime_core.c.
# -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE externs them out of the inline runtime_core.c
# (the narrow runtime-misc guard, NOT the broad HEXA_RT_SELFEMIT). Every callee
# AND touched global of the 11 is external-linkage or a macro (the seed-portability
# rule); __hexa_try_push (static __hexa_try_stack), __hexa_last_error (static
# __hexa_error_val), hexa_args / hexa_real_args / hexa_script_path (static
# _hexa_argc / _hexa_argv) are EXCLUDED — they stay inline-C. Default (unset):
# byte-IDENTICAL — the seed is not built/linked and the inline #else bodies are
# compiled verbatim. Revert is via env.
RTCORE_RUNTIME_MISC_OBJ=""
RTCORE_RUNTIME_MISC_DEF=""
if [ "${HEXA_ZEROC_RT_CORE_RUNTIME_MISC:-0}" != "0" ]; then
    if [ ! -f "$REPO/build/rtcore_runtime-misc_native.o" ]; then
        CC="${CC:-clang}" ARCH_FLAG="$ARCH_FLAG" bash tool/regen_rtcore_runtime-misc_native_o.sh "$REPO/build/rtcore_runtime-misc_native.o" >&2 \
            || { echo "build_aprime: HEXA_ZEROC_RT_CORE_RUNTIME_MISC=1 but rtcore_runtime-misc_native.o build failed" >&2; exit 1; }
    fi
    if [ ! -f "$REPO/build/rtcore_runtime-misc_native.o" ]; then
        echo "build_aprime: HEXA_ZEROC_RT_CORE_RUNTIME_MISC=1 but build/rtcore_runtime-misc_native.o missing" >&2; exit 1
    fi
    RTCORE_RUNTIME_MISC_OBJ="$REPO/build/rtcore_runtime-misc_native.o"
    RTCORE_RUNTIME_MISC_DEF="-DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1"
    echo "  [3/5] ZERO-C RT-CORE-RUNTIME-MISC: HEXA_ZEROC_RT_CORE_RUNTIME_MISC=1 — 11 runtime-misc symbols linked from native seed .o"
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
    -D_FORTIFY_SOURCE=0 -fno-stack-protector $ALLOC_DEF $STR_DEF $PRINT_DEF $RTCORE_LEAF_DEF $RTCORE_ARITH_DEF $RTCORE_MATH_DEF $RTCORE_MATH2_DEF $RTCORE_VALOP_DISPATCH_DEF $RTCORE_MAP_QUERY_DISPATCH_DEF $RTCORE_MAP_QUERY_FOLD_DEF $RTCORE_COLLECTION_MUTATE_DEF $RTCORE_ATL_DEF $RTCORE_FS_RW_DEF $RTCORE_ACF_DEF $RTCORE_RUNTIME_MISC_DEF \
    -I self -I . "$APPOST" $ZEROC_RT_HI_OBJ $ARRAY_CORE_OBJ $MAP_CORE_OBJ $ALLOC_CORE_OBJ $STR_CORE_OBJ $RTCORE_LEAF_OBJ $RTCORE_ARITH_OBJ $RTCORE_MATH_OBJ $RTCORE_MATH2_OBJ $RTCORE_VALOP_DISPATCH_OBJ $RTCORE_MAP_QUERY_DISPATCH_OBJ $RTCORE_MAP_QUERY_FOLD_OBJ $RTCORE_COLLECTION_MUTATE_OBJ $RTCORE_ATL_OBJ $RTCORE_FS_RW_OBJ $RTCORE_ACF_OBJ $RTCORE_RUNTIME_MISC_OBJ -o "$OUT" -lm 2>&1 | grep -iE 'error:|undefined' | head -5)"
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
clang -c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE $EXTRA_DEFS $ALLOC_DEF $RTCORE_LEAF_DEF $RTCORE_ARITH_DEF $RTCORE_MATH_DEF $RTCORE_MATH2_DEF $RTCORE_VALOP_DISPATCH_DEF $RTCORE_MAP_QUERY_DISPATCH_DEF $RTCORE_MAP_QUERY_FOLD_DEF $RTCORE_COLLECTION_MUTATE_DEF $RTCORE_ATL_DEF $RTCORE_FS_RW_DEF $RTCORE_ACF_DEF $RTCORE_RUNTIME_MISC_DEF -Wno-trigraphs -I self -I . \
    self/runtime.c -o "$RTO" 2>&1 | grep -iE 'error:|undefined|ld:|fatal|cannot find' | head -3
clang $ARCH_FLAG "$SMS" -c -o "$SMO" 2>&1 | grep -iE 'error:|undefined|ld:|fatal|cannot find' | head -3
clang $ARCH_FLAG "$SMO" "$RTO" $ZEROC_RT_HI_OBJ $ARRAY_CORE_OBJ $MAP_CORE_OBJ $ALLOC_CORE_OBJ $RTCORE_LEAF_OBJ $RTCORE_ARITH_OBJ $RTCORE_MATH_OBJ $RTCORE_MATH2_OBJ $RTCORE_VALOP_DISPATCH_OBJ $RTCORE_MAP_QUERY_DISPATCH_OBJ $RTCORE_MAP_QUERY_FOLD_OBJ $RTCORE_COLLECTION_MUTATE_OBJ $RTCORE_ATL_OBJ $RTCORE_FS_RW_OBJ $RTCORE_ACF_OBJ $RTCORE_RUNTIME_MISC_OBJ -o "$SMB" -lm 2>&1 | grep -iE 'undefined|error:' | head -5
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
