set -uo pipefail
cd ~/hexa-lang || exit 1
echo "=== sh-array-write ARENA byte-eq A/B (native bridge vs C body) ==="
git rev-parse --short HEAD

# [0] Regenerate the x86_64 array_core seed from the branch SSOT so it carries
# the new rt_array_arena_alloc_items_native symbol (the committed seed predates
# this lane). Requires the native compiler at build/aprime_cc.
echo "=== [0] regen x86_64 array_core seed ==="
APRIME=build/aprime_cc bash tool/regen_array_core_native_s.sh x86_64 2>&1 | tail -6
echo "ARENA-GLOBL=$(grep -cE '\.globl[[:space:]]+_?rt_array_arena_alloc_items_native' self/native/array_core_x86_64.s) ARENA-CALL=$(grep -cE 'call[[:space:]]+_?hexa_arena_alloc' self/native/array_core_x86_64.s) TOTAL-RT-GLOBL=$(grep -cE '^\.globl[[:space:]]+_?rt_array_' self/native/array_core_x86_64.s)"
if [ "$(grep -cE '\.globl[[:space:]]+_?rt_array_arena_alloc_items_native' self/native/array_core_x86_64.s)" != "1" ]; then
    echo "WALL: regenerated seed does NOT export rt_array_arena_alloc_items_native — alloc-bearing prim did not lower to a native seed"
    exit 2
fi

# Ensure runtime_core.c is regenerated from the (branch) emitter SSOT so the
# #ifdef HEXA_RT_ARRAY_ARENA_NATIVE arm + the array seed wiring are present.
CC="${CC:-clang}" bash tool/stage_resolve_runtime_a >/tmp/srra.log 2>&1 || { echo "stage_resolve FAIL"; tail -20 /tmp/srra.log; exit 1; }
grep -nE "HEXA_RT_ARRAY_ARENA_NATIVE=1|RT-NATIVE ARRAY-R4|ALLOC-RB" /tmp/srra.log | tail
[ -f build/array_core_native.o ] || { echo "MISSING array_core_native.o"; exit 1; }
[ -f build/alloc_syscall_native.o ] || { echo "MISSING alloc_syscall_native.o"; exit 1; }
# Confirm the regenerated seed carries the new arena bridge symbol.
echo "--- seed arena bridge symbol ---"
nm build/array_core_native.o 2>/dev/null | grep -E "rt_array_arena_alloc_items_native|hexa_arena_alloc" | head

CC="${CC:-clang}"
CFLAGS="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self"
# Link EVERY native seed the stage produced (array + alloc are the lane under
# test; map/intern/fs/rt_hi are co-resident in this runtime_core.c and their
# native delegations are wired the same in both A and B builds, so they cancel
# out of the byte-eq — the ONLY config delta between the two builds is the
# HEXA_RT_ARRAY_ARENA_NATIVE define). Mirrors the real stage_resolve link set.
# Link the array + alloc seeds (lane under test) PLUS map/intern/fs seeds, which
# are co-resident in this runtime_core.c TU (their native delegations are wired
# identically in both A and B builds — only HEXA_RT_ARRAY_ARENA_NATIVE differs —
# so they cancel out of the byte-eq). rt_hi is EXCLUDED: its native path needs a
# separate `#include "runtime_hi_gen.c"` sed in the TU (HEXA_ZEROC_RT_HI), out of
# scope for this gate; without the define runtime.c keeps its C rt_str bodies.
SEEDS="$(ls build/array_core_native.o build/alloc_syscall_native.o build/map_core_native.o build/intern_core_native.o build/fs_core_native.o 2>/dev/null | tr '\n' ' ')"
NATIVE_DEFS="-DHEXA_RT_ALLOC_NATIVE=1 -DHEXA_RT_ARRAY_NATIVE=1"
[ -f build/map_core_native.o ]    && NATIVE_DEFS="$NATIVE_DEFS -DHEXA_RT_MAP_NATIVE=1"
[ -f build/intern_core_native.o ] && NATIVE_DEFS="$NATIVE_DEFS -DHEXA_RT_INTERN_NATIVE=1"
[ -f build/fs_core_native.o ]     && NATIVE_DEFS="$NATIVE_DEFS -DHEXA_RT_FS_NATIVE=1"
echo "NATIVE_DEFS=$NATIVE_DEFS"
echo "SEEDS=$SEEDS"

build_and_run() {
    local tag="$1" arena_def="$2" out="$3"
    echo "--- build $tag ($arena_def) ---"
    $CC $CFLAGS $NATIVE_DEFS $arena_def \
        -c self/runtime.c -o /tmp/rt_${tag}.o 2>/tmp/cc_${tag}.log || { echo "RT COMPILE FAIL $tag"; tail -20 /tmp/cc_${tag}.log; return 1; }
    $CC $CFLAGS $NATIVE_DEFS $arena_def \
        -c scripts/scratch/rt_native/sh_array_arena_byteeq_gate.c -o /tmp/gate_${tag}.o 2>/tmp/gatecc_${tag}.log || { echo "GATE COMPILE FAIL $tag"; tail -20 /tmp/gatecc_${tag}.log; return 1; }
    $CC /tmp/gate_${tag}.o /tmp/rt_${tag}.o $SEEDS -o /tmp/gate_${tag} -lm 2>/tmp/link_${tag}.log || { echo "LINK FAIL $tag"; tail -20 /tmp/link_${tag}.log; return 1; }
    /tmp/gate_${tag} > "$out" 2>&1 || { echo "RUN FAIL $tag"; cat "$out"; return 1; }
    echo "$tag ran OK ($(wc -l < "$out") lines)"
}

build_and_run native "-DHEXA_RT_ARRAY_ARENA_NATIVE=1" /tmp/dump_native.txt || exit 1
build_and_run cbody  "-UHEXA_RT_ARRAY_ARENA_NATIVE"   /tmp/dump_cbody.txt  || exit 1

echo "=== A/B DIFF ==="
if diff -u /tmp/dump_cbody.txt /tmp/dump_native.txt; then
    echo "BYTEEQ_OK native==C — array contents byte-identical after arena-grow push sequence"
    echo "--- native dump (head) ---"; head -8 /tmp/dump_native.txt
else
    echo "BYTEEQ_DIFFER — native arena bridge diverges from C body"
    exit 1
fi
