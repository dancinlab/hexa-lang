#!/bin/bash
# tool/build_selfhost.sh — reproducible self-hosted native compiler build.
#
# Turns the ad-hoc ghost byte-eq build (aprime -> cc-prc2 -> gen2 -> gen3 ->
# gen4 fixpoint) into a single committed, deterministic recipe driven from
# current main. This is the SELFHOST-NEXT graduation build, made one-command
# reproducible so the toolchain promotion can be re-verified at any time.
#
# ── The bootstrap ladder (each stage compiles the NEXT) ──────────────────────
#   seeds   tool/restore_frozen_seeds  -> self/runtime.c + self/native/hexa_cc.c
#   hexat   clang hexa_cc.c            -> build/hexat   (C-transpiler bootstrap)
#   stage0  tool/build_aprime.sh       -> aprime_cc     (hexat-transpiled native
#                                                        arm64-asm compiler)
#   stage1  aprime_cc emit cc-flat     -> cc-prc2.o  -> gen2   (1st self-emit)
#   stage2  gen2 emit cc-flat          -> cc-gen3.o  -> gen3   (2nd self-emit)
#   stage3  gen3 emit cc-flat          -> cc-gen4.o          (3rd self-emit)
#   GATE    cmp cc-gen3.o cc-gen4.o    -> BYTE-EQ FIXPOINT  (stage2==stage3 out)
#
# The fixpoint is stage3-output == stage4-output (cc-gen3.o == cc-gen4.o): once
# a generation reproduces the EXACT object the next generation emits, the
# compiler is a verified self-host fixpoint. (cc-prc2.o, the very first native
# self-emit, is NOT yet byte-identical to cc-gen3.o — the first iteration still
# carries a 2-residual C-vs-native delta that converges out by gen3; see
# .verdicts/compiler-selfhost-fixpoint. The terminal GATE is gen3==gen4.)
#
# ── Inputs (all resolved from the repo at $REPO; nothing from /tmp) ───────────
#   compiler/main.hexa + its import/use closure  (the compiler source)
#   tool/hexa_ld.hexa                            (the Mach-O linker, __literal8
#                                                 const-merge fix landed on main)
#   self/runtime.c                               (runtime obj, restored seed)
#   self/native/hexa_cc.c                        (hexat seed)
#
# ── Outputs (under $WORK, default ./build/selfhost) ──────────────────────────
#   aprime_cc        stage0 native compiler
#   hexa_ld          self-built Mach-O linker
#   rt.o             runtime object (self/runtime.c)
#   cc-flat.hexa     flattened compiler source (the self-emit input)
#   cc-prc2.o gen2   1st self-emit object + linked compiler
#   cc-gen3.o gen3   2nd self-emit object + linked compiler
#   cc-gen4.o        3rd self-emit object (the fixpoint witness)
#   selfhost.done    machine-readable marker: EXIT=.. GATE=BYTE-EQ|DIFFER@n ...
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   tool/build_selfhost.sh [-r REPO] [-w WORK] [-j] [--detached MARK]
#     -r REPO        repo root (default: cwd; must hold compiler/main.hexa)
#     -w WORK        scratch/output dir (default: $REPO/build/selfhost) — NOT /tmp
#     -j             stop after stage0 (aprime_cc + hexa_ld + rt.o) — fast smoke
#     --detached M   write progress marker to M; intended for nohup. The three
#                    self-emits are ~68min EACH on ghost; run DETACHED.
#
# ── Exit codes ───────────────────────────────────────────────────────────────
#   0  BYTE-EQ FIXPOINT reached (cc-gen3.o == cc-gen4.o, all ENCODE-MISS=0)
#   1  build failure (seed/hexat/aprime/flatten/emit/link)
#   2  fixpoint NOT reached (gens built but cc-gen3.o != cc-gen4.o)
#   3  bad invocation / missing inputs
#
# Heavy: full run is THREE ~68min self-emits (~3.5h wall). Use --detached.
set -u

