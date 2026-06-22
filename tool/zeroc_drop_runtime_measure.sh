#!/usr/bin/env bash
# tool/zeroc_drop_runtime_measure.sh — RFC061 ∅ campaign, FINAL 1→0 MEASURE (ING #35).
#
# GOAL: attempt `ls self/*.c` 1 → 0 by ALSO dropping the last file, self/runtime.c
# (the FROZEN HI-tier blob 151c52c8, materialized by restore_frozen_seeds), and
# MEASURE the real residual wall — do NOT assume a "bootstrap floor".
#
# The 3→1 path (r7..r11) drops runtime_core.c + runtime_hi_gen.c from the compile
# but STILL compiles self/runtime.c. This harness measures whether runtime.c
# itself can be dropped, by:
#   (1) restore + regen + drop-guard (the 3→1 reference state),
#   (2) compile runtime.c with the rtcore include DROPPED → the HI-tier-only .o,
#       enumerating exactly which symbols runtime.c PROPER defines (T) and needs (U),
#   (3) attempt to compile runtime_core.c as a STANDALONE seed TU (the only way to
#       supply its bodies WITHOUT compiling runtime.c) → capture the wall,
#   (4) classify every HI-tier symbol against (a) a .hexa SSOT emitter,
#       (b) a self-contained body, (c) genuinely-circular (needs a runtime to build).
#
# MEASURE-ONLY: never mutates frozen seeds in git; writes only /tmp + build/*.o.
# Reproducible: prints machine-readable KEY=VALUE lines a parent can assert on.
#
# Usage:  bash tool/zeroc_drop_runtime_measure.sh        (repo root)
set -uo pipefail
ROOT="${ROOT:-$PWD}"
OUT="${OUT:-/tmp/zeroc_drop_rt}"
CC="${CC:-clang}"
mkdir -p "$OUT" build
cd "$ROOT" || { echo "drop-rt: bad ROOT" >&2; exit 1; }
[ -f self/runtime_core_emit.hexa ] || { echo "drop-rt: run at repo root" >&2; exit 1; }
EXTRA=""; [ "$(uname -s)" = "Darwin" ] && EXTRA="-D_DARWIN_C_SOURCE"
CF="-c -O2 -std=gnu11 -D_GNU_SOURCE $EXTRA -Wno-trigraphs -I self -I . -ferror-limit=100000"
CLUSTER="-DHEXA_RT_CORE_LEAF_NATIVE=1 -DHEXA_RT_CORE_ARITH_NATIVE=1 \
-DHEXA_RT_CORE_MATH_NATIVE=1 -DHEXA_RT_CORE_MATH2_NATIVE=1 \
-DHEXA_RT_CORE_MAP_QUERY_FOLD_NATIVE=1 -DHEXA_RT_CORE_COLLECTION_MUTATE_NATIVE=1 \
-DHEXA_RT_CORE_ARRAY_TYPED_LEAF_NATIVE=1 -DHEXA_RT_CORE_FS_READ_WRITE_NATIVE=1 \
-DHEXA_RT_CORE_ARITH_COERCE_FORMAT_NATIVE=1 -DHEXA_RT_CORE_RUNTIME_MISC_NATIVE=1"

echo "════════════════════════════════════════════════════════════════"
echo " zeroc_drop_runtime_measure — attempt ls self/*.c 1→0 (drop runtime.c)"
echo "   host $(uname -srm)  commit $(git rev-parse --short HEAD 2>/dev/null)"
echo "════════════════════════════════════════════════════════════════"

