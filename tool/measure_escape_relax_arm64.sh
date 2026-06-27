#!/usr/bin/env bash
# tool/measure_escape_relax_arm64.sh — FLEET arm64 element-pack: codegen
# escape-relax measure for the ARM64 backend (compiler/codegen/arm64_darwin.hexa).
#
# Sibling of tool/measure_escape_relax.sh (x86_64). The arm64 backend never had a
# per-local type lattice, so escape-relax (the x86_64-only #4133 fix shipped
# #4140/#4143/#4151) was a no-op on arm64 — an escaping typed-prim [i64] stayed
# boxed. This branch adds the SAME esc-mint + poly-route lattice + the 5 emit
# boundaries (array_lit mint · index · index_set · push · len) in AAPCS64. The
# runtime half (TAG_ARRAY_I64 + hexa_arr_poly_*, #4140) is platform-agnostic C, so
# the SAME runtime.a (compiled -DHEXA_PACK_ESCAPING) serves both backends.
#
# This script emits arm64-linux-gnu objects with the patched aprime_cc and runs
# them under qemu-aarch64 (aiden is x86_64). It mirrors the x86 GATES:
#   G-RUN    : hexa-source escaping buffer SURVIVES + checksum parity (OFF==ON).
#   G-BYTEEQ : aprime flag-OFF arm64 emit (.o) == origin/main aprime arm64 emit.
#   G-LEVER  : asm OFF vs ON differs (lever LIVE) + esc symbols appear ON only.
#
# Run on aiden (mini cannot build). Single-SSH, isolated $HOME scratch.
#   bash tool/measure_escape_relax_arm64.sh
# Env: BR (branch) · CANON (default $HOME/hexa-lang) · WORK · RESULT.
set -u

BR="${BR:-fleet/arm64-element-pack}"
CANON="${CANON:-$HOME/hexa-lang}"
SLUG="$(echo "$BR" | tr '/ ' '__')"
WORK="${WORK:-$HOME/escape_relax_arm64_${SLUG}}"
RESULT="${RESULT:-$HOME/escape_relax_arm64_${SLUG}_RESULT.txt}"
# aarch64 cross toolchain + emulator (Debian/Ubuntu: gcc-aarch64-linux-gnu
# qemu-user). CC builds the runtime.a (cross), CCX links the arm64 objects.
CCX="${CCX:-aarch64-linux-gnu-gcc}"
QEMU="${QEMU:-qemu-aarch64-static}"
QEMU_LD="${QEMU_LD:-/usr/aarch64-linux-gnu}"
TGT="arm64-linux-gnu"
CFLAGS_ESC="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -DHEXA_PACK_ESCAPING"
TEST_HEXA="test/escaping_packed_worker_buf.hexa"
say() { echo "$@" | tee -a "$RESULT"; }

: > "$RESULT"
say "=== arm64 escape-relax measure — branch=$BR — $(date -u +%FT%TZ) — $(hostname) ==="
say "    target=$TGT  CANON=$CANON  WORK=$WORK  CCX=$CCX  QEMU=$QEMU"

command -v "$CCX"  >/dev/null 2>&1 || say "  ⚠ $CCX not found — install gcc-aarch64-linux-gnu"
command -v "$QEMU" >/dev/null 2>&1 || say "  ⚠ $QEMU not found — install qemu-user (qemu-user-static)"

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

# ── build patched aprime_cc (x86_64 host compiler that emits arm64) ──────────
say "--- building patched aprime_cc (host) ---"
( cd "$SRC"; setsid bash tool/build_aprime.sh -o "$WORK/aprime_cc" -r "$SRC" ) >"$WORK/aprime.log" 2>&1 \
    && say "  aprime build EXIT=0" || { say "  aprime build EXIT=$?"; tail -30 "$WORK/aprime.log" | sed 's/^/    /' | tee -a "$RESULT"; }
AP="$WORK/aprime_cc"
[ -x "$AP" ] || { say "FATAL: aprime_cc not built"; exit 4; }

# ── build aarch64 runtime.a WITH -DHEXA_PACK_ESCAPING (poly readers) ─────────
say "--- building aarch64 runtime.a (-DHEXA_PACK_ESCAPING — poly readers) ---"
( cd "$SRC"
  env -u HEXA_CUDA CC="$CCX" LIBS="${LIBS:--lm}" CFLAGS_COMMON="$CFLAGS_ESC" \
      bash tool/stage_resolve_runtime_a ) >"$WORK/rt.log" 2>&1 \
    && say "  runtime.a EXIT=0" || { say "  runtime.a EXIT=$?"; tail -25 "$WORK/rt.log" | sed 's/^/    /' | tee -a "$RESULT"; }
RT="$SRC/build/runtime.a"
[ -f "$RT" ] || { say "FATAL: runtime.a not built"; exit 4; }
for sym in hexa_arr_i64_new_esc hexa_arr_poly_get hexa_arr_poly_set hexa_arr_poly_len hexa_arr_poly_push; do
    if "${CCX%-gcc}-nm" "$RT" 2>/dev/null | grep -qw "$sym" || nm "$RT" 2>/dev/null | grep -qw "$sym"; then
        say "  runtime.a HAS $sym"; else say "  ⚠ runtime.a MISSING $sym"; fi
done

