set -uo pipefail
cd ~/hexa-lang || exit 1
echo "=== sh-array-write ARENA byte-eq A/B (native bridge vs C body) ==="
git rev-parse --short HEAD
CC="${CC:-clang}"

# [0] Regenerate ALL native seeds from the branch SSOT so there is NO seed/runtime
# drift (the committed seeds predate this lane + may lag the emitter for other
# families). array_core picks up the new rt_array_arena_alloc_items_native symbol.
echo "=== [0] regen all native seeds (x86_64) ==="
git checkout -- self/runtime.c self/runtime_core.c 2>/dev/null || true
for s in array_core alloc_syscall map_core intern_core fs_core runtime_hi; do
    APRIME=build/aprime_cc bash tool/regen_${s}_native_s.sh x86_64 2>&1 | tail -1
done
echo "ARENA-GLOBL=$(grep -cE '\.globl[[:space:]]+_?rt_array_arena_alloc_items_native' self/native/array_core_x86_64.s) ARENA-CALL=$(grep -cE 'call[[:space:]]+_?hexa_arena_alloc' self/native/array_core_x86_64.s)"
if [ "$(grep -cE '\.globl[[:space:]]+_?rt_array_arena_alloc_items_native' self/native/array_core_x86_64.s)" != "1" ]; then
    echo "WALL: regenerated seed does NOT export rt_array_arena_alloc_items_native — alloc-bearing prim did not lower to a native seed"
    exit 2
fi

# [1] Let stage_resolve_runtime_a regen runtime_core.c + assemble all seed .o +
# decide the full native define matrix (it builds build/runtime.a with
# HEXA_RT_ARRAY_ARENA_NATIVE=1 — the NATIVE config). Drop stale .o first so it
# reassembles from the freshly regenerated seeds.
echo "=== [1] stage_resolve_runtime_a (full native matrix) ==="
rm -f build/*_native.o build/runtime.o build/runtime.a
CC="$CC" bash tool/stage_resolve_runtime_a >/tmp/srra.log 2>&1 || { echo "stage_resolve FAIL"; tail -30 /tmp/srra.log; exit 1; }
grep -nE "HEXA_RT_ARRAY_ARENA_NATIVE=1|ARRAY-R4|ALLOC-RB|MAP-R3|INTERN|FS-R1|Z2a" /tmp/srra.log | tail
[ -f build/runtime.a ] || { echo "MISSING runtime.a"; exit 1; }
echo "--- native array seed .o carries arena bridge symbol? ---"
nm build/array_core_native.o 2>/dev/null | grep -E "rt_array_arena_alloc_items_native|hexa_arena_alloc" | head

# Reconstruct the EXACT define matrix + seed-object set the stage used (parsed
# from its log) so both A/B builds are identical EXCEPT HEXA_RT_ARRAY_ARENA_NATIVE.
DEFS="-DHEXA_RT_ALLOC_NATIVE=1"
grep -q "HEXA_RT_ARRAY_NATIVE=1"  /tmp/srra.log && DEFS="$DEFS -DHEXA_RT_ARRAY_NATIVE=1"
grep -q "HEXA_RT_MAP_NATIVE=1"    /tmp/srra.log && DEFS="$DEFS -DHEXA_RT_MAP_NATIVE=1"
grep -q "HEXA_RT_INTERN_NATIVE=1" /tmp/srra.log && DEFS="$DEFS -DHEXA_RT_INTERN_NATIVE=1"
grep -q "HEXA_RT_FS_NATIVE=1"     /tmp/srra.log && DEFS="$DEFS -DHEXA_RT_FS_NATIVE=1"
grep -q "Z2a:"                    /tmp/srra.log && DEFS="$DEFS -DHEXA_ZEROC_RT_HI=1"
SEEDS="$(ls build/*_native.o 2>/dev/null | tr '\n' ' ')"
CFLAGS="-O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I self"
echo "DEFS=$DEFS"
echo "SEEDS=$SEEDS"

build_and_run() {
    local tag="$1" arena_def="$2" out="$3"
    echo "--- build $tag ($arena_def) ---"
    $CC $CFLAGS $DEFS $arena_def -c self/runtime.c -o /tmp/rt_${tag}.o 2>/tmp/cc_${tag}.log || { echo "RT COMPILE FAIL $tag"; tail -20 /tmp/cc_${tag}.log; return 1; }
    $CC $CFLAGS $DEFS $arena_def -c scripts/scratch/rt_native/sh_array_arena_byteeq_gate.c -o /tmp/gate_${tag}.o 2>/tmp/gatecc_${tag}.log || { echo "GATE COMPILE FAIL $tag"; tail -20 /tmp/gatecc_${tag}.log; return 1; }
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