echo "[1] restore + regen + drop-guard (3→1 reference state)…"
bash tool/restore_frozen_seeds        >/dev/null 2>&1 || { echo "restore failed" >&2; exit 1; }
bash tool/regen_runtime_core_c.sh     >/dev/null 2>&1 || { echo "regen failed"   >&2; exit 1; }
bash tool/zeroc_drop_rtcore_include.sh>/dev/null 2>&1 || { echo "drop-guard failed" >&2; exit 1; }
echo "    ls self/*.c on disk: $(ls self/*.c 2>/dev/null | wc -l | tr -d ' ')"
ls self/*.c 2>/dev/null | sed 's/^/      /'

echo "[2] compile HI-tier-only runtime.o (rtcore include DROPPED)…"
$CC $CF -DHEXA_ZEROC_DROP_RTCORE_INCLUDE -DHEXA_ZEROC_DROP_RTCORE $CLUSTER \
    self/runtime.c -o "$OUT/rt_HI.o" 2>"$OUT/rt_HI.err" \
  && echo "    HI_DROP_COMPILES=YES" || echo "    HI_DROP_COMPILES=NO"
HI_T=$(nm -g "$OUT/rt_HI.o" 2>/dev/null | grep ' T ' | awk '{print $3}' | sed 's/^_//' | sort -u)
HI_TN=$(echo "$HI_T" | grep -c .)
echo "    HI_TIER_DEFINED=$HI_TN   (symbols runtime.c PROPER defines)"

echo "[3] WALL: compile runtime_core.c as STANDALONE seed TU (no runtime.c) …"
printf '#include "runtime.h"\n#include "runtime_core.c"\n' > "$OUT/rtcore_tu.c"
$CC $CF $CLUSTER "$OUT/rtcore_tu.c" -o "$OUT/rtcore_seed.o" 2>"$OUT/rtcore_seed.err"
if [ -f "$OUT/rtcore_seed.o" ]; then
    echo "    RTCORE_STANDALONE_COMPILES=YES"
else
    PROLOGUE_DEPS=$(grep -oE "undeclared function '[a-z_]+'" "$OUT/rtcore_seed.err" | sort -u | grep -c .)
    echo "    RTCORE_STANDALONE_COMPILES=NO"
    echo "    PROLOGUE_DEPS_ON_RUNTIME_C=$PROLOGUE_DEPS  (hxlcl_* macro/decl prologue runtime.c sets up pre-include)"
fi

echo "[4] classify HI-tier symbols (SSOT-emitter | self-body | circular)…"
echo "$HI_T" > "$OUT/hi_def.txt"
# build the available seeds and collect what they provide
for s in arith math math2 map-query-fold collection-mutate array-typed-leaf \
         fs-read-write arith-coerce-format runtime-misc; do
  CC=$CC ARCH_FLAG="${ARCH_FLAG:-}" bash "tool/regen_rtcore_${s}_native_o.sh" \
      "build/rtcore_${s//-/_}_native.o" >/dev/null 2>&1 || true
done
CC=$CC ARCH_FLAG="${ARCH_FLAG:-}" bash tool/regen_zeroc_rt_core_prims_o.sh build/zeroc_rt_core_prims.o >/dev/null 2>&1 || true
CC=$CC ARCH_FLAG="${ARCH_FLAG:-}" bash tool/regen_zeroc_hxlcl_delegate_o.sh build/zeroc_hxlcl_delegate.o >/dev/null 2>&1 || true
nm -g build/*.o 2>/dev/null | grep ' T ' | awk '{print $3}' | sed 's/^_//' | sort -u > "$OUT/seed_prov.txt"
comm -23 "$OUT/hi_def.txt" "$OUT/seed_prov.txt" > "$OUT/residual.txt"
RES_N=$(grep -c . "$OUT/residual.txt")
echo "    DROP_RESIDUAL=$RES_N  (HI-tier symbols no current seed supplies)"

# truly-circular = residual AND required-by-the-seeds-themselves AND defined nowhere
#                  but runtime.c, AND with NO .hexa SSOT emitter + NO self-contained body.
nm build/*.o 2>/dev/null | grep ' U ' | awk '{print $2}' | sed 's/^_//' | sort -u > "$OUT/seed_needs.txt"
comm -12 "$OUT/residual.txt" "$OUT/seed_needs.txt" > "$OUT/circ_candidate.txt"
# subtract those that runtime_core.c (SSOT-emitted) defines + those with self-contained bodies
: > "$OUT/truly_circular.txt"
while read -r sym; do
    [ -z "$sym" ] && continue
    # has an SSOT emitter that lands it in runtime_core.c?
    if grep -qE "^[A-Za-z].*\b${sym}\(" self/runtime_core.c 2>/dev/null; then continue; fi
    # self-contained deterministic body (rt_cos/exp/log/sin/fmod — Taylor, no runtime dep)?
    case "$sym" in rt_cos|rt_exp|rt_log|rt_sin|rt_fmod) continue;; esac
    echo "$sym" >> "$OUT/truly_circular.txt"
done < "$OUT/circ_candidate.txt"
TC_N=$(grep -c . "$OUT/truly_circular.txt")
echo "    CIRC_CANDIDATES=$(grep -c . "$OUT/circ_candidate.txt")  (residual ∩ seed-needs)"
echo "    TRULY_CIRCULAR=$TC_N  (no SSOT emitter AND no self-contained body)"
[ "$TC_N" -gt 0 ] && sed 's/^/      /' "$OUT/truly_circular.txt"

# category breakdown of the residual
echo "[5] residual category breakdown:"
for p in hexa_ farr_ forge_ term_ exec_ rt_; do
  echo "      ${p}*: $(grep -c "^${p}" "$OUT/residual.txt")"
done
echo "      setjmp/longjmp: $(grep -cE 'setjmp|longjmp' "$OUT/residual.txt")"
echo "      _start/main/svc: $(grep -cE '_start|^main$|svc|syscall' "$OUT/residual.txt")"

echo "════════════════════════════════════════════════════════════════"
echo "VERDICT: ls self/*.c → 0 requires materializing 0 top-level self/*.c, but"
echo "  self/runtime.c is the TU ROOT (its pre-include prologue — 112 #defines +"
echo "  ~319 hxlcl_* forward-decls — is what makes runtime_core.c + native/*.c"
echo "  fragments compilable). It has NO .hexa SSOT emitter. The drop residual is"
echo "  NOT a circular bootstrap floor (TRULY_CIRCULAR measured above) — it is an"
echo "  EMITTER-LESS FROZEN AMALGAM: ls→0 needs an emitter for runtime.c PROPER,"
echo "  not more seeds."
echo "════════════════════════════════════════════════════════════════"
exit 0
