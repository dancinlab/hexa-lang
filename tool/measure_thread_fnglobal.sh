#!/usr/bin/env bash
# tool/measure_thread_fnglobal.sh — FLEET lane A3: thread fn-global fwd-decl.
#
# Proves the A end-to-end: a hexa SOURCE that directly thread_spawn()s N OS
# threads sharing an escaping packed [i64] buffer.
#
#   BEFORE (runtime.h WITHOUT the thread carrier fwd-decls): the C-transpile /
#          hexa run path fails to compile (undeclared `thread_spawn`).
#   AFTER  (runtime.h WITH the fwd-decls): compiles + links; with HEXA_THREADS
#          set the 4P+4C real-spawn path runs and the joined total == oracle.
#
# Also re-checks G-BYTEEQ: the DEFAULT (flag-OFF) runtime.o is byte-identical
# before/after — the fix is declaration-only.
#
# Run on aiden (mini cannot build). Single-SSH, isolated $HOME scratch.
#   bash tool/measure_thread_fnglobal.sh
set -u

BR="${BR:-feat/thread-fnglobal-fwddecl}"
CANON="${CANON:-$HOME/hexa-lang}"
SLUG="$(echo "$BR" | tr '/ ' '__')"
WORK="${WORK:-$HOME/thread_fnglobal_${SLUG}}"
RESULT="${RESULT:-$HOME/thread_fnglobal_${SLUG}_RESULT.txt}"
CC="${CC:-clang}"
TGT="x86_64-linux-gnu"
TEST_HEXA="test/real_spawn_packed_buf.hexa"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== thread-fnglobal measure — branch=$BR — $(date -u +%FT%TZ) — $(hostname) ==="

for w in $(seq 1 60); do
    L=$(awk '{print $1}' /proc/loadavg 2>/dev/null); Li=${L%.*}
    [ "${Li:-99}" -lt 6 ] && { say "  load=$L OK"; break; }
    [ "$w" = 60 ] && say "  load high (last=$L) — proceeding"; sleep 30
done

rm -rf "$WORK"; mkdir -p "$WORK"
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }

git -C "$CANON" worktree prune 2>>"$WORK/git.log" || true
git -C "$CANON" fetch -f origin "$BR:refs/remotes/origin/$BR" 2>>"$WORK/git.log" || say "  (fetch BR warn)"
git -C "$CANON" worktree add -f --detach "$WORK/src" "origin/$BR" 2>>"$WORK/git.log" \
    || { say "FATAL cannot materialise $BR"; exit 3; }
SRC="$WORK/src"
say "  SRC=$SRC  sha=$(git -C "$SRC" rev-parse --short HEAD)"

prep_seeds() { local s="$1"
    for f in self/runtime.c self/native/hexat self/native/hexa_cc.c; do
        [ -e "$CANON/$f" ] && [ ! -e "$s/$f" ] && { mkdir -p "$s/$(dirname "$f")"; cp -a "$CANON/$f" "$s/$f" 2>/dev/null; }
    done
    [ -d "$CANON/self/native" ] && cp -an "$CANON/self/native/." "$s/self/native/" 2>/dev/null || true
    [ -d "$CANON/build" ] && mkdir -p "$s/build" && cp -an "$CANON/build/hexat" "$s/build/" 2>/dev/null || true; }
prep_seeds "$SRC"

KERN="$SRC/$TEST_HEXA"
[ -f "$KERN" ] || { say "FATAL: test missing $KERN"; exit 4; }

# ── build runtime.a once (-DHEXA_PACK_ESCAPING + threads) ────────────────────
say "--- building runtime.a (-DHEXA_PACK_ESCAPING) ---"
( cd "$SRC"
  env -u HEXA_CUDA CC="$CC" LIBS="${LIBS:--lm -lpthread}" \
      CFLAGS_COMMON="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -DHEXA_PACK_ESCAPING" \
      bash tool/stage_resolve_runtime_a ) >"$WORK/rt.log" 2>&1 \
    && say "  runtime.a EXIT=0" || { say "  runtime.a EXIT=$?"; tail -25 "$WORK/rt.log" | sed 's/^/    /' | tee -a "$RESULT"; }
