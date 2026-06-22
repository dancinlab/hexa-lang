#!/usr/bin/env bash
# tool/measure_rtcore_seed_coverage.sh — zero-c leg-B r3 SCOPE MEASUREMENT
#
# Answers the question driving `ls self/*.c == ∅`: how reducible is the
# generated runtime_core.c, and is dropping it a BOUNDED native-object swap
# (like the rt_hi seed that took 3→2) or the full standalone-ABI redesign?
#
# It regenerates self/runtime_core.c from its emitter SSOT (hexat-FREE awk
# un-escaper, the SAME path tool/stage_resolve_runtime_a uses), then classifies
# every public C function def by whether an in-tree native seed (self/native/
# *_<arch>.s) already supplies its symbol.
#
# OUTPUT (measured 2026-06-22 origin/main on aiden Linux x86_64):
#   runtime_core.c public fn defs : ~250
#   covered by a native seed      : 20
#   NOT covered (pure-C port debt): ~230
#   only code #include inside it  : runtime_hi_gen.c (1, already dropped by rt_hi seed)
#   irreducible-C: 11 libm-transcendental fns + setjmp/longjmp try-frame (9 uses)
#                  + HexaVal struct ABI + _start/CRT
#   self/runtime.c is a FROZEN BOOTSTRAP SEED (restore_frozen_seeds, blob
#                  151c52c82) — NOT emitter-generated; it #include "runtime_core.c".
#
# VERDICT: dropping runtime_core.c is ALL-OR-NOTHING — it is one monolithic
# #include with NO further separable code sub-leaf (rt_hi was the last leaf).
# The 20 seeded symbols swap bodies INSIDE the file but do not reduce the
# file's existence. Dropping the file needs ALL ~250 symbols supplied as native
# objects → the full standalone-ABI redesign (RFC 061), not a bounded swap.
#
# Usage: bash tool/measure_rtcore_seed_coverage.sh   (run at repo root)
set -uo pipefail
ROOT="$PWD"
EMIT="$ROOT/self/runtime_core_emit.hexa"
[ -f "$EMIT" ] || { echo "no $EMIT — run at repo root" >&2; exit 1; }
GEN="$(mktemp)"; trap 'rm -f "$GEN"' EXIT

# hexat-free un-escaper (mirrors stage_resolve_runtime_a::_unescape_emit_to_c)
awk '
  { line=$0; pfx="    buf = buf + \"";
    if (substr(line,1,length(pfx))!=pfx) next;
    s=substr(line, length(pfx)+1);
    sub(/"$/,"",s);
    gsub(/\\n/,"\n",s); gsub(/\\t/,"\t",s); gsub(/\\"/,"\"",s); gsub(/\\\\/,"\\",s);
    printf "%s", s
  }' "$EMIT" > "$GEN"
echo "regenerated runtime_core.c: $(wc -l < "$GEN") lines"

GEN="$GEN" python3 - "$ROOT" << 'PYEOF'
import re,glob,os,sys
root=sys.argv[1]
src=open(os.environ["GEN"]).read().split("\n")
fn_re=re.compile(r"^(?:static\s+)?(?:HexaVal|void|int|long|long long|double|char|size_t|uint64_t|int64_t|uint32_t|bool|HexaArena\w*|HexaIC|const char\s*\*?)\s+\*?([a-zA-Z_][a-zA-Z0-9_]*)\s*\(")
libm=re.compile(r"\b(sin|cos|tan|exp|expf|log|logf|sqrt|sqrtf|pow|fmod|floor|ceil|fabs|atan|atan2|sinh|cosh|tanh)\s*\(")
fns=[];i=0;n=len(src)
while i<n:
    m=fn_re.match(src[i])
    if m and ("{" in src[i] or (i+1<n and src[i+1].strip().startswith("{"))):
        depth=0;body=[];j=i;started=False
        while j<n:
            body.append(src[j]);depth+=src[j].count("{")-src[j].count("}")
            if "{" in src[j]:started=True
            if started and depth<=0:break
            j+=1
        fns.append((m.group(1),"\n".join(body)));i=j+1
    else:i+=1
seedsyms=set()
for f in glob.glob(os.path.join(root,"self/native/*_x86_64.s"))+[os.path.join(root,"self/native/runtime_hi_native.s")]:
    if os.path.exists(f):
        for l in open(f,errors="ignore"):
            mm=re.search(r"\.globl\s+(\S+)",l)
            if mm:seedsyms.add(mm.group(1).lstrip("_"))
def has_seed(f):
    return bool({f,"rt_"+f,f+"_native",f.replace("hexa_","rt_")+"_native",f.replace("hexa_","rt_")}&seedsyms)
names=[f for f,_ in fns]
cov=[f for f in names if has_seed(f)]
unc=[(f,b) for f,b in fns if not has_seed(f)]
print("runtime_core.c public fn defs :", len(names))
print("covered by a native seed      :", len(cov))
print("NOT covered (pure-C port debt):", len(unc))
print("irreducible — libm-transcendental:", sorted({f for f,b in unc if libm.search(b)}))
print("irreducible — try-frame (setjmp):", sorted({f for f,b in unc if 'try' in f.lower() or 'throw' in f.lower()}))
PYEOF
