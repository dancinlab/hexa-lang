#!/bin/bash
# Diagnose the linux Z2a link failure: capture FULL clang/ld error.
cd ~/hexa-lang
# Patch build_aprime.sh's clang capture to tee full output (python, robust).
python3 - <<'PY'
import re
p="tool/build_aprime.sh"; s=open(p).read()
s=s.replace("-o \"$OUT\" -lm 2>&1 | grep -iE 'error:|undefined' | head -5)\"",
            "-o \"$OUT\" -lm 2>&1 | tee /tmp/clang_full.log | grep -iE 'error:|undefined' | head -5)\"")
open(p,"w").write(s)
print("patched" if "/tmp/clang_full.log" in s else "NO-MATCH")
PY
HEXA_ZEROC_RT_HI=1 bash tool/build_aprime.sh -o /tmp/az2a 2>&1 | tail -3
echo "=== FULL LINK ERRORS ==="
grep -iE 'undefined|duplicate|multiple definition|error:|relocation' /tmp/clang_full.log 2>/dev/null | head -20
echo "=== rt_hi.o vs runtime symbols (conflict check) ==="
nm build/rt_hi_native.o 2>/dev/null | grep -E ' [TtUu] ' | grep -iE 'rt_str|hexa_str_join|__hexa_rt_sl' | head
# restore build_aprime.sh (don't leave it patched)
cd ~/hexa-lang && git checkout tool/build_aprime.sh 2>/dev/null
echo "DIAG_DONE"