RT="$SRC/build/runtime.a"
[ -f "$RT" ] || { say "FATAL: runtime.a not built"; exit 4; }
# the carrier globals must be DEFINED in the archive (thread.c members)
for sym in thread_spawn thread_join; do
    if nm "$RT" 2>/dev/null | grep -qw "$sym"; then say "  runtime.a DEFINES $sym"; else say "  ⚠ runtime.a missing $sym"; fi
done

# ── runtime.h presence assertion (the fix) ───────────────────────────────────
say "--- runtime.h carrier decls (the fix) ---"
for sym in thread_spawn thread_join thread_channel_recv sleep_ms now_ms; do
    if grep -q "extern HexaVal $sym;" "$SRC/self/runtime.h"; then say "  runtime.h DECLARES extern HexaVal $sym"; else say "  ⚠ runtime.h MISSING extern HexaVal $sym"; fi
done

# ── build aprime once ───────────────────────────────────────────────────────
say "--- building aprime_cc ---"
( cd "$SRC"; setsid bash tool/build_aprime.sh -o "$WORK/aprime_cc" -r "$SRC" ) >"$WORK/aprime.log" 2>&1 \
    && say "  aprime EXIT=0" || { say "  aprime EXIT=$?"; tail -30 "$WORK/aprime.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"

# ── AFTER: compile the test via the user-facing `hexa run` path ──────────────
# The real user path is `hexa run` (C-transpile through self/codegen.hexa), the
# ING#33 class. Use the installed/seeded hexat -> C -> clang path with the
# PATCHED runtime.h (carrier decls present).
HEXA="$SRC/build/hexat"
say "--- AFTER: hexa-source 4P+4C escaping packed compile + run (patched runtime.h) ---"
# emit user.c via hexat, compile with patched runtime.h on the include path
run_e2e() { # $1=tag $2=envk
    local tag="$1" envk="$2"
    local uc="$WORK/$tag.user.c" bin="$WORK/$tag.bin"
    # hexat transpiles `.hexa` → `.c` via positional args: hexat IN.hexa OUT.c
    ( cd "$SRC"; "$HEXA" "$KERN" "$uc" ) >"$WORK/$tag.emitc.log" 2>&1
    if [ ! -f "$uc" ]; then say "  $tag: hexat transpile produced no user.c (see $tag.emitc.log)"; tail -8 "$WORK/$tag.emitc.log" | sed 's/^/      /' | tee -a "$RESULT"; return 9; fi
    grep -q 'thread_spawn' "$uc" && say "  $tag: user.c references thread_spawn (bare-ident carrier)"
    "$CC" -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_PACK_ESCAPING -I"$SRC/self" "$uc" "$RT" -lm -lpthread -o "$bin" 2>"$WORK/$tag.cc.log" \
        || { say "  $tag: COMPILE/LINK FAIL"; grep -iE 'thread_spawn|undeclar|implicit|undefined' "$WORK/$tag.cc.log" | head -6 | sed 's/^/      /' | tee -a "$RESULT"; return 1; }
    ( cd "$WORK"; env $envk "$bin" ) >"$WORK/$tag.out" 2>"$WORK/$tag.err"; local rc=$?
    say "  $tag run rc=$rc:"; tail -10 "$WORK/$tag.out" | sed 's/^/      /' | tee -a "$RESULT"
    [ -s "$WORK/$tag.err" ] && { tail -4 "$WORK/$tag.err" | sed 's/^/      ERR /' | tee -a "$RESULT"; }
    return $rc; }
run_e2e oracle "HEXA_PACK_ESCAPING=1"                ; ORACLE_RC=$?
run_e2e e2e    "HEXA_PACK_ESCAPING=1 HEXA_THREADS=1" ; E2E_RC=$?
say "  AFTER: oracle rc=$ORACLE_RC  4P+4C rc=$E2E_RC  (0 = all checks PASS)"

# ── BEFORE: strip the carrier decls from runtime.h → expect compile fail ─────
say "--- BEFORE: runtime.h WITHOUT carrier decls → expect compile fail ---"
BSRC="$WORK/before"; cp -a "$SRC" "$BSRC"
# remove the carrier-decl block (delete the 8 thread + 6 atomic extern lines)
sed -i '/extern HexaVal thread_spawn;/,/extern HexaVal atomic_cell_cas;/d' "$BSRC/self/runtime.h"
grep -q 'extern HexaVal thread_spawn;' "$BSRC/self/runtime.h" && say "  ⚠ strip failed (decls still present)" || say "  carrier decls stripped from before/runtime.h"
BUC="$WORK/before.user.c"
( cd "$BSRC"; "$HEXA" "$KERN" "$BUC" ) >"$WORK/before.emitc.log" 2>&1
if [ -f "$BUC" ]; then
    "$CC" -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_PACK_ESCAPING -I"$BSRC/self" "$BUC" "$RT" -lm -lpthread -o "$WORK/before.bin" 2>"$WORK/before.cc.log"
    BRC=$?
    if [ "$BRC" != 0 ]; then
        say "  BEFORE compile FAILED (rc=$BRC) as expected — undeclared thread_spawn:"
        grep -iE 'thread_spawn|undeclar|implicit declaration|undefined' "$WORK/before.cc.log" | head -4 | sed 's/^/      /' | tee -a "$RESULT"
    else
        say "  ⚠ BEFORE compiled rc=0 — carrier decl was NOT load-bearing (investigate)"
    fi
else
    say "  BEFORE: hexat transpile produced no user.c (see before.emitc.log)"
    tail -6 "$WORK/before.emitc.log" | sed 's/^/      /' | tee -a "$RESULT"
fi

# ── G-BYTEEQ: DEFAULT runtime.o byte-identical before/after (decl-only) ──────
say "--- G-BYTEEQ (DEFAULT runtime.o byte-identical before/after the runtime.h decl) ---"
# Default build = NO -DHEXA_PACK_ESCAPING, NO -DHEXA_THREADS. Compile runtime.c
# against patched vs stripped runtime.h; the .o must be byte-identical.
byteeq_o() { # $1=src-dir $2=out.o
    ( cd "$1"; "$CC" -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -c self/runtime.c -I self -o "$2" ) 2>"$2.log"; }
byteeq_o "$SRC"  "$WORK/after.rt.o"
byteeq_o "$BSRC" "$WORK/before.rt.o"
if [ -f "$WORK/after.rt.o" ] && [ -f "$WORK/before.rt.o" ]; then
    if cmp -s "$WORK/after.rt.o" "$WORK/before.rt.o"; then
        say "  G-BYTEEQ OK: DEFAULT runtime.o BYTE-IDENTICAL before/after (x86_64-linux)"
    else
        say "  G-BYTEEQ DIFFER (unexpected for decl-only):"
        objdump -d "$WORK/before.rt.o" >"$WORK/b.s" 2>/dev/null; objdump -d "$WORK/after.rt.o" >"$WORK/a.s" 2>/dev/null
        diff "$WORK/b.s" "$WORK/a.s" | head -20 | sed 's/^/    /' | tee -a "$RESULT"
    fi
else
    say "  G-BYTEEQ: missing .o (after=$([ -f "$WORK/after.rt.o" ]&&echo y||echo n) before=$([ -f "$WORK/before.rt.o" ]&&echo y||echo n))"
    tail -6 "$WORK/after.rt.o.log" 2>/dev/null | sed 's/^/    A /' | tee -a "$RESULT"
fi

say "=== RESULT branch=$BR  AFTER(oracle=$ORACLE_RC 4P+4C=$E2E_RC) ==="
say "=== DONE — artifacts under $WORK ==="
