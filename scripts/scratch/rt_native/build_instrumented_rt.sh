#!/bin/bash
# build_instrumented_rt.sh — Lane B tag24 UAF diagnosis.
# Builds an ISOLATED instrumented runtime.a (hexa_mul throw prints a.tag/b.tag +
# backtrace under HEXA_TAG24_TRACE=1) WITHOUT touching the shared tree.
# Persistent build dir (NOT /tmp): ~/rt_instr.  Re-runnable after any wipe.
set -eu
SRC="$HOME/core/hexa-lang"
DST="$HOME/rt_instr"
rm -rf "$DST"; mkdir -p "$DST/build"
cp -r "$SRC/self" "$DST/self"
# instrument hexa_mul throw in the ISOLATED copy
python3 - "$DST/self/runtime_core.c" <<'PY'
import sys
f=sys.argv[1]; s=open(f).read()
n=("        snprintf(_buf, sizeof(_buf), \"cannot multiply non-numeric operand (tag %d * tag %d)\", (int)HX_TAG(a), (int)HX_TAG(b));\n        hexa_throw(hexa_str(_buf));\n")
assert n in s, "mul needle missing"
ins=("        if (hxlcl_getenv(\"HEXA_TAG24_TRACE\")) {\n"
     "          fprintf(stderr, \"[TAG24-MUL] a.tag=%d b.tag=%d\\n\", (int)HX_TAG(a), (int)HX_TAG(b));\n"
     "          void* _bt[32]; int _n = hxlcl_backtrace(_bt, 32); hxlcl_backtrace_symbols_fd(_bt, _n, 2);\n"
     "        }\n")
open(f,"w").write(s.replace(n, ins+n, 1))
print("instrumented" if "[TAG24-MUL]" in open(f).read() else "FAIL")
PY
clang -O2 -std=gnu11 -D_GNU_SOURCE -Wno-trigraphs -I "$DST/self" -c "$DST/self/runtime.c" -o "$DST/build/runtime.o"
ar rcs "$DST/build/runtime.a" "$DST/build/runtime.o"
echo "built $DST/build/runtime.a"
nm "$DST/build/runtime.a" | grep -E " T (forge_dispatch_groupnorm_gelu|rt_read_bytes_at)" || true
