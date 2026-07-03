#!/usr/bin/env python3
# tool/emit_runtime_cuda_via_python.py
#
# Reproduce emit_runtime_cuda_c() WITHOUT a working hexa binary, for hosts whose
# prebuilt runtime.a is stale (rt_map_set_inplace_native undefined etc.). The
# emitter fn body (self/cuda/runtime_cuda_emit.hexa lines `let s = ...` ..
# `return s`) is a pure concatenation of C string literals joined by ` +`; we
# extract those literals and de-escape them to bytes — byte-identical to what
# the hexa emitter would write.
#
# Usage: python3 tool/emit_runtime_cuda_via_python.py self/cuda/runtime_cuda_emit.hexa OUT.c
import sys, re

src = open(sys.argv[1], 'r', encoding='utf-8').read()
lines = src.splitlines()

# locate the emit fn and its `let s = ...` .. `return s`
start = None
for i, ln in enumerate(lines):
    if ln.strip().startswith('let s ='):
        start = i; break
assert start is not None, "no `let s =` found"
end = None
for i in range(start, len(lines)):
    if lines[i].strip() == 'return s':
        end = i; break
assert end is not None, "no `return s` found"

def decode_literal(body):
    # body is the chars between the outer quotes; handle \n \t \" \\ etc.
    out = []
    k = 0
    while k < len(body):
        c = body[k]
        if c == '\\' and k + 1 < len(body):
            n = body[k+1]
            mp = {'n':'\n','t':'\t','r':'\r','"':'"','\\':'\\','0':'\0',"'":"'"}
            if n in mp:
                out.append(mp[n]); k += 2; continue
            # unknown escape: keep backslash + char
            out.append(n); k += 2; continue
        out.append(c); k += 1
    return ''.join(out)

pieces = []
lit_re = re.compile(r'"((?:[^"\\]|\\.)*)"')
for i in range(start, end):
    ln = lines[i]
    # strip leading `let s = ` on the first line
    # find ALL string literals on the line (most lines have exactly one)
    for m in lit_re.finditer(ln):
        pieces.append(decode_literal(m.group(1)))

text = ''.join(pieces)
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    f.write(text)
print(f"[py-emit] wrote {sys.argv[2]} ({len(text)} bytes)")
