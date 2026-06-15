# Non-n6 breakthrough probe (no deps): SPF sieve → arithmetic functions →
# scan identity templates over all n, surface anchors OTHER than 6.
N = 100000
spf = list(range(N+1))
i = 2
while i*i <= N:
    if spf[i] == i:
        for j in range(i*i, N+1, i):
            if spf[j] == j: spf[j] = i
    i += 1

def factor(n):
    f = {}
    while n > 1:
        p = spf[n]
        while n % p == 0:
            f[p] = f.get(p,0)+1; n//=p
    return f

def sigma(n):
    r=1
    for p,e in factor(n).items(): r*= (p**(e+1)-1)//(p-1)
    return r
def phi(n):
    r=1
    for p,e in factor(n).items(): r*= (p-1)*p**(e-1)
    return r
def tau(n):
    r=1
    for p,e in factor(n).items(): r*=(e+1)
    return r
def J2(n):
    r=1
    for p,e in factor(n).items(): r*= (p*p-1)*(p*p)**(e-1)
    return r
def psi(n):
    r=1
    for p,e in factor(n).items(): r*= (p+1)*p**(e-1)
    return r
def sopfr(n): return sum(p*e for p,e in factor(n).items())

def scan(pred, lo=2, hi=N, cap=10):
    hits=[]
    for n in range(lo,hi+1):
        if pred(n):
            hits.append(n)
            if len(hits)>cap+1: break
    full=[n for n in range(lo,hi+1) if pred(n)] if len(hits)<=cap+1 else None
    cnt=len(full) if full is not None else f">{cap}"
    return hits[:cap], cnt

laws = {
 "sigma*phi = n*tau   (THE 6-law)":  lambda n: sigma(n)*phi(n)==n*tau(n),
 "sigma = 2n (perfect)":             lambda n: sigma(n)==2*n,
 "sigma = 3n (3-perfect)":           lambda n: sigma(n)==3*n,
 "sigma = 4n (4-perfect)":           lambda n: sigma(n)==4*n,
 "phi*tau = n":                      lambda n: phi(n)*tau(n)==n,
 "sigma*phi = n*n":                  lambda n: sigma(n)*phi(n)==n*n,
 "J2 = sigma*phi":                   lambda n: J2(n)==sigma(n)*phi(n),
 "psi*phi = n*tau":                  lambda n: psi(n)*phi(n)==n*tau(n),
 "psi = 2*phi":                      lambda n: psi(n)==2*phi(n),
 "tau*phi = sigma":                  lambda n: tau(n)*phi(n)==sigma(n),
 "sigma*tau = n*psi":                lambda n: sigma(n)*tau(n)==n*psi(n),
 "sopfr = tau":                      lambda n: sopfr(n)==tau(n),
 "sigma+phi = n*tau":                lambda n: sigma(n)+phi(n)==n*tau(n),
 "phi*3 = n  AND sigma=2n":          lambda n: phi(n)*3==n and sigma(n)==2*n,
 "sigma*phi*tau = 24n":              lambda n: sigma(n)*phi(n)*tau(n)==24*n,
 "psi = sigma":                      lambda n: psi(n)==sigma(n),
 "J2 = n*phi":                       lambda n: J2(n)==n*phi(n),
 "sigma*phi = 24*tau":               lambda n: sigma(n)*phi(n)==24*tau(n),
}
print(f"=== anchor scan n=2..{N} ===")
for name,pred in laws.items():
    hits,cnt = scan(pred)
    tag = "  <-- UNIQUE" if cnt==1 else ("  <-- rare" if isinstance(cnt,int) and cnt<=4 else "")
    print(f"{name:34s} count={str(cnt):<6} first={hits}{tag}")

