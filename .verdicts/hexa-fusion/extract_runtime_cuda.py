#!/usr/bin/env python3
# extract_runtime_cuda.py — deterministically reconstruct runtime_cuda.c from the
# emit SSOT self/cuda/runtime_cuda_emit.hexa. The emit body emit_runtime_cuda_c()
# is PURE string concatenation ("..." + "..." + ...), no control flow, so the C
# output = the ordered concat of every string literal between `let s = ` and
# `return s`, with hexa string-escapes (\n \" \\ \t) unescaped. The local/pool
# hexa toolchain miscompiles this emitter (drops blocks); this extractor is the
# faithful reconstruction path the P1B verdict established. Includes the P1B-a'
# [EAGER-DEVGLUE-FIRED] edit since it reads the (edited) SSOT.
import sys, re

emit = sys.argv[1] if len(sys.argv) > 1 else "self/cuda/runtime_cuda_emit.hexa"
out  = sys.argv[2] if len(sys.argv) > 2 else "runtime_cuda.c"

lines = open(emit, encoding="utf-8").read().splitlines()

# locate emit_runtime_cuda_c() body: from `let s = "` to the `return s`
start = None
end   = None
for i, ln in enumerate(lines):
    if start is None and re.match(r'\s*let s = "', ln):
        start = i
    elif start is not None and re.match(r'\s*return s\s*$', ln):
        end = i
        break
if start is None or end is None:
    sys.exit("FATAL: could not bracket emit_runtime_cuda_c body")

def unescape(lit):
    # lit is the raw chars between the outer quotes, with hexa escapes.
    res = []
    i = 0
    while i < len(lit):
        c = lit[i]
        if c == '\\' and i + 1 < len(lit):
            n = lit[i+1]
            res.append({'n':'\n','t':'\t','r':'\r','"':'"','\\':'\\','0':'\0'}.get(n, '\\'+n))
            i += 2
        else:
            res.append(c)
            i += 1
    return ''.join(res)

# extract the quoted literal from each chain line. Each is:  <indent>"<lit>" +
#  or the final:  <indent>"<lit>"
pat = re.compile(r'^\s*"(.*)"\s*\+?\s*$')
# the first body line is:  let s = "<lit>" +
first = re.compile(r'^\s*let s = "(.*)"\s*\+?\s*$')

parts = []
for j in range(start, end):
    ln = lines[j]
    m = first.match(ln) if j == start else pat.match(ln)
    if not m:
        # tolerate blank / continuation lines; but a non-matching content line is fatal
        if ln.strip() == "" or ln.strip() == "+":
            continue
        sys.exit(f"FATAL: unparsed chain line {j+1}: {ln!r}")
    parts.append(unescape(m.group(1)))

c_text = ''.join(parts)
open(out, "w", encoding="utf-8").write(c_text)
print(f"[extract] wrote {out}: {len(c_text)} bytes from {len(parts)} literals (lines {start+1}..{end})")
# self-check markers
for mk in ("_hx_k_clm_megafwd_fp64", "MEGAFWD-FIRED", "EAGER-DEVGLUE-FIRED",
           "OWN-GEMM-FIRED", "_hx_k_gelu", "erf("):
    print(f"  {'OK ' if mk in c_text else 'MISS'} {mk} x{c_text.count(mk)}")
