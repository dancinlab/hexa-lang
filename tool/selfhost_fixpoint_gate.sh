#!/bin/bash
# tool/selfhost_fixpoint_gate.sh — HEXA-CC-NATIVE N5/N7 fixpoint gate.
#
# Asserts the C-free native arm64 compiler reproduces ITSELF byte-exact:
# two consecutive NATIVE self-emits of the whole compiler are byte-identical.
# This is the N5 fixpoint invariant; running it in (nightly) CI is N7.
#
#   aprime(C-transpiled) --emit=obj--> cc-prc2.o --hld_ld--> gen2(native)
#   gen2 --emit=obj--> cc-gen3.o --hld_ld--> gen3(native)
#   gen3 --emit=obj--> cc-gen4.o
#   ASSERT cc-gen3.o == cc-gen4.o          (consecutive native stages)
#
# cc-prc2.o (aprime/C-transpile) is NOT expected to equal cc-gen3.o — that is
# the one-time C-transpile<->native boundary delta (embedded modhash etc.).
# The fixpoint is between consecutive NATIVE stages, which is the correct
# definition of a self-reproducing compiler.
#
# Usage:
#   tool/selfhost_fixpoint_gate.sh [-r REPO] [-v HEXA_V2] [-w WORKDIR] [-k]
#     -r REPO     repo root holding compiler/      (default: cwd)
#     -v HEXA_V2  C-transpiler used to build aprime (default: ~/.hx/bin/self/native/hexa_v2)
#     -w WORKDIR  scratch dir for artifacts        (default: mktemp)
#     -k          keep WORKDIR on exit (debug)
#
# Exit codes: 0 = fixpoint holds · 1 = build/emit/link failure · 3 = NOT byte-identical.
#
# Verified 2026-06-10 (darwin/arm64): cc-gen3.o == cc-gen4.o,
# sha256 ece490874337a3241fd6f02908ac85160e6f5574dfcc202a03ce7a8385285cb3 (3461680B).
# See .verdicts/hexa-cc-native/F-HEXA-CC-NATIVE-N5-FIXPOINT-ACHIEVED.txt.
set -u

REPO="$(pwd)"
HEXA_V2="$HOME/.hx/bin/self/native/hexa_v2"
WORK=""
KEEP=0
while [ $# -gt 0 ]; do
    case "$1" in
        -r) REPO="$2"; shift 2 ;;
        -v) HEXA_V2="$2"; shift 2 ;;
        -w) WORK="$2"; shift 2 ;;
        -k) KEEP=1; shift ;;
        *) echo "fixpoint-gate: unknown arg '$1'" >&2; exit 1 ;;
    esac
done
[ -f "$REPO/compiler/main.hexa" ] || { echo "fixpoint-gate: no compiler/main.hexa under $REPO" >&2; exit 1; }
[ -n "$WORK" ] || WORK="$(mktemp -d -t n5_fixpoint.XXXXXX)"
mkdir -p "$WORK"
[ "$KEEP" = 1 ] || trap 'rm -rf "$WORK"' EXIT

APRIME="$WORK/aprime"
FLAT="$WORK/ap_flat.hexa"
RT="$WORK/runtime.o"
HLD="$WORK/hld"
say() { echo "[fixpoint-gate] $*"; }
die() { echo "[fixpoint-gate] FAIL: $*" >&2; exit "${2:-1}"; }

# 0. native linker (hexa_ld) built from the same source tree.
say "building hexa_ld ..."
HEXA_MAC_BUILD_OK=1 hexa build "$REPO/tool/hexa_ld.hexa" -o "$HLD" >/dev/null 2>&1 || die "hexa_ld build" 1
# runtime.o: reuse a prebuilt one if present, else build via build_aprime's stage.
if [ -f "$REPO/build/rtx/runtime.o" ]; then cp "$REPO/build/rtx/runtime.o" "$RT"; fi

# 1. aprime (C-transpiled native-emitting compiler) from current source.
say "building aprime (build_aprime.sh) ..."
HEXA_MAC_BUILD_OK=1 nice -n 19 bash "$REPO/tool/build_aprime.sh" -o "$APRIME" -r "$REPO" -v "$HEXA_V2" \
    >"$WORK/build.log" 2>&1 || { tail -20 "$WORK/build.log" >&2; die "build_aprime" 1; }