# ─── Phase 2: anchor SPECTRUM — which n is the UNIQUE solution of a c-templated law ───
def spectrum(value_fn, lo=2, hi=20000, label=""):
    from collections import defaultdict
    buckets=defaultdict(list)
    for n in range(lo,hi+1):
        v=value_fn(n)
        if v is not None: buckets[v].append(n)
    # unique anchors: value hit by exactly one n
    uniq={v:ns[0] for v,ns in buckets.items() if len(ns)==1}
    # report anchors n<=60 that are the SOLE solution of their constant
    anchored=sorted((n,v) for v,n in uniq.items() if n<=60)
    print(f"\n=== {label}: 유일-앵커 (n<=60, n=this is the ONLY n with that constant, range..{hi}) ===")
    for n,v in anchored:
        print(f"  n={n:<4} is the UNIQUE solution of  [{label}] = {v}")

# σ·φ = c·τ   → constant c = σφ/τ (integer only)
def cval_sphi_tau(n):
    num=sigma(n)*phi(n)
    return num//tau(n) if num%tau(n)==0 else None
spectrum(cval_sphi_tau, label="sigma*phi/tau")

# σ·φ = c·n   → c = σφ/n
def cval_sphi_n(n):
    num=sigma(n)*phi(n)
    return num//n if num%n==0 else None
spectrum(cval_sphi_n, label="sigma*phi/n")

# ψ·φ = c·τ
def cval_psiphi_tau(n):
    num=psi(n)*phi(n)
    return num//tau(n) if num%tau(n)==0 else None
spectrum(cval_psiphi_tau, label="psi*phi/tau")

# ─── Phase 3: SELF-REFERENTIAL fixed points R(n)=n (the real 6-law generalization) ───
# 6-law = σφ/τ has fixed point 6. Find OTHER ratio templates whose R(n)=n
# pins a DIFFERENT anchor. Connects to meta fixed-point f(x)=x (lineage doc).
def mu_simple(n):  # not needed
    return 0
templates = {
 "sigma*phi/tau":      lambda n: (sigma(n)*phi(n), tau(n)),
 "sigma*phi/n_isconst":lambda n: (sigma(n)*phi(n), 1),   # placeholder skip
 "psi*phi/tau":        lambda n: (psi(n)*phi(n), tau(n)),
 "sigma*tau/psi":      lambda n: (sigma(n)*tau(n), psi(n)),
 "psi*tau/sigma":      lambda n: (psi(n)*tau(n), sigma(n)),
 "sigma/phi_*tau? sig*tau/phi": lambda n: (sigma(n)*tau(n), phi(n)),
 "J2/(sigma)":         lambda n: (J2(n), sigma(n)),
 "J2/(psi)":           lambda n: (J2(n), psi(n)),
 "sigma*psi/(n*tau)":  lambda n: (sigma(n)*psi(n), n*tau(n)),
 "psi*phi/(sigma)":    lambda n: (psi(n)*phi(n), sigma(n)),
 "sigma*phi/(psi)":    lambda n: (sigma(n)*phi(n), psi(n)),
 "J2*tau/(sigma*phi)": lambda n: (J2(n)*tau(n), sigma(n)*phi(n)),
}
print("\n=== Phase 3: 자기참조 부동점  R(n)=n  (6-law 일반화) ===")
for name,fn in templates.items():
    fps=[]
    for n in range(2,20001):
        num,den=fn(n)
        if den and num%den==0 and num//den==n:
            fps.append(n)
            if len(fps)>8: break
    if name.endswith("isconst"): continue
    tag = "  <-- UNIQUE fixed point" if len(fps)==1 else ("  <-- few" if 1<len(fps)<=4 else ("  (none)" if not fps else ""))
    print(f"  {name:30s} fixed-points(R(n)=n): {fps}{tag}")

