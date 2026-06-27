#!/usr/bin/env bash
# tool/measure_escape_relax.sh — FLEET lane A2: codegen escape-relax measure.
#
# Builds the native aprime_cc compiler WITH the escape-relax codegen
# (HEXA_PACK_ESCAPING), a runtime.a carrying the A-half poly readers
# (-DHEXA_PACK_ESCAPING → hexa_arr_i64_new_esc + hexa_arr_poly_get/_set/_len/_push),
# compiles the hexa-source escaping-worker-buffer test (test/escaping_packed_
# worker_buf.hexa) with the flag OFF (control = boxed) and ON (treatment =
# esc-mint + poly-route), runs both, and reports PASS/FAIL.
#
# GATES:
#   G-RUN  : hexa-source escaping buffer SURVIVES + checksum parity.
#            OFF (boxed)  : all checks PASS (boxed mint + boxed read coherent).
#            ON  (packed) : all checks PASS, SAME checksum (a·c production close).
#            A miscompile (poly-route miss) → checksum divergence/crash → WALL.
#   G-BYTEEQ : aprime flag-OFF emit (.o) of the test == origin/main aprime emit
#              (.o) → codegen byte-identical when HEXA_PACK_ESCAPING unset.
#   G-LEVER  : asm OFF vs ON differs (lever LIVE) + esc symbols appear ON only.
#
# Run on aiden (mini cannot build). Single-SSH, isolated $HOME scratch.
#   bash tool/measure_escape_relax.sh
# Env: BR (branch, default feat/codegen-escape-relax) · CANON (default
#      $HOME/hexa-lang) · WORK · RESULT.
set -u

BR="${BR:-feat/codegen-escape-relax}"
CANON="${CANON:-$HOME/hexa-lang}"
SLUG="$(echo "$BR" | tr '/ ' '__')"
WORK="${WORK:-$HOME/escape_relax_${SLUG}}"
RESULT="${RESULT:-$HOME/escape_relax_${SLUG}_RESULT.txt}"
CC="${CC:-clang}"
TGT="x86_64-linux-gnu"
CFLAGS_ESC="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -DHEXA_PACK_ESCAPING"
TEST_HEXA="test/escaping_packed_worker_buf.hexa"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== escape-relax measure — branch=$BR — $(date -u +%FT%TZ) — $(hostname) ==="
say "    target=$TGT  CANON=$CANON  WORK=$WORK"

# no-starve courtesy
for w in $(seq 1 60); do
    L=$(awk '{print $1}' /proc/loadavg 2>/dev/null); Li=${L%.*}
    [ "${Li:-99}" -lt 6 ] && { say "  load=$L OK"; break; }
    [ "$w" = 60 ] && say "  load high (last=$L) — proceeding"; sleep 30
done

rm -rf "$WORK"; mkdir -p "$WORK"
cd "$CANON" || { say "FATAL no canon $CANON"; exit 3; }

# ── materialise patched branch worktree ─────────────────────────────────────
git -C "$CANON" worktree prune 2>>"$WORK/git.log" || true
git -C "$CANON" fetch -f origin "$BR:refs/remotes/origin/$BR" 2>>"$WORK/git.log" || say "  (fetch BR warn)"
git -C "$CANON" worktree add -f --detach "$WORK/src" "origin/$BR" 2>>"$WORK/git.log" \
    || git -C "$CANON" worktree add -f --detach "$WORK/src" "$BR" 2>>"$WORK/git.log" \
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

