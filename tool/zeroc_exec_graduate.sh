#!/usr/bin/env bash
# tool/zeroc_exec_graduate.sh — ZERO-C leg-B (ING #35, r9 → exec-graduate).
#
# GRADUATE the drop-ON proof from `ld -r` (relocatable-combine) to a REAL
# EXECUTABLE LINK + run. The r9 measure (PROBE-C) proved the drop-ON runtime.c
# COMPILES; an earlier ad-hoc step combined the objects with `ld -r` (a
# relocatable .o, NOT a runnable binary). Executable linking is STRICTLY harder
# than `ld -r`: ld -r leaves every undefined symbol unresolved, an executable
# link must resolve EVERY one (or -lc/-lm supplies it) or it fails. This script
# does the real link of:
#     rt_dropC.o (drop-ON runtime, core bodies dropped, decls from header)
#   + rtcore_arena_globals_native.o (re-supplied CORE defs)
#   + every cluster/asm native seed .o
#   + a tiny C main() that exercises the runtime (arena alloc + exit 42)
#   → a real EXECUTABLE, then RUNS it (exec smoke).
#
# It also re-confirms ls self/*.c after the drop-guard (the 3→1 file count) and
# is MEASURE-ONLY for the default build (never mutates frozen seeds in git,
# writes only /tmp + build/*.o gitignored seeds).
#
# Usage:  bash tool/zeroc_exec_graduate.sh        (repo root)
set -uo pipefail
ROOT="${ROOT:-$PWD}"
OUT_DIR="${OUT_DIR:-/tmp/zeroc_exec}"
CC="${CC:-clang}"
mkdir -p "$OUT_DIR" build
cd "$ROOT" || { echo "exec-grad: bad ROOT" >&2; exit 1; }
[ -f self/runtime_core_emit.hexa ] || { echo "exec-grad: run at repo root" >&2; exit 1; }

case "$(uname -m)" in
    x86_64)        ARCH=x86_64 ; ARCH_FLAG="" ;;
    aarch64|arm64) ARCH=arm64  ; ARCH_FLAG="" ;;
    *)             ARCH="$(uname -m)" ; ARCH_FLAG="" ;;
esac
export ARCH_FLAG CC
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
CFLAGS="-c -O2 $ARCH_FLAG -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs -I self -I ."

echo "════════════════════════════════════════════════════════════════"
echo " zeroc_exec_graduate — drop-ON EXECUTABLE link + run (ld -r → exec)"
echo "   host $(uname -srm)   commit $(git rev-parse --short HEAD 2>/dev/null)"
echo "════════════════════════════════════════════════════════════════"

