#!/usr/bin/env bash
# tool/measure_thread_channel_e2e.sh — FLEET 잔여 #4 r2: thread_channel 2P+2C e2e.
#
# Proves the producer–consumer CHANNEL hand-off that #4154 (spawn/join + shared
# buffer) did not cover: a hexa SOURCE in which 2 producers push integers into a
# mutex+condvar `thread_channel_*` queue and 2 consumers drain it, with an
# order-insensitive total-sum oracle.
#
#   ORACLE run  (no HEXA_THREADS)        : pure arithmetic, default-build-safe.
#   2P+2C  run  (-DHEXA_THREADS + env)   : real OS threads + condvars; consumers
#                                          block on the empty channel, producers
#                                          push, channel closes, consumers drain
#                                          + see "" sentinel. Σ sums == oracle.
#
# REAL threads require runtime.c built -DHEXA_THREADS (runtime_emit_full.hexa:2472);
# the DEFAULT build is a synchronous shim (cond_wait no-op) — so this harness
# builds runtime.a AND the test with -DHEXA_THREADS, and links -lpthread.
#
# Also re-checks G-BYTEEQ: this branch changes NO runtime/codegen source (NEW
# test file + tool only), so the DEFAULT runtime.o is byte-identical to origin/main.
#
# Run on aiden (mini cannot build). Single-SSH, isolated $HOME scratch.
#   bash tool/measure_thread_channel_e2e.sh
set -u

BR="${BR:-feat/thread-channel-e2e}"
CANON="${CANON:-$HOME/hexa-lang}"
SLUG="$(echo "$BR" | tr '/ ' '__')"
WORK="${WORK:-$HOME/thread_channel_${SLUG}}"
RESULT="${RESULT:-$HOME/thread_channel_${SLUG}_RESULT.txt}"
CC="${CC:-clang}"
TEST_HEXA="test/channel_2p2c_e2e.hexa"
CRASH_RUNS="${CRASH_RUNS:-20}"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== thread-channel 2P+2C measure — branch=$BR — $(date -u +%FT%TZ) — $(hostname) ==="

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
    for d in native forge; do
        [ -d "$CANON/self/$d" ] && { mkdir -p "$s/self/$d"; cp -an "$CANON/self/$d/." "$s/self/$d/" 2>/dev/null; }
    done
    [ -d "$CANON/build" ] && mkdir -p "$s/build" && cp -an "$CANON/build/hexat" "$s/build/" 2>/dev/null || true; }
prep_seeds "$SRC"

KERN="$SRC/$TEST_HEXA"
[ -f "$KERN" ] || { say "FATAL: test missing $KERN"; exit 4; }

# ── REGEN runtime.c from its emitter SSOT (the #4100 game-thread recipe) ──────
# The on-disk/frozen self/runtime.c seed is STALE: the `#if defined(HEXA_THREADS)`
# real-pthread block lives ONLY in the emitter self/runtime_emit_full.hexa and was
# never baked into the frozen .c (rfc_game_thread_perf.md:77-82). Building the
# stale .c links the SYNCHRONOUS `#else` shims (rt_pthread_noop) → blocking recv
# spins. Regen runtime.c VERBATIM from the emitter (deterministic hexat-FREE awk
# un-escaper, same primary path as stage_resolve_runtime_a / regen_runtime_core_c.sh;
# 14683 pure `buf = buf + "..."` literals) so the HEXA_THREADS branch is present.
# runtime.c `#include "native/thread.c"` (the hand-written channel logic), so a
# single -DHEXA_THREADS TU yields real OS threads. (BYTEEQ-NEUTRAL: this regen is
# for the THREADS measurement only; the DEFAULT byteeq check below uses the seed.)
# runtime.c #includes the GENERATED self/runtime_core.c (line ~2149) + native/*
# + forge/* fragments. native/forge are copied by prep_seeds; runtime_core.c is
# generated → regen it from its emitter SSOT (canonical hexat-free tool).
say "--- REGEN runtime_core.c (tool/regen_runtime_core_c.sh) ---"
bash "$SRC/tool/regen_runtime_core_c.sh" "$SRC" >"$WORK/rtcore.log" 2>&1 \
    && say "  runtime_core.c: $(wc -l < "$SRC/self/runtime_core.c" 2>/dev/null) lines" \
    || { say "  ⚠ regen_runtime_core_c rc=$?"; tail -8 "$WORK/rtcore.log" | sed 's/^/    /' | tee -a "$RESULT"; }
[ -f "$SRC/self/runtime_core.c" ] || { say "FATAL: runtime_core.c not generated"; exit 4; }