grep -q "smoke: exit(42)==42 PASS" "$WORK/build.log" || die "aprime smoke" 1
[ -f "$RT" ] || { f=$(ls -t "$REPO"/build/**/runtime.o 2>/dev/null | head -1); [ -n "$f" ] && cp "$f" "$RT"; }
[ -f "$RT" ] || die "no runtime.o (set build/rtx/runtime.o)" 1

# 2. flatten compiler/main.hexa (reuse build_aprime stage-1 closure walk).
say "flattening compiler/main.hexa ..."
REPO="$REPO" FLAT="$FLAT" python3 - <<'PY' || die "flatten" 1
import re, os
repo=os.environ["REPO"]; flat=os.environ["FLAT"]; os.chdir(repo)
seen=[]; sset=set()
STUB=('pub let ATLAS_HASH: string = "fixture"\npub let ATLAS_SOURCE_COUNT: i64 = 0\n'
      'pub let ATLAS_GENERATED_AT: string = "fixture"\n'
      + ''.join(f'pub let ATLAS_{k}_NODES: [AtlasNode] = []\n' for k in "PCLEFRSXQ"))
def walk(f):
    f=os.path.normpath(f)
    if f in sset or not os.path.exists(f): return
    sset.add(f); d=os.path.dirname(f); txt=open(f,encoding="utf-8",errors="replace").read(); deps=[]
    for m in re.finditer(r'^\s*import\s+"([^"]+)"',txt,re.M): deps.append(os.path.normpath(os.path.join(d,m.group(1))))
    for m in re.finditer(r'^\s*use\s+"([^"]+)"',txt,re.M):
        p=m.group(1);
        if not p.endswith(".hexa"): p+=".hexa"
        for c in [p,os.path.join(d,p),os.path.join(d,os.path.basename(p))]:
            if os.path.exists(os.path.normpath(c)): deps.append(os.path.normpath(c)); break
    for x in deps: walk(x)
    seen.append(f)
walk("compiler/main.hexa"); out=[]
for f in seen:
    if f.endswith("embedded.gen.hexa"): out.append("// STUB\n"+STUB); continue
    t=open(f,encoding="utf-8",errors="replace").read()
    t=re.sub(r'^\s*(import|use)\s+"[^"]*".*$','',t,flags=re.M); out.append("// ==== "+f+" ====\n"+t)
open(flat,"w").write("\n".join(out))
PY
# typeof->type_of belongs in source (PR #3020); tolerate until merged.
sed -i '' 's/typeof(/type_of(/g' "$FLAT" 2>/dev/null || sed -i 's/typeof(/type_of(/g' "$FLAT"

emit() { # $1=compiler $2=out.o
    nice -n 19 "$1" _drv.hexa --emit=obj --target=arm64-apple-darwin -o "$2" "$FLAT" \
        2>&1 | grep -vE "HX4001|HexaWarn|cause:|explain:|integer division" | tail -3
    [ -s "$2" ] || die "emit produced no $2" 1
}
link() { # $1=in.o $2=out-bin
    "$HLD" -o "$2" "$1" "$RT" --lc-main _main >/dev/null 2>&1 || die "link $2" 1
    codesign -s - -f "$2" 2>/dev/null
}

say "stage C->native: aprime --emit=obj cc-prc2.o ..."; emit "$APRIME" "$WORK/cc-prc2.o"
link "$WORK/cc-prc2.o" "$WORK/gen2"
say "native stage 1: gen2 --emit=obj cc-gen3.o ..."; emit "$WORK/gen2" "$WORK/cc-gen3.o"
link "$WORK/cc-gen3.o" "$WORK/gen3"
say "native stage 2: gen3 --emit=obj cc-gen4.o ..."; emit "$WORK/gen3" "$WORK/cc-gen4.o"

# 3. the fixpoint assertion.
if cmp -s "$WORK/cc-gen3.o" "$WORK/cc-gen4.o"; then
    say "OK ✅ cc-gen3.o == cc-gen4.o ($(stat -f%z "$WORK/cc-gen3.o" 2>/dev/null || stat -c%s "$WORK/cc-gen3.o")B) — N5 NATIVE FIXPOINT HOLDS"
    exit 0
else
    n=$(cmp -l "$WORK/cc-gen3.o" "$WORK/cc-gen4.o" 2>/dev/null | wc -l | tr -d ' ')
    die "cc-gen3.o != cc-gen4.o ($n differing bytes) — fixpoint BROKEN" 3
fi
