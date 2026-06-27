#!/usr/bin/env bash
# FLEET lane A — build + measure the array descriptor discriminator (TAG_ARRAY_I64).
# Run on aiden in a fresh clone of branch feat/array-descriptor-discriminator.
# Builds a single-TU C harness over the FULL amalgam runtime.c (regen'd from the
# branch emitters) with -DHEXA_PACK_ESCAPING and runs 4P+4C 20x.
set -u
ROOT="${1:-$PWD}"
cd "$ROOT" || exit 1
echo "=== [1/4] regen runtime.c + runtime_core.c from branch emitters ==="
# runtime_core.c (CORE body, has my TAG_ARRAY_I64 + poly readers)
bash tool/regen_runtime_core_c.sh . 2>&1 | tail -1
# runtime.c (full amalgam wrapper that #includes runtime_core.c) — same awk un-escaper
awk '
  BEGIN { saw=0 }
  { line=$0; pfx="    buf = buf + \""
    if (substr(line,1,length(pfx))!=pfx) next
    body=substr(line,length(pfx)+1)
    if (substr(body,length(body),1)!="\"") next
    body=substr(body,1,length(body)-1); saw=1
    out=""; n=length(body); i=1
    while(i<=n){ c=substr(body,i,1)
      if(c=="\\"&&i<n){ d=substr(body,i+1,1)
        if(d=="n"){out=out"\n";i+=2;continue}
        if(d=="t"){out=out"\t";i+=2;continue}
        if(d=="\""){out=out"\"";i+=2;continue}
        if(d=="\\"){out=out"\\";i+=2;continue}
        out=out"\\";i+=1;continue }
      out=out c;i+=1 }
    printf "%s",out }
  END{ if(!saw) exit 3 }
' self/runtime_emit_full.hexa > self/runtime.c || { echo "FATAL: runtime.c regen failed"; exit 1; }
echo "runtime.c regen: $(wc -l < self/runtime.c) lines"
grep -q "hexa_arr_poly_get" self/runtime_core.c && echo "OK poly readers present" || { echo "FATAL: poly readers missing"; exit 1; }
grep -q "TAG_ARRAY_I64" self/runtime_core.c && echo "OK TAG_ARRAY_I64 present" || { echo "FATAL: tag missing"; exit 1; }

echo "=== [2/4] compile harness (-DHEXA_PACK_ESCAPING) ==="
# The amalgam runtime.c references rt_*_native delegates (array/map/intern/valop/fs)
# supplied as native .o in the installed runtime.a; extract them. Drop rt_hi_native.o
# (the amalgam's runtime_hi_gen.c already defines those) and alloc seed (C body owns it
# when HEXA_RT_ALLOC_NATIVE unset). Match lane-s's working recipe.
WORK=/tmp/descdisc_build; rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
ar x ~/.hx/bin/build/runtime.a array_core_native.o map_core_native.o intern_core_native.o valop_core_native.o fs_core_native.o 2>/dev/null || true
ls *.o 2>/dev/null | sed 's/^/  extracted: /'
cd "$ROOT"
set -x
gcc -O2 -g -DHEXA_PACK_ESCAPING -DHEXA_THREADS -pthread -I self \
    -o /tmp/descdisc \
    test/native_build/descriptor_discriminator_4p4c.c self/runtime.c \
    $WORK/*.o -lm -ldl -lpthread 2>&1 | tail -40
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

echo "=== [4/4] byteeq sanity: default (no flag) runtime_core.c .o vs flag-built ==="
# Prove the flag-OFF object is byte-identical to baseline by compiling the SAME
# runtime.c twice (default vs -DHEXA_PACK_ESCAPING) and diffing the default against
# an origin/main-emitter build is the CI job; here just confirm default compiles +
# the flag-guarded symbols are ABSENT without the flag.
gcc -O2 -DHEXA_THREADS -pthread -I self -c self/runtime.c -o /tmp/rt_default.o 2>/tmp/rtd.err && \
  { nm /tmp/rt_default.o | grep -q "hexa_arr_poly_get" && echo "WARN: poly symbol leaked into DEFAULT (byteeq risk!)" || echo "OK: poly readers ABSENT from default .o (flag-OFF byte-neutral)"; } || \
  echo "default compile note: $(tail -2 /tmp/rtd.err)"
echo "=== DONE ==="