say "--- REGEN runtime.c from runtime_emit_full.hexa (un-escaper) ---"
EMIT="$SRC/self/runtime_emit_full.hexa"
[ -f "$EMIT" ] || { say "FATAL: emitter missing $EMIT"; exit 4; }
awk '
  BEGIN { saw = 0 }
  { line = $0; pfx = "    buf = buf + \""
    if (substr(line, 1, length(pfx)) != pfx) next
    body = substr(line, length(pfx) + 1)
    if (substr(body, length(body), 1) != "\"") next
    body = substr(body, 1, length(body) - 1)
    saw = 1; out = ""; n = length(body); i = 1
    while (i <= n) { c = substr(body, i, 1)
      if (c == "\\" && i < n) { d = substr(body, i+1, 1)
        if (d == "n") { out = out "\n"; i += 2; continue }
        if (d == "t") { out = out "\t"; i += 2; continue }
        if (d == "\"") { out = out "\""; i += 2; continue }
        if (d == "\\") { out = out "\\"; i += 2; continue }
        out = out "\\"; i += 1; continue }
      out = out c; i += 1 }
    printf "%s", out }
  END { if (!saw) exit 3 }' "$EMIT" > "$SRC/self/runtime.c" || { say "FATAL: regen awk rc=$?"; exit 4; }
TC=$(grep -c "HEXA_THREADS" "$SRC/self/runtime.c"); PC=$(grep -c "pthread_create((pthread_t" "$SRC/self/runtime.c")
say "  regen'd runtime.c: $(wc -l < "$SRC/self/runtime.c") lines · HEXA_THREADS=$TC · real-pthread_create=$PC"
[ "$PC" -ge 1 ] || { say "FATAL: regen'd runtime.c lacks real pthread_create branch"; exit 4; }

# ── build runtime.a from the regen'd single TU WITH -DHEXA_THREADS ────────────
say "--- building runtime.a (clang -DHEXA_THREADS -c runtime.c) ---"
( cd "$SRC"; "$CC" -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_THREADS -Wno-trigraphs -c self/runtime.c -I self -o "$WORK/runtime.o" ) >"$WORK/rt.log" 2>&1 \
    && { rm -f "$WORK/runtime.a"; ar rcs "$WORK/runtime.a" "$WORK/runtime.o"; say "  runtime.o compile EXIT=0"; } \
    || { say "  runtime.o compile EXIT=$?"; tail -25 "$WORK/rt.log" | sed 's/^/    /' | tee -a "$RESULT"; exit 4; }
RT="$WORK/runtime.a"
[ -f "$RT" ] || { say "FATAL: runtime.a not built"; exit 4; }
for sym in thread_channel_new thread_channel_send thread_channel_recv thread_channel_close; do
    if nm "$RT" 2>/dev/null | grep -qw "$sym"; then say "  runtime.a DEFINES $sym"; else say "  ⚠ runtime.a missing $sym"; fi
done
# CRITICAL: real pthreads must be linked (U pthread_create), not the no-op shim.
if nm "$RT" 2>/dev/null | grep -qE "U pthread_create"; then say "  runtime.a links REAL pthread (U pthread_create) ✓"; else say "  ⚠ runtime.a has NO real pthread_create (synchronous shim!) — threaded result invalid"; fi

HEXA="$SRC/build/hexat"

# ── compile + run the 2P+2C test via the user-facing hexat → C → clang path ──
run_e2e() { # $1=tag $2=envk
    local tag="$1" envk="$2"
    local uc="$WORK/$tag.user.c" bin="$WORK/$tag.bin"
    ( cd "$SRC"; "$HEXA" "$KERN" "$uc" ) >"$WORK/$tag.emitc.log" 2>&1
    if [ ! -f "$uc" ]; then say "  $tag: hexat transpile produced no user.c"; tail -8 "$WORK/$tag.emitc.log" | sed 's/^/      /' | tee -a "$RESULT"; return 9; fi
    grep -q 'thread_channel_send' "$uc" && say "  $tag: user.c references thread_channel_send (bare-ident carrier)"
    "$CC" -O2 -std=gnu11 -D_GNU_SOURCE -DHEXA_THREADS -I"$SRC/self" "$uc" "$RT" -lm -lpthread -o "$bin" 2>"$WORK/$tag.cc.log" \
        || { say "  $tag: COMPILE/LINK FAIL"; grep -iE 'thread_channel|undeclar|implicit|undefined' "$WORK/$tag.cc.log" | head -6 | sed 's/^/      /' | tee -a "$RESULT"; return 1; }
    ( cd "$WORK"; env $envk timeout 60 "$bin" ) >"$WORK/$tag.out" 2>"$WORK/$tag.err"; local rc=$?
    say "  $tag run rc=$rc:"; sed 's/^/      /' "$WORK/$tag.out" | tee -a "$RESULT"
    [ -s "$WORK/$tag.err" ] && { tail -4 "$WORK/$tag.err" | sed 's/^/      ERR /' | tee -a "$RESULT"; }
    return $rc; }

say "--- ORACLE (no HEXA_THREADS, default-safe arithmetic) ---"
run_e2e oracle ""                ; ORACLE_RC=$?
say "--- 2P+2C (HEXA_THREADS=1, real OS threads + condvar channel) ---"
run_e2e e2e    "HEXA_THREADS=1"  ; E2E_RC=$?

