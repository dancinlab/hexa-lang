#!/usr/bin/env python3
# bucket_nsys.py — bucket nsys CUDA GPU trace into GEMM / GLUE / OPTIMIZER, compute device-idle GAP,
# valley_fraction and the Amdahl ceiling 1/(1-valley).
#
# Input: nsys_gputrace.csv  (from `nsys stats --report cuda_gpu_trace --format csv`)
#        nsys_kernsum.txt    (the cuda_gpu_kern_sum table, for a name listing fallback)
#
# We compute, over the profiled window [t_first_kernel_start, t_last_kernel_end]:
#   busy_b = sum of kernel durations in bucket b   (note: with one stream, kernels are serial -> no overlap;
#                                                    we additionally compute a union to be overlap-safe)
#   span   = t_last_end - t_first_start
#   gap    = span - union(all kernel intervals)      (device truly idle between launches)
#   GEMM%  = busy_gemm/span, GLUE% = busy_glue/span, OPT% = busy_opt/span, GAP% = gap/span
#   valley_fraction = (GLUE% + OPT% + GAP%) = 1 - GEMM%
#   Amdahl ceiling  = 1/(1-valley_fraction) = 1/GEMM%
import sys, csv, re

GEMM = re.compile(r'gemm|dgemm|sgemm|hgemm|wgmma|matmul|_hx_k_gemm|cutlass|volta|ampere|sm[0-9]+_xmma|dot|cublas', re.I)
OPT  = re.compile(r'adam|adamw|optim|moment|\bupdate\b|sgd|lamb|rmsprop', re.I)
GLUE = re.compile(r'group_?norm|groupnorm|gelu|\bconv|expert|elementwise|im2col|col2im|token|pack|\badd\b|bias|softmax|\bce\b|cross_?entropy|reduce|norm|transpose|copy|cast|memset|fill|scale|relu|silu|layernorm|embed', re.I)

def classify(name):
    if GEMM.search(name): return 'GEMM'
    if OPT.search(name):  return 'OPT'
    if GLUE.search(name): return 'GLUE'
    return 'GLUE'  # default: un-named small kernels are between-GEMM glue (memory/launch-bound)

def parse_trace(path):
    # nsys cuda_gpu_trace csv columns vary by version; find Start, Duration, Name (kernel) columns.
    rows=[]
    with open(path) as f:
        # skip nsys preamble lines until header
        lines=[l for l in f]
    # locate header line (contains 'Start' and 'Duration' and 'Name')
    hdr_i=None
    for i,l in enumerate(lines):
        if 'Start' in l and 'Duration' in l and ('Name' in l or 'Kernel' in l):
            hdr_i=i; break
    if hdr_i is None:
        return rows
    rdr=csv.DictReader(lines[hdr_i:])
    def numcol(d, *cands):
        for c in d:
            cl=c.strip()
            for k in cands:
                if cl.lower().startswith(k): return c
        return None
    sample=None
    for r in rdr:
        if sample is None: sample=r
        sc = numcol(r,'start')
        dc = numcol(r,'duration','durat')
        nc=None
        for c in r:
            if c.strip().lower() in ('name','kernel name','demangled name'): nc=c; break
        if nc is None:
            # last text-ish column
            for c in reversed(list(r.keys())):
                if r[c] and not re.match(r'^[\d.,\s]+$', str(r[c])): nc=c; break
        if not sc or not dc or not nc: continue
        try:
            s=float(str(r[sc]).replace(',',''))
            d=float(str(r[dc]).replace(',',''))
        except: continue
        name=str(r.get(nc,'')).strip()
        if not name or d<=0: continue
        # CUDA trace rows also include memcpy/memset; keep only rows that look like kernels OR memcpy(glue)
        rows.append((s,d,name))
    return rows

def union_len(intervals):
    if not intervals: return 0.0
    iv=sorted(intervals); tot=0.0; cs,ce=iv[0]
    for s,e in iv[1:]:
        if s>ce: tot+=ce-cs; cs,ce=s,e
        else: ce=max(ce,e)
    tot+=ce-cs
    return tot

def main():
    trace=sys.argv[1] if len(sys.argv)>1 else 'nsys_gputrace.csv'
    rows=parse_trace(trace)
    if not rows:
        print("  bucket: no parseable trace rows — falling back to kern_sum table only")
        return
    # nsys durations/starts are in ns by default in csv. Convert to ms.
    NS=1e6
    t0=min(s for s,d,n in rows); t1=max(s+d for s,d,n in rows)
    span=(t1-t0)/NS
    by={'GEMM':[], 'GLUE':[], 'OPT':[]}
    busy={'GEMM':0.0,'GLUE':0.0,'OPT':0.0}
    intervals_all=[]
    for s,d,n in rows:
        b=classify(n); busy[b]+=d/NS
        by[b].append((s/NS,(s+d)/NS,n))
        intervals_all.append((s,s+d))
    union=union_len(intervals_all)/NS
    gap=max(0.0, span-union)
    def pct(x): return 100.0*x/span if span>0 else 0.0
    gemm_p=pct(busy['GEMM']); glue_p=pct(busy['GLUE']); opt_p=pct(busy['OPT']); gap_p=pct(gap)
    valley=glue_p+opt_p+gap_p
    print(f"  profiled span = {span:.3f} ms  | kernels = {len(rows)}  | union(busy) = {union:.3f} ms")
    print(f"  ---------------- BUCKET TABLE (% of step wall) ----------------")
    print(f"  (a) GEMM%       = {gemm_p:6.2f}%   ({busy['GEMM']:.3f} ms, {len(by['GEMM'])} kernels)")
    print(f"  (b) GLUE%       = {glue_p:6.2f}%   ({busy['GLUE']:.3f} ms, {len(by['GLUE'])} kernels)")
    print(f"  (c) OPTIMIZER%  = {opt_p:6.2f}%   ({busy['OPT']:.3f} ms, {len(by['OPT'])} kernels)")
    print(f"  (d) GAP/idle%   = {gap_p:6.2f}%   ({gap:.3f} ms)  [device truly idle = dispatch latency]")
    print(f"  ---------------------------------------------------------------")
    print(f"  valley_fraction = GLUE+OPT+GAP = {valley/100:.4f}  ({valley:.2f}%)")
    if gemm_p>0:
        print(f"  AMDAHL CEILING  = 1/(1-valley) = 1/GEMM% = {100.0/gemm_p:.3f}x")
    # per-bucket priority ranking (biggest reclaimable chunk first)
    ranked=sorted([('GLUE(->FF-EPILOGUE/FF-VALLEY)',glue_p),('OPTIMIZER(->FF-FUSED-OPTIM)',opt_p),('GAP/idle(->FF-XSTREAM)',gap_p)], key=lambda x:-x[1])
    print(f"  per-bucket priority (biggest reclaimable first):")
    for i,(nm,p) in enumerate(ranked,1):
        print(f"    {i}. {nm:32s} {p:6.2f}%")
    # top kernels by total time for the verbatim listing
    agg={}
    for s,d,n in rows:
        key=re.sub(r'<.*?>','',n)[:60]
        agg[key]=agg.get(key,0.0)+d/NS
    print(f"  --- top 15 kernels by total time (ms, bucket) ---")
    for k,v in sorted(agg.items(),key=lambda x:-x[1])[:15]:
        print(f"    {v:8.3f} ms  [{classify(k):4s}]  {k}")

if __name__=='__main__':
    main()
