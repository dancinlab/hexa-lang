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
    # 0d: place the transpiler where the default HEXA_V2 resolves it
    #     (self/native/hexat). build/hexat is the canonical STAGE-0 output.
    if [ ! -x "$HEXA_V2" ] && [ -x build/hexat ]; then
        mkdir -p "$(dirname "$HEXA_V2")"
        cp build/hexat "$HEXA_V2"; chmod +x "$HEXA_V2"
    fi
    echo "  [0/5] regen: runtime.c=$( [ -f self/runtime.c ] && wc -l < self/runtime.c || echo MISSING )L · hexat=$( [ -x "$HEXA_V2" ] && wc -c < "$HEXA_V2" || echo MISSING )B"
fi

[ -x "$HEXA_V2" ] || { echo "build_aprime: hexat missing/not-executable: $HEXA_V2" >&2; exit 1; }

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
CL_ERR="$(clang -Oz -arch arm64 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs \
    -ffunction-sections -fdata-sections -Wl,-dead_strip \
    -fno-builtin-bzero -fno-builtin-memcpy -fno-builtin-strlen \
    -D_FORTIFY_SOURCE=0 -fno-stack-protector \
    -I self -I . "$APPOST" -o "$OUT" -lm 2>&1 | grep -iE 'error:|undefined' | head -5)"
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
"$OUT" _drv.hexa --emit=asm --target=arm64-apple-darwin -o "$SMS" "$SMK" 2>&1 | tail -1
EXTRA_DEFS=""
if [ "$(uname -s)" = "Darwin" ]; then
    EXTRA_DEFS="-D_DARWIN_C_SOURCE"
fi
clang -c -O2 -arch arm64 -std=gnu11 -D_GNU_SOURCE $EXTRA_DEFS -Wno-trigraphs -I self -I . \
    self/runtime.c -o "$RTO" 2>&1 | grep -iE 'error:' | head -3
clang -arch arm64 "$SMS" -c -o "$SMO" 2>&1 | grep -iE 'error:' | head -3
clang -arch arm64 "$SMO" "$RTO" -o "$SMB" -lm 2>&1 | grep -iE 'undefined|error:' | head -5
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