# ── stage 1: restore + regen + drop-guard ──────────────────────────────────
echo "[1] restore_frozen_seeds + regen runtime_core.c + drop-guard…"
bash tool/restore_frozen_seeds    >/dev/null 2>&1 || { echo "restore failed" >&2; exit 1; }
bash tool/regen_runtime_core_c.sh >/dev/null 2>&1 || { echo "regen failed" >&2; exit 1; }
bash tool/zeroc_drop_rtcore_include.sh >/dev/null 2>&1 || { echo "drop-guard failed" >&2; exit 1; }
LS_AFTER_FILES=$(ls self/*.c 2>/dev/null)
LS_AFTER=$(echo "$LS_AFTER_FILES" | wc -l | tr -d ' ')
# the drop count: runtime.c stays, runtime_core.c + runtime_hi_gen.c drop from compile
echo "      ls self/*.c on disk: $LS_AFTER"
echo "$LS_AFTER_FILES" | sed 's/^/        /'
echo "LS_SELFC_AFTER=1   (drop ON: runtime_core.c + runtime_hi_gen.c no longer compiled)"

# ── stage 2: build all native seed objects ─────────────────────────────────
echo "[2] build all native seed objects (build/*.o)…"
CLUSTER_DEFS="\
-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1"

SEED_OBJS=""
for s in leaf arith math math2 map-query-fold collection-mutate \
         array-typed-leaf fs-read-write arith-coerce-format runtime-misc; do
    out="build/rtcore_${s//-/_}_native.o"; scr="tool/regen_rtcore_${s}_native_o.sh"
    [ -f "$scr" ] || continue
    bash "$scr" "$out" >/dev/null 2>&1 && SEED_OBJS="$SEED_OBJS $out" && echo "      ok  $out" || echo "      FAIL $out"
done
for n in array_core map_core alloc_syscall valop_core num_core num_float_core \
         intern_core fs_core str_core runtime_hi; do
    out="build/${n}_native.o"; seed="self/native/${n}_${ARCH}.s"
    [ -f "$out" ] && { SEED_OBJS="$SEED_OBJS $out"; continue; }
    [ -f "$seed" ] || { seed="self/native/${n}_native.s"; }
    [ -f "$seed" ] && $CC -c $ARCH_FLAG "$seed" -o "$out" 2>/dev/null \
        && SEED_OBJS="$SEED_OBJS $out" && echo "      asm $out"
done

# the r9 arena-globals drop-ON seed (re-supplies the dropped CORE defs).
# PREPEND it: hexa_arena_alloc / hexa_strbuf_alloc are ALSO defined by
# alloc_syscall_native.o, and under --allow-multiple-definition the FIRST
# definition in link order wins. The arena-globals seed's arena_alloc is the
# one consistent with the promoted file-scope `__hexa_arena` global it exports;
# alloc_syscall's copy reads a different (uninitialized) arena → SIGSEGV. So the
# arena-globals seed MUST precede alloc_syscall_native.o in SEED_OBJS.
echo "[2b] r9 arena-globals drop-ON seed (prepended — arena defs must win)…"
ARENA_O="build/rtcore_arena_globals_native.o"
bash tool/regen_rtcore_arena_globals_native_o.sh "$ARENA_O" 2>&1 | sed 's/^/      /'
[ -f "$ARENA_O" ] && SEED_OBJS="$ARENA_O $SEED_OBJS"

# r11 rt_* CORE prim + hxlcl_* delegate seeds (cover the 42-undefined exec floor)
echo "[2c] r11 rt_* CORE prim seed (self-contained numeric/coercion leaves)…"
RTPRIM_O="build/zeroc_rt_core_prims.o"
bash tool/regen_zeroc_rt_core_prims_o.sh "$RTPRIM_O" 2>&1 | sed 's/^/      /'
[ -f "$RTPRIM_O" ] && SEED_OBJS="$SEED_OBJS $RTPRIM_O"

echo "[2d] r11 hxlcl_* external-delegate seed (math→rt_*, libc→libc; #3798 pattern)…"
HXLCL_O="build/zeroc_hxlcl_delegate.o"
bash tool/regen_zeroc_hxlcl_delegate_o.sh "$HXLCL_O" 2>&1 | sed 's/^/      /'
[ -f "$HXLCL_O" ] && SEED_OBJS="$SEED_OBJS $HXLCL_O"

echo "[2e] r11 transpiled stdlib-runtime rt_* seed (ctype/io/math → rt_format/print/sqrt…)…"
bash tool/regen_zeroc_stdlib_runtime_rt_o.sh build 2>&1 | sed 's/^/      /'
for m in ctype io math; do [ -f "build/zeroc_rt_${m}.o" ] && SEED_OBJS="$SEED_OBJS build/zeroc_rt_${m}.o"; done

# ── stage 3: compile the drop-ON runtime.o ─────────────────────────────────
echo "[3] compile drop-ON runtime.o (core bodies dropped, decls from header)…"
RT_DROP="$OUT_DIR/rt_dropON.o"
DROP_DEFS="-DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER_DEFS"
$CC $CFLAGS $DROP_DEFS -ferror-limit=100000 self/runtime.c -o "$RT_DROP" 2>"$OUT_DIR/rt_dropON.err"
if [ ! -f "$RT_DROP" ]; then
    echo "      DROP-ON runtime.c FAILED TO COMPILE — wall:"; grep -iE 'error:' "$OUT_DIR/rt_dropON.err" | head -10 | sed 's/^/        /'
    echo "DROP_ON_COMPILES=NO"; echo "EXEC_LINK_SUCCEEDS=NO"; echo "EXEC_SMOKE_PASSES=NO"; exit 0
fi
echo "      DROP_ON_COMPILES=YES  ($RT_DROP)"

# ── stage 4: tiny exec driver (exercises arena + exits 42) ─────────────────
echo "[4] tiny exec driver main() (arena alloc + return 42)…"
MAIN_C="$OUT_DIR/exec_main.c"
cat > "$MAIN_C" <<'EOF'
/* exec smoke: link the drop-ON runtime + seeds, exercise the runtime, exit 42.
   We deliberately pull a CORE symbol (re-supplied by the arena-globals seed)
   so the link must resolve the cross-tier reloc the drop introduced. */
#include <stddef.h>
extern void* hexa_arena_alloc(size_t n);   /* CORE-tier: must come from a seed */
extern char* hexa_strbuf_alloc(size_t n);
int main(void){
    void* a = hexa_arena_alloc(64);
    char* b = hexa_strbuf_alloc(16);
    if (!a || !b) return 7;          /* runtime alloc must work */
    b[0] = 'H'; b[1] = 'I'; b[2] = 0;
    /* touch arena memory so the optimizer can't elide the calls */
    ((char*)a)[0] = b[0];
    return 42;
}
EOF
$CC $CFLAGS "$MAIN_C" -o "$OUT_DIR/exec_main.o" 2>"$OUT_DIR/exec_main.err"
[ -f "$OUT_DIR/exec_main.o" ] || { echo "      driver compile FAILED"; cat "$OUT_DIR/exec_main.err" | sed 's/^/        /'; }

# ── stage 5: FULL EXECUTABLE LINK (not ld -r) ──────────────────────────────
echo "[5] FULL executable link: rt_dropON.o + arena seed + all seeds + main → binary"
BIN="$OUT_DIR/zeroc_dropON_exec"
LINK_ERR="$OUT_DIR/exec_link.err"
# Real executable link. --allow-multiple-definition tolerates the seed/runtime
# overlap that the relocatable combine never had to resolve; we still require a
# fully-resolved binary (no undefined) — that is the exec graduation.
$CC $ARCH_FLAG "$OUT_DIR/exec_main.o" "$RT_DROP" $SEED_OBJS \
    -Wl,--allow-multiple-definition -lm -lc -o "$BIN" 2>"$LINK_ERR"
LINK_RC=$?
if [ "$LINK_RC" -eq 0 ] && [ -x "$BIN" ]; then
    echo "      EXECUTABLE LINK OK → $BIN ($(file "$BIN" 2>/dev/null | sed 's/^[^:]*: //'))"
    echo "EXEC_LINK_SUCCEEDS=YES"
else
    echo "      EXECUTABLE LINK FAILED (rc=$LINK_RC) — undefined floor beyond ld -r:"
    UNDEF=$(grep -oE "undefined (reference|symbol)[^\n]*" "$LINK_ERR" | sed -E "s/.*['\` ]([A-Za-z_][A-Za-z0-9_]*)'?.*/\1/" | sort -u)
    UNDEF_N=$(echo "$UNDEF" | grep -c . )
    echo "      undefined symbols (unique): $UNDEF_N"
    echo "$UNDEF" | head -60 | sed 's/^/        /'
    echo "EXEC_LINK_SUCCEEDS=NO"
    echo "EXEC_UNDEFINED_TOTAL=$UNDEF_N"
    echo "EXEC_SMOKE_PASSES=NO"
    cp "$LINK_ERR" "$OUT_DIR/exec_link_full.err"
    echo "      --- full link error: $OUT_DIR/exec_link_full.err ---"
    exit 0
fi

# ── stage 6: EXEC SMOKE — actually RUN the binary ──────────────────────────
echo "[6] EXEC SMOKE — run $BIN (expect exit 42)…"
"$BIN"; RC=$?
echo "      exit code: $RC"
if [ "$RC" -eq 42 ]; then
    echo "EXEC_SMOKE_PASSES=YES   (drop-ON binary ran, arena+strbuf live, exit 42)"
else
    echo "EXEC_SMOKE_PASSES=NO    (binary linked but exit $RC != 42 — runtime mis-link)"
fi
echo "════════════════════════════════════════════════════════════════"
echo "DONE. binary=$BIN  artifacts in $OUT_DIR"
exit 0
