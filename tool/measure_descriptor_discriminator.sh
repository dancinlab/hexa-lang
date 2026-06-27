#!/usr/bin/env bash
# FLEET lane A — build + measure the array descriptor discriminator (TAG_ARRAY_I64).
# Run on aiden in a fresh clone of branch feat/array-descriptor-discriminator.
# Builds a single-TU C harness over the FULL amalgam runtime.c (regen'd from the
# branch emitters) with -DHEXA_PACK_ESCAPING and runs 4P+4C 20x.
set -u
ROOT="${1:-$PWD}"
cd "$ROOT" || exit 1
echo "=== [1/4] regen runtime_core.c from branch emitter (CORE tier, self-contained) ==="
# runtime_core.c (CORE body, has my TAG_ARRAY_I64 + poly readers). The harness
# self-includes sysheaders + hxlcl shim + runtime_core.c into ONE TU.
bash tool/regen_runtime_core_c.sh . 2>&1 | tail -1
grep -q "hexa_arr_poly_get" self/runtime_core.c && echo "OK poly readers present" || { echo "FATAL: poly readers missing"; exit 1; }
grep -q "TAG_ARRAY_I64" self/runtime_core.c && echo "OK TAG_ARRAY_I64 present" || { echo "FATAL: tag missing"; exit 1; }

echo "=== [2/4] compile self-contained harness TU (-DHEXA_PACK_ESCAPING) ==="
# runtime_core.c references rt_*_native delegates (array/map/intern/valop/fs) + the
# alloc seed (hexa_arena_*), supplied as native .o in the installed runtime.a. A few
# HI-tier symbols (hexa_farr_*, hexa_str_parse_int, hexa_char_code, …) are referenced
# from dead-for-this-test paths (rt_read_f32_*, hexa_to_int) — provide weak no-op
# stubs so the link closes without pulling the whole HI tier. None are on the
# 4P+4C measurement path (producer/consumer only call hexa_arr_poly_* + hexa_int).
WORK=/tmp/descdisc_build; rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
ar x ~/.hx/bin/build/runtime.a array_core_native.o map_core_native.o intern_core_native.o valop_core_native.o fs_core_native.o alloc_syscall_native.o 2>/dev/null || true
ls *.o 2>/dev/null | sed 's/^/  extracted: /'
cat > $WORK/hi_stubs.c <<'STUB'
#include <stdlib.h>
/* These are only reached on paths the 4P+4C test never executes. Define them as
 * weak symbols that abort if ever called — satisfies the linker, fails loud if hit. */
#define STUB0(n) __attribute__((weak)) long n(void){ abort(); }
#define STUB1(n) __attribute__((weak)) long n(long a){ (void)a; abort(); }
#define STUB2(n) __attribute__((weak)) long n(long a,long b){ (void)a;(void)b; abort(); }
STUB0(hexa_farr_zeros) STUB0(hexa_farr32_zeros)
STUB2(hexa_farr_set) STUB2(hexa_farr32_set)
STUB1(hexa_str_parse_int) STUB1(hexa_char_code) STUB1(hexa_range_field)
__attribute__((weak)) void _hexa_init_fn_shims(void){}
STUB
cd "$ROOT"
set -x
gcc -O2 -g -DHEXA_PACK_ESCAPING -DHEXA_THREADS -DHEXA_RT_ALLOC_NATIVE=0 -pthread -I self \
    -o /tmp/descdisc \
    test/native_build/descriptor_discriminator_4p4c.c $WORK/*.o $WORK/hi_stubs.c \
    -lm -ldl -lpthread 2>&1 | grep -iE "undefined|collect2|error:|cannot" | head -30
set +x
[ -x /tmp/descdisc ] || { echo "BUILD FAILED — see link errors above"; exit 1; }
echo "BUILD OK: /tmp/descdisc"

echo "=== [3/4] run 4P+4C 20x (descriptor-packed escaping buffer) ==="
pass=0; crash=0
for i in $(seq 1 20); do
  /tmp/descdisc >/tmp/dd.out 2>/tmp/dd.err; rc=$?
  if [ $rc -eq 0 ]; then pass=$((pass+1)); else crash=$((crash+1)); echo "  run $i: rc=$rc $(cat /tmp/dd.err | head -1)"; fi
done
echo "RESULT(packed escaping via descriptor): PASS=$pass CRASH=$crash  (target: PASS=20 CRASH=0)"
echo "sample output: $(/tmp/descdisc 2>&1 | head -1)"

echo "=== [4/4] byteeq: my runtime_core.c (flag-OFF) .o == origin/main runtime_core.c .o ? ==="
# THE release-integrity proof: compile the CORE-tier runtime_core.c standalone with
# NO flag, from MY emitter vs the origin/main emitter, and diff the .o. Force-include
# the sysheaders prelude so the fragment compiles standalone (HEXA_ZEROC_RTCORE_SHIM_TU
# path). Default (flag-OFF) must be byte-identical.
git show origin/main:self/runtime_core_emit.hexa > /tmp/base_rcemit.hexa
mkdir -p /tmp/base_rc/self && cp /tmp/base_rcemit.hexa /tmp/base_rc/self/runtime_core_emit.hexa
bash tool/regen_runtime_core_c.sh /tmp/base_rc 2>&1 | tail -1
CFLAGS_RC="-O2 -DHEXA_RT_ALLOC_NATIVE=0 -include self/runtime_core_sysheaders.h -I self"
gcc $CFLAGS_RC -c self/runtime_core.c -o /tmp/rc_mine.o 2>/tmp/rcm.err
gcc $CFLAGS_RC -c /tmp/base_rc/self/runtime_core.c -o /tmp/rc_base.o 2>/tmp/rcb.err
if [ -f /tmp/rc_mine.o ] && [ -f /tmp/rc_base.o ]; then
  if cmp -s /tmp/rc_mine.o /tmp/rc_base.o; then
    echo "BYTEEQ OK: runtime_core.o (flag-OFF) BYTE-IDENTICAL to origin/main (x86_64-linux)"
  else
    echo "BYTEEQ DIFFER: comparing .text sections —"
    objdump -d /tmp/rc_mine.o > /tmp/m.s 2>/dev/null; objdump -d /tmp/rc_base.o > /tmp/b.s 2>/dev/null
    diff /tmp/b.s /tmp/m.s | head -20
  fi
  nm /tmp/rc_mine.o | grep -q "hexa_arr_poly_get" && echo "WARN: poly leaked into flag-OFF .o" || echo "OK: poly readers ABSENT from flag-OFF .o"
else
  echo "byteeq compile note (mine): $(tail -2 /tmp/rcm.err)"
  echo "byteeq compile note (base): $(tail -2 /tmp/rcb.err)"
fi
echo "=== DONE ==="
