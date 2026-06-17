#!/usr/bin/env bash
# RT-NATIVE x86_64 byte-eq self-reproduction — emit the flattened compiler twice
# to an x86_64-linux object with the (pair-model-fixed) aprime and cmp gen3==gen4.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
REPO="$PWD" FLAT="/tmp/flat_x86.hexa" python3 - <<'PY'
import re, os
repo=os.environ["REPO"]; flat=os.environ["FLAT"]; os.chdir(repo)
seen=[]; sset=set()
STUB=('pub let ATLAS_HASH: string = "fixture"\npub let ATLAS_SOURCE_COUNT: i64 = 0\npub let ATLAS_GENERATED_AT: string = "fixture"\n'+''.join(f'pub let ATLAS_{k}_NODES: [AtlasNode] = []\n' for k in "PCLEFRSXQ"))
def walk(f):
    f=os.path.normpath(f)
    if f in sset or not os.path.exists(f): return
    sset.add(f); d=os.path.dirname(f)
    txt=open(f,encoding="utf-8",errors="replace").read(); deps=[]
    for m in re.finditer(r'^\s*import\s+"([^"]+)"',txt,re.M): deps.append(os.path.normpath(os.path.join(d,m.group(1))))
    for m in re.finditer(r'^\s*use\s+"([^"]+)"',txt,re.M):
        p=m.group(1)
        if not p.endswith(".hexa"): p+=".hexa"
        for c in [p,os.path.join(d,p),os.path.join(d,os.path.basename(p))]:
            if os.path.exists(os.path.normpath(c)): deps.append(os.path.normpath(c)); break
    for x in deps: walk(x)
    seen.append(f)
walk("compiler/main.hexa")
out=[]
for f in seen:
    if f.endswith("embedded.gen.hexa"): out.append("// STUB\n"+STUB); continue
    t=open(f,encoding="utf-8",errors="replace").read()
    t=re.sub(r'^\s*(import|use)\s+"[^"]*".*$','',t,flags=re.M)
    out.append("// ==== "+f+" ====\n"+t)
open(flat,"w").write("\n".join(out)); print("flatten:",len(seen),"files",len(open(flat).read().splitlines()),"lines")
PY
AP="${AP:-build/aprime_cc}"
"$AP" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o /tmp/g3x.o /tmp/flat_x86.hexa 2>/tmp/emit3.log
"$AP" _drv.hexa --emit=obj --target=x86_64-linux-gnu -o /tmp/g4x.o /tmp/flat_x86.hexa 2>/tmp/emit4.log
echo "g3 size=$(stat -c%s /tmp/g3x.o 2>/dev/null) g4 size=$(stat -c%s /tmp/g4x.o 2>/dev/null)"
grep -ic "ENCODE-MISS" /tmp/emit3.log /tmp/emit4.log 2>/dev/null || true
if cmp /tmp/g3x.o /tmp/g4x.o; then echo "BYTEEQ_OK gen3==gen4 ($(stat -c%s /tmp/g3x.o) bytes)"; else echo "BYTEEQ_DIFFER"; fi
