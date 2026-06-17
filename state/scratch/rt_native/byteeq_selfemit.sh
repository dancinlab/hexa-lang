#!/usr/bin/env bash
# RT-NATIVE byte-eq self-reproduction (LEG-A) — reproduce gen3≡gen4 locally.
# Uses a FRESH aprime (not the stale ~/.hx/bin/hexa) so the gate runs for real.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
REPO="$PWD" FLAT="/tmp/flat.hexa" python3 - <<'PY'
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
open(flat,"w").write("\n".join(out)); print("flatten:",len(seen),"files")
PY
bash tool/build_aprime.sh -o build/aprime_be
./build/aprime_be _drv.hexa --emit=obj --target=arm64-apple-darwin -o /tmp/g3.o /tmp/flat.hexa 2>/dev/null
./build/aprime_be _drv.hexa --emit=obj --target=arm64-apple-darwin -o /tmp/g4.o /tmp/flat.hexa 2>/dev/null
cmp /tmp/g3.o /tmp/g4.o && echo "✅ gen3 ≡ gen4 BYTE-IDENTICAL ($(stat -f%z /tmp/g3.o) bytes)" || echo "❌ DIFFER"
