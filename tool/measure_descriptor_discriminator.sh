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
set -x
gcc -O2 -g -DHEXA_PACK_ESCAPING -DHEXA_THREADS -DHEXA_RT_ALLOC_NATIVE=0 -pthread -I self \
    -o /tmp/descdisc \
    test/native_build/descriptor_discriminator_4p4c.c -lm -ldl -lpthread 2>&1 | tail -45
set +x
[ -x /tmp/descdisc ] || { echo "BUILD FAILED — see errors above"; exit 1; }

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
gcc $CFLAGS_RC -include self/runtime_core_sysheaders.h -c /tmp/base_rc/self/runtime_core.c -o /tmp/rc_base.o 2>/tmp/rcb.err
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
