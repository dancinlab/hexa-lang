set -uo pipefail
cd ~/hexa-lang || exit 1
echo "=== sh-array-write ARENA byte-eq A/B (native bridge vs C body) ==="
git rev-parse --short HEAD
CC="${CC:-clang}"

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

# [1] Regenerate runtime_core.c from the (branch) emitter SSOT (so the
# #ifdef HEXA_RT_ARRAY_ARENA_NATIVE arm is present) WITHOUT pulling in the other
# families' native paths. We isolate to ARRAY+ALLOC native; map/intern/fs/rt_hi
# use their C bodies (-U…) so any committed-seed drift for those families is
# irrelevant to this lane. Restore the runtime amalgam first (a prior run may
# have sed-removed the rt_hi #include).
echo "=== [1] regen runtime_core.c (array+alloc native only) ==="
git checkout -- self/runtime.c self/runtime_core.c 2>/dev/null || true
rm -f build/array_core_native.o build/alloc_syscall_native.o
# Only assemble the two seeds this lane links; HEXA_RT_*_NATIVE for the others
# stays unset so the C bodies are used and no seed symbols are referenced.
HEXA_RT_MAP_NATIVE=0 HEXA_RT_INTERN_NATIVE=0 HEXA_RT_FS_NATIVE=0 HEXA_ZEROC_RT_HI=0 \
    CC="$CC" bash tool/stage_resolve_runtime_a >/tmp/srra.log 2>&1 || { echo "stage_resolve FAIL"; tail -25 /tmp/srra.log; exit 1; }
grep -nE "HEXA_RT_ARRAY_ARENA_NATIVE=1|RT-NATIVE ARRAY-R4|ALLOC-RB" /tmp/srra.log | tail
[ -f build/array_core_native.o ] || { echo "MISSING array_core_native.o"; exit 1; }
[ -f build/alloc_syscall_native.o ] || { echo "MISSING alloc_syscall_native.o"; exit 1; }
echo "--- regenerated array seed .o carries the arena bridge symbol? ---"
nm build/array_core_native.o 2>/dev/null | grep -E "rt_array_arena_alloc_items_native|hexa_arena_alloc" | head

CFLAGS="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self"
# ARRAY + ALLOC native; every other family forced to its C body so the only
# config delta between the two builds is HEXA_RT_ARRAY_ARENA_NATIVE.
NATIVE_DEFS="-DHEXA_RT_ALLOC_NATIVE=1 -DHEXA_RT_ARRAY_NATIVE=1 -UHEXA_RT_MAP_NATIVE -UHEXA_RT_INTERN_NATIVE -UHEXA_RT_FS_NATIVE -UHEXA_ZEROC_RT_HI"
SEEDS="build/array_core_native.o build/alloc_syscall_native.o"
echo "NATIVE_DEFS=$NATIVE_DEFS"
echo "SEEDS=$SEEDS"

build_and_run() {
    local tag="$1" arena_def="$2" out="$3"
    echo "--- build $tag ($arena_def) ---"
    $CC $CFLAGS $NATIVE_DEFS $arena_def \
        -c self/runtime.c -o /tmp/rt_${tag}.o 2>/tmp/cc_${tag}.log || { echo "RT COMPILE FAIL $tag"; tail -20 /tmp/cc_${tag}.log; return 1; }
    $CC $CFLAGS $NATIVE_DEFS $arena_def \
        -c scripts/scratch/rt_native/sh_array_arena_byteeq_gate.c -o /tmp/gate_${tag}.o 2>/tmp/gatecc_${tag}.log || { echo "GATE COMPILE FAIL $tag"; tail -20 /tmp/gatecc_${tag}.log; return 1; }
    $CC /tmp/gate_${tag}.o /tmp/rt_${tag}.o $SEEDS -o /tmp/gate_${tag} -lm 2>/tmp/link_${tag}.log || { echo "LINK FAIL $tag"; tail -25 /tmp/link_${tag}.log; return 1; }
    /tmp/gate_${tag} > "$out" 2>&1 || { echo "RUN FAIL $tag"; cat "$out"; return 1; }
    echo "$tag ran OK ($(wc -l < "$out") lines)"
}

build_and_run native "-DHEXA_RT_ARRAY_ARENA_NATIVE=1" /tmp/dump_native.txt || exit 1
build_and_run cbody  "-UHEXA_RT_ARRAY_ARENA_NATIVE"   /tmp/dump_cbody.txt  || exit 1

echo "=== A/B DIFF ==="
if diff -u /tmp/dump_cbody.txt /tmp/dump_native.txt; then
    echo "BYTEEQ_OK native==C — array contents byte-identical after arena-grow push sequence"
    echo "--- native dump (full) ---"; cat /tmp/dump_native.txt
else
    echo "BYTEEQ_DIFFER — native arena bridge diverges from C body"
    exit 1
fi
