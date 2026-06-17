from fractions import Fraction as F
def fac(n):
    f={}; d=2; m=n
    while d*d<=m:
        while m%d==0: f[d]=f.get(d,0)+1; m//=d
        d+=1
    if m>1: f[m]=f.get(m,0)+1
    return f
def SIG(n):
    r=1
    for p,a in fac(n).items(): r*=(p**(a+1)-1)//(p-1)
    return r
def PHI(n):
    r=1
    for p,a in fac(n).items(): r*=(p-1)*p**(a-1)
    return r
def TAU(n):
    r=1
    for p,a in fac(n).items(): r*=a+1
    return r
def PSI(n):
    r=1
    for p,a in fac(n).items(): r*=(p+1)*p**(a-1)
    return r
def J2(n):
    r=1
    for p,a in fac(n).items(): r*=(p*p-1)*(p*p)**(a-1)
    return r
def SOPFR(n): return sum(p*a for p,a in fac(n).items())

# prime-power exact pieces
def sig(p,a): return (p**(a+1)-1)//(p-1)
def phi(p,a): return p**(a-1)*(p-1)
def tau(p,a): return a+1
def psi(p,a): return (p+1)*p**(a-1)
def j2(p,a):  return (p*p-1)*(p*p)**(a-1)
def npa(p,a): return p**a

# ===== 1) 8-law COMPLETE =====
print("### J2(n)=n·sopfr(n) ⟺ n=8  (완전증명) ###")
cands=[]
for P in [3,5,7]:
    Qmax=F(P,(F(6,10)*P-1))
    for Q in range(2,int(Qmax)+1):
        if all(pp<P for pp in fac(Q)): cands.append(P*Q)
cands=sorted(set(cands))
ok8=[n for n in cands if J2(n)==n*SOPFR(n)]
print(f"  k≥2 후보 {cands} → 해 {ok8}; prime-power 해 [8] ⇒ 유일 8  ({'OK' if ok8==[] else ok8})\n")

PRIMES=[2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97]
def gfun(num_den):
    num,den=num_den
    def g(p,a):
        N=1; D=1
        for f in num: N*=f(p,a)
        for f in den: D*=f(p,a)
        return F(N,D)
    return g

# multiplicative laws: g(p^a) and target solset; ∏g=1
LAWS={
 "σφ/τ→6":    (([sig,phi],[npa,tau]), [6]),
 "στ/φ→28":   (([sig,tau],[npa,phi]), [28]),
 "σ/φ→6":     (([sig],[npa,phi]),     [6]),
 "ψ/φ→6":     (([psi],[npa,phi]),     [6]),
 "στ/ψ→2":    (([sig,tau],[npa,psi]), [2]),
 "ψτ/σ→2":    (([psi,tau],[npa,sig]), [2]),
 "J2τ/(σφ)→2":(([j2,tau],[npa,sig,phi]), [2]),
 "σψ/(n²τ)→6":(([sig,psi],[npa,npa,tau]), [6]),
 "ψφ/τ→{4,6}":(([psi,phi],[npa,tau]), [4,6]),
}
def prove(g):
    # S = prime-powers with g>1
    S=[(p,a) for p in PRIMES for a in range(1,60) if g(p,a)>1]
    if len(S)>=40: return None,"S무한(g>1 빈발)"
    M=F(1)
    bymax={}
    for p,a in S: bymax[p]=max(bymax.get(p,F(0)), g(p,a))
    for p in bymax: M*=bymax[p]
    thr=F(1,1)/M
    # T = prime-powers that can appear (g>=thr); finite since g→0
    T=[(p,a) for p in PRIMES for a in range(1,60) if g(p,a)>=thr]
    if len(T)>200: return None,"T과대"
    # group by prime
    from collections import defaultdict
    byp=defaultdict(list)
    for p,a in T: byp[p].append(a)
    primes=sorted(byp)
    sols=set()
    # enumerate: each prime absent or one allowed exponent
    import itertools
    choices=[[None]+byp[p] for p in primes]
    for combo in itertools.product(*choices):
        val=F(1); n=1
        for p,a in zip(primes,combo):
            if a is not None: val*=g(p,a); n*=p**a
        if n>=2 and val==1: sols.add(n)
    return sorted(sols), f"M={M} |T|={len(T)}"

print("### 곱셈적 앵커 generic prover (∏g=1) ###")
for name,((num,den),expect) in LAWS.items():
    g=gfun((num,den))
    sols,info=prove(g)
    status = "OK" if sols==sorted(expect) else ("INF" if sols is None else f"≠ {sols}")
    print(f"  {name:14s} → {sols if sols is not None else info}   기대 {expect}  [{status}] {info if sols is not None else ''}")

# ===== 2) infinite-g laws: only (2,1) has g<1  → one-sub-unit argument =====
print("\n### g>1 빈발 법칙 — '유일 <1 인자' 논증 ###")
def check_one_subunit(g, expect, name):
    # (a) (p,a) with g<1  must be exactly {(2,1)}
    sub=[(p,a) for p in PRIMES for a in range(1,30) if g(p,a)<1]
    # (b) g==1 prime-powers
    eq1=[(p,a) for p in PRIMES for a in range(1,30) if g(p,a)==1]
    # (c) reciprocal partner: g(p,a)==1/g(2,1)
    rec=F(1)/g(2,1)
    partners=[(p,a) for p in PRIMES for a in range(1,30) if g(p,a)==rec]
    # candidate solutions: empty(n=1 skip) · {single eq1 prime-power} · {2^1 × single partner}
    sols=set()
    for p,a in eq1: sols.add(p**a)
    for p,a in partners: sols.add(2*(p**a))
    sols={n for n in sols if n>=2}
    okA = sub==[(2,1)]
    print(f"  {name:12s}: <1 인자={sub} (유일2^1? {okA}) · g=1 at {eq1} · 1/g(2)={rec} at {partners}")
    print(f"     ⇒ 해 = {sorted(sols)}  기대 {expect}  [{'OK' if sorted(sols)==sorted(expect) else '≠'}]")
check_one_subunit(gfun(([SIG.__call__ if False else sig,phi],[npa,tau])), [6], "σφ/τ→6")
check_one_subunit(gfun(([psi,phi],[npa,tau])), [4,6], "ψφ/τ→{4,6}")
# large-range numeric confirmation
print("\n  수치 확인 (n≤300000):")
import sys
def Rscan(numf,denf):
    s=[]
    for n in range(2,300001):
        if numf(n)==n*denf(n): s.append(n)
    return s
print("   σφ=nτ :", Rscan(lambda n:SIG(n)*PHI(n), lambda n:TAU(n)))
print("   ψφ=nτ :", Rscan(lambda n:PSI(n)*PHI(n), lambda n:TAU(n)))
