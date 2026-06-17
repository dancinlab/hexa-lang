# tool/larm64_flatten.py — flatten a .hexa import/use closure into ONE file.
#
# Shared flatten helper for the linux-arm64 native-compiler build
# (tool/build_native_linux_arm64). Identical recipe to build_aprime.sh /
# build_selfhost.sh's inline flatten: walk import/use edges from <entry>,
# concatenate in dependency order, strip import/use lines, and replace
# embedded.gen.hexa with an empty-ATLAS_* stub (avoids the O(n^2)
# array-literal transpile hang). Extracted to a tool/ file so the linux
# build script can `python3 tool/larm64_flatten.py <entry> <out>` without a
# fragile remote heredoc.
#
# Usage: python3 tool/larm64_flatten.py [entry.hexa] [out.hexa]
#   entry  default compiler/main.hexa
#   out    default build/larm64/cc-flat.hexa
import re, os, sys
entry = sys.argv[1] if len(sys.argv) > 1 else "compiler/main.hexa"
out_path = sys.argv[2] if len(sys.argv) > 2 else "build/larm64/cc-flat.hexa"
# Repo root = parent of this tool/ dir, so `use a::b::c` resolves to a/b/c.hexa
# regardless of cwd.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
seen = []; sset = set()
STUB = ('pub let ATLAS_HASH: string = "fixture"\n'
        'pub let ATLAS_SOURCE_COUNT: i64 = 0\n'
        'pub let ATLAS_GENERATED_AT: string = "fixture"\n'
        + ''.join('pub let ATLAS_%s_NODES: [AtlasNode] = []\n' % k for k in "PCLEFRSXQ"))
def walk(f):
    f = os.path.normpath(f)
    if f in sset or not os.path.exists(f): return
    sset.add(f); d = os.path.dirname(f)
    txt = open(f, encoding="utf-8", errors="replace").read(); deps = []
    for m in re.finditer(r'^\s*import\s+"([^"]+)"', txt, re.M):
        deps.append(os.path.normpath(os.path.join(d, m.group(1))))
    for m in re.finditer(r'^\s*use\s+"([^"]+)"', txt, re.M):
        p = m.group(1)
        if not p.endswith(".hexa"): p += ".hexa"
        for c in [p, os.path.join(d, p), os.path.join(d, os.path.basename(p))]:
            if os.path.exists(os.path.normpath(c)): deps.append(os.path.normpath(c)); break
    # `use self::rt::syscall` (`::`-path form, no quotes) — used by self/rt/mod.hexa
    # to pull the runtime-replacement module tree. Map `a::b::c` -> `a/b/c.hexa`
    # relative to the repo root (ROOT), falling back to the entry dir.
    for m in re.finditer(r'^\s*use\s+([A-Za-z_][\w]*(?:::[A-Za-z_][\w]*)+)\s*$', txt, re.M):
        rel = m.group(1).replace("::", os.sep) + ".hexa"
        for c in [os.path.join(ROOT, rel), os.path.join(d, rel), rel]:
            if os.path.exists(os.path.normpath(c)): deps.append(os.path.normpath(c)); break
    for x in deps: walk(x)
    seen.append(f)
walk(entry)
out = []
for f in seen:
    if f.endswith("embedded.gen.hexa"):
        out.append("// STUB\n" + STUB); continue
    t = open(f, encoding="utf-8", errors="replace").read()
    t = re.sub(r'^\s*(import|use)\s+"[^"]*".*$', '', t, flags=re.M)
    # strip the `::`-path `use a::b::c` lines too (resolved above, no quotes)
    t = re.sub(r'^\s*use\s+[A-Za-z_][\w]*(?:::[A-Za-z_][\w]*)+\s*$', '', t, flags=re.M)
    out.append("// ==== " + f + " ====\n" + t)
open(out_path, "w").write("\n".join(out))
print("flatten:", len(seen), "files", ("\n".join(out)).count(chr(10)) + 1, "lines")