# ── emit OFF / ON (the ONE patched aprime, arm64-linux target) ──────────────
KERN="$SRC/$TEST_HEXA"
[ -f "$KERN" ] || { say "FATAL: test missing $KERN"; exit 4; }
emit_one() { # $1=flag(0/1) $2=outbase
    local f="$1" out="$2"
    ( cd "$SRC"
      if [ "$f" = 1 ]; then export HEXA_PACK_ESCAPING=1; else unset HEXA_PACK_ESCAPING; fi
      "$AP" _drv.hexa --emit=asm --target="$TGT" -o "$out.s" "$KERN" >"$out.s.log" 2>&1 || echo "emit asm rc=$? f=$f"
      "$AP" _drv.hexa --emit=obj --target="$TGT" -o "$out.o" "$KERN" >"$out.o.log" 2>&1 || echo "emit obj rc=$? f=$f" ); }
say "--- emit OFF / ON (arm64-linux) ---"
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

# ── G-RUN: link (aarch64 cross) + run (qemu-aarch64) OFF / ON ───────────────
say "--- G-RUN (cross-link + qemu run; single-thread escape path) ---"
run_one() { # $1=tag $2=extra-env
    local tag="$1" envk="$2" o="$WORK/$tag.o" b="$WORK/$tag.bin"
    "$CCX" -O2 "$o" "$RT" -lm -lpthread -static -o "$b" 2>"$b.ld.log" \
      || "$CCX" -O2 "$o" "$RT" -lm -lpthread -o "$b" 2>>"$b.ld.log" \
      || { say "  $tag: LINK FAIL"; tail -8 "$b.ld.log" | sed 's/^/      /' | tee -a "$RESULT"; return 1; }
    ( cd "$WORK"; env $envk "$QEMU" -L "$QEMU_LD" "$b" ) >"$WORK/$tag.out" 2>"$WORK/$tag.err"; local rc=$?
    say "  $tag run rc=$rc:"; tail -8 "$WORK/$tag.out" | sed 's/^/      /' | tee -a "$RESULT"
    [ -s "$WORK/$tag.err" ] && { say "  $tag stderr:"; tail -4 "$WORK/$tag.err" | sed 's/^/      /' | tee -a "$RESULT"; }
    return $rc; }
run_one off ""                      ; OFF_RC=$?
run_one on  "HEXA_PACK_ESCAPING=1"  ; ON_RC=$?
say "  OFF rc=$OFF_RC  ON rc=$ON_RC  (0 = all checks PASS)"
OFF_TOT=$(grep -o 'total = [0-9-]*' "$WORK/off.out" 2>/dev/null | head -1)
ON_TOT=$(grep -o 'total = [0-9-]*'  "$WORK/on.out"  2>/dev/null | head -1)
say "  OFF $OFF_TOT  |  ON $ON_TOT  (must match — value parity)"

# ── G-BYTEEQ: flag-OFF arm64 emit == origin/main aprime arm64 emit ──────────
say "--- G-BYTEEQ (flag-OFF arm64 .o == origin/main aprime arm64 .o) ---"
git -C "$CANON" worktree add -f --detach "$WORK/base" origin/main 2>>"$WORK/git.log" \
    || git -C "$CANON" worktree add -f --detach "$WORK/base" main 2>>"$WORK/git.log" \
    || say "  (base worktree warn)"
BASE="$WORK/base"
if [ -d "$BASE" ]; then
    prep_seeds "$BASE"
    mkdir -p "$BASE/test"; cp "$KERN" "$BASE/$TEST_HEXA"
    ( cd "$BASE"; setsid bash tool/build_aprime.sh -o "$WORK/aprime_base" -r "$BASE" ) >"$WORK/aprime_base.log" 2>&1 \
        && say "  base aprime EXIT=0" || { say "  base aprime EXIT=$?"; tail -20 "$WORK/aprime_base.log" | sed 's/^/    /' | tee -a "$RESULT"; }
    APB="$WORK/aprime_base"
    if [ -x "$APB" ]; then
        ( cd "$BASE"; unset HEXA_PACK_ESCAPING; "$APB" _drv.hexa --emit=obj --target="$TGT" -o "$WORK/base.o" "$BASE/$TEST_HEXA" >"$WORK/base.o.log" 2>&1 )
        if [ -f "$WORK/base.o" ] && [ -f "$WORK/off.o" ]; then
            if cmp -s "$WORK/base.o" "$WORK/off.o"; then
                say "  G-BYTEEQ OK: patched flag-OFF .o BYTE-IDENTICAL to origin/main (arm64-linux)"
            else
                say "  G-BYTEEQ DIFFER — .text diff head:"
                "${CCX%-gcc}-objdump" -d "$WORK/base.o" >"$WORK/b.s" 2>/dev/null || objdump -d "$WORK/base.o" >"$WORK/b.s" 2>/dev/null
                "${CCX%-gcc}-objdump" -d "$WORK/off.o"  >"$WORK/o.s" 2>/dev/null || objdump -d "$WORK/off.o"  >"$WORK/o.s" 2>/dev/null
                diff "$WORK/b.s" "$WORK/o.s" | head -30 | sed 's/^/    /' | tee -a "$RESULT"
            fi
        else say "  G-BYTEEQ: missing .o"; fi
    else say "  G-BYTEEQ: base aprime not built — byteeq delegated to CI 3-target"; fi
else say "  G-BYTEEQ: no base worktree — delegated to CI"; fi

say "=== RESULT branch=$BR  G-RUN(off=$OFF_RC on=$ON_RC)  ==="
say "=== DONE — artifacts under $WORK ==="
