# s4_flatc_post.py — S4 stage-1 flat C post-processor.
#
# Compensates defects in the *stale committed* hexa_v2 binary
# (build/hexa_v2_new) relative to the current codegen_c2 source. Operates
# on /tmp/flat4.c in place. NOT a permanent codegen path — the principled
# fix is rebuilding hexa_v2; this keeps the S4 verdict pipeline runnable
# meanwhile. Each transform is exact-scoped, statically verifiable and
# trivially reversible (re-transpile to regenerate flat4.c).
#
# Transforms:
#   1. mkdir lowering — codegen_c2:3746 authoritative. Stale hexa_v2
#      emits generic hexa_call1(mkdir,…) which collides with libc
#      mkdir(const char*,mode_t).
#   2. enum #define hoist — stale hexa_v2 emits some enum-constant
#      macros (Severity_*, FixItKind_*) AFTER first use. Hoist every
#      `#define NAME hexa_int(N)` to just after the runtime include so
#      every reference is define-before-use.
#   3. bind rename — the compiler's `bind` phase fn collides with libc
#      bind(int,const struct sockaddr*,socklen_t) from <sys/socket.h>.
#      Rename the C identifier (`bind(` sites only — decl/defn/call;
#      string literals "bind"/"bindings" are left intact) to hexa_ubind.
#   4. free_tree lowering — F6 step 2 (PLAN-stage3-footprint-F6.md).
#      Hexa source calls `free_tree(v)`; stale hexa_v2 emits the generic
#      `hexa_call1(free_tree, X)` which has no resolvable callee.
#      Lower to the runtime function `hexa_val_free_tree(X)` (added in
#      self/runtime.c at F6 step 1 / commit 0efebc88).

import re, sys

p = "/tmp/flat4.c"
src = open(p).read().split("\n")

# (2) collect every enum-constant macro for define-before-use hoisting.
defs = [l for l in src
        if re.match(r"^#define [A-Za-z_][A-Za-z0-9_]* hexa_int\([0-9]+\)$", l)]

hoisted = False
out = []
for l in src:
    # (1) mkdir → direct libc call.
    l = re.sub(r"hexa_call1\(mkdir,\s*([^)]+)\)",
               r"((void)mkdir(HX_STR(\1),0755),hexa_void())", l)
    # (3) bind identifier → hexa_ubind (only `bind(` — decl/defn/call).
    l = re.sub(r"\bbind\s*\(", "hexa_ubind(", l)
    # (4) free_tree builtin → hexa_val_free_tree (F6 step 2).
    l = re.sub(r"hexa_call1\(free_tree,\s*([^)]+)\)",
               r"hexa_val_free_tree(\1)", l)
    out.append(l)
    # (2) hoist after the runtime include (flat C #includes runtime.c).
    s = l.strip()
    if not hoisted and (s == '#include "runtime.c"' or s == '#include "runtime.h"'):
        out.append("/* S4 hoist: enum constant macros forward (define-before-use) */")
        out.extend(defs)
        hoisted = True

if not hoisted:
    sys.stderr.write("s4_flatc_post: ERROR — runtime include anchor not found; "
                     "enum #defines NOT hoisted\n")
    sys.exit(1)

open(p, "w").write("\n".join(out))
print(f"post: hoisted {len(defs)} enum #defines + mkdir lowering + bind rename + free_tree lowering applied")
