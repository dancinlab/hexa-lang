#!/usr/bin/env python3
# One-shot census of the "missing malformed-input guard" bug class across stdlib.
# Heuristic (advisory): the canonical permanent enforcer is the .hexa lint; this
# python sweep enumerates the class NOW to validate the detector + size the work.
import os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "stdlib"

def strip(src):
    # crude: drop // line comments, /* */ block comments, and "..." string bodies
    src = re.sub(r'//[^\n]*', '', src)
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    src = re.sub(r'"(\\.|[^"\\])*"', '""', src)
    return src

FN = re.compile(r'^\s*(?:pub\s+)?fn\s+(\w+)\s*\(([^)]*)', re.M)

def functions(src):
    # split top-level/nested fn headers; body = lines until next fn header
    hdrs = list(FN.finditer(src))
    for i, m in enumerate(hdrs):
        start = m.start()
        end = hdrs[i+1].start() if i+1 < len(hdrs) else len(src)
        params = re.findall(r'(\w+)\s*:', m.group(2)) + re.findall(r'(?:^|,)\s*(\w+)\s*(?:,|$)', m.group(2))
        yield m.group(1), set(params), src[start:end], start

def line_of(src, pos):
    return src.count('\n', 0, pos) + 1

FLOATLIT = re.compile(r'^\d')

def guarded(body, tok, upto):
    # is there an `if`-guard referencing tok before offset `upto`?
    pre = body[:upto]
    # guard forms: if .. tok .. (==0 | <=0 | <0. | >0 | <1 | len(tok) | tok.len())
    pat = re.compile(r'if\b[^\n{]*\b' + re.escape(tok) + r'\b[^\n{]*(==\s*0|<=\s*0|<\s*0\.|>\s*0|<\s*1\b|len\s*\(|\.len\s*\(\s*\))')
    if pat.search(pre): return True
    # generic: if len(tok)==0 / if tok.len()==0 anywhere before
    if re.search(r'if\b[^\n{]*(len\s*\(\s*' + re.escape(tok) + r'\s*\)|' + re.escape(tok) + r'\.len\s*\(\s*\))', pre): return True
    return False

findings = []
for dp, _, files in os.walk(ROOT):
    for fn in files:
        if not fn.endswith('.hexa'): continue
        if fn.endswith('_test.hexa') or fn.startswith('test_'): continue
        path = os.path.join(dp, fn)
        try: raw = open(path, encoding='utf-8', errors='ignore').read()
        except: continue
        src = strip(raw)
        for name, params, body, base in functions(src):
            # A) first-element OOB: <ident>[0]
            for m in re.finditer(r'\b(\w+)\s*\[\s*0\s*\]', body):
                arr = m.group(1)
                if arr in ('out','result','res','acc','buf','tmp','rows','cols'): continue
                if guarded(body, arr, m.start()): continue
                findings.append((path, line_of(src, base+m.start()), name, 'idx0', arr))
            # B) divide by param/len: / to_float(ident) or / ident (not literal)
            for m in re.finditer(r'/\s*(?:to_float\s*\(\s*)?([A-Za-z_]\w*(?:\.\w+)?)', body):
                div = m.group(1)
                d0 = div.split('.')[0]
                if d0 in ('PI','MU0','HALF_PI','CF_TWO_PI','ln10','TWO_PI','E','LN2','LN10'): continue
                # only flag if divisor is a param, or derived 'n'/'mass'/'tot'/'count'-like
                if d0 not in params and d0 not in ('n','tot','mass','count','denom','sm','s0','s1','s2','nm','dof','sum'):
                    continue
                if guarded(body, d0, m.start()): continue
                findings.append((path, line_of(src, base+m.start()), name, 'div', div))

# dedupe + rank by file
seen = set(); uniq = []
for f in findings:
    k = (f[0], f[2], f[3], f[4])
    if k in seen: continue
    seen.add(k); uniq.append(f)

from collections import Counter
bycls = Counter(f[3] for f in uniq)
byfile = Counter(f[0] for f in uniq)
print(f"TOTAL candidate unguarded sites: {len(uniq)}  (idx0={bycls['idx0']} div={bycls['div']})")
print(f"files touched: {len(byfile)}")
print("\n=== top 25 files by candidate count ===")
for path, c in byfile.most_common(25):
    print(f"  {c:3d}  {path}")
print("\n=== sample 20 sites ===")
for f in uniq[:20]:
    print(f"  {f[0].split('stdlib/')[-1]}:{f[1]}  {f[2]}()  [{f[3]}] {f[4]}")