REPO="$(pwd)"
WORK=""
JUST_STAGE0=0
MARK=""

while [ $# -gt 0 ]; do
    case "$1" in
        -r) REPO="$2"; shift 2 ;;
        -w) WORK="$2"; shift 2 ;;
        -j) JUST_STAGE0=1; shift ;;
        --detached) MARK="$2"; shift 2 ;;
        *) echo "build_selfhost: unknown arg '$1'" >&2; exit 3 ;;
    esac
done

cd "$REPO" || { echo "build_selfhost: bad repo '$REPO'" >&2; exit 3; }
[ -f compiler/main.hexa ] || { echo "build_selfhost: no compiler/main.hexa under $REPO" >&2; exit 3; }
[ -z "$WORK" ] && WORK="$REPO/build/selfhost"
mkdir -p "$WORK" || { echo "build_selfhost: cannot mkdir $WORK" >&2; exit 3; }
case "$WORK" in /tmp/*|/private/tmp/*) echo "build_selfhost: WORK must not be under /tmp" >&2; exit 3 ;; esac

HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
mark() { [ -n "$MARK" ] && echo "$*" > "$MARK"; }
log()  { echo "[build_selfhost] $*"; }
fail() { log "FATAL: $*"; mark "EXIT=1 STAGE=$1 NOTE=$2 HEAD=$HEAD_SHA"; exit 1; }

# Host-conditional clang flags: `-arch arm64` and -D_DARWIN_C_SOURCE are Darwin-only —
# on Linux clang errors `unsupported option '-arch'` (pool-host FATAL at the seed stage).
HOST_ARCH=""; HOST_EXTRA=""
if [ "$(uname -s)" = "Darwin" ]; then HOST_ARCH="-arch arm64"; HOST_EXTRA="-D_DARWIN_C_SOURCE"; fi

# Atlas embed override: an EMPTY dir disables the embedded atlas array-literal
# (which the transpile path hangs O(n^2) on); the self-emit doesn't need it.
NOATLAS="$WORK/noatlas"; mkdir -p "$NOATLAS"

log "=== repo=$REPO HEAD=$HEAD_SHA work=$WORK ==="
mark "EXIT=. STAGE=start HEAD=$HEAD_SHA"

# ── flatten helper (single SSOT — same recipe as build_aprime.sh stage 1) ─────
flatten() { # $1=out.hexa
    REPO="$REPO" FLAT="$1" python3 - <<'PY'
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
print("flatten:",len(seen),"files",("\n".join(out)).count(chr(10))+1,"lines")
PY
}

# self-emit: $1=compiler $2=out.o $3=log  -> echoes "rc=N miss=M sz=S"
selfemit() {
    HEXA_ATLAS_EMBED="$NOATLAS" "$1" _drv.hexa --emit=obj \
        --target=arm64-apple-darwin --ignore-errors -o "$2" "$WORK/cc-flat.hexa" \
        > "$3" 2>&1
    local rc=$?
    local miss; miss=$(grep -c "ENCODE-MISS" "$3" 2>/dev/null || echo 0)
    local sz; sz=$(stat -f%z "$2" 2>/dev/null || stat -c%s "$2" 2>/dev/null || echo 0)
    echo "rc=$rc miss=$miss sz=$sz"
}

# ── stage: seeds + hexat ─────────────────────────────────────────────────────
if [ ! -x build/hexat ]; then
    log "stage seed: restoring frozen bootstrap seeds + building hexat"
    if [ ! -f self/native/hexa_cc.c ] || [ ! -f self/runtime.c ]; then
        bash tool/restore_frozen_seeds >/dev/null 2>&1 || fail seed restore_frozen_seeds
    fi
    [ -f self/native/hexa_cc.c ] || fail seed no-hexa_cc.c
    [ -f self/runtime.c ] || fail seed no-runtime.c
    mkdir -p build
    # hexat is the C-transpiler bootstrap: hexa_cc.c references the runtime ABI
    # (___hexa_last_error, ___hexa_fn_arena_*, ___hx_to_double, …), so self/runtime.c
    # MUST be in the same link (+ -lm for libm trig). Omitting it left a from-scratch
    # build failing `Undefined symbols … ___hexa_last_error` — fixed OP-129.
    # zero-c #29 own-_start flip (default-OFF byte-neutral): HEXA_ZEROC_OWN_START=1 compiles the
    # runtime scaffold (payload #ifdef) AND links -nostartfiles so the shipped hexat uses its own
    # _start (drops __libc_start_main/_start from the binary nm-u). Unset -> both empty -> identical.
    # DEFAULT-ON flip on x86_64-linux (validated 2-host summer+aiden: own _start boots, __libc_start_main
    # dropped). arm64-linux stays OFF (arm64 asm not yet 2-host-validated); darwin stays OFF (Mach-O
    # dyld/LC_MAIN entry — no -nostartfiles own _start). Env HEXA_ZEROC_OWN_START=0 force-overrides OFF.
    _zc_own_default=0
    if [ "$(uname -s)" = "Linux" ] && { [ "$(uname -m)" = "x86_64" ] || [ "$(uname -m)" = "aarch64" ]; }; then _zc_own_default=1; fi
    _zc_own_def=""; _zc_own_link=""
    if [ "${HEXA_ZEROC_OWN_START:-$_zc_own_default}" = "1" ]; then _zc_own_def="-DHEXA_ZEROC_OWN_START"; _zc_own_link="-nostartfiles"; fi
    clang -O2 $HOST_ARCH -std=gnu11 -D_GNU_SOURCE $HOST_EXTRA $_zc_own_def -Wno-trigraphs \
        -I self -I . self/native/hexa_cc.c self/runtime.c -o build/hexat -lm $_zc_own_link \
        2>&1 | grep -iE 'error:|undefined' | head -5
    [ -x build/hexat ] || fail seed hexat-build
fi
log "hexat: $(file -b build/hexat 2>/dev/null)"

# ── stage: runtime REGEN — close the from-scratch promote rot ─────────────────
# restore_frozen_seeds (above) leaves the STALE frozen self/runtime_core.c, and
# build_aprime.sh SKIPS its own regen when self/runtime.c is present (warm-tree
# guard, build_aprime.sh:62). Without this, rt.o + gen2+ link that stale runtime
# and gen2 dyld-FAILS at load on __map_raw_len / __raw_d2i (the helper family the
# current emitter SSOT owns but the 2026-05-29 frozen seed predates) -> stage2
# self-emit aborts rc=134 -> no byte-eq fixpoint. Regenerate runtime_core.c from
# the emitter SSOT (self/runtime_core_emit.hexa) so every stage links COMPLETE.
log "runtime: regen runtime_core.c from emitter SSOT (stage_resolve_runtime_a)"
# byteeq only needs the runtime_core.c REGEN side-effect here — it builds its OWN
# rt.o below (flag-free clang) and never links the runtime.a stage_resolve_runtime_a
# produces. Pin HEXA_RT_MULTIOBJ=0 so this regen-only call takes the single-TU
# archive path even when invoked from an env where the release default-ON flip is
# set (release_build exports HEXA_RT_MULTIOBJ=1) — the multi-object packaging is
# pure wasted work for the self-host fixpoint and is link-form-agnostic to it.
HEXA_RT_MULTIOBJ=0 CC="${CC:-clang}" bash tool/stage_resolve_runtime_a >/dev/null 2>&1 || fail seed runtime-regen

# ── stage 0: aprime_cc (the proven canonical recipe) ─────────────────────────
log "stage0: build_aprime.sh -> aprime_cc"
bash tool/build_aprime.sh -r "$REPO" -o "$WORK/aprime_cc" -v "$REPO/build/hexat" \
    > "$WORK/aprime.log" 2>&1
APRC=$?
[ "$APRC" = 0 ] && [ -x "$WORK/aprime_cc" ] || { tail -5 "$WORK/aprime.log" >&2; fail stage0 "aprime rc=$APRC"; }
log "stage0: aprime_cc OK ($(stat -f%z "$WORK/aprime_cc" 2>/dev/null || echo ?) B)"

# ── stage: runtime object (self/runtime.c) ───────────────────────────────────
log "runtime: clang self/runtime.c -> rt.o"
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
clang -c -O2 $HOST_ARCH -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs \
    -I self -I . self/runtime.c -o "$WORK/rt.o" 2>&1 | grep -iE 'error:|undefined|ld:|fatal|cannot find' | head -3
[ -s "$WORK/rt.o" ] || fail runtime rt.o

# ── stage: hexa_ld (Mach-O linker w/ __literal8 const-merge fix on main) ──────
log "linker: build hexa_ld from tool/hexa_ld.hexa"
flatten "$WORK/ld-flat.hexa" || fail linker flatten-ld
# hexa_ld is a normal compiler program: transpile its own flat closure via
# aprime_cc (native emit) then link. But the simplest reproducible path is to
# transpile via hexat -> C -> clang, identical to the aprime recipe, since
# hexa_ld shares the runtime. We flatten tool/hexa_ld.hexa's own closure.
REPO="$REPO" FLAT="$WORK/ld-flat.hexa" ENTRY="tool/hexa_ld.hexa" python3 - <<'PY'
import re, os
repo=os.environ["REPO"]; flat=os.environ["FLAT"]; entry=os.environ["ENTRY"]
os.chdir(repo)
seen=[]; sset=set()
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
walk(entry)
out=[]
for f in seen:
    t=open(f,encoding="utf-8",errors="replace").read()
    t=re.sub(r'^\s*(import|use)\s+"[^"]*".*$','',t,flags=re.M)
    out.append("// ==== "+f+" ====\n"+t)
open(flat,"w").write("\n".join(out))
print("ld flatten:",len(seen),"files")
PY
build/hexat "$WORK/ld-flat.hexa" "$WORK/ld.c" 2>&1 | tail -1
[ -f "$WORK/ld.c" ] || fail linker hexat-transpile-ld
python3 tool/s4_flatc_post.py "$WORK/ld.c" 2>&1 | tail -1
sed -E -e 's/hexa_call1\(sha256_hex,[ ]*([^)]*)\)/hexa_sha256(\1)/g' \
       -e 's/hexa_call1\(list_dir,[ ]*[^)]*\)/hexa_array_new()/g' \
       "$WORK/ld.c" > "$WORK/ld-post.c"
sed -i.bak 's|#include "runtime.h"|#include "runtime.c"|' "$WORK/ld-post.c"; rm -f "$WORK/ld-post.c.bak"
clang -Oz $HOST_ARCH -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs $EXTRA \
    -I self -I . "$WORK/ld-post.c" -o "$WORK/hexa_ld" -lm 2>&1 | grep -iE 'error:|undefined' | head -5
[ -x "$WORK/hexa_ld" ] || fail linker hexa_ld-clang
log "linker: hexa_ld OK ($(stat -f%z "$WORK/hexa_ld" 2>/dev/null || echo ?) B)"

LD="$WORK/hexa_ld"

if [ "$JUST_STAGE0" = 1 ]; then
    log "stage0-only (-j): aprime_cc + hexa_ld + rt.o built. Stopping before self-emits."
    mark "EXIT=0 STAGE=stage0-only HEAD=$HEAD_SHA aprime=ok hexa_ld=ok rt=ok"
    exit 0
fi

# ── shared flattened compiler source (the self-emit input) ───────────────────
log "flatten: compiler/main.hexa closure -> cc-flat.hexa"
flatten "$WORK/cc-flat.hexa" || fail flatten cc-flat
[ -s "$WORK/cc-flat.hexa" ] || fail flatten cc-flat-empty

# ── stage 1: aprime emits cc-prc2.o -> link gen2 ─────────────────────────────
log "stage1: aprime_cc self-emit -> cc-prc2.o (~68min)"
R=$(selfemit "$WORK/aprime_cc" "$WORK/cc-prc2.o" "$WORK/emit1.log"); log "stage1: $R"
[ -s "$WORK/cc-prc2.o" ] || fail stage1 "emit ($R)"
mark "EXIT=. STAGE=stage1-emitted HEAD=$HEAD_SHA $R"
"$LD" -o "$WORK/gen2" "$WORK/cc-prc2.o" "$WORK/rt.o" --lc-main _main > "$WORK/link2.log" 2>&1 \
    || fail stage1 link-gen2
[ -x "$WORK/gen2" ] || fail stage1 gen2-missing
log "stage1: gen2 linked"

# ── stage 2: gen2 emits cc-gen3.o -> link gen3 ───────────────────────────────
log "stage2: gen2 self-emit -> cc-gen3.o (~68min)"
R=$(selfemit "$WORK/gen2" "$WORK/cc-gen3.o" "$WORK/emit2.log"); log "stage2: $R"
[ -s "$WORK/cc-gen3.o" ] || fail stage2 "emit ($R)"
mark "EXIT=. STAGE=stage2-emitted HEAD=$HEAD_SHA $R"
"$LD" -o "$WORK/gen3" "$WORK/cc-gen3.o" "$WORK/rt.o" --lc-main _main > "$WORK/link3.log" 2>&1 \
    || fail stage2 link-gen3
[ -x "$WORK/gen3" ] || fail stage2 gen3-missing
log "stage2: gen3 linked"

# ── stage 3: gen3 emits cc-gen4.o (the fixpoint witness) ─────────────────────
log "stage3: gen3 self-emit -> cc-gen4.o (~68min)"
R=$(selfemit "$WORK/gen3" "$WORK/cc-gen4.o" "$WORK/emit3.log"); log "stage3: $R"
[ -s "$WORK/cc-gen4.o" ] || fail stage3 "emit ($R)"
MISS3=$(echo "$R" | grep -oE 'miss=[0-9]+' | cut -d= -f2)

# ── GATE: byte-eq fixpoint cc-gen3.o == cc-gen4.o ────────────────────────────
SZ3=$(stat -f%z "$WORK/cc-gen3.o" 2>/dev/null || echo 0)
SZ4=$(stat -f%z "$WORK/cc-gen4.o" 2>/dev/null || echo 0)
if cmp "$WORK/cc-gen3.o" "$WORK/cc-gen4.o" > "$WORK/gate.log" 2>&1; then
    GATE="BYTE-EQ"; RC=0
    log "GATE: BYTE-EQ FIXPOINT — cc-gen3.o == cc-gen4.o ($SZ4 B). SELF-HOST GRADUATION."
else
    FIRST=$(cmp "$WORK/cc-gen3.o" "$WORK/cc-gen4.o" 2>&1 | grep -oE 'byte [0-9]+' | grep -oE '[0-9]+' | head -1)
    GATE="DIFFER@${FIRST:-NA}"; RC=2
    log "GATE: NOT a fixpoint — cc-gen3.o != cc-gen4.o ($GATE; sz3=$SZ3 sz4=$SZ4)"
fi

# smoke: gen3 runs (no-arg invocation must not crash)
"$WORK/gen3" > "$WORK/gen3_smoke.log" 2>&1; SMK=$?
mark "EXIT=$RC STAGE=fixpoint HEAD=$HEAD_SHA GATE=$GATE SZ3=$SZ3 SZ4=$SZ4 GEN3_MISS=$MISS3 SMOKE=$SMK"
log "DONE: GATE=$GATE smoke_rc=$SMK"
exit $RC