# ── crash-free repeat: race-soak the 2P+2C binary CRASH_RUNS times ───────────
say "--- crash-free soak: $CRASH_RUNS× 2P+2C (expect rc=0 + identical total each) ---"
CRASH_OK=0; CRASH_BAD=0
if [ -x "$WORK/e2e.bin" ]; then
    for i in $(seq 1 "$CRASH_RUNS"); do
        ( cd "$WORK"; env HEXA_THREADS=1 timeout 60 ./e2e.bin ) >"$WORK/soak.$i.out" 2>&1; rc=$?
        if [ "$rc" = 0 ] && grep -q '0 failed' "$WORK/soak.$i.out"; then CRASH_OK=$((CRASH_OK+1)); else CRASH_BAD=$((CRASH_BAD+1)); say "    run#$i rc=$rc FAIL:"; tail -3 "$WORK/soak.$i.out" | sed 's/^/      /' | tee -a "$RESULT"; fi
    done
    say "  crash-free soak: $CRASH_OK/$CRASH_RUNS rc=0 + all-pass  ($CRASH_BAD bad)"
else
    say "  ⚠ no e2e.bin to soak"
fi

# ── G-BYTEEQ: branch changes NO runtime/codegen source → DEFAULT runtime.o is
#    byte-identical to origin/main. Proof = (1) git diff self/+compiler/ empty;
#    (2) DEFAULT (no -DHEXA_THREADS) runtime.o regen'd from each side's emitter
#        + compiled is byte-identical (emitter SSOT unchanged → same .c → same .o).
say "--- G-BYTEEQ (branch vs origin/main) ---"
say "  source diff (self/ + compiler/) — expect EMPTY:"
git -C "$SRC" diff --stat origin/main -- self/ compiler/ 2>/dev/null | sed 's/^/    /' | tee -a "$RESULT"
DIFFN=$(git -C "$SRC" diff --name-only origin/main -- self/ compiler/ 2>/dev/null | wc -l)
say "  → $DIFFN changed source files under self/+compiler/ (0 = byteeq trivially neutral)"
git -C "$CANON" fetch -q origin main 2>>"$WORK/git.log" || true
MSRC="$WORK/main"; git -C "$CANON" worktree add -f --detach "$MSRC" origin/main 2>>"$WORK/git.log" && prep_seeds "$MSRC"
regen_rt() { awk '
  { line=$0; pfx="    buf = buf + \""
    if (substr(line,1,length(pfx))!=pfx) next
    body=substr(line,length(pfx)+1)
    if (substr(body,length(body),1)!="\"") next
    body=substr(body,1,length(body)-1); out=""; n=length(body); i=1
    while(i<=n){ c=substr(body,i,1)
      if(c=="\\"&&i<n){ d=substr(body,i+1,1)
        if(d=="n"){out=out "\n";i+=2;continue}; if(d=="t"){out=out "\t";i+=2;continue}
        if(d=="\""){out=out "\"";i+=2;continue}; if(d=="\\"){out=out "\\";i+=2;continue}
        out=out "\\";i+=1;continue }
      out=out c;i+=1 }
    printf "%s",out }' "$1/self/runtime_emit_full.hexa" > "$1/self/runtime.c"; }
regen_rt "$MSRC"; regen_rt "$SRC"  # both from their (identical) emitter SSOT
bash "$MSRC/tool/regen_runtime_core_c.sh" "$MSRC" >/dev/null 2>&1  # runtime_core.c for MSRC
byteeq_o() { ( cd "$1"; "$CC" -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -c self/runtime.c -I self -o "$2" ) 2>"$2.log"; }
byteeq_o "$SRC"  "$WORK/branch.rt.o"
byteeq_o "$MSRC" "$WORK/main.rt.o"
if [ -f "$WORK/branch.rt.o" ] && [ -f "$WORK/main.rt.o" ]; then
    if cmp -s "$WORK/branch.rt.o" "$WORK/main.rt.o"; then
        say "  G-BYTEEQ OK: DEFAULT runtime.o (emitter-regen'd) BYTE-IDENTICAL branch vs origin/main (x86_64-linux)"
    else
        say "  ⚠ G-BYTEEQ DIFFER (unexpected):"; cmp "$WORK/branch.rt.o" "$WORK/main.rt.o" | sed 's/^/    /' | tee -a "$RESULT"
    fi
else
    say "  G-BYTEEQ: missing .o"; tail -5 "$WORK/branch.rt.o.log" 2>/dev/null | sed 's/^/    /' | tee -a "$RESULT"
fi
git -C "$CANON" worktree remove --force "$MSRC" 2>/dev/null || true

say "=== RESULT branch=$BR  oracle=$ORACLE_RC  2P+2C=$E2E_RC  soak=$CRASH_OK/$CRASH_RUNS ==="
say "=== DONE — artifacts under $WORK ==="
