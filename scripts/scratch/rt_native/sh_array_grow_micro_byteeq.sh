set -uo pipefail
cd ~/hexa-lang || exit 1
echo "=== sh-array-grow (r2) FOCUSED arena GROW byte-eq (array seed + alloc seed only) ==="
git rev-parse --short HEAD
CC="${CC:-clang}"

echo "=== [0] regen array_core + alloc seeds ==="
APRIME=build/aprime_cc bash tool/regen_array_core_native_s.sh x86_64 2>&1 | tail -1
APRIME=build/aprime_cc bash tool/regen_alloc_syscall_native_s.sh x86_64 2>&1 | tail -1
GROW_GLOBL=$(grep -cE '\.globl[[:space:]]+_?rt_array_grow_arena_native' self/native/array_core_x86_64.s)
ALLOC_GLOBL=$(grep -cE '\.globl[[:space:]]+_?rt_array_arena_alloc_items_native' self/native/array_core_x86_64.s)
TOTAL=$(grep -cE '^\.globl[[:space:]]+_?rt_array_' self/native/array_core_x86_64.s)
echo "GROW-GLOBL=$GROW_GLOBL ALLOC-ITEMS-GLOBL=$ALLOC_GLOBL TOTAL-RT-GLOBL=$TOTAL"
if [ "$GROW_GLOBL" != "1" ]; then
    echo "WALL: rt_array_grow_arena_native did NOT lower to a native seed (globl=$GROW_GLOBL)"
    exit 2
fi

echo "=== [1] assemble seed objects ==="
mkdir -p build
for f in array_core alloc_syscall; do
    grep -vE '^// ' self/native/${f}_x86_64.s > /tmp/${f}.s
    $CC -c /tmp/${f}.s -o build/${f}_native.o 2>/tmp/asm_${f}.log || { echo "ASM FAIL $f"; tail -10 /tmp/asm_${f}.log; exit 1; }
done
echo "--- array seed grow + alloc-items exports ---"
nm build/array_core_native.o | grep -E "rt_array_grow_arena_native|rt_array_arena_alloc_items_native"

echo "=== [2] build + run grow micro-gate ==="
$CC -O2 -std=gnu11 -c scripts/scratch/rt_native/sh_array_grow_micro_gate.c -o /tmp/grow.o 2>/tmp/growcc.log || { echo "GATE CC FAIL"; tail -15 /tmp/growcc.log; exit 1; }
$CC /tmp/grow.o build/array_core_native.o build/alloc_syscall_native.o -o /tmp/grow 2>/tmp/growlink.log || { echo "LINK FAIL"; tail -20 /tmp/growlink.log; exit 1; }
/tmp/grow
RC=$?
echo "grow micro-gate exit=$RC"
exit $RC
