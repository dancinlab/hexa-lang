import re, sys
p = sys.argv[1]
src = open(p).read()
# Rewrite hexa_callN(forge_dispatch_X, args) -> forge_dispatch_X(args) ONLY.
# forge_dispatch_* are real C functions (runtime.h). farr_*_gpu are HexaVal
# carrier variables (extern HexaVal) and MUST stay as hexa_callN dispatch.
pat = re.compile(r'hexa_call[0-9]\(\s*(forge_dispatch_[A-Za-z0-9_]+)\s*,\s*')
n = 0
def repl(m):
    global n; n += 1
    return m.group(1) + '('
src = pat.sub(repl, src)
# Inject a prototype for forge_dispatch_adamw_fused (M2, stubbed) right after
# the runtime.h include so the direct call type-checks (returns HexaVal).
proto = ('HexaVal forge_dispatch_adamw_fused(HexaVal,HexaVal,HexaVal,HexaVal,HexaVal,'
         'HexaVal,HexaVal,HexaVal,HexaVal,HexaVal,HexaVal,HexaVal);\n')
if 'forge_dispatch_adamw_fused(HexaVal,' not in src:
    src = src.replace('#include "runtime.h"\n', '#include "runtime.h"\n'+proto, 1)
open(p, 'w').write(src)
print(f"rewrote {n} forge_dispatch hexa_callN->direct; adamw proto injected")
