set -uo pipefail
cd ~/hexa-lang || exit 1
echo "=== sh-array-write FOCUSED arena byte-eq (array seed + alloc seed only) ==="
git rev-parse --short HEAD
CC="${CC:-clang}"

# [0] Regenerate the x86_64 array_core + alloc seeds from the branch SSOT.
echo "=== [0] regen array_core + alloc seeds ==="
APRIME=build/aprime_cc bash tool/regen_array_core_native_s.sh x86_64 2>&1 | tail -1
APRIME=build/aprime_cc bash tool/regen_alloc_syscall_native_s.sh x86_64 2>&1 | tail -1
ARENA_GLOBL=$(grep -cE '\.globl[[:space:]]+_?rt_array_arena_alloc_items_native' self/native/array_core_x86_64.s)
ARENA_CALL=$(grep -cE 'call[[:space:]]+_?hexa_arena_alloc' self/native/array_core_x86_64.s)
echo "ARENA-GLOBL=$ARENA_GLOBL ARENA-CALL=$ARENA_CALL"
if [ "$ARENA_GLOBL" != "1" ] || [ "$ARENA_CALL" != "1" ]; then
    echo "WALL: alloc-bearing prim did NOT lower to a native seed (globl=$ARENA_GLOBL call=$ARENA_CALL)"
    exit 2
fi

# [1] Assemble the two seed objects (strip the // comment header first).
echo "=== [1] assemble seed objects ==="
mkdir -p build
for f in array_core alloc_syscall; do
    grep -vE '^// ' self/native/${f}_x86_64.s > /tmp/${f}.s
    $CC -c /tmp/${f}.s -o build/${f}_native.o 2>/tmp/asm_${f}.log || { echo "ASM FAIL $f"; tail -10 /tmp/asm_${f}.log; exit 1; }
done
echo "--- array seed exports + arena ref ---"
nm build/array_core_native.o | grep -E "rt_array_arena_alloc_items_native|hexa_arena_alloc"
echo "--- alloc seed exports ---"
nm build/alloc_syscall_native.o | grep -E " T (rt_init|hexa_arena_alloc|hexa_arena_reset)$"

# [2] Build + run the focused micro-gate against ONLY these two seeds.
echo "=== [2] build + run micro-gate ==="
$CC -O2 -std=gnu11 -c scripts/scratch/rt_native/sh_array_arena_micro_gate.c -o /tmp/micro.o 2>/tmp/microcc.log || { echo "GATE CC FAIL"; tail -15 /tmp/microcc.log; exit 1; }
$CC /tmp/micro.o build/array_core_native.o build/alloc_syscall_native.o -o /tmp/micro 2>/tmp/microlink.log || { echo "LINK FAIL"; tail -15 /tmp/microlink.log; exit 1; }
/tmp/micro
RC=$?
echo "micro-gate exit=$RC"
exit $RC
