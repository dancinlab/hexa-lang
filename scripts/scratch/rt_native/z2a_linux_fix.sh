#!/bin/bash
# Z2a linux fix: native x86_64 rt_hi.o uses absolute relocations (non-PIC) →
# link the HEXA_ZEROC_RT_HI build with -no-pie. Then parity-test vs C-rt build.
cd ~/hexa-lang
git checkout tool/build_aprime.sh 2>/dev/null
# Patch: add -no-pie to the clang link when ZEROC_RT_HI_OBJ is set.
python3 - <<'PY'
p="tool/build_aprime.sh"; s=open(p).read()
old='-I self -I . "$APPOST" $ZEROC_RT_HI_OBJ -o "$OUT" -lm'
new='-I self -I . "$APPOST" $ZEROC_RT_HI_OBJ ${ZEROC_RT_HI_OBJ:+-no-pie} -o "$OUT" -lm'
s=s.replace(old,new); open(p,"w").write(s)
print("patched-no-pie" if "-no-pie" in s else "NO-MATCH")
PY
echo "=== rebuild aprime_z2a (linux, -no-pie) ==="
HEXA_ZEROC_RT_HI=1 bash tool/build_aprime.sh -o build/aprime_z2a_lin 2>&1 | tail -3
echo "=== parity: aprime_z2a (native rt) vs aprime_cc (C rt), byte-identical .s? ==="
P=0; F=0
for src in self/runtime_hi.hexa self/ast.hexa self/atomic_ops.hexa self/codegen_native.hexa; do
  ./build/aprime_z2a_lin _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/a.s "$src" 2>/dev/null || { echo "  ERR z2a $src"; F=$((F+1)); continue; }
  ./build/aprime_cc_lin  _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/b.s "$src" 2>/dev/null || { echo "  ERR cc $src"; F=$((F+1)); continue; }
  if cmp -s /tmp/a.s /tmp/b.s; then echo "  PASS byte-identical: $src"; P=$((P+1)); else echo "  FAIL DIFFERS: $src"; F=$((F+1)); fi
done
echo "=== smoke: aprime_z2a compiles+runs exit(42)? ==="
echo 'fn main() -> int { return 6*7 }' > /tmp/smk.hexa
./build/aprime_z2a_lin _drv.hexa --emit=asm --target=x86_64-linux-gnu -o /tmp/smk.s /tmp/smk.hexa 2>/dev/null && clang -no-pie /tmp/smk.s build/runtime.a -o /tmp/smk -lm 2>/dev/null && /tmp/smk; echo "smoke exit=$?"
echo "=== RESULT: $P identical, $F differ ==="
git checkout tool/build_aprime.sh 2>/dev/null
[ $F -eq 0 ] && [ $P -ge 3 ] && echo 'Z2A_LINUX_VERIFIED_PASS' || echo 'Z2A_LINUX_FAIL'