# ─── Phase 4: 쌍대 구조 분석 + 큰 완전수(496,8128) 자기참조 법칙 사냥 ───
print("\n=== Phase 4: perfect-number self-referential laws ===")
perfects=[6,28,496,8128,33550336]
# For perfect n (sigma=2n), the 6-law sigma*phi/tau=n  <=> 2*phi=tau
#                            the 28-law sigma*tau/phi=n <=> 2*tau=phi
for n in perfects:
    if n>N: 
        print(f"  n={n}: (range 밖, factor 직접)"); continue
    s,p,t = sigma(n),phi(n),tau(n)
    law6 = (s*p==n*t)
    law28= (s*t==n*p)
    print(f"  n={n:<6} sigma=2n? {s==2*n}  | 6-law(σφ/τ=n)? {law6} (2φ={2*p} vs τ={t})  | 28-law(στ/φ=n)? {law28} (2τ={2*t} vs φ={p})")

# Broaden functions + hunt ANY self-ref template R(n)=n pinning a perfect>28.
def omega(n): return len(factor(n))
def Omega(n): return sum(factor(n).values())
def rad(n):
    r=1
    for p in factor(n): r*=p
    return r
def sigma2(n):
    r=1
    for p,e in factor(n).items(): r*=(p**(2*(e+1))-1)//(p*p-1)
    return r
funcs={"sigma":sigma,"phi":phi,"tau":tau,"psi":psi,"J2":J2,"sigma2":sigma2,"rad":rad,"sopfr":sopfr}
import itertools
names=list(funcs)
print("\n=== Phase 4b: 2-함수 비 F/G = n  유일 부동점 (n<=60, range..5000) ===")
seen=set()
for a,b in itertools.permutations(names,2):
    fa,fb=funcs[a],funcs[b]
    fps=[]
    for n in range(2,5001):
        db=fb(n)
        if db and fa(n)%db==0 and fa(n)//db==n:
            fps.append(n)
            if len(fps)>3: break
    if len(fps)==1 and fps[0] not in (2,3) and fps[0]<=60:
        key=fps[0]
        print(f"  {a}/{b} = n  →  유일 n={fps[0]}")

# ─── Phase 5: anchor MULTIPLICITY — 각 수가 몇 개 독립 법칙의 자기참조 부동점인가 ───
from collections import Counter
def F(*fs): return fs
lib = {
 "sigma*phi/tau": (lambda n:sigma(n)*phi(n), lambda n:tau(n)),
 "sigma*tau/phi": (lambda n:sigma(n)*tau(n), lambda n:phi(n)),
 "sigma/phi":     (lambda n:sigma(n),        lambda n:phi(n)),
 "psi/phi":       (lambda n:psi(n),          lambda n:phi(n)),
 "psi*phi/tau":   (lambda n:psi(n)*phi(n),   lambda n:tau(n)),
 "sigma*tau/psi": (lambda n:sigma(n)*tau(n), lambda n:psi(n)),
 "psi*tau/sigma": (lambda n:psi(n)*tau(n),   lambda n:sigma(n)),
 "J2/sopfr":      (lambda n:J2(n),           lambda n:sopfr(n)),
 "J2*tau/(sigma*phi)": (lambda n:J2(n)*tau(n), lambda n:sigma(n)*phi(n)),
 "sigma*psi/(n*tau)":  (lambda n:sigma(n)*psi(n), lambda n:n*tau(n)),
 "sigma2/(sigma*n)":   (lambda n:sigma2(n),   lambda n:sigma(n)*n),
 "psi*sigma/(n*tau)":  (lambda n:psi(n)*sigma(n), lambda n:n*tau(n)),
}
mult=Counter()
laws_at=defaultdict(list) if False else {}
from collections import defaultdict
laws_at=defaultdict(list)
for name,(num,den) in lib.items():
    for n in range(2,20001):
        d=den(n)
        if d and num(n)%d==0 and num(n)//d==n:
            mult[n]+=1; laws_at[n].append(name)
print("\n=== Phase 5: 자기참조 앵커 다중도 (법칙 개수 순) ===")
for n,c in mult.most_common(10):
    print(f"  n={n:<4} 앵커 법칙 {c}개:  {', '.join(laws_at[n])}")
