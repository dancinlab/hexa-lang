#!/usr/bin/env bash
# RT-NATIVE x86_64 leg A cross-assemble gate — verify x86_64 whole-compiler
# codegen LOCALLY on darwin (no summer/pod contention). darwin clang carries
# a multi-arch backend, so `clang -target x86_64-linux-gnu -c` assembles the
# x86_64 asm the native emitter produces — surfacing every codegen bug as an
# `as` error WITHOUT needing a linux host. (Execution still needs linux; this
# gate is the EMIT-correctness fence.)
#   1. build fresh aprime (darwin)   2. flatten whole compiler
#   3. aprime --emit=asm --target=x86_64-linux-gnu  4. clang cross-assemble
#   5. tally remaining `as` error classes
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
A="${1:-build/aprime_xc}"
[ -x "$A" ] || { echo "build $A first (tool/build_aprime.sh -o $A)"; exit 1; }
"$A" _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/flat_x86.s /tmp/flat.hexa 2>/dev/null
echo "asm: $(wc -l < /tmp/flat_x86.s) lines"
clang -target x86_64-linux-gnu -c /tmp/flat_x86.s -o /tmp/flat_x86.o 2>/tmp/flatas.err
echo "obj: $([ -f /tmp/flat_x86.o ] && echo OK $(stat -f%z /tmp/flat_x86.o)B || echo NONE)"
echo "errors: $(grep -c 'error:' /tmp/flatas.err)"
echo "bare g<N> label (should be 0 post-#3423): $(grep -cE '\b(cmp|test|mov)\b[^,]*\bg[0-9]+\b' /tmp/flat_x86.s)"
echo "── error classes ──"
grep 'error:' /tmp/flatas.err | sed -E 's/.*error: //; s/`[^`]*`/`X`/g; s/[0-9]+/N/g' | sort | uniq -c | sort -rn | head
