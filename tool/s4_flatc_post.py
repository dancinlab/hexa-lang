import re,sys
p="/tmp/flat4.c"; src=open(p).read().split("\n")
defs=[l for l in src if re.match(r"^#define [A-Za-z_][A-Za-z0-9_]* hexa_int\([0-9]+\)$", l)]
out=[]
for l in src:
    # codegen_c2:3746 authoritative mkdir lowering (committed hexa_v2 binary is
    # stale vs codegen_c2 source → emitted generic hexa_call1(mkdir,…) which
    # collides with libc mkdir(const char*,mode_t)).
    l=re.sub(r"hexa_call1\(mkdir,\s*([^)]+)\)", r"((void)mkdir(HX_STR(\1),0755),hexa_void())", l)
    out.append(l)
    if l.strip()=='#include "runtime.h"':
        out.append("/* S4 hoist: enum constant macros forward (define-before-use) */")
        out.extend(defs)
open(p,"w").write("\n".join(out))
print(f"post: hoisted {len(defs)} enum #defines + mkdir lowering applied")
