#!/bin/bash
# RT-NATIVE Z2a x86_64-linux byte-eq verification (run on aiden, linux x86_64).
# Mirrors the darwin parity proof: build aprime_cc with C runtime_hi vs with
# native rt_hi.o (HEXA_ZEROC_RT_HI=1), emit identical .s = runtime_hi_gen.c eliminable.
set -e
cd ~/hexa-lang
echo "=== [1] build aprime_cc (x86_64-linux) ==="
bash tool/build_aprime.sh -o build/aprime_cc_lin 2>&1 | tail -3
echo "=== [2] native-compile lib-only runtime_hi -> x86_64-linux .s ==="
head -130 self/runtime_hi.hexa > /tmp/rt_hi_lib.hexa
./build/aprime_cc_lin _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/rt_hi.s /tmp/rt_hi_lib.hexa 2>&1 | grep -v atlas | head -2
echo "=== [3] assemble -> rt_hi.o ==="
clang -c /tmp/rt_hi.s -o build/rt_hi_native.o
echo "PROVIDED:"; nm build/rt_hi_native.o | grep -E ' [Tt] .*rt_str' | head
echo "MAIN?:"; nm build/rt_hi_native.o | grep -iE ' T (_?main)$' || echo '  none (good)'
echo "=== [4] build aprime with HEXA_ZEROC_RT_HI=1 (no runtime_hi_gen.c, link rt_hi.o) ==="
HEXA_ZEROC_RT_HI=1 bash tool/build_aprime.sh -o build/aprime_z2a_lin 2>&1 | tail -3
echo "=== [5] PARITY: aprime_z2a (native rt) vs aprime_cc (C rt) emit byte-identical .s? ==="
P=0; F=0
for src in self/runtime_hi.hexa self/ast.hexa self/atomic_ops.hexa; do
  ./build/aprime_z2a_lin _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/a.s "$src" 2>/dev/null || { echo "  ERR emit z2a $src"; F=$((F+1)); continue; }
  ./build/aprime_cc_lin  _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/b.s "$src" 2>/dev/null || { echo "  ERR emit cc $src"; F=$((F+1)); continue; }
  if cmp -s /tmp/a.s /tmp/b.s; then echo "  PASS byte-identical: $src"; P=$((P+1)); else echo "  FAIL DIFFERS: $src"; F=$((F+1)); fi
done
echo "=== RESULT: $P identical, $F differ ==="
[ $F -eq 0 ] && echo 'Z2A_LINUX_VERIFIED_PASS' || echo 'Z2A_LINUX_FAIL'