# ── build patched aprime_cc (single build, OOM-safe) ────────────────────────
say "--- building patched aprime_cc ---"
( cd "$SRC"; setsid bash tool/build_aprime.sh -o "$WORK/aprime_cc" -r "$SRC" ) >"$WORK/aprime.log" 2>&1 \
    && say "  aprime build EXIT=0" || { say "  aprime build EXIT=$?"; tail -30 "$WORK/aprime.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"
[ -x "$AP" ] || { say "FATAL: aprime_cc not built"; exit 4; }

# ── build runtime.a WITH -DHEXA_PACK_ESCAPING (poly readers present) ─────────
say "--- building runtime.a (-DHEXA_PACK_ESCAPING — poly readers) ---"
( cd "$SRC"
  env -u HEXA_CUDA CC="$CC" LIBS="${LIBS:--lm}" CFLAGS_COMMON="$CFLAGS_ESC" \
      bash tool/stage_resolve_runtime_a ) >"$WORK/rt.log" 2>&1 \
    && say "  runtime.a EXIT=0" || { say "  runtime.a EXIT=$?"; tail -25 "$WORK/rt.log" | sed 's/^/    /' | tee -a "$RESULT"; }
RT="$SRC/build/runtime.a"
[ -f "$RT" ] || { say "FATAL: runtime.a not built"; exit 4; }
say "  runtime.a poly-reader members: $(ar t "$RT" 2>/dev/null | tr '\n' ' ' | head -c 1)"
# verify the esc symbols are actually in the archive
for sym in hexa_arr_i64_new_esc hexa_arr_poly_get hexa_arr_poly_set hexa_arr_poly_len hexa_arr_poly_push; do
    if nm "$RT" 2>/dev/null | grep -qw "$sym"; then say "  runtime.a HAS $sym"; else say "  ⚠ runtime.a MISSING $sym (T symbol)"; fi
done

# ── emit OFF / ON (the ONE patched aprime) ──────────────────────────────────
KERN="$SRC/$TEST_HEXA"
[ -f "$KERN" ] || { say "FATAL: test missing $KERN"; exit 4; }
emit_one() { # $1=flag(0/1) $2=outbase
    local f="$1" out="$2"
    ( cd "$SRC"
      if [ "$f" = 1 ]; then export HEXA_PACK_ESCAPING=1; else unset HEXA_PACK_ESCAPING; fi
      "$AP" _drv.hexa --emit=asm --target="$TGT" -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      "$AP" _drv.hexa --emit=obj --target="$TGT" -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" ); }
say "--- emit OFF / ON ---"
emit_one 0 "$WORK/off"
emit_one 1 "$WORK/on"
[ -f "$WORK/off.o" ] || { say "FATAL: OFF emit produced no .o"; tail -15 "$WORK/off.o.log" | sed 's/^/    /' | tee -a "$RESULT"; exit 5; }
[ -f "$WORK/on.o" ]  || { say "FATAL: ON emit produced no .o";  tail -15 "$WORK/on.o.log"  | sed 's/^/    /' | tee -a "$RESULT"; exit 5; }

# ── G-LEVER: asm OFF vs ON + esc symbols ────────────────────────────────────
say "--- G-LEVER (asm OFF vs ON, esc-symbol presence) ---"
for tag in off on; do
    s="$WORK/$tag.s"
    [ -f "$s" ] || { say "  $tag: no .s"; continue; }
    ng=$(grep -c 'hexa_arr_i64_new_esc' "$s" 2>/dev/null)
    pg=$(grep -c 'hexa_arr_poly_get' "$s" 2>/dev/null)
    ps=$(grep -c 'hexa_arr_poly_set' "$s" 2>/dev/null)
    pl=$(grep -c 'hexa_arr_poly_len' "$s" 2>/dev/null)
    pp=$(grep -c 'hexa_arr_poly_push' "$s" 2>/dev/null)
    say "  $tag: new_esc=$ng poly_get=$pg poly_set=$ps poly_len=$pl poly_push=$pp"
done
if cmp -s "$WORK/off.s" "$WORK/on.s"; then say "  ⚠ asm OFF==ON byte-identical — lever did NOT fire"; else say "  asm OFF!=ON (lever LIVE)"; fi

# ── G-RUN: link + run OFF / ON ──────────────────────────────────────────────
say "--- G-RUN (link + run; single-thread escape path) ---"
run_one() { # $1=tag $2=extra-env
    local tag="$1" envk="$2" o="$WORK/$tag.o" b="$WORK/$tag.bin"
    gcc -O2 "$o" "$RT" -lm -lpthread -o "$b" 2>"$b.ld.log" || { say "  $tag: LINK FAIL"; tail -8 "$b.ld.log" | sed 's/^/      /' | tee -a "$RESULT"; return 1; }
    ( cd "$WORK"; env $envk "$b" ) >"$WORK/$tag.out" 2>"$WORK/$tag.err"; local rc=$?
    say "  $tag run rc=$rc:"; tail -8 "$WORK/$tag.out" | sed 's/^/      /' | tee -a "$RESULT"
    [ -s "$WORK/$tag.err" ] && { say "  $tag stderr:"; tail -4 "$WORK/$tag.err" | sed 's/^/      /' | tee -a "$RESULT"; }
    return $rc; }
run_one off ""                      ; OFF_RC=$?
run_one on  "HEXA_PACK_ESCAPING=1"  ; ON_RC=$?
say "  OFF rc=$OFF_RC  ON rc=$ON_RC  (0 = all checks PASS)"
# parity of the printed total line
OFF_TOT=$(grep -o 'total = [0-9-]*' "$WORK/off.out" 2>/dev/null | head -1)
ON_TOT=$(grep -o 'total = [0-9-]*'  "$WORK/on.out"  2>/dev/null | head -1)
say "  OFF $OFF_TOT  |  ON $ON_TOT  (must match — value parity)"

# ── G-RUN threaded 4P+4C (escaping buffer across spawn boundary) ────────────
say "--- G-RUN 4P+4C (real OS threads, escaping packed buffer) ---"
emit_thr() { # build a -DHEXA_THREADS variant? threads use runtime thread.c already in runtime.a if seeded.
    :; }
run_one off_thr "HEXA_THREADS=1"                      ; OFF_THR_RC=$?  # reuse off.bin? no, same bin
# threads need HEXA_THREADS=1 at RUN (the test gates on it); the binary is the same.
( cd "$WORK"; env HEXA_THREADS=1 "$WORK/off.bin" ) >"$WORK/off_thr.out" 2>"$WORK/off_thr.err"; OFF_THR_RC=$?
( cd "$WORK"; env HEXA_THREADS=1 HEXA_PACK_ESCAPING=1 "$WORK/on.bin" ) >"$WORK/on_thr.out" 2>"$WORK/on_thr.err"; ON_THR_RC=$?
say "  OFF(threads) rc=$OFF_THR_RC:"; tail -6 "$WORK/off_thr.out" | sed 's/^/      /' | tee -a "$RESULT"
say "  ON(threads)  rc=$ON_THR_RC:";  tail -6 "$WORK/on_thr.out"  | sed 's/^/      /' | tee -a "$RESULT"

# ── G-BYTEEQ: flag-OFF emit == origin/main aprime emit ──────────────────────
say "--- G-BYTEEQ (flag-OFF .o == origin/main aprime .o; codegen byte-identical) ---"
git -C "$CANON" worktree add -f --detach "$WORK/base" origin/main 2>>"$WORK/git.log" \
    || git -C "$CANON" worktree add -f --detach "$WORK/base" main 2>>"$WORK/git.log" \
    || say "  (base worktree warn)"
BASE="$WORK/base"
if [ -d "$BASE" ]; then
    prep_seeds "$BASE"
    # copy the NEW test file into base (it does not exist on origin/main) so the
    # baseline aprime can emit the SAME source — the test is byteeq-neutral input.
    mkdir -p "$BASE/test"; cp "$KERN" "$BASE/$TEST_HEXA"
    ( cd "$BASE"; setsid bash tool/build_aprime.sh -o "$WORK/aprime_base" -r "$BASE" ) >"$WORK/aprime_base.log" 2>&1 \
        && say "  base aprime EXIT=0" || { say "  base aprime EXIT=$?"; tail -20 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }
    APB="$WORK/aprime_base"
    if [ -x "$APB" ]; then
        ( cd "$BASE"; unset HEXA_PACK_ESCAPING; "$APB" _drv.hexa --emit=obj --target="$TGT" -o "$WORK/base.o" "$BASE/$TEST_HEXA" >"$WORK/base.o.log" 2>&1 )
        if [ -f "$WORK/base.o" ] && [ -f "$WORK/off.o" ]; then
            if cmp -s "$WORK/base.o" "$WORK/off.o"; then
                say "  G-BYTEEQ OK: patched flag-OFF .o BYTE-IDENTICAL to origin/main (x86_64-linux)"
            else
                say "  G-BYTEEQ DIFFER — .text diff head:"
                objdump -d "$WORK/base.o" >"$WORK/b.s" 2>/dev/null; objdump -d "$WORK/off.o" >"$WORK/o.s" 2>/dev/null
                diff "$WORK/b.s" "$WORK/o.s" | head -30 | sed 's/^/    /' | tee -a "$RESULT"
            fi
        else say "  G-BYTEEQ: missing .o (base=$([ -f "$WORK/base.o" ]&&echo y||echo n) off=$([ -f "$WORK/off.o" ]&&echo y||echo n))"; fi
    else say "  G-BYTEEQ: base aprime not built — byteeq delegated to CI 3-target"; fi
else say "  G-BYTEEQ: no base worktree — delegated to CI"; fi

say "=== RESULT branch=$BR  G-RUN(off=$OFF_RC on=$ON_RC thr_off=$OFF_THR_RC thr_on=$ON_THR_RC)  ==="
say "=== DONE — artifacts under $WORK ==="
